library(data.table)
library(xts)
library(ggplot2)
library(viridis)

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

floors <- building[,
  .(
   floor_count = as.integer(median(floor_count, na.rm = TRUE)),
   na_prop = mean(is.na(floor_count)),
   unique_vals = uniqueN(floor_count),
   observations = .N
  ),
  by = .(primary_use, site_id)
]
floors <- merge(
  floors,
  building[, .(floors_primary = as.integer(median(floor_count, na.rm = TRUE))), by = primary_use],
  all.x = TRUE,
  by = 'primary_use'
)
floors[is.na(floor_count), floor_count := floors_primary]
building <- merge(
  building,
  floors[, .(primary_use, site_id, replace_floor = floor_count)],
  all.x = TRUE,
  by = c('primary_use', 'site_id')
)
building[is.na(floor_count), floor_count := replace_floor]
building[, replace_floor := NULL]
median_floor_count <- building[, median(floor_count, na.rm = TRUE)]
building[is.na(floor_count), floor_count := median_floor_count]
rm(floors)

years <- building[, .(year_built = median(year_built, na.rm = TRUE)), by = .(site_id, primary_use)]
years <- merge(
  years,
  building[, .(year_replace = median(year_built, na.rm = TRUE)), by = .(site_id)],
  all.x = TRUE,
  by = 'site_id'
)
years[is.na(year_built), year_built := year_replace]
years[, year_replace := NULL]
building <- merge(
  building,
  years[, .(primary_use, site_id, replace_year = year_built)],
  all.x = TRUE,
  by = c('primary_use', 'site_id')
)
building[is.na(year_built), year_built := replace_year]
year_median <- building[, median(year_built, na.rm = TRUE)]
building[is.na(year_built), year_built := year_median]
building[, replace_year := NULL]
rm(years)

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
weather <- weather[order(timestamp), ]
weather[, cloud_coverage := na.locf(na.locf(cloud_coverage, na.rm = FALSE), fromLast = TRUE), by = site_id]
weather[, cloud_coverage := as.character(cloud_coverage)]
site_ids_fill <- weather[, mean(is.na(precip_depth_1_hr)), by = site_id][V1 < 0.1, site_id]
weather[
  site_id %in% site_ids_fill,
  precip_depth_1_hr := na.locf(na.locf(precip_depth_1_hr, na.rm = FALSE), fromLast = TRUE),
  by = site_id
  ]
precip_by_clouds <- weather[,
  .(
    precip = mean(precip_depth_1_hr, na.rm=TRUE),
    missing = mean(is.na(precip_depth_1_hr))
  ),
  by = cloud_coverage
][order(cloud_coverage), ]
precip_by_clouds[, precip := na.locf(precip)]
precip_by_clouds[, missing := NULL]
weather <- merge(
  weather,
  precip_by_clouds,
  all.x = TRUE,
  by = 'cloud_coverage'
)
weather[is.na(precip_depth_1_hr), precip_depth_1_hr := precip]
weather[, precip := NULL]

weather[, air_temperature := na.locf(na.locf(air_temperature, na.rm = FALSE), fromLast = TRUE), by = site_id]
weather[, dew_temperature := na.locf(na.locf(dew_temperature, na.rm = FALSE), fromLast = TRUE), by = site_id]
weather[, sea_level_pressure := na.locf(na.locf(sea_level_pressure, na.rm = FALSE), fromLast = TRUE), by = site_id]
weather[, wind_direction := na.locf(na.locf(wind_direction, na.rm = FALSE), fromLast = TRUE), by = site_id]
weather[, wind_speed := na.locf(na.locf(wind_speed, na.rm = FALSE), fromLast = TRUE), by = site_id]
median_sea <- weather[, median(sea_level_pressure, na.rm = TRUE)]
weather[is.na(sea_level_pressure), sea_level_pressure := median_sea]
weather[is.na(cloud_coverage), cloud_coverage := 'unknown']
weather <- weather[order(timestamp), ]
weather[, temp_diff := diff.xts(air_temperature), by = site_id]
weather[is.na(temp_diff), temp_diff := 0]
weather[, site_id := as.integer(site_id)]
energy <- merge(energy, weather, all.x = TRUE, by = c('site_id', 'timestamp'))
rm(weather)

# missing summary ---------------------------------------------------------

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
col_summary <- missing_summary(energy)

energy[, timestamp := as.POSIXct(timestamp, tz = 'UTC')]

# outlier fix -------------------------------------------------------------

meter0 <- energy[
  !is.na(meter_reading),
  .(zero_meter = round(mean(meter_reading == 0), 2)),
  by = building_id
  ][zero_meter > 0, ][order(-zero_meter), ]
print(meter0)
energy[, del := (is.na(row_id) & building_id %in% meter0[zero_meter > 2/3, building_id])]
energy <- energy[del == FALSE, ]
energy[, del := NULL]

energy[, meter_reading := log1p(meter_reading)]
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
energy <- energy[is.na(meter_reading) | meter_reading > 0, ]

meter_pruned <- energy[!is.na(meter_reading), unname(quantile(meter_reading, 0.98))]
energy[meter_reading > meter_pruned, meter_reading := meter_pruned]

# time parse --------------------------------------------------------------

for (col in names(energy)) {
  missing <- energy[, mean(is.na(get(col)))]
  print(paste(col, missing))
}

energy[, weekday := weekdays(timestamp)]
energy[, hour := format(timestamp, '%H')]
energy[, month := format(timestamp, '%m')]
energy[, timestamp := NULL]

# write cleaned data ------------------------------------------------------

train_clean <- energy[!is.na(meter_reading), ]
test_clean <- energy[is.na(meter_reading), ]
train_clean[, row_id := NULL]
test_clean[, meter_reading := NULL]
fwrite(train_clean, 'ashrae-energy-prediction/train_clean.csv')
fwrite(test_clean, 'ashrae-energy-prediction/test_clean.csv')
