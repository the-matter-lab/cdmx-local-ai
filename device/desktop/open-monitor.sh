#!/bin/sh
set -eu

exec xterm -title 'System Monitor' -geometry 100x30 \
    -fa Monospace -fs 10 -bg '#111827' -fg '#86efac' \
    -e top
