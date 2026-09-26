import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/pricing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/colour_names.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/drip_chip.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/rating_badge.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/swipe_action_bar.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/fashion_category.dart';
import '../../data/models/product.dart';
import '../../data/models/store.dart';
import '../../navigation.dart';
import '../../state/cart_controller.dart';
import '../../state/catalog_controller.dart';
import '../checkout/checkout_screen.dart';
import 'widgets/add_to_cart_flow.dart';
import 'widgets/product_card.dart';

/// Live product page: stock updates in real time from Firestore.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initial,
    this.heroTag,
  });

  final String productId;
  final Product? initial;
  final String? heroTag;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final CatalogController _catalog = context.read<CatalogController>();
  late final Stream<Product?> _stream =
      _catalog.repository.watchProduct(widget.productId);
  Future<Store?>? _storeFuture;
  String? _size;
  String? _colour;
  bool _sizeError = false;

  Store? _storeFor(Product p) {
    final cached = _catalog.storeById(p.storeId);
    if (cached != null) return cached;
    _storeFuture ??= _catalog.repository.fetchStore(p.storeId);
    return null;
  }

  CartItem? _buildItem(Product p, Store? store) {
    if (!p.inStock) {
      showSnackMessage('This product is sold out.');
      return null;
    }
    final size = _size;
    if (size == null) {
      setState(() => _sizeError = true);
      showSnackMessage('Select a size first.');
      return null;
    }
    if (p.stockFor(size) <= 0) {
      showSnackMessage('Size $size just sold out. Pick another size.');
      setState(() => _size = null);
      return null;
    }
    return CartItem.fromProduct(
      p,
      size: size,
      color: _colour ?? (p.colors.length == 1 ? p.colors.first : null),
      storeDeliveryFee: store?.deliveryFee ?? PricingRules.defaultDeliveryFee,
    );
  }

  void showSnackMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addToCart(Product p, Store? store) async {
    final item = _buildItem(p, store);
    if (item == null) return;
    await addToCartWithFeedback(context, item);
  }

  Future<void> _buyNow(Product p, Store? store) async {
    final item = _buildItem(p, store);
    if (item == null) return;
    final cart = context.read<CartController>();
    final alreadyIn = cart.quantityOf(item.productId, item.size, item.color) > 0;
    final added = alreadyIn || await addToCartWithFeedback(context, item, quiet: true);
    if (added && mounted) {
      AppNav.push(context, const CheckoutScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Product?>(
      stream: _stream,
      initialData: widget.initial,
      builder: (context, snap) {
        final product = snap.data;
        if (product == null) {
          final waiting = snap.connectionState == ConnectionState.waiting ||
              snap.connectionState == ConnectionState.none;
          return Scaffold(
            appBar: AppBar(backgroundColor: AppColors.ink),
            body: snap.hasError
                ? const ErrorState(message: 'Couldn\'t load this product.')
                : waiting
                    ? const CenteredLoader()
                    : const EmptyState(
                        icon: Icons.checkroom_outlined,
                        title: 'No longer available',
                        message: 'The store has removed this product.',
                      ),
          );
        }

        final cached = _storeFor(product);
        if (cached != null) return _page(product, cached);
        return FutureBuilder<Store?>(
          future: _storeFuture,
          builder: (context, s) => _page(product, s.data),
        );
      },
    );
  }

  Widget _page(Product p, Store? store) {
    // Drop a selection that became invalid after a live stock update.
    if (_size != null && !p.sizes.containsKey(_size)) _size = null;
    if (_colour == null && p.colors.isNotEmpty) _colour = p.colors.first;

    final heroTag = widget.heroTag ?? 'product-detail-${p.id}';
    final width = MediaQuery.sizeOf(context).width;
    final selectedStock = _size == null ? null : p.stockFor(_size!);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: width * 1.15,
            backgroundColor: AppColors.ink,
            surfaceTintColor: Colors.transparent,
            foregroundColor: AppColors.paper,
            actions: [
              WishlistButton(product: p, size: 36),
              IconButton(
                tooltip: 'Cart',
                onPressed: () => AppNav.openCart(context),
                icon: const Icon(Icons.shopping_bag_outlined),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _Gallery(product: p, heroTag: heroTag),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (p.brand.isNotEmpty ? p.brand : p.storeName).toUpperCase(),
                    style: AppTextStyles.mono(size: 11, color: AppColors.shopper),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(p.name,
                            style: AppTextStyles.heading(size: 25)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatInr(p.price),
                              style: AppTextStyles.heading(
                                  size: 25, weight: FontWeight.w600)),
                          if (p.mrp != null && p.mrp! > p.price)
                            Text(
                              formatInr(p.mrp!),
                              style: AppTextStyles.body(
                                size: 13,
                                color: AppColors.mute,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  if (p.discountPercent > 0) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${p.discountPercent}% OFF',
                          style: AppTextStyles.mono(
                            size: 10.5,
                            weight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text('Inclusive of all taxes',
                      style: AppTextStyles.mono(size: 10)),
                  const SizedBox(height: 16),
                  _StockLine(product: p, selectedStock: selectedStock),
                  if (p.colors.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Colour · ${_colour ?? ''}',
                        style: AppTextStyles.body(weight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in p.colors)
                          DripChip(
                            label: c,
                            swatch: swatchFor(c),
                            selected: _colour == c,
                            onTap: () => setState(() => _colour = c),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('Select size',
                      style: AppTextStyles.body(weight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  if (p.sizes.isEmpty)
                    Text('Sizes not listed by the store yet.',
                        style: AppTextStyles.body(size: 13, color: AppColors.mute))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final size in p.sizeLabels)
                          DripChip(
                            label: size,
                            selected: _size == size,
                            enabled: p.stockFor(size) > 0,
                            onTap: () => setState(() {
                              _size = size;
                              _sizeError = false;
                            }),
                          ),
                      ],
                    ),
                  if (_sizeError) ...[
                    const SizedBox(height: 8),
                    Text('Please select a size',
                        style: AppTextStyles.body(size: 12, color: AppColors.danger)),
                  ],
                  const SizedBox(height: 24),
                  _StoreTile(product: p, store: store),
                  const SizedBox(height: 12),
                  _InfoBlock(
                    icon: Icons.local_shipping_outlined,
                    title: store == null
                        ? 'Local delivery'
                        : 'Delivery in ${store.etaLabel}',
                    body: store == null
                        ? 'Delivered from a store near you.'
                        : [
                            store.deliveryFee == 0
                                ? 'Free delivery.'
                                : '${formatInr(store.deliveryFee)} delivery fee, free on orders over ${formatInr(PricingRules.freeDeliveryThreshold)}.',
                            if (store.pickupAvailable)
                              'Store pickup available.',
                          ].join(' '),
                  ),
                  const SizedBox(height: 12),
                  _InfoBlock(
                    icon: Icons.assignment_return_outlined,
                    title: 'Returns & exchanges',
                    body: store?.returnPolicy ??
                        'Returns and size exchanges per the store\'s policy.',
                  ),
                  if (p.description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('About this piece',
                        style: AppTextStyles.heading(size: 19)),
                    const SizedBox(height: 8),
                    Text(p.description,
                        style: AppTextStyles.body(size: 14, height: 1.55)),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    [categoryLabel(p.category), ...p.tags.take(4)].join('  ·  ').toUpperCase(),
                    style: AppTextStyles.mono(size: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          decoration: BoxDecoration(
            color: AppColors.ink,
            border: Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwipeActionBar(
                leftLabel: 'Add to cart',
                rightLabel: 'Buy now',
                enabled: p.inStock,
                disabledLabel: 'Sold out',
                onSwipeLeft: () => _addToCart(p, store),
                onSwipeRight: () => _buyNow(p, store),
              ),
              if (p.inStock)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Swipe ← to add to cart · swipe → to buy now',
                    style: AppTextStyles.mono(size: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.product, required this.heroTag});

  final Product product;
  final String heroTag;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final images = p.images.isEmpty ? <String?>[null] : p.images;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: images.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (context, i) {
            final image = DripImage(
              url: images[i],
              label: p.name,
              icon: categoryIcon(p.category),
            );
            return i == 0 ? Hero(tag: widget.heroTag, child: image) : image;
          },
        ),
        if (images.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.paper : AppColors.faint,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StockLine extends StatelessWidget {
  const _StockLine({required this.product, required this.selectedStock});

  final Product product;
  final int? selectedStock;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String text) = !product.inStock
        ? (Icons.block_rounded, AppColors.danger, 'Sold out in all sizes')
        : selectedStock != null && selectedStock! <= 3
            ? (Icons.local_fire_department_outlined, AppColors.warning,
                'Only $selectedStock left in this size')
            : (Icons.check_circle_outline, AppColors.success,
                'In stock at ${product.storeName}');
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: AppTextStyles.body(size: 13, color: color)),
        ),
      ],
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({required this.product, required this.store});

  final Product product;
  final Store? store;

  @override
  Widget build(BuildContext context) {
    final s = store;
    return Pressable(
      semanticLabel: 'Open ${product.storeName}',
      onTap: () => AppNav.openStore(context, product.storeId, initial: s),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            Icon(Icons.storefront_outlined, color: AppColors.shopper),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s?.name ?? product.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (s?.distanceKm != null) formatDistance(s!.distanceKm!),
                      if (s != null) s.etaLabel,
                      'View store',
                    ].join(' · '),
                    style: AppTextStyles.mono(size: 10.5),
                  ),
                ],
              ),
            ),
            if (s != null && s.hasRating) RatingBadge(rating: s.rating),
            Icon(Icons.chevron_right_rounded, color: AppColors.mute),
          ],
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.mute),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.body(weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(body,
                  style: AppTextStyles.body(
                      size: 13, color: AppColors.mute, height: 1.45)),
            ],
          ),
        ),
      ],
    );
  }
}
