import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});

  /// What the shopper should do.
  final String message;

  /// Technical code from Firebase / Google, shown in small print so problems
  /// can be diagnosed from a screenshot.
  final String? code;

  String get userText =>
      code == null || code!.isEmpty ? message : '$message\n(Error code: $code)';

  @override
  String toString() => userText;
}

/// Thin wrapper over Firebase Auth that converts error codes into messages a
/// shopper can act on.
class AuthRepository {
  AuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Also fires when profile fields (e.g. display name) change.
  Stream<User?> userChanges() => _auth.userChanges();

  /// Sends a 6-digit OTP to [phoneE164] (e.g. +919876543210).
  ///
  /// On many Android phones Firebase reads the SMS itself and signs the user
  /// in without typing the code ([onAutoVerified]).
  Future<void> sendOtp({
    required String phoneE164,
    int? resendToken,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function() onAutoVerified,
    required void Function(AuthFailure failure) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneE164,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resendToken,
        verificationCompleted: (credential) async {
          try {
            await _auth.signInWithCredential(credential);
            onAutoVerified();
          } on FirebaseAuthException catch (e) {
            onError(failureFrom(e));
          }
        },
        verificationFailed: (e) => onError(failureFrom(e)),
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      onError(failureFrom(e));
    } catch (e) {
      onError(AuthFailure(
        'Couldn\'t send the code. Please try again.',
        code: e.toString(),
      ));
    }
  }

  Future<User> verifyOtp({
    required String verificationId,
    required String code,
  }) async {
    try {
      final cred = await _auth.signInWithCredential(
        PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code.trim(),
        ),
      );
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw failureFrom(e);
    }
  }
  User? get currentUser => _auth.currentUser;

  Future<User> signIn({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      throw failureFrom(e);
    }
  }

  Future<User> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(name.trim());
      return user;
    } on FirebaseAuthException catch (e) {
      throw failureFrom(e);
    }
  }

  /// Native Google account picker → Firebase credential.
  ///
  /// Needs: Google provider enabled, your SHA-1 + SHA-256 added in Firebase
  /// (Project settings → Your apps), and `googleWebClientId` in
  /// lib/firebase_options.dart (created by tools/gen_firebase_options.py).
  Future<User> signInWithGoogle() async {
    if (DefaultFirebaseOptions.googleWebClientId.isEmpty) {
      throw const AuthFailure(
        'Google sign-in isn\'t set up in this build yet. Use your phone number.',
        code: 'missing-web-client-id',
      );
    }
    final google = GoogleSignIn(
      scopes: const ['email'],
      serverClientId: DefaultFirebaseOptions.googleWebClientId,
    );
    try {
      // Always show the account chooser.
      await google.signOut();
      final account = await google.signIn();
      if (account == null) {
        throw const AuthFailure('Sign-in was cancelled.');
      }
      final tokens = await account.authentication;
      final idToken = tokens.idToken;
      if (idToken == null) {
        throw const AuthFailure(
          'Google didn\'t return a sign-in token. Check the SHA-1 fingerprint '
          'in Firebase and try again.',
          code: 'no-id-token',
        );
      }
      final cred = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(
          idToken: idToken,
          accessToken: tokens.accessToken,
        ),
      );
      return cred.user!;
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw failureFrom(e);
    } on PlatformException catch (e) {
      throw _googleFailure(e);
    } catch (e) {
      throw AuthFailure(
        'Google sign-in didn\'t work. Please try again.',
        code: _short(e.toString()),
      );
    }
  }

  static AuthFailure _googleFailure(PlatformException e) {
    final raw = '${e.code} ${e.message ?? ''}';
    // ApiException status codes from Google Play services.
    if (raw.contains('ApiException: 10') || raw.contains('12500')) {
      return AuthFailure(
        'Google sign-in isn\'t authorised for this app build. Add the SHA-1 '
        'and SHA-256 fingerprints in Firebase and download a fresh '
        'google-services.json.',
        code: _short(raw),
      );
    }
    if (raw.contains('ApiException: 7') || e.code == 'network_error') {
      return AuthFailure(
        'No internet connection. Check your network and try again.',
        code: _short(raw),
      );
    }
    if (e.code == 'sign_in_canceled' || raw.contains('12501')) {
      return const AuthFailure('Sign-in was cancelled.');
    }
    return AuthFailure(
      'Google sign-in didn\'t work. Please try again.',
      code: _short(raw),
    );
  }

  static String _short(String s) {
    final t = s.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.length > 120 ? '${t.substring(0, 120)}…' : t;
  }

  /// Turns a Firebase error into a message, looking at both the code and the
  /// server message (Firebase sometimes reports `unknown` / `internal-error`
  /// with the real reason only in the text).
  static AuthFailure failureFrom(FirebaseAuthException e) {
    final text = '${e.code} ${e.message ?? ''}';
    final upper = text.toUpperCase();
    String message;
    if (upper.contains('BILLING_NOT_ENABLED') || e.code == 'billing-not-enabled') {
      message = 'Real SMS needs the Firebase Blaze plan. For free testing, '
          'use a test number added under Authentication → Phone.';
    } else if (upper.contains('REGION')) {
      message = 'SMS to this country is blocked in Firebase. Allow India under '
          'Authentication → Settings → SMS region policy.';
    } else if (upper.contains('CONFIGURATION_NOT_FOUND')) {
      message = 'Sign-in isn\'t set up for this Firebase project yet.';
    } else if (upper.contains('INVALID_CERT_HASH') ||
        upper.contains('APP_NOT_AUTHORIZED') ||
        upper.contains('PLAY_INTEGRITY')) {
      message = 'This app build isn\'t authorised yet. Add the SHA-1 and '
          'SHA-256 fingerprints in Firebase (Project settings → Your apps).';
    } else {
      message = messageForCode(e.code);
    }
    return AuthFailure(message, code: _short(text));
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // Don't reveal whether an account exists.
      if (e.code == 'user-not-found') return;
      throw failureFrom(e);
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Not signed in with Google.
    }
    await _auth.signOut();
  }

  static String messageForCode(String code) => switch (code) {
        'email-already-in-use' =>
          'An account with this email already exists. Log in instead.',
        'invalid-email' => 'That email address doesn\'t look right.',
        'weak-password' => 'Choose a stronger password (8+ characters).',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' ||
        'INVALID_LOGIN_CREDENTIALS' =>
          'Incorrect email or password.',
        'invalid-verification-code' =>
          'That code isn\'t right. Check the SMS and try again.',
        'invalid-verification-id' || 'session-expired' || 'code-expired' =>
          'This code has expired. Tap "Resend code".',
        'invalid-phone-number' => 'Enter a valid 10-digit mobile number.',
        'quota-exceeded' =>
          'We\'ve sent too many codes right now. Try again in a little while.',
        'billing-not-enabled' =>
          'SMS sign-in isn\'t switched on for Dripzzee yet. Try Google instead.',
        'app-not-authorized' ||
        'missing-client-identifier' ||
        'invalid-app-credential' =>
          'This version of the app isn\'t authorised for phone sign-in yet.',
        'captcha-check-failed' || 'web-internal-error' =>
          'Verification didn\'t complete. Please try again.',
        'user-disabled' => 'This account has been disabled. Contact support.',
        'too-many-requests' =>
          'Too many attempts. Wait a few minutes and try again.',
        'network-request-failed' =>
          'No internet connection. Check your network and try again.',
        'operation-not-allowed' =>
          'This sign-in method is switched off in Firebase '
              '(Authentication → Sign-in method).',
        'web-context-canceled' ||
        'web-context-cancelled' ||
        'canceled' ||
        'cancelled' =>
          'Sign-in was cancelled.',
        'account-exists-with-different-credential' =>
          'This email is registered with a password. Log in with email instead.',
        _ => 'Something went wrong. Please try again.',
      };
}
