#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
team=""
skip_upgrade=false
install_agents=true
enable_usb_ncm=false
workshop_user=cdmx

usage() {
    cat <<'EOF'
Usage: sudo ./device/install.sh --team N [options]

Install the workshop stack on a booted Radxa ZERO 3W running the pinned RadxaOS.
The script prompts without echo for the shared local workshop password. For
automation, pass it through the CDMX_WORKSHOP_PASSWORD environment variable.

Options:
  --team N              Initial team number (1-10)
  --skip-upgrade        Skip apt full-upgrade (package lists are still refreshed)
  --skip-agents         Do not download PicoClaw/Pi now
  --enable-usb-ncm      Enable radxa-ncm if the OTG overlay was already selected
  -h, --help            Show this help
EOF
}

while (($#)); do
    case "$1" in
        --team) team=${2:-}; shift 2 ;;
        --skip-upgrade) skip_upgrade=true; shift ;;
        --skip-agents) install_agents=false; shift ;;
        --enable-usb-ncm) enable_usb_ncm=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 64 ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    printf 'Run this installer with sudo.\n' >&2
    exit 77
fi
case "$team" in 1|2|3|4|5|6|7|8|9|10) ;; *) printf '%s\n' '--team must be 1-10' >&2; exit 64 ;; esac

if [[ $(dpkg --print-architecture) != arm64 ]]; then
    printf 'This installer targets RadxaOS arm64; detected %s.\n' "$(dpkg --print-architecture)" >&2
    exit 69
fi

password=${CDMX_WORKSHOP_PASSWORD:-}
if [[ -z $password ]]; then
    [[ -t 0 ]] || { printf 'Set CDMX_WORKSHOP_PASSWORD for non-interactive installation.\n' >&2; exit 64; }
    read -r -s -p 'Local workshop password (Linux/Samba/AP/noVNC, 12+ characters): ' password
    printf '\n'
    read -r -s -p 'Repeat password: ' password_check
    printf '\n'
    [[ $password == "$password_check" ]] || { printf 'Passwords do not match.\n' >&2; exit 65; }
