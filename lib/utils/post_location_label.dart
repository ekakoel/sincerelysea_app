import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

final RegExp _coordinateLocationPattern = RegExp(
  r'^\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*$',
);
final Map<String, Future<String>> _locationLabelCache = <String, Future<String>>{};

bool _looksLikeCoordinateLocation(String value) {
  return _coordinateLocationPattern.hasMatch(value.trim());
}

String _fallbackLocationLabel({
  required String fallback,
  required double latitude,
  required double longitude,
}) {
  final String trimmed = fallback.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

Future<String> resolveRegionCountryLabel({
  required double latitude,
  required double longitude,
  String fallback = '',
}) async {
  try {
    final List<Placemark> placemarks = await placemarkFromCoordinates(
      latitude,
      longitude,
    );
    if (placemarks.isNotEmpty) {
      final Placemark first = placemarks.first;
      final String region =
          first.subAdministrativeArea?.trim().isNotEmpty == true
          ? first.subAdministrativeArea!.trim()
          : first.locality?.trim().isNotEmpty == true
          ? first.locality!.trim()
          : first.administrativeArea?.trim() ?? '';
      final String country = first.country?.trim() ?? '';
      if (region.isNotEmpty && country.isNotEmpty) {
        return '$region - $country';
      }
      if (region.isNotEmpty) {
        return region;
      }
      if (country.isNotEmpty) {
        return country;
      }
    }
  } catch (_) {}
  return _fallbackLocationLabel(
    fallback: fallback,
    latitude: latitude,
    longitude: longitude,
  );
}

Future<String> resolvePostLocationLabel(Map<String, dynamic> postData) {
  final String location = postData['location']?.toString() ?? '';
  final GeoPoint? geo = postData['geo'] is GeoPoint
      ? postData['geo'] as GeoPoint
      : null;
  if (geo == null) {
    return Future<String>.value(location.trim());
  }
  if (location.trim().isNotEmpty && !_looksLikeCoordinateLocation(location)) {
    return Future<String>.value(location.trim());
  }
  final String key =
      '${geo.latitude.toStringAsFixed(5)},${geo.longitude.toStringAsFixed(5)}';
  return _locationLabelCache.putIfAbsent(
    key,
    () => resolveRegionCountryLabel(
      latitude: geo.latitude,
      longitude: geo.longitude,
      fallback: location,
    ),
  );
}
