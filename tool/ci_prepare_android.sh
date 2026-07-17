#!/usr/bin/env bash
set -euo pipefail
# Called after `flutter create --platforms=android,ios --org ir.abtin .`
#
# `flutter create` on a directory that already has a pubspec.yaml derives the
# Android/iOS project name from the *pubspec* name ("abtin_navigator"), not
# from any --project-name flag. Combined with --org ir.abtin that produces
# applicationId/namespace "ir.abtin.abtin_navigator" and a fresh, empty
# MainActivity.kt under .../kotlin/ir/abtin/abtin_navigator/.
#
# That does NOT match this repo's real native implementation, which ships at
# android/app/src/main/kotlin/ir/abtin/navigator/MainActivity.kt with package
# "ir.abtin.navigator" (routing/vosk/car-projection MethodChannels). Likewise
# android/app/src/main/AndroidManifest.xml.template and
# android/app/build.gradle.snippet were never actually merged into the files
# flutter create generates. Left alone, the app would build "successfully"
# but ship the empty stub Activity with no permissions, deep links, or
# Android Auto metadata. This script fixes that up.

APP_DIR="android/app"
PKG_DIR_OLD_ROOT="$APP_DIR/src/main/kotlin/ir/abtin"
REAL_PKG_DIR="$PKG_DIR_OLD_ROOT/navigator"

echo "== ci_prepare_android: fixing applicationId/namespace =="
for GRADLE in "$APP_DIR/build.gradle" "$APP_DIR/build.gradle.kts"; do
  [ -f "$GRADLE" ] || continue
  sed -i 's/ir\.abtin\.abtin_navigator/ir.abtin.navigator/g' "$GRADLE" || true
  sed -i 's/applicationId = "[^"]*"/applicationId = "ir.abtin.navigator"/' "$GRADLE" || true
  sed -i 's/applicationId "[^"]*"/applicationId "ir.abtin.navigator"/' "$GRADLE" || true
  sed -i 's/namespace = "[^"]*"/namespace = "ir.abtin.navigator"/' "$GRADLE" || true
  sed -i 's/namespace "[^"]*"/namespace "ir.abtin.navigator"/' "$GRADLE" || true
done

echo "== ci_prepare_android: removing stray auto-generated MainActivity =="
if [ -d "$PKG_DIR_OLD_ROOT" ]; then
  for d in "$PKG_DIR_OLD_ROOT"/*/; do
    [ -d "$d" ] || continue
    if [ "$(realpath "$d")" != "$(realpath "$REAL_PKG_DIR")" ]; then
      echo "  removing unused stub package: $d"
      rm -rf "$d"
    fi
  done
fi

echo "== ci_prepare_android: applying real AndroidManifest.xml =="
MANIFEST="$APP_DIR/src/main/AndroidManifest.xml"
TEMPLATE="$APP_DIR/src/main/AndroidManifest.xml.template"
if [ -f "$TEMPLATE" ] && [ -f "$MANIFEST" ]; then
  # Strip the leading "this is a template" XML comment, keep the rest as-is.
  awk '/-->/{f=1;next} f' "$TEMPLATE" > "$MANIFEST"
  echo "  merged $TEMPLATE -> $MANIFEST"
fi

echo "== ci_prepare_android: applying build.gradle.snippet (minSdk/multiDex/jniLibs) =="
for GRADLE in "$APP_DIR/build.gradle" "$APP_DIR/build.gradle.kts"; do
  [ -f "$GRADLE" ] || continue
  if [[ "$GRADLE" == *.kts ]]; then
    sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 24/' "$GRADLE" || true
    sed -i 's/minSdk = [0-9]\+/minSdk = 24/' "$GRADLE" || true
    if ! grep -q "multiDexEnabled" "$GRADLE"; then
      sed -i '/defaultConfig {/a\        multiDexEnabled = true' "$GRADLE" || true
    fi
  else
    sed -i 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 24/' "$GRADLE" || true
    sed -i 's/minSdkVersion [0-9]\+/minSdkVersion 24/' "$GRADLE" || true
    if ! grep -q "multiDexEnabled" "$GRADLE"; then
      sed -i '/defaultConfig {/a\        multiDexEnabled true' "$GRADLE" || true
    fi
  fi
  if ! grep -q "useLegacyPackaging" "$GRADLE"; then
    printf '\nandroid.packagingOptions.jniLibs.useLegacyPackaging = true\n' >> "$GRADLE"
  fi
done

echo "ci_prepare_android: done"
