# CDMX Local AI workshop kit

🇲🇽 [![Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README.md) ·
🇬🇧 [![English](https://img.shields.io/badge/lang-English-blue.svg)](README.en.md)

Reproducible configuration for ten 1 GB Radxa ZERO 3W boards. Each board
boots as `equipo1` through `equipo10`, runs without a keyboard after the master
image has been built, provides a shared noVNC desktop, and can run a coding
agent from Telegram or Discord inside a restricted workspace.

This repository contains all source code, configuration, checks, and operating
instructions. Multi-gigabyte SD-card images and credentials are generated
locally and intentionally excluded from the repository.

## What participants get

- `http://equipoN.local:6080/control.html` — active noVNC controller.
- `http://equipoN.local:6080/view.html` — shared read-only link for the rest of
  the team.
- `ssh cdmx@equipoN.local` — terminal access from the same LAN.
- `smb://equipoN.local/workspace` — shared, writable code folder.
- A 1280×720 Openbox desktop with a Pi terminal, channel and workspace
  activity, CPU/RAM/temperature status, and a live 2-D Bayesian-optimization
  demonstration.
- PicoClaw as the primary Telegram channel agent; Discord is optional.
- Pi as an optional local interactive coding agent.

The single shared desktop is intentional. Five graphical sessions plus the
agents do not fit comfortably in 1 GB; one person controls the desktop while
the other four watch and send instructions through the team channel.

## Operating system

The pinned image is the fully tested RadxaOS image for ZERO 3: Debian 12
Bookworm arm64, kernel 6.1, release `rsdk-b1`. The original KDE packages remain
available for recovery, but the workshop uses Openbox to conserve memory. The
exact URL and published SHA-512 are in
[`image/radxa-zero3-bookworm-kde-rsdk-b1.env`](image/radxa-zero3-bookworm-kde-rsdk-b1.env).

## Prepare the ten cards

Use SD cards with the same make, model, and capacity for the master and every
copy. On the Mac or Linux preparation computer:

```bash
./host/list-disks.sh
./host/download-stock-image.sh
./host/flash-stock.sh --disk /dev/DISK
```

Boot one ZERO 3W with that original card. This is the only stage that may need
HDMI and a keyboard long enough to join the preparation Wi-Fi. Clone this
repository on the board and run:

```bash
cd cdmx-local-ai
sudo ./device/install.sh --team 1
sudo reboot
```

Test SSH, Samba, noVNC, the setup access point, and a complete power-off and
power-on cycle. **Do not** put API keys or bot tokens on the master card. Clean
and shut it down:

```bash
sudo cdmx-prepare-master --yes-really-power-off
```

Insert it back into the preparation computer, capture its image, and write the
card for each team:

```bash
./host/capture-golden.sh --source /dev/DISK
./host/flash-team.sh --team 1 --disk /dev/DISK
# repeat with --team 2 ... --team 10
```

Every destructive command displays the selected disk and requires exact
confirmation. It also verifies the downloaded/compressed image and the bytes
read back from every completed SD card. See [host/WORKFLOW.md](host/WORKFLOW.md)
for the detailed operator procedure.

## Network setup without knowing the venue Wi-Fi

If there is no saved connection for the venue, `equipoN` creates the WPA2
setup access point `equipoN-setup` at `10.42.N.1`. Connect using the local
workshop password defined while installing the master card and open:

```text
http://10.42.N.1:8080/
```

The page scans for Wi-Fi networks and saves submitted credentials directly in
NetworkManager. It never writes them to this repository or the application
logs. After the board changes networks, reconnect the phone or laptop to the
venue Wi-Fi and use `equipoN.local`.

The ZERO 3W has one Wi-Fi radio, so the setup access point and venue client
connection are not assumed to work simultaneously. If the venue network uses
client isolation, participants will not be able to reach local noVNC even if
Telegram works. For a 50-person workshop, a dedicated workshop router or access
point is the reliable solution; each board's setup access point is for
onboarding and recovery, not a replacement for routed Wi-Fi.

USB-C NCM can provide a rescue route after enabling **OTG peripheral mode** and
the `radxa-ncm@*.*` service with Radxa `rsetup` on the master card. When `usb0`
exists, the board provides `10.55.N.1`. Test the exact cables and hubs plus the
macOS and Windows laptops before the event; do not assume every laptop port can
power a board reliably.

## Configure the agent after cloning

Give every board its own API key or LiteLLM virtual key and its own Telegram
bot token. Never put the LiteLLM master key on a board. For one to five Telegram
users:

```bash
sudo cdmx-agent-setup \
  --provider openai \
  --model gpt-5.4 \
  --telegram-user 111111111 \
  --telegram-user 222222222
```

For a central LiteLLM gateway:

```bash
sudo cdmx-agent-setup \
  --provider litellm \
  --api-base https://YOUR-GATEWAY.example/v1 \
  --model cdmx-workshop \
  --telegram-user 111111111
```

The command requests the API or virtual key and bot token without displaying
them. It also accepts root-only secret files for instructor automation. Details
and the optional Discord flow are in
[device/agent/README.md](device/agent/README.md).

## Workshop-day links

For team `N`:

| Purpose | Address |
|---|---|
| Wi-Fi setup | `http://10.42.N.1:8080/` |
| noVNC control | `http://equipoN.local:6080/control.html` |
| Read-only noVNC | `http://equipoN.local:6080/view.html` |
| SSH | `ssh cdmx@equipoN.local` |
| Samba | `smb://equipoN.local/workspace` |
| USB rescue | `http://10.55.N.1:6080/view.html` |

Run `sudo cdmx-network reset` to forget the venue Wi-Fi and restore the setup
access point.

## Bayesian-optimization demonstration

The reproducible demonstration shown on the desktop lives in
[`aspuru-guzik-group/cdmx-bayesopt`](https://github.com/aspuru-guzik-group/cdmx-bayesopt).
It is designed specifically for a 1 GB ZERO 3W and can drive either a test
function or a physical experiment through a Python function.

## Reliability and security limits

- ext4 journaling, zram, size-limited volatile logs, unattended security
  upgrades, restartable systemd services, and unique post-cloning host keys
  reduce SD-card wear and enable automatic recovery after normal power cycles.
- Sudden power loss can still damage any writable SD card. Keep tested spare
  cards and use `sudo poweroff` whenever possible.
- Direct VNC listens only on loopback. noVNC is LAN-only HTTP protected by the
  VNC password; it must not be exposed directly to the public Internet.
- PicoClaw is pinned to a specific version because it has not reached v1. It
  runs without sudo as a dedicated user, with systemd isolation and one
  writable workspace, but remote code execution is intentionally enabled for
  the exercise. Use explicit allowlists of five authorized people and
  disposable credentials for each team.
- These workshop cards do not use LUKS, as requested.

Run `make test` to execute the repository checks.

Primary references: [Radxa ZERO 3 downloads](https://docs.radxa.com/en/zero/zero3/download),
[Radxa installation](https://docs.radxa.com/en/zero/zero3/getting-started/install-os),
[Radxa access-point setup](https://docs.radxa.com/en/zero/zero3/radxa-os/ap),
[Radxa USB networking](https://docs.radxa.com/en/zero/zero3/radxa-os/usbnet),
[PicoClaw](https://github.com/sipeed/picoclaw),
[Pi](https://pi.dev/docs/latest/quickstart), and
[noVNC](https://github.com/novnc/noVNC).
