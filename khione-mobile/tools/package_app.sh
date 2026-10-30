#!/bin/bash
# Zips khione-mobile/app (minus build output) for syncing into the Higgsfield
# website repo, which lives in Higgsfield's cloud sandbox.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/tmp/khione-app.zip}"
rm -f "$OUT"
cd "$HERE"
zip -qr "$OUT" app -x 'app/node_modules/*' 'app/dist/*' 'app/.wrangler/*' 'app/public/js/dev/*' '*.DS_Store'
ls -la "$OUT"
