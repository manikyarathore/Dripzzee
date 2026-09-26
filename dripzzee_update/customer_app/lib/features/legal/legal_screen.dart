import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/pricing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/drip_app_bar.dart';

enum LegalDoc { terms, privacy }

/// Terms & Conditions and Privacy Policy.
///
/// DRAFT TEMPLATE — have a lawyer review it and fill in the business details
/// in AppConfig before publishing the app.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final sections = doc == LegalDoc.terms ? _terms() : _privacy();
    return Scaffold(
      appBar: dripAppBar(
        title: doc == LegalDoc.terms ? 'Terms & Conditions' : 'Privacy Policy',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Text('Last updated ${AppConfig.legalLastUpdated}',
              style: AppTextStyles.mono(size: 11)),
          const SizedBox(height: 16),
          for (final (heading, body) in sections) ...[
            Text(heading, style: AppTextStyles.heading(size: 18)),
            const SizedBox(height: 6),
            Text(body,
                style: AppTextStyles.body(size: 14, height: 1.55, color: AppColors.mute)),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  static String get _contact => [
        if (AppConfig.supportEmail.isNotEmpty) AppConfig.supportEmail,
        if (AppConfig.supportPhone.isNotEmpty) AppConfig.supportPhone,
      ].join(' · ');

  static String get _grievance =>
      'Grievance Officer: ${AppConfig.grievanceOfficerName}, '
      '${AppConfig.grievanceOfficerEmail}. We acknowledge complaints within '
      '48 hours and aim to resolve them within one month.';

  static List<(String, String)> _terms() => [
        (
          '1. About Dripzzee',
          'Dripzzee is an online marketplace operated by ${AppConfig.legalEntityName} '
              '(${AppConfig.legalAddress}). It lets you discover and buy fashion '
              'from independent stores near you. Each product is sold by the store '
              'listed on it; Dripzzee provides the platform, payments and support.'
        ),
        (
          '2. Your account',
          'You sign in with your mobile number (verified by a one-time code) or '
              'your Google account. You must be 18 or older, or use the app with a '
              'parent or guardian. Keep your phone and account secure — activity on '
              'your account is treated as yours.'
        ),
        (
          '3. Orders and pricing',
          'Prices are set by the stores and include applicable taxes unless shown '
              'otherwise. A platform fee of ${formatInr(PricingRules.platformFee)} '
              'applies per order, and a delivery fee applies below '
              '${formatInr(PricingRules.freeDeliveryThreshold)}. An order is confirmed '
              'only when the store accepts it. Stores may decline an order (for '
              'example, if an item is damaged or sold out in store); any amount paid '
              'is then refunded in full.'
        ),
        (
          '4. Payments',
          'Online payments are processed by Razorpay; Dripzzee never stores your '
              'card or UPI details. Cash on delivery is available up to '
              '${formatInr(PricingRules.codLimit)} per order.'
        ),
        (
          '5. Coupons',
          'Coupons have their own conditions (minimum order, expiry, one use per '
              'customer, etc.), cannot be exchanged for cash, and may be withdrawn '
              'at any time. Misuse can lead to cancellation of the order.'
        ),
        (
          '6. Delivery',
          'Delivery times shown are estimates based on the store\'s location and '
              'current demand. Please make sure someone is available at the '
              'delivery address.'
        ),
        (
          '7. Cancellations, returns and refunds',
          'You can cancel an order free of charge until the store accepts it. '
              'Returns and size exchanges follow the policy shown on each store and '
              'product page (usually within the stated number of days after '
              'delivery, for unused items with original tags). Refunds go to the '
              'original payment method, typically within 5–7 business days after '
              'the return is completed.'
        ),
        (
          '8. Reviews and content',
          'Reviews must be honest and about your own purchase. We may remove '
              'content that is abusive, misleading or unlawful.'
        ),
        (
          '9. Acceptable use',
          'Don\'t misuse the app — for example by placing fake orders, abusing '
              'coupons, or attempting to interfere with the service. We may suspend '
              'accounts that do.'
        ),
        (
          '10. Liability',
          'Stores are responsible for the products they sell. To the extent '
              'permitted by law, Dripzzee\'s liability for any order is limited to '
              'the amount you paid for it. Nothing here limits your rights under '
              'the Consumer Protection Act, 2019.'
        ),
        (
          '11. Changes and governing law',
          'We may update these terms and will notify you of important changes in '
              'the app. These terms are governed by the laws of India, and courts '
              'in ${AppConfig.jurisdictionCity} have jurisdiction.'
        ),
        (
          '12. Contact and grievances',
          '${_contact.isEmpty ? '' : 'Contact us: $_contact. '}$_grievance'
        ),
      ];

  static List<(String, String)> _privacy() => [
        (
          'What we collect',
          'Your mobile number and/or Google account email, name, and the optional '
              'profile details you add (date of birth, gender). Delivery addresses '
              'you save. Your shopping location (GPS or searched) to show nearby '
              'stores. Orders, wishlist, reviews, and return requests. A device '
              'token so we can send order notifications.'
        ),
        (
          'How we use it',
          'To sign you in, show stores near you, process and deliver orders, handle '
              'returns and refunds, send order and restock notifications, prevent '
              'fraud, and improve the app. We do not sell your personal data.'
        ),
        (
          'Who we share it with',
          'The store you order from receives your name, phone number and delivery '
              'address to fulfil the order. Payment details go directly to Razorpay. '
              'We use Google Firebase to host data and send notifications. We share '
              'data with authorities only when required by law.'
        ),
        (
          'Location',
          'Location is used only while you use the app, to find nearby stores and '
              'fill in addresses. You can deny permission and enter your area '
              'manually instead.'
        ),
        (
          'Storage and security',
          'Data is stored on Google Cloud servers with access controls so that only '
              'you (and, for your orders, the relevant store) can see it. Payments '
              'are handled by a PCI-DSS compliant provider.'
        ),
        (
          'Your choices',
          'You can view and edit your profile and addresses in the app, turn off '
              'notifications in your phone\'s settings, and ask us to delete your '
              'account and personal data (order records we must keep by law are '
              'retained for the required period).'
        ),
        (
          'Children',
          'Dripzzee is not intended for children under 18 without parental '
              'consent.'
        ),
        (
          'Contact and grievances',
          '${_contact.isEmpty ? '' : 'Contact us: $_contact. '}$_grievance'
        ),
      ];
}
