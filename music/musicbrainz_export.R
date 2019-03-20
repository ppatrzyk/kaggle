library(data.table)
library(R.utils)

# helper function for getting top-level area
get_root <- function(Id, df){
  if(!(Id %in% df$Child)){
    return(Id)
  }else{
    Id <- mb_area_area[Child == Id, Parent][1]
    get_root(Id, df)
  }
}

download.file("https://mirrors.dotsrc.org/MusicBrainz/data/fullexport/20190302-001603/mbdump.tar.bz2", "mbdump.tar.bz2")
download.file("https://mirrors.dotsrc.org/MusicBrainz/data/fullexport/20190302-001603/mbdump-derived.tar.bz2", "mbdump-derived.tar.bz2")
bunzip2("mbdump.tar.bz2")
bunzip2("mbdump-derived.tar.bz2")
untar("mbdump.tar", exdir = "mbdump")
untar("mbdump-derived.tar", exdir = "mbdump-derived")

# read data
mb_artists <- fread("~\\mbdump\\mbdump\\artist", na.strings = "\\N", encoding = 'UTF-8')
mb_area <- fread("~\\mbdump\\mbdump\\area", na.strings = "\\N", encoding = 'UTF-8')
mb_area_area <- fread("~\\mbdump\\mbdump\\l_area_area", na.strings = "\\N", encoding = 'UTF-8')
mb_artist_tag <- fread("~\\mbdump-derived\\mbdump\\artist_tag", na.strings = "\\N", encoding = 'UTF-8')
mb_tag <- fread("~\\mbdump-derived\\mbdump\\tag", na.strings = "\\N", encoding = 'UTF-8')

mb_artists <- mb_artists[, .(ArtistId = V1, mbid = V2, artist = V3, AreaId = V12)]

# merge area info
mb_area <- mb_area[, .(AreaId = V1, Area = V3, Level = V4)]
mb_area_area <- mb_area_area[, .(Parent = V3, Child = V4)]
mb_area <- mb_area[, TopArea := NA_character_]
for (i in 1:mb_area[, .N]) {
  
  top_area_id <- get_root(mb_area[i, AreaId], mb_area_area)
  top_area <- mb_area[AreaId == top_area_id, Area]
  
  set(mb_area, i, 4L,
      top_area
  )
  if(i %% 1000 == 0){
    print(i)
    flush.console()
  }
}
mb_artists <- merge(mb_artists, mb_area[, .(AreaId, TopArea)], by = "AreaId", all.x = TRUE)

# merge taginfo
mb_artist_tag <- merge(mb_artist_tag, mb_tag[, .(V1, tag = V2)], all.x = TRUE, by.x = 'V2', by.y = "V1")
mb_artist_tag2 <- mb_artist_tag[, .(tag = paste(tag, collapse = "; ")), by = V1]
mb_artists <- merge(mb_artists, mb_artist_tag2[, .(ArtistId = V1, tag)], by = "ArtistId", all.x = TRUE)
mb_artists <- mb_artists[, .(mbid, artist_mb = artist, country_mb = TopArea, tags_mb = tag)]
fwrite(mb_artists, "mb_export.csv")