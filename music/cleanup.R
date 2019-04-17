library(data.table)
lfm <- fread("lastfm_export.csv", encoding = 'UTF-8')

# tag fix
lfm[
  tags_length == 5 & tags_lastfm_all != '' & !is.na(tags_lastfm_all), 
  tags_lastfm := tags_lastfm_all
]
lfm[tags_length == 0 | is.na(tags_length), tags_lastfm := NA]
lfm[, tags_length := NULL]
lfm[, tags_lastfm_all := NULL]
lfm[tags_mb == '', tags_mb := NA]
lfm[, tags_mb_count := NA_integer_]
for (i in 1:lfm[, .N]) {
  mbtags <- lfm[i, tags_mb]
  taglenghth <- length(unlist(strsplit(mbtags, "; ")))
  set(lfm, i, 'tags_mb_count', taglenghth)
}

# duplicate fix
# Problem: lastfm redirects to incorrect mbid
# lfm <- lfm[artist_mb != '' & artist_lastfm != '[unknown]', ]
lfm[artist_lastfm == '', artist_lastfm := NA_character_]
count_names <- lfm[, .(artist_lastfm_repeats = .N), by = artist_lastfm]
count_names[, artist_lastfm_unique := ifelse(artist_lastfm_repeats == 1, TRUE, FALSE)]
lfm <- merge(lfm, count_names, all.x = TRUE, by = 'artist_lastfm')
rm(count_names)
lfm[!is.na(scrobbles_lastfm), .N, by = .(artist_mb_unique, artist_lastfm_unique)]
nonna <- lfm[!is.na(artist_lastfm), ]
duplicate_all <- nonna[
  duplicated(
    nonna[, .(artist_lastfm)]
  ) | duplicated(
    nonna[, .(artist_lastfm)], fromLast = TRUE
  ), 
]
rm(nonna)

# lfm <- lfm[order(scrobbles_lastfm, decreasing = TRUE), ]