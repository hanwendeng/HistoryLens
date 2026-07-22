// Historical photo with location, metadata, and decade grouping.

import 'package:latlong2/latlong.dart';

class HistoricalPhoto {
  final String id;
  final String title;
  final String? description;
  final DateTime? dateTaken;
  final String source;
  final String? sourceUrl;
  final LatLng location;
  final String imageUrl;
  final String? photographer;
  final String? streetAddress;
  final String? linkedPoiId;

  const HistoricalPhoto({
    required this.id,
    required this.title,
    this.description,
    this.dateTaken,
    required this.source,
    this.sourceUrl,
    required this.location,
    required this.imageUrl,
    this.photographer,
    this.streetAddress,
    this.linkedPoiId,
  });

  String get dateLabel {
    if (dateTaken == null) return 'Unknown date';
    final y = dateTaken!.year;
    final m = dateTaken!.month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  int? get decade {
    if (dateTaken == null) return null;
    return dateTaken!.year ~/ 10 * 10;
  }
}
