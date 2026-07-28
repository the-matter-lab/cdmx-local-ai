#!/usr/bin/env bash

# Shared, source-only helpers for the destructive host-side imaging scripts.
# Supports macOS and Linux. Callers must enable: set -Eeuo pipefail.

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '==> %s\n' "$*" >&2
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

host_os() {
  case "$(uname -s)" in
    Darwin) printf 'macos\n' ;;
    Linux) printf 'linux\n' ;;
    *) die "Only macOS and Linux hosts are supported" ;;
  esac
}

validate_team() {
  local team=${1:-}
  [[ "$team" =~ ^([1-9]|10)$ ]] || die "Team must be an integer from 1 through 10"
}

canonical_disk() {
  local disk=${1:-}
  [[ -n "$disk" ]] || die "A whole-disk device is required"
  case "$(host_os)" in
    macos)
      disk=${disk/\/dev\/rdisk/\/dev\/disk}
      [[ "$disk" =~ ^/dev/disk[0-9]+$ ]] || die "Use a whole macOS disk such as /dev/disk4 (not a partition)"
      ;;
    linux)
      [[ "$disk" =~ ^/dev/(sd[a-z]+|mmcblk[0-9]+)$ ]] || die "Use a whole Linux disk such as /dev/sdb or /dev/mmcblk0"
      ;;
  esac
  printf '%s\n' "$disk"
}

raw_disk() {
  local disk
  disk=$(canonical_disk "$1")
  if [[ $(host_os) == macos ]]; then
    printf '%s\n' "${disk/\/dev\/disk/\/dev\/rdisk}"
  else
    printf '%s\n' "$disk"
  fi
}

dd_block_size() {
  if [[ $(host_os) == macos ]]; then
    printf '4m\n'
  else
    printf '4M\n'
  fi
}

disk_size_bytes() {
  local disk
  disk=$(canonical_disk "$1")
  if [[ $(host_os) == macos ]]; then
    diskutil info "$disk" | awk -F '[()]' '/Disk Size:/ {value=$2; sub(/ Bytes.*/, "", value); gsub(/[^0-9]/, "", value); print value; exit}'
  else
    sudo blockdev --getsize64 "$disk"
  fi
}

