
<!-- README.md is generated from README.Rmd. Please edit that file -->

# filearchy

<!-- badges: start -->

[![R-CMD-check](https://github.com/hypertidy/filearchy/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/hypertidy/filearchy/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

The goal of filearchy is to generate pyramid tiled image directories.
(Like gdal2tiles.py).

## Installation

You can install the development version of filearchy from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("hypertidy/filearchy")
```

## Example

‘gebco_ovr5.vrt’ is a pre-prepared version of GEBCO 2023 elevation COG
that has been Byte-scaled and reduced to the zoom overview 5

``` r
library(filearchy)
#options(parallelly.fork.enable = TRUE, future.rng.onMisuse = "ignore")
#library(future); plan(multicore)
dsn <- system.file("extdata/gebco_ovr5.vrt", package = "filearchy", mustWork = TRUE)
tiles <- gdal_tiles(dsn)
#> [1] "/vsimem/file71922344929b1.vrt"                                                                 
#> [2] "/perm_storage/home/mdsumner/R/x86_64-pc-linux-gnu-library/4.3/filearchy/extdata/gebco_ovr5.vrt"
#> [1] "tiles in directory: /tmp/RtmpJu1hLW/file71922726e876e"
#plan(sequential)
fs::dir_ls(dirname(dirname(dirname(tiles$path[1]))), recurse = TRUE, type = "f")
#> /tmp/RtmpJu1hLW/file71922726e876e/0/0/0.png
#> /tmp/RtmpJu1hLW/file71922726e876e/1/0/0.png
#> /tmp/RtmpJu1hLW/file71922726e876e/1/0/1.png
#> /tmp/RtmpJu1hLW/file71922726e876e/1/1/0.png
#> /tmp/RtmpJu1hLW/file71922726e876e/1/1/1.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/0/0.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/0/1.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/0/2.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/0/3.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/1/0.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/1/1.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/1/2.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/1/3.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/2/0.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/2/1.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/2/2.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/2/3.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/3/0.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/3/1.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/3/2.png
#> /tmp/RtmpJu1hLW/file71922726e876e/2/3/3.png

gdalraster::createCopy("GTiff", tf <- tempfile(fileext = ".tif"), tiles$path[1])
#> 0...10...20...30...40...50...60...70...80...90...100 - done.

ds <- new(gdalraster::GDALRaster, tf, read_only = FALSE)
## tiles are 256x256 by default
w <- pi *  6378137

ds$setGeoTransform(c(-w, w * 2 / 256, 0, w, 0, -w * 2 / 256))
#> [1] TRUE
gdalraster::plot_raster(ds, bands = 1:3)
#> Warning in graphics::plot.window(xlim = xlim, ylim = ylim, asp = asp, xaxs =
#> xaxs, : "bands" is not a graphical parameter
ds$close()
m <- do.call(cbind, maps::map(plot = F)[1:2])
m[m[,1] > 180, ] <- NA
# library(gdalraster)
# lines(gdalraster::transform_xy(m, srs_to = srs_to_wkt("EPSG:3857"), srs_from = srs_to_wkt("EPSG:4326")))
lines(reproj::reproj_xy(m, "EPSG:3857", source = "EPSG:4326"), col = "firebrick")
```

<img src="man/figures/README-example-1.png" width="100%" />
