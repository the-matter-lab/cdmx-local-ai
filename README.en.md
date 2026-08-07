# Local agent for the CDMX workshop

🇲🇽 [![Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README.md) ·
🇬🇧 [![English](https://img.shields.io/badge/lang-English-blue.svg)](README.en.md)

This repository contains only the workshop coding agent for the Radxa ZERO
3W: PicoClaw for Telegram or Discord conversations, Pi for terminal work, and
a configuration that confines the agent to the shared workspace.

The operating-system image, Wi-Fi portal, noVNC desktop, and SD-card tools live
in [`the-matter-lab/cdmx-radxa-flash`](https://github.com/the-matter-lab/cdmx-radxa-flash).
The Bayesian-optimization exercise lives in
[`the-matter-lab/cdmx-bayesopt`](https://github.com/the-matter-lab/cdmx-bayesopt).

## Install on the Radxa

```bash
git clone https://github.com/the-matter-lab/cdmx-local-ai.git
cd cdmx-local-ai
sudo ./device/agent/install-agent.sh
```

The installer pins and verifies PicoClaw, Node, and Pi. It creates the
non-login `cdmx-agent` account, systemd service, and shared workspace at
`/var/lib/cdmx-picoclaw/workspace`. The service does not start until credentials
and at least one authorized user have been configured.

## Configure Telegram

Every team should use its own OpenAI key or LiteLLM virtual key and its own bot.
For one to five participants:

```bash
sudo cdmx-agent-setup \
  --provider openai \
  --model gpt-5.4 \
  --telegram-user 111111111 \
  --telegram-user 222222222
```

The command requests the API key and bot token through hidden prompts.
`--telegram-user` values are numeric Telegram user IDs, not usernames.

With a LiteLLM gateway:

```bash
sudo cdmx-agent-setup \
  --provider litellm \
  --api-base https://YOUR-GATEWAY.example/v1 \
  --model cdmx-workshop \
  --telegram-user 111111111
```

## Configure Discord

Enable *Message Content Intent* for the bot in Discord's developer portal and
explicitly add the allowed people:

```bash
sudo cdmx-agent-setup \
  --provider openai \
  --model gpt-5.4 \
  --disable-telegram \
  --enable-discord \
  --discord-user 999999999999999999
```

Telegram and Discord can also be enabled in the same command. See
[`device/agent/README.md`](device/agent/README.md) for automation with protected
files or environment variables.

## Use and diagnose

```bash
sudo systemctl status cdmx-picoclaw.service
sudo journalctl -u cdmx-picoclaw.service -n 100 --no-pager
sudo -u cdmx-agent picoclaw --version
pi --version
```

The agent runs without privileges and can write only inside its workspace.
Credentials are stored at `/etc/cdmx-picoclaw/.security.yml`, owned by
`root:cdmx-agent` with mode `0640`. Use separate disposable credentials per
team and explicit participant allowlists.

Run the repository checks with:

```bash
make test
```