assert_safe_disk() {
  local disk info base root_source root_chain
  disk=$(canonical_disk "$1")

  if [[ $(host_os) == macos ]]; then
    need_command diskutil
    [[ "$disk" != /dev/disk0 ]] || die "Refusing to erase macOS system disk /dev/disk0"
    info=$(diskutil info "$disk") || die "Disk does not exist: $disk"
    grep -q 'Whole:[[:space:]]*Yes' <<<"$info" || die "Target is not a whole disk: $disk"
    if grep -Eq '(Internal:[[:space:]]*Yes|Device Location:[[:space:]]*Internal)' <<<"$info"; then
      die "Refusing to erase an internal disk: $disk"
    fi
    if ! grep -Eq '(Device Location:[[:space:]]*External|Removable Media:[[:space:]]*(Yes|Removable)|Protocol:[[:space:]]*USB)' <<<"$info"; then
      die "Target is neither removable nor attached over USB: $disk"
    fi
  else
    need_command lsblk
    [[ -b "$disk" ]] || die "Block device does not exist: $disk"
    [[ $(lsblk -dnro TYPE "$disk") == disk ]] || die "Target is not a whole disk: $disk"
    base=${disk#/dev/}
    root_source=$(findmnt -nro SOURCE / 2>/dev/null || true)
    root_chain=$(lsblk -sno NAME "$root_source" 2>/dev/null || true)
    if grep -qx "$base" <<<"$root_chain"; then
      die "Refusing to erase the disk backing the running root filesystem: $disk"
    fi
    if [[ $(lsblk -dnro RM "$disk") != 1 && $(lsblk -dnro TRAN "$disk") != usb ]]; then
      die "Target is neither removable nor attached over USB: $disk"
    fi
  fi

  local bytes
  bytes=$(disk_size_bytes "$disk")
  [[ "$bytes" =~ ^[0-9]+$ && "$bytes" -ge 4000000000 ]] || die "Disk is unexpectedly small or its size could not be read: $disk"
}

disk_description() {
  local disk
  disk=$(canonical_disk "$1")
  if [[ $(host_os) == macos ]]; then
    diskutil info "$disk" | awk -F: '/Device \/ Media Name:|Disk Size:|Protocol:|Internal:|Device Location:|Removable Media:/ {gsub(/^[ \t]+/, "", $2); printf "  %-18s %s\n", $1 ":", $2}'
  else
    lsblk -dn -o NAME,SIZE,MODEL,TRAN,RM "$disk"
  fi
}

confirm_destructive_action() {
  local expected=$1 supplied=${2:-} answer
  if [[ -n "$supplied" ]]; then
    [[ "$supplied" == "$expected" ]] || die "Confirmation mismatch. Required exactly: $expected"
    return
  fi
  [[ -r /dev/tty ]] || die "No interactive terminal. Pass --confirm '$expected'"
  printf '\nDESTRUCTIVE OPERATION. Type exactly:\n  %s\n> ' "$expected" >/dev/tty
  IFS= read -r answer </dev/tty
  [[ "$answer" == "$expected" ]] || die "Confirmation did not match; nothing was written"
}

sha512_file() {
  local file=$1
  if command -v sha512sum >/dev/null 2>&1; then
    sha512sum "$file" | awk '{print $1}'
  else
    shasum -a 512 "$file" | awk '{print $1}'
  fi
}

sha512_stream() {
  if command -v sha512sum >/dev/null 2>&1; then
    sha512sum | awk '{print $1}'
  else
    shasum -a 512 | awk '{print $1}'
  fi
}

verify_compressed_image() {
  local image=$1 expected=${2:-} sidecar actual
  [[ -f "$image" ]] || die "Image not found: $image"
  if [[ -z "$expected" ]]; then
    sidecar="${image}.sha512"
    [[ -f "$sidecar" ]] || die "Missing checksum sidecar: $sidecar"
    read -r expected _ <"$sidecar"
  fi
  [[ "$expected" =~ ^[[:xdigit:]]{128}$ ]] || die "Invalid SHA-512 value"
  note "Checking compressed image SHA-512"
  actual=$(sha512_file "$image")
  [[ "$actual" == "$expected" ]] || die "Image checksum mismatch (expected $expected, got $actual)"
}

image_uncompressed_bytes() {
  local image=$1
  if [[ "$image" == *.xz ]]; then
    need_command xz
    xz --robot --list "$image" | awk -F '\t' '$1 == "totals" {print $5; found=1} END {if (!found) exit 1}'
  else
    if [[ $(host_os) == macos ]]; then
      stat -f '%z' "$image"
    else
      stat -c '%s' "$image"
    fi
  fi
}

unmount_disk() {
  local disk part mountpoint
  disk=$(canonical_disk "$1")
  if [[ $(host_os) == macos ]]; then
    diskutil unmountDisk "$disk" >/dev/null || die "Could not unmount $disk"
  else
    while read -r part mountpoint; do
      [[ -n "${mountpoint:-}" ]] && sudo umount "$part"
    done < <(lsblk -lnpo NAME,MOUNTPOINT "$disk" | tail -n +2)
  fi
}

eject_disk() {
  local disk
  disk=$(canonical_disk "$1")
  sync
  if [[ $(host_os) == macos ]]; then
    diskutil eject "$disk" >/dev/null || die "Could not eject $disk"
  else
    unmount_disk "$disk"
    if command -v udisksctl >/dev/null 2>&1; then
      sudo udisksctl power-off -b "$disk" >/dev/null 2>&1 || true
    fi
  fi
  note "Safe to remove $disk"
}

refresh_partitions() {
  local disk=$1
  sync
  if [[ $(host_os) == macos ]]; then
    diskutil list "$disk" >/dev/null
  else
    sudo partprobe "$disk" 2>/dev/null || true
    command -v udevadm >/dev/null 2>&1 && sudo udevadm settle || true
  fi
}

write_image() {
  local image=$1 disk raw bytes disk_bytes
  disk=$(canonical_disk "$2")
  raw=$(raw_disk "$disk")
  bytes=$(image_uncompressed_bytes "$image")
  disk_bytes=$(disk_size_bytes "$disk")
  [[ "$bytes" =~ ^[0-9]+$ && "$bytes" -gt 0 ]] || die "Could not determine uncompressed image size"
  (( disk_bytes >= bytes )) || die "Image ($bytes bytes) is larger than target ($disk_bytes bytes)"

  unmount_disk "$disk"
  note "Writing $image to $disk ($bytes uncompressed bytes)"
  if [[ "$image" == *.xz ]]; then
    xz -dc -- "$image" | sudo dd of="$raw" bs="$(dd_block_size)"
  else
    sudo dd if="$image" of="$raw" bs="$(dd_block_size)"
  fi
  sync
  refresh_partitions "$disk"
}

verify_written_image() {
  local image=$1 disk raw bytes expected actual
  disk=$(canonical_disk "$2")
  raw=$(raw_disk "$disk")
  bytes=$(image_uncompressed_bytes "$image")

  note "Hashing the uncompressed image for write verification"
  if [[ "$image" == *.xz ]]; then
    expected=$(xz -dc -- "$image" | sha512_stream)
  else
    expected=$(sha512_file "$image")
  fi
  note "Reading back and hashing the first $bytes bytes of $disk"
  actual=$(sudo head -c "$bytes" "$raw" | sha512_stream)
  [[ "$actual" == "$expected" ]] || die "Read-back verification failed (expected $expected, got $actual)"
  note "Read-back verification passed"
}

find_config_partition() {
  local disk part
  disk=$(canonical_disk "$1")
  if [[ $(host_os) == macos ]]; then
    part=$(diskutil list "$disk" | awk 'tolower($0) ~ /config/ {print $NF; exit}')
    [[ -n "$part" ]] || return 1
    [[ "$part" == /dev/* ]] || part="/dev/$part"
  else
    part=$(lsblk -lnpo NAME,FSTYPE,LABEL "$disk" | awk 'tolower($2) ~ /^(vfat|fat|msdos)/ && tolower($3) == "config" {print $1; exit}')
    [[ -n "$part" ]] || return 1
  fi
  printf '%s\n' "$part"
}

# Sets CONFIG_MOUNT and CONFIG_MOUNT_OWNED for cleanup_config_mount.
mount_config_partition() {
  local disk=$1 part current
  part=$(find_config_partition "$disk") || die "Could not find the FAT partition labelled 'config' on $disk"
  if [[ $(host_os) == macos ]]; then
    current=$(diskutil info "$part" | awk -F: '/Mount Point:/ {sub(/^[ \t]+/, "", $2); print $2; exit}')
    if [[ -n "$current" && "$current" != 'Not mounted' ]]; then
      CONFIG_MOUNT=$current
      CONFIG_MOUNT_OWNED=macos
    else
      diskutil mount "$part" >/dev/null || die "Could not mount $part"
      CONFIG_MOUNT=$(diskutil info "$part" | awk -F: '/Mount Point:/ {sub(/^[ \t]+/, "", $2); print $2; exit}')
      CONFIG_MOUNT_OWNED=macos
    fi
    [[ -d "$CONFIG_MOUNT" ]] || die "Could not determine mount point for $part"
  else
    current=$(lsblk -nro MOUNTPOINT "$part" | head -n1)
    if [[ -n "$current" ]]; then
      CONFIG_MOUNT=$current
      CONFIG_MOUNT_OWNED=linux-existing
    else
      CONFIG_MOUNT=$(mktemp -d "${TMPDIR:-/tmp}/cdmx-config.XXXXXX")
      sudo mount -o rw "$part" "$CONFIG_MOUNT"
      CONFIG_MOUNT_OWNED=linux
    fi
  fi
}

cleanup_config_mount() {
  local disk=${1:-}
  case "${CONFIG_MOUNT_OWNED:-}" in
    macos) diskutil unmount "${CONFIG_MOUNT:?}" >/dev/null || true ;;
    linux) sudo umount "${CONFIG_MOUNT:?}" || true; rmdir "$CONFIG_MOUNT" 2>/dev/null || true ;;
    linux-existing) sudo umount "${CONFIG_MOUNT:?}" || true ;;
  esac
  CONFIG_MOUNT=
  CONFIG_MOUNT_OWNED=
  [[ -n "$disk" ]] && sync
}

write_team_config() {
  local destination=$1 team=$2 hostname source_root staging
  validate_team "$team"
  hostname="equipo${team}"
  source_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
  staging=$(mktemp -d "${TMPDIR:-/tmp}/cdmx-team.XXXXXX")
  cp "$source_root/image/before.txt" "$staging/before.txt"
  {
    printf '# Generated by cdmx-local-ai; safe to commit (contains no secrets).\n'
    printf 'CDMX_TEAM=%s\n' "$team"
    printf 'CDMX_HOSTNAME=%s\n' "$hostname"
  } >"$staging/cdmx-team.env"
  if [[ -w "$destination" ]]; then
    cp "$staging/before.txt" "$destination/before.txt"
    cp "$staging/cdmx-team.env" "$destination/cdmx-team.env"
  else
    sudo cp "$staging/before.txt" "$destination/before.txt"
    sudo cp "$staging/cdmx-team.env" "$destination/cdmx-team.env"
  fi
  sync
  rm "$staging/before.txt" "$staging/cdmx-team.env"
  rmdir "$staging"
  note "Provisioned $hostname marker and credential-free before.txt"
}
