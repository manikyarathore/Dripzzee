# Dripzzee — Customer App

Hyperlocal fashion: discover clothing in stock at stores around you, order
from one store at a time, and track delivery live. Flutter + Firebase
(Auth, Firestore, Cloud Functions, Cloud Messaging) with Razorpay payments.

First-time setup (Firebase project, keys, seeding, building): **see
`../SETUP.md`**.

## Architecture

```
lib/
  main.dart / app.dart     Firebase init, providers, AuthGate (route guard)
  navigation.dart          navigator key, AppNav helpers, notification routing
  core/                    theme tokens, pricing rules, config, utils, widgets
  data/
    models/                Store, Product, CartItem, DripOrder, ReturnRequest…
    repositories/          Firestore / Functions access (one per domain)
    services/              location, Razorpay, FCM, recent searches
  state/                   ChangeNotifier controllers (auth, location,
                           catalog, cart, wishlist, shell) + gate.dart
  features/                screens grouped by journey (auth, location, home,
                           campaigns, catalog, search, wishlist, cart,
                           checkout, orders, returns, profile)
```

State management is `provider`. Controllers depend on each other through
`ChangeNotifierProxyProvider`: Auth → Location → Catalog; Auth → Cart,
Wishlist. `resolveGate()` decides splash / auth / location setup / app, so a
signed-out user can never reach app screens and back-navigation can't return
to auth after sign-in.

**Server is the source of truth for money and stock.** The app never writes
orders. `createOrder` (Cloud Function) re-prices the cart, checks stock in a
transaction, reserves it, and (for online payment) opens a Razorpay order.
`verifyPayment` checks the Razorpay signature with the secret key before the
order becomes `PLACED`. Each checkout carries an idempotency key, so double
taps and retries can't create duplicate orders. `lib/core/pricing.dart` mirrors
the function's `PRICING` for display — keep them in sync.

Order statuses follow the shared README with the retailer app:
`PLACED → RETAILER_CONFIRMING → ACCEPTED → PREPARING → READY_FOR_PICKUP →
PICKED_UP → OUT_FOR_DELIVERY → DELIVERED`, plus `REJECTED`, `CANCELLED`,
`RETURN_REQUESTED`, and customer-only `PAYMENT_PENDING` (while Razorpay is
open). The retailer app updates `status`; tracking in this app is a live
Firestore stream.

## Design system

Dark by default with a Light mode (Profile → Appearance). Colours come from
`AppPalette.dark` / `AppPalette.light` in `core/theme/app_theme.dart`; always
read `AppColors.*` at build time (they change with the appearance).

| Token | Value | Use |
|---|---|---|
| ink | `#0A0A0C` | background |
| panel | `#111114` | cards, sheets, inputs |
| panelHover | `#17171B` | elevated / pressed |
| paper | `#F3F1F6` | primary text |
| mute | `#8D899A` | secondary text |
| shopper | `#C77DFF` | accent — small doses only (CTAs, selection) |

Fonts (google_fonts): Fraunces (headings), Manrope (body), JetBrains Mono
(meta labels). The wordmark is `assets/logo.png`; the app icon lives in `tools/icon/`
and is installed by `tools/setup_android.sh`.

## Seasonal campaigns (Home carousel)

The animated carousel between Search and Categories is driven by
`lib/features/campaigns/`:

- `campaign.dart` — `Campaign` (id, start/end dates, slides), the shared
  `CampaignCard`, and `LoopingScene` (one AnimationController that only runs
  while its slide is visible, the tab is active, and system animations are on).
- `campaign_carousel.dart` — `kCampaigns`; the first live campaign is shown.
  Auto-advances every 6 s, pauses while dragging, in hidden tabs, and with
  reduced motion.
- `navratri_campaign.dart` + `scenes/` — the Navratri 2026 edit
  (15 Sep – 26 Oct 2026): *Garba Night Fits* (products tagged `garba`),
  *Nine Nights, Nine Looks* (products tagged `navratri`, pre-filtered by the
  colour on screen), *Festive stores near you* (stores tagged `festive`).

To replace it, add a new `Campaign` to `kCampaigns` with its own slides. To
remove it, delete it from the list — nothing else references it. Retailers
opt products into an edit simply by adding tags.

## Commands

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter run                         # device/emulator
flutter build apk --release         # build/app/outputs/flutter-apk/app-release.apk
```
