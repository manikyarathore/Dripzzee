import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/cart_item.dart';
import '../../navigation.dart';
import '../../state/cart_controller.dart';
import '../../state/catalog_controller.dart';
import '../../state/shell_controller.dart';
import '../checkout/checkout_screen.dart';
import 'bill_summary.dart';

/// Re-checks stock/prices against Firestore. Returns true if checkout can
/// continue unchanged.
Future<bool> validateCartWithServer(BuildContext context) async {
  final cart = context.read<CartController>();
  final repo = context.read<CatalogController>().repository;
  final fresh =
      await repo.fetchProductsByIds(cart.items.map((i) => i.productId).toList());
  final notes = cart.reconcile(fresh);
  if (notes.isEmpty) return true;
  if (context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel,
        surfaceTintColor: Colors.transparent,
        title: Text('Your cart was updated', style: AppTextStyles.heading(size: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final n in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $n',
                    style: AppTextStyles.body(size: 13, color: AppColors.mute)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Review cart',
                style: AppTextStyles.body(
                    color: AppColors.shopper, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
  return false;
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _checking = false;

  Future<void> _checkout() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final ok = await validateCartWithServer(context);
      if (!mounted) return;
      if (ok && !context.read<CartController>().isEmpty) {
        AppNav.push(context, const CheckoutScreen());
      }
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Couldn\'t check stock. Check your connection.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();

    if (cart.isEmpty) {
      return Scaffold(
        appBar: dripAppBar(title: 'Your cart'),
        body: EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Your cart is empty',
          message: 'Find something you love from stores around you.',
          actionLabel: 'Start exploring',
          onAction: () {
            context.read<ShellController>().goTo(ShellTab.home);
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      );
    }

    final bill = cart.breakdown;
    final store = context.read<CatalogController>().storeById(cart.storeId!);

    return Scaffold(
      appBar: dripAppBar(
        title: 'Your cart',
        actions: [
          TextButton(
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Clear cart?',
                message: 'This removes all items from your cart.',
                confirmLabel: 'Clear',
                destructive: true,
              );
              if (ok && context.mounted) context.read<CartController>().clear();
            },
            child: Text('Clear',
                style: AppTextStyles.body(color: AppColors.mute, weight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => AppNav.openStore(context, cart.storeId!, initial: store),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.storefront_outlined, color: AppColors.shopper),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cart.storeName ?? '',
                            style: AppTextStyles.heading(size: 19)),
                        if (store != null)
                          Text(
                            [
                              if (store.distanceKm != null)
                                formatDistance(store.distanceKm!),
                              'Delivery in ${store.etaLabel}',
                            ].join(' · '),
                            style: AppTextStyles.mono(size: 11),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.mute),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final item in cart.items) _CartLine(item: item),
          const SizedBox(height: 8),
          if (bill.amountToFreeDelivery > 0)
            InlineNotice(
              error: false,
              icon: Icons.local_shipping_outlined,
              message:
                  'Add ${formatInr(bill.amountToFreeDelivery)} more for free delivery.',
            ),
          const SizedBox(height: 16),
          BillSummary(breakdown: bill),
          const SizedBox(height: 12),
          Text(
            'Orders ship from one store at a time. Final amounts are confirmed '
            'by the server at checkout.',
            style: AppTextStyles.body(size: 12, color: AppColors.mute),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: PrimaryButton(
            label: 'Checkout · ${formatInr(bill.total)}',
            loading: _checking,
            onPressed: _checkout,
          ),
        ),
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartController>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => AppNav.openProduct(context, item.productId),
            child: SizedBox(
              width: 72,
              height: 92,
              child: DripImage(
                url: item.imageUrl,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  [
                    'Size ${item.size}',
                    if (item.color != null) item.color!,
                  ].join(' · '),
                  style: AppTextStyles.mono(size: 11),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(formatInr(item.lineTotal),
                          style: AppTextStyles.body(
                              size: 15, weight: FontWeight.w800)),
                    ),
                    QuantityStepper(
                      quantity: item.quantity,
                      max: item.maxStock,
                      onChanged: (q) => cart.setQuantity(item.key, q),
                    ),
                  ],
                ),
                if (item.quantity >= item.maxStock)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Max available: ${item.maxStock}',
                        style: AppTextStyles.mono(
                            size: 10, color: AppColors.warning)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.max,
    required this.onChanged,
  });

  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tip, VoidCallback? onTap) => SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            tooltip: tip,
            padding: EdgeInsets.zero,
            iconSize: 18,
            color: AppColors.shopper,
            disabledColor: AppColors.faint,
            onPressed: onTap,
            icon: Icon(icon),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.shopper.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            quantity <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
            quantity <= 1 ? 'Remove' : 'Decrease',
            () => onChanged(quantity - 1),
          ),
          SizedBox(
            width: 24,
            child: Text('$quantity',
                textAlign: TextAlign.center,
                style: AppTextStyles.body(weight: FontWeight.w800)),
          ),
          button(
            Icons.add_rounded,
            'Increase',
            quantity >= max ? null : () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

