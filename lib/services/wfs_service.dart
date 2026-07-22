// WFS and WFS-T client for the GeoServer — GetFeature, Insert, Update, Delete.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../config/constants.dart';
import '../models/map_feature.dart';
import '../models/photo.dart';

class WfsService {
  static Future<List<MapFeature>> fetchHistoricPlaces() async {
    final query = {
      'service': 'WFS',
      'version': '2.0.0',
      'request': 'GetFeature',
      'typeNames': wfsTypeName,
      'CQL_FILTER': 'historic IS NOT NULL',
      'outputFormat': 'application/json',
      'srsName': 'urn:ogc:def:crs:EPSG::4326',
    };

    final uri = Uri.https(wfsBaseUrl, wfsPath, query);

    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw WfsException('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final features = <MapFeature>[];
    final featureList = (data['features'] as List<dynamic>?) ?? [];

    for (int i = 0; i < featureList.length; i++) {
      final f = featureList[i];
      final rawProps = (f['properties'] as Map<String, dynamic>?) ?? {};
      final geom = f['geometry'] as Map<String, dynamic>?;
      if (geom == null) continue;

      final props = <String, String>{};
      rawProps.forEach((k, v) {
        if (v != null) props[k] = v.toString();
      });

      final name = props['name'] ?? props['historic'] ?? 'historic site';

      final feature = _parseFeature(
        id: (f['id'] as String?) ?? 'wfs-$i',
        name: name,
        props: props,
        geom: geom,
      );

      if (feature != null) features.add(feature);
    }

    return features;
  }

  static const _nsUri = 'mobilegis';
  static const _transactionPath = '/geoserver/wfs';

  static Future<List<HistoricalPhoto>> fetchPhotos() async {
    final query = {
      'service': 'WFS',
      'version': '2.0.0',
      'request': 'GetFeature',
      'typeNames': photoTypeName,
      'outputFormat': 'application/json',
      'srsName': 'urn:ogc:def:crs:EPSG::4326',
    };

    final uri = Uri.https(wfsBaseUrl, photoWfsPath, query);

    final response = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw WfsException('Fetch photos failed: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final photos = <HistoricalPhoto>[];
    final featureList = (data['features'] as List<dynamic>?) ?? [];

    for (final f in featureList) {
      final props = (f['properties'] as Map<String, dynamic>?) ?? {};
      final geom = f['geometry'] as Map<String, dynamic>?;
      if (geom == null) continue;

      final coords = geom['coordinates'] as List<dynamic>?;
      if (coords == null || coords.length < 2) continue;

      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();

      String rawImageUrl = props['image_url']?.toString() ?? '';
      final imageUrl = rawImageUrl.startsWith('http')
          ? rawImageUrl
          : '$imageBaseUrl$rawImageUrl';

      final photo = HistoricalPhoto(
        id: (f['id'] as String?) ?? '',
        title: props['title']?.toString() ?? 'Untitled',
        description: props['description']?.toString(),
        dateTaken: _parseDate(props['date_taken']?.toString()),
        source: props['source']?.toString() ?? 'Unknown',
        sourceUrl: props['source_url']?.toString(),
        location: LatLng(lat, lon),
        imageUrl: imageUrl,
        photographer: props['photographer']?.toString(),
        streetAddress: props['street_addr']?.toString(),
        linkedPoiId: props['linked_poi']?.toString(),
      );

      photos.add(photo);
    }

    return photos;
  }

  static Future<String> insertPhoto({
    required String title,
    required String imageUrl,
    required LatLng location,
    String? description,
    String? dateTaken,
    String? source,
    String? sourceUrl,
    String? photographer,
    String? streetAddress,
    String? linkedPoiId,
  }) async {
    final props = _buildXmlProps({
      'title': title,
      'image_url': imageUrl,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (dateTaken != null && dateTaken.isNotEmpty) 'date_taken': dateTaken,
      if (source != null && source.isNotEmpty) 'source': source,
      if (sourceUrl != null && sourceUrl.isNotEmpty) 'source_url': sourceUrl,
      if (photographer != null && photographer.isNotEmpty)
        'photographer': photographer,
      if (streetAddress != null && streetAddress.isNotEmpty)
        'street_addr': streetAddress,
      if (linkedPoiId != null && linkedPoiId.isNotEmpty)
        'linked_poi': linkedPoiId,
    });

    final body = '''
<wfs:Transaction
    service="WFS"
    version="2.0.0"
    xmlns:wfs="http://www.opengis.net/wfs/2.0"
    xmlns:gml="http://www.opengis.net/gml/3.2"
    xmlns:mobilegis="$_nsUri">
  <wfs:Insert>
    <mobilegis:group5historical_photos>
      <mobilegis:geom>
        <gml:Point srsName="urn:ogc:def:crs:EPSG::4326">
          <gml:pos>${location.latitude} ${location.longitude}</gml:pos>
        </gml:Point>
      </mobilegis:geom>
$props    </mobilegis:group5historical_photos>
  </wfs:Insert>
</wfs:Transaction>''';

    final uri = Uri.https(wfsBaseUrl, _transactionPath);
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/xml; charset=UTF-8',
            'Accept': '*/*',
            'User-Agent': appUserAgent,
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw WfsException(
          'Insert failed: HTTP ${response.statusCode} — ${response.body}');
    }

    final ridMatch =
        RegExp(r'rid="([^"]+)"').firstMatch(response.body);
    if (ridMatch == null) {
      throw WfsException(
          'Insert succeeded but could not parse featureId from response');
    }
    return ridMatch.group(1)!;
  }

  static Future<void> updatePhoto({
    required String featureId,
    String? title,
    String? imageUrl,
    String? description,
    String? dateTaken,
    String? source,
    String? sourceUrl,
    String? photographer,
    String? streetAddress,
    String? linkedPoiId,
  }) async {
    final props = _buildXmlProps({
      if (title != null) 'title': title,
      if (imageUrl != null) 'image_url': imageUrl,
      if (description != null) 'description': description,
      if (dateTaken != null) 'date_taken': dateTaken,
      if (source != null) 'source': source,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (photographer != null) 'photographer': photographer,
      if (streetAddress != null) 'street_addr': streetAddress,
      if (linkedPoiId != null) 'linked_poi': linkedPoiId,
    });

    final body = '''
<wfs:Transaction
    service="WFS"
    version="2.0.0"
    xmlns:wfs="http://www.opengis.net/wfs/2.0"
    xmlns:gml="http://www.opengis.net/gml/3.2"
    xmlns:mobilegis="$_nsUri"
    xmlns:fes="http://www.opengis.net/fes/2.0">
  <wfs:Update typeName="mobilegis:group5historical_photos">
    <wfs:Property>
      <wfs:ValueReference>geom</wfs:ValueReference>
    </wfs:Property>
$props    <fes:Filter>
      <fes:ResourceId rid="$featureId"/>
    </fes:Filter>
  </wfs:Update>
</wfs:Transaction>''';

    final uri = Uri.https(wfsBaseUrl, _transactionPath);
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/xml; charset=UTF-8',
            'Accept': '*/*',
            'User-Agent': appUserAgent,
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw WfsException(
          'Update failed: HTTP ${response.statusCode} — ${response.body}');
    }
  }

