import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/drip_logo.dart';
import '../../core/widgets/state_views.dart';
import '../../data/services/location_service.dart';
import '../../state/auth_controller.dart';
import '../../state/location_controller.dart';
import 'location_search_screen.dart';

/// First-run location step. The gate moves on automatically once a location
/// is saved (GPS or manual).
class LocationSetupScreen extends StatelessWidget {
  const LocationSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationController>();
    final failure = location.lastFailure;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const DripLogo(height: 22),
                        const Spacer(),
                        LinkButton(
                          label: 'Log out',
                          onPressed: () =>
                              context.read<AuthController>().signOut(),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Center(child: _PinBadge(animate: !reduceMotion)),
                    const SizedBox(height: 32),
                    Text(
                      'Where should we look?',
                      style: AppTextStyles.heading(size: 30),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Dripzzee shows boutiques, sneaker spots and streetwear '
                      'stores near you — with real sizes in stock. We only use '
                      'your location to find stores and estimate delivery.',
                      style: AppTextStyles.body(
                        size: 15,
                        color: AppColors.mute,
                        height: 1.5,
                      ),
                    ),
                    if (failure != null) ...[
                      const SizedBox(height: 20),
                      InlineNotice(message: failure.message),
                      _SettingsShortcut(failure: failure),
                    ],
                    const Spacer(),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Use my current location',
                      icon: Icons.my_location_rounded,
                      loading: location.detecting,
                      onPressed: () =>
                          context.read<LocationController>().detectAndSave(),
                    ),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: 'Enter location manually',
                      icon: Icons.search_rounded,
                      onPressed: location.detecting
                          ? null
                          : () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const LocationSearchScreen(),
                              )),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsShortcut extends StatelessWidget {
  const _SettingsShortcut({required this.failure});

  final LocationFailure failure;

  @override
  Widget build(BuildContext context) {
    final service = context.read<LocationController>().service;
    if (failure == LocationFailure.deniedForever) {
      return Align(
        alignment: Alignment.centerLeft,
        child: LinkButton(
          label: 'Open app settings',
          onPressed: service.openAppSettings,
        ),
      );
    }
    if (failure == LocationFailure.serviceDisabled) {
      return Align(
        alignment: Alignment.centerLeft,
        child: LinkButton(
          label: 'Turn on location',
          onPressed: service.openLocationSettings,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _PinBadge extends StatelessWidget {
  const _PinBadge({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    Widget ring = Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.shopper.withValues(alpha: 0.35)),
      ),
    );
    if (animate) {
      ring = ring
          .animate(onPlay: (c) => c.repeat())
          .scale(
            begin: const Offset(0.7, 0.7),
            end: const Offset(1.15, 1.15),
            duration: 1800.ms,
            curve: Curves.easeOut,
          )
          .fadeOut(duration: 1800.ms);
    }
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring,
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColors.panel,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: 38,
              color: AppColors.shopper,
            ),
          ),
        ],
      ),
    );
  }
}
