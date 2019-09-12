library(data.table)
library(stringr)

setwd('~/ieee-fraud-detection')

files <- list.files(pattern='submit')
raw_preds <- fread(files[1])
setnames(raw_preds, 'isFraud', str_extract(files[1], '.*_'))
for (file in files[2:length(files)]) {
  dt <- fread(file)
  raw_preds[, (str_extract(file, '.*_')) := dt$isFraud]
}

raw_preds[,
  `:=`(
    mean_score = rowMeans(.SD),
    sd_score = apply(.SD, 1L, sd)
  ), 
  .SDcols = 2:ncol(raw_preds)
]

ensemble <- raw_preds[, .(TransactionID, isFraud = mean_score)]
fwrite(ensemble, 'esemble_submit.csv')
