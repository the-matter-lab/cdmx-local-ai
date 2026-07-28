#!/bin/sh
set -eu

ROOT="${CDMX_ROOT:-$(cd -- "$(dirname -- "$0")/../.." && pwd)}"
OUTPUT="${DEMO_FRAME:-/var/lib/cdmx-local-ai/demo/latest.png}"
exec python3 -u "$ROOT/device/demo/bayesian_optimization.py" \
    --output "$OUTPUT" --interval "${DEMO_INTERVAL:-2}"
