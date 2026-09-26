import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/services/notification_service.dart';

enum AuthStatus { unknown, signedOut, signedIn }

class AuthController extends ChangeNotifier {
  AuthController(this._auth, this._users, this._notifications) {
    _sub = _auth.userChanges().listen(_onUserChanged);
  }

  final AuthRepository _auth;
  final UserRepository _users;
  final NotificationService _notifications;
  late final StreamSubscription<User?> _sub;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _pendingName;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get uid => _user?.uid;
  String get email => _user?.email ?? '';

  Future<void> _onUserChanged(User? user) async {
    if (user == null) {
      _user = null;
      _status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    if (user.uid == _user?.uid) {
      // Same session, profile fields changed (e.g. name edited).
      _user = user;
      notifyListeners();
      return;
    }
    try {
      await _users.ensureCustomerDoc(user, name: _pendingName);
    } catch (_) {
      // Profile creation is retried on the next sign-in; the session itself
      // is valid, so don't block the user.
    }
    _pendingName = null;
    _user = user;
    _status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) =>
      _auth.signIn(email: email, password: password);

  Future<void> signUp(String name, String email, String password) async {
    _pendingName = name.trim();
    try {
      await _auth.signUp(name: name, email: email, password: password);
    } catch (_) {
      _pendingName = null;
      rethrow;
    }
  }

  Future<void> signInWithGoogle() => _auth.signInWithGoogle();

  /// Phone OTP step 1. See [AuthRepository.sendOtp].
  Future<void> sendOtp({
    required String phoneE164,
    int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(AuthFailure failure) onError,
  }) =>
      _auth.sendOtp(
        phoneE164: phoneE164,
        resendToken: resendToken,
        onCodeSent: onCodeSent,
        onAutoVerified: onAutoVerified,
        onError: onError,
      );

  /// Phone OTP step 2. Signing in also creates the account the first time.
  Future<void> verifyOtp(String verificationId, String code) =>
      _auth.verifyOtp(verificationId: verificationId, code: code);

  /// Keeps the Firebase Auth display name in sync with the profile.
  Future<void> updateDisplayName(String name) async {
    await _user?.updateDisplayName(name.trim());
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(email);

  Future<void> signOut() async {
    await _notifications.stop();
    await _auth.signOut();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
