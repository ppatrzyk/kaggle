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
  paste0('id_', 12:38)
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

cat_cols_prune <- c(
  paste0('card', c(1, 2, 3, 5)),
  paste0('addr', 1:2),
  paste0('id_', c(17, 19, 20, 21, 25, 26, 31, 33))
)
for (col in cat_cols_prune) {
  counts <- as.data.table(transactions[, .N, by = get(col)])[order(-N), ]
  q1 <- counts[, summary(N)][2]
  filter_out <- counts[N <= q1, get]
  transactions[get(col) %in% filter_out, c(col) := 'other']
}

transactions[, mail_match := (P_emaildomain == R_emaildomain)]
transactions[, afterdot := tstrsplit(as.character(TransactionAmt), '\\.', keep = 2)]
transactions[, afterdot_len := nchar(afterdot)]
transactions[is.na(afterdot_len), afterdot_len := 0]
transactions[, afterdot_len := paste0('D', afterdot_len)]
transactions[, afterdot := NULL]
transactions[, DateTime := as.POSIXlt('2017-12-01 00:00:00', tz = 'UTC') + TransactionDT]
transactions[, Date := as.Date(DateTime)]
transactions[, wday := weekdays(Date)]
transactions[, hour := substr(DateTime, 12, 13)]
transactions[, Date := NULL]
transactions[, DateTime := NULL]
transactions[, TransactionDT := NULL]

missing_summary <- function(dt){
  missing <- function(x) {
    mean(is.na(x))
  }
  mode_prop <- function(x) {
    mode_val <- names(sort(table(x), decreasing = TRUE))[1]
    mean(x == mode_val)
  }
  funcs <- c('uniqueN', 'missing', 'mode_prop', 'class')
  res <- dt[, lapply(.SD, function(u){
    sapply(funcs, function(f) do.call(f,list(u)))
  })][, t(.SD)]
  colnames(res) <- funcs
  res <- data.table(res, keep.rownames = TRUE)
  return(res)
}
col_summary <- missing_summary(transactions)

MISSING_THRESHOLD <- 0.8
drop_cols <- col_summary[
  (missing > MISSING_THRESHOLD & is.na(mode_prop)) | 
    (mode_prop > MISSING_THRESHOLD & is.na(missing)), 
  rn
]
transactions[, (drop_cols) := NULL]

median_impute <- function(col) {
  if (class(col) != 'numeric') {
    return(col)
  } else {
    col_fixed <- col
    median_val <- median(col_fixed, na.rm = TRUE)
    col_fixed[is.na(col_fixed)] <- median_val
    return(col_fixed)
  }
}
for (col in names(transactions)) {
  transactions[, (col) := median_impute(transactions[[col]])]
}

train <- transactions[!is.na(isFraud), ]
test <- transactions[is.na(isFraud), ]
rm(transactions)
test[, isFraud := NULL]

fwrite(train, 'train_clean.csv')
fwrite(test, 'test_clean.csv')
