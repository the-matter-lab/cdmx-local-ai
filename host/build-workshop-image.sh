#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=host/lib/imager.sh
source "$ROOT/host/lib/imager.sh"

key_file=""
while (($#)); do
    case "$1" in
        --authorized-key-file) key_file=${2:-}; shift 2 ;;
        -h|--help)
            printf 'Usage: %s [--authorized-key-file PATH]\n' "$0"
            exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

if [[ -z $key_file ]]; then
    for candidate in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_ecdsa.pub" "$HOME/.ssh/id_rsa.pub"; do
        if [[ -r $candidate ]]; then key_file=$candidate; break; fi
    done
fi
[[ -r $key_file ]] || die 'No instructor SSH public key found'
grep -Eq '^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521))[[:space:]]+' "$key_file" ||
    die 'Instructor key is not a supported SSH public key'

need_command docker
need_command git
need_command xz
docker info >/dev/null 2>&1 || die 'Docker Desktop is not running'

# shellcheck source=image/radxa-zero3-bookworm-kde-rsdk-b1.env
source "$ROOT/image/radxa-zero3-bookworm-kde-rsdk-b1.env"
stock_xz="$ROOT/image/cache/$IMAGE_FILENAME"
stock_raw="${stock_xz%.xz}"
output_raw=$(mktemp "$ROOT/image/cache/cdmx-workshop-golden.XXXXXX.img")
output_xz="$ROOT/image/cdmx-workshop-golden.img.xz"
output_partial="$output_xz.partial"
checksum_partial="$output_xz.sha512.partial"
source_archive="$ROOT/image/cache/cdmx-source.tar"
source_archive_partial="$source_archive.partial"
cleanup() {
    rm -f -- "$output_raw" "$output_partial" "$checksum_partial" "$source_archive" "$source_archive_partial"
}
trap cleanup EXIT

note 'Snapshotting the tracked source at the current commit'
git -C "$ROOT" archive --format=tar HEAD > "$source_archive_partial"
mv -f -- "$source_archive_partial" "$source_archive"
verify_compressed_image "$stock_xz" "$IMAGE_SHA512"

if [[ ! -f $stock_raw ]]; then
    note 'Expanding the official RadxaOS image'
    xz -dk -- "$stock_xz"
fi
note 'Creating a copy-on-write workshop image'
if [[ $(uname -s) == Darwin ]]; then
    cp -c -f "$stock_raw" "$output_raw"
else
    cp --reflink=auto -f "$stock_raw" "$output_raw"
fi

note 'Installing the workshop stack into the ARM64 image'
docker run --rm --privileged \
    -v "$ROOT:/source:ro" \
    -v "$ROOT/image/cache:/images" \
    -v "$source_archive:/source.tar:ro" \
    -v "$key_file:/instructor.pub:ro" \
    ubuntu:24.04 \
    /bin/bash /source/host/build-image-in-container.sh \
    "/images/$(basename "$output_raw")" /source.tar /instructor.pub

note 'Compressing and checking the workshop image'
xz -T0 -1 -c -- "$output_raw" > "$output_partial"
xz -t -- "$output_partial"
checksum=$(sha512_file "$output_partial")
printf '%s  %s\n' "$checksum" "$(basename "$output_xz")" > "$checksum_partial"
mv -f -- "$output_partial" "$output_xz"
mv -f -- "$checksum_partial" "$output_xz.sha512"
rm -f -- "$stock_raw" "$output_raw"
note "Workshop image ready: $output_xz"
