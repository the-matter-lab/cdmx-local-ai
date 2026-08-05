#!/usr/bin/env bash
set -euo pipefail

sentinel=/etc/cdmx/needs-personalization
config=/etc/cdmx/workshop.conf
marker=
marker_dir=
for directory in /config /boot/efi /boot; do
    if [[ -f $directory/cdmx-team.env ]]; then
        marker=$directory/cdmx-team.env
        marker_dir=$directory
        break
    fi
done

[[ $EUID -eq 0 ]] || { printf 'cdmx-personalize must run as root.\n' >&2; exit 77; }

if [[ -z $marker ]]; then
    if [[ -e $sentinel ]]; then
        printf 'Golden image needs cdmx-team.env on its FAT boot partition; refusing to start cloned network services.\n' >&2
        exit 1
    fi
    exit 0
fi

team=$(awk -F= '$1 == "CDMX_TEAM" {print $2; exit}' "$marker")
requested_hostname=$(awk -F= '$1 == "CDMX_HOSTNAME" {print $2; exit}' "$marker")
case "$team" in
    0|1|2|3|4|5|6|7|8|9) hostname="equipo$team"; network_index=$team ;;
    admin) hostname=admin; network_index=10 ;;
    *) printf 'Invalid CDMX_TEAM marker.\n' >&2; exit 65 ;;
esac
[[ $requested_hostname == "$hostname" ]] || { printf 'Hostname marker does not match team.\n' >&2; exit 65; }

install -d -m 0755 /etc/cdmx
cat > "$config" <<EOF
TEAM=$team
HOSTNAME=$hostname
AP_SSID=${hostname}-setup
WIFI_COUNTRY=MX
WORKSHOP_USER=cdmx
OPEN_ACCESS=1
NETWORK_INDEX=$network_index
EOF
chmod 0644 "$config"
install -d -m 0755 /etc/NetworkManager/dnsmasq-shared.d
cat > /etc/NetworkManager/dnsmasq-shared.d/10-cdmx-captive.conf <<EOF
address=/#/10.42.$network_index.1
dhcp-option-force=114,http://10.42.$network_index.1:8080/captive-api
EOF
chmod 0644 /etc/NetworkManager/dnsmasq-shared.d/10-cdmx-captive.conf
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

rm -f "$marker" "$sentinel"
sync "$marker_dir" || sync
printf 'Personalized this card as %s.\n' "$hostname"
