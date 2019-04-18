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
lfm <- lfm[
  !(
    grepl('^\\[unknown\\]$|^various.*artists$', artist_mb, ignore.case = TRUE) |
      grepl('^\\[unknown\\]$|^various.*artists$', artist_lastfm, ignore.case = TRUE)
  ),
]
lfm[artist_lastfm == '', artist_lastfm := NA_character_]
count_names <- lfm[, .(artist_lastfm_repeats = .N), by = artist_lastfm]
count_names[, artist_lastfm_unique := ifelse(artist_lastfm_repeats == 1, TRUE, FALSE)]
lfm <- merge(lfm, count_names, all.x = TRUE, by = 'artist_lastfm')
rm(count_names)
lfm[!is.na(scrobbles_lastfm), .N, by = .(artist_mb_unique, artist_lastfm_unique)]

# this is for inspection
nonna <- lfm[!is.na(artist_lastfm), ]
duplicate_all <- nonna[
  duplicated(
    nonna[, .(artist_lastfm)]
  ) | duplicated(
    nonna[, .(artist_lastfm)], fromLast = TRUE
  ), 
  .(
    artist_lastfm, artist_mb, country_mb, 
    artist_lastfm_unique, artist_mb_unique, 
    listeners_lastfm, tags_mb_count
  )
][order(listeners_lastfm, decreasing = TRUE), ]
rm(nonna)

duplicated_artists <- duplicate_all[, unique(artist_lastfm)]
lfm[, ambiguous := NA]
lfm[!(artist_lastfm %in% duplicated_artists), ambiguous := FALSE]
for (artist in duplicated_artists) {
  tag_max <- lfm[artist_lastfm == artist, max(tags_mb_count)]
  index <- which(lfm$artist_lastfm == artist & lfm$tags_mb_count == tag_max)
  if(length(index) > 1){
    lfm[artist_lastfm == artist, ambiguous := TRUE]
    next
  }else{
    lfm[artist_lastfm == artist, ambiguous := FALSE]
    garbage <- which(lfm$artist_lastfm == artist & lfm$tags_mb_count != tag_max)
    lfm[garbage, c('listeners_lastfm', 'scrobbles_lastfm', 'tags_lastfm') := NA]
  }
}
# TODO compare with duplicate_all whether this is correct

# lfm <- lfm[order(scrobbles_lastfm, decreasing = TRUE), ]