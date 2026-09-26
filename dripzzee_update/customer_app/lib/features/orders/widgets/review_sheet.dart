import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/text_field.dart';
import '../../../data/models/order.dart';
import '../../../data/repositories/review_repository.dart';
import '../../../state/auth_controller.dart';

/// Returns true when a review was submitted.
Future<bool> showReviewSheet(BuildContext context, DripOrder order) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReviewSheet(order: order),
  );
  return result ?? false;
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.order});
  final DripOrder order;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 0;
  final _comment = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Tap a star to rate.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final name = (context.read<AuthController>().user?.displayName ?? '')
        .trim()
        .split(' ')
        .first;
    try {
      await context.read<ReviewRepository>().submit(
            order: widget.order,
            rating: _rating,
            comment: _comment.text,
            customerName: name,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Couldn\'t submit. You may have already reviewed this order.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Rate ${widget.order.storeName}',
              style: AppTextStyles.heading(size: 22)),
          const SizedBox(height: 6),
          Text('Your rating helps other shoppers find great local stores.',
              style: AppTextStyles.body(size: 13, color: AppColors.mute)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  iconSize: 36,
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i <= _rating ? AppColors.marigold : AppColors.faint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: _comment,
            label: 'Tell us more (optional)',
            maxLines: 3,
            maxLength: 300,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: AppTextStyles.body(size: 12, color: AppColors.danger)),
            ),
          PrimaryButton(label: 'Submit review', loading: _saving, onPressed: _submit),
        ],
      ),
    );
  }
}
