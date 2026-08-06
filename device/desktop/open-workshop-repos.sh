#!/bin/sh
set -eu

exec xterm -title 'Workshop Code Download' -geometry 110x32 \
    -fa Monospace -fs 10 -bg '#000000' -fg '#e5e7eb' \
    -e /bin/bash -lc '/usr/local/bin/cdmx-get-workshop-repos; result=$?; printf "\n"; if [ "$result" -eq 0 ]; then echo "Download/update complete. You may close this terminal."; else echo "Download/update failed. Read the message above, then try again."; fi; exec /bin/bash -l'
