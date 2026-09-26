# Dripzzee — update v2

Phone-OTP login, new Home, appearance modes, coupons, swipe-to-buy,
new checkout, app icon, Terms & Privacy.

Run everything from `~/ZManikya/Dripzzee/dripzzee_update`.

## 1. Put the new code in place

`lib/firebase_options.dart` is yours (generated for your Firebase project), so
keep a copy while replacing the code:

```bash
cd ~/ZManikya/Dripzzee/dripzzee_update
cp customer_app/lib/firebase_options.dart /tmp/firebase_options.dart
rm -rf customer_app/lib customer_app/test
unzip -o ~/Downloads/dripzzee_update_v2.zip -d .
cp /tmp/firebase_options.dart customer_app/lib/firebase_options.dart
```

## 2. Android setup (adds the new app icon)

```bash
cd customer_app
bash tools/setup_android.sh
```

## 3. Firebase console

1. **Authentication → Sign-in method → Add new provider → Phone → Enable → Save.**
2. Same Phone page → **Phone numbers for testing** → add your number with a
   fixed code (e.g. `+91 98192 88848` → `123456`). Test numbers work
   without SMS and without the Blaze plan. Real SMS to any number needs Blaze.
3. **Settings → General → your Android app → Add fingerprint** → add SHA-1
   and SHA-256 (phone OTP and Google sign-in both need them):
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep -E 'SHA1|SHA256'
   ```
4. **Firestore → Rules** → replace with the new rules → **Publish**:
   ```bash
   wl-copy < ~/ZManikya/Dripzzee/dripzzee_update/firestore.rules
   ```

## 4. Add the demo coupons

```bash
cd ~/ZManikya/Dripzzee/dripzzee_update/seed
export GOOGLE_APPLICATION_CREDENTIALS=~/keys/dripzzee-admin.json
node seed.js --coupons-only
```

Creates `WELCOME100`, `NAVRATRI15` and `DRIP50`.

## 5. Build

```bash
cd ~/ZManikya/Dripzzee/dripzzee_update/customer_app
flutter pub get
flutter analyze
flutter build apk --release
```

Uninstall the old app from the phone first if the new icon doesn't show
(launchers cache icons).

## Notes

- Ordering, coupons at checkout, payments and notifications still need the
  backend deployed (Blaze plan + `firebase deploy`, see SETUP.md §5). The
  functions in this zip include the coupon logic.
- Login images are AI test images from pollinations.ai; replace them in
  `lib/features/auth/widgets/fashion_mosaic.dart` with brand photos later.
- Support, legal and grievance details live in
  `lib/core/config/app_config.dart`.
