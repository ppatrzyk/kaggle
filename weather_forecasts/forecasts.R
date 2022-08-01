library(data.table)
library(ggplot2)

df <- fread("~/Documents/Github/kaggle/weather_forecasts/forecasts.csv")
df <- df[order(weather_time, forecast_time, source), ]

# https://www.wunderground.com/history/daily/pl/wroc%C5%82aw/EPWR/date/2022-7-19
weather_url <- "https://api.weather.com/v1/location/EPWR:9:PL/observations/historical.json?apiKey=e1f10a1e78da46f5b10a1e78da96f525&units=m&startDate=20220721&endDate=20220801"
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

# Example forecast evolution
ggplot(df_comp[source == vars$source[2] & weather_time == vars$weather_time[2]]) +
  geom_line(aes(x=forecast_time, y=temperature, color="forecast")) +
  geom_hline(aes(yintercept=actual_temp, color="actual")) +
  labs(title = paste(vars$source[2], "forecasts for:", vars$weather_time[2]))

# actual vs all forecasts
ggplot(df_comp) +
  geom_point(aes(x=weather_time, y=temperature, group=source, color=source), alpha=0.01) +
  geom_line(aes(x=weather_time, y=actual_temp, color="actual"), size=1.5) +
  labs(title = "Actual temperature vs all forecasts")

# Histogram of errors
error_summary <- rbindlist(list(
  df_comp[, .(metric = names(summary(temp_error)), value = as.numeric(summary(temp_error))), by = source],
  df_comp[, .(metric = "sd", value = sd(temp_error)), by = source],
  df_comp[, .(metric = "mse", value = sqrt(mean(temp_error^2))), by = source],
  df_comp[, .(metric = "max_abs_error", value = max(abs(temp_error))), by = source]
))
error_summary_cast <- dcast.data.table(error_summary, source ~ metric)

ggplot(df_comp, aes(x=temp_error)) +
  geom_histogram(bins=100) +
  geom_vline(aes(xintercept = Median, color = source), error_summary_cast) +
  facet_grid(source ~ .) +
  labs(title = "Histogram of errors")

ggplot(error_summary[metric %in% c("max_abs_error", "mse"), ], aes(x=source, xend=source, y=0, yend=value)) +
  geom_segment() +
  geom_point(aes(x=source, y=value), size = 4, pch = 21, bg = 4, col = 1) +
  coord_flip() +
  facet_grid(metric ~ .) +
  labs(title = "Errors by source")

# Error vs time before
df_comp[, cor(forecast_diff, temp_error_abs), by = source]
ggplot(df_comp, aes(x=forecast_diff, y=temp_error_abs)) +
  geom_point(alpha=0.01) +
  geom_smooth(method='lm') + 
  facet_grid(source ~ .) +
  labs(title = "Errors by forecast timing", x = "Forecast before (hours)")

# as.POSIXlt("2022-07-22T11:00:00", format="%Y-%m-%dT%H:%M:%S", tz = "UTC")
