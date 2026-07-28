#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/imager.sh
source "$ROOT/host/lib/imager.sh"

disk=''
team=''
image="$ROOT/image/cdmx-workshop-golden.img.xz"
confirmation=''
while (($#)); do
  case "$1" in
    --disk) disk=${2:-}; shift 2 ;;
    --team) team=${2:-}; shift 2 ;;
    --image) image=${2:-}; shift 2 ;;
    --confirm) confirmation=${2:-}; shift 2 ;;
    -h|--help)
      printf 'Usage: %s --team 1..10 --disk /dev/DISK [--image GOLDEN.img.xz] [--confirm "ERASE /dev/DISK FOR equipoN"]\n' "$0"
      exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

validate_team "$team"
disk=$(canonical_disk "$disk")
assert_safe_disk "$disk"
verify_compressed_image "$image"
if [[ -f "${image}.bytes" ]]; then
  read -r captured_bytes <"${image}.bytes"
  actual_bytes=$(image_uncompressed_bytes "$image")
  [[ "$actual_bytes" == "$captured_bytes" ]] || die "Golden image size metadata does not match the image"
fi
disk_description "$disk" >&2
confirm_destructive_action "ERASE $disk FOR equipo${team}" "$confirmation"
write_image "$image" "$disk"
verify_written_image "$image" "$disk"
"$ROOT/host/provision-team.sh" --disk "$disk" --team "$team"
eject_disk "$disk"
note "equipo${team} is verified and safe to remove"
