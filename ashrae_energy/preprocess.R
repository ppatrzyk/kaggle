library(data.table)
library(xts)

train <- fread('ashrae-energy-prediction/train.csv')
test <- fread('ashrae-energy-prediction/test.csv')
building <- fread('ashrae-energy-prediction/building_metadata.csv')
weather_train <- fread('ashrae-energy-prediction/weather_train.csv')
weather_test <- fread('ashrae-energy-prediction/weather_test.csv')

energy <- rbindlist(list(train, test), fill = TRUE)
energy <- merge(energy, building, all.x = TRUE, by = 'building_id')
weather <- rbindlist(list(weather_train, weather_test), fill = TRUE)
energy <- merge(energy, weather, all.x = TRUE, by = c('site_id', 'timestamp'))
rm(train, test, building, weather_test, weather_train, weather)

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

floors <- energy[,
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
  energy[, .(floors_primary = as.integer(median(floor_count, na.rm = TRUE))), by = primary_use],
  all.x = TRUE,
  by = 'primary_use'
)
floors[is.na(floor_count), floor_count := floors_primary]
energy <- merge(
  energy,
  floors[, .(primary_use, site_id, replace_floor = floor_count)],
  all.x = TRUE,
  by = c('primary_use', 'site_id')
)
energy[is.na(floor_count), floor_count := replace_floor]
energy[, replace_floor := NULL]
median_floor_count <- energy[, median(floor_count, na.rm = TRUE)]
energy[is.na(floor_count), floor_count := median_floor_count]
rm(floors)

years <- energy[, .(year_built = median(year_built, na.rm = TRUE)), by = .(site_id, primary_use)]
years <- merge(
  years,
  energy[, .(year_replace = median(year_built, na.rm = TRUE)), by = .(site_id)],
  all.x = TRUE,
  by = 'site_id'
)
years[is.na(year_built), year_built := year_replace]
years[, year_replace := NULL]
energy <- merge(
  energy,
  years[, .(primary_use, site_id, replace_year = year_built)],
  all.x = TRUE,
  by = c('primary_use', 'site_id')
)
energy[is.na(year_built), year_built := replace_year]
year_median <- energy[, median(year_built, na.rm = TRUE)]
energy[is.na(year_built), year_built := year_median]
energy[, replace_year := NULL]
rm(years)

energy[, cloud_coverage := na.locf(na.locf(cloud_coverage, na.rm = FALSE), fromLast = TRUE), by = site_id]
energy[, cloud_coverage := as.character(cloud_coverage)]
# energy[is.na(cloud_coverage), cloud_coverage := 'unknown']
site_ids_fill <- energy[, mean(is.na(precip_depth_1_hr)), by = site_id][V1 < 0.1, site_id]
energy[
  site_id %in% site_ids_fill,
  precip_depth_1_hr := na.locf(na.locf(precip_depth_1_hr, na.rm = FALSE), fromLast = TRUE),
  by = site_id
]
precip_by_clouds <- energy[,
  .(
    precip = mean(precip_depth_1_hr, na.rm=TRUE),
    missing = mean(is.na(precip_depth_1_hr))
  ),
  by = cloud_coverage
][order(cloud_coverage), ]
precip_by_clouds[, precip := na.locf(precip)]
precip_by_clouds[, missing := NULL]
energy <- merge(
  energy,
  precip_by_clouds,
  all.x = TRUE,
  by = 'cloud_coverage'
)
energy[is.na(precip_depth_1_hr), precip_depth_1_hr := precip]
energy[, precip := NULL]

energy[, air_temperature := na.locf(na.locf(air_temperature, na.rm = FALSE), fromLast = TRUE), by = site_id]
energy[, dew_temperature := na.locf(na.locf(dew_temperature, na.rm = FALSE), fromLast = TRUE), by = site_id]
energy[, sea_level_pressure := na.locf(na.locf(sea_level_pressure, na.rm = FALSE), fromLast = TRUE), by = site_id]
energy[, wind_direction := na.locf(na.locf(wind_direction, na.rm = FALSE), fromLast = TRUE), by = site_id]
energy[, wind_speed := na.locf(na.locf(wind_speed, na.rm = FALSE), fromLast = TRUE), by = site_id]
median_sea <- energy[, median(sea_level_pressure, na.rm = TRUE)]
energy[is.na(sea_level_pressure), sea_level_pressure := median_sea]
energy[is.na(cloud_coverage), cloud_coverage := 'unknown']

for (col in names(energy)) {
  missing <- energy[, mean(is.na(get(col)))]
  print(paste(col, missing))
}

energy[, weekday := weekdays(timestamp)]
# todo parse timestamp

