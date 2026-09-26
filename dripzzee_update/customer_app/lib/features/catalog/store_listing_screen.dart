import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/drip_chip.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/catalog_filter.dart';
import '../../navigation.dart';
import '../../state/catalog_controller.dart';
import '../location/location_search_screen.dart';
import 'widgets/store_card.dart';

class StoreListingScreen extends StatefulWidget {
  const StoreListingScreen({super.key, required this.filter});

  final StoreFilter filter;

  @override
  State<StoreListingScreen> createState() => _StoreListingScreenState();
}

class _StoreListingScreenState extends State<StoreListingScreen> {
  StoreSort _sort = StoreSort.nearest;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    Widget body = const SizedBox.shrink();
    switch (catalog.state) {
      case LoadState.idle:
      case LoadState.loading:
        body = ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            SkeletonBox(height: 210, radius: AppRadius.lg),
            SizedBox(height: 14),
            SkeletonBox(height: 210, radius: AppRadius.lg),
          ],
        );
      case LoadState.error:
        body = ErrorState(
          message: catalog.error ?? 'Couldn\'t load stores.',
          onRetry: catalog.refresh,
        );
      case LoadState.ready:
        final stores = catalog.storesFor(widget.filter, _sort);
        body = RefreshIndicator(
          color: AppColors.shopper,
          backgroundColor: AppColors.panel,
          onRefresh: catalog.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              if (widget.filter.subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    widget.filter.subtitle!,
                    style: AppTextStyles.body(size: 13, color: AppColors.mute),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in StoreSort.values)
                    DripChip(
                      label: s.label,
                      selected: s == _sort,
                      onTap: () => setState(() => _sort = s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (stores.isEmpty)
                EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No stores match yet',
                  message: widget.filter.tag == 'festive'
                      ? 'No boutiques near you have a festive edit listed yet. Try another area or check back soon.'
                      : 'No stores near ${catalog.location?.label ?? 'you'} match this.',
                  actionLabel: 'Change location',
                  onAction: () =>
                      AppNav.push(context, const LocationSearchScreen()),
                )
              else
                for (final s in stores) ...[
                  StoreCard(store: s, heroTag: 'stores-${s.id}'),
                  const SizedBox(height: 14),
                ],
            ],
          ),
        );
    }

    return Scaffold(
      appBar: dripAppBar(title: widget.filter.title),
      body: body,
    );
  }
}
