import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/return_request.dart';
import '../../data/repositories/return_repository.dart';
import '../../navigation.dart';
import '../../state/auth_controller.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  late final Stream<List<ReturnRequest>> _stream = context
      .read<ReturnRepository>()
      .watchForCustomer(context.read<AuthController>().uid!);

  Color _color(String status) => switch (status) {
        'APPROVED' || 'COMPLETED' => AppColors.success,
        'REJECTED' => AppColors.danger,
        _ => AppColors.warning,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dripAppBar(title: 'Returns & exchanges'),
      body: StreamBuilder<List<ReturnRequest>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return const ErrorState(message: 'Couldn\'t load your requests.');
          }
          if (!snap.hasData) return const CenteredLoader();
          final list = snap.data!;
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.assignment_return_outlined,
              title: 'No return requests',
              message:
                  'Delivered orders can be returned or exchanged from the order page within the store\'s return window.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = list[i];
              final color = _color(r.status);
              return Material(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => AppNav.openOrder(context, r.orderId),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${r.isExchange ? 'Exchange' : 'Return'} · ${r.storeName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body(weight: FontWeight.w700),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(r.statusLabel.toUpperCase(),
                                  style: AppTextStyles.mono(
                                      size: 9.5, color: color, weight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          r.items
                              .map((it) => it.exchangeSize == null
                                  ? '${it.name} (${it.size})'
                                  : '${it.name} (${it.size} → ${it.exchangeSize})')
                              .join(', '),
                          style: AppTextStyles.body(size: 13, color: AppColors.mute),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [
                            r.reason,
                            shortOrderId(r.orderId),
                            if (r.createdAt != null) formatDate(r.createdAt!),
                          ].join(' · '),
                          style: AppTextStyles.mono(size: 10.5),
                        ),
                        if (r.resolutionNote != null) ...[
                          const SizedBox(height: 6),
                          Text('Store: ${r.resolutionNote}',
                              style: AppTextStyles.body(size: 13)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
