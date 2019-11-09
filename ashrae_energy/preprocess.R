library(data.table)
library(xts)
library(ggplot2)
library(viridis)

missing_summary <- function(dt){
  missing <- function(x) {
    mean(is.na(x))
  }
  funcs <- c('uniqueN', 'missing', 'class')
  res <- dt[, lapply(.SD, function(u){
    sapply(funcs, function(f) do.call(f,list(u)))
  })][, t(.SD)]
  colnames(res) <- funcs
  res <- data.table(res, keep.rownames = TRUE)
  names(res) <- c('col_name', 'unique_vals', 'missing', 'col_class')
  res[, unique_vals := as.integer(unique_vals)]
  res[, missing := as.numeric(missing)]
  return(res)
}

# read data ---------------------------------------------------------------

train <- fread('ashrae-energy-prediction/train.csv')
test <- fread('ashrae-energy-prediction/test.csv')
building <- fread('ashrae-energy-prediction/building_metadata.csv')
weather_train <- fread('ashrae-energy-prediction/weather_train.csv')
weather_test <- fread('ashrae-energy-prediction/weather_test.csv')

energy <- rbindlist(list(train, test), fill = TRUE)
weather <- rbindlist(list(weather_train, weather_test), fill = TRUE)
rm(weather_test, weather_train, train, test)

# building missing fix ----------------------------------------------------

building[, building_complete := as.numeric(complete.cases(building))]
building[, square_feet := log1p(square_feet)]
building[is.na(floor_count), floor_count := -1]

buildings <- building[, uniqueN(building_id), by = .(site_id, primary_use)]
ggplot(data = buildings, aes(x = factor(site_id), y = factor(primary_use), fill = V1)) +
  geom_tile(aes(fill = V1)) +
  scale_x_discrete(drop=FALSE) +
  scale_y_discrete(drop=FALSE) +
  scale_fill_viridis(option = 'plasma', direction = -1) +
  geom_text(aes(label=V1)) +
  theme(legend.position="none") +
  xlab("site_id") + ylab('primary_use')

building[primary_use == 'Technology/science', primary_use := 'Education']
building[
  primary_use %in% c('Entertainment/public assembly', 'Parking'),
  primary_use := 'Public services'
]
building[
  primary_use %in% c('Warehouse/storage', 'Retail'),
  primary_use := 'Other'
]
rm(buildings)

building[, year_built := round(year_built/10)]
building[is.na(year_built), year_built := -1]

energy <- merge(energy, building, all.x = TRUE, by = 'building_id')
rm(building)

# weather fix and merge ---------------------------------------------------

ts_test <- merge(
  weather[, .(weather_ts = uniqueN(timestamp)), by = site_id],
  energy[, .(energy_ts = uniqueN(timestamp)), by = site_id],
  all = TRUE,
  by = 'site_id'
)
print(ts_test)
site_ids_add <- character()
timestamps_add <- character()
for (current_site_id in ts_test$site_id) {
  missing_ts <- setdiff(
    energy[site_id == current_site_id, timestamp],
    weather[site_id == current_site_id, timestamp]
  )
  site_ids_add <<- c(site_ids_add, rep(current_site_id, length(missing_ts)))
  timestamps_add <<- c(timestamps_add, missing_ts)
}
weather_add <- data.table(
  site_id = site_ids_add,
  timestamp = timestamps_add
)
weather <- rbindlist(list(weather, weather_add), fill = TRUE)
weather[, weather_complete := as.numeric(complete.cases(weather))]
weather_test <- missing_summary(weather)
print(weather_test)
weather <- weather[order(timestamp), ]
weather[, cloud_coverage := as.character(cloud_coverage)]
weather[is.na(cloud_coverage), cloud_coverage := 'unknown']
weather[
  !is.na(precip_depth_1_hr) & precip_depth_1_hr > 0,
  hist(precip_depth_1_hr, breaks = seq(-1, max(precip_depth_1_hr), 1))
]
weather[precip_depth_1_hr >= 1, precip_depth_1_hr := log(precip_depth_1_hr+2)]
weather[is.na(precip_depth_1_hr), precip := 'missing']
weather[precip_depth_1_hr == -1, precip := 'precip_1']
weather[precip_depth_1_hr == 0, precip := 'no_precip']
precip_q <- weather[precip_depth_1_hr >= 1, summary(precip_depth_1_hr)]
weather[is.na(precip) & precip_depth_1_hr <= unname(precip_q['1st Qu.']), precip := 'precip_Q1']
weather[is.na(precip) & precip_depth_1_hr <= unname(precip_q['Median']), precip := 'precip_Q2']
weather[is.na(precip) & precip_depth_1_hr <= unname(precip_q['3rd Qu.']), precip := 'precip_Q3']
weather[is.na(precip), precip := 'precip_Q4']
weather[, precip_depth_1_hr := NULL]

