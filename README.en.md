# Coding agent · CDMX workshop

🇲🇽 [![Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README.md) ·
🇬🇧 [![English](https://img.shields.io/badge/lang-English-blue.svg)](README.en.md)

PicoClaw connects Telegram to each Radxa ZERO 3W coding agent. Participants
configure the model, bot, and gateway with PicoClaw's native syntax. Workshop
skills let the agent control the NeoPixel, read the TCS34725, and work with
code.

The team-facing material is visible at the repository root:
[`skills/`](skills) contains the agent instructions and [`tools/`](tools)
contains the hardware interface. The image does not install either; each team
downloads them during the workshop.

The image already includes PicoClaw `0.3.1` and `pi`, but not this repository
or its skills. Do not run the installer from the noVNC desktop.

## 1. Clone the repository

From `~/workspace`:

```bash
git clone https://github.com/the-matter-lab/cdmx-local-ai.git
cd cdmx-local-ai
```

## 2. Initialize PicoClaw

PicoClaw `0.3.1` calls its initialization command `onboard`:

```bash
picoclaw version
picoclaw onboard
```

The **`picoclaw is ready!`** message is expected: it only confirms that
PicoClaw created its initial files. No model, key, bot, or gateway is configured
yet; those are the participant's next steps.

This creates `~/.picoclaw/config.json`, `~/.picoclaw/.security.yml`, and the
PicoClaw workspace. For the workshop, start from the examples:

```bash
cp device/agent/examples/config.telegram.json ~/.picoclaw/config.json
cp device/agent/examples/security.telegram.example.yml ~/.picoclaw/.security.yml
chmod 600 ~/.picoclaw/.security.yml
```

Now edit both files yourself:

```bash
nano ~/.picoclaw/config.json
nano ~/.picoclaw/.security.yml
```

In `config.json`:

- Replace `YOUR_NUMERIC_TELEGRAM_USER_ID` with your numeric ID.
- `provider`, `model`, and `model_name` select the model.
- Keep `workspace` set to `/home/cdmx/workspace` so noVNC, `pi`, and PicoClaw
  share the same code.
- `allow_from` must contain only authorized participants.

In `.security.yml`, replace only the OpenRouter key and bot token. Never place
them in `config.json`, the repository, or chat.

To use a different provider, preserve the `model_list` structure and follow
PicoClaw's [official provider guide](https://github.com/sipeed/picoclaw/blob/v0.3.1/docs/guides/providers.md).

## 3. Install the skills

PicoClaw `0.3.1` installs one skill per command. This block installs all three
at once while using the native syntax:

```bash
for skill in coding color-sensor led; do
  picoclaw skills install "the-matter-lab/cdmx-local-ai/skills/$skill"
done
picoclaw skills list
```

To install all three into `pi` with one command:

```bash
npx skills add the-matter-lab/cdmx-local-ai \
  --skill '*' \
  --agent pi --yes
```

The hardware tool stays inside the clone and is not installed system-wide.
From `~/workspace/cdmx-local-ai`, test it with:

```bash
python3 tools/cdmx_hardware.py --help
```

## 4. Create the Telegram bot

1. Talk to [`@BotFather`](https://t.me/BotFather), run `/newbot`, and place the
   token in `.security.yml`.
2. Send `/start` to the new bot.
3. Obtain your numeric ID through the official
   [`getUpdates`](https://core.telegram.org/bots/api#getupdates) method and put
   it in `allow_from`.

An empty allowlist permits everyone: do not leave it empty.

## 5. Test and start the gateway

First test the model and tools without Telegram:

```bash
picoclaw agent -m "List the workshop skills"
```

Then start the gateway in the foreground:

```bash
picoclaw gateway
```

Keep that terminal open and message the bot. `Ctrl-C` stops the gateway; the
same command starts it again. Try messages such as:

```text
Change the LED to purple at 20% brightness.
Read the color sensor and explain the values.
Review cdmx-bayesopt and run its tests.
```

Use `/list skills` and `/use led ...` to practice PicoClaw skill syntax. `pi`
remains available as a separate interactive coding agent:

```bash
pi
```

## Discord

PicoClaw also accepts a `channel_list.discord` block. Enable **Message Content
Intent**, put authorized IDs in `allow_from`, and store the token under
`channels.discord.token` in `.security.yml`. See the
[official Discord syntax](https://github.com/sipeed/picoclaw/blob/v0.3.1/docs/channels/discord/README.md).

## Image installation

[`device/agent/install-agent.sh`](device/agent/install-agent.sh) is only for
building the image or installing the binaries on a prepared Radxa.
Participants do not run it. The installer does not include the skills or tools;
the repository contains no real credentials.

```bash
make test
```
