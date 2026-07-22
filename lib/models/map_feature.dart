// Data model for map features — points and polygons.

import 'package:latlong2/latlong.dart';

class MapFeature {
  final String id;
  final String name;
  final FeatureSource source;
  final FeatureGeometry geometry;
  final Map<String, String> properties;

  const MapFeature({
    required this.id,
    required this.name,
    required this.source,
    required this.geometry,
    this.properties = const {},
  });

  String get sourceLabel => 'GeoServer WFS';

  bool get hasPoint => geometry is PointGeometry;

  bool get hasPolygon => geometry is PolygonGeometry;

  @override
  String toString() => 'MapFeature($id, $name, $source)';
}

enum FeatureSource { wfs }

sealed class FeatureGeometry {
  const FeatureGeometry();
}

class PointGeometry extends FeatureGeometry {
  final LatLng position;
  const PointGeometry(this.position);
}

class PolygonGeometry extends FeatureGeometry {
  final List<LatLng> outerRing;
  final List<List<LatLng>> holes;

  const PolygonGeometry({required this.outerRing, this.holes = const []});
}
