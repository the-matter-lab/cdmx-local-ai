# Workshop agent and chat channels

This bundle installs PicoClaw v0.3.1 for arm64, the Pi coding agent, and a locked-down service account. No real credentials belong in this repository. Every board gets a different API key (or LiteLLM virtual key) and its own Telegram bot token during workshop preparation.

## Install

On the Radxa, from the repository root:

```bash
sudo device/agent/install-agent.sh
```

The installer verifies both the pinned upstream release checksum manifest and the pinned `picoclaw_aarch64.deb` digest before installation. It also installs a verified official Node 22 arm64 runtime and `@earendil-works/pi-coding-agent` 0.82.1. The service is installed but is not started until credentials and a non-empty allowlist exist.

## Configure one team (Telegram first)

Find each participant's numeric Telegram user ID, then supply one to five IDs. Secrets are hidden prompts and do not enter shell history or the process list:

```bash
sudo cdmx-agent-setup \
  --provider openai \
  --model gpt-5.4 \
  --telegram-user 111111111 \
  --telegram-user 222222222 \
  --telegram-user 333333333 \
  --telegram-user 444444444 \
  --telegram-user 555555555
```

For a LiteLLM proxy, the model is the proxy's alias and the prompted value is that board's virtual key:

```bash
sudo cdmx-agent-setup \
  --provider litellm \
  --api-base https://litellm.example.org/v1 \
  --model cdmx-workshop \
  --telegram-user 111111111
```

Discord is opt-in. Enable the Discord developer portal's Message Content Intent, then add its allowed users separately:

```bash
sudo cdmx-agent-setup \
  --telegram-user 111111111 \
  --enable-discord \
  --discord-user 999999999999999999
```

For automated imaging, put each secret in a separate root-only (`chmod 600`) file and pass `--api-key-file`, `--telegram-token-file`, and optionally `--discord-token-file`. Alternatively, `--from-env` reads `OPENAI_API_KEY` or `LITELLM_VIRTUAL_KEY`, `LITELLM_API_BASE`, plus `TELEGRAM_BOT_TOKEN` and optional `DISCORD_BOT_TOKEN`; unset those variables immediately afterward. File or hidden-prompt input is preferred.

If using environment input through `sudo`, explicitly preserve only the variables needed, for example:

```bash
sudo --preserve-env=OPENAI_API_KEY,TELEGRAM_BOT_TOKEN \
  cdmx-agent-setup --from-env --telegram-user 111111111
```

Reconfiguration refuses to overwrite existing credentials unless `--force` is supplied. Use `--no-start` when preparing an offline image.

## Security boundaries

- Telegram and Discord never accept an empty allowlist; each accepts at most five explicit numeric user IDs.
- Remote command execution is enabled because coding is the exercise, but PicoClaw v0.3.1 restricts paths to `/var/lib/cdmx-picoclaw/workspace` and keeps its dangerous-command filter enabled.
- The service runs as the non-login `cdmx-agent` user with no capabilities, a read-only operating system, private devices and temporary directory, and multiple kernel/system-call protections.
- Only PicoClaw state/workspace is writable. Configuration is root-owned; secrets are `root:cdmx-agent` mode `0640`. The noVNC `cdmx` user shares the setgid workspace through a separate `cdmx-workspace` group and cannot read the secret file.
- The gateway listens only on loopback. Telegram and Discord use outbound connections, so no PicoClaw port needs to be exposed on the LAN.

Useful checks:

```bash
sudo systemctl status cdmx-picoclaw.service
sudo journalctl -u cdmx-picoclaw.service -n 100 --no-pager
sudo -u cdmx-agent picoclaw --version
pi --version
```

Run the local generator tests with:

```bash
python3 -m unittest discover -s device/agent/tests -v
```
