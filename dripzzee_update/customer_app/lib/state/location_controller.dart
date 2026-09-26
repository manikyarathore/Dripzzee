import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/saved_location.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/location_service.dart';

enum LocationStatus { idle, loading, needsSetup, ready }

class LocationController extends ChangeNotifier {
  LocationController(this._service, this._users);

  final LocationService _service;
  final UserRepository _users;

  String? _uid;
  LocationStatus _status = LocationStatus.idle;
  SavedLocation? _current;
  bool _detecting = false;
  LocationFailure? _lastFailure;

  LocationStatus get status => _status;
  SavedLocation? get current => _current;
  bool get detecting => _detecting;
  LocationFailure? get lastFailure => _lastFailure;
  LocationService get service => _service;

  String _prefsKey(String uid) => 'location_$uid';

  /// Called by the provider tree whenever the signed-in user changes.
  void bindUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _current = null;
    _lastFailure = null;
    _status = uid == null ? LocationStatus.idle : LocationStatus.loading;
    scheduleMicrotask(() {
      notifyListeners();
      if (uid != null) _restore(uid);
    });
  }

  Future<void> _restore(String uid) async {
    SavedLocation? location;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey(uid));
      if (raw != null) location = SavedLocation.fromJson(raw);
    } catch (_) {}
    if (location == null) {
      try {
        location = await _users.fetchLocation(uid);
      } catch (_) {}
    }
    if (_uid != uid) return;
    _current = location;
    _status = location == null ? LocationStatus.needsSetup : LocationStatus.ready;
    notifyListeners();
  }

  /// Detects GPS location and saves it. Returns the failure, if any, so the
  /// calling screen can offer the right fallback.
  Future<LocationFailure?> detectAndSave() async {
    if (_detecting) return null;
    _detecting = true;
    _lastFailure = null;
    notifyListeners();
    final fix = await _service.detectCurrent();
    _detecting = false;
    final location = fix.location;
    if (location != null) {
      await setLocation(location);
      return null;
    }
    _lastFailure = fix.failure;
    notifyListeners();
    return fix.failure;
  }

  Future<void> setLocation(SavedLocation location) async {
    _current = location;
    _status = LocationStatus.ready;
    _lastFailure = null;
    notifyListeners();
    final uid = _uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey(uid), location.toJson());
    } catch (_) {}
    try {
      await _users.saveLocation(uid, location);
    } catch (_) {
      // Saved locally; Firestore sync will happen on the next change.
    }
  }
}
