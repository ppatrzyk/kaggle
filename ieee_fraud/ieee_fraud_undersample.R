library(data.table)

train <- fread('ieee-fraud-detection/train_clean.csv')

fraud_indices <- which(train$isFraud==1)
fraud_choose <- ceiling(length(fraud_indices)*0.9)
non_fraud_indices <- which(train$isFraud==0)

for (i in 1:30) {
  non_fraud_choose <- ceiling(runif(1, 20000, 40000))
  indices <- c(
    sample(fraud_indices, fraud_choose),
    sample(non_fraud_indices, non_fraud_choose)
  )
  under <- train[indices, ]
  under <- under[sample(.N), ]
  fwrite(under, paste0('ieee-fraud-detection/train_clean_undersample', i, '.csv'))
  print(paste(i, 'processed'))
  flush.console()
}
