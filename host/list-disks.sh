#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=lib/imager.sh
source "$ROOT/host/lib/imager.sh"

if [[ $(host_os) == macos ]]; then
  diskutil list external physical
else
  lsblk -d -o NAME,PATH,SIZE,MODEL,TRAN,RM,TYPE
fi
