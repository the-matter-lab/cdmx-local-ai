#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=host/lib/imager.sh
source "$SCRIPT_DIR/lib/imager.sh"

IMAGE_REF=${CDMX_IMAGE_REF:-bestquark/cdmx-radxa-zero3w:latest}
DEST_DIR=${CDMX_IMAGE_DEST:-$REPO_ROOT/image}
CONTAINER_ID=
TEMP_DIR=

cleanup() {
  if [[ -n "$CONTAINER_ID" ]]; then
    docker rm -f "$CONTAINER_ID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    find "$TEMP_DIR" -type f -delete
    find "$TEMP_DIR" -depth -type d -empty -delete
  fi
}
trap cleanup EXIT

need_command docker
mkdir -p "$DEST_DIR"

note "Pulling $IMAGE_REF"
docker pull "$IMAGE_REF"
CONTAINER_ID=$(docker create "$IMAGE_REF" /unused)
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/cdmx-workshop-image.XXXXXX")
mkdir -p "$TEMP_DIR/parts"

docker cp "$CONTAINER_ID:/image/parts/." "$TEMP_DIR/parts/"
docker cp "$CONTAINER_ID:/image/cdmx-workshop-golden.img.xz.sha512" "$TEMP_DIR/"

for part in "$TEMP_DIR"/parts/part-*; do
  [[ -f "$part" ]] || die "Docker artifact contains no image parts"
  cat "$part"
done >"$TEMP_DIR/cdmx-workshop-golden.img.xz"

verify_compressed_image "$TEMP_DIR/cdmx-workshop-golden.img.xz"
mv "$TEMP_DIR/cdmx-workshop-golden.img.xz" "$DEST_DIR/"
mv "$TEMP_DIR/cdmx-workshop-golden.img.xz.sha512" "$DEST_DIR/"

note "Workshop image is ready at $DEST_DIR/cdmx-workshop-golden.img.xz"
