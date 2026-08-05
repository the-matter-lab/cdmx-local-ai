#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
team=""
skip_upgrade=false
install_agents=true
enable_usb_ncm=false
offline_image=false
workshop_user=cdmx
authorized_key_file=""

usage() {
    cat <<'EOF'
Usage: sudo ./device/install.sh --team N [options]

Install the workshop stack on a booted Radxa ZERO 3W running the pinned RadxaOS.
Local workshop services are passwordless. SSH accepts public keys only.

Options:
  --team ID             Initial identity: 0-9 or admin
  --skip-upgrade        Skip apt full-upgrade (package lists are still refreshed)
  --skip-agents         Do not download PicoClaw/Pi now
  --enable-usb-ncm      Enable radxa-ncm if the OTG overlay was already selected
  --offline-image       Prepare a mounted image without starting host services
  --authorized-key-file PATH
                        Install an instructor SSH public key (recommended)
  -h, --help            Show this help
EOF
}

while (($#)); do
    case "$1" in
        --team) team=${2:-}; shift 2 ;;
        --skip-upgrade) skip_upgrade=true; shift ;;
        --skip-agents) install_agents=false; shift ;;
        --enable-usb-ncm) enable_usb_ncm=true; shift ;;
        --offline-image) offline_image=true; shift ;;
        --authorized-key-file) authorized_key_file=${2:-}; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 64 ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    printf 'Run this installer with sudo.\n' >&2
    exit 77
fi
case "$team" in
    0|1|2|3|4|5|6|7|8|9) device_hostname="equipo$team"; network_index=$team ;;
    admin) device_hostname=admin; network_index=10 ;;
    *) printf '%s\n' '--team must be 0-9 or admin' >&2; exit 64 ;;
esac

if [[ $(dpkg --print-architecture) != arm64 ]]; then
    printf 'This installer targets RadxaOS arm64; detected %s.\n' "$(dpkg --print-architecture)" >&2
    exit 69
fi

if [[ -n $authorized_key_file ]]; then
    [[ -r $authorized_key_file ]] || { printf 'Cannot read SSH public key: %s\n' "$authorized_key_file" >&2; exit 66; }
    if ! awk '
        NF == 0 { next }
        $1 ~ /^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521))$/ && NF >= 2 { found=1; next }
        { exit 1 }
        END { if (!found) exit 1 }
    ' "$authorized_key_file"; then
        printf 'The SSH key file must contain one or more public keys.\n' >&2
        exit 65
    fi
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
if ! $skip_upgrade; then
    apt-get -y full-upgrade
fi
apt-get install -y --no-install-recommends \
    avahi-daemon bash ca-certificates curl feh git jq locales \
    network-manager novnc openbox openssh-server python3 python3-matplotlib \
    python3-numpy rfkill sudo tigervnc-standalone-server \
    tmux ufw unattended-upgrades websockify x11-xserver-utils xauth xterm \
    zram-tools

if ! id "$workshop_user" >/dev/null 2>&1; then
    adduser --disabled-password --gecos 'CDMX workshop team' "$workshop_user"
fi
usermod -aG audio,video,render,plugdev,systemd-journal "$workshop_user"
passwd --lock "$workshop_user" >/dev/null
install -d -m 0700 -o "$workshop_user" -g "$workshop_user" "/home/$workshop_user/.ssh"
if [[ -n $authorized_key_file ]]; then
    install -m 0600 -o "$workshop_user" -g "$workshop_user" \
        "$authorized_key_file" "/home/$workshop_user/.ssh/authorized_keys"
else
    rm -f "/home/$workshop_user/.ssh/authorized_keys"
    printf 'WARNING: no instructor SSH public key was installed; SSH login will remain unavailable.\n' >&2
fi

# Disable vendor defaults after the dedicated account is known to work.
for vendor_user in radxa rock; do
    if id "$vendor_user" >/dev/null 2>&1; then
        usermod --lock --shell /usr/sbin/nologin "$vendor_user" || true
    fi
done

install -d -m 0755 /etc/cdmx /etc/cdmx-local-ai /usr/local/lib/cdmx
getent group cdmx-workspace >/dev/null || groupadd --system cdmx-workspace
usermod -aG cdmx-workspace "$workshop_user"
install -d -m 0750 -o "$workshop_user" -g "$workshop_user" \
    "/home/$workshop_user/.pi" "/home/$workshop_user/.picoclaw"
install -d -m 2770 -o "$workshop_user" -g cdmx-workspace /var/lib/cdmx-picoclaw/workspace
cat > /etc/cdmx/workshop.conf <<EOF
TEAM=$team
HOSTNAME=$device_hostname
AP_SSID=${device_hostname}-setup
WIFI_COUNTRY=MX
WORKSHOP_USER=$workshop_user
OPEN_ACCESS=1
NETWORK_INDEX=$network_index
EOF
chmod 0644 /etc/cdmx/workshop.conf
rm -f /etc/cdmx/ap-password
install -d -m 0755 /etc/NetworkManager/dnsmasq-shared.d
cat > /etc/NetworkManager/dnsmasq-shared.d/10-cdmx-captive.conf <<EOF
address=/#/10.42.$network_index.1
dhcp-option-force=114,http://10.42.$network_index.1:8080/captive-api
EOF
chmod 0644 /etc/NetworkManager/dnsmasq-shared.d/10-cdmx-captive.conf

