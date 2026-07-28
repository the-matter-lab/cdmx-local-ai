#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/imager.sh
source "$ROOT/host/lib/imager.sh"

source_disk=''
output="$ROOT/image/cdmx-workshop-golden.img.xz"
confirmation=''
while (($#)); do
  case "$1" in
    --source) source_disk=${2:-}; shift 2 ;;
    --output) output=${2:-}; shift 2 ;;
    --confirm) confirmation=${2:-}; shift 2 ;;
    -h|--help)
      printf 'Usage: %s --source /dev/DISK [--output FILE.img.xz] [--confirm "CAPTURE /dev/DISK WITHOUT SECRETS"]\n' "$0"
      exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

source_disk=$(canonical_disk "$source_disk")
assert_safe_disk "$source_disk"
[[ "$output" == *.xz ]] || die "Golden image output must end in .xz"
[[ ! -e "$output" && ! -e "${output}.partial" ]] || die "Output already exists: $output (or its .partial file)"
need_command xz
disk_description "$source_disk" >&2
printf '\nWARNING: a golden image contains every byte on the source card. Remove API keys, Wi-Fi passwords, shell history, and personal credentials first.\n' >&2
confirm_destructive_action "CAPTURE $source_disk WITHOUT SECRETS" "$confirmation"
mkdir -p "$(dirname "$output")"
unmount_disk "$source_disk"
raw=$(raw_disk "$source_disk")
bytes=$(disk_size_bytes "$source_disk")
note "Capturing $bytes bytes; this can take a long time"
sudo dd if="$raw" bs="$(dd_block_size)" | xz -T0 -6 >"${output}.partial"
mv "${output}.partial" "$output"
hash=$(sha512_file "$output")
printf '%s  %s\n' "$hash" "$(basename "$output")" >"${output}.sha512"
printf '%s\n' "$bytes" >"${output}.bytes"
eject_disk "$source_disk"
note "Golden image captured: $output"
note "SHA-512: $hash"
