#!/usr/bin/env bash
# Generates the Android Gradle skeleton with the Flutter version on THIS machine,
# overlays this project's native code, then builds. Safe to run repeatedly.
#
#   ./scripts/bootstrap.sh            -> pub get, format, analyze, test, Debug APK
#   ./scripts/bootstrap.sh --release  -> same + Release APK
#
# Design: analyze/test failures are RECORDED but do not block the APK (the code
# was written without a compiler, so you want the APK and the error list in the
# same run). Only a failed build exits non-zero. Everything lands in dist/.
set -uo pipefail
cd "$(dirname "$0")/.."

WANT_RELEASE=0
[ "${1:-}" = "--release" ] && WANT_RELEASE=1

mkdir -p dist
: > dist/checks.txt

note() { echo "$*" | tee -a dist/checks.txt; }
warn() { echo "::warning::$*"; echo "WARNING: $*" >> dist/checks.txt; }

command -v flutter >/dev/null 2>&1 || { echo "ERROR: Flutter SDK not found in PATH"; exit 1; }
flutter --version 2>&1 | head -n 3 | tee -a dist/checks.txt

# ---- 1. Android skeleton (only if missing) -------------------------------
if [ ! -f android/app/build.gradle ] && [ ! -f android/app/build.gradle.kts ]; then
  note "== flutter create (android/ was missing) =="
  flutter create --platforms=android --org dev.autocontinue \
    --project-name claude_auto_continue . > dist/create.txt 2>&1
  rc=$?
  tail -n 15 dist/create.txt
  if [ $rc -ne 0 ]; then
    note "flutter create FAILED (exit $rc)"
    exit 1
  fi
fi

# ---- 2. overlay our manifest / Kotlin / resources ------------------------
mkdir -p android/app/src/main
cp -R android_overlay/. android/app/src/main/

# Our Kotlin uses API 26+ directly (notification channels, startForegroundService).
for f in android/app/build.gradle android/app/build.gradle.kts; do
  if [ -f "$f" ]; then
    sed -i.bak -E 's/flutter\.minSdkVersion/26/' "$f" && rm -f "$f.bak"
    sed -i.bak -E 's/(minSdk(Version)?[[:space:]]*=?[[:space:]]*)(1[0-9]|2[0-5])([^0-9]|$)/\126\4/' "$f" && rm -f "$f.bak"
  fi
done
if ! grep -qsE 'minSdk(Version)?[[:space:]]*=?[[:space:]]*26' android/app/build.gradle android/app/build.gradle.kts; then
  warn "could not force minSdk 26 automatically; check android/app/build.gradle(.kts)"
fi

# Package check: Kotlin package must equal the generated namespace.
NS=$(grep -hoE '(namespace|applicationId)[[:space:]]*=?[[:space:]]*"[^"]+"' android/app/build.gradle* 2>/dev/null | head -n 1 | sed -E 's/.*"([^"]+)"/\1/')
note "namespace/applicationId: ${NS:-unknown}"
if [ -n "${NS:-}" ] && [ "$NS" != "dev.autocontinue.claude_auto_continue" ]; then
  warn "namespace is '$NS' but Kotlin files use dev.autocontinue.claude_auto_continue"
fi

if grep -q "MyApp" test/widget_test.dart 2>/dev/null; then
  echo "ERROR: test/widget_test.dart was replaced by the template; restore it."; exit 1
fi

# ---- 3. dependencies -----------------------------------------------------
note "== flutter pub get =="
flutter pub get > dist/pub_get.txt 2>&1
rc=$?
tail -n 8 dist/pub_get.txt
if [ $rc -ne 0 ]; then note "pub get FAILED (exit $rc)"; exit 1; fi

# ---- 4. non-blocking checks ---------------------------------------------
dart format lib test > dist/format.txt 2>&1 || true

note "== flutter analyze =="
flutter analyze --no-fatal-infos > dist/analyze.txt 2>&1
ANALYZE_RC=$?
tail -n 40 dist/analyze.txt
note "analyze exit: $ANALYZE_RC"
[ $ANALYZE_RC -ne 0 ] && warn "flutter analyze reported problems (see dist/analyze.txt)"

note "== flutter test =="
flutter test > dist/test.txt 2>&1
TEST_RC=$?
tail -n 40 dist/test.txt
note "test exit: $TEST_RC"
[ $TEST_RC -ne 0 ] && warn "flutter test failed (see dist/test.txt)"

# ---- 5. build ------------------------------------------------------------
build() { # $1 = debug|release
  note "== flutter build apk --$1 =="
  flutter build apk --"$1" > "dist/build_$1.txt" 2>&1
  local rc=$?
  tail -n 40 "dist/build_$1.txt"
  note "build $1 exit: $rc"
  if [ $rc -ne 0 ]; then
    { echo "BUILD FAILED ($1). Key lines:"; \
      grep -nE "^e: |error:|Error:|FAILURE|What went wrong|Execution failed|Could not|not found|unresolved|Unresolved" "dist/build_$1.txt" | head -n 60; } \
      | tee dist/ERRORS.txt
    return $rc
  fi
  cp "build/app/outputs/flutter-apk/app-$1.apk" "dist/claude-auto-continue-$1.apk"
}

build debug || exit 1
if [ $WANT_RELEASE -eq 1 ]; then
  build release || exit 1
  note "NOTE: release APK is signed with the DEBUG key unless key.properties is configured."
fi

note "== done =="
ls -l dist/*.apk
exit 0
