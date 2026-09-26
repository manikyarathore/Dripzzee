# Install this zip

This zip is the complete Dripzzee project EXCEPT three files that are unique
to your Firebase project and your machine (they are never inside the zip, so
extracting it never deletes or overwrites them):

- customer_app/android/                       (created by `flutter create`)
- customer_app/android/app/google-services.json
- customer_app/lib/firebase_options.dart

Extract it INTO your existing project folder, replacing files:

    unzip -o ~/Downloads/dripzzee_update.zip -d ~/ZManikya/Dripzzee/dripzzee_update

Then build:

    cd ~/ZManikya/Dripzzee/dripzzee_update/customer_app
    bash tools/setup_android.sh
    python3 tools/gen_firebase_options.py
    flutter pub get
    flutter build apk --release

See FIX_LOGIN.md for the login fix, UPDATE_V2.md for the Firebase console steps (Phone sign-in, rules,
coupons) and SETUP.md for the full first-time setup.
