#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=host/lib/imager.sh
source "$ROOT/host/lib/imager.sh"

disk=''
team=''
config_dir=''
while (($#)); do
  case "$1" in
    --disk) disk=${2:-}; shift 2 ;;
    --team) team=${2:-}; shift 2 ;;
    --config-dir) config_dir=${2:-}; shift 2 ;;
    -h|--help)
      printf 'Usage: %s --team 0..9|admin (--disk /dev/DISK | --config-dir PATH)\n' "$0"
      exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done
validate_team "$team"

if [[ -n "$config_dir" ]]; then
  [[ -z "$disk" ]] || die "Use only one of --disk or --config-dir"
  [[ -d "$config_dir" ]] || die "Config directory does not exist: $config_dir"
  write_team_config "$config_dir" "$team"
else
  disk=$(canonical_disk "$disk")
  assert_safe_disk "$disk"
  CONFIG_MOUNT=''
  CONFIG_MOUNT_OWNED=''
  export CONFIG_MOUNT CONFIG_MOUNT_OWNED
  trap 'cleanup_config_mount "$disk"' EXIT
  refresh_partitions "$disk"
  mount_config_partition "$disk"
  write_team_config "$CONFIG_MOUNT" "$team"
fi
