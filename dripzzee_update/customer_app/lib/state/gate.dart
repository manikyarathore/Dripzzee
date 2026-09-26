import 'auth_controller.dart';
import 'location_controller.dart';

enum GateDestination { splash, auth, locationSetup, app }

/// Route guard: which top-level surface a user may see. Pure so it can be
/// unit-tested; AuthGate renders the result.
GateDestination resolveGate(AuthStatus auth, LocationStatus location) =>
    switch (auth) {
      AuthStatus.unknown => GateDestination.splash,
      AuthStatus.signedOut => GateDestination.auth,
      AuthStatus.signedIn => switch (location) {
          LocationStatus.idle || LocationStatus.loading => GateDestination.splash,
          LocationStatus.needsSetup => GateDestination.locationSetup,
          LocationStatus.ready => GateDestination.app,
        },
    };
