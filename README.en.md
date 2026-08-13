# Coding agent · CDMX workshop

🇲🇽 [![Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README.md) ·
🇬🇧 [![English](https://img.shields.io/badge/lang-English-blue.svg)](README.en.md)

PicoClaw turns Telegram or Discord into an entry point for each Radxa ZERO 3W
coding agent. Participants can ask in natural language to change the NeoPixel,
read the TCS34725, explain the project, or create, modify, and test files. The
noVNC desktop and the agent share the same workspace.

The image, Wi-Fi, and noVNC live in
[`cdmx-radxa-flash`](https://github.com/the-matter-lab/cdmx-radxa-flash). The
Color Lab and RGB Bayesian-optimization exercise remain in
[`cdmx-bayesopt`](https://github.com/the-matter-lab/cdmx-bayesopt).

## 1. Install

It is already installed in the workshop image. To update it or install it on
another card:

```bash
git clone https://github.com/the-matter-lab/cdmx-local-ai.git
cd cdmx-local-ai
sudo ./device/agent/install-agent.sh
```

The installer pins PicoClaw `0.3.1`, creates the unprivileged `cdmx-agent`
account, and installs three skills: `led`, `color-sensor`, and `coding`. It also
installs `pi` for interactive agent work from the desktop terminal.

## 2. Choose a model

For a short trial, we recommend an [OpenRouter](https://openrouter.ai/keys) key
with its `openrouter/free` router:

```bash
sudo cdmx-agent-setup \
  --provider openrouter \
  --telegram-user 111111111 \
  --telegram-user 222222222
```

The command asks for the key and bot token without displaying them. OpenRouter's
free tier has low limits and variable availability; it is for experiments, not
production. These options are also available:

| Option | Argument | Default |
|---|---|---|
| [Gemini API](https://aistudio.google.com/api-keys) | `--provider gemini` | `gemini-2.5-flash` |
| [DeepSeek](https://platform.deepseek.com/api_keys) | `--provider deepseek` | `deepseek-chat` |
| [Moonshot/Kimi](https://platform.moonshot.cn/console/api-keys) | `--provider moonshot` | `moonshot-v1-8k` |
| [OpenAI API](https://platform.openai.com/api-keys) | `--provider openai` | `gpt-5.4` |
| [Anthropic API](https://console.anthropic.com/settings/keys) | `--provider anthropic` | `claude-sonnet-4-6` |
| Workshop LiteLLM | `--provider litellm --api-base https://…/v1` | `cdmx-workshop` |

Override the model with `--model`. Provider accounts and quotas are separate.

PicoClaw also provides its own login flows, without pasting an API key. Actual
access depends on the account's plan and permissions:

```bash
# Displays a code and URL for OpenAI/Codex login.
sudo cdmx-agent-setup --provider openai-oauth --telegram-user 111111111

# First create a token with `claude setup-token` on a machine with Claude.
sudo cdmx-agent-setup --provider anthropic-oauth --telegram-user 111111111
```

## 3. Connect chat

### Telegram

1. Create a bot with [`@BotFather`](https://t.me/BotFather) and send it `/start`.
2. Get every participant's numeric `from.id` using the official
   [`getUpdates`](https://core.telegram.org/bots/api#getupdates) method.
3. Repeat `--telegram-user ID` for every person (maximum five).

### Discord

Enable **Message Content Intent** for the bot and copy the participants' numeric
IDs:

```bash
sudo cdmx-agent-setup \
  --provider openrouter \
  --disable-telegram \
  --enable-discord \
  --discord-user 999999999999999999
```

To use both channels, omit `--disable-telegram` and add the Discord options.
Use `--force` to replace an older configuration.

## 4. Try it

Send the bot messages such as:

```text
Change the LED to purple at 20% brightness.
Read the color sensor and explain the values.
Review my project files and run their tests.
```

PicoClaw selects the appropriate skill automatically. You can also use
`/list skills` and `/use led ...`. The same hardware commands work in a
terminal:

```bash
cd /var/lib/cdmx-picoclaw/workspace
python3 tools/cdmx_hardware.py led '#6633FF' --brightness 0.20
python3 tools/cdmx_hardware.py sensor
```

## Operations and security

```bash
sudo systemctl status cdmx-picoclaw.service
sudo journalctl -u cdmx-picoclaw.service -n 100 --no-pager
sudo systemctl restart cdmx-picoclaw.service
```

Only allowlisted IDs can talk to the bot. The service does not run as root, can
write only inside its shared workspace, and receives only the required I²C/SPI
groups. Credentials stay outside the agent workspace in
`/etc/cdmx-picoclaw/.security.yml` with mode `0640`. Use separate disposable
bots and keys per team. PicoClaw is still pre-v1 software; do not expose it as a
public service or use it with sensitive data.

```bash
make test
```
