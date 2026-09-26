# 🛍️ Dripzzee — Fashion Around You

> **Discover. Drip. Repeat.**

Dripzzee is a hyperlocal fashion discovery and shopping platform that connects customers with local fashion retailers, boutiques, sneaker stores, and streetwear shops in their own neighbourhood. Instead of scrolling Instagram, Google Maps, and store WhatsApps separately, users open Dripzzee and instantly see **fashion that's actually around them** — with real-time size availability, pricing, and store info — and order directly from local retailers.

Dripzzee is **not** positioned as a "60-minute delivery app." Fast local delivery is a natural byproduct of connecting customers to nearby stores, but the core identity is **local fashion discovery**.

A live interactive preview of the Home screen (matching the design system below) is linked in `/docs/ui-previews/`.

---

## ✨ Core Idea

```
Local Retailer  →  Dripzzee  →  Local Customer
```

We connect local fashion supply with local customer demand — helping retailers gain digital presence and helping customers discover what's around them before physically visiting a store.

---

## 🎨 Design System (locked — derived from the live landing page)

This is the **exact** token set already shipping on the Dripzzee landing page (`index.html` / `style.css`). The apps must use these same values — not a new palette — so the landing page, customer app, and retailer app all feel like one brand.

| Token | Value | Use |
|---|---|---|
| `--ink` | `#0A0A0C` | App background |
| `--panel` | `#111114` | Cards, sheets, inputs |
| `--panel-hover` | `#17171B` | Card hover/press state |
| `--line` | `rgba(255,255,255,.09)` | Borders |
| `--paper` | `#F3F1F6` | Primary text |
| `--mute` | `#8D899A` | Secondary text |
| `--faint` | `#514E5A` | Tertiary/disabled text |
| `--shopper` | `#C77DFF` (violet) | **Customer app** accent — buttons, active states, price highlights |
| `--shopper-deep` | `#6D28D9` | Customer app gradient end |
| `--retailer` | `#F2A65A` (copper) | **Retailer app** accent — buttons, active states |
| `--retailer-deep` | `#B45309` | Retailer app gradient end |

**Fonts** (already loaded from Google Fonts in the landing page — reuse the same three):
- **Fraunces** (serif) — headings, section titles, price emphasis
- **Manrope** (sans) — body text, buttons, labels
- **JetBrains Mono** (mono) — eyebrows/tags, category chips, metadata (distance, delivery time, ratings) — this monospace-for-metadata detail is a signature of the current brand and should carry into the app

**Signature visual elements to carry into both apps:**
- **Ambient background glow** — soft violet + copper radial gradients behind content, exactly like `.ambient` and `.glow-orb` on the landing page (breathing/pulsing animation on the orb).
- **Glassmorphism top bar** — blurred, semi-transparent nav that solidifies slightly on scroll.
- **Logo as an image asset, never as text.** Anywhere the brand name would appear in-app (splash screen, top bar, empty states, loading screens), use the actual `logo.png` wordmark image — never render "Dripzzee" as a text string styled to look like the logo. Store the asset once in `shared/assets/logo.png` and reference it from both apps.
- **Two apps, two accents.** The customer app uses violet (`--shopper`) as its primary accent; the retailer app uses copper (`--retailer`) as its primary accent. This mirrors the landing page's existing shopper/retailer color split and gives each app its own identity while staying one visual family.

---

## 🎬 Motion & Interaction (Zomato-style, defined explicitly)

Dripzzee should feel as fluid and "alive" as Zomato/Swiggy. Concretely, this means:

| Interaction | Behavior |
|---|---|
| **App/screen load** | Skeleton shimmer placeholders (not blank/spinner) while data loads, then content fades/slides in |
| **List & card entrance** | Staggered fade + slide-up as sections enter view (each card ~80–100ms after the previous) |
| **Category chips / horizontal rows** | Snap-scrolling, momentum-based, active chip animates into a filled gradient state |
| **Card press** | Slight scale-down on tap (press feedback), subtle lift + shadow-glow on hover/focus |
| **Bottom nav** | Active icon lifts and gets a small dot indicator; icon swap uses a spring curve, not linear |
| **Store/product image → detail transition** | Shared element (Hero) transition — the tapped image grows into the detail page's hero image, not a hard cut |
| **Order status stepper** | Each stage fills in with an animated progress line, not an instant state change |
| **Pull-to-refresh on Home/Store lists** | Custom-branded refresh indicator (small animated logo mark), not the default platform spinner |

Flutter packages to implement this without hand-rolling everything:
- `flutter_animate` — declarative entrance/stagger animations
- `shimmer` — skeleton loading placeholders
- `flutter_staggered_animations` — staggered list/grid reveals
- Built-in `Hero` widget — shared element transitions between list and detail screens
- `AnimatedContainer` / `AnimatedSwitcher` — chip/tab active-state transitions

---

## 🎯 Target Audience

Gen Z and young adults who:
- Love discovering new styles and local brands
- Prefer shopping from nearby retailers over centralized e-commerce
- Need an outfit urgently (last-minute shoppers)
- Want to know what's in stock nearby before visiting a store
- Discover fashion primarily through social media

---

## 🧩 Tech Stack

| Layer | Choice |
|---|---|
| Customer App | **Flutter** (Android first, iOS-ready) |
| Retailer App | **Flutter** (separate app, same backend) |
| Backend | **Firebase** — Auth, Firestore, Storage, Cloud Functions, Cloud Messaging |
| Location & Geo-queries | `geolocator`, `geoflutterfire` |
| Payments | Razorpay / Stripe (UPI, Card, Net Banking) |
| Admin Panel | Web dashboard (Flutter Web or React) |
| State Management | Provider / Riverpod *(pick one, stay consistent across both apps)* |
| Animation | `flutter_animate`, `shimmer`, `flutter_staggered_animations`, `Hero` |

