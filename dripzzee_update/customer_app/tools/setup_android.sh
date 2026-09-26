#!/usr/bin/env bash
# Applies the Android-side configuration the app needs. Safe to run twice.
#   cd customer_app && bash tools/setup_android.sh
set -euo pipefail

cd "$(dirname "$0")/.."
APP=android/app
MANIFEST=$APP/src/main/AndroidManifest.xml
GRADLE=$APP/build.gradle.kts

if [[ ! -f "$MANIFEST" ]]; then
  echo "✗ $MANIFEST not found. Run this from inside customer_app after 'flutter create'." >&2
  exit 1
fi
command -v python3 >/dev/null || { echo "✗ python3 is required (sudo pacman -S python)" >&2; exit 1; }

python3 - "$MANIFEST" <<'PY'
import re, sys
path = sys.argv[1]
s = open(path, encoding="utf-8").read()
perms = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.POST_NOTIFICATIONS",
]
missing = [p for p in perms if p not in s]
if missing:
    block = "".join(f'    <uses-permission android:name="{p}"/>\n' for p in missing)
    s = re.sub(r"(<manifest[^>]*>\n?)", lambda m: m.group(1) + block, s, count=1)
# Razorpay UPI intent flow + mail links on Android 11+
if 'android:scheme="upi"' not in s:
    q = ('    <queries>\n'
         '        <intent>\n'
         '            <action android:name="android.intent.action.VIEW"/>\n'
         '            <data android:scheme="upi"/>\n'
         '        </intent>\n'
         '        <intent>\n'
         '            <action android:name="android.intent.action.SENDTO"/>\n'
         '            <data android:scheme="mailto"/>\n'
         '        </intent>\n'
         '    </queries>\n')
    if "<queries>" in s:
        s = s.replace("<queries>\n", q.split("\n", 1)[1].rsplit("    </queries>", 1)[0].join(["<queries>\n", ""]), 1)
    else:
        s = s.replace("</manifest>", q + "</manifest>", 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Dripzzee"', s, count=1)
open(path, "w", encoding="utf-8").write(s)
print("✓ AndroidManifest: permissions, UPI/mail queries, app label")
PY

if [[ -f "$GRADLE" ]]; then
  if grep -q 'minSdk = flutter.minSdkVersion' "$GRADLE"; then
    sed -i 's/minSdk = flutter.minSdkVersion/minSdk = maxOf(flutter.minSdkVersion, 23)/' "$GRADLE"
  fi
  echo "✓ build.gradle.kts: minSdk ≥ 23 (Firebase Auth)"
fi

cat > $APP/proguard-rules.pro <<'PRO'
# Razorpay
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/
-keepclasseswithmembers class * {
  public void onPayment*(...);
}
# Google Pay inside Razorpay
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.**
-keep class com.google.android.apps.nbu.paisa.inapp.client.api.** {*;}
PRO
if [[ -f "$GRADLE" ]] && ! grep -q 'proguard-rules.pro' "$GRADLE"; then
  python3 - "$GRADLE" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
m = re.search(r'buildTypes\s*\{\s*release\s*\{', s)
if m:
    ins = '\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")'
    s = s[:m.end()] + ins + s[m.end():]
    open(p, "w").write(s)
PY
fi
echo "✓ proguard-rules.pro (Razorpay keep rules)"

for dir in drawable drawable-v21; do
  mkdir -p "$APP/src/main/res/$dir"
  cat > "$APP/src/main/res/$dir/launch_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item android:drawable="@color/dripzzee_ink" />
</layer-list>
XML
done
mkdir -p "$APP/src/main/res/values"
cat > "$APP/src/main/res/values/dripzzee_colors.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="dripzzee_ink">#FF0A0A0C</color>
</resources>
XML
echo "✓ Dark launch screen (#0A0A0C)"

if [[ -d tools/icon/res ]]; then
  cp -r tools/icon/res/. "$APP/src/main/res/"
  echo "✓ App icon (Dripzzee logo on navy)"
fi

echo
echo "Android setup done. Next: flutterfire configure (see SETUP.md)."
