import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/drip_logo.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/repositories/coupon_repository.dart';
import 'data/repositories/order_repository.dart';
import 'data/repositories/return_repository.dart';
import 'data/repositories/review_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/repositories/wishlist_repository.dart';
import 'data/services/location_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/payment_service.dart';
import 'data/services/recent_search_store.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/location/location_setup_screen.dart';
import 'features/shell/root_shell.dart';
import 'navigation.dart';
import 'state/auth_controller.dart';
import 'state/cart_controller.dart';
import 'state/catalog_controller.dart';
import 'state/gate.dart';
import 'state/location_controller.dart';
import 'state/shell_controller.dart';
import 'state/theme_controller.dart';
import 'state/wishlist_controller.dart';

class DripzzeeApp extends StatelessWidget {
  const DripzzeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repositories & services (stateless singletons)
        Provider<AuthRepository>(create: (_) => AuthRepository()),
        Provider<UserRepository>(create: (_) => UserRepository()),
        Provider<CatalogRepository>(create: (_) => CatalogRepository()),
        Provider<WishlistRepository>(create: (_) => WishlistRepository()),
        Provider<OrderRepository>(create: (_) => OrderRepository()),
        Provider<CouponRepository>(create: (_) => CouponRepository()),
        Provider<ReturnRepository>(create: (_) => ReturnRepository()),
        Provider<ReviewRepository>(create: (_) => ReviewRepository()),
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<PaymentService>(create: (_) => PaymentService()),
        Provider<RecentSearchStore>(create: (_) => RecentSearchStore()),
        Provider<NotificationService>(
          create: (c) => NotificationService(c.read<UserRepository>()),
        ),

        // App state
        ChangeNotifierProvider<AuthController>(
          create: (c) => AuthController(
            c.read<AuthRepository>(),
            c.read<UserRepository>(),
            c.read<NotificationService>(),
          ),
        ),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(),
          lazy: false,
        ),
        ChangeNotifierProvider<ShellController>(
          create: (_) => ShellController(),
        ),
        ChangeNotifierProxyProvider<AuthController, LocationController>(
          create: (c) => LocationController(
            c.read<LocationService>(),
            c.read<UserRepository>(),
          ),
          update: (_, auth, location) => location!..bindUser(auth.uid),
        ),
        ChangeNotifierProxyProvider<LocationController, CatalogController>(
          create: (c) => CatalogController(c.read<CatalogRepository>()),
          update: (_, location, catalog) =>
              catalog!..onLocationChanged(location.current),
        ),
        ChangeNotifierProxyProvider<AuthController, CartController>(
          create: (_) => CartController(),
          update: (_, auth, cart) => cart!..bindUser(auth.uid),
        ),
        ChangeNotifierProxyProvider<AuthController, WishlistController>(
          create: (c) => WishlistController(c.read<WishlistRepository>()),
          update: (_, auth, wishlist) => wishlist!..bindUser(auth.uid),
        ),
      ],
      child: const _ThemedApp(),
    );
  }
}

/// Rebuilds the whole tree when the appearance changes, so every widget
/// re-reads [AppColors] without losing navigation or form state.
class _ThemedApp extends StatefulWidget {
  const _ThemedApp();

  @override
  State<_ThemedApp> createState() => _ThemedAppState();
}

class _ThemedAppState extends State<_ThemedApp> {
  Brightness? _last;

  void _rebuildAll() {
    void visit(Element e) {
      e.markNeedsBuild();
      e.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = context.watch<ThemeController>().brightness;
    if (_last != null && _last != brightness) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuildAll();
      });
    }
    _last = brightness;
    return MaterialApp(
      title: 'Dripzzee',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      home: const AuthGate(),
    );
  }
}

/// Top-level route guard: splash → auth → location setup → app.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final location = context.watch<LocationController>();
    final destination = resolveGate(auth.status, location.status);
    final uid = auth.uid;

    final Widget child = switch (destination) {
      GateDestination.splash => const SplashScreen(),
      GateDestination.auth => const LoginScreen(),
      GateDestination.locationSetup => SignedInScope(
          uid: uid!,
          child: const LocationSetupScreen(),
        ),
      GateDestination.app => SignedInScope(
          uid: uid!,
          child: const RootShell(),
        ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(key: ValueKey(destination), child: child),
    );
  }
}

/// Starts per-session services (push notifications) for a signed-in user.
class SignedInScope extends StatefulWidget {
  const SignedInScope({super.key, required this.uid, required this.child});

  final String uid;
  final Widget child;

  @override
  State<SignedInScope> createState() => _SignedInScopeState();
}

class _SignedInScopeState extends State<SignedInScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationService>().start(
            uid: widget.uid,
            onOpen: AppNav.handleNotification,
            onForeground: (title, body, data) {
              messengerKey.currentState
                ?..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.body(
                          size: 14,
                          weight: FontWeight.w700,
                        ),
                      ),
                      if (body.isNotEmpty)
                        Text(
                          body,
                          style: AppTextStyles.body(
                            size: 13,
                            color: AppColors.mute,
                          ),
                        ),
                    ],
                  ),
                  action: data.isEmpty
                      ? null
                      : SnackBarAction(
                          label: 'View',
                          onPressed: () => AppNav.handleNotification(data),
                        ),
                ));
            },
          );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shown only if Firebase failed to initialise (e.g. `flutterfire configure`
/// was not run). Keeps a misconfigured build from crashing silently.
class FirebaseSetupErrorApp extends StatelessWidget {
  const FirebaseSetupErrorApp({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DripLogo(height: 26),
                const SizedBox(height: 32),
                Text(
                  'We couldn\'t start Dripzzee',
                  style: AppTextStyles.heading(size: 26),
                ),
                const SizedBox(height: 12),
                Text(
                  'Firebase is not configured for this build. Run '
                  '`flutterfire configure` in the customer_app folder and '
                  'rebuild.',
                  style: AppTextStyles.body(color: AppColors.mute, height: 1.5),
                ),
                const SizedBox(height: 16),
                Text(error, style: AppTextStyles.mono(size: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
