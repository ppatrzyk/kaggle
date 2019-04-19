library(data.table)
library(foreach)
library(parallel)
library(doSNOW)

lfm <- fread("lastfm_export.csv", encoding = 'UTF-8')
countries <- fread('countries.csv')

# tag fix
lfm[
  tags_length == 5 & tags_lastfm_all != '' & !is.na(tags_lastfm_all), 
  tags_lastfm := tags_lastfm_all
]
lfm[tags_length == 0 | is.na(tags_length), tags_lastfm := NA]
lfm[, tags_length := NULL]
lfm[, tags_lastfm_all := NULL]
lfm[tags_mb == '', tags_mb := NA]
lfm[,
  tags_mb_count := ifelse(
    is.na(tags_mb),
    0,
    (lengths(regmatches(tags_mb, gregexpr(";", lfm$tags_mb))) + 1)
  )
]

# country fix
lfm[country_mb %in% c('', '[Worldwide]'), country_mb := NA]
lfm[grepl('Kingdom.*Netherlands', country_mb), country_mb := 'Netherlands']
lfm[grepl('Ivoire', country_mb), country_mb := 'Ivory Coast']
# test <- lfm[, .N, by = country_mb][order(N, decreasing = TRUE), ]
patterns <- countries[,
  .(pattern = paste0(sprintf('[ ;]%s[ ;]', adjectival), collapse = '|')), 
  by = country
]
patterns[, pattern := paste(pattern, sprintf('[ ;]%s[ ;]', country), sep = '|')]
rm(countries)
get_country <- function(tags) {
  if(is.na(tags) | tags == ''){
    return(NA_character_)
  }
  matches <- patterns[,
    grepl(pattern, tags, ignore.case = TRUE), 
    by = country
  ][V1 == TRUE, country]
  return(paste(sort(matches), collapse = '; '))
}

tags <- lfm[!is.na(tags_lastfm), tags_lastfm]
cores <- detectCores()
cl <- makeCluster(cores[1])
registerDoSNOW(cl)
pb <- txtProgressBar(max = length(tags), style = 3)
progress <- function(n) setTxtProgressBar(pb, n)
opts <- list(progress = progress)
countries <- foreach(
  i = 1:length(tags), 
  .packages = 'data.table', 
  .combine = rbind, 
  .options.snow = opts
) %dopar% {
  get_country(tags[i])
}
close(pb)
stopCluster(cl)

lfm[, country_lastfm := NA_character_]
lfm[!is.na(tags_lastfm), country_lastfm := unname(countries[, 1])]
lfm[country_lastfm == '', country_lastfm := NA_character_]

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

# duplicate inspection
lfm[, orig_index := 1:.N]
nonna <- lfm[!is.na(artist_lastfm), ]
duplicate_all <- nonna[
  duplicated(
    nonna[, .(artist_lastfm)]
  ) | duplicated(
    nonna[, .(artist_lastfm)], fromLast = TRUE
  ), 
  .(
    orig_index, artist_lastfm, artist_mb, 
    country_lastfm, country_mb, 
    artist_lastfm_unique, artist_mb_unique, 
    listeners_lastfm, tags_mb_count
  )
][order(listeners_lastfm, decreasing = TRUE), ]
rm(nonna)
duplicate_all[,
  country_match := as.logical(mapply(
    grepl, 
    country_mb, 
    country_lastfm, 
    ignore.case = TRUE
  ))
]
duplicate_all[is.na(country_match), country_match := FALSE]
duplicate_all <- duplicate_all[order(tags_mb_count, decreasing = TRUE), ]
duplicate_all[, mbduplicate := FALSE]
duplicate_all[!is.na(country_mb) & duplicated(duplicate_all[, .(artist_mb, country_mb)]), mbduplicate := TRUE]
duplicate_all <- duplicate_all[order(listeners_lastfm, decreasing = TRUE), ]
duplicate_all[, tagmax := max(tags_mb_count), by = artist_lastfm]
duplicate_all[, tagmax := (tags_mb_count == tagmax)]
duplicate_all[, .N, by = .(country_match, tagmax)]

match_counts <- duplicate_all[
  mbduplicate == FALSE,
  .(
    country_matches = sum(country_match), 
    tagmax_matches = sum(tagmax), 
    duplicates = .N
  ), 
  by = artist_lastfm
]
duplicate_all <- merge(
  duplicate_all, match_counts, 
  all.x = TRUE, by = 'artist_lastfm'
)[order(listeners_lastfm, decreasing= TRUE), ]
rm(match_counts)

duplicate_all[, true_artist := (
  country_match & 
    tagmax & 
    (country_matches == 1) & 
    (tagmax_matches == 1)
)]
duplicate_all[, true_identified := sum(true_artist), by = artist_lastfm]
duplicate_all[, removal := !true_artist & true_identified]
manual_removal <- c(1328753, 1328754)
removal <- c(duplicate_all[removal == TRUE, orig_index], manual_removal)
ambiguous <- setdiff(duplicate_all[true_identified == 0, orig_index], c(1328752, manual_removal))

lfm[removal, c("artist_lastfm", "listeners_lastfm", "scrobbles_lastfm", "tags_lastfm", "lastfm_by_mbid") := NA]
lfm[, ambiguous_artist := FALSE]
lfm[ambiguous, ambiguous_artist := TRUE]

lfm[,
  c(
    "artist_mb_repeats",
    "artist_mb_unique",
    "received_mbid",
    "tags_mb_count",
    "artist_lastfm_repeats",
    "artist_lastfm_unique",
    "orig_index"
  ) := NULL
]

lfm <- lfm[order(listeners_lastfm, decreasing = TRUE), ]
fwrite(lfm, 'artists.csv')