  static Future<void> deletePhoto(String featureId) async {
    final body = '''
<wfs:Transaction
    service="WFS"
    version="2.0.0"
    xmlns:wfs="http://www.opengis.net/wfs/2.0"
    xmlns:fes="http://www.opengis.net/fes/2.0"
    xmlns:mobilegis="$_nsUri">
  <wfs:Delete typeName="mobilegis:group5historical_photos">
    <fes:Filter>
      <fes:ResourceId rid="$featureId"/>
    </fes:Filter>
  </wfs:Delete>
</wfs:Transaction>''';

    final uri = Uri.https(wfsBaseUrl, _transactionPath);
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/xml; charset=UTF-8',
            'Accept': '*/*',
            'User-Agent': appUserAgent,
          },
          body: body,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw WfsException(
          'Delete failed: HTTP ${response.statusCode} — ${response.body}');
    }
  }

  static String _buildXmlProps(Map<String, String> props) {
    final buf = StringBuffer();
    for (final entry in props.entries) {
      buf.writeln('      <mobilegis:${entry.key}>${_escapeXml(entry.value)}'
          '</mobilegis:${entry.key}>');
    }
    return buf.toString();
  }

  static String _escapeXml(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static MapFeature? _parseFeature({
    required String id,
    required String name,
    required Map<String, String> props,
    required Map<String, dynamic> geom,
  }) {
    final type = geom['type'] as String? ?? '';
    final coords = geom['coordinates'] as List<dynamic>?;

    switch (type) {
      case 'Point':
        if (coords == null || coords.length < 2) return null;
        final lon = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();
        return MapFeature(
          id: id,
          name: name,
          source: FeatureSource.wfs,
          geometry: PointGeometry(LatLng(lat, lon)),
          properties: props,
        );

      case 'Polygon':
        if (coords == null || coords.isEmpty) return null;
        final outerRing = <LatLng>[];
        for (final pair in coords[0] as List<dynamic>) {
          outerRing.add(LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          ));
        }
        final holes = <List<LatLng>>[];
        for (int h = 1; h < coords.length; h++) {
          final ring = <LatLng>[];
          for (final pair in coords[h] as List<dynamic>) {
            ring.add(LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            ));
          }
          holes.add(ring);
        }
        return MapFeature(
          id: id,
          name: name,
          source: FeatureSource.wfs,
          geometry: PolygonGeometry(outerRing: outerRing, holes: holes),
          properties: props,
        );

      default:
        return null;
    }
  }

  static DateTime? parseDate(String? raw) => _parseDate(raw);

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
    final year = int.tryParse(raw.split('.').first.trim());
    if (year != null && year >= 1000 && year <= 9999) return DateTime(year);
    return null;
  }

  static const _headers = {
    'Accept': 'application/json',
    'User-Agent': appUserAgent,
  };
}

class WfsException implements Exception {
  final String message;
  const WfsException(this.message);

  @override
  String toString() => 'WFS error: $message';
}
