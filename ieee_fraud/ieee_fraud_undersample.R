library(data.table)

train <- fread('C:\\Users\\ppatrzyk\\Documents\\ieee-fraud-detection\\train_clean.csv')

for (i in 1:15) {
  indices <- c(which(train$isFraud==1), sample(which(train$isFraud==0), 30000))
  under <- train[indices, ]
  under <- under[sample(.N), ]
  fwrite(under, paste0('ieee-fraud-detection/train_clean_undersample', i, '.csv'))
  print(paste(i, 'processed'))
  flush.console()
}
