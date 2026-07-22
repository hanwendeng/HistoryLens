# History Lens — Karlsruhe Historical Photo Map

KIT Mobile GIS & LBS course project — Group 5. Tap any location on the map
to discover historical photos and background stories of Karlsruhe.

## Features

- GPS location (device sensor) — green dot on map
- OSM basemap via XYZ raster tiles
- Historic places from GeoServer WFS (GetFeature, CQL filter)
- Six real historical photos from LEO-BW and DDB archives
- Crowdsourcing: add a photo → upload to Cloudinary → WFS-T Insert metadata
- Timeline slider to filter photos by decade
- Near Me — spatial proximity filter with adjustable radius (100–1000m)
- WFS-T Insert — write photo metadata to the shared GeoServer layer

## Project structure

```
lib/
├── main.dart                     Entry point
├── app.dart                      MaterialApp + theme
├── config/
│   └── constants.dart            API URLs, map defaults, app metadata
├── models/
│   ├── map_feature.dart          Unified feature model (point & polygon)
│   └── photo.dart                HistoricalPhoto model
├── services/
│   ├── location_service.dart     GPS with permission handling
│   ├── wfs_service.dart          GeoServer WFS & WFS-T client
│   └── photo_store.dart          In-memory photo registry with spatial queries
├── screens/
│   └── home_screen.dart          Main map screen with all layers
└── widgets/
    ├── add_photo_sheet.dart      Camera/gallery picker + mini-map + metadata form
    ├── feature_detail_sheet.dart  POI detail + linked photos + properties
    ├── photo_gallery.dart         Horizontal scrolling photo cards
    └── timeline_bar.dart          Decade slider to filter photos
```

## Data flow

```
Device GPS       → LocationService → LatLng → green dot marker
GeoServer WFS    → WfsService      → List<MapFeature> → blue markers + polygons
GeoServer WFS    → WfsService      → List<HistoricalPhoto> → brown photo markers
OSM Tiles        → TileLayer (XYZ raster)
User camera      → Cloudinary      → image URL → WFS-T Insert (metadata) → live on server
```

## Requirements

Flutter SDK, iOS Simulator.

## OGC standards covered

- WFS 2.0 (Web Feature Service) — GeoServer, GetFeature with CQL filter, GeoJSON output
- WFS-T — Insert via XML transaction requests
- XYZ Tiles — OSM raster basemap
---

KIT · Mobile GIS & LBS · Summer Semester 2026
