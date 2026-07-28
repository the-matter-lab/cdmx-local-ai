#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# shellcheck source=../../host/lib/imager.sh
source "$ROOT/host/lib/imager.sh"

failures=0
assert_eq() {
  local expected=$1 actual=$2 label=$3
  if [[ "$expected" != "$actual" ]]; then
    printf 'not ok - %s (expected %q, got %q)\n' "$label" "$expected" "$actual"
    failures=$((failures + 1))
  else
    printf 'ok - %s\n' "$label"
  fi
}

assert_fails() {
  local label=$1
  shift
  if ("$@") >/dev/null 2>&1; then
    printf 'not ok - %s (unexpected success)\n' "$label"
    failures=$((failures + 1))
  else
    printf 'ok - %s\n' "$label"
  fi
}

assert_eq 1 "$(validate_team 1; printf 1)" 'team 1 is valid'
assert_eq 10 "$(validate_team 10; printf 10)" 'team 10 is valid'
assert_fails 'team 0 is rejected' validate_team 0
assert_fails 'team 11 is rejected' validate_team 11
assert_fails 'non-numeric team is rejected' validate_team one

tmp=$(mktemp -d "${TMPDIR:-/tmp}/cdmx-test.XXXXXX")
write_team_config "$tmp" 7
assert_eq CDMX_TEAM=7 "$(grep '^CDMX_TEAM=' "$tmp/cdmx-team.env")" 'team marker contains number'
assert_eq CDMX_HOSTNAME=equipo7 "$(grep '^CDMX_HOSTNAME=' "$tmp/cdmx-team.env")" 'team marker contains hostname'
if grep -Eqi '(password|psk|ssid|api[_-]?key)=' "$tmp/cdmx-team.env" "$tmp/before.txt"; then
  printf 'not ok - generated config appears to contain a credential\n'
  failures=$((failures + 1))
else
  printf 'ok - generated config contains no credential assignment\n'
fi

assert_eq 6f9f67df6f997bef41aac2cc568ebb4b7820216be1256a49ce472cb877684c08ad793ff726da3155a02f0eab60b2b2c9318168b3cf8fab81849ae91e8724f10d "$(bash -c 'source "$1"; printf %s "$IMAGE_SHA512"' _ "$ROOT/image/radxa-zero3-bookworm-kde-rsdk-b1.env")" 'stock image pin is unchanged'

if (( failures > 0 )); then
  printf '%s test(s) failed\n' "$failures" >&2
  exit 1
fi
printf 'all host imager tests passed\n'
