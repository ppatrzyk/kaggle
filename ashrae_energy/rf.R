library(data.table)
library(mlr)

fix_factors <- function(dt) {
  categorical <- c(
    'cloud_coverage', 'primary_use', 'year_built',
    'floor_count', 'meter', 'building_id', 'site_id', 
    'weekday', 'hour', 'month', 'precip',
    'building_complete', 'weather_complete'
  )
  for (col in categorical) {
    dt[, (col) := as.factor(get(col))]
    print(col)
    flush.console()
  }
}

train <- fread('~/ashrae-energy-prediction/train_clean.csv')
fix_factors(train)
nrows <- train[, .N]

task <- makeRegrTask(data = train, target = "meter_reading")
rm(train)
gc()
rf <- makeLearner(
  "regr.ranger",
  verbose = TRUE,
  num.threads = 8,
  num.trees = 32
)
rf_model <- train(rf, task)

# train_pred <- predict(rf_model, task = task, subset = sample(1:nrows, 2000))
# performance(train_pred)
rm(task)
gc()

test_dfs <- list()
for (i in 1:10) {
  filename <- paste0('~/ashrae-energy-prediction/test_clean', i, '.csv')
  test <- fread(filename)
  fix_factors(test)
  row_id <- test[, row_id]
  test[, row_id := NULL]
  prediction <- predict(rf_model, newdata = test)
  dt <- data.table(row_id = row_id, meter_reading = exp(prediction$data$response)-1)
  test_dfs[[i]] <- dt
  print(paste0(i, ' done...'))
  flush.console()
}
submit <- rbindlist(test_dfs)
fwrite(submit, '~/ashrae-energy-prediction/rf_submit.csv')
