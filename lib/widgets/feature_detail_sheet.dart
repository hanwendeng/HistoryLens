// Bottom sheet for POI details — properties, linked photos, and add photo.

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_feature.dart';
import '../models/photo.dart';
import '../services/photo_store.dart';
import 'photo_gallery.dart';
import 'add_photo_sheet.dart';

class FeatureDetailSheet extends StatefulWidget {
  final MapFeature feature;

  const FeatureDetailSheet({super.key, required this.feature});

  static Future<void> show(BuildContext context, MapFeature feature) {
    return showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FeatureDetailSheet(feature: feature),
    );
  }

  @override
  State<FeatureDetailSheet> createState() => _FeatureDetailSheetState();
}

class _FeatureDetailSheetState extends State<FeatureDetailSheet> {
  List<HistoricalPhoto> _photos = [];

  LatLng get _pos {
    final f = widget.feature;
    if (f.hasPoint) return (f.geometry as PointGeometry).position;
    final poly = f.geometry as PolygonGeometry;
    return poly.outerRing.isNotEmpty
        ? poly.outerRing.first
        : const LatLng(49.0093, 8.4040);
  }

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  void _loadPhotos() {
    final f = widget.feature;
    _photos = [
      ...PhotoStore.linkedTo(f.id),
      ...PhotoStore.near(_pos, radiusMeters: 200)
          .where((p) => p.linkedPoiId != f.id),
    ];
    final seen = <String>{};
    _photos = _photos.where((p) => seen.add(p.id)).toList();
  }

  Future<void> _addPhoto() async {
    final f = widget.feature;
    final photo = await AddPhotoSheet.show(
      context,
      initialLocation: _pos,
      linkedPoiId: f.id,
      linkedPoiName: f.name,
    );
    if (photo != null && mounted) {
      setState(() => _loadPhotos());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(Icons.map, color: Colors.blue, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.feature.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(widget.feature.sourceLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.blue,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _propRow(Icons.pin_drop, 'Coordinates', _fmtLatLng(_pos)),
          if (widget.feature.hasPolygon)
            _propRow(Icons.polyline, 'Vertices',
                '${(widget.feature.geometry as PolygonGeometry).outerRing.length} pts'),

          if (widget.feature.properties.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Divider(),
            ...widget.feature.properties.entries.take(6).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(e.key,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                      ),
                      Expanded(
                        child: Text(e.value,
                            style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                )),
          ],

          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 8),

          PhotoGallery(photos: _photos),

          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: _addPhoto,
            icon: const Icon(Icons.add_a_photo, size: 16),
            label: const Text('Add Photo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(38),
            ),
          ),
        ],
      ),
    );
  }

  Widget _propRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  static String _fmtLatLng(LatLng p) =>
      '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
}
