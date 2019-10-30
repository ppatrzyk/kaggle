library(data.table)

test <- fread('~/ashrae-energy-prediction/test_clean.csv')
indices <- 1:test[, .N]
chunks <- split(indices, cut(seq_along(indices), 10, labels = FALSE)) 
for (i in 1:10) {
  chunk <- chunks[[i]]
  fwrite(test[chunk, ], sprintf('ashrae-energy-prediction/test_clean%s.csv', i))
}
