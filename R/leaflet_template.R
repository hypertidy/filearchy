write_leaflet_html <- function(dsn,  minmaxzoom, beginzoom = minmaxzoom[1], path, tileformat = c("png", "jpeg", "jpg"), tms = TRUE,
                               title =  "my tiled raster",
                               copyright = "ourstuff") {
  leaflet_template <- .leaflet_template()
  tosubs <- .to_subs() ## what strings must we gsub, list follows

  ## use the source to determine our longlat extent for the HTML
  info <- vapour::vapour_raster_info(dsn)
  llex <- reproj::reproj_extent(info$extent, "EPSG:4326", source = info$projection)

 if (!nzchar(title)) {
   if (!nzchar(info$filelist[1])) {
     title <- "title for image tiles"
   }
 }
  #title <- "my tiled raster"
  minzoom <- minmaxzoom[1]
  maxzoom <- minmaxzoom[2]
  tileformat <- match.arg(tileformat)
  if (tileformat == "jpeg") tileformat <- "jpg"
  tms <- as.integer(tms)   ## or xyz, 0 presumably
  #copyright <- "our stuff"
  centerlon <- sprintf("%01f", mean(llex[1:2]))
  centerlat <- sprintf("%01f", mean(llex[3:4]))


  double_quote_escaped_title <- title  ## FIXME
  south <- llex[3]
  east <- llex[2]
  north <- llex[4]
  west <- llex[1]

  values <- c(title, minzoom, maxzoom, tileformat, tms, copyright, centerlon, centerlat,
              beginzoom, double_quote_escaped_title,
              south, east, north, west)

  for (i in seq_along(tosubs)) {
    leaflet_template <- gsub(tosubs[i], values[i], leaflet_template)
  }
  writeLines(leaflet_template, path)
  invisible(path)
}








