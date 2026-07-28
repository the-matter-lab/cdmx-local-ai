#!/bin/sh
set -eu

clear
printf '%s\n' \
    'CDMX Local AI — Pi Agent' \
    'Local interactive agent. Telegram/Discord use the separate PicoClaw service.' \
    ''

if command -v pi-agent >/dev/null 2>&1; then
    exec pi-agent
elif command -v pi >/dev/null 2>&1; then
    exec pi
fi

printf '%s\n' \
    'The agent CLI is not configured yet.' \
    'Run cdmx-agent-setup, or use this shell for local work.' \
    ''
exec /bin/bash -l
