import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/colour_names.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/drip_chip.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/catalog_filter.dart';
import '../../data/models/product.dart';
import '../../navigation.dart';
import '../../state/catalog_controller.dart';
import 'widgets/product_card.dart';

/// Any product collection: category, campaign edit, trending, new in.
class ProductListingScreen extends StatefulWidget {
  const ProductListingScreen({super.key, required this.filter});

  final ProductFilter filter;

  @override
  State<ProductListingScreen> createState() => _ProductListingScreenState();
}

class _ProductListingScreenState extends State<ProductListingScreen> {
  late ProductSort _sort = widget.filter.sort;
  late String? _colour = widget.filter.initialColor;
  bool _inStockOnly = false;

  Future<void> _pickSort() async {
    final picked = await showModalBottomSheet<ProductSort>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sort by', style: AppTextStyles.heading(size: 20)),
            const SizedBox(height: 8),
            for (final s in ProductSort.values)
              ListTile(
                title: Text(s.label, style: AppTextStyles.body(size: 15)),
                trailing: s == _sort
                    ? Icon(Icons.check_rounded, color: AppColors.shopper)
                    : null,
                onTap: () => Navigator.of(ctx).pop(s),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _sort = picked);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    final filter = widget.filter;

    return Scaffold(
      appBar: dripAppBar(title: filter.title),
      body: switch (catalog.state) {
        LoadState.idle || LoadState.loading => const _GridSkeleton(),
        LoadState.error => ErrorState(
            message: catalog.error ?? 'Couldn\'t load products.',
            onRetry: catalog.refresh,
          ),
        LoadState.ready => _buildReady(catalog),
      },
    );
  }

  Widget _buildReady(CatalogController catalog) {
    final base = catalog.productsFor(widget.filter, sort: _sort);
    final colours = <String>{for (final p in base) ...p.colors}.toList()..sort();
    final activeColour =
        (_colour != null && colours.contains(_colour)) ? _colour : null;

    final List<Product> products = base.where((p) {
      if (_inStockOnly && !p.inStock) return false;
      if (activeColour != null && !p.colors.contains(activeColour)) return false;
      return true;
    }).toList();

    return RefreshIndicator(
      color: AppColors.shopper,
      backgroundColor: AppColors.panel,
      onRefresh: catalog.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (widget.filter.subtitle != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  widget.filter.subtitle!,
                  style: AppTextStyles.body(size: 13, color: AppColors.mute),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  DripChip(
                    label: _sort.label,
                    icon: Icons.swap_vert_rounded,
                    selected: _sort != widget.filter.sort,
                    onTap: _pickSort,
                  ),
                  const SizedBox(width: 8),
                  DripChip(
                    label: 'In stock',
                    icon: Icons.inventory_2_outlined,
                    selected: _inStockOnly,
                    onTap: () => setState(() => _inStockOnly = !_inStockOnly),
                  ),
                ],
              ),
            ),
          ),
          if (colours.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  children: [
                    DripChip(
                      label: 'All colours',
                      selected: activeColour == null,
                      onTap: () => setState(() => _colour = null),
                    ),
                    for (final c in colours) ...[
                      const SizedBox(width: 8),
                      DripChip(
                        label: c,
                        swatch: swatchFor(c),
                        selected: activeColour == c,
                        onTap: () => setState(
                            () => _colour = activeColour == c ? null : c),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Text(
                pluralize(products.length, 'style').toUpperCase(),
                style: AppTextStyles.mono(size: 11),
              ),
            ),
          ),
          if (products.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: base.isEmpty
                  ? EmptyState(
                      icon: Icons.checkroom_outlined,
                      title: 'Nothing here yet',
                      message:
                          'Stores near you haven\'t listed anything in this collection. Check back soon or browse nearby stores.',
                      actionLabel: 'Browse stores',
                      onAction: () => AppNav.openStores(
                        context,
                        const StoreFilter(title: 'Stores around you'),
                      ),
                    )
                  : EmptyState(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No matches',
                      message: 'Nothing fits these filters right now.',
                      actionLabel: 'Clear filters',
                      onAction: () => setState(() {
                        _colour = null;
                        _inStockOnly = false;
                      }),
                    ),
            )
          else
            ProductGridSliver(
              products: products,
              heroPrefix: 'list-${widget.filter.title}',
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
        childAspectRatio: 0.62,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => const SkeletonBox(),
    );
  }
}
