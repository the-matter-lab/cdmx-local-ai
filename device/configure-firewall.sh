#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { printf 'Run cdmx-configure-firewall as root.\n' >&2; exit 77; }

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
for subnet in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
    ufw allow from "$subnet" to any port 22 proto tcp
    ufw allow from "$subnet" to any port 6080 proto tcp
    ufw allow from "$subnet" to any port 5353 proto udp
done
for subnet in 10.42.0.0/16 10.55.0.0/16; do
    ufw allow from "$subnet" to any port 80 proto tcp
    ufw allow from "$subnet" to any port 8080 proto tcp
    ufw allow from "$subnet" to any port 53 proto tcp
    ufw allow from "$subnet" to any port 53 proto udp
    ufw allow from "$subnet" to any port 67 proto udp
    ufw allow from "$subnet" to any port 68 proto udp
done
ufw --force enable
