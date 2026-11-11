#!/usr/bin/env bash
# Verifies, then builds. The android/ project is committed, so a plain
# `flutter build apk` also works without this script. Safe to run repeatedly.
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

# ---- 1. android/ is committed (Gradle 8.14, AGP 8.11.1, Kotlin 2.2.20) ----
if [ ! -f android/app/build.gradle.kts ]; then
  echo "ERROR: android/app/build.gradle.kts is missing. Restore the android/ folder from the ZIP."
  exit 1
fi
note "android/: present"

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
