import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/drip_chip.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/text_field.dart';
import '../../data/models/order.dart';
import '../../data/models/product.dart';
import '../../data/models/return_request.dart';
import '../../data/repositories/return_repository.dart';
import '../../state/catalog_controller.dart';

const _reasons = [
  'Size doesn\'t fit',
  'Looks different from photos',
  'Damaged or defective',
  'Wrong item received',
  'Quality not as expected',
  'Changed my mind',
];
const _needsDetails = {'Damaged or defective', 'Wrong item received'};

class ReturnRequestScreen extends StatefulWidget {
  const ReturnRequestScreen({super.key, required this.order});

  final DripOrder order;

  @override
  State<ReturnRequestScreen> createState() => _ReturnRequestScreenState();
}

class _ReturnRequestScreenState extends State<ReturnRequestScreen> {
  String _type = 'RETURN';
  String? _reason;
  final Set<int> _selected = {};
  final Map<int, String> _exchangeSize = {};
  final _details = TextEditingController();
  late final Future<List<Product>> _products = context
      .read<CatalogController>()
      .repository
      .fetchProductsByIds(widget.order.items.map((i) => i.productId).toList());
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_selected.isEmpty) return 'Select at least one item.';
    if (_reason == null) return 'Choose a reason.';
    if (_type == 'EXCHANGE' &&
        _selected.any((i) => _exchangeSize[i] == null)) {
      return 'Pick the size you want for each exchanged item.';
    }
    if (_needsDetails.contains(_reason) && _details.text.trim().length < 10) {
      return 'Please describe the problem (at least 10 characters).';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final items = [
      for (final i in _selected)
        ReturnRequestItem(
          productId: widget.order.items[i].productId,
          name: widget.order.items[i].name,
          size: widget.order.items[i].size,
          quantity: widget.order.items[i].quantity,
          exchangeSize: _type == 'EXCHANGE' ? _exchangeSize[i] : null,
        ),
    ];
    try {
      await context.read<ReturnRepository>().submit(
            order: widget.order,
            type: _type,
            items: items,
            reason: _reason!,
            details: _details.text,
          );
      if (!mounted) return;
      showSnack(context, 'Request sent to ${widget.order.storeName}.');
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.code == 'permission-denied'
            ? 'This order isn\'t eligible — the return window may have closed or a request already exists.'
            : 'Couldn\'t send your request. Check your connection and try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Couldn\'t send your request. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    return Scaffold(
      appBar: dripAppBar(title: 'Return or exchange'),
      body: FutureBuilder<List<Product>>(
        future: _products,
        builder: (context, snap) {
          final products = {for (final p in snap.data ?? const <Product>[]) p.id: p};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (_error != null) ...[
                InlineNotice(message: _error!),
                const SizedBox(height: 16),
              ],
              Text('What would you like?', style: AppTextStyles.heading(size: 19)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  DripChip(
                    label: 'Return for refund',
                    selected: _type == 'RETURN',
                    onTap: () => setState(() => _type = 'RETURN'),
                  ),
                  DripChip(
                    label: 'Exchange size',
                    selected: _type == 'EXCHANGE',
                    onTap: () => setState(() => _type = 'EXCHANGE'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Select items', style: AppTextStyles.heading(size: 19)),
              const SizedBox(height: 10),
              for (var i = 0; i < o.items.length; i++)
                _ItemTile(
                  item: o.items[i],
                  selected: _selected.contains(i),
                  onTap: () => setState(() {
                    if (!_selected.remove(i)) _selected.add(i);
                  }),
                  exchangeSizes: _type == 'EXCHANGE' && _selected.contains(i)
                      ? (products[o.items[i].productId]?.sizeLabels
                              .where((s) =>
                                  s != o.items[i].size &&
                                  (products[o.items[i].productId]?.stockFor(s) ?? 0) > 0)
                              .toList() ??
                          const <String>[])
                      : null,
                  loadingSizes: snap.connectionState == ConnectionState.waiting,
                  pickedSize: _exchangeSize[i],
                  onPickSize: (s) => setState(() => _exchangeSize[i] = s),
                ),
              const SizedBox(height: 20),
              Text('Reason', style: AppTextStyles.heading(size: 19)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in _reasons)
                    DripChip(
                      label: r,
                      selected: _reason == r,
                      onTap: () => setState(() => _reason = r),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              AppTextField(
                controller: _details,
                label: _needsDetails.contains(_reason)
                    ? 'Describe the problem'
                    : 'Anything else? (optional)',
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: 8),
              Text(
                'Items should be unused with original tags. The store reviews '
                'your request per its policy; you\'ll get a notification when it\'s decided.',
                style: AppTextStyles.body(size: 12, color: AppColors.mute),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Submit request',
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.exchangeSizes,
    required this.loadingSizes,
    required this.pickedSize,
    required this.onPickSize,
  });

  final OrderItem item;
  final bool selected;
  final VoidCallback onTap;
  final List<String>? exchangeSizes;
  final bool loadingSizes;
  final String? pickedSize;
  final ValueChanged<String> onPickSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.shopperSoft : AppColors.panel,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: selected ? AppColors.shopper : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: selected ? AppColors.shopper : AppColors.mute,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            style: AppTextStyles.body(weight: FontWeight.w700)),
                        Text('Size ${item.size} · Qty ${item.quantity}',
                            style: AppTextStyles.mono(size: 10.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (exchangeSizes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: loadingSizes
                  ? Text('Checking available sizes…',
                      style: AppTextStyles.mono(size: 11))
                  : exchangeSizes!.isEmpty
                      ? Text('No other sizes in stock right now — choose a return instead.',
                          style: AppTextStyles.body(size: 12, color: AppColors.warning))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in exchangeSizes!)
                              DripChip(
                                label: s,
                                selected: pickedSize == s,
                                onTap: () => onPickSize(s),
                              ),
                          ],
                        ),
            ),
        ],
      ),
    );
  }
}
