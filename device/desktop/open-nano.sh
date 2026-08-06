#!/bin/sh
set -eu

WORKSPACE="${CDMX_WORKSPACE:-/var/lib/cdmx-picoclaw/workspace}"
START_DIR="$HOME"
[ ! -d "$WORKSPACE" ] || START_DIR="$WORKSPACE"
cd "$START_DIR"
exec xterm -title 'Workspace Editor — Nano' -geometry 110x34 \
    -fa Monospace -fs 10 -bg '#0b1020' -fg '#e5e7eb' -e nano
