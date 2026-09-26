import '../../core/utils/parse.dart';

class Address {
  const Address({
    required this.id,
    required this.label,
    required this.name,
    required this.phone,
    required this.line1,
    required this.line2,
    required this.landmark,
    required this.city,
    required this.state,
    required this.pincode,
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  final String id;
  final String label; // Home | Work | Other
  final String name;
  final String phone;
  final String line1;
  final String line2;
  final String landmark;
  final String city;
  final String state;
  final String pincode;
  final double? lat;
  final double? lng;
  final bool isDefault;

  String get fullText {
    final parts = [line1, line2, landmark, city]
        .where((p) => p.trim().isNotEmpty)
        .join(', ');
    return '$parts, $state $pincode'.trim();
  }

  Address copyWith({String? id, bool? isDefault}) => Address(
        id: id ?? this.id,
        label: label,
        name: name,
        phone: phone,
        line1: line1,
        line2: line2,
        landmark: landmark,
        city: city,
        state: state,
        pincode: pincode,
        lat: lat,
        lng: lng,
        isDefault: isDefault ?? this.isDefault,
      );

  Map<String, dynamic> toMap() => {
        'label': label,
        'name': name,
        'phone': phone,
        'line1': line1,
        'line2': line2,
        'landmark': landmark,
        'city': city,
        'state': state,
        'pincode': pincode,
        'lat': lat,
        'lng': lng,
        'isDefault': isDefault,
      };

  factory Address.fromMap(String id, Map<String, dynamic> d) => Address(
        id: id,
        label: readString(d['label'], 'Other'),
        name: readString(d['name']),
        phone: readString(d['phone']),
        line1: readString(d['line1']),
        line2: readString(d['line2']),
        landmark: readString(d['landmark']),
        city: readString(d['city']),
        state: readString(d['state']),
        pincode: readString(d['pincode']),
        lat: readDoubleOrNull(d['lat']),
        lng: readDoubleOrNull(d['lng']),
        isDefault: readBool(d['isDefault']),
      );
}
