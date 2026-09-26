# Fix: phone OTP and Google sign-in

This update switches Google sign-in to the native Android account picker,
and every login error now shows a small "(Error code: …)" line so problems
can be pinpointed from a screenshot.

## 1. Extract over your project

```bash
unzip -o ~/Downloads/dripzzee_update.zip -d ~/ZManikya/Dripzzee/dripzzee_update
cd ~/ZManikya/Dripzzee/dripzzee_update/customer_app
```

## 2. Firebase console

1. **Project settings → Your apps → Android app** → **Add fingerprint**:
   add both SHA-1 and SHA-256 from
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android | grep -E 'SHA1|SHA256'
   ```
2. **Authentication → Sign-in method**: Phone = Enabled (with your test
   numbers), Google = Enabled.
3. **Authentication → Settings → SMS region policy**: allow **India**
   (or "Allow all").
4. Back on **Project settings → Your apps**, download **google-services.json**
   again (it must be downloaded *after* step 1).

## 3. Rebuild

```bash
mv ~/Downloads/google-services.json android/app/google-services.json
python3 tools/gen_firebase_options.py
flutter pub get
flutter build apk --release
```

The script must print:

```
✓ Google web client ID found
✓ 2 SHA fingerprint(s) registered for Android
```

If it prints a "!" line instead, fix that console step and download the file
again.

Uninstall the old app from the phone, then install the new APK.

## 4. Test

- OTP: enter one of your **test numbers** exactly (e.g. 9819288848) and type
  its test code (444444). No SMS arrives for test numbers.
  Real SMS to other numbers needs the Blaze plan.
- Google: tap **Continue with Google** and pick an account.

If either still fails, send a screenshot of the error: the "(Error code: …)"
line says exactly what's wrong.
