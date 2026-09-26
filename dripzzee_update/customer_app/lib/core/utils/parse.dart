import 'package:cloud_firestore/cloud_firestore.dart';

/// Defensive readers for Firestore data — documents written by the retailer
/// app, the seed script or older versions must never crash the customer app.

DateTime? readDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

int readInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? readIntOrNull(Object? v) {
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v);
  return null;
}

double readDouble(Object? v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

double? readDoubleOrNull(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String readString(Object? v, [String fallback = '']) =>
    v is String ? v : fallback;

bool readBool(Object? v, [bool fallback = false]) => v is bool ? v : fallback;

List<String> readStringList(Object? v) =>
    v is List ? v.whereType<String>().toList() : <String>[];

Map<String, dynamic> readMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> readMapList(Object? v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];
