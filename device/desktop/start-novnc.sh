#!/bin/sh
set -eu

ROOT="${CDMX_ROOT:-$(cd -- "$(dirname -- "$0")/../.." && pwd)}"
RUNTIME_DIR="${RUNTIME_DIRECTORY:-/run/cdmx-novnc}"
WEBROOT="$RUNTIME_DIR/web"
NOVNC_ROOT="${NOVNC_ROOT:-/usr/share/novnc}"

if [ ! -r "$NOVNC_ROOT/vnc.html" ]; then
    echo "noVNC web assets not found in $NOVNC_ROOT" >&2
    exit 69
fi
if ! command -v websockify >/dev/null 2>&1; then
    echo "websockify is not installed" >&2
    exit 69
fi

mkdir -p "$WEBROOT"
cp -as "$NOVNC_ROOT"/. "$WEBROOT"/
cp "$ROOT/device/desktop/novnc-web/control.html" "$WEBROOT/control.html"
cp "$ROOT/device/desktop/novnc-web/view.html" "$WEBROOT/view.html"

echo "Controller: http://HOST:6080/control.html"
echo "View only: http://HOST:6080/view.html"
exec websockify --web "$WEBROOT" 0.0.0.0:6080 127.0.0.1:5901
