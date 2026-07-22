// Main map screen — GPS, WFS layers, photo markers, timeline, and Near Me.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/constants.dart';
import '../models/map_feature.dart';
import '../models/photo.dart';
import '../services/location_service.dart';
import '../services/photo_store.dart';
import '../services/wfs_service.dart';
import '../widgets/feature_detail_sheet.dart';
import '../widgets/add_photo_sheet.dart';
import '../widgets/timeline_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _mapController = MapController();

  LatLng? _userLocation;
  List<MapFeature> _wfsFeatures = [];

  bool _showWfs = true;

  bool _loading = true;
  String _loadingMsg = 'Locating...';

  int _photoCount = 0;
  int? _selectedDecade;
  double? _nearMeRadius; // null = off, value = radius 100–1000m

  @override
  void initState() {
    super.initState();
    _photoCount = 0;
    _initAll();
  }

  Future<void> _initAll() async {
    await _fetchLocation();
    await _fetchWfs();
    await _fetchPhotos();
    if (mounted) {
      setState(() => _loading = false);
      _showSnack('Ready — ${_wfsFeatures.length} historic places, '
          '$_photoCount historical photos');
    }
  }

  Future<void> _fetchLocation() async {
    try {
      final pos = await LocationService.getCurrentLocation();
      if (mounted) setState(() => _userLocation = pos);
    } catch (_) {
      if (mounted) setState(() => _loadingMsg = 'GPS unavailable');
    }
  }

  Future<void> _fetchWfs() async {
    try {
      final features = await WfsService.fetchHistoricPlaces();
      if (mounted) setState(() => _wfsFeatures = features);
    } catch (_) {}
  }

  Future<void> _fetchPhotos() async {
    try {
      final photos = await WfsService.fetchPhotos();
      PhotoStore.clear();
      PhotoStore.seed(photos);
      if (mounted) setState(() => _photoCount = photos.length);
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMsg = 'Photos unavailable');
      }
    }
  }

  List<HistoricalPhoto> get _filteredPhotos {
    var photos = PhotoStore.all;
    if (_nearMeRadius != null && _userLocation != null) {
      photos = PhotoStore.near(_userLocation!, radiusMeters: _nearMeRadius!);
    }
    if (_selectedDecade != null) {
      photos = photos.where((p) => p.decade == _selectedDecade).toList();
    }
    return photos;
  }

  int _photosForPoi(String poiId) {
    return _filteredPhotos.where((p) => p.linkedPoiId == poiId).length;
  }

  int _photosNear(LatLng pos) {
    final nearbyIds =
        PhotoStore.near(pos, radiusMeters: 50).map((p) => p.id).toSet();
    return _filteredPhotos.where((p) => nearbyIds.contains(p.id)).length;
  }

  void _toggleNearMe() {
    if (_userLocation == null) {
      _showSnack('GPS location not available');
      return;
    }
    setState(() => _nearMeRadius = _nearMeRadius == null ? 500.0 : null);
  }

  Future<void> _addPhoto({MapFeature? linkedPoi}) async {
    final centre = _mapController.camera.center;
    final photo = await AddPhotoSheet.show(
      context,
      initialLocation: linkedPoi?.hasPoint == true
          ? (linkedPoi!.geometry as PointGeometry).position
          : centre,
      linkedPoiId: linkedPoi?.id,
      linkedPoiName: linkedPoi?.name,
    );
    if (photo != null && mounted) {
      setState(() => _photoCount = PhotoStore.all.length);
      _showSnack('Photo added: ${photo.title}');
    }
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 16.0);
    }
  }

  void _onFeatureTap(MapFeature feature) {
    FeatureDetailSheet.show(context, feature);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<Marker> _photoMarkers() {
    final seen = <String>{};
    final markers = <Marker>[];
    final filtered = _filteredPhotos;
    for (final photo in filtered) {
      if (photo.linkedPoiId != null &&
          _wfsFeatures.any((f) => f.id == photo.linkedPoiId)) {
        continue;
      }
      final key = '${photo.location.latitude.toStringAsFixed(5)}_'
          '${photo.location.longitude.toStringAsFixed(5)}';
      if (seen.add(key)) {
        final count = _photosNear(photo.location);
        markers.add(Marker(
          point: photo.location,
          width: 28,
          height: 28,
          child: GestureDetector(
            onTap: () {
              final filteredIds =
                  _filteredPhotos.map((p) => p.id).toSet();
              final photos = PhotoStore.near(photo.location)
                  .where((p) => filteredIds.contains(p.id))
                  .toList();
              if (photos.isNotEmpty) _showPhotoPreview(photos);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.camera_alt,
                    color: Colors.brown, size: 20),
                if (count > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('$count',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 8)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ));
      }
    }
    return markers;
  }

  void _showPhotoPreview(List<HistoricalPhoto> photos) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _PhotoPreviewSheet(photos: photos),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History Lens'),
        backgroundColor:
            Theme.of(context).colorScheme.primaryContainer,
        actions: [
          if (_userLocation != null)
            IconButton(
              icon: const Icon(Icons.my_location),
              tooltip: 'My location',
              onPressed: _centerOnUser,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: defaultCenter,
                    initialZoom: defaultZoom,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: osmTileUrl,
                      userAgentPackageName: appPackageName,
                    ),

                    if (_nearMeRadius != null &&
                        _userLocation != null &&
                        !_loading)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: _circlePoints(
                                _userLocation!, _nearMeRadius!),
                            color: const Color(kitGreen).withAlpha(60),
                            borderStrokeWidth: 1.5,
                            borderColor: const Color(kitGreen),
                          ),
                        ],
                      ),

                    if (_showWfs)
                      MarkerLayer(
                        markers:
                            _wfsFeatures.where((f) => f.hasPoint).map((f) {
                          final pos =
                              (f.geometry as PointGeometry).position;
                          final count =
                              _photosForPoi(f.id) + _photosNear(pos);
                          final hasPhotos = count > 0;
                          return Marker(
                            point: pos,
                            width: 30,
                            height: 30,
                            child: GestureDetector(
                              onTap: () => _onFeatureTap(f),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    hasPhotos
                                        ? Icons.camera_alt
                                        : Icons.location_on,
                                    color: hasPhotos
                                        ? Colors.brown
                                        : Colors.blue,
                                    size: hasPhotos ? 20 : 22,
                                    shadows: hasPhotos
                                        ? null
                                        : const [
                                            Shadow(
                                                color: Colors.black38,
                                                blurRadius: 2)
                                          ],
                                  ),
                                  if (hasPhotos)
                                    Positioned(
                                      top: 2,
                                      right: 4,
                                      child: Container(
                                        width: 15,
                                        height: 15,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            count > 9 ? '9+' : '$count',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight:
                                                    FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                    if (_showWfs)
                      PolygonLayer(
                        polygons: _wfsFeatures
                            .where((f) => f.hasPolygon)
                            .map((f) {
                          final poly = f.geometry as PolygonGeometry;
                          return Polygon(
                            points: poly.outerRing,
                            holePointsList: poly.holes,
                            color: Colors.blue.withAlpha(20),
                            borderStrokeWidth: 2,
                            borderColor: Colors.blue,
                          );
                        }).toList(),
                      ),

                    MarkerLayer(markers: _photoMarkers()),

                    if (_userLocation != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: _userLocation!,
                          width: 36,
                          height: 36,
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  const Color(kitGreen).withAlpha(35),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(kitGreen),
                                  width: 2.5),
                            ),
                            child: const Center(
                              child: Icon(Icons.circle,
                                  size: 10, color: Color(kitGreen)),
                            ),
                          ),
                        ),
                      ]),
                  ],
                ),

                if (_loading)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Text(_loadingMsg,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  left: 10,
                  top: 10,
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withAlpha(230),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _legendRow(Colors.blue, 'Historic place'),
                          const SizedBox(height: 3),
                          _legendRow(Colors.brown, 'Photo'),
                          const SizedBox(height: 3),
                          _legendRow(const Color(kitGreen), 'You'),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  right: 10,
                  top: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _layerChip(
                        selected: _showWfs,
                        icon: Icons.map,
                        label: 'Historic Points',
                        onTap: () =>
                            setState(() => _showWfs = !_showWfs),
                      ),
                      const SizedBox(height: 4),
                      if (_userLocation != null)
                        _layerChip(
                          selected: _nearMeRadius != null,
                          icon: Icons.near_me,
                          label: _nearMeRadius != null
                              ? '${_nearMeRadius!.toInt()}m'
                              : 'Near Me',
                          onTap: _toggleNearMe,
                        ),
                    ],
                  ),
                ),

                Positioned(
                  right: 10,
                  bottom: 100,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _zoomButton(Icons.add, () {
                        final c = _mapController.camera;
                        _mapController.move(c.center, c.zoom + 1);
                      }),
                      const SizedBox(height: 2),
                      _zoomButton(Icons.remove, () {
                        final c = _mapController.camera;
                        _mapController.move(c.center, c.zoom - 1);
                      }),
                    ],
                  ),
                ),

                Positioned(
                  right: 6,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('© OSM',
                        style: TextStyle(
                            fontSize: 10, color: Colors.black45)),
                  ),
                ),
              ],
            ),
          ),
          if (_nearMeRadius != null)
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(235),
                border:
                    const Border(top: BorderSide(color: Color(0x20000000))),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.near_me, size: 16, color: Colors.brown),
                  const SizedBox(width: 6),
                  Text('${_nearMeRadius!.toInt()}m',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: Colors.brown,
                        inactiveTrackColor: Colors.brown.shade100,
                        thumbColor: Colors.brown,
                        overlayColor: Colors.brown.withAlpha(30),
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8),
                        showValueIndicator: ShowValueIndicator.never,
                      ),
                      child: Slider(
                        value: _nearMeRadius!,
                        min: 100,
                        max: 1000,
                        divisions: 9,
                        onChanged: (v) =>
                            setState(() => _nearMeRadius = v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          TimelineBar(
            selectedDecade: _selectedDecade,
            totalPhotos: PhotoStore.all.length,
            onDecadeChanged: (decade) =>
                setState(() => _selectedDecade = decade),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'add_photo',
        onPressed: () => _addPhoto(),
        tooltip: 'Add historical photo',
        backgroundColor: Colors.brown,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }

  Widget _legendRow(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }

  Widget _layerChip({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: selected ? Colors.white : Colors.white.withAlpha(200),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? Colors.black87 : Colors.grey),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? Colors.black87 : Colors.grey,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  List<LatLng> _circlePoints(LatLng center, double radiusMeters) {
    const n = 64;
    const dist = Distance();
    final pts = <LatLng>[];
    for (int i = 0; i < n; i++) {
      final bearing = 360.0 * i / n;
      pts.add(dist.offset(center, radiusMeters, bearing));
    }
    return pts;
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(6),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: 20, color: Colors.black87),
        ),
      ),
    );
  }
}

