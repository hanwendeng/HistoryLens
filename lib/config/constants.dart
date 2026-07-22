// Every URL, default value, and global constant lives here.

import 'package:latlong2/latlong.dart';

const wfsBaseUrl = 'mobilegisserver.mywire.org';

const wfsPath = '/geoserver/wfs';
const wfsTypeName = 'mobilegis:planet_osm_point';

const photoWfsPath = '/geoserver/mobilegis/ows';
const photoTypeName = 'mobilegis:group5historical_photos';
const imageBaseUrl = 'https://mobilegisserver.mywire.org/assets/history/';

const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

const defaultCenter = LatLng(49.0093, 8.4040);
const defaultZoom = 14.0;

const appName = 'History Lens';
const appSubtitle = 'Karlsruhe — Historical Photos on Map';
const appUserAgent = 'HistoryLens/1.0 (KIT Student Project)';
const appPackageName = 'com.example.hello_gik';

const cloudinaryCloudName = 'oypxnxhi';
const cloudinaryUploadPreset = 'historylens';

const kitGreen = 0xFF009682;
