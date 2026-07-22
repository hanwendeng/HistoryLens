// In-memory photo store with spatial queries (Haversine) and POI linking.

import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/photo.dart';

class PhotoStore {
  static final List<HistoricalPhoto> _photos = [];

  static List<HistoricalPhoto> get all => List.unmodifiable(_photos);

  static void add(HistoricalPhoto photo) => _photos.add(photo);

  static List<HistoricalPhoto> near(LatLng pos, {double radiusMeters = 100}) {
    final results = <HistoricalPhoto>[];
    for (final p in _photos) {
      if (_haversine(pos, p.location) <= radiusMeters) results.add(p);
    }
    results.sort((a, b) =>
        _haversine(pos, a.location).compareTo(_haversine(pos, b.location)));
    return results;
  }

  static List<HistoricalPhoto> linkedTo(String poiId) =>
      _photos.where((p) => p.linkedPoiId == poiId).toList();

  static void seed(List<HistoricalPhoto> photos) => _photos.addAll(photos);

  static void clear() => _photos.clear();

  static double _haversine(LatLng a, LatLng b) {
    const r = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final sinDLat = sin(dLat / 2);
    final sinDLng = sin(dLng / 2);
    final h = sinDLat * sinDLat +
        cos(_rad(a.latitude)) * cos(_rad(b.latitude)) * sinDLng * sinDLng;
    return 2 * r * atan2(sqrt(h), sqrt(1 - h));
  }

  static double _rad(double deg) => deg * pi / 180;
}
