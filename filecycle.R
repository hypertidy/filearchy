
dsn <- sds::wms_bluemarble_s3_tms()
vrt <- vapour::vapour_vrt(dsn, overview = 3)
info <- vapour::vapour_raster_info(vrt)
library(grout)
## what level do we go to
block <- 512
library(gdalraster)
nzooms <- 7
l <- vector("list", nzooms)
warp(dsn, tf <- tempfile(tmpdir = "/vsimem", fileext = ".vrt"),
     t_srs = "EPSG:3857", cl_arg = c("-ts", block, 0))
base <- new(GDALRaster, tf)
basesize <- c(base$getRasterXSize(), base$getRasterYSize())
ex <- base$bbox()[c(1, 3, 2, 4)]
for (i in seq_len(nzooms)) {
  isize <- basesize * 2^(i-1)
  print(isize)
  g <-   grout(isize, ex, blocksize = c(block, block))
  ti <- tile_index( g)
  ti$zoom <- i - 1
  ti$crs <- "EPSG:3857"
  ## we have to flip the rows
  ti$tile_col_tms <- ti$tile_col - 1
  ti$tile_row_tms <- g$scheme$ntilesY - ti$tile_row
  ti$path <- file.path(ti$zoom, ti$tile_col_tms, sprintf("%i.png", ti$tile_row_tms))
  l[[i]] <- ti
}

gdalraster::set_config_option("GDAL_PAM_ENABLED", "NO")

write_tile <- function(tile, dataset, basedir = "tiles") {
  path <- file.path(basedir, tile$path)
  if (fs::file_exists(path)) return(NULL)
  fs::dir_create(dirname(path))
  te <- c(tile$xmin, tile$ymin, tile$xmax, tile$ymax)
  gdalraster::warp(dataset, path, t_srs = tile$crs, cl_arg = c("-ts", tile$ncol, tile$nrow, "-te", te))
}

d <- do.call(rbind, l)
library(furrr)
options(parallelly.fork.enable = TRUE, future.rng.onMisuse = "ignore")
plan(multicore)

system.time({jk <- future_map(split(d, 1:nrow(d)), write_tile, dataset = dsn)})
plan(sequential)

str(info)
writeLines(vrt, "dsn1.vrt")
system("gdal2tiles.py dsn1.vrt ovr_g2t")

dsn2 <- sprintf("vrt://%s?ot=Byte&scale=true", sds::gebco())
writeLines(vapour::vapour_vrt(dsn2), "longlat.vrt")
system(sprintf("gdal2tiles.py %s ovr_longlat --processes=24", "longlat.vrt"))

## TODO

## calculate output range
info <- sds::
out_range <- reproj::reproj_extent(info$extent, "EPSG:3857", source = info$project)

##-20037508.342789244, -20037508.342789244, 20037508.342789244, 20037508.342789244
## add resampling option

## add s_srs

## parallel write within a zoom

## flip on xyz (from top)

## tile size

## tile driver

## exclude transparent tiles

## resume (don't rewrite non-missing)

## profile mercator/geodetic/raster

## auto-scaling via VRT


## native tiles are at level
