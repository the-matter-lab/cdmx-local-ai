#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PORT=${CDMX_IMAGER_PORT:-8766}
PYTHON=$(command -v python3)

printf 'CDMX SD Imager\n'
printf 'macOS will ask once for permission to access removable SD cards.\n'
printf 'No password is stored or written to a Radxa.\n\n'

(
  for _ in {1..60}; do
    if curl --fail --silent "http://127.0.0.1:${PORT}/api/state" >/dev/null 2>&1; then
      open "http://127.0.0.1:${PORT}/"
      exit 0
    fi
    sleep 0.5
  done
) &

exec sudo "$PYTHON" "$ROOT/host/imager_app.py" --port "$PORT"
