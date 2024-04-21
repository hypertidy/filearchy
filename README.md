
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

``` r
library(filearchy)
#options(parallelly.fork.enable = TRUE, future.rng.onMisuse = "ignore")
#library(future); plan(multicore)
dsn <- sprintf("vrt://%s?ovr=5&ot=Byte&scale=true", "/vsicurl/https://gebco2023.s3.valeria.science/gebco_2023_land_cog.tif")
tiles <- gdal_tiles(dsn)
#> [1] "tiles in directory: /tmp/RtmpdO9jh2/file6c22479521953"
#plan(sequential)
fs::dir_ls(dirname(dirname(dirname(tiles$path[1]))), recurse = TRUE, type = "f")
#> /tmp/RtmpdO9jh2/file6c22479521953/0/0/0.png
#> /tmp/RtmpdO9jh2/file6c22479521953/1/0/0.png
#> /tmp/RtmpdO9jh2/file6c22479521953/1/0/1.png
#> /tmp/RtmpdO9jh2/file6c22479521953/1/1/0.png
#> /tmp/RtmpdO9jh2/file6c22479521953/1/1/1.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/0/0.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/0/1.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/0/2.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/0/3.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/1/0.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/1/1.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/1/2.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/1/3.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/2/0.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/2/1.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/2/2.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/2/3.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/3/0.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/3/1.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/3/2.png
#> /tmp/RtmpdO9jh2/file6c22479521953/2/3/3.png

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
