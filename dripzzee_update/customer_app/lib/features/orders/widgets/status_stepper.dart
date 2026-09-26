import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order.dart';

/// Vertical tracking timeline driven entirely by the order document. When
/// the backend advances the status, the connecting line animates to the new
/// step (TweenAnimationBuilder keeps the previous value as its start).
class StatusStepper extends StatelessWidget {
  const StatusStepper({super.key, required this.order});

  final DripOrder order;

  @override
  Widget build(BuildContext context) {
    final current = order.status.stepIndex;
    final steps = OrderStatus.trackingSteps;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(end: current.toDouble()),
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
      builder: (context, progress, _) {
        return Column(
          children: [
            for (var i = 0; i < steps.length; i++)
              _StepRow(
                status: steps[i],
                time: order.timeOf(steps[i]),
                done: progress >= i,
                isCurrent: i == current,
                isLast: i == steps.length - 1,
                lineFill: (progress - i).clamp(0.0, 1.0),
              ),
          ],
        );
      },
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.status,
    required this.time,
    required this.done,
    required this.isCurrent,
    required this.isLast,
    required this.lineFill,
  });

  final OrderStatus status;
  final DateTime? time;
  final bool done;
  final bool isCurrent;
  final bool isLast;
  final double lineFill;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isCurrent ? 18 : 14,
                  height: isCurrent ? 18 : 14,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? AppColors.shopper : AppColors.panel,
                    border: Border.all(
                      color: done ? AppColors.shopper : AppColors.lineStrong,
                      width: 2,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: AppColors.shopper.withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: done && !isCurrent
                      ? Icon(Icons.check_rounded, size: 9, color: AppColors.ink)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: AppColors.lineStrong,
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        heightFactor: lineFill,
                        child: Container(color: AppColors.shopper),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.label,
                    style: AppTextStyles.body(
                      size: 14,
                      weight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      color: done ? AppColors.paper : AppColors.faint,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(height: 2),
                    Text(status.description,
                        style: AppTextStyles.body(size: 12, color: AppColors.mute)),
                  ],
                  if (time != null && done) ...[
                    const SizedBox(height: 2),
                    Text(formatTime(time!), style: AppTextStyles.mono(size: 10)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
