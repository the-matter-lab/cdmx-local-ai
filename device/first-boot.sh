#!/usr/bin/env bash
set -euo pipefail

sentinel=/etc/cdmx/needs-runtime-init
[[ -e $sentinel ]] || exit 0

/usr/local/sbin/cdmx-configure-firewall
rm -f "$sentinel"
sync
