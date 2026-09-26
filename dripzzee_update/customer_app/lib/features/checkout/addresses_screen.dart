import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/address.dart';
import '../../data/repositories/user_repository.dart';
import '../../navigation.dart';
import '../../state/auth_controller.dart';
import 'address_form_screen.dart';

/// Manage saved addresses. In [selectMode] tapping an address returns it.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key, this.selectMode = false, this.selectedId});

  final bool selectMode;
  final String? selectedId;

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  late final String _uid = context.read<AuthController>().uid!;
  late final Stream<List<Address>> _stream =
      context.read<UserRepository>().watchAddresses(_uid);

  Future<void> _add() async {
    final saved = await AppNav.push<Address>(context, const AddressFormScreen());
    if (saved != null && widget.selectMode && mounted) {
      Navigator.of(context).pop(saved);
    }
  }

  Future<void> _delete(Address a) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete address?',
      message: '${a.label}: ${a.fullText}',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<UserRepository>().deleteAddress(_uid, a);
    } catch (_) {
      if (mounted) showSnack(context, 'Couldn\'t delete. Try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dripAppBar(title: widget.selectMode ? 'Choose address' : 'Saved addresses'),
      body: StreamBuilder<List<Address>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const ErrorState(message: 'Couldn\'t load your addresses.');
          }
          if (!snap.hasData) return const CenteredLoader();
          final list = snap.data!;
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.home_outlined,
              title: 'No saved addresses',
              message: 'Add one to check out faster.',
              actionLabel: 'Add address',
              onAction: _add,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              for (final a in list)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.panel,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: widget.selectedId == a.id
                          ? AppColors.shopper
                          : AppColors.line,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: widget.selectMode
                        ? () => Navigator.of(context).pop(a)
                        : () => AppNav.push(context, AddressFormScreen(initial: a)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            a.label == 'Work'
                                ? Icons.work_outline_rounded
                                : Icons.home_outlined,
                            color: AppColors.shopper,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(a.label,
                                        style: AppTextStyles.body(
                                            weight: FontWeight.w700)),
                                    if (a.isDefault) ...[
                                      const SizedBox(width: 8),
                                      Text('DEFAULT',
                                          style: AppTextStyles.mono(
                                              size: 9, color: AppColors.shopper)),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('${a.name} · ${a.phone}',
                                    style: AppTextStyles.body(size: 13)),
                                const SizedBox(height: 2),
                                Text(a.fullText,
                                    style: AppTextStyles.body(
                                        size: 12, color: AppColors.mute, height: 1.4)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Edit',
                            icon: Icon(Icons.edit_outlined,
                                size: 20, color: AppColors.mute),
                            onPressed: () =>
                                AppNav.push(context, AddressFormScreen(initial: a)),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 20, color: AppColors.mute),
                            onPressed: () => _delete(a),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SecondaryButton(
                label: 'Add new address',
                icon: Icons.add_rounded,
                onPressed: _add,
              ),
            ],
          );
        },
      ),
    );
  }
}
