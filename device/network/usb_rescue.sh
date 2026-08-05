#!/bin/sh
set -eu

config=/etc/cdmx/workshop.conf
team=$(awk -F= '$1 == "TEAM" {print $2; exit}' "$config")
case "$team" in
    0|1|2|3|4|5|6|7|8|9) network_index=$team ;;
    admin) network_index=10 ;;
    *) exit 1 ;;
esac

# Radxa's NCM service creates usb0 only after the peripheral-mode overlay is
# enabled. This unit is deliberately best-effort so Wi-Fi still boots if the
# overlay or cable is absent.
for _ in $(seq 1 20); do
    if ip link show usb0 >/dev/null 2>&1; then
        nmcli connection delete cdmx-usb >/dev/null 2>&1 || true
        nmcli connection add type ethernet ifname usb0 con-name cdmx-usb \
            connection.autoconnect yes ipv4.method shared \
            ipv4.addresses "10.55.${network_index}.1/24" ipv6.method disabled
        nmcli --wait 15 connection up cdmx-usb || true
        exit 0
    fi
    sleep 1
done

printf 'usb0 is absent; enable the Radxa OTG peripheral overlay and radxa-ncm service for USB rescue.\n' >&2
exit 0
