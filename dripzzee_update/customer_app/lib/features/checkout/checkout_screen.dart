import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/pricing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/drip_image.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/pressable.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/address.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/coupon.dart';
import '../../data/models/order.dart';
import '../../data/repositories/coupon_repository.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/services/payment_service.dart';
import '../../navigation.dart';
import '../../state/auth_controller.dart';
import '../../state/cart_controller.dart';
import '../../state/catalog_controller.dart';
import '../campaigns/campaign.dart';
import '../cart/bill_summary.dart';
import '../cart/cart_screen.dart';
import '../catalog/widgets/product_card.dart';
import 'address_form_screen.dart';
import 'addresses_screen.dart';

/// Address → items (+ recommendations) → coupon → payment → place order.
///
/// Guarantees: one tap = at most one order (idempotent requestId + a
/// "placing" lock), and "Order placed" is only shown for an order the server
/// actually created and (for online payments) verified. Coupons are checked
/// here for display and enforced again by the server.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final String _uid = context.read<AuthController>().uid!;
  late final Stream<List<Address>> _addresses =
      context.read<UserRepository>().watchAddresses(_uid);
  late final Future<List<Coupon>> _available = context
      .read<CouponRepository>()
      .fetchAvailable()
      .catchError((_) => <Coupon>[]);
  late String _requestId = _newRequestId();
  String? _selectedAddressId;
  String _method = 'razorpay';
  bool _placing = false;
  String _stage = '';
  String? _error;

  final _couponField = TextEditingController();
  Coupon? _coupon;
  String? _couponError;
  bool _checkingCoupon = false;

  @override
  void dispose() {
    _couponField.dispose();
    super.dispose();
  }

  String _newRequestId() {
    final rand = Random.secure().nextInt(1 << 30).toRadixString(36);
    return '${_uid.substring(0, min(6, _uid.length))}'
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$rand';
  }

  Address? _pick(List<Address> list) {
    if (list.isEmpty) return null;
    for (final a in list) {
      if (a.id == _selectedAddressId) return a;
    }
    return list.firstWhere((a) => a.isDefault, orElse: () => list.first);
  }

  void _setStage(String stage) {
    if (mounted) setState(() => _stage = stage);
  }

  Future<void> _applyCoupon([String? code]) async {
    final cart = context.read<CartController>();
    final typed = (code ?? _couponField.text).trim().toUpperCase();
    if (typed.isEmpty) {
      setState(() => _couponError = 'Enter a coupon code.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _checkingCoupon = true;
      _couponError = null;
    });
    try {
      final coupon = await context.read<CouponRepository>().find(typed);
      if (!mounted) return;
      final problem = coupon == null
          ? 'That code doesn\'t exist.'
          : coupon.problemFor(subtotal: cart.subtotal, storeId: cart.storeId!);
      setState(() {
        _checkingCoupon = false;
        if (problem != null) {
          _couponError = problem;
        } else {
          _coupon = coupon;
          _couponField.text = coupon!.code;
          HapticFeedback.lightImpact();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _checkingCoupon = false;
          _couponError = 'Couldn\'t check the coupon. Try again.';
        });
      }
    }
  }

  void _removeCoupon() => setState(() {
        _coupon = null;
        _couponError = null;
        _couponField.clear();
      });

  Future<void> _placeOrder(Address? address, Coupon? validCoupon) async {
    if (_placing) return;
    final cart = context.read<CartController>();
    if (cart.isEmpty) return;
    if (address == null) {
      showSnack(context, 'Add a delivery address to continue.', error: true);
      return;
    }
    final orders = context.read<OrderRepository>();
    final payments = context.read<PaymentService>();
    final email = context.read<AuthController>().email;

    setState(() {
      _placing = true;
      _error = null;
      _stage = 'Checking stock with ${cart.storeName ?? 'the store'}…';
    });

    String? createdOrderId;
    try {
      final result = await orders.createOrder(
        requestId: _requestId,
        storeId: cart.storeId!,
        items: cart.items,
        address: address,
        paymentMethod: _method,
        couponCode: validCoupon?.code,
      );
      createdOrderId = result.orderId;

      if (!result.needsPayment) {
        cart.clear();
        if (mounted) AppNav.showPlacedOrder(context, result.orderId);
        return;
      }

      _setStage('Waiting for payment…');
      final outcome = await payments.checkout(
        keyId: result.razorpayKeyId!,
        razorpayOrderId: result.razorpayOrderId!,
        amountPaise: result.amountPaise ?? result.total * 100,
        description: 'Order from ${cart.storeName ?? 'Dripzzee'}',
        email: email,
        contact: address.phone,
        customerName: address.name,
      );

      if (outcome is PaymentSucceeded) {
        _setStage('Confirming your payment…');
        try {
          await orders.verifyPayment(
            orderId: result.orderId,
            razorpayPaymentId: outcome.paymentId,
            razorpayOrderId: outcome.orderId,
            razorpaySignature: outcome.signature,
          );
        } on CheckoutFailure {
          // The order screen shows the real server state; the backend
          // re-checks with Razorpay and confirms or refunds automatically.
        }
        cart.clear();
        if (mounted) AppNav.showPlacedOrder(context, result.orderId);
        return;
      }

      final reason = outcome is PaymentCancelled ? 'cancelled' : 'failed';
      _setStage('Releasing your items…');
      final status = await orders.reportPaymentFailure(
        orderId: result.orderId,
        reason: reason,
      );
      if (status == OrderStatus.placed) {
        cart.clear();
        if (mounted) AppNav.showPlacedOrder(context, result.orderId);
        return;
      }
      _requestId = _newRequestId();
      if (mounted) {
        setState(() => _error = outcome is PaymentFailed
            ? '${outcome.message} No money was taken for this order — your cart is saved.'
            : 'Payment cancelled. Your cart is saved — try again when ready.');
      }
    } on CheckoutFailure catch (e) {
      // Keep the same idempotency key after network errors so a retry can't
      // create a duplicate order; rotate it once the server has answered.
      if (createdOrderId != null || e.definitelyRejected) {
        _requestId = _newRequestId();
      }
      if (mounted) {
        setState(() => _error = e.message);
        try {
          await validateCartWithServer(context);
        } catch (_) {}
      }
    } finally {
      if (mounted) {
        setState(() {
          _placing = false;
          _stage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    if (cart.isEmpty) {
      return Scaffold(
        appBar: dripAppBar(title: 'Checkout'),
        body: const EmptyState(
          icon: Icons.shopping_bag_outlined,
          title: 'Your bag is empty',
          message: 'Add something to your bag to check out.',
        ),
      );
    }

    final catalog = context.watch<CatalogController>();
    final store = catalog.storeById(cart.storeId!);
    final couponProblem =
        _coupon?.problemFor(subtotal: cart.subtotal, storeId: cart.storeId!);
    final validCoupon = couponProblem == null ? _coupon : null;
    final bill = PricingRules.breakdown(
      subtotal: cart.subtotal,
      storeDeliveryFee: cart.items.first.storeDeliveryFee,
      discount: validCoupon?.discountFor(cart.subtotal) ?? 0,
    );
    final codAllowed = bill.total <= PricingRules.codLimit;
    if (!codAllowed && _method == 'cod') _method = 'razorpay';

    final inCart = {for (final i in cart.items) i.productId};
    final recommendations = catalog
        .storeProducts(cart.storeId!)
        .where((p) => p.inStock && !inCart.contains(p.id))
        .take(10)
        .toList();

    Widget pad(Widget child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: child,
        );

    return PopScope(
      canPop: !_placing,
      child: StreamBuilder<List<Address>>(
        stream: _addresses,
        builder: (context, snap) {
          final addresses = snap.data ?? const <Address>[];
          final address = _pick(addresses);
          final loadingAddresses = !snap.hasData && !snap.hasError;

          return Stack(
            children: [
              Scaffold(
                appBar: dripAppBar(title: 'Checkout'),
                body: ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  children: [
                    if (_error != null)
                      pad(Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InlineNotice(message: _error!),
                      )),
                    pad(_EtaCard(
                      storeName: cart.storeName ?? 'the store',
                      minMinutes: store?.minDeliveryMinutes ?? 30,
                      maxMinutes: store?.maxDeliveryMinutes ?? 60,
                    )),
                    const SizedBox(height: 22),
                    pad(const _SectionTitle('Deliver to')),
                    if (loadingAddresses)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: CenteredLoader(),
                      )
                    else if (address == null)
                      pad(SecondaryButton(
                        label: 'Add delivery address',
                        icon: Icons.add_location_alt_outlined,
                        onPressed: _placing
                            ? null
                            : () async {
                                final saved = await AppNav.push<Address>(
                                    context, const AddressFormScreen());
                                if (saved != null && mounted) {
                                  setState(() => _selectedAddressId = saved.id);
                                }
                              },
                      ))
                    else
                      pad(_AddressCard(
                        address: address,
                        onChange: _placing
                            ? null
                            : () async {
                                final picked = await AppNav.push<Address>(
                                  context,
                                  AddressesScreen(
                                      selectedId: address.id, selectMode: true),
                                );
                                if (picked != null && mounted) {
                                  setState(() => _selectedAddressId = picked.id);
                                }
                              },
                      )),
                    const SizedBox(height: 24),
                    pad(_SectionTitle('Your items · ${cart.storeName}')),
                    for (final i in cart.items) pad(_ItemRow(item: i)),
                    if (recommendations.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      pad(Text('Add more from ${cart.storeName}',
                          style: AppTextStyles.body(weight: FontWeight.w800))),
                      pad(Text('SAME STORE · SAME DELIVERY',
                          style: AppTextStyles.mono(size: 10))),
                      const SizedBox(height: 12),
                      ProductRail(
                        products: recommendations,
                        heroPrefix: 'checkout-rec',
                      ),
                    ],
                    const SizedBox(height: 24),
                    pad(const _SectionTitle('Offers')),
                    pad(_CouponBox(
                      controller: _couponField,
                      applied: _coupon,
                      problem: couponProblem,
                      error: _couponError,
                      saving: bill.discount,
                      checking: _checkingCoupon,
                      available: _available,
                      subtotal: cart.subtotal,
                      storeId: cart.storeId!,
                      onApply: _placing ? null : _applyCoupon,
                      onRemove: _placing ? null : _removeCoupon,
                    )),
                    const SizedBox(height: 24),
                    pad(const _SectionTitle('Payment method')),
                    pad(_MethodTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Pay online',
                      subtitle: 'UPI, debit/credit cards, net banking · via Razorpay',
                      selected: _method == 'razorpay',
                      onTap: _placing
                          ? null
                          : () => setState(() => _method = 'razorpay'),
                    )),
                    pad(_MethodTile(
                      icon: Icons.payments_outlined,
                      title: 'Cash on delivery',
                      subtitle: codAllowed
                          ? 'Pay the rider in cash or UPI'
                          : 'Available on orders up to ${formatInr(PricingRules.codLimit)}',
                      selected: _method == 'cod',
                      enabled: codAllowed,
                      onTap: _placing || !codAllowed
                          ? null
                          : () => setState(() => _method = 'cod'),
                    )),
                    const SizedBox(height: 20),
                    pad(BillSummary(breakdown: bill)),
                    const SizedBox(height: 10),
                    pad(Text(
                      'By placing this order you agree to the store\'s return '
                      'policy. Stock is reserved for you while you pay.',
                      style: AppTextStyles.body(size: 12, color: AppColors.mute),
                    )),
                  ],
                ),
                bottomNavigationBar: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatInr(bill.total),
                                  style: AppTextStyles.heading(size: 22)),
                              Text(
                                bill.discount > 0
                                    ? 'You save ${formatInr(bill.discount)}'
                                    : 'Total to pay',
                                style: AppTextStyles.mono(
                                  size: 10.5,
                                  color: bill.discount > 0
                                      ? AppColors.success
                                      : AppColors.mute,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 6,
                          child: PrimaryButton(
                            label: _method == 'cod' ? 'Place order' : 'Pay now',
                            icon: _method == 'cod'
                                ? Icons.check_circle_outline_rounded
                                : Icons.lock_outline_rounded,
                            onPressed: address == null || _placing
                                ? null
                                : () => _placeOrder(address, validCoupon),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_placing) Positioned.fill(child: _PlacingOverlay(stage: _stage)),
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: AppTextStyles.heading(size: 19)),
      );
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address, required this.onChange});

  final Address address;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_outlined, color: AppColors.shopper),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${address.label} · ${address.name}',
                    style: AppTextStyles.body(weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(address.fullText,
                    style: AppTextStyles.body(
                        size: 13, color: AppColors.mute, height: 1.4)),
                const SizedBox(height: 4),
                Text(address.phone, style: AppTextStyles.mono(size: 11)),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: Text('Change',
                style: AppTextStyles.body(
                    size: 13, color: AppColors.shopper, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        enabled: enabled,
        child: Pressable(
          scale: 0.99,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected ? AppColors.shopperSoft : AppColors.panel,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? AppColors.shopper : AppColors.line,
              ),
            ),
            child: Row(
              children: [
                Icon(icon,
                    color: enabled ? AppColors.paper : AppColors.faint),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTextStyles.body(
                            weight: FontWeight.w700,
                            color: enabled ? AppColors.paper : AppColors.faint,
                          )),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: AppTextStyles.body(
                              size: 12, color: AppColors.mute)),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.shopper : AppColors.faint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body(size: 14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    'Size ${item.size}',
                    if (item.color != null) item.color!,
                    'Qty ${item.quantity}',
                  ].join(' · '),
                  style: AppTextStyles.mono(size: 10.5),
                ),
                const SizedBox(height: 6),
                Text(formatInr(item.lineTotal),
                    style: AppTextStyles.body(size: 15, weight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            height: 64,
            child: DripImage(
              url: item.imageUrl,
              label: item.name,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estimated delivery with a little rider travelling store → home.
class _EtaCard extends StatelessWidget {
  const _EtaCard({
    required this.storeName,
    required this.minMinutes,
    required this.maxMinutes,
  });

  final String storeName;
  final int minMinutes;
  final int maxMinutes;

  @override
  Widget build(BuildContext context) {
    final by = DateTime.now().add(Duration(minutes: maxMinutes));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.shopperDeep.withValues(alpha: AppColors.isLight ? 0.14 : 0.35),
            AppColors.panel,
          ],
        ),
        border: Border.all(color: AppColors.shopper.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: AppColors.marigold, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Arriving in $minMinutes–$maxMinutes min',
                  style: AppTextStyles.heading(size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Estimated by ${formatTime(by)} · from $storeName',
            style: AppTextStyles.body(size: 12, color: AppColors.mute),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: LoopingScene(
              active: true,
              duration: const Duration(milliseconds: 2800),
              staticValue: 0.55,
              builder: (context, t) => LayoutBuilder(
                builder: (context, box) {
                  final travel = box.maxWidth - 36 * 2 - 28;
                  final x = 36 + travel * Curves.easeInOut.transform(t);
                  final bob = sin(t * pi * 8) * 1.5;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 36,
                        right: 36,
                        top: 17,
                        child: Row(
                          children: [
                            for (var i = 0; i < 24; i++)
                              Expanded(
                                child: Container(
                                  height: 2,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  color: (i / 24) < t
                                      ? AppColors.shopper
                                      : AppColors.lineStrong,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 2,
                        child: Icon(Icons.storefront_rounded,
                            color: AppColors.shopper, size: 30),
                      ),
                      Positioned(
                        right: 0,
                        top: 2,
                        child: Icon(Icons.home_rounded,
                            color: AppColors.paper, size: 30),
                      ),
                      Positioned(
                        left: x,
                        top: 4 + bob,
                        child: const Icon(Icons.delivery_dining_rounded,
                            color: AppColors.marigold, size: 28),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponBox extends StatelessWidget {
  const _CouponBox({
    required this.controller,
    required this.applied,
    required this.problem,
    required this.error,
    required this.saving,
    required this.checking,
    required this.available,
    required this.subtotal,
    required this.storeId,
    required this.onApply,
    required this.onRemove,
  });

  final TextEditingController controller;
  final Coupon? applied;
  final String? problem;
  final String? error;
  final int saving;
  final bool checking;
  final Future<List<Coupon>> available;
  final int subtotal;
  final String storeId;
  final Future<void> Function([String? code])? onApply;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final coupon = applied;
    if (coupon != null) {
      final ok = problem == null;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: (ok ? AppColors.success : AppColors.warning).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: (ok ? AppColors.success : AppColors.warning).withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(ok ? Icons.local_offer_rounded : Icons.error_outline_rounded,
                color: ok ? AppColors.success : AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${coupon.code} applied',
                      style: AppTextStyles.body(weight: FontWeight.w800)),
                  Text(
                    ok ? 'You save ${formatInr(saving)} · ${coupon.title}' : problem!,
                    style: AppTextStyles.body(size: 12, color: AppColors.mute),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onRemove,
              child: Text('Remove',
                  style: AppTextStyles.body(
                      size: 13, weight: FontWeight.w700, color: AppColors.danger)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 52,
          padding: const EdgeInsets.only(left: 14, right: 4),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: error != null ? AppColors.danger : AppColors.line),
          ),
          child: Row(
            children: [
              Icon(Icons.local_offer_outlined, color: AppColors.shopper, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: onApply == null ? null : (_) => onApply!(),
                  style: AppTextStyles.body(size: 15, weight: FontWeight.w700)
                      .copyWith(letterSpacing: 1),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter coupon code',
                    hintStyle: AppTextStyles.body(size: 14, color: AppColors.faint),
                  ),
                ),
              ),
              TextButton(
                onPressed: checking || onApply == null ? null : () => onApply!(),
                child: checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Apply',
                        style: AppTextStyles.body(
                            weight: FontWeight.w800, color: AppColors.shopper)),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(error!,
                style: AppTextStyles.body(size: 12, color: AppColors.danger)),
          ),
        FutureBuilder<List<Coupon>>(
          future: available,
          builder: (context, snap) {
            final list = snap.data ?? const <Coupon>[];
            if (list.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in list)
                    _CouponChip(
                      coupon: c,
                      usable: c.problemFor(subtotal: subtotal, storeId: storeId) == null,
                      onTap: onApply == null ? null : () => onApply!(c.code),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _CouponChip extends StatelessWidget {
  const _CouponChip({required this.coupon, required this.usable, required this.onTap});

  final Coupon coupon;
  final bool usable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = usable ? AppColors.shopper : AppColors.faint;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(coupon.code,
                style: AppTextStyles.mono(size: 11, weight: FontWeight.w700, color: color)),
            Text(
              coupon.minOrder > 0
                  ? '${coupon.title} · min ${formatInr(coupon.minOrder)}'
                  : coupon.title,
              style: AppTextStyles.body(size: 11, color: AppColors.mute),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen progress while the order is being placed.
class _PlacingOverlay extends StatelessWidget {
  const _PlacingOverlay({required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.ink.withValues(alpha: 0.88),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.shopper,
                        backgroundColor: AppColors.shopperSoft,
                      ),
                    ),
                    Icon(Icons.shopping_bag_rounded,
                            color: AppColors.shopper, size: 38)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1.08, 1.08),
                          duration: 700.ms,
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  stage,
                  key: ValueKey(stage),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading(size: 20),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please keep the app open.',
                style: AppTextStyles.body(size: 13, color: AppColors.mute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
