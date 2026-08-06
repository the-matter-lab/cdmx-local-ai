#!/bin/sh
set -eu

WORKSPACE="${CDMX_WORKSPACE:-/var/lib/cdmx-picoclaw/workspace}"
START_DIR="$HOME"
TITLE='Workshop Terminal'

if [ "${1:-}" = workspace ] && [ -x "$WORKSPACE" ]; then
    START_DIR="$WORKSPACE"
    TITLE='Workspace Terminal'
fi

cd "$START_DIR"
exec xterm -title "$TITLE" -geometry 100x30 \
    -fa Monospace -fs 10 -bg '#0b1020' -fg '#e5e7eb' \
    -e /bin/bash -l
