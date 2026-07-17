#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/../abtin_navigator_complete.zip}"
cd "$ROOT"
# exclude junk
zip -r "$OUT" . \
  -x '*/.dart_tool/*' \
  -x '*/build/*' \
  -x '*/.idea/*' \
  -x '*/android/.gradle/*' \
  -x '*/ios/Pods/*' \
  -x '*/src_dump/*' \
  -x '*.iml'
echo "Packed: $OUT"
ls -lh "$OUT"
