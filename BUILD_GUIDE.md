# Dripzzee — Build Guide (Flutter + Firebase, Separate Customer & Retailer Apps)

Stack: **Flutter** (two separate apps) + **Firebase** (shared backend). Design
system is locked to the existing landing page's tokens — see README.md's
Design System table before writing any UI code.

---

## PHASE 0 — Environment Setup (Arch Linux)

Avoid the AUR `flutter` package — it pins a `dart<3.12.0` constraint that
regularly conflicts with Arch's rolling `dart` package. Install via git.

```bash
sudo pacman -Syu
sudo pacman -S git curl unzip xz zip mesa clang cmake ninja pkgconf gtk3

mkdir -p ~/development
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable

echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc
source ~/.zshrc

flutter doctor
flutter doctor --android-licenses
```

Android Studio: Settings → Plugins → install **Flutter** (pulls in Dart) →
Restart. Create an emulator via Device Manager (Pixel 8, API 34).

---

## PHASE 1 — Repo & Project Structure

```bash
mkdir dripzzee && cd dripzzee
git init

flutter create customer_app
flutter create retailer_app
flutter create --template=package shared
mkdir functions admin_panel docs
mkdir -p docs/ui-previews shared/assets
```

Copy your actual logo file into the shared assets folder so both apps use
the exact same file:

```bash
cp /path/to/logo.png shared/assets/logo.png
```

```
dripzzee/
  customer_app/
  retailer_app/
  shared/
    assets/logo.png
    lib/
      theme/app_theme.dart
      models/
      services/
      utils/
  functions/
  admin_panel/
  docs/
    ui-previews/          # HTML mockups (design reference, not shipped code)
```

### Link `shared` into both apps

In both `customer_app/pubspec.yaml` and `retailer_app/pubspec.yaml`:

```yaml
dependencies:
  shared:
    path: ../shared
```

### Register the shared logo asset

In `shared/pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/logo.png
```

Then in each app's `pubspec.yaml`, also declare it so it's bundled into that
app's build:
```yaml
flutter:
  assets:
    - packages/shared/assets/logo.png
```

Use it anywhere the brand mark appears — **never as styled text**:
```dart
Image.asset('packages/shared/assets/logo.png', height: 26)
```

---

## PHASE 2 — Design System (`shared/lib/theme/app_theme.dart`)

This is a direct translation of the landing page's CSS tokens into Flutter.
Build this file **before** any screen — everything else references it.

```dart
import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF0A0A0C);        // background
  static const panel = Color(0xFF111114);       // cards/sheets/inputs
  static const panelHover = Color(0xFF17171B);
  static const line = Color(0x17FFFFFF);        // rgba(255,255,255,.09)
  static const paper = Color(0xFFF3F1F6);       // primary text
  static const mute = Color(0xFF8D899A);        // secondary text
  static const faint = Color(0xFF514E5A);       // tertiary text

  // Customer app accent (violet)
  static const shopper = Color(0xFFC77DFF);
  static const shopperDeep = Color(0xFF6D28D9);

  // Retailer app accent (copper)
  static const retailer = Color(0xFFF2A65A);
  static const retailerDeep = Color(0xFFB45309);
}

class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 26.0;
}

class AppSpacing {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
}

// Fonts: add google_fonts package, or bundle Fraunces/Manrope/JetBrains Mono
// as local assets to match the landing page exactly.
class AppTextStyles {
  static const heading = TextStyle(
    fontFamily: 'Fraunces', fontWeight: FontWeight.w500,
    color: AppColors.paper,
  );
  static const body = TextStyle(
    fontFamily: 'Manrope', fontWeight: FontWeight.w500,
    color: AppColors.paper,
  );
  static const mono = TextStyle(
    fontFamily: 'JetBrainsMono', fontWeight: FontWeight.w400,
    color: AppColors.mute, letterSpacing: 0.6,
  ); // used for eyebrows, chips, distance/rating/delivery-time metadata
}

// Build one ThemeData per app, sharing colors/type but swapping the
// primary accent: shopper (violet) for customer_app, retailer (copper)
// for retailer_app.
ThemeData buildAppTheme({required Color accent, required Color accentDeep}) {
  return ThemeData(
    scaffoldBackgroundColor: AppColors.ink,
    colorScheme: ColorScheme.dark(
      primary: accent,
      secondary: accentDeep,
      surface: AppColors.panel,
    ),
    fontFamily: 'Manrope',
    useMaterial3: true,
  );
}
```

