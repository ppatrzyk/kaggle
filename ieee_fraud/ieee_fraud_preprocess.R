library(data.table)
library(stringr)

setwd('~/ieee-fraud-detection')
train_tran <- fread('train_transaction.csv')
train_iden <- fread('train_identity.csv')
test_tran <- fread('test_transaction.csv')
test_iden <- fread('test_identity.csv')

train_tran[, isIdent := (TransactionID %in% train_iden[, TransactionID])]
train <- merge(train_iden, train_tran, by = 'TransactionID', all = TRUE)

test_tran[, isIdent := (TransactionID %in% test_iden[, TransactionID])]
test <- merge(test_iden, test_tran, by = 'TransactionID', all = TRUE)

transactions <- rbindlist(list(train, test), fill = TRUE)
rm(train, test, train_tran, train_iden, test_tran, test_iden)

cat_cols_all <- c(
  paste0('card', 1:6),
  paste0('addr', 1:2),
  paste0('id_', 12:38),
  paste0('M', 1:9)
)
for (col in cat_cols_all){
  transactions[, (col) := as.character(transactions[[col]])]
}
fix_chars <- function(col) {
  if (class(col) != 'character') {
    return(col)
  } else {
    col_fixed <- str_trim(col, "both")
    col_fixed[col_fixed == ''] <- 'unknown'
    col_fixed[is.na(col_fixed)] <- 'unknown'
    col_fixed <- paste0('V', col_fixed)
    return(col_fixed)
  }
}
for (col in names(transactions)) {
  transactions[, (col) := fix_chars(transactions[[col]])]
}

transactions[, mail_match := (P_emaildomain == R_emaildomain)]
transactions[, afterdot := tstrsplit(as.character(TransactionAmt), '\\.', keep = 2)]
transactions[, afterdot_len := nchar(afterdot)]
transactions[is.na(afterdot_len), afterdot_len := 0]
transactions[, afterdot_len := paste0('D', afterdot_len)]
transactions[, afterdot := NULL]
trans_by_bin <- transactions[, .(bin_avg = mean(TransactionAmt)), by = card1]
transactions <- merge(transactions, trans_by_bin, by = 'card1', all.x = TRUE)
transactions[, bin_deviation := (TransactionAmt - bin_avg)]
transactions[, DateTime := as.POSIXlt('2017-12-01 00:00:00', tz = 'UTC') + TransactionDT]
transactions[, Date := as.Date(DateTime)]
transactions[, wday := weekdays(Date)]
transactions[, hour := as.integer(substr(DateTime, 12, 13))]
transactions[, Date := NULL]
transactions[, DateTime := NULL]
transactions[, TransactionDT := NULL]

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

get_min_max <- function(dt){
  funcs <- c('min', 'max')
  res <- dt[, lapply(.SD, function(u){
    sapply(funcs, function(f) do.call(f,list(u, na.rm = TRUE)))
  })][, t(.SD)]
  colnames(res) <- funcs
  res <- data.table(res, keep.rownames = TRUE)
  names(res) <- c('col_name', funcs)
  return(res)
}

col_summary <- missing_summary(transactions)
min_maxes <- get_min_max(transactions)
col_summary <- merge(col_summary, min_maxes, by = 'col_name')
rm(min_maxes)
col_summary[, missing := round(as.numeric(missing), 2)]

missing_impute <- function(col) {
  if (class(col) != 'numeric') {
    return(col)
  } else {
    col_fixed <- col
    col_fixed[is.na(col_fixed)] <- (-9999)
    return(col_fixed)
  }
}
for (col in names(transactions)) {
  transactions[, (col) := missing_impute(transactions[[col]])]
}

categorical_cols <- col_summary[col_class %in% c('character', 'logical'), col_name]
for (col in categorical_cols) {
  counts <- transactions[, .N, by = col]
  setnames(counts, 'N', paste0(col, '_count'))
  transactions <- merge(transactions, counts, by = col, all.x = TRUE)
}
transactions[, DeviceInfo := NULL]

devices <- transactions[, .N, by = DeviceInfo][order(-N),]
devices[, device := DeviceInfo]
devices[N < 100, device := 'other']
devices[grepl('windows', DeviceInfo, ignore.case = TRUE), device := 'windows']
devices[grepl('sm', DeviceInfo, ignore.case = TRUE), device := 'samsung']
devices[grepl('rv:', DeviceInfo, ignore.case = TRUE), device := 'RV']
devices[grepl('lg', DeviceInfo, ignore.case = TRUE), device := 'LG']
devices[grepl('moto', DeviceInfo, ignore.case = TRUE), device := 'motorola']
devices[grepl('^vane|huawei', DeviceInfo, ignore.case = TRUE), device := 'huawei']
devices[grepl('^vgt', DeviceInfo, ignore.case = TRUE), device := 'gt']
devices[grepl('blade', DeviceInfo, ignore.case = TRUE), device := 'blade']
devices[grepl('nexus', DeviceInfo, ignore.case = TRUE), device := 'nexus']
devices[grepl('pixel', DeviceInfo, ignore.case = TRUE), device := 'pixel']
devices[grepl('iliu', DeviceInfo, ignore.case = TRUE), device := 'ilium']
devices[grepl('^vhi', DeviceInfo, ignore.case = TRUE), device := 'hisense']
devices[grepl('linux', DeviceInfo, ignore.case = TRUE), device := 'linux']
devices[grepl('^vxt', DeviceInfo, ignore.case = TRUE), device := 'xt']
devices[grepl('^vf', DeviceInfo, ignore.case = TRUE), device := 'f']
devices[grepl('^vhtc', DeviceInfo, ignore.case = TRUE), device := 'htc']
devices[grepl('redmi', DeviceInfo, ignore.case = TRUE), device := 'redmi']
devices[grepl('^v[0-9]{4}', DeviceInfo, ignore.case = TRUE), device := 'some_numeric']
devices[, N := NULL]
transactions <- merge(transactions, devices, by = 'DeviceInfo', all.x = TRUE)
transactions[, DeviceInfo := NULL]

categorical_cols <- setdiff(c(categorical_cols, 'device'), 'DeviceInfo')

col_summary <- missing_summary(transactions)
col_summary[, missing := round(as.numeric(missing), 2)]

cat_cols_prune <- col_summary[col_class == 'character' & unique_vals > 100, col_name]
for (col in cat_cols_prune) {
  counts <- as.data.table(transactions[, .N, by = get(col)])[order(-N), ]
  # cutoff 1st Q
  q1 <- counts[, summary(N)][2]
  filter_out <- counts[N <= q1, get]
  transactions[get(col) %in% filter_out, c(col) := 'other']
}

train <- transactions[!is.na(isFraud), ]
test <- transactions[is.na(isFraud), ]
rm(transactions)
test[, isFraud := NULL]

fwrite(train, 'train_clean.csv')
fwrite(test, 'test_clean.csv')

cat(categorical_cols, sep = '\n', file = 'categorical_cols.txt')