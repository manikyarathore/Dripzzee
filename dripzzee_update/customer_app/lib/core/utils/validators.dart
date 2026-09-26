/// Form validators. Each returns an error message, or null when valid.
class Validators {
  Validators._();

  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final _indianMobile = RegExp(r'^[6-9]\d{9}$');
  static final _pincode = RegExp(r'^[1-9]\d{5}$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!_email.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  /// Strength rules for new passwords.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Create a password';
    if (v.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  /// Login only checks presence; the server decides if it's correct.
  static String? loginPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Enter your password' : null;

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your name';
    if (v.length < 2) return 'Name looks too short';
    if (v.length > 50) return 'Keep it under 50 characters';
    return null;
  }

  /// Removes spaces, dashes and a leading +91/91/0.
  static String normalizePhone(String value) {
    var v = value.replaceAll(RegExp(r'[\s\-()]'), '');
    if (v.startsWith('+91')) v = v.substring(3);
    if (v.length == 12 && v.startsWith('91')) v = v.substring(2);
    if (v.length == 11 && v.startsWith('0')) v = v.substring(1);
    return v;
  }

  static String? phone(String? value, {bool required = true}) {
    final v = normalizePhone(value ?? '');
    if (v.isEmpty) return required ? 'Enter a mobile number' : null;
    if (!_indianMobile.hasMatch(v)) return 'Enter a valid 10-digit mobile number';
    return null;
  }

  static String? pincode(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter the pincode';
    if (!_pincode.hasMatch(v)) return 'Enter a valid 6-digit pincode';
    return null;
  }

  static String? required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Enter $label';
    return null;
  }
}
