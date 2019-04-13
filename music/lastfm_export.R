library(curl)
library(data.table)
library(xml2)

# read and necessary transforms
lastfm <- fread("mb_export.csv", encoding = 'UTF-8')
count_names <- lastfm[, .(artist_mb_repeats = .N), by = artist_mb]
count_names[, artist_mb_unique := ifelse(artist_mb_repeats == 1, TRUE, FALSE)]
lastfm <- merge(lastfm, count_names, all.x = TRUE, by = 'artist_mb')
lastfm[, received_mbid := NA_character_]
lastfm[, lastfm_by_mbid := NA]
lastfm[, artist_lastfm := NA_character_]
lastfm[, listeners_lastfm := NA_integer_]
lastfm[, scrobbles_lastfm := NA_integer_]
lastfm[, tags_lastfm := NA_character_]
lastfm[, tags_length := NA_integer_]
lastfm[, tags_lastfm_all := NA_character_]

# helpers for extract
api_root <- "http://ws.audioscrobbler.com/2.0/?method="
api_key <- "23fadd845ffb9a4ece7caeaecd74c94e"

run_batch <- function(url_list, indices, update_data){
  pool <- new_pool()
  for (i in indices) {
    curl_fetch_multi(url_list[i], pool = pool, done = update_data)
  }
  out <- multi_run(pool = pool)
}

# get data
artist_urls <- paste0(
  api_root,
  "artist.getInfo&mbid=",
  lastfm$mbid,
  "&api_key=",
  api_key
)

all_indices <- 1:length(artist_urls)
batches <- split(all_indices, ceiling(seq_along(all_indices) / 100))

add_data <- function(response){
  page_index <- which(artist_urls == response$url)
  content <- rawToChar(response$content)
  Encoding(content) <- 'UTF-8'
  parsed_xml <- read_xml(content)
  status <- xml_attr(xml_find_first(parsed_xml, "..//lfm"), "status")
  if(status == "ok"){
    # lastfm redirect you to different mbid than provided in duplicated artists
    mbid_received <- xml_text(xml_find_first(parsed_xml, ".//artist/mbid"))
    name <- xml_text(xml_find_first(parsed_xml, ".//artist/name"))
    listeners <- as.integer(xml_text(xml_find_first(parsed_xml, ".//listeners")))
    scrobbles <- as.integer(xml_text(xml_find_first(parsed_xml, ".//playcount")))
    tags_vector <- xml_text(xml_find_all(parsed_xml, ".//tag/name"))
    tags_len <- length(tags_vector)
    tags <- paste(tags_vector, collapse = "; ")
    lastfm[
      page_index,
      `:=`(
        received_mbid = mbid_received,
        lastfm_by_mbid = TRUE,
        artist_lastfm = name,
        listeners_lastfm = listeners,
        scrobbles_lastfm = scrobbles,
        tags_lastfm = tags,
        tags_length = tags_len
      )
      ]
  }else{
    lastfm[page_index, lastfm_by_mbid := FALSE]
  }
}

for (i in 1:length(batches)) {
  current_batch <- batches[[i]]
  start <- Sys.time()
  run_batch(url_list = artist_urls, indices = current_batch, update_data = add_data)
  print(sprintf("Run I: Batch %s / %s processed. %s", i, length(batches), (Sys.time() - start)))
  flush.console()
}

# if failed to find by mbid, try by name
# for this to work, artist name must be unique within mb db,
# otherwise last fm api returns wrong mbid artist
# there are multiple names, but only one mbid recorded at last fm
failed_indices <- lastfm[, which(!lastfm_by_mbid & artist_mb_unique)]
artist_urls2 <- paste0(
  api_root,
  "artist.getInfo&artist=",
  sapply(
    lastfm$artist_mb[failed_indices],
    function(x) URLencode(x, reserved = TRUE)
  ),
  "&autocorrect=0&api_key=",
  api_key
)
all_indices2 <- 1:length(artist_urls2)
batches2 <- split(all_indices2, ceiling(seq_along(all_indices2) / 100))
add_data2 <- function(response){
  page_index <- failed_indices[which(artist_urls2 == response$url)]
  content <- rawToChar(response$content)
  Encoding(content) <- 'UTF-8'
  parsed_xml <- read_xml(content)
  status <- xml_attr(xml_find_first(parsed_xml, "..//lfm"), "status")
  if(status == "ok"){
    name <- xml_text(xml_find_first(parsed_xml, ".//artist/name"))
    listeners <- as.integer(xml_text(xml_find_first(parsed_xml, ".//listeners")))
    scrobbles <- as.integer(xml_text(xml_find_first(parsed_xml, ".//playcount")))
    lastfm[
      page_index,
      `:=`(
        artist_lastfm = name,
        listeners_lastfm = listeners,
        scrobbles_lastfm = scrobbles
      )
      ]
  }
}

for (i in 1:length(batches2)) {
  current_batch <- batches2[[i]]
  start <- Sys.time()
  run_batch(url_list = artist_urls2, indices = current_batch, update_data = add_data2)
  print(sprintf("Run II: Batch %s / %s processed. %s", i, length(batches2), (Sys.time() - start)))
  flush.console()
}

# if there are less then 5 in earlier response it means that's everything, no need to call
tag_indices <- lastfm[, which(!is.na(listeners_lastfm) & tags_length == 5)]

artist_urls3 <- lastfm[tag_indices,
  ifelse(
    lastfm_by_mbid,
    paste0(
      api_root,
      "artist.gettoptags&",
      "mbid=",
      mbid,
      "&api_key=",
      api_key
    ),
    paste0(
      api_root,
      "artist.gettoptags&",
      "artist=",
      URLencode(artist_lastfm),
      "&autocorrect=0",
      "&api_key=",
      api_key
    )
  )
]

all_indices3 <- 1:length(artist_urls3)
batches3 <- split(all_indices3, ceiling(seq_along(all_indices3) / 100))
add_data3 <- function(response){
  page_index <- tag_indices[which(artist_urls3 == response$url)]
  content <- rawToChar(response$content)
  Encoding(content) <- 'UTF-8'
  parsed_xml <- read_xml(content)
  status <- xml_attr(xml_find_first(parsed_xml, "..//lfm"), "status")
  if(status == "ok"){
    tags <- paste(xml_text(xml_find_all(parsed_xml, ".//tag/name")), collapse = "; ")
    lastfm[page_index, tags_lastfm_all := tags]
  }
}

for (i in 1:length(batches3)) {
  current_batch <- batches3[[i]]
  start <- Sys.time()
  run_batch(url_list = artist_urls3, indices = current_batch, update_data = add_data3)
  print(sprintf("Run III: Batch %s / %s processed. %s", i, length(batches3), (Sys.time() - start)))
  flush.console()
}

fwrite(lastfm, "lastfm_export.csv")
