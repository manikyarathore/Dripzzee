import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/pricing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/drip_app_bar.dart';
import '../../core/widgets/feedback.dart';
import '../../state/shell_controller.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static final _faqs = [
    (
      'How do I log in?',
      'Enter your mobile number and the 6-digit code we text you. There\'s no '
          'separate sign-up — your account is created the first time, and you '
          'stay logged in until you log out from Profile.'
    ),
    (
      'How does delivery work?',
      'Every order ships from one local store near you. You\'ll see the '
          'estimated time on the store and product pages, and can track each '
          'step live from Orders.'
    ),
    (
      'Can I cancel my order?',
      'Yes — until the store accepts it. Open the order and tap "Cancel order". '
          'Online payments are refunded to the original method.'
    ),
    (
      'How do returns and exchanges work?',
      'After delivery, open the order and tap "Return or exchange" within the '
          'store\'s return window. Items should be unused with tags. The store '
          'reviews your request and you\'ll be notified of the decision.'
    ),
    (
      'Which payment methods are supported?',
      'UPI, debit and credit cards and net banking through Razorpay, plus cash '
          'on delivery for orders up to ${formatInr(PricingRules.codLimit)}.'
    ),
    (
      'What are the fees?',
      'A ${formatInr(PricingRules.platformFee)} platform fee applies to each '
          'order. Delivery is free on orders over '
          '${formatInr(PricingRules.freeDeliveryThreshold)}; otherwise the '
          'store\'s delivery fee applies.'
    ),
    (
      'My payment was debited but the order failed',
      'Dripzzee re-checks every payment with Razorpay. If an order can\'t be '
          'placed, the amount is refunded automatically, usually within 5–7 '
          'business days.'
    ),
  ];

  Future<void> _call(BuildContext context) async {
    final digits = AppConfig.supportPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    final ok = await launchUrl(Uri(scheme: 'tel', path: digits));
    if (!ok && context.mounted) {
      showSnack(context, 'Call us on ${AppConfig.supportPhone}.', error: true);
    }
  }

  Future<void> _email(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.supportEmail,
      queryParameters: {'subject': 'Dripzzee support'},
    );
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      showSnack(context, 'No email app found. Write to ${AppConfig.supportEmail}.',
          error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dripAppBar(title: 'Help & support'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (AppConfig.supportPhone.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.shopperSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.support_agent_rounded,
                        color: AppColors.shopper),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Helpline',
                            style: AppTextStyles.body(weight: FontWeight.w700)),
                        Text(AppConfig.supportPhone,
                            style: AppTextStyles.body(size: 15)),
                        Text(AppConfig.supportHours,
                            style: AppTextStyles.mono(size: 10.5)),
                      ],
                    ),
                  ),
                  PrimaryButton(
                    label: 'Call',
                    icon: Icons.call_rounded,
                    expand: false,
                    onPressed: () => _call(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text('Common questions', style: AppTextStyles.heading(size: 20)),
          const SizedBox(height: 10),
          for (final (q, a) in _faqs)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                iconColor: AppColors.shopper,
                collapsedIconColor: AppColors.mute,
                title: Text(q, style: AppTextStyles.body(size: 15, weight: FontWeight.w600)),
                childrenPadding: const EdgeInsets.only(bottom: 12),
                children: [
                  Text(a,
                      style: AppTextStyles.body(
                          size: 13, color: AppColors.mute, height: 1.5)),
                ],
              ),
            ),
          const SizedBox(height: 20),
          SecondaryButton(
            label: 'Problem with an order? Open your orders',
            icon: Icons.receipt_long_outlined,
            onPressed: () {
              context.read<ShellController>().goTo(ShellTab.orders);
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
          if (AppConfig.supportEmail.isNotEmpty) ...[
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Email support',
              icon: Icons.mail_outline_rounded,
              onPressed: () => _email(context),
            ),
          ],
        ],
      ),
    );
  }
}
