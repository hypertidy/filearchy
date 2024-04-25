## we might add args like "res" or profile_extent to snap out to a clean target extent
tile_profile <- function(x = c("mercator", "geodetic", "raster"),
                         extent = NULL, crs = NULL, ...) {
  x <- match.arg(x)
  extent <- switch(x,
                   mercator = c(-1, 1, -1, 1) * 20037508.342789244,
                   geodetic = c(-180, 180, -90, 90),
                   raster = extent)
  crs <- switch(x,
                mercator = "EPSG:3857",
                geodetic = "EPSG:4326",
                raster = crs)
  list(extent = extent, crs = crs, name = x )
}
#' @importFrom graphics text
plot_scheme <- function(x, max = 10000, add = FALSE, label = NULL, ...) {
  if (nrow(x) > max) stop("many many tiles in input > max: %i", max)
  if (!add) {
    ex <- c(min(x$xmin), max(x$xmax), min(x$ymin), max(x$ymax))
    vaster::plot_extent(ex, asp = 1)
  }
  exall <- cbind(x$xmin, x$xmax, x$ymin, x$ymax)
  vaster::plot_extent(exall, add = TRUE)
  if (!is.null(label)) {
    pt <- cbind((x$xmin + x$xmax)/2, (x$ymin+ x$ymax)/2)
    graphics::text(pt, label = x[[label]])
  }
  invisible(NULL)
}
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
#' @param zoom  zooms to render, can be a single number multiple (from 0:23)
#' @param blocksize size of tiles, defaults to 256
#' @param dsn input dataset, file path, VRT string, or any DSN GDAL can open and warp from
#' @param update not implemented (please take care)
#' @param output_dir directory to write to, by default a tempdir is used
#' @param overwrite clobber the output directory, `FALSE` is the default
#' @param dry_run if `TRUE` only the scheme is built and returned as a data frame
#' @param profile domain to use, 'mercator', 'geodetic' (longlat), or 'raster'
#' @param xyz is the zero-row tile to be at the top, then set this `TRUE`
#' @param format 'png' or 'jpeg'
#'
#' @return the tile scheme, invisibly as a dataframe
#' @export
#'
#' @importFrom grout tile_spec tile_zoom
#' @importFrom gdalraster warp
#' @importFrom furrr future_map
#' @importFrom methods new
#' @importFrom PROJ proj_trans
#' @examples
#' dsn <- system.file("extdata/gebco_ovr5.vrt", package = "filearchy", mustWork = TRUE)
#' ## parallelize here
#' #future::plan(multicore)
#' tiles <- gdal_tiles(dsn, dry_run = TRUE)
#' if (!interactive()) unlink(tiles$path)
#' #future::plan(sequential)
gdal_tiles <- function(dsn, zoom = NULL,
                       blocksize = 256L, profile = "mercator",
                       output_dir = tempfile(),
                       overwrite = FALSE,
                       update = FALSE,
                       dry_run = TRUE,
                       xyz = FALSE,
                       format = c("png", "jpeg")) {

  format <- match.arg(format)
  fileext <- switch(format,
                    png = "%i.png",
                    jpeg = "%i.jpg")
  #browser()

  ## below we check if natural zoom to be determined
  if (!is.null(zoom)) {
    zoom <- as.integer(unique(zoom))
    if (anyNA(zoom) || any(zoom < 0) || any(zoom > 24)) stop("unsupported zoom levels, make unique and within 0:23")
  }
  opt <- gdalraster::get_config_option("GDAL_PAM_ENABLED")
  gdalraster::set_config_option("GDAL_PAM_ENABLED", "NO")
  on.exit(gdalraster::set_config_option("GDAL_PAM_ENABLED", opt), add = TRUE)

  if (!dry_run) {
    if (update) { ## ignore overwrite
      if (!file.exists(output_dir)) stop("no update possible, output_dir does not exist")
    } else {
      if (overwrite) {
        unlink(output_dir, recursive = TRUE)
        dir.create(output_dir, showWarnings = FALSE)
      } else {
        if (file.exists(output_dir)) {
          stop("output_dir already exists, delete or set overwrite = TRUE OR update = TRUE")
        }
      }
    }
  }

  ds <- new(gdalraster::GDALRaster, dsn)
  src_dm <- c(ds$getRasterXSize(), ds$getRasterYSize())
  src_ex <- ds$bbox()[c(1, 3, 2, 4)]
  src_res <- diff(src_ex)[c(1, 3)]/src_dm

  src_crs <- ds$getProjection()
  ## dirty hack to scale resolution if we are going from longlat to Mercator
  if (profile == "mercator" && gdalraster::srs_is_geographic(src_crs)) {
    src_res <- src_res * c(1, cos(mean(src_ex[3:4] * pi / 180))) * 111111

  }

  ## src_ex and src_crs are ignored for mercator and geodetic
  profl <- tile_profile(profile, extent = src_ex, crs = src_crs)

  ## target extent and global extent
  tgt_ex <- reproj::reproj_extent(src_ex, profl$crs, source = src_crs)
  gbl_ex <- profl$extent
  tgt_crs <- profl$crs %||% src_crs

  blocksize <- 256

  warp(dsn, tf <- tempfile(tmpdir = "/vsimem", fileext = ".vrt"),
       t_srs = tgt_crs, cl_arg = c("-ts", blocksize, 0), quiet = TRUE)
  base <- new(gdalraster::GDALRaster, tf)

  basesize <- c(base$getRasterXSize(), base$getRasterYSize())

  baseextent <- base$bbox()[c(1, 3, 2, 4)]
  base$close()
  gdalraster::vsi_unlink(tf)
blocksize <- rep(blocksize, length.out = 2L)
  if (is.null(zoom)) {
    ## pick the natural one and do all levels below that

    zoom <- seq(0, grout::tile_zoom(as.integer(diff(baseextent)[c(1, 3)] / src_res),baseextent,
                     blocksize = blocksize, profile = profile))
  }
  baseextent[1] <- max(c(baseextent[1], profl$extent[1]))
  baseextent[2] <- min(c(baseextent[2], profl$extent[2]))
  baseextent[3] <- max(c(baseextent[3], profl$extent[3]))
  baseextent[4] <- min(c(baseextent[4], profl$extent[4]))

  d <- do.call(rbind, lapply(zoom, function(.z) grout::tile_spec(
         dimension = basesize,
         extent  = baseextent,
         zoom = .z,
         blocksize = rep(blocksize, length.out = 2L),
         profile = profile,
         xyz = xyz)))
  d <- tibble::as_tibble(d)
  if (dry_run) return(d)

  d$path <- file.path(output_dir, d$zoom, d$tile_col, sprintf(fileext, d$tile_row))
  jk <- future_map(split(d, 1:nrow(d)), write_tile,
                   dataset = dsn, overwrite = overwrite)
  print(sprintf("tiles in directory: %s", output_dir))


d
}
