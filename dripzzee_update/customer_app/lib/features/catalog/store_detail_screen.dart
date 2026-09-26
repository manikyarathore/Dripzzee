import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo.dart';
import '../../core/widgets/drip_chip.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/rating_badge.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/fashion_category.dart';
import '../../data/models/product.dart';
import '../../data/models/review.dart';
import '../../data/models/store.dart';
import '../../state/catalog_controller.dart';
import '../../state/location_controller.dart';
import 'widgets/product_card.dart';

class StoreDetailScreen extends StatefulWidget {
  const StoreDetailScreen({
    super.key,
    required this.storeId,
    this.initial,
    this.heroTag,
  });

  final String storeId;
  final Store? initial;
  final String? heroTag;

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  late final CatalogController _catalog = context.read<CatalogController>();
  Future<Store?>? _storeFuture;
  Future<List<Product>>? _productsFuture;
  late Future<List<Review>> _reviewsFuture;
  String _category = 'all';

  bool get _inCatalog => _catalog.storeById(widget.storeId) != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = _catalog.repository;
    if (!_inCatalog) {
      _storeFuture = repo.fetchStore(widget.storeId);
      _productsFuture = repo.fetchProductsForStores([widget.storeId]);
    }
    _reviewsFuture = repo.fetchStoreReviews(widget.storeId);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogController>();
    final fromCatalog = catalog.storeById(widget.storeId);
    if (fromCatalog != null) {
      return _buildWith(fromCatalog, catalog.storeProducts(widget.storeId));
    }
    return FutureBuilder<Store?>(
      future: _storeFuture,
      initialData: widget.initial,
      builder: (context, storeSnap) {
        final store = storeSnap.data;
        if (store == null) {
          if (storeSnap.connectionState == ConnectionState.done ||
              storeSnap.hasError) {
            return Scaffold(
              appBar: AppBar(backgroundColor: AppColors.ink),
              body: storeSnap.hasError
                  ? ErrorState(
                      message: 'Couldn\'t load this store.',
                      onRetry: () => setState(_load),
                    )
                  : const EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Store unavailable',
                      message: 'This store is no longer on Dripzzee.',
                    ),
            );
          }
          return const Scaffold(body: CenteredLoader());
        }
        final loc = context.read<LocationController>().current;
        final withDistance = (loc != null && store.lat != null && store.lng != null)
            ? store.withDistance(distanceKm(loc.lat, loc.lng, store.lat!, store.lng!))
            : store;
        return FutureBuilder<List<Product>>(
          future: _productsFuture,
          builder: (context, snap) => _buildWith(
            withDistance,
            snap.data,
            productsError: snap.hasError,
          ),
        );
      },
    );
  }

  Widget _buildWith(
    Store store,
    List<Product>? products, {
    bool productsError = false,
  }) {
    final categories = <String>{
      for (final p in products ?? const <Product>[]) p.category,
    }.where((c) => c.isNotEmpty).toList();
    final visible = (products ?? const <Product>[])
        .where((p) => _category == 'all' || p.category == _category)
        .toList();
    final heroTag = widget.heroTag ?? 'store-detail-${store.id}';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            backgroundColor: AppColors.ink,
            surfaceTintColor: Colors.transparent,
            foregroundColor: AppColors.paper,
            title: Text(
              store.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading(size: 18),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: heroTag,
                child: DripImage(
                  url: store.imageUrl,
                  label: store.name,
                  icon: Icons.storefront_outlined,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _StoreInfo(store: store)),
          if (categories.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: [
                    DripChip(
                      label: 'All',
                      selected: _category == 'all',
                      onTap: () => setState(() => _category = 'all'),
                    ),
                    for (final c in categories) ...[
                      const SizedBox(width: 8),
                      DripChip(
                        label: categoryLabel(c),
                        selected: _category == c,
                        onTap: () => setState(() => _category = c),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                products == null
                    ? 'CATALOGUE'
                    : 'CATALOGUE · ${pluralize(visible.length, 'STYLE')}',
                style: AppTextStyles.mono(size: 11),
              ),
            ),
          ),
          if (productsError)
            const SliverToBoxAdapter(
              child: ErrorState(message: 'Couldn\'t load this store\'s catalogue.'),
            )
          else if (products == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CenteredLoader(),
              ),
            )
          else if (visible.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.checkroom_outlined,
                title: 'No styles listed yet',
                message: 'This store hasn\'t added products to Dripzzee yet.',
              ),
            )
          else
            ProductGridSliver(
              products: visible,
              heroPrefix: 'store-${store.id}',
              showStore: false,
            ),
          SliverToBoxAdapter(child: _Reviews(future: _reviewsFuture)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _StoreInfo extends StatelessWidget {
  const _StoreInfo({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.name, style: AppTextStyles.heading(size: 28)),
          if (s.categories.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              s.categories.map(categoryLabel).join(' • '),
              style: AppTextStyles.body(size: 13, color: AppColors.mute),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (s.hasRating)
                RatingBadge(rating: s.rating, count: s.ratingCount)
              else
                Text('NEW ON DRIPZZEE',
                    style: AppTextStyles.mono(size: 11, color: AppColors.shopper)),
              if (s.distanceKm != null)
                _Meta(Icons.near_me_outlined, formatDistance(s.distanceKm!)),
              _Meta(Icons.schedule_rounded, s.etaLabel),
              if (s.pickupAvailable)
                const _Meta(Icons.storefront_outlined, 'Pickup available'),
            ],
          ),
          if (s.address.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: AppColors.mute),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.address,
                    style: AppTextStyles.body(size: 13, color: AppColors.mute),
                  ),
                ),
              ],
            ),
          ],
          if (s.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              s.description,
              style: AppTextStyles.body(size: 14, height: 1.5),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.panel,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.assignment_return_outlined,
                    color: AppColors.shopper, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Returns & exchanges',
                          style: AppTextStyles.body(weight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        s.returnPolicy,
                        style: AppTextStyles.body(
                            size: 13, color: AppColors.mute, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.mute),
        const SizedBox(width: 4),
        Text(text, style: AppTextStyles.mono(size: 11)),
      ],
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.future});

  final Future<List<Review>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Review>>(
      future: future,
      builder: (context, snap) {
        final reviews = snap.data ?? const <Review>[];
        if (reviews.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What shoppers say', style: AppTextStyles.heading(size: 20)),
              const SizedBox(height: 12),
              for (final r in reviews)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          RatingBadge(rating: r.rating.toDouble()),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body(
                                  size: 13, weight: FontWeight.w700),
                            ),
                          ),
                          if (r.createdAt != null)
                            Text(formatDate(r.createdAt!),
                                style: AppTextStyles.mono(size: 10)),
                        ],
                      ),
                      if (r.comment.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(r.comment,
                            style: AppTextStyles.body(size: 13, height: 1.45)),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