if ! $offline_image; then
    hostnamectl set-hostname "$device_hostname"
fi
printf '%s\n' "$device_hostname" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1 localhost
127.0.1.1 $device_hostname
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# Install a clean source snapshot. Generated images, git metadata, and secrets
# are deliberately not copied onto the device runtime tree.
install -d -m 0755 /opt/cdmx-local-ai
if [[ $(readlink -f "$repo_root") != /opt/cdmx-local-ai ]]; then
    tar -C "$repo_root" --exclude=.git --exclude=artifacts --exclude='*.img' --exclude='*.img.xz' -cf - . |
        tar -C /opt/cdmx-local-ai -xf -
fi
chown -R root:root /opt/cdmx-local-ai
find /opt/cdmx-local-ai/device /opt/cdmx-local-ai/host -type f -name '*.sh' -exec chmod 0755 {} +
chmod 0755 /opt/cdmx-local-ai/device/network/cdmx-network \
    /opt/cdmx-local-ai/device/network/network_portal.py

install -m 0755 /opt/cdmx-local-ai/device/network/cdmx-network /usr/local/sbin/cdmx-network
install -m 0755 /opt/cdmx-local-ai/device/network/network_portal.py /usr/local/lib/cdmx/network_portal.py
install -d -m 0755 /usr/local/share/cdmx
install -m 0644 /opt/cdmx-local-ai/device/network/matter-lab-logo.svg /usr/local/share/cdmx/matter-lab-logo.svg
install -m 0755 /opt/cdmx-local-ai/device/network/usb_rescue.sh /usr/local/lib/cdmx/usb_rescue.sh
install -m 0755 /opt/cdmx-local-ai/device/personalize.sh /usr/local/sbin/cdmx-personalize
install -m 0755 /opt/cdmx-local-ai/device/configure-firewall.sh /usr/local/sbin/cdmx-configure-firewall
install -m 0755 /opt/cdmx-local-ai/device/first-boot.sh /usr/local/sbin/cdmx-first-boot

for unit in /opt/cdmx-local-ai/device/systemd/*.service /opt/cdmx-local-ai/device/systemd/*.timer; do
    [[ -e $unit ]] || continue
    install -m 0644 "$unit" "/etc/systemd/system/$(basename "$unit")"
done

rm -f /etc/cdmx-local-ai/vnc.passwd

install -d -m 0755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/30-cdmx-workshop.conf <<EOF
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
AllowUsers $workshop_user
MaxAuthTries 4
X11Forwarding no
EOF

install -d -m 0755 /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/30-cdmx-sd-card.conf <<'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=32M
RateLimitIntervalSec=30s
RateLimitBurst=1000
EOF
cat > /etc/default/zramswap <<'EOF'
ALGO=lz4
PERCENT=50
PRIORITY=100
EOF
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
cat > /etc/apt/apt.conf.d/52cdmx-unattended <<'EOF'
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF

if $offline_image; then
    touch /etc/cdmx/needs-runtime-init
else
    /usr/local/sbin/cdmx-configure-firewall
fi

if $install_agents && [[ -x /opt/cdmx-local-ai/device/agent/install-agent.sh ]]; then
    if $offline_image; then
        CDMX_OFFLINE_IMAGE=1 /opt/cdmx-local-ai/device/agent/install-agent.sh
    else
        /opt/cdmx-local-ai/device/agent/install-agent.sh
    fi
fi

if $enable_usb_ncm; then
    systemctl enable 'radxa-ncm@*.*.service' 2>/dev/null ||
        printf 'radxa-ncm service was not found; use rsetup to enable OTG peripheral mode and NCM.\n' >&2
fi

if ! $offline_image; then
    systemctl daemon-reload
fi
systemctl enable ssh avahi-daemon NetworkManager zramswap \
    cdmx-personalize.service cdmx-first-boot.service cdmx-network.service cdmx-network-portal.service \
    cdmx-usb-rescue.service cdmx-demo.service cdmx-desktop.service cdmx-novnc.service
if [[ -f /etc/systemd/system/cdmx-picoclaw.service ]]; then
    systemctl enable cdmx-picoclaw.service
fi

chown -R "$workshop_user:$workshop_user" "/home/$workshop_user/.pi" "/home/$workshop_user/.picoclaw"
if ! $offline_image; then
    systemctl restart ssh avahi-daemon
fi

printf '\nInstalled %s. Reboot, join %s-setup, then open http://10.42.%s.1:8080/.\n' "$device_hostname" "$device_hostname" "$network_index"
printf 'The setup Wi-Fi and noVNC have no password; SSH is public-key only.\n'
