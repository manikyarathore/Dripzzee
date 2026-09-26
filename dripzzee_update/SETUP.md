# Dripzzee — setup guide (Arch Linux)

Follow top to bottom once. Commands assume the project lives in
`~/ZManikya/Dripzzee` and Flutter/Android SDK are already set up from the
first APK build.

---

## 0. Put the new code in place

```bash
cd ~/ZManikya/Dripzzee
# keep your android/ folder, replace the Dart code
rm -rf customer_app/lib customer_app/test
unzip -o ~/Downloads/dripzzee_update.zip -d ~/ZManikya/Dripzzee
```

You should now have:

```
Dripzzee/
  SETUP.md  firebase.json  firestore.rules  firestore.indexes.json  storage.rules
  functions/   (Cloud Functions)
  seed/        (demo data script)
  customer_app/ (Flutter app — lib/, test/, tools/, pubspec.yaml, assets/)
```

## 1. Tools

```bash
sudo pacman -S --needed nodejs npm python
npm install -g firebase-tools            # add `sudo` if npm global dir isn't yours
dart pub global activate flutterfire_cli
echo 'export PATH="$PATH:$HOME/.pub-cache/bin"' >> ~/.zshrc && source ~/.zshrc
firebase login
```

## 2. Firebase project (console.firebase.google.com)

1. **Create project** (or pick an existing one).
2. **Upgrade to Blaze** (pay-as-you-go) — Cloud Functions require it. Normal
   testing stays within the free quota; set a budget alert under
   *Usage and billing*.
3. **Firestore Database → Create database** → production mode → location
   **asia-south1 (Mumbai)**. (If you pick another region, change `REGION` in
   `functions/index.js` *and* `functionsRegion` in
   `customer_app/lib/core/config/app_config.dart`.)
4. **Authentication → Get started → Sign-in method** → enable **Phone**
   and **Google**. Under Phone, add test numbers for free testing; real SMS
   needs the Blaze plan.
5. **Storage → Get started** (for retailer product photos later).

## 3. Connect the Flutter app

```bash
cd ~/ZManikya/Dripzzee/dripzzee_update/customer_app
flutter create --org com.dripzzee --platforms=android --project-name customer_app .   # only if android/ is missing
rm -f test/widget_test.dart
bash tools/setup_android.sh          # permissions, icon, launch screen, proguard, minSdk
```

### SHA fingerprints (needed for phone OTP and Google sign-in)

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep -E 'SHA1|SHA256'
```

Firebase console → Project settings → *Your apps* → Android app
(`com.dripzzee.customer_app`) → **Add fingerprint** → paste SHA-1 → Save;
repeat for SHA-256.

### Firebase config files

On the same page click **google-services.json** to download it (download it
again every time you add fingerprints or change sign-in providers), then:

```bash
mv ~/Downloads/google-services.json android/app/google-services.json
python3 tools/gen_firebase_options.py
```

The script writes `lib/firebase_options.dart` and tells you whether the
fingerprints and the Google web client ID are present. The app won't compile
until this file exists.

## 4. Razorpay (online payments)

1. Sign up at dashboard.razorpay.com → switch to **Test mode**.
2. *Account & Settings → API Keys → Generate Test Key*. You get a **Key ID**
   (`rzp_test_…`) and **Key Secret**.
3. Store both as Cloud Functions secrets — they never go into the app:

```bash
cd ~/ZManikya/Dripzzee
firebase use --add                   # pick your project
firebase functions:secrets:set RAZORPAY_KEY_ID      # paste rzp_test_…
firebase functions:secrets:set RAZORPAY_KEY_SECRET  # paste the secret
```

No Razorpay account yet? Enter `not_configured` for both. Cash on delivery
works; "Pay online" shows a clear "not set up" message.

Test payments: card `4111 1111 1111 1111`, any future expiry, any CVV; UPI
`success@razorpay` (or `failure@razorpay` to test failures).

## 5. Deploy the backend

```bash
cd ~/ZManikya/Dripzzee/functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

First deploy takes a few minutes and may ask to enable APIs (Cloud Build,
Artifact Registry, Eventarc, Cloud Scheduler) — answer **yes**. Indexes can
take ~5 minutes to finish building.

## 6. Seed demo stores and products

Firebase console → Project settings → **Service accounts** → *Generate new
private key* → save it, e.g. `~/keys/dripzzee-admin.json` (never commit it).

Get coordinates for where you'll test: long-press the spot in Google Maps
and copy the `lat, lng` shown.

```bash
cd ~/ZManikya/Dripzzee/seed && npm install
export GOOGLE_APPLICATION_CREDENTIALS=~/keys/dripzzee-admin.json
node seed.js --lat <latitude> --lng <longitude>
# later: node seed.js --lat … --lng … --reset   or   node seed.js --reset-only
```

This creates 8 stores (5 with a festive edit), 45 products within ~8 km
(including the Navratri pieces the Home campaign links to) and 3 demo
coupons. Optional test photos: `node ai_images.js`.

## 7. Run, check, build

```bash
cd ~/ZManikya/Dripzzee/customer_app
flutter pub get
dart format .
flutter analyze
flutter test
flutter run                     # phone connected with USB debugging
flutter build apk --release
```

APK: `build/app/outputs/flutter-apk/app-release.apk`.

If `flutter analyze` or a build reports errors, copy the full output and
send it over.

## 8. Try the full journey

1. Log in with your phone number + OTP → allow location (or search it).
2. Home → tap a Navratri card → add a chaniya choli (pick a size) → cart.
3. Checkout → add address → apply `DRIP50` → **Cash on delivery** → the
   order appears in Orders.
4. Simulate the store: Firestore console → `orders/<id>` → change `status`
   to `ACCEPTED`, then `PREPARING`, … `DELIVERED`. The tracking screen and
   push notifications update live. (The retailer app does this in
   production.)
5. After `DELIVERED`: rate the order, request a return/exchange.
6. Pay online with the Razorpay test card; try cancelling the sheet too.
7. Wishlist the sold-out "Anklet Pair", then set one of its `sizes` above 0
   in the console → you get a "Back in stock" notification.

## Retailer app (same backend)

The retailer app must:
- sign retailers in with a custom claim `{ role: 'retailer', storeId }`
  (set once with the Admin SDK: `getAuth().setCustomUserClaims(uid, {...})`),
- write its device tokens to `stores/{storeId}.fcmTokens` to receive "New
  order" / return notifications,
- move orders through the statuses and set `return_requests/{id}.status`
  to `APPROVED` / `REJECTED` / `COMPLETED`.
Rules already allow exactly those writes.
