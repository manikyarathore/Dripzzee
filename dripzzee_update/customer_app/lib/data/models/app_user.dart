import '../../core/utils/parse.dart';
import 'saved_location.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.location,
    this.dob,
    this.gender = '',
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final SavedLocation? location;

  /// Date of birth (stored as yyyy-MM-dd).
  final DateTime? dob;

  /// 'female' | 'male' | 'other' | 'prefer_not' | ''
  final String gender;

  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
    if (letters.isNotEmpty) return letters;
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> d) => AppUser(
        uid: uid,
        name: readString(d['name']),
        email: readString(d['email']),
        phone: readString(d['phone']),
        location: SavedLocation.tryParse(d['location']),
        dob: d['dob'] is String ? DateTime.tryParse(d['dob'] as String) : null,
        gender: readString(d['gender']),
      );
}
