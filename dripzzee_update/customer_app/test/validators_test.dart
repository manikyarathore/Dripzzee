import 'package:customer_app/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email', () {
    expect(Validators.email(''), isNotNull);
    expect(Validators.email('a@b'), isNotNull);
    expect(Validators.email(' shopper@dripzzee.in '), isNull);
  });

  test('new password strength', () {
    expect(Validators.newPassword('short1'), isNotNull);
    expect(Validators.newPassword('onlyletters'), isNotNull);
    expect(Validators.newPassword('12345678'), isNotNull);
    expect(Validators.newPassword('garba2026'), isNull);
  });

  test('indian mobile numbers', () {
    expect(Validators.phone('98765 43210'), isNull);
    expect(Validators.phone('+91 98765-43210'), isNull);
    expect(Validators.phone('09876543210'), isNull);
    expect(Validators.phone('12345'), isNotNull);
    expect(Validators.phone('5876543210'), isNotNull);
    expect(Validators.phone('', required: false), isNull);
    expect(Validators.normalizePhone('+91 98765 43210'), '9876543210');
  });

  test('pincode and name', () {
    expect(Validators.pincode('400050'), isNull);
    expect(Validators.pincode('012345'), isNotNull);
    expect(Validators.pincode('4000'), isNotNull);
    expect(Validators.name('A'), isNotNull);
    expect(Validators.name('Aarav'), isNull);
  });
}
