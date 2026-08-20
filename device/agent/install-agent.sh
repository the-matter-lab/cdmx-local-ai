#!/usr/bin/env bash
# Install the workshop's pinned PicoClaw build and Pi coding agent on arm64.
set -Eeuo pipefail

PICOCLAW_VERSION="0.3.1"
PICOCLAW_DEB="picoclaw_aarch64.deb"
PICOCLAW_DEB_SHA256="bfb4b91240d725613a58caa89cf8061a1639419f7f7f10b75a3ad4304e699030"
PICOCLAW_CHECKSUMS="picoclaw_0.3.1_checksums.txt"
PICOCLAW_CHECKSUMS_SHA256="a60e0242f72508f5fbd8ab5976661d0d183c76d8f7863a383e60f3262e976acf"
PICOCLAW_RELEASE_URL="https://github.com/sipeed/picoclaw/releases/download/v${PICOCLAW_VERSION}"

# Pi currently requires Node >=22.19. Pin the official Node 22 arm64 archive so
# all ten boards get the same runtime. Update this deliberately with its digest.
NODE_VERSION="22.23.1"
NODE_ARCHIVE="node-v${NODE_VERSION}-linux-arm64.tar.xz"
NODE_ARCHIVE_SHA256="0294e8b915ab75f92c7513d2fcb830ae06e10684e6c603e99a87dbf8835389c1"
NODE_URL="https://nodejs.org/dist/v${NODE_VERSION}/${NODE_ARCHIVE}"

# Current published release when this workshop image was authored (2026-07-28).
PI_CODING_AGENT_VERSION="0.82.1"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root: sudo $0" >&2
  exit 1
fi

case "$(dpkg --print-architecture)" in
  arm64) ;;
  *)
    echo "This installer is pinned for the Radxa Zero 3W arm64 image." >&2
    exit 1
    ;;
esac

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl git python3 python3-smbus python3-spidev tar xz-utils

work_dir="$(mktemp -d -t cdmx-agent-install.XXXXXXXX)"
cleanup() {
  find "${work_dir}" -mindepth 1 -delete 2>/dev/null || true
  rmdir "${work_dir}" 2>/dev/null || true
}
trap cleanup EXIT

curl --fail --location --proto '=https' --tlsv1.2 \
  --output "${work_dir}/${PICOCLAW_CHECKSUMS}" \
  "${PICOCLAW_RELEASE_URL}/${PICOCLAW_CHECKSUMS}"
echo "${PICOCLAW_CHECKSUMS_SHA256}  ${work_dir}/${PICOCLAW_CHECKSUMS}" | sha256sum --check --strict

published_deb_sha="$(awk -v file="${PICOCLAW_DEB}" '$2 == file { print $1 }' "${work_dir}/${PICOCLAW_CHECKSUMS}")"
if [[ "${published_deb_sha}" != "${PICOCLAW_DEB_SHA256}" ]]; then
  echo "Pinned PicoClaw digest disagrees with the verified release manifest." >&2
  exit 1
fi

curl --fail --location --proto '=https' --tlsv1.2 \
  --output "${work_dir}/${PICOCLAW_DEB}" \
  "${PICOCLAW_RELEASE_URL}/${PICOCLAW_DEB}"
echo "${PICOCLAW_DEB_SHA256}  ${work_dir}/${PICOCLAW_DEB}" | sha256sum --check --strict
dpkg-deb --info "${work_dir}/${PICOCLAW_DEB}" | grep -q '^ Version: 0\.3\.1$'
dpkg-deb --info "${work_dir}/${PICOCLAW_DEB}" | grep -q '^ Architecture: arm64$'
apt-get install -y "${work_dir}/${PICOCLAW_DEB}"

curl --fail --location --proto '=https' --tlsv1.2 \
  --output "${work_dir}/${NODE_ARCHIVE}" "${NODE_URL}"
echo "${NODE_ARCHIVE_SHA256}  ${work_dir}/${NODE_ARCHIVE}" | sha256sum --check --strict
install -d -m 0755 /opt/nodejs
tar --extract --xz --file "${work_dir}/${NODE_ARCHIVE}" \
  --directory /opt/nodejs --strip-components=1 --no-same-owner
for command in node npm npx corepack; do
  ln -sfn "/opt/nodejs/bin/${command}" "/usr/local/bin/${command}"
done

install -d -m 0755 /opt/cdmx-pi
/opt/nodejs/bin/npm install --global --prefix /opt/cdmx-pi \
  "@earendil-works/pi-coding-agent@${PI_CODING_AGENT_VERSION}"
ln -sfn /opt/cdmx-pi/bin/pi /usr/local/bin/pi

workshop_user="${CDMX_WORKSHOP_USER:-cdmx}"
if ! id "${workshop_user}" >/dev/null 2>&1; then
  echo "Workshop user not found: ${workshop_user}" >&2
  exit 1
fi

for hardware_group in i2c spi spidev; do
  if ! getent group "$hardware_group" >/dev/null; then
    groupadd --system "$hardware_group"
  fi
done
usermod --append --groups i2c,spi,spidev "${workshop_user}"

workshop_home="$(getent passwd "${workshop_user}" | cut -d: -f6)"
workshop_group="$(id -gn "${workshop_user}")"
workshop_workspace="${workshop_home}/workspace"
if [[ -L "${workshop_workspace}" ]]; then
  workshop_workspace="$(readlink -f "${workshop_workspace}")"
elif [[ ! -d "${workshop_workspace}" ]]; then
  install -d -o "${workshop_user}" -g "${workshop_group}" -m 0755 \
    "${workshop_workspace}"
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
install -o "${workshop_user}" -g "${workshop_group}" -m 0644 \
  "${script_dir}/workspace/AGENT.md" "${workshop_workspace}/AGENT.md"
install -o "${workshop_user}" -g "${workshop_group}" -m 0644 \
  "${script_dir}/workspace/README.md" "${workshop_workspace}/README.md"

echo
echo "Installed PicoClaw ${PICOCLAW_VERSION}, Node ${NODE_VERSION}, and Pi ${PI_CODING_AGENT_VERSION}."
echo "Workshop skills and tools are not preinstalled; each team clones cdmx-local-ai."
echo "Each team configures its own gateway with: picoclaw onboard"