---

## 📱 Why Two Separate Apps?

Dripzzee ships **two separate, independently installable apps** — not one app with a customer/seller toggle. Same pattern as Swiggy/Swiggy Partner, Uber/Uber Driver, Zomato/Zomato for Business.

- **Different jobs.** Customers browse and buy; retailers manage orders and inventory under time pressure.
- **Different install audience.** Retailers install once on a store device and never touch the customer UI.
- **Cleaner security.** Separate Firebase Auth roles (`customer` / `retailer` custom claims) + separate Firestore rules per app.
- **Independent releases.** Fix a retailer-app bug without forcing every customer to update.
- **Conveniently already reflected in your brand colors** — violet for shopper, copper for retailer, straight from the existing landing page.

**One backend, one Firebase project, one set of shared code:**

```
dripzzee/
  customer_app/    # Flutter app — end users (Play Store: "Dripzzee")
  retailer_app/     # Flutter app — store partners (Play Store: "Dripzzee for Business")
  admin_panel/        # Web dashboard — internal ops
  functions/            # Firebase Cloud Functions (order logic, notifications)
  shared/                # Local Dart package: theme, models, Firebase wrappers, logo asset, utils
  docs/
    ui-previews/           # HTML/CSS reference mockups matching the locked design system
```

`customer_app` and `retailer_app` both depend on `shared/` via a local `path:` dependency in `pubspec.yaml`.

---

## 🔄 Full System Flow

```
CUSTOMER APP                    FIREBASE (shared backend)              RETAILER APP
─────────────                   ─────────────────────────              ─────────────
Login/signup      ────────────▶ Auth (role: customer)
Location shared    ───────────▶ Firestore: users/{uid}
Browse nearby       ──────────▶ Firestore query: stores by geohash
                                 radius + products subcollection
Select product+size ─────────▶ Firestore: products/{id}
Place order          ─────────▶ Firestore: orders/{id} (status: PLACED)
                                        │
                                        ▼
                     Cloud Function triggers on new order doc
                     → sends FCM push to retailer  ──────────────────▶ New Order notification
                                                                        Retailer: Accept/Reject
                                                                        (timer-based, e.g. 5 min)
                                        ◀───────────────────────────── Retailer updates order:
                                 Firestore: orders/{id}.status          CONFIRMED → PREPARING
                                                                        → READY_FOR_PICKUP
Order tracking screen ◀──────── Cloud Function triggers on
(live status updates)           order.status change → FCM push
                                 to customer
                                        │
                                        ▼
                                 Admin/manual: delivery partner
                                 assignment → PICKED_UP →
                                 OUT_FOR_DELIVERY → DELIVERED
Order delivered ◀────────────── Firestore: orders/{id}.status = DELIVERED
                                        │
Rate order/store/product ─────▶ Firestore: reviews/{id}
Return/exchange request ──────▶ Firestore: return_requests/{id} ──────▶ Retailer reviews request
                                                                        Approves/handles per policy
```

**Order status enum** (`shared/models/order_status.dart`):
`PLACED → RETAILER_CONFIRMING → ACCEPTED → PREPARING → READY_FOR_PICKUP → PICKED_UP → OUT_FOR_DELIVERY → DELIVERED` (or `REJECTED` / `CANCELLED` / `RETURN_REQUESTED`)

Both apps listen to the same order document in real time via Firestore streams.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev) installed via git (see `BUILD_GUIDE.md` — avoid the AUR `flutter` package, it has known `dart` version conflicts on Arch)
- Android Studio with the Flutter & Dart plugins
- A Firebase project (Auth, Firestore, Storage, Functions, FCM enabled)
- Node.js (for Cloud Functions)

### Setup

```bash
git clone https://github.com/<your-username>/dripzzee.git
cd dripzzee
flutter doctor

cd customer_app
flutter pub get
flutterfire configure
flutter run

cd ../retailer_app
flutter pub get
flutterfire configure
flutter run
```

---

## 🗺️ MVP Feature Scope

### Customer App
- [ ] Login/signup
- [ ] Location selection
- [ ] Home (Fashion Around You feed, with skeleton loading + staggered reveal)
- [ ] Search
- [ ] Categories
- [ ] Nearby stores
- [ ] Store profiles
- [ ] Product listing & details (Hero transition from card → detail)
- [ ] Size/availability indicators
- [ ] Cart (single-retailer checkout for MVP)
- [ ] Checkout & payments
- [ ] Order tracking (animated status stepper)
- [ ] Order history
- [ ] Return/exchange requests
- [ ] Profile & wishlist

### Retailer App
- [ ] Retailer login
- [ ] Store profile setup
- [ ] Product catalogue & upload
- [ ] Inventory management
- [ ] Order management (accept/reject with timer, prepare, ready-for-pickup)
- [ ] Return/exchange handling

### Admin Panel
- [ ] User management
- [ ] Retailer approval & management
- [ ] Product moderation
- [ ] Order monitoring
- [ ] Returns/refunds oversight
- [ ] Analytics

> Full requirements and post-MVP roadmap are in `/docs/PRD.md`. Step-by-step build instructions are in `BUILD_GUIDE.md`.

---

## 🤝 Contributing

1. Branch from `main` using `feature/<app-name>/<short-description>`
2. Keep features isolated under `lib/features/<feature_name>/` within the relevant app
3. Shared logic/models/theme/logo changes go in `shared/` — never duplicate into one app
4. Run `flutter analyze` before opening a PR
5. Include screenshots/GIFs for UI changes, checked against the design system table above

---

## 📄 License

*(Add your chosen license here)*

---

## 📬 Contact

*(Add project owner / team contact info here)*
