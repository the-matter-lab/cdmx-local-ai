#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/imager.sh
source "$ROOT/host/lib/imager.sh"
# shellcheck source=../../image/radxa-zero3-bookworm-kde-rsdk-b1.env
source "$ROOT/image/radxa-zero3-bookworm-kde-rsdk-b1.env"

disk=''
image=''
confirmation=''
while (($#)); do
  case "$1" in
    --disk) disk=${2:-}; shift 2 ;;
    --image) image=${2:-}; shift 2 ;;
    --confirm) confirmation=${2:-}; shift 2 ;;
    -h|--help)
      printf 'Usage: %s --disk /dev/DISK [--image FILE] [--confirm "ERASE /dev/DISK FOR GOLDEN-MASTER"]\n' "$0"
      exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

disk=$(canonical_disk "$disk")
assert_safe_disk "$disk"
image=${image:-"$ROOT/image/cache/$IMAGE_FILENAME"}
[[ -f "$image" ]] || image=$("$ROOT/host/download-stock-image.sh" "$image")
verify_compressed_image "$image" "$IMAGE_SHA512"
disk_description "$disk" >&2
confirm_destructive_action "ERASE $disk FOR GOLDEN-MASTER" "$confirmation"
write_image "$image" "$disk"
verify_written_image "$image" "$disk"
eject_disk "$disk"
note "Stock master card is ready. Boot it, run the on-device installer, shut it down, then capture it with host/capture-golden.sh."
