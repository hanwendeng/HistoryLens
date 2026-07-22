// GPS location with permission handling via the geolocator package.

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static Future<LatLng> getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationPermissionDeniedException();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionDeniedException();
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw LocationServiceDisabledException();

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return LatLng(position.latitude, position.longitude);
  }
}

class LocationPermissionDeniedException implements Exception {
  @override
  String toString() => 'Location permission denied';
}

class LocationServiceDisabledException implements Exception {
  @override
  String toString() => 'Location services disabled';
}
