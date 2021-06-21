---
layout: post
title: "Mapbox: Art and Science of Vector Maps"
date: 2021-01-10
slug: mapbox-server-side-clustering
draft: true

resources:
- src: "*.png"
- src: "*.jpg"

keywords: [ mapbox, postgis, database ]
---

This is a series of blog posts which covers the art and the science of vector maps. This post serves as an introduction.


## What are Vector Maps?

You probably have already seen plenty of maps on the web.
If you see an map embedded into some website the chances are high that it is uses [OpenStreetMap](https://www.openstreetmap.org).
The default way to view OSM (OpenStreetMaps) uses raster images. That means the OSM servers serve static images for your current viewport.
These images are usually PNG files.

If you browser Google Maps or Apple Maps in 2021 you are not downloading static images. Instead your browser is rendering vector tiles, which contain the geographic data of a specific region. These tiles contain geometries like lines, points or polygons.
This offers a lot of benefits for users, like dynamic styling of the geometries, allow rendering of 3D buildings or changing the view angle.

From the technical side an advantage is that Google or Apple does not have to render and update PNG files for every map style. They only have to provide the geographic information and the client renders it in real-time.

{{< resourceFigure "vector-tile-example.png" "Visualisation of a Vector Tile. " 500 >}}
Visualization of a Vector Tile. [Mapzen CC-BY-4.0](https://github.com/tilezen/vector-datasource/blob/master/docs/LICENSE-DOCS.md)
{{< /resourceFigure >}}

This gives clients and users a lot of freedom in styling and rendering their map! Also they feel very smooth as it is easy to interpolate information when using vector graphics.
Now, how can we utilize this freedom and power to create great map experiences? We will focus on the Mapbox and [MapLibre](https://github.com/maplibre) Stack. MapLibre is the Free and Open Source fork which should be used if you want to stay a way from the Mapbox Cloud offers.

## Science and Art


```json
{
    "version": 8,
    "name": "My Map Style",
    # The Science!
    "sources": {...},     
    # The Art!                                           
    "sprite": "https://example.net/sprites",
    "glyphs": "https://example.net/font-glyphs/{fontstack}/{range}.pbf",
    "layers": [...]    
}
```

## Science

### Definition of Sources

`{z}/{x}/{y}` format

### Example Sources

* Natural Earth
* OpenMapTiles
* Own Data Sets using PostGIS
  * Martin 
  * https://tegola.io/

### Vector Tile Formats

#### GeoJSON

https://geojson.org/

#### MVT

Explain ProtocolBuffers

https://github.com/mapbox/vector-tile-spec


### MBTiles

Serving tiles using only Nginx:

* https://github.com/mapbox/mbutil
* Block Size of file systems

### Create a Map of Germany within ... days?

https://download.geofabrik.de/europe/germany.html (.osm.xml vs .osm.pbf)
https://openmaptiles.org/

### Converting Tiles

`ogr2ogr -progress -f "GeoJSON" output.json test.pbf`


### Server-side clustering using PostGIS




## Art

https://maputnik.github.io/

### Definition of Layers

### Definition of Glyphs

### Definition of Sprites



