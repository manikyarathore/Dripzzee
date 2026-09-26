/// App-wide configuration: support, legal and business details.
class AppConfig {
  AppConfig._();

  /// Region your Cloud Functions are deployed to. Must match `REGION` in
  /// functions/index.js (and ideally your Firestore location).
  static const functionsRegion = 'asia-south1';

  /// How far (in km) we look for stores around the customer.
  static const nearbyRadiusKm = 25.0;

  /// Country code used for phone sign-in.
  static const phoneCountryCode = '+91';

  // ---------------------------------------------------------------------
  // Support & legal
  // ---------------------------------------------------------------------

  /// Customer helpline, e.g. '+91 98765 43210'. Empty hides the call button.
  static const supportPhone = '+91 98192 88848';

  /// Support inbox, e.g. 'support@dripzzee.in'. Empty hides the email button.
  static const supportEmail = 'dirpzzeeoffical@gmail.com';

  /// Helpline hours shown on Help & support.
  static const supportHours = '10 AM – 8 PM, all days';

  /// Registered business name, address and city (for courts' jurisdiction)
  /// shown in the Terms and Privacy Policy.
  static const legalEntityName = 'Dripzzee Limited';
  static const legalAddress = 'Andheri Gulmohar CHS, Mumbai';
  static const jurisdictionCity = 'Mumbai';

  /// Grievance Officer — required for e-commerce platforms in India
  /// (Consumer Protection (E-Commerce) Rules, 2020 and IT Rules, 2021).
  static const grievanceOfficerName = 'Jash Vora';
  static const grievanceOfficerEmail = 'dirpzzeeoffical@gmail.com';

  /// Date shown as "Last updated" on the legal pages.
  static const legalLastUpdated = '25 September 2026';
}
