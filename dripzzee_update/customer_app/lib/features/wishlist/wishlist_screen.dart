import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/product.dart';
import '../../data/models/wishlist_entry.dart';
import '../../navigation.dart';
import '../../state/catalog_controller.dart';
import '../../state/shell_controller.dart';
import '../../state/wishlist_controller.dart';
import '../catalog/widgets/product_card.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistController>();
    final entries = wishlist.entries;

    final Widget body;
    if (wishlist.loading) {
      body = const CenteredLoader();
    } else if (wishlist.error != null) {
      body = ErrorState(message: wishlist.error!);
    } else if (entries.isEmpty) {
      body = EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'Nothing saved yet',
        message: 'Tap the heart on any piece to keep it here. We\'ll tell you when sold-out sizes come back.',
        actionLabel: 'Discover styles',
        onAction: () => context.read<ShellController>().goTo(ShellTab.home),
      );
    } else {
      final width = MediaQuery.sizeOf(context).width;
      final tileWidth = (width - 16 * 2 - 12) / 2;
      body = GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
          mainAxisExtent: productTileExtent(context, tileWidth),
        ),
        itemCount: entries.length,
        itemBuilder: (context, i) => _WishlistTile(entry: entries[i]),
      );
    }

    return Scaffold(
      appBar: dripAppBar(
        title: entries.isEmpty ? 'Saved' : 'Saved · ${entries.length}',
        automaticallyImplyLeading: false,
      ),
      body: body,
    );
  }
}

class _WishlistTile extends StatelessWidget {
  const _WishlistTile({required this.entry});

  final WishlistEntry entry;

  @override
  Widget build(BuildContext context) {
    // Prefer live data (price/stock) when the product is nearby.
    final live = context.select<CatalogController, Product?>((c) {
      for (final p in c.products) {
        if (p.id == entry.productId) return p;
      }
      return null;
    });
    final heroTag = 'saved-${entry.productId}';

    if (live != null) return ProductCard(product: live, heroTag: heroTag);

    return Pressable(
      onTap: () => AppNav.openProduct(context, entry.productId, heroTag: heroTag),
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
                    url: entry.imageUrl,
                    label: entry.name,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: IconButton.filledTonal(
                    tooltip: 'Remove',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.ink.withValues(alpha: 0.6),
                    ),
                    icon: Icon(Icons.favorite_rounded,
                        color: AppColors.shopper, size: 18),
                    onPressed: () async {
                      try {
                        await context
                            .read<WishlistController>()
                            .remove(entry.productId);
                      } catch (_) {
                        if (context.mounted) {
                          showSnack(context, 'Couldn\'t remove. Try again.',
                              error: true);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.storeName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.mono(size: 10),
          ),
          const SizedBox(height: 2),
          Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body(size: 13, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(formatInr(entry.price),
              style: AppTextStyles.body(size: 14, weight: FontWeight.w800)),
          Text('Outside your current area',
              maxLines: 1, style: AppTextStyles.mono(size: 10)),
        ],
      ),
    );
  }
}
