#!/usr/bin/env bash
set -Eeuo pipefail

image=${1:?image path required}
source_root=${2:-/source}
authorized_key=${3:-/instructor.pub}
mount_root=/mnt/cdmx-image
rootfs=$mount_root/rootfs

cleanup() {
    set +e
    for path in "$rootfs/run" "$rootfs/sys" "$rootfs/proc" "$rootfs/dev/pts" "$rootfs/dev"; do
        mountpoint -q "$path" && umount "$path"
    done
    mountpoint -q "$rootfs" && umount "$rootfs"
    rmdir "$rootfs" "$mount_root" 2>/dev/null || true
}
trap cleanup EXIT

export DEBIAN_FRONTEND=noninteractive
apt-get update >/dev/null
apt-get install -y --no-install-recommends gdisk e2fsprogs util-linux >/dev/null

# Keep the vendor image geometry byte-for-byte.  ZERO 3W boot firmware has
# proven sensitive to an offline GPT/root-partition expansion.  Radxa's first
# boot resize_root hook will safely claim the rest of each physical SD card.
root_first_sector=$(sgdisk --info=3 "$image" | awk '/First sector:/ {print $3}')
root_last_sector=$(sgdisk --info=3 "$image" | awk '/Last sector:/ {print $3}')
[[ $root_first_sector =~ ^[0-9]+$ && $root_last_sector =~ ^[0-9]+$ ]] || {
    printf 'Could not read the official root partition geometry.\n' >&2
    exit 65
}
root_offset=$(( root_first_sector * 512 ))
root_size=$(( (root_last_sector - root_first_sector + 1) * 512 ))
root_loop=$(losetup --find --show --offset "$root_offset" --sizelimit "$root_size" "$image")
e2fsck -fy "$root_loop" >/dev/null
losetup -d "$root_loop"

mkdir -p "$rootfs"
mount -o "loop,offset=$root_offset,sizelimit=$root_size" "$image" "$rootfs"

install -d -m 0755 "$rootfs/opt/cdmx-local-ai"
tar -C "$source_root" \
    --exclude=.git --exclude=artifacts --exclude=image/cache \
    --exclude='*.img' --exclude='*.img.xz' -cf - . |
    tar -C "$rootfs/opt/cdmx-local-ai" -xf -
install -m 0600 "$authorized_key" "$rootfs/tmp/cdmx-instructor.pub"

mount --bind /dev "$rootfs/dev"
mount --bind /dev/pts "$rootfs/dev/pts"
mount -t proc proc "$rootfs/proc"
mount -t sysfs sysfs "$rootfs/sys"
mount --bind /run "$rootfs/run"

if [[ -e $rootfs/etc/resolv.conf || -L $rootfs/etc/resolv.conf ]]; then
    cp -a "$rootfs/etc/resolv.conf" "$rootfs/etc/resolv.conf.cdmx-backup"
fi
cp /etc/resolv.conf "$rootfs/etc/resolv.conf"
if [[ -e $rootfs/usr/sbin/policy-rc.d ]]; then
    cp "$rootfs/usr/sbin/policy-rc.d" "$rootfs/usr/sbin/policy-rc.d.cdmx-backup"
fi
printf '#!/bin/sh\nexit 101\n' > "$rootfs/usr/sbin/policy-rc.d"
chmod 0755 "$rootfs/usr/sbin/policy-rc.d"

# The workshop desktop is a headless TigerVNC/Openbox session.  Remove the two
# large local browsers and KDE applications before installing it so the full
# offline stack fits inside the unmodified vendor root partition.
chroot "$rootfs" apt-get -y purge \
    task-desktop task-kde-desktop kde-standard kde-plasma-desktop sddm \
    firefox-esr chromium-x11 akregator dragonplayer gwenview kate kcalc \
    kde-spectacle kdeconnect khelpcenter kmail konqueror maliit-keyboard \
    okular plasma-discover samba samba-vfs-modules smbclient python3-samba \
    samba-common-bin samba-common samba-libs libsmbclient
chroot "$rootfs" apt-get clean

chroot "$rootfs" /usr/bin/env CDMX_OFFLINE_IMAGE=1 \
    /bin/bash /opt/cdmx-local-ai/device/install.sh \
    --team 0 --skip-upgrade --offline-image \
    --authorized-key-file /tmp/cdmx-instructor.pub

if [[ -e $rootfs/etc/resolv.conf.cdmx-backup || -L $rootfs/etc/resolv.conf.cdmx-backup ]]; then
    mv "$rootfs/etc/resolv.conf.cdmx-backup" "$rootfs/etc/resolv.conf"
else
    rm -f "$rootfs/etc/resolv.conf"
fi
if [[ -e $rootfs/usr/sbin/policy-rc.d.cdmx-backup ]]; then
    mv "$rootfs/usr/sbin/policy-rc.d.cdmx-backup" "$rootfs/usr/sbin/policy-rc.d"
else
    rm -f "$rootfs/usr/sbin/policy-rc.d"
fi
rm -f "$rootfs/tmp/cdmx-instructor.pub" "$rootfs"/etc/ssh/ssh_host_*
rm -f "$rootfs/home/cdmx/.bash_history" "$rootfs/root/.bash_history"
find "$rootfs/var/log" -type f -exec truncate -s 0 {} +
find "$rootfs/var/lib/apt/lists" -type f -delete
rm -f "$rootfs/var/lib/systemd/random-seed" "$rootfs/var/lib/dbus/machine-id"
: > "$rootfs/etc/machine-id"
install -d -m 0755 "$rootfs/etc/cdmx"
touch "$rootfs/etc/cdmx/needs-personalization" "$rootfs/etc/cdmx/needs-runtime-init"
sync
