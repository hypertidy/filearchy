## write one tile, we can parallize this call
write_tile <- function(tile, dataset,  overwrite = FALSE) {
  path <- tile$path
  if (!overwrite) {
    if (fs::file_exists(path)) return(NULL)
  }
  fs::dir_create(dirname(path))
  te <- c(tile$xmin, tile$ymin, tile$xmax, tile$ymax)

  gdalraster::warp(dataset, path, t_srs = tile$crs, cl_arg = c("-ts", tile$ncol, tile$nrow, "-te", te), quiet = TRUE)
}

#' Create tiles, like gdal2tiles.py
#'
#' @param nzoom  number of levels, currently just single number
#' @param blocksize size of tiles, defaults to 256
#' @param t_srs crs of output, defaults to global mercator (use "EPSG:4326" for geodetic/longlat)
#' @param dsn input dataset, file path, VRT string, or any DSN GDAL can open and warp from
#' @param update not implemented (please take care)
#' @param output_dir directory to write to, by default a tempdir is used
#' @param overwrite clobber the output directory, `FALSE` is the default
#' @param dry_run if `TRUE` only the scheme is built and returned as a data frame
#'
#' @return the tile scheme, invisibly as a dataframe
#' @export
#'
#' @importFrom grout grout tile_index
#' @importFrom gdalraster warp
#' @importFrom furrr future_map
#' @importFrom methods new
#' @examples
#' dsn <- system.file("extdata/gebco_ovr5.vrt", package = "filearchy", mustWork = TRUE)
#' ## parallelize here
#' #future::plan(multicore)
#' tiles <- gdal_tiles(dsn)
#' if (!interactive()) unlink(tiles$path)
#' #future::plan(sequential)
gdal_tiles <- function(dsn, nzoom = NULL, blocksize = 256L, t_srs = "EPSG:3857", update = TRUE, output_dir = tempfile(), overwrite = FALSE,
                       dry_run = FALSE) {
 #browser()
   opt <- gdalraster::get_config_option("GDAL_PAM_ENABLED")
  gdalraster::set_config_option("GDAL_PAM_ENABLED", "NO")
  on.exit(gdalraster::set_config_option("GDAL_PAM_ENABLED", opt), add = TRUE)

if (!dry_run) {
  ## put all write-handling in here
  if (!overwrite) {
    if (file.exists(output_dir)) {
     stop("output_dir already exists, delete or set overwrite = TRUE")
    }
  }
  unlink(output_dir, recursive = TRUE)
  dir.create(output_dir, showWarnings = FALSE)
}
  ## we can't get info from gdalraster yet because it will run statistics
  ##info <- vapour::vapour_raster_info(dsn)
  ds <- new(gdalraster::GDALRaster, dsn)
 src_dim <- c(ds$getRasterXSize(), ds$getRasterYSize())
 ds$close()
  nzoom <- nzoom %||% max(which(src_dim[1] / (2^(0:20)) >= blocksize))
  l <- vector("list", nzoom)

  ## first do a warp to the target, our source could be anything
  warp(dsn, tf <- tempfile(tmpdir = "/vsimem", fileext = ".vrt"),
       t_srs = t_srs, cl_arg = c("-ts", blocksize, 0), quiet = TRUE)
  base <- new(gdalraster::GDALRaster, tf)
  basesize <- c(base$getRasterXSize(), base$getRasterYSize())
  ex <- base$bbox()[c(1, 3, 2, 4)]  ## here we have to limit to the global bounds
  ex[3] <- max(c(ex[3], -20037508.342789244))
  ex[4] <- min(c(ex[4], 20037508.342789244))


  base$close()
  ## I'm a bit confused about this still
  gdalraster::vsi_rmdir(dirname(tf))
  ## this would delete our source, so how do we only clean up the vsimem? do we?
  #unlink(filelist)

  for (i in seq_len(nzoom)) {
    isize <- basesize * 2^(i-1)

    g <-   grout(isize, ex, blocksize = c(blocksize, blocksize))
    ti <- tile_index( g)
    ti$zoom <- i - 1
    ti$crs <- t_srs
    ## we have to flip the rows (we need tms vs xyz)
    ti$tile_col_tms <- ti$tile_col - 1
    ti$tile_row_tms <- g$scheme$ntilesY - ti$tile_row

    ti$path <- file.path(output_dir, ti$zoom, ti$tile_col_tms, sprintf("%i.png", ti$tile_row_tms))
    l[[i]] <- ti
  }


  d <- do.call(rbind, l)
 if (dry_run) return(d)

  jk <- future_map(split(d, 1:nrow(d)), write_tile,
                                dataset = dsn, overwrite = overwrite)
  print(sprintf("tiles in directory: %s", output_dir))


  invisible(d)

}
