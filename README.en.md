# CDMX Local AI workshop kit

🇲🇽 [![Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README.md) ·
🇬🇧 [![English](https://img.shields.io/badge/lang-English-blue.svg)](README.en.md)

Reproducible configuration for ten 1 GB Radxa ZERO 3W boards. Each board
boots as `equipo0` through `equipo9`, runs without a keyboard, provides a
shared noVNC desktop, and can run a coding
agent from Telegram or Discord inside a restricted workspace.

This repository contains all source code, configuration, checks, and operating
instructions. Multi-gigabyte SD-card images are not stored in Git; the
ready-to-flash image is also published as a Docker artifact. Credentials are
always generated and stored locally.

## What participants get

- `http://equipoN.local:6080/control.html` — active noVNC controller.
- `http://equipoN.local:6080/view.html` — shared read-only link for the rest of
  the team.
- `ssh cdmx@equipoN.local` — terminal access from the same LAN.
- Passwordless `sudo` for installing exercise tools and configuring local
  hardware.
- A 1280×720 Openbox desktop with three workspaces on a clickable bottom bar:
  **WORK** for code, **AGENT** for Pi Agent and channel activity, and **RUN**
  for experiments and CPU/RAM/temperature monitoring. Windows have normal
  title bars and can be moved, resized, minimized, maximized, and selected with
  `Alt+Tab`. Right-click the background to open terminals, the Geany or Nano
  editor, Pi Agent, or the system monitor. `Ctrl+Alt+T` opens a new terminal.
- A Matter Lab conference wallpaper and a one-click menu launcher that clones
  or safely updates both workshop repositories in the shared workspace.
- PicoClaw as the primary Telegram channel agent; Discord is optional.
- Pi as an optional local interactive coding agent.
- `cdmx-bayesopt` dependencies and the ZERO 3W I2C4-M0/SPI3-M1 interfaces
  prepared for the color lab.

The single shared graphical session is intentional, but it contains the three
independent workspaces above so the team can organize its windows. Five
separate graphical sessions plus the agents do not fit comfortably in 1 GB;
one person controls the shared session while the other four watch and send
instructions through the team channel.

## Operating system

The pinned image is the fully tested RadxaOS image for ZERO 3: Debian 12
Bookworm arm64, kernel 6.1, release `rsdk-b1`. The workshop image removes the
unused local KDE applications and browsers and uses Openbox to conserve storage and memory. The
exact URL and published SHA-512 are in
[`image/radxa-zero3-bookworm-kde-rsdk-b1.env`](image/radxa-zero3-bookworm-kde-rsdk-b1.env).

## Prepare the ten cards

Use SD cards with the same make, model, and capacity. On the preparation Mac,
build the local workshop image once:

```bash
./host/download-stock-image.sh
./host/build-workshop-image.sh
```

On macOS, open [`host/start-imager.command`](host/start-imager.command) to use
the local interface at `http://127.0.0.1:8766/`. macOS requests authorization
once when the server starts; after that, insert each card, choose `equipo0`
through `equipo9` (or `admin` for the instructor's faster spare card), and
watch live write and verification progress. The server
listens only on loopback, revalidates that the target is a removable whole
disk, and ejects the card when it is safe to remove.

To avoid rebuilding the image, download the verified artifact from
[Docker Hub](https://hub.docker.com/r/bestquark/cdmx-radxa-zero3w):

```bash
./host/pull-workshop-image.sh
./host/start-imager.command
```

The container is not an application to run: it transports
`cdmx-workshop-golden.img.xz` in parts plus its SHA-512 checksum. The script
reassembles the image and verifies the checksum before enabling SD-card
flashing. To pin an exact version, use, for example,
`CDMX_IMAGE_REF=bestquark/cdmx-radxa-zero3w:2026-08-06.3 ./host/pull-workshop-image.sh`.

No physical master board or master SD card is used. The build runs in an
isolated ARM64 Linux environment on the Mac and includes the Mac user's SSH
public key. Then write each card in the web app, or use the CLI:

```bash
./host/flash-team.sh --team 0 --disk /dev/DISK
# repeat with --team 1 ... --team 9
```

Every destructive command displays the selected disk and requires exact
confirmation. It also verifies the downloaded/compressed image and the bytes
read back from every completed SD card. See [host/WORKFLOW.md](host/WORKFLOW.md)
for the detailed operator procedure.

## Network setup without knowing the venue Wi-Fi

If there is no saved connection for the venue, `equipoN` creates the open
setup access point `equipoN-setup` at `10.42.N.1`. Joining it should open the
network sign-in window automatically on iPhone/iPad, macOS, Windows, and
Android. Windows may show an **Action needed** notification first. If the
operating system does not show anything, open:

```text
http://10.42.N.1:8080/
```

The `admin` card uses `admin-setup`, `http://10.42.10.1:8080/`, and
`http://admin.local:6080/control.html`.

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
the `radxa-ncm@*.*` service with Radxa `rsetup` on each board. When `usb0`
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
| USB rescue | `http://10.55.N.1:6080/view.html` |

Run `sudo cdmx-network reset` to forget the venue Wi-Fi and restore the setup
access point.

## Bayesian-optimization example

The reproducible example that participants can clone and run lives in
[`aspuru-guzik-group/cdmx-bayesopt`](https://github.com/aspuru-guzik-group/cdmx-bayesopt).
It is designed specifically for a 1 GB ZERO 3W and can drive either a test
function or a physical experiment through a Python function.

## Reliability and security limits

- ext4 journaling, zram, size-limited volatile logs, unattended security
  upgrades, restartable systemd services, and unique post-cloning host keys
  reduce SD-card wear and enable automatic recovery after normal power cycles.
- Sudden power loss can still damage any writable SD card. Keep tested spare
  cards and use `sudo poweroff` whenever possible.
- Direct VNC listens only on loopback. The setup Wi-Fi and noVNC are
  deliberately passwordless for the workshop, so anyone on those local
  networks can view/control the desktop. The `cdmx` account also has
  passwordless `sudo` for hardware exercises. Do not expose these interfaces to
  the public Internet. SSH is public-key only.
- PicoClaw is pinned to a specific version because it has not reached v1. It
  runs without sudo as a dedicated user, with systemd isolation and one
  writable workspace, but remote code execution is intentionally enabled for
  the exercise. Use explicit allowlists of five authorized people and
  disposable credentials for each team.

Run `make test` to execute the repository checks.

Primary references: [Radxa ZERO 3 downloads](https://docs.radxa.com/en/zero/zero3/download),
[Radxa installation](https://docs.radxa.com/en/zero/zero3/getting-started/install-os),
[Radxa access-point setup](https://docs.radxa.com/en/zero/zero3/radxa-os/ap),
[Radxa USB networking](https://docs.radxa.com/en/zero/zero3/radxa-os/usbnet),
[PicoClaw](https://github.com/sipeed/picoclaw),
[Pi](https://pi.dev/docs/latest/quickstart), and
[noVNC](https://github.com/novnc/noVNC).
