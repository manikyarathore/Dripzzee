import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pressable.dart';
import '../../../navigation.dart';
import '../../../state/auth_controller.dart';
import '../../../state/location_controller.dart';
import '../../location/location_search_screen.dart';
import '../../profile/profile_screen.dart';
import '../../search/search_screen.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final location = context.watch<LocationController>().current;
    final name = context.select<AuthController, String>(
      (a) => a.user?.displayName ?? '',
    );
    final initial = name.trim().isEmpty ? null : name.trim()[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              semanticLabel: 'Change location',
              onTap: () => AppNav.push(context, const LocationSearchScreen()),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      color: AppColors.shopper, size: 24),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                location?.label ?? 'Set location',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body(
                                  size: 17,
                                  weight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                color: AppColors.paper, size: 20),
                          ],
                        ),
                        if (location?.detail != null)
                          Text(
                            location!.detail!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                              size: 12,
                              color: AppColors.paper.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            label: 'Profile',
            child: GestureDetector(
              onTap: () => AppNav.push(context, const ProfileScreen()),
              child: Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.panel.withValues(alpha: 0.85),
                  border: Border.all(color: AppColors.shopper.withValues(alpha: 0.5)),
                ),
                child: initial == null
                    ? Icon(Icons.person_rounded, color: AppColors.paper, size: 22)
                    : Text(
                        initial,
                        style: AppTextStyles.body(
                          size: 16,
                          weight: FontWeight.w800,
                          color: AppColors.shopper,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable search bar with rotating example queries (stops rotating when
/// reduced motion is on or the tab is hidden).
class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({super.key});

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  static const _hints = [
    'chaniya choli',
    'white sneakers',
    'oversized tee',
    'oxidised jhumkas',
    'kurta set',
    'cargo pants',
  ];
  int _hint = 0;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        TickerMode.valuesOf(context).enabled && !MediaQuery.disableAnimationsOf(context);
    if (animate && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
        if (mounted) setState(() => _hint = (_hint + 1) % _hints.length);
      });
    } else if (!animate) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Pressable(
        scale: 0.99,
        semanticLabel: 'Search products, stores and brands',
        onTap: () => AppNav.push(context, const SearchScreen(standalone: true)),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.shopper),
              const SizedBox(width: 10),
              Text('Search "',
                  style: AppTextStyles.body(size: 15, color: AppColors.mute)),
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                  child: Text(
                    '${_hints[_hint]}"',
                    key: ValueKey(_hint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(size: 15, color: AppColors.mute),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
