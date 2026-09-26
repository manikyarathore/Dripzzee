import 'package:customer_app/data/repositories/auth_repository.dart';
import 'package:customer_app/state/auth_controller.dart';
import 'package:customer_app/state/gate.dart';
import 'package:customer_app/state/location_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('navigation guard', () {
    test('unknown session shows splash', () {
      for (final l in LocationStatus.values) {
        expect(resolveGate(AuthStatus.unknown, l), GateDestination.splash);
      }
    });

    test('signed-out users only ever see auth', () {
      for (final l in LocationStatus.values) {
        expect(resolveGate(AuthStatus.signedOut, l), GateDestination.auth);
      }
    });

    test('signed-in users need a location before the app', () {
      expect(resolveGate(AuthStatus.signedIn, LocationStatus.loading),
          GateDestination.splash);
      expect(resolveGate(AuthStatus.signedIn, LocationStatus.needsSetup),
          GateDestination.locationSetup);
      expect(resolveGate(AuthStatus.signedIn, LocationStatus.ready),
          GateDestination.app);
    });
  });

  test('auth error codes map to actionable messages', () {
    expect(AuthRepository.messageForCode('email-already-in-use'),
        contains('already exists'));
    expect(AuthRepository.messageForCode('invalid-credential'),
        'Incorrect email or password.');
    expect(AuthRepository.messageForCode('wrong-password'),
        'Incorrect email or password.');
    expect(AuthRepository.messageForCode('network-request-failed'),
        contains('internet'));
    expect(AuthRepository.messageForCode('weird-code'), isNotEmpty);
  });
}
