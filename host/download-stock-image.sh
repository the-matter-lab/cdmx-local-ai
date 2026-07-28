#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/imager.sh
source "$ROOT/host/lib/imager.sh"
# shellcheck source=../../image/radxa-zero3-bookworm-kde-rsdk-b1.env
source "$ROOT/image/radxa-zero3-bookworm-kde-rsdk-b1.env"

destination=${1:-"$ROOT/image/cache/$IMAGE_FILENAME"}
mkdir -p "$(dirname "$destination")"
need_command curl

if [[ -f "$destination" ]]; then
  if [[ $(sha512_file "$destination") == "$IMAGE_SHA512" ]]; then
    note "Pinned stock image is already downloaded and valid: $destination"
    printf '%s\n' "$destination"
    exit 0
  fi
  die "Existing download has the wrong checksum; move it aside and run again: $destination"
fi

partial="${destination}.partial"
note "Downloading official Radxa $IMAGE_RELEASE image"
curl --fail --location --retry 5 --continue-at - --output "$partial" "$IMAGE_URL"
actual=$(sha512_file "$partial")
[[ "$actual" == "$IMAGE_SHA512" ]] || die "Downloaded image checksum mismatch"
mv "$partial" "$destination"
note "Verified SHA-512: $IMAGE_SHA512"
printf '%s\n' "$destination"
