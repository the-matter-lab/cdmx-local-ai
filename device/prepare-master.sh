#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { printf 'Run cdmx-prepare-master with sudo.\n' >&2; exit 77; }
[[ ${1:-} == --yes-really-power-off ]] || {
    printf '%s\n' 'This removes per-device identity, saved Wi-Fi, API/channel secrets, and powers off.'
    printf '%s\n' 'Re-run: sudo cdmx-prepare-master --yes-really-power-off'
    exit 64
}

systemctl stop cdmx-picoclaw.service cdmx-novnc.service cdmx-desktop.service \
    cdmx-demo.service smbd.service 2>/dev/null || true
nmcli connection delete cdmx-venue >/dev/null 2>&1 || true
nmcli connection delete cdmx-setup >/dev/null 2>&1 || true
rm -f /etc/NetworkManager/system-connections/cdmx-venue.nmconnection \
    /etc/NetworkManager/system-connections/cdmx-setup.nmconnection
rm -f /etc/ssh/ssh_host_*
rm -f /etc/cdmx/agent.env /home/cdmx/.picoclaw/.security.yml \
    /etc/cdmx-picoclaw/config.json /etc/cdmx-picoclaw/.security.yml
rm -rf /home/cdmx/.pi/agent/sessions /home/cdmx/.picoclaw/sessions \
    /var/lib/cdmx-picoclaw/sessions
rm -f /home/cdmx/.bash_history /root/.bash_history
find /var/log -type f -exec truncate -s 0 {} +
rm -f /var/lib/systemd/random-seed
: > /etc/machine-id
rm -f /var/lib/dbus/machine-id
install -d -m 0755 /etc/cdmx
touch /etc/cdmx/needs-personalization
rm -f /config/cdmx-team.env
sync
printf 'Master is sanitized. Powering off; do not boot this card before capture.\n'
systemctl poweroff
