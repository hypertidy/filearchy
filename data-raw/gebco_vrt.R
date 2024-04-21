dir.create("inst/extdata")
system(sprintf("gdal_translate %s inst/extdata/gebco_ovr5.vrt",
       sprintf("\"vrt://%s?ovr=5&ot=Byte&scale=true\"", "/vsicurl/https://gebco2023.s3.valeria.science/gebco_2023_land_cog.tif")))