weather[, air_temperature := na.locf(na.locf(air_temperature, na.rm = FALSE), fromLast = TRUE), by = site_id]
weather[, dew_temperature := na.locf(na.locf(dew_temperature, na.rm = FALSE), fromLast = TRUE), by = site_id]
weather[, sea_level_pressure := na.locf(na.locf(sea_level_pressure, na.rm = FALSE), fromLast = TRUE), by = site_id]
weather[, wind_direction := na.locf(na.locf(wind_direction, na.rm = FALSE), fromLast = TRUE), by = site_id]
weather[, wind_speed := na.locf(na.locf(wind_speed, na.rm = FALSE), fromLast = TRUE), by = site_id]
median_sea <- weather[, median(sea_level_pressure, na.rm = TRUE)]
weather[is.na(sea_level_pressure), sea_level_pressure := median_sea]
weather <- weather[order(timestamp), ]
weather[, temp_diff := diff.xts(air_temperature), by = site_id]
weather[is.na(temp_diff), temp_diff := 0]
weather[, site_id := as.integer(site_id)]
energy <- merge(energy, weather, all.x = TRUE, by = c('site_id', 'timestamp'))
rm(weather)

col_summary <- missing_summary(energy)
print(col_summary)

# time parse --------------------------------------------------------------

energy[, timestamp := as.POSIXct(timestamp, tz = 'UTC')]
energy[, weekday := weekdays(timestamp)]
energy[, hour := as.numeric(format(timestamp, '%H'))]
energy[, month := as.numeric(format(timestamp, '%m'))]

# meter_reading outlier fix -------------------------------------------------------------

energy[, meter_reading := log1p(meter_reading)]

meter0 <- energy[
  !is.na(meter_reading),
  .(zero_meter = round(mean(meter_reading == 0), 2)),
  by = building_id
  ][zero_meter > 0, ][order(-zero_meter), ]
print(meter0)

daily <- energy[
  !is.na(meter_reading),
  .(daily_meter = sum(meter_reading)),
  by = .(building_id, date = as.Date(timestamp))
  ]
ggplot(data = daily, aes(x = factor(date), y = factor(building_id), fill = daily_meter)) +
  geom_tile(aes(fill = daily_meter)) +
  scale_x_discrete(drop=FALSE) +
  scale_y_discrete(drop=FALSE) +
  scale_fill_viridis(option = 'plasma', direction = -1) +
  xlab("date") + ylab('building_id')

# TODO: something special about meter_reading=0 ?
# energy <- energy[is.na(meter_reading) | meter_reading > 0, ]

meter_pruned <- energy[!is.na(meter_reading), unname(quantile(meter_reading, 0.98))]
energy[meter_reading > meter_pruned, meter_reading := meter_pruned]

energy[, timestamp := NULL]

# Encode labels -----------------------------------------------------------

for (col in names(energy)) {
  missing <- energy[, mean(is.na(get(col)))]
  print(paste(col, missing))
}

categorical <- c(
  'cloud_coverage',
  'primary_use',
  'meter',
  'building_id',
  'site_id',
  'weekday',
  'floor_count',
  'year_built',
  'precip'
)
for (col in categorical) {
  energy[, (col) := as.numeric(as.factor(get(col)))]
  print(col)
  flush.console()
}

# write cleaned data ------------------------------------------------------

train_clean <- energy[!is.na(meter_reading), ]
train_clean[, row_id := NULL]
fwrite(train_clean, 'ashrae-energy-prediction/train_clean.csv', verbose = TRUE)
rm(train_clean)

test_clean <- energy[is.na(meter_reading), ]
test_clean[, meter_reading := NULL]
rm(energy)

# indices <- 1:test_clean[, .N]
indices <- which(!is.na(energy$row_id))
chunks <- split(indices, cut(seq_along(indices), 10, labels = FALSE)) 
for (i in 1:10) {
  chunk <- chunks[[i]]
  dt <- energy[chunk, ]
  dt[, meter_reading := NULL]
  fwrite(dt, sprintf('ashrae-energy-prediction/test_clean%s.csv', i), verbose = TRUE)
}
