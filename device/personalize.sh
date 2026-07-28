#!/usr/bin/env bash
set -euo pipefail

marker=/config/cdmx-team.env
sentinel=/etc/cdmx/needs-personalization
config=/etc/cdmx/workshop.conf

[[ $EUID -eq 0 ]] || { printf 'cdmx-personalize must run as root.\n' >&2; exit 77; }

if [[ ! -e $marker ]]; then
    if [[ -e $sentinel ]]; then
        printf 'Golden image needs %s; refusing to start cloned network services.\n' "$marker" >&2
        exit 1
    fi
    exit 0
fi

team=$(awk -F= '$1 == "CDMX_TEAM" {print $2; exit}' "$marker")
requested_hostname=$(awk -F= '$1 == "CDMX_HOSTNAME" {print $2; exit}' "$marker")
case "$team" in 1|2|3|4|5|6|7|8|9|10) ;; *) printf 'Invalid CDMX_TEAM marker.\n' >&2; exit 65 ;; esac
hostname="equipo$team"
[[ $requested_hostname == "$hostname" ]] || { printf 'Hostname marker does not match team.\n' >&2; exit 65; }

install -d -m 0755 /etc/cdmx
cat > "$config" <<EOF
TEAM=$team
HOSTNAME=$hostname
AP_SSID=${hostname}-setup
WIFI_COUNTRY=MX
WORKSHOP_USER=cdmx
EOF
chmod 0644 "$config"
printf '%s\n' "$hostname" > /etc/hostname
hostname "$hostname"
cat > /etc/hosts <<EOF
127.0.0.1 localhost
127.0.1.1 $hostname
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# These values must be unique after cloning a golden card.
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A
rm -f /etc/NetworkManager/system-connections/cdmx-setup.nmconnection
nmcli connection reload 2>/dev/null || true

if [[ -f /etc/samba/cdmx-workshop.conf ]]; then
    sed -i -E "s/^    comment = Equipo [0-9]+ workspace$/    comment = Equipo $team workspace/" \
        /etc/samba/cdmx-workshop.conf
fi

rm -f "$marker" "$sentinel"
sync /config || sync
printf 'Personalized this card as %s.\n' "$hostname"
