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
    text(pt, label = x[[label]])
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
gdal_tiles <- function(dsn, zooms = NULL,
                       blocksize = 256L, profile = "mercator",
                       output_dir = tempfile(),
                       overwrite = FALSE,
                       update = FALSE,
                       dry_run = FALSE,
                       xyz = FALSE) {
  #browser()
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

  ds <- new(GDALRaster, dsn)
  src_dm <- c(ds$getRasterXSize(), ds$getRasterYSize())
  src_ex <- ds$bbox()[c(1, 3, 2, 4)]
  src_crs <- ds$getProjection()

  ## src_ex and src_crs are ignored for mercator and geodetic
  profile <- tile_profile(profile, extent = src_ex, crs = src_crs)

  ## target extent and global extent
  tgt_ex <- reproj::reproj_extent(src_ex, profile$crs, source = src_crs)
  gbl_ex <- profile$extent
  tgt_crs <- profile$crs %||% src_crs

  blocksize <- 256

  warp(dsn, tf <- tempfile(tmpdir = "/vsimem", fileext = ".vrt"),
       t_srs = tgt_crs, cl_arg = c("-ts", blocksize, 0), quiet = TRUE)
  base <- new(gdalraster::GDALRaster, tf)
  basesize <- c(base$getRasterXSize(), base$getRasterYSize())
  base$close()
  gdalraster::vsi_unlink(tf)

  res0 <- diff(tgt_ex)[c(1, 3)] / (src_dm * 2)
  xres0 <- res0[1]; yres0 <- res0[2]
  min_ratio <- 8
  l <- list()
  for (nz in 0:22) {
    if (!is.null(zooms) && (!nz %in% zooms)) next;

    dm <- rep(blocksize, 2L) * 2^nz
    xres <- vaster::x_res(dm, gbl_ex)
    yres <- vaster::y_res(dm, gbl_ex)
    a_ex <- vaster::align_extent(tgt_ex, dm %/% blocksize, gbl_ex)
    a_dm <- as.integer(round(diff(a_ex)[c(1, 3)] / c(xres, yres)))

    g <- grout(a_dm, a_ex, rep(blocksize, length.out = 2L))

    if (is.null(zooms) && (xres < xres0 & yres < yres0)) break;

    ntiles <- c(g$scheme$ntilesX, g$scheme$ntilesY)

    res_zoom <- diff(a_ex)[c(1, 3)] / a_dm

    tst <- mean(res_zoom/ res0) < min_ratio
    if (!is.null(zooms)) tst <- TRUE  ## ignore ratio logic and just do what user asked
    if ( tst) {
      ti <- tile_index(g)
      ti$zoom <- nz

      ti$crs <- tgt_crs
      ## we have to flip the rows (we need tms vs xyz)
      ti$tile_col_tms <- ti$tile_col - 1
      if (xyz) {
        ti$tile_row_tms <- g$scheme$ntilesY - ti$tile_row
      } else {
        ti$tile_row_tms <- ti$tile_row - 1
      }

      ti$path <- file.path(output_dir, ti$zoom, ti$tile_col_tms, sprintf("%i.png", ti$tile_row_tms))

      l <- c(l, list(ti))
    }
    l
  }


  d <- do.call(rbind, l)
  if (dry_run) return(d)

  jk <- future_map(split(d, 1:nrow(d)), write_tile,
                   dataset = dsn, overwrite = overwrite)
  print(sprintf("tiles in directory: %s", output_dir))


  invisible(d)

}
