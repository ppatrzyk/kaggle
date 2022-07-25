library(data.table)
library(ggplot2)

df <- fread("~/Documents/Github/kaggle/weather_forecasts/forecasts_test2.csv")
df <- df[order(weather_time, forecast_time, source), ]

# https://www.wunderground.com/history/daily/pl/wroc%C5%82aw/EPWR/date/2022-7-19
weather_url <- "https://api.weather.com/v1/location/EPWR:9:PL/observations/historical.json?apiKey=e1f10a1e78da46f5b10a1e78da96f525&units=m&startDate=20220721&endDate=20220730"
history_json <- jsonlite::fromJSON(weather_url)
history_df <- data.table(
  actual_temp = history_json$observations[['temp']],
  weather_time = as.POSIXct(history_json$observations[['valid_time_gmt']], origin="1970-01-01", tz='UTC')
)

df_comp <- df[history_df, on="weather_time", nomatch=0][forecast_time <= weather_time, ]
df_comp[, temp_error := temperature-actual_temp]
df_comp[, temp_error_abs := abs(temp_error)]
df_comp[, forecast_diff := as.numeric(difftime(forecast_time, weather_time, units="hours"))]

vars <- df_comp[, .(var = var(temperature)), by = .(source, weather_time)][order(var, decreasing = TRUE), ]

# TODO headers etc
ggplot(df_comp[source == vars$source[2] & weather_time == vars$weather_time[2]]) +
  geom_line(aes(x=forecast_time, y=temperature)) +
  geom_hline(aes(yintercept=actual_temp))

# actual vs all forecasts
ggplot(df_comp) +
  geom_line(aes(x=weather_time, y=actual_temp)) +
  geom_point(aes(x=weather_time, y=temperature, group=source, color=source), alpha=0.01)

# Histogram of errors
ggplot(df_comp, aes(x=temp_error)) +
  geom_histogram() +
  facet_grid(source ~ .)

# Error vs time before
ggplot(df_comp, aes(x=forecast_diff, y=temp_error)) +
  geom_point(alpha=0.01) +
  facet_grid(source ~ .)

# as.POSIXlt("2022-07-22T11:00:00", format="%Y-%m-%dT%H:%M:%S", tz = "UTC")