In `customer_app/lib/main.dart`:
```dart
theme: buildAppTheme(accent: AppColors.shopper, accentDeep: AppColors.shopperDeep),
```

In `retailer_app/lib/main.dart`:
```dart
theme: buildAppTheme(accent: AppColors.retailer, accentDeep: AppColors.retailerDeep),
```

### Ambient background glow (shared widget)

Build one `AmbientGlow` widget in `shared/lib/widgets/ambient_glow.dart` using
`RadialGradient` + `BackdropFilter`/`ImageFilter.blur`, replicating the
landing page's `.ambient` + `.glow-orb` (soft violet/copper radial gradients,
with the orb pulsing via an `AnimationController` on a 7s loop, same as the
CSS `breathe` keyframe). Place it behind every screen's `Scaffold` body via a
`Stack`.

---

## PHASE 3 — Motion Implementation (Zomato-style, concrete)

Add to both apps' `pubspec.yaml`:
```yaml
dependencies:
  flutter_animate: ^latest
  shimmer: ^latest
  flutter_staggered_animations: ^latest
```

**Skeleton loading** (`shimmer` package) — wrap placeholder boxes while
Firestore data loads:
```dart
Shimmer.fromColors(
  baseColor: AppColors.panel,
  highlightColor: AppColors.panelHover,
  child: Container(height: 170, decoration: BoxDecoration(
    color: AppColors.panel, borderRadius: BorderRadius.circular(AppRadius.md))),
)
```

**Staggered card/list entrance** (`flutter_staggered_animations`):
```dart
AnimationLimiter(
  child: ListView.builder(
    itemBuilder: (context, index) => AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 400),
      child: SlideAnimation(
        verticalOffset: 24,
        child: FadeInAnimation(child: ProductCard(...)),
      ),
    ),
  ),
)
```

**Card press feedback** — wrap cards in `GestureDetector` + `AnimatedScale`
(scale to 0.97 on tap-down, back to 1.0 on tap-up).

**Shared element transition, list → detail** (built into Flutter, no
package needed):
```dart
// In the list card:
Hero(tag: 'product-${product.id}', child: Image.network(product.imageUrl))
// In the detail screen:
Hero(tag: 'product-${product.id}', child: Image.network(product.imageUrl))
```
Flutter animates the image growing from its list position into the detail
page automatically.

**Category chip active state** — `AnimatedContainer` (200–250ms,
`Curves.easeOutCubic`) transitioning background from transparent/outlined to
the accent gradient fill.

**Order tracking stepper** — animate each connecting line's fill with
`TweenAnimationBuilder<double>` (0 → 1) whenever `order.status` advances,
rather than snapping the UI to the new state instantly.

**Bottom nav** — `AnimatedContainer` + `AnimatedScale` on the active icon,
`Curves.elasticOut` for a slight overshoot/spring feel on tap.

---

## PHASE 4 — Reference UI Preview

Before writing Flutter screens, generate/keep an HTML mockup of each major
screen in `docs/ui-previews/`, built with the exact CSS custom properties
from `style.css` (`--ink`, `--shopper`, `--retailer`, etc.) so designers and
you can preview interaction/motion in a browser before writing Dart. Treat
these as throwaway reference files, not shipped code — the real
implementation is the Flutter code in Phase 2/3 above.

---

## PHASE 5 — Firebase Setup (one project, two registered apps)

