#!/bin/sh
set -eu

WORKSPACE="${CDMX_WORKSPACE:-/var/lib/cdmx-picoclaw/workspace}"

while :; do
    clear
    printf 'PicoClaw channel + workspace activity — %s\n\n' "$(date '+%H:%M:%S')"
    if [ -d "$WORKSPACE/.git" ]; then
        git -C "$WORKSPACE" status --short 2>/dev/null | sed -n '1,12p'
    else
        printf 'Clone team code into:\n  %s\n\n' "$WORKSPACE"
        find "$WORKSPACE" -maxdepth 2 -type f 2>/dev/null | sed -n '1,10p'
    fi
    printf '\nRecent agent log:\n'
    journalctl -u cdmx-picoclaw.service -n 7 --no-pager -o cat 2>/dev/null || \
        printf 'Agent not configured yet. Instructor: sudo cdmx-agent-setup\n'
    sleep 5
done