fi
if ((${#password} < 12 || ${#password} > 63)) || [[ $password == *$'\n'* || $password == *$'\r'* ]]; then
    printf 'Password must contain 12-63 characters without line breaks.\n' >&2
    exit 65
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
if ! $skip_upgrade; then
    apt-get -y full-upgrade
fi
apt-get install -y --no-install-recommends \
    avahi-daemon bash ca-certificates curl feh git jq locales \
    network-manager novnc openbox openssh-server python3 python3-matplotlib \
    python3-numpy rfkill samba samba-vfs-modules smbclient sudo tigervnc-standalone-server \
    tmux ufw unattended-upgrades websockify x11-xserver-utils xauth xterm \
    zram-tools

if ! id "$workshop_user" >/dev/null 2>&1; then
    adduser --disabled-password --gecos 'CDMX workshop team' "$workshop_user"
fi
usermod -aG audio,video,render,plugdev,systemd-journal "$workshop_user"
printf '%s:%s\n' "$workshop_user" "$password" | chpasswd

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
HOSTNAME=equipo$team
AP_SSID=equipo${team}-setup
WIFI_COUNTRY=MX
WORKSHOP_USER=$workshop_user
EOF
chmod 0644 /etc/cdmx/workshop.conf
printf '%s\n' "$password" > /etc/cdmx/ap-password
chmod 0600 /etc/cdmx/ap-password

hostnamectl set-hostname "equipo$team"
cat > /etc/hosts <<EOF
127.0.0.1 localhost
127.0.1.1 equipo$team
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
install -m 0755 /opt/cdmx-local-ai/device/network/usb_rescue.sh /usr/local/lib/cdmx/usb_rescue.sh
install -m 0755 /opt/cdmx-local-ai/device/personalize.sh /usr/local/sbin/cdmx-personalize
install -m 0755 /opt/cdmx-local-ai/device/prepare-master.sh /usr/local/sbin/cdmx-prepare-master

for unit in /opt/cdmx-local-ai/device/systemd/*.service /opt/cdmx-local-ai/device/systemd/*.timer; do
    [[ -e $unit ]] || continue
    install -m 0644 "$unit" "/etc/systemd/system/$(basename "$unit")"
done

printf '%s\n' "$password" | tigervncpasswd -f > /etc/cdmx-local-ai/vnc.passwd
chown root:"$workshop_user" /etc/cdmx-local-ai/vnc.passwd
chmod 0640 /etc/cdmx-local-ai/vnc.passwd

install -d -m 0755 /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/30-cdmx-workshop.conf <<EOF
PermitRootLogin no
PasswordAuthentication yes
KbdInteractiveAuthentication no
PermitEmptyPasswords no
AllowUsers $workshop_user
MaxAuthTries 4
X11Forwarding no
EOF

cat > /etc/samba/cdmx-workshop.conf <<EOF
[workspace]
    comment = Equipo $team workspace
    path = /var/lib/cdmx-picoclaw/workspace
    browseable = yes
    read only = no
    guest ok = no
    valid users = $workshop_user
    force user = $workshop_user
    force group = $workshop_user
    create mask = 0660
    directory mask = 0770
    ea support = yes
    vfs objects = catia fruit streams_xattr
    fruit:metadata = stream
    fruit:model = MacSamba
EOF
if ! grep -Fq 'include = /etc/samba/cdmx-workshop.conf' /etc/samba/smb.conf; then
    printf '\ninclude = /etc/samba/cdmx-workshop.conf\n' >> /etc/samba/smb.conf
fi
printf '%s\n%s\n' "$password" "$password" | smbpasswd -s -a "$workshop_user"

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

ufw --force reset
ufw default deny incoming
ufw default allow outgoing
for subnet in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
    ufw allow from "$subnet" to any port 22 proto tcp
    ufw allow from "$subnet" to any port 6080 proto tcp
    ufw allow from "$subnet" to any port 445 proto tcp
    ufw allow from "$subnet" to any port 139 proto tcp
    ufw allow from "$subnet" to any port 5353 proto udp
done
for subnet in 10.42.0.0/16 10.55.0.0/16; do
    ufw allow from "$subnet" to any port 8080 proto tcp
    ufw allow from "$subnet" to any port 53 proto tcp
    ufw allow from "$subnet" to any port 53 proto udp
    ufw allow from "$subnet" to any port 67 proto udp
    ufw allow from "$subnet" to any port 68 proto udp
done
ufw --force enable

if $install_agents && [[ -x /opt/cdmx-local-ai/device/agent/install-agent.sh ]]; then
    /opt/cdmx-local-ai/device/agent/install-agent.sh
fi

if $enable_usb_ncm; then
    systemctl enable 'radxa-ncm@*.*.service' 2>/dev/null ||
        printf 'radxa-ncm service was not found; use rsetup to enable OTG peripheral mode and NCM.\n' >&2
fi

systemctl daemon-reload
systemctl enable ssh avahi-daemon smbd NetworkManager zramswap \
    cdmx-personalize.service cdmx-network.service cdmx-network-portal.service \
    cdmx-usb-rescue.service cdmx-demo.service cdmx-desktop.service cdmx-novnc.service
if [[ -f /etc/systemd/system/cdmx-picoclaw.service ]]; then
    systemctl enable cdmx-picoclaw.service
fi

chown -R "$workshop_user:$workshop_user" "/home/$workshop_user/.pi" "/home/$workshop_user/.picoclaw"
systemctl restart ssh avahi-daemon smbd

unset password password_check CDMX_WORKSHOP_PASSWORD
printf '\nInstalled equipo%s. Reboot, join equipo%s-setup, then open http://10.42.%s.1:8080/.\n' "$team" "$team" "$team"
printf 'After testing, run sudo cdmx-prepare-master before capturing the golden SD image.\n'