1. console.firebase.google.com → Create Project → `dripzzee`.
2. Enable: **Authentication**, **Firestore**, **Storage**, **Cloud Functions**, **Cloud Messaging (FCM)**.
3. Register two Android apps in this one project:
   - `com.dripzzee.customer`
   - `com.dripzzee.retailer`

```bash
dart pub global activate flutterfire_cli

cd customer_app
flutterfire configure

cd ../retailer_app
flutterfire configure
```

Add to both `pubspec.yaml`:
```yaml
dependencies:
  firebase_core: ^latest
  firebase_auth: ^latest
  cloud_firestore: ^latest
  firebase_storage: ^latest
  firebase_messaging: ^latest
  geolocator: ^latest
  cached_network_image: ^latest
  provider: ^latest
  shared:
    path: ../shared
```

---

## PHASE 6 — Auth Roles & Firestore Security Rules

- Customer signup → Cloud Function sets `{ role: "customer" }` claim.
- Retailer signup (admin-approved) → Cloud Function sets
  `{ role: "retailer", storeId: "<id>" }` claim.

```
match /orders/{orderId} {
  allow read: if request.auth.token.role == "customer" && resource.data.customerId == request.auth.uid
              || request.auth.token.role == "retailer" && resource.data.storeId == request.auth.token.storeId;
  allow create: if request.auth.token.role == "customer";
  allow update: if request.auth.token.role == "retailer" && resource.data.storeId == request.auth.token.storeId;
}
```

---

## PHASE 7 — Full End-to-End Flow

```
1. Customer opens customer_app → logs in → shares location
2. Home shows nearby stores/products (Firestore geo query), skeleton → staggered reveal
3. Customer picks product + size → adds to cart → checks out (single retailer per order for MVP)
4. Order doc created: orders/{id}, status = PLACED
5. Cloud Function triggers → FCM push to retailer_app
6. Retailer sees "New Order" with accept-within-5-min timer
7. Retailer Accepts → status = ACCEPTED → Cloud Function pushes update to customer_app
8. Retailer marks Preparing → Ready for Pickup
9. Admin/delivery partner marks Picked Up → Out for Delivery → Delivered
10. Customer sees live order tracking via Firestore stream, animated stepper
11. Post-delivery: rate order/store/product, or file return/exchange
    → return_requests/{id} → retailer_app Returns tab → retailer resolves per policy
```

Build and test this full loop with **one dummy store and one dummy product**
before building out every screen.

---

## PHASE 8 — Build Order

### Step A — Customer App MVP
1. Auth
2. Location selection
3. Home (dummy Firestore data, full motion treatment from Phase 3)
4. Categories
5. Nearby stores
6. Store profile
7. Product listing + detail (Hero transition, sizes, availability, delivery estimate, return policy visible)
8. Cart (single retailer)
9. Checkout + payment
10. Order tracking (animated stepper)
11. Order history
12. Return/exchange request
13. Profile + wishlist

### Step B — Retailer App MVP
1. Retailer login
2. Store profile setup
3. Product upload/catalogue
4. Inventory management
5. Order management (accept/reject timer → Preparing → Ready for pickup)
6. Return/exchange handling

### Step C — Cloud Functions
- `onOrderCreated` → notify retailer
- `onOrderStatusChanged` → notify customer
- `onWishlistItemRestocked` → notify customer

### Step D — Admin Panel
- User/retailer/product/order management, analytics.

### Step E — Delivery Assignment
- Manual first (admin dropdown); automate later.

---

## Notes on scaling later
- Cross-store size search needs Algolia/Typesense once past MVP.
- Consider Postgres+PostGIS for heavy geo-query/analytics workloads if volume grows, while keeping Firebase for auth/orders/notifications.

---

## Immediate next action
1. Get `flutter doctor` fully green.
2. Scaffold the repo structure in Phase 1, copy the logo into `shared/assets/`.
3. Build `app_theme.dart` exactly as in Phase 2 — do not deviate from the token values.
4. Build the customer app's Home screen with dummy data and full motion treatment (Phase 3) — first real milestone, and should visually match the published Home screen preview.