class _PhotoPreviewSheet extends StatefulWidget {
  final List<HistoricalPhoto> photos;
  const _PhotoPreviewSheet({required this.photos});

  @override
  State<_PhotoPreviewSheet> createState() => _PhotoPreviewSheetState();
}

class _PhotoPreviewSheetState extends State<_PhotoPreviewSheet> {
  int _index = 0;

  HistoricalPhoto get _photo => widget.photos[_index];

  void _prev() {
    if (_index > 0) setState(() => _index--);
  }

  void _next() {
    if (_index < widget.photos.length - 1) setState(() => _index++);
  }

  Widget _buildImage(String url, double height) {
    final fallback = Container(
      height: height,
      color: Colors.grey.shade200,
      child: const Center(
          child:
              Icon(Icons.broken_image, color: Colors.grey, size: 40)),
    );
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(url,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback);
    }
    if (url.startsWith('/') || url.startsWith('file://')) {
      return Image.file(File(url.replaceFirst('file://', '')),
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback);
    }
    return Image.asset(url,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _index > 0 ? _prev : null,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  widget.photos.length > 1
                      ? '${_index + 1} / ${widget.photos.length}'
                      : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed:
                    _index < widget.photos.length - 1 ? _next : null,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Text(_photo.title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          if (_photo.description != null) ...[
            const SizedBox(height: 6),
            Text(_photo.description!,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black87)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _chip(_photo.dateLabel),
              const SizedBox(width: 8),
              _chip(_photo.source),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImage(_photo.imageUrl, 220),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}
