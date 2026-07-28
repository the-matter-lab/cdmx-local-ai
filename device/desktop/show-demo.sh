#!/bin/sh
set -eu

FRAME="${DEMO_FRAME:-/var/lib/cdmx-local-ai/demo/latest.png}"
i=0
while [ ! -r "$FRAME" ] && [ "$i" -lt 60 ]; do
    i=$((i + 1))
    sleep 1
done

if ! command -v feh >/dev/null 2>&1; then
    exec xterm -title 'Bayesian Optimization' -geometry 80x42+640+54 \
        -e sh -c 'echo "feh is not installed; install it to view the demo."; sleep 86400'
fi

if [ ! -r "$FRAME" ]; then
    exec xterm -title 'Bayesian Optimization' -geometry 80x42+640+54 \
        -e sh -c 'echo "Waiting for cdmx-demo.service to create a frame."; sleep 86400'
fi

exec feh --title 'Bayesian Optimization' --borderless --scale-down \
    --reload 2 --image-bg '#111827' "$FRAME"
