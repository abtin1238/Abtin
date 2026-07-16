#!/usr/bin/env bash
set -euo pipefail
# Called after `flutter create` to force minSdk 24 and disable minify.
for GRADLE in android/app/build.gradle android/app/build.gradle.kts; do
  [ -f "$GRADLE" ] || continue
  if [[ "$GRADLE" == *.kts ]]; then
    sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 24/' "$GRADLE" || true
    sed -i 's/minSdk = [0-9]\+/minSdk = 24/' "$GRADLE" || true
  else
    sed -i 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 24/' "$GRADLE" || true
    sed -i 's/minSdkVersion [0-9]\+/minSdkVersion 24/' "$GRADLE" || true
  fi
done
echo "Android prepare done"
