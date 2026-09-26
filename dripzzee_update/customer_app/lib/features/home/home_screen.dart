import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/catalog_filter.dart';
import '../../navigation.dart';
import '../../state/catalog_controller.dart';
import '../campaigns/campaign_carousel.dart';
import '../catalog/widgets/product_card.dart';
import '../catalog/widgets/store_card.dart';
import '../location/location_search_screen.dart';
import 'widgets/category_strip.dart';
import 'widgets/home_header.dart';

/// Gradient header (location + profile, search, campaign carousel)
/// → Shop by category → Stores around you → Trending near you → Discover more.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    final topInset = MediaQuery.paddingOf(context).top;

    return RefreshIndicator(
      color: AppColors.shopper,
      backgroundColor: AppColors.panel,
      edgeOffset: topInset,
      onRefresh: catalog.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.shopperDeep.withValues(
                        alpha: AppColors.isLight ? 0.30 : 0.55),
                    AppColors.shopper.withValues(
                        alpha: AppColors.isLight ? 0.12 : 0.16),
                    AppColors.ink.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: const Column(
                  children: [
                    HomeHeader(),
                    HomeSearchBar(),
                    CampaignCarousel(),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: 'Shop by category'),
                  SizedBox(height: 14),
                  CategoryStrip(),
                ],
              ),
            ),
          ),
          ..._content(context, catalog),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, CatalogController catalog) {
    switch (catalog.state) {
      case LoadState.idle:
      case LoadState.loading:
        return const [SliverToBoxAdapter(child: _HomeSkeleton())];
      case LoadState.error:
        return [
          SliverToBoxAdapter(
            child: ErrorState(
              message: catalog.error ?? 'Couldn\'t load stores near you.',
              onRetry: catalog.refresh,
            ),
          ),
        ];
      case LoadState.ready:
        break;
    }

    if (catalog.stores.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.storefront_outlined,
            title: 'No stores around here yet',
            message:
                'We couldn\'t find Dripzzee stores near ${catalog.location?.label ?? 'this location'}. Try another area.',
            actionLabel: 'Change location',
            onAction: () => AppNav.push(context, const LocationSearchScreen()),
          ),
        ),
      ];
    }

    final stores = catalog.stores.take(4).toList();
    final trending = catalog.recommended();
    final discover = catalog.discover();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget reveal(Widget child, int i) => reduceMotion
        ? child
        : child
            .animate()
            .fadeIn(duration: 380.ms, delay: (80 * i).ms)
            .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic);

    return [
      // 1. Stores around you
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 28, bottom: 12),
          child: SectionHeader(
            title: 'Stores around you',
            subtitle: '${catalog.stores.length} STORES NEARBY · SORTED BY DISTANCE',
            actionLabel: 'See all',
            onAction: () => AppNav.openStores(
              context,
              const StoreFilter(title: 'Stores around you'),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: stores.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) => reveal(
            StoreCard(store: stores[i], heroTag: 'home-store-${stores[i].id}'),
            i,
          ),
        ),
      ),

      // 2. Trending near you
      if (trending.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Trending near you',
                  subtitle: 'WHAT SHOPPERS AROUND YOU ARE PICKING',
                  actionLabel: 'See all',
                  onAction: () => AppNav.openProducts(
                    context,
                    const ProductFilter(title: 'Trending near you'),
                  ),
                ),
                const SizedBox(height: 12),
                ProductRail(products: trending, heroPrefix: 'home-trend'),
              ],
            ),
          ),
        ),

      // 3. Discover more
      if (discover.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 30, bottom: 14),
            child: SectionHeader(
              title: 'Discover more',
              subtitle: 'FRESH PICKS FROM EVERY STORE NEARBY',
            ),
          ),
        ),
        ProductGridSliver(products: discover, heroPrefix: 'home-discover'),
        if (catalog.products.length > discover.length)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: SecondaryButton(
                label: 'See everything nearby',
                icon: Icons.grid_view_rounded,
                onPressed: () => AppNav.openProducts(
                  context,
                  const ProductFilter(title: 'Discover more'),
                ),
              ),
            ),
          ),
      ],
    ];
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 180, height: 22, radius: 6),
          const SizedBox(height: 14),
          const SkeletonBox(height: 210, radius: AppRadius.lg),
          const SizedBox(height: 28),
          const SkeletonBox(width: 160, height: 22, radius: 6),
          const SizedBox(height: 14),
          SizedBox(
            height: 250,
            child: Row(
              children: const [
                Expanded(child: SkeletonBox()),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox()),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
