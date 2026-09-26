import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/address.dart';
import '../models/app_user.dart';
import '../models/saved_location.dart';

/// users/{uid} and its addresses subcollection.
class UserRepository {
  UserRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _addresses(String uid) =>
      _user(uid).collection('addresses');

  /// Creates the customer profile on first sign-in (phone, Google or
  /// email) and fills in the phone number for phone sign-ins.
  Future<void> ensureCustomerDoc(User user, {String? name}) async {
    final ref = _user(user.uid);
    final snap = await ref.get();
    final phone = _tenDigits(user.phoneNumber);
    if (!snap.exists) {
      await ref.set({
        'name': (name ?? user.displayName ?? '').trim(),
        'email': user.email ?? '',
        'phone': phone,
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else if (phone.isNotEmpty && (snap.data()?['phone'] ?? '') == '') {
      await ref.update({
        'phone': phone,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static String _tenDigits(String? e164) {
    final digits = (e164 ?? '').replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
  }

  Stream<AppUser?> watchUser(String uid) => _user(uid).snapshots().map(
        (s) => s.exists ? AppUser.fromMap(uid, s.data()!) : null,
      );

  Future<void> updateProfile(
    String uid, {
    required String name,
    required String phone,
    required String email,
    DateTime? dob,
    String gender = '',
  }) =>
      _user(uid).update({
        'name': name.trim(),
        'phone': phone,
        'email': email.trim(),
        'dob': dob == null
            ? null
            : '${dob.year.toString().padLeft(4, '0')}-'
                '${dob.month.toString().padLeft(2, '0')}-'
                '${dob.day.toString().padLeft(2, '0')}',
        'gender': gender,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<SavedLocation?> fetchLocation(String uid) async {
    final snap = await _user(uid).get();
    return SavedLocation.tryParse(snap.data()?['location']);
  }

  Future<void> saveLocation(String uid, SavedLocation location) =>
      _user(uid).update({
        'location': location.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Stream<List<Address>> watchAddresses(String uid) =>
      _addresses(uid).snapshots().map((s) {
        final list =
            s.docs.map((d) => Address.fromMap(d.id, d.data())).toList();
        list.sort((a, b) {
          if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
          return a.label.compareTo(b.label);
        });
        return list;
      });

  /// Saves (creates or updates) an address. The first address, or one marked
  /// default, becomes the only default.
  Future<Address> saveAddress(String uid, Address address) async {
    final existing = await _addresses(uid).get();
    final makeDefault = address.isDefault || existing.docs.isEmpty;
    final ref = address.id.isEmpty
        ? _addresses(uid).doc()
        : _addresses(uid).doc(address.id);
    final saved = address.copyWith(id: ref.id, isDefault: makeDefault);

    final batch = _db.batch();
    if (makeDefault) {
      for (final d in existing.docs) {
        if (d.id != ref.id && d.data()['isDefault'] == true) {
          batch.update(d.reference, {'isDefault': false});
        }
      }
    }
    batch.set(ref, saved.toMap());
    await batch.commit();
    return saved;
  }

  Future<void> deleteAddress(String uid, Address address) async {
    await _addresses(uid).doc(address.id).delete();
    if (address.isDefault) {
      final rest = await _addresses(uid).limit(1).get();
      if (rest.docs.isNotEmpty) {
        await rest.docs.first.reference.update({'isDefault': true});
      }
    }
  }

  Future<void> addFcmToken(String uid, String token) => _user(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });

  Future<void> removeFcmToken(String uid, String token) => _user(uid).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
}
