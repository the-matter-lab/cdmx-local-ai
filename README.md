# CDMX Local AI workshop kit

Reproducible setup for ten 1 GB Radxa ZERO 3W boards. Each board boots as
`equipo1` through `equipo10`, works without a keyboard after the master image is
built, offers a shared noVNC desktop, and can run a workspace-restricted coding
agent from Telegram or Discord.

This repository contains all source, configuration, checks, and operating
instructions. Multi-gigabyte SD image artifacts and credentials are generated
locally and are intentionally not committed.

## What participants get

- `http://equipoN.local:6080/control.html` — one active noVNC controller.
- `http://equipoN.local:6080/view.html` — shared view-only link for teammates.
- `ssh cdmx@equipoN.local` — terminal access on the same LAN.
- `smb://equipoN.local/workspace` — writable shared code folder.
- A 1280×720 Openbox desktop with a Pi terminal, channel/workspace activity,
  CPU/RAM/temperature status, and a live 2-D Bayesian-optimization demo.
- PicoClaw as the Telegram-first channel agent; Discord is optional.
- Pi as an optional local interactive coding agent.

One shared desktop is deliberate. Five graphical sessions plus agents do not
fit comfortably in 1 GB; one person controls while the other four watch and
prompt through the team channel.

## Operating system

The image pin is Radxa's fully-tested ZERO 3 RadxaOS image: Debian 12 Bookworm
arm64, kernel 6.1, release `rsdk-b1`. The stock KDE packages remain available
for recovery, but the workshop runs Openbox to conserve memory. The exact URL
and published SHA-512 are in
[`image/radxa-zero3-bookworm-kde-rsdk-b1.env`](image/radxa-zero3-bookworm-kde-rsdk-b1.env).

## Build the ten cards

Use the same make/model/capacity SD card for the master and all copies. On the
Mac or Linux preparation computer:

```bash
./host/list-disks.sh
./host/download-stock-image.sh
./host/flash-stock.sh --disk /dev/DISK
```

Boot that one stock card in a ZERO 3W. This is the only stage that may require
HDMI/keyboard long enough to join preparation Wi-Fi. Clone this repository on
the board, then run:

```bash
cd cdmx-local-ai
sudo ./device/install.sh --team 1
sudo reboot
```

Test SSH, Samba, noVNC, the setup hotspot, and a full power cycle. Do **not**
put API keys or bot tokens on the master. Sanitize and power it off:

```bash
sudo cdmx-prepare-master --yes-really-power-off
```

Put it back in the preparation computer, capture it, and flash each team card:

```bash
./host/capture-golden.sh --source /dev/DISK
./host/flash-team.sh --team 1 --disk /dev/DISK
# repeat with --team 2 ... --team 10
```

Every destructive command displays the selected disk and requires an exact
confirmation. It verifies both the downloaded/compressed image and the bytes
read back from each finished SD card. See [host/WORKFLOW.md](host/WORKFLOW.md)
for the detailed operator procedure.

## Network setup without knowing venue Wi-Fi

With no saved venue connection, `equipoN` creates the WPA2 setup hotspot
`equipoN-setup` at `10.42.N.1`. Join it using the local workshop password set
while installing the master, then open:

```text
http://10.42.N.1:8080/
```

The page scans for Wi-Fi and saves the submitted credentials directly in
NetworkManager. It never writes them to this repository or application logs.
After the board switches networks, reconnect the phone/laptop to venue Wi-Fi
and use `equipoN.local`.

The ZERO 3W has one Wi-Fi radio, so the setup AP and venue client connection
are not assumed to run concurrently. If the venue network isolates clients,
participants will not reach local noVNC even though Telegram works. For a
50-person workshop, the reliable solution is a dedicated workshop router/AP;
the per-board hotspot is onboarding/recovery, not a substitute for routed Wi-Fi.

USB-C NCM can be a rescue route after enabling **OTG peripheral mode** and the
`radxa-ncm@*.*` service with Radxa `rsetup` on the master. When `usb0` exists,
the board offers `10.55.N.1`. Test the exact cables, hubs, macOS, and Windows
laptops before the event; do not assume every laptop port can power a board
reliably.

## Configure the agent after cloning

Give every board its own API/LiteLLM virtual key and Telegram bot token. Never
put the upstream LiteLLM master key on a board. For one to five Telegram users:

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

The command prompts invisibly for the API/virtual key and bot token. It also
supports root-only secret files for instructor automation. Details and the
optional Discord flow are in [device/agent/README.md](device/agent/README.md).

## Day-of links

For team `N`:

| Purpose | Address |
|---|---|
| Wi-Fi onboarding | `http://10.42.N.1:8080/` |
| noVNC control | `http://equipoN.local:6080/control.html` |
| noVNC view-only | `http://equipoN.local:6080/view.html` |
| SSH | `ssh cdmx@equipoN.local` |
| Samba | `smb://equipoN.local/workspace` |
| USB rescue | `http://10.55.N.1:6080/view.html` |

Run `sudo cdmx-network reset` to forget venue Wi-Fi and restore the setup AP.

## Reliability and security boundaries

- ext4 journaling, zram, volatile bounded logs, unattended security updates,
  restartable systemd services, and unique post-clone host keys reduce SD-card
  wear and make ordinary power-cycle recovery automatic.
- Sudden power loss can still corrupt any writable SD card. Keep tested spare
  cards and use `sudo poweroff` whenever possible.
- Raw VNC listens only on loopback. noVNC is LAN-only HTTP with VNC password
  protection; it must not be exposed directly to the public internet.
- PicoClaw is pinned because it is pre-v1. It runs without sudo as a separate
  user, with systemd isolation and a single writable workspace, but remote code
  execution is still intentionally enabled for the exercise. Use only explicit
  five-person allowlists and disposable per-team credentials.
- No LUKS is used on these workshop cards, as requested.

Run repository checks with `make test`.

Primary references: [Radxa ZERO 3 downloads](https://docs.radxa.com/en/zero/zero3/download),
[Radxa installation](https://docs.radxa.com/en/zero/zero3/getting-started/install-os),
[Radxa hotspot setup](https://docs.radxa.com/en/zero/zero3/radxa-os/ap),
[Radxa USB networking](https://docs.radxa.com/en/zero/zero3/radxa-os/usbnet),
[PicoClaw](https://github.com/sipeed/picoclaw),
[Pi](https://pi.dev/docs/latest/quickstart), and
[noVNC](https://github.com/novnc/noVNC).
