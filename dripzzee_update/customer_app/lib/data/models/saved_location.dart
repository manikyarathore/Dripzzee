import 'dart:convert';

/// The customer's selected shopping location (GPS, searched, or an address).
class SavedLocation {
  const SavedLocation({
    required this.label,
    required this.lat,
    required this.lng,
    this.detail,
    this.source = 'manual',
  });

  final String label;
  final String? detail;
  final double lat;
  final double lng;

  /// 'gps' | 'manual' | 'address'
  final String source;

  bool get isGps => source == 'gps';

  Map<String, dynamic> toMap() => {
        'label': label,
        'detail': detail,
        'lat': lat,
        'lng': lng,
        'source': source,
      };

  static SavedLocation? tryParse(Object? value) {
    if (value is! Map) return null;
    final m = Map<String, dynamic>.from(value);
    final lat = m['lat'];
    final lng = m['lng'];
    if (lat is! num || lng is! num) return null;
    return SavedLocation(
      label: m['label'] is String ? m['label'] as String : 'Selected location',
      detail: m['detail'] is String ? m['detail'] as String : null,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      source: m['source'] is String ? m['source'] as String : 'manual',
    );
  }

  String toJson() => jsonEncode(toMap());

  static SavedLocation? fromJson(String raw) {
    try {
      return tryParse(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }
}
