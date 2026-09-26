import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/drip_image.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/pressable.dart';
import '../../../data/models/fashion_category.dart';
import '../../../data/models/product.dart';
import '../../../navigation.dart';
import '../../../state/catalog_controller.dart';
import '../../../state/wishlist_controller.dart';

/// Height of a product tile for a given width (image 3:4 + text block that
/// grows with the user's text scale, so grids and rails never overflow).
double productTileExtent(BuildContext context, double width) =>
    width * 4 / 3 + MediaQuery.textScalerOf(context).scale(84) + 8;

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.heroTag,
    this.showStore = true,
  });

  final Product product;

  /// Must be unique per screen (prefix it with the section name).
  final String heroTag;
  final bool showStore;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final distance = context.select<CatalogController, double?>(
      (c) => c.distanceTo(p.storeId),
    );

    return Pressable(
      semanticLabel: '${p.name}, ${formatInr(p.price)}',
      onTap: () => AppNav.openProduct(context, p.id, initial: p, heroTag: heroTag),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: heroTag,
                  child: DripImage(
                    url: p.primaryImage,
                    label: p.name,
                    icon: categoryIcon(p.category),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                if (!p.inStock)
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: Text('SOLD OUT',
                        style: AppTextStyles.mono(
                            size: 11,
                            color: AppColors.paper,
                            weight: FontWeight.w700)),
                  ),
                if (p.discountPercent > 0 && p.inStock)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _Badge(text: '${p.discountPercent}% OFF'),
                  )
                else if (p.isNewArrival && p.inStock)
                  const Positioned(left: 8, top: 8, child: _Badge(text: 'NEW')),
                Positioned(
                  right: 6,
                  top: 6,
                  child: WishlistButton(product: p),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (showStore)
            Text(
              p.brand.isNotEmpty ? p.brand.toUpperCase() : p.storeName.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.mono(size: 10),
            ),
          const SizedBox(height: 2),
          Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(size: 13, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                formatInr(p.price),
                style: AppTextStyles.body(size: 14, weight: FontWeight.w800),
              ),
              if (p.mrp != null && p.mrp! > p.price) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    formatInr(p.mrp!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      size: 11,
                      color: AppColors.mute,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (distance != null && showStore) ...[
            const SizedBox(height: 2),
            Text(
              '${formatDistance(distance)} · ${p.storeName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.mono(size: 10),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.shopper.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: AppTextStyles.mono(
            size: 9, color: AppColors.shopper, weight: FontWeight.w700),
      ),
    );
  }
}

class WishlistButton extends StatelessWidget {
  const WishlistButton({super.key, required this.product, this.size = 34});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context) {
    final saved = context.select<WishlistController, bool>(
      (w) => w.isSaved(product.id),
    );
    return Semantics(
      button: true,
      toggled: saved,
      label: saved ? 'Remove from wishlist' : 'Save to wishlist',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          try {
            final nowSaved =
                await context.read<WishlistController>().toggle(product);
            if (context.mounted) {
              showSnack(
                context,
                nowSaved ? 'Saved to your wishlist' : 'Removed from wishlist',
              );
            }
          } catch (_) {
            if (context.mounted) {
              showSnack(context, 'Couldn\'t update your wishlist. Try again.',
                  error: true);
            }
          }
        },
        child: Container(
          width: size + 10,
          height: size + 10,
          alignment: Alignment.center,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.ink.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: Icon(
                saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(saved),
                size: size * 0.52,
                color: saved ? AppColors.shopper : AppColors.paper,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal product rail used on Home and Store detail.
class ProductRail extends StatelessWidget {
  const ProductRail({
    super.key,
    required this.products,
    required this.heroPrefix,
  });

  final List<Product> products;
  final String heroPrefix;

  static const _cardWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: productTileExtent(context, _cardWidth),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => SizedBox(
          width: _cardWidth,
          child: ProductCard(
            product: products[i],
            heroTag: '$heroPrefix-${products[i].id}',
          ),
        ),
      ),
    );
  }
}

/// Two-column product grid as a sliver.
class ProductGridSliver extends StatelessWidget {
  const ProductGridSliver({
    super.key,
    required this.products,
    required this.heroPrefix,
    this.showStore = true,
  });

  final List<Product> products;
  final String heroPrefix;
  final bool showStore;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tileWidth = (width - 16 * 2 - 12) / 2;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          mainAxisExtent: productTileExtent(context, tileWidth),
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => ProductCard(
            product: products[i],
            heroTag: '$heroPrefix-${products[i].id}',
            showStore: showStore,
          ),
          childCount: products.length,
        ),
      ),
    );
  }
}
