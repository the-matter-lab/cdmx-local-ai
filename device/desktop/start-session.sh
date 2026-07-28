#!/bin/sh
set -eu

DISPLAY_NUMBER="${DISPLAY_NUMBER:-1}"
DISPLAY=":${DISPLAY_NUMBER}"
export DISPLAY
ROOT="${CDMX_ROOT:-$(cd -- "$(dirname -- "$0")/../.." && pwd)}"
RUNTIME_DIR="${RUNTIME_DIRECTORY:-/run/cdmx-desktop}"
AUTH_FILE="$RUNTIME_DIR/Xauthority"
VNC_PASSWORD_FILE="${VNC_PASSWORD_FILE:-/etc/cdmx-local-ai/vnc.passwd}"

if [ ! -r "$VNC_PASSWORD_FILE" ]; then
    echo "Missing $VNC_PASSWORD_FILE. Create it with: tigervncpasswd $VNC_PASSWORD_FILE" >&2
    exit 78
fi

XVNC="$(command -v Xtigervnc || command -v Xvnc || true)"
if [ -z "$XVNC" ]; then
    echo "TigerVNC server not found (expected Xtigervnc or Xvnc)." >&2
    exit 69
fi
for command_name in mcookie xauth openbox xterm xsetroot; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Required desktop command not found: $command_name" >&2
        exit 69
    fi
done

mkdir -p "$RUNTIME_DIR"
touch "$AUTH_FILE"
chmod 600 "$AUTH_FILE"
XAUTHORITY="$AUTH_FILE"
export XAUTHORITY
xauth -f "$AUTH_FILE" add "$DISPLAY" . "$(mcookie)"

cleanup() {
    trap - EXIT INT TERM
    for pid in ${CHILDREN:-}; do
        kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true
}
trap cleanup EXIT INT TERM

"$XVNC" "$DISPLAY" \
    -geometry 1280x720 -depth 24 \
    -localhost yes -SecurityTypes VncAuth \
    -PasswordFile "$VNC_PASSWORD_FILE" \
    -AlwaysShared -AcceptKeyEvents -AcceptPointerEvents \
    -DisconnectClients=0 -NeverShared=0 \
    -rfbport 5901 -auth "$AUTH_FILE" \
    -Log '*:stderr:30' &
XVNC_PID=$!
CHILDREN="$XVNC_PID"

i=0
while [ ! -S "/tmp/.X11-unix/X${DISPLAY_NUMBER}" ] && [ "$i" -lt 50 ]; do
    kill -0 "$XVNC_PID" 2>/dev/null || {
        wait "$XVNC_PID" || true
        exit 1
    }
    i=$((i + 1))
    sleep 0.1
done

openbox --config-file "$ROOT/device/desktop/openbox.xml" &
CHILDREN="$CHILDREN $!"

xsetroot -solid '#111827'
xterm -title 'System Status' -geometry 160x3+0+0 \
    -fa Monospace -fs 9 -bg '#111827' -fg '#86efac' \
    -e "$ROOT/device/desktop/system-status.sh" &
CHILDREN="$CHILDREN $!"

xterm -title 'Pi Agent' -geometry 80x21+0+54 \
    -fa Monospace -fs 10 -bg '#0b1020' -fg '#e5e7eb' \
    -e "$ROOT/device/desktop/pi-terminal.sh" &
CHILDREN="$CHILDREN $!"

xterm -title 'Channel + Workspace' -geometry 80x20+0+384 \
    -fa Monospace -fs 9 -bg '#0b1020' -fg '#bfdbfe' \
    -e "$ROOT/device/desktop/code-viewer.sh" &
CHILDREN="$CHILDREN $!"

"$ROOT/device/desktop/show-demo.sh" &
CHILDREN="$CHILDREN $!"

wait "$XVNC_PID"
