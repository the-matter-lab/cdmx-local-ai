#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
# shellcheck source=host/lib/imager.sh
source "$REPO_ROOT/host/lib/imager.sh"

IMAGE=${1:-$REPO_ROOT/image/cdmx-workshop-golden.img.xz}
PARTS_DIR=$REPO_ROOT/image/docker-parts
MAX_PARTS=20

need_command split
verify_compressed_image "$IMAGE"
mkdir -p "$PARTS_DIR"
find "$PARTS_DIR" -type f -name 'part-*' -delete
split -b 100m -d -a 3 "$IMAGE" "$PARTS_DIR/part-"

part_count=$(find "$PARTS_DIR" -type f -name 'part-*' | wc -l | tr -d ' ')
(( part_count <= MAX_PARTS )) || die "Image needs $part_count Docker layers; increase MAX_PARTS and Dockerfile entries"

index=0
while (( index < MAX_PARTS )); do
  part=$(printf '%s/part-%03d' "$PARTS_DIR" "$index")
  [[ -e "$part" ]] || touch "$part"
  index=$((index + 1))
done

note "Prepared $MAX_PARTS resilient Docker layers in $PARTS_DIR"
