import 'dart:async';

import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

import '../models/saved_location.dart';

enum LocationFailure { serviceDisabled, denied, deniedForever, timeout, unavailable }

extension LocationFailureMessage on LocationFailure {
  String get message => switch (this) {
        LocationFailure.serviceDisabled =>
          'Location is turned off on your phone. Turn it on, or enter your area manually.',
        LocationFailure.denied =>
          'Location permission was denied. Allow it to see stores near you, or enter your area manually.',
        LocationFailure.deniedForever =>
          'Location permission is blocked. Enable it in Settings, or enter your area manually.',
        LocationFailure.timeout =>
          'We couldn\'t get a GPS fix in time. Move near a window or enter your area manually.',
        LocationFailure.unavailable =>
          'We couldn\'t detect your location. Enter your area manually.',
      };
}

class LocationFix {
  const LocationFix.success(SavedLocation this.location) : failure = null;
  const LocationFix.failed(LocationFailure this.failure) : location = null;

  final SavedLocation? location;
  final LocationFailure? failure;
}

class PlaceDetails {
  const PlaceDetails({
    required this.line1,
    required this.city,
    required this.state,
    required this.pincode,
  });

  final String line1;
  final String city;
  final String state;
  final String pincode;
}

class LocationService {
  Future<LocationFix> detectCurrent() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationFix.failed(LocationFailure.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationFix.failed(LocationFailure.deniedForever);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        return const LocationFix.failed(LocationFailure.denied);
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } on TimeoutException {
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          return const LocationFix.failed(LocationFailure.timeout);
        }
      }

      final place = await describe(position.latitude, position.longitude);
      return LocationFix.success(SavedLocation(
        label: place.$1,
        detail: place.$2,
        lat: position.latitude,
        lng: position.longitude,
        source: 'gps',
      ));
    } catch (_) {
      return const LocationFix.failed(LocationFailure.unavailable);
    }
  }

  /// Reverse-geocodes to a short title ("Bandra West") and a detail line.
  Future<(String, String?)> describe(double lat, double lng) async {
    try {
      final marks = await geo.placemarkFromCoordinates(lat, lng);
      if (marks.isNotEmpty) {
        final p = marks.first;
        final title = _firstNonEmpty([p.subLocality, p.locality, p.name]) ??
            'Current location';
        final detail = <String>{
          for (final part in [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
            p.postalCode,
          ])
            if (part != null && part.trim().isNotEmpty) part.trim(),
        }.join(', ');
        return (title, detail.isEmpty ? null : detail);
      }
    } catch (_) {
      // Fall through to coordinates.
    }
    return (
      'Pinned location',
      '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
    );
  }

  /// Forward geocoding for the manual location search.
  Future<List<SavedLocation>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return [];
    try {
      final results = await geo.locationFromAddress(q);
      final out = <SavedLocation>[];
      for (final r in results.take(5)) {
        final place = await describe(r.latitude, r.longitude);
        out.add(SavedLocation(
          label: place.$1 == 'Pinned location' ? q : place.$1,
          detail: place.$2,
          lat: r.latitude,
          lng: r.longitude,
          source: 'manual',
        ));
      }
      return out;
    } on geo.NoResultFoundException {
      return [];
    }
  }

  /// Structured address parts for pre-filling the address form.
  Future<PlaceDetails?> placeDetails(double lat, double lng) async {
    try {
      final marks = await geo.placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      final p = marks.first;
      return PlaceDetails(
        line1: [p.street, p.subLocality]
            .where((s) => s != null && s.trim().isNotEmpty)
            .join(', '),
        city: p.locality ?? p.subAdministrativeArea ?? '',
        state: p.administrativeArea ?? '',
        pincode: p.postalCode ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  static String? _firstNonEmpty(List<String?> values) {
    for (final v in values) {
      if (v != null && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }
}
