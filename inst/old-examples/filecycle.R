
# dsn <- sds::wms_bluemarble_s3_tms()
# vrt <- vapour::vapour_vrt(dsn, overview = 3)

gebco <- "/vsicurl/https://gebco2023.s3.valeria.science/gebco_2023_land_cog.tif"
## max is ovr=7
dsn <- sprintf("vrt://%s?ovr=4&scale=true&ot=Byte", gebco)
ds <- new(gdalraster::GDALRaster, dsn)
ds$getPaletteInterp(1)

## set a palette (we might map value prior to scaling here)
coltab <- cbind(0:255, t(col2rgb(hcl.colors(256))))
ds$setColorTable(1, coltab, "RGB")




library(grout)
## what level do we go to
block <- 512
library(gdalraster)


#
# str(info)
# writeLines(vrt, "dsn1.vrt")
# system("gdal2tiles.py dsn1.vrt ovr_g2t")
#
# dsn2 <- sprintf("vrt://%s?ot=Byte&scale=true", sds::gebco())
# writeLines(vapour::vapour_vrt(dsn2), "longlat.vrt")
# system(sprintf("gdal2tiles.py %s ovr_longlat --processes=24", "longlat.vrt"))
#
# ## TODO
#
# ## calculate output range
# info <- sds::
# out_range <- reproj::reproj_extent(info$extent, "EPSG:3857", source = info$project)

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
