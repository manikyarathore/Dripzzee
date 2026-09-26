import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/catalog_filter.dart';
import '../../navigation.dart';
import '../../state/catalog_controller.dart';
import 'campaign.dart';
import 'scenes/garba_scene.dart';
import 'scenes/nine_looks_scene.dart';
import 'scenes/stores_near_scene.dart';

/// Navratri 2026 festive edit. Products/stores opt in via tags written by
/// retailers: `garba`, `navratri` (products) and `festive` (products/stores).
final navratriCampaign = Campaign(
  id: 'navratri-2026',
  startsAt: DateTime(2026, 9, 15),
  endsAt: DateTime(2026, 10, 26),
  slides: [
    (context, active) => CampaignCard(
          eyebrow: 'NAVRATRI · GARBA NIGHTS',
          title: 'Garba Night Fits',
          subtitle: 'Chaniya cholis, kediyus and dandiya-ready jewellery',
          ctaLabel: 'Shop the edit',
          accent: AppColors.marigold,
          scene: GarbaScene(active: active),
          onTap: () => AppNav.openProducts(
            context,
            const ProductFilter(
              title: 'Garba Night Fits',
              subtitle: 'Twirl-ready looks in stock near you',
              tag: 'garba',
            ),
          ),
        ),
    (context, active) => NineLooksSlide(active: active),
    (context, active) => FestiveStoresSlide(active: active),
  ],
);

/// Cycles through the nine looks; tapping opens the Navratri collection
/// pre-filtered to the colour on screen.
class NineLooksSlide extends StatefulWidget {
  const NineLooksSlide({super.key, required this.active});

  final bool active;

  @override
  State<NineLooksSlide> createState() => _NineLooksSlideState();
}

class _NineLooksSlideState extends State<NineLooksSlide> {
  int _index = 0;
  Timer? _timer;
  bool _reduceMotion = false;

  void _sync() {
    final run = widget.active && !_reduceMotion;
    if (run && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 1900), (_) {
        if (mounted) setState(() => _index = (_index + 1) % kNineLooks.length);
      });
    } else if (!run) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(covariant NineLooksSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final look = kNineLooks[_index];
    return CampaignCard(
      eyebrow: 'NINE NIGHTS · NINE LOOKS',
      title: 'Nine Nights, Nine Looks',
      subtitle: 'Night ${look.night}: ${look.colour} — ${look.look}',
      ctaLabel: 'Shop ${look.colour}',
      accent: AppColors.shopper,
      scene: NineLooksScene(index: _index),
      onTap: () => AppNav.openProducts(
        context,
        ProductFilter(
          title: 'Nine Nights, Nine Looks',
          subtitle: 'Shop the festive palette, night by night',
          tag: 'navratri',
          initialColor: look.colour,
        ),
      ),
    );
  }
}

class FestiveStoresSlide extends StatelessWidget {
  const FestiveStoresSlide({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final count = context.select<CatalogController, int>(
      (c) => c.countStoresWithTag('festive'),
    );
    final loaded = context.select<CatalogController, bool>(
      (c) => c.state == LoadState.ready,
    );
    final subtitle = !loaded
        ? 'Boutiques with a Navratri edit, close to you'
        : count == 0
            ? 'Be the first to see festive edits as stores add them'
            : '$count ${count == 1 ? 'boutique' : 'boutiques'} with a festive '
                'edit within ${AppConfig.nearbyRadiusKm.round()} km';
    return CampaignCard(
      eyebrow: 'FESTIVE STORES NEAR YOU',
      title: 'Festive stores near you',
      subtitle: subtitle,
      ctaLabel: 'Explore stores',
      accent: AppColors.marigold,
      scene: StoresNearScene(active: active),
      onTap: () => AppNav.openStores(
        context,
        const StoreFilter(
          title: 'Festive stores near you',
          subtitle: 'Local boutiques with a Navratri edit',
          tag: 'festive',
        ),
      ),
    );
  }
}
