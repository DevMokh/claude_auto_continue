#!/usr/bin/env bash
# Generates the Android Gradle skeleton with YOUR Flutter version, overlays this
# project's native code on top, then runs the full verification pipeline.
#
#   ./scripts/bootstrap.sh            -> pub get, format, analyze, test, debug APK
#   ./scripts/bootstrap.sh --release  -> same + release APK (see README: signing)
#
# Why: the Gradle wrapper/templates differ per Flutter release and cannot be
# written reliably by hand. `flutter create` makes the right ones for you.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null 2>&1 || { echo "ERROR: Flutter SDK not found in PATH"; exit 1; }

if [ ! -d android ]; then
  flutter create --platforms=android --org dev.autocontinue --project-name claude_auto_continue .
fi

# Overlay our manifest, Kotlin sources and resources (overwrites template files).
mkdir -p android/app/src/main
cp -R android_overlay/. android/app/src/main/

# We use API 26+ notification/FGS APIs directly. Force minSdk 26.
for f in android/app/build.gradle android/app/build.gradle.kts; do
  if [ -f "$f" ]; then
    sed -i.bak -E 's/flutter\.minSdkVersion/26/' "$f" && rm -f "$f.bak"
  fi
done
if ! grep -qsE 'minSdk(Version)?[ =]+26' android/app/build.gradle android/app/build.gradle.kts; then
  echo "WARNING: could not set minSdk 26 automatically. Set it by hand in android/app/build.gradle(.kts)."
fi

# The template's default test references a counter app we do not have.
# (We ship our own test/widget_test.dart, so nothing to do unless it was regenerated.)
if grep -q "MyApp" test/widget_test.dart 2>/dev/null; then
  echo "ERROR: test/widget_test.dart was overwritten by the template; restore it from the ZIP."; exit 1
fi

flutter pub get
dart format lib test
flutter analyze --no-fatal-infos
flutter test

flutter build apk --debug
mkdir -p dist
cp build/app/outputs/flutter-apk/app-debug.apk dist/claude-auto-continue-debug.apk

if [ "${1:-}" = "--release" ]; then
  flutter build apk --release
  cp build/app/outputs/flutter-apk/app-release.apk dist/claude-auto-continue-release.apk
  echo "NOTE: release APK is signed with the DEBUG key unless you configured key.properties."
fi

ls -l dist