## leaflet template from gdal2tiles.py copyright   2008 Klokan Petr Pridal
.leaflet_template <- function() r"(<!DOCTYPE html>
        <html lang="en">
          <head>
            <meta charset="utf-8">
            <meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no' />
            <title>%(xml_escaped_title)s</title>

            <!-- Leaflet -->
            <link rel="stylesheet" href="https://unpkg.com/leaflet@0.7.5/dist/leaflet.css" />
            <script src="https://unpkg.com/leaflet@0.7.5/dist/leaflet.js"></script>

            <style>
                body { margin:0; padding:0; }
                body, table, tr, td, th, div, h1, h2, input { font-family: "Calibri", "Trebuchet MS", "Ubuntu", Serif; font-size: 11pt; }
                #map { position:absolute; top:0; bottom:0; width:100%; } /* full size */
                .ctl {
                    padding: 2px 10px 2px 10px;
                    background: white;
                    background: rgba(255,255,255,0.9);
                    box-shadow: 0 0 15px rgba(0,0,0,0.2);
                    border-radius: 5px;
                    text-align: right;
                }
                .title {
                    font-size: 18pt;
                    font-weight: bold;
                }
                .src {
                    font-size: 10pt;
                }

            </style>

        </head>
        <body>

        <div id="map"></div>

        <script>
        /* **** Leaflet **** */

        // Base layers
        //  .. OpenStreetMap
        var osm = L.tileLayer('http://{s}.tile.osm.org/{z}/{x}/{y}.png', {attribution: '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors', minZoom: %(minzoom)s, maxZoom: %(maxzoom)s});

        //  .. CartoDB Positron
        var cartodb = L.tileLayer('http://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png', {attribution: '&copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors, &copy; <a href="http://cartodb.com/attributions">CartoDB</a>', minZoom: %(minzoom)s, maxZoom: %(maxzoom)s});

        //  .. OSM Toner
        var toner = L.tileLayer('http://{s}.tile.stamen.com/toner/{z}/{x}/{y}.png', {attribution: 'Map tiles by <a href="http://stamen.com">Stamen Design</a>, under <a href="http://creativecommons.org/licenses/by/3.0">CC BY 3.0</a>. Data by <a href="http://openstreetmap.org">OpenStreetMap</a>, under <a href="http://www.openstreetmap.org/copyright">ODbL</a>.', minZoom: %(minzoom)s, maxZoom: %(maxzoom)s});

        //  .. White background
        var white = L.tileLayer("data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAQAAAAEAAQMAAABmvDolAAAAA1BMVEX///+nxBvIAAAAH0lEQVQYGe3BAQ0AAADCIPunfg43YAAAAAAAAAAA5wIhAAAB9aK9BAAAAABJRU5ErkJggg==", {minZoom: %(minzoom)s, maxZoom: %(maxzoom)s});

        // Overlay layers (TMS)
        var lyr = L.tileLayer('./{z}/{x}/{y}.%(tileformat)s', {tms: %(tms)s, opacity: 0.7, attribution: "%(copyright)s", minZoom: %(minzoom)s, maxZoom: %(maxzoom)s});

        // Map
        var map = L.map('map', {
            center: [%(centerlon)s, %(centerlat)s],
            zoom: %(beginzoom)s,
            minZoom: %(minzoom)s,
            maxZoom: %(maxzoom)s,
            layers: [osm, lyr]
        });

        var basemaps = {"OpenStreetMap": osm, "CartoDB Positron": cartodb, "Stamen Toner": toner, "Without background": white}
        var overlaymaps = {"Layer": lyr}

        // Title
        var title = L.control();
        title.onAdd = function(map) {
            this._div = L.DomUtil.create('div', 'ctl title');
            this.update();
            return this._div;
        };
        title.update = function(props) {
            this._div.innerHTML = "%(double_quote_escaped_title)s";
        };
        title.addTo(map);

        // Note
        var src = 'Generated by <a href="https://github.com/hypertidy/filearchy">filearchy</a>, GDAL, and gdal2tiles leaflet template, Copyright &copy; 2008 <a href="http://www.klokan.cz/">Klokan Petr Pridal</a>,  <a href="https://gdal.org">GDAL</a> &amp; <a href="http://www.osgeo.org/">OSGeo</a> <a href="http://code.google.com/soc/">GSoC</a>';
        var title = L.control({position: 'bottomleft'});
        title.onAdd = function(map) {
            this._div = L.DomUtil.create('div', 'ctl src');
            this.update();
            return this._div;
        };
        title.update = function(props) {
            this._div.innerHTML = src;
        };
        title.addTo(map);


        // Add base layers
        L.control.layers(basemaps, overlaymaps, {collapsed: false}).addTo(map);

        // Fit to overlay bounds (SE and NW points with (lat, lon))
        map.fitBounds([[%(south)s, %(east)s], [%(north)s, %(west)s]]);

        </script>

        </body>
        </html>

)"

.to_subs <- function() c("%\\(xml_escaped_title\\)s", "%\\(minzoom\\)s", "%\\(maxzoom\\)s",
                         "%\\(tileformat\\)s", "%\\(tms\\)s", "%\\(copyright\\)s", "%\\(centerlon\\)s",
                         "%\\(centerlat\\)s", "%\\(beginzoom\\)s", "%\\(double_quote_escaped_title\\)s",
                         "%\\(south\\)s", "%\\(east\\)s", "%\\(north\\)s", "%\\(west\\)s"
)
# .to_subs <- function() { read.table(text = "
# %\\(xml_escaped_title\\)s
# %\\(minzoom\\)s
# %\\(maxzoom\\)s
# %\\(tileformat\\)s
# %\\(tms\\)s
# %\\(copyright\\)s
# %\\(centerlon\\)s
# %\\(centerlat\\)s
# %\\(beginzoom\\)s
# %\\(double_quote_escaped_title\\)s
# %\\(south\\)s
# %\\(east\\)s
# %\\(north\\)s
# %\\(west\\)s")[[1]]
#
# }
