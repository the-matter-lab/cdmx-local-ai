#!/usr/bin/env python3
"""Safely generate PicoClaw v0.3.1 workshop configuration."""

from __future__ import annotations

import argparse
import getpass
import grp
import json
import os
import pathlib
import pwd
import stat
import subprocess
import sys
import tempfile
import urllib.parse

CONFIG_DIR = pathlib.Path("/etc/cdmx-picoclaw")
STATE_DIR = pathlib.Path("/var/lib/cdmx-picoclaw")
SERVICE_USER = "cdmx-agent"
SERVICE_GROUP = "cdmx-agent"
MAX_CHANNEL_USERS = 5

PROVIDERS = {
    "openrouter": {
        "provider": "openrouter",
        "model": "openrouter/free",
        "env": "OPENROUTER_API_KEY",
        "prompt": "OpenRouter API key: ",
    },
    "gemini": {
        "provider": "gemini",
        "model": "gemini-2.5-flash",
        "env": "GEMINI_API_KEY",
        "prompt": "Gemini API key: ",
    },
    "deepseek": {
        "provider": "deepseek",
        "model": "deepseek-chat",
        "env": "DEEPSEEK_API_KEY",
        "prompt": "DeepSeek API key: ",
    },
    "moonshot": {
        "provider": "moonshot",
        "model": "moonshot-v1-8k",
        "env": "MOONSHOT_API_KEY",
        "prompt": "Moonshot/Kimi API key: ",
    },
    "openai": {
        "provider": "openai",
        "model": "gpt-5.4",
        "env": "OPENAI_API_KEY",
        "prompt": "OpenAI API key: ",
    },
    "anthropic": {
        "provider": "anthropic",
        "model": "claude-sonnet-4-6",
        "env": "ANTHROPIC_API_KEY",
        "prompt": "Anthropic API key: ",
    },
    "litellm": {
        "provider": "litellm",
        "model": "cdmx-workshop",
        "env": "LITELLM_VIRTUAL_KEY",
        "prompt": "LiteLLM virtual key: ",
    },
    "openai-oauth": {
        "provider": "openai",
        "model": "gpt-5.4",
        "oauth": "openai",
    },
    "anthropic-oauth": {
        "provider": "anthropic",
        "model": "claude-sonnet-4.6",
        "oauth": "anthropic",
    },
}


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description=(
            "Configure one team's PicoClaw agent. Secrets are requested with "
            "hidden prompts unless a root-readable file or --from-env is used."
        )
    )
    p.add_argument(
        "--provider",
        choices=tuple(PROVIDERS),
        default="openrouter",
        help="LLM provider; openrouter uses its free-model router by default",
    )
    p.add_argument("--model", help="Override the provider's workshop default model")
    p.add_argument("--api-base", help="LiteLLM OpenAI-compatible base URL, normally ending in /v1")
    p.add_argument("--api-key-file", type=pathlib.Path, help="Root-readable file containing only the API/virtual key")
    p.add_argument("--from-env", action="store_true", help="Read API/channel secrets from environment variables")
    p.add_argument("--telegram-user", action="append", default=[], metavar="NUMERIC_ID", help="Allowed Telegram user ID; repeat up to five times")
    p.add_argument("--telegram-token-file", type=pathlib.Path, help="Root-readable file containing only the bot token")
    p.add_argument("--disable-telegram", action="store_true", help="Disable the default Telegram channel")
    p.add_argument("--enable-discord", action="store_true")
    p.add_argument("--discord-user", action="append", default=[], metavar="NUMERIC_ID", help="Allowed Discord user ID; repeat up to five times")
    p.add_argument("--discord-token-file", type=pathlib.Path, help="Root-readable file containing only the bot token")
    p.add_argument("--force", action="store_true", help="Replace an existing configuration")
    p.add_argument("--no-start", action="store_true", help="Write files without enabling/starting the service")
    p.add_argument("--config-dir", type=pathlib.Path, default=CONFIG_DIR, help=argparse.SUPPRESS)
    p.add_argument("--state-dir", type=pathlib.Path, default=STATE_DIR, help=argparse.SUPPRESS)
    return p


def one_line_secret(value: str, label: str) -> str:
    value = value.strip()
    if not value or "\n" in value or "\r" in value:
        raise ValueError(f"{label} must be one non-empty line")
    return value


def secret_from_file(path: pathlib.Path, label: str) -> str:
    if path.is_symlink():
        raise ValueError(f"{path} must not be a symbolic link")
    st = path.stat()
    if not stat.S_ISREG(st.st_mode):
        raise ValueError(f"{path} must be a regular file")
    if st.st_mode & 0o077:
        raise ValueError(f"{path} is accessible by group/others; run: chmod 600 {path}")
    return one_line_secret(path.read_text(encoding="utf-8"), label)


def obtain_secret(
    *, file_path: pathlib.Path | None, from_env: bool, env_name: str, prompt: str, label: str
) -> str:
    if file_path:
        return secret_from_file(file_path, label)
    if from_env:
        return one_line_secret(os.environ.get(env_name, ""), f"{label} ({env_name})")
    if not sys.stdin.isatty():
        raise ValueError(f"No terminal available; use --{label.replace('_', '-')}-file or --from-env")
    return one_line_secret(getpass.getpass(prompt), label)


def validate_ids(values: list[str], channel: str, enabled: bool) -> list[str]:
    if not enabled:
        if values:
            raise ValueError(f"{channel} users were provided while {channel} is disabled")
        return []
    if not 1 <= len(values) <= MAX_CHANNEL_USERS:
        raise ValueError(f"{channel} needs 1-{MAX_CHANNEL_USERS} explicitly allowed user IDs")
    if len(set(values)) != len(values):
        raise ValueError(f"{channel} user IDs must be unique")
    if any(not value.isascii() or not value.isdigit() for value in values):
        raise ValueError(f"{channel} user IDs must contain digits only")
    return values


def validate_base_url(value: str | None) -> str:
    if not value:
        raise ValueError("--api-base is required for LiteLLM")
    value = value.rstrip("/")
    parsed = urllib.parse.urlparse(value)
    loopback = parsed.hostname in {"localhost", "127.0.0.1", "::1"}
    if not parsed.hostname or (parsed.scheme != "https" and not (parsed.scheme == "http" and loopback)):
        raise ValueError("LiteLLM URL must use HTTPS (HTTP is allowed only for loopback)")
    return value


def build_config(args: argparse.Namespace) -> dict[str, object]:
    telegram_enabled = not args.disable_telegram
    if not telegram_enabled and not args.enable_discord:
        raise ValueError("enable Telegram or Discord; at least one controlled channel is required")
    telegram_users = validate_ids(args.telegram_user, "Telegram", telegram_enabled)
    discord_users = validate_ids(args.discord_user, "Discord", args.enable_discord)

    provider = PROVIDERS[args.provider]
    model_name = (args.model or provider["model"]).strip()
    if not model_name or any(character.isspace() for character in model_name):
        raise ValueError("model must be one non-empty identifier without whitespace")

    model: dict[str, object] = {
        "model_name": "workshop",
        "provider": provider["provider"],
        "model": model_name,
        "enabled": True,
    }
    if provider.get("oauth"):
        model["auth_method"] = "oauth"
    if args.provider == "gemini":
        model["tool_schema_transform"] = "simple"
    if args.provider == "litellm":
        model["api_base"] = validate_base_url(args.api_base)
    elif args.api_base:
        raise ValueError("--api-base is only accepted with --provider litellm")

    return {
        "version": 3,
        "agents": {
            "defaults": {
                "workspace": str(args.state_dir / "workspace"),
                "restrict_to_workspace": True,
                "allow_read_outside_workspace": False,
                "model_name": "workshop",
                "max_tokens": 4096,
                "context_window": 65536,
                "max_tool_iterations": 20,
                "max_parallel_turns": 1,
            }
        },
        "model_list": [model],
        "channel_list": {
            "telegram": {
                "enabled": telegram_enabled,
                "type": "telegram",
                "allow_from": telegram_users,
                "group_trigger": {"mention_only": True},
                "settings": {"streaming": {"enabled": False}},
            },
            "discord": {
                "enabled": args.enable_discord,
                "type": "discord",
                "allow_from": discord_users,
                "group_trigger": {"mention_only": True},
                "settings": {},
            },
        },
        "gateway": {"host": "127.0.0.1", "port": 18790, "log_level": "info"},
        "tools": {
            "exec": {
                "enabled": True,
                "allow_remote": True,
                "enable_deny_patterns": True,
                "timeout_seconds": 120,
            },
            "allow_read_paths": [],
            "allow_write_paths": [],
        },
        "heartbeat": {"enabled": False},
    }


def build_security(
    api_key: str | None, telegram_token: str | None, discord_token: str | None
) -> str:
    # JSON string literals are also valid YAML and safely escape punctuation.
    lines: list[str] = []
    if api_key:
        lines += [
            "model_list:",
            "  workshop:",
            "    api_keys:",
            f"      - {json.dumps(api_key)}",
        ]
    channels: list[str] = []
    if telegram_token:
        channels += ["  telegram:", "    settings:", f"      token: {json.dumps(telegram_token)}"]
    if discord_token:
        channels += ["  discord:", "    settings:", f"      token: {json.dumps(discord_token)}"]
    if channels:
        lines += ["channel_list:", *channels]
    return "\n".join(lines) + "\n"


def run_oauth_login(provider: str, config: dict[str, object], state_dir: pathlib.Path) -> None:
    """Authenticate as the service account without making /etc writable to it."""

    service = pwd.getpwnam(SERVICE_USER)
    temporary_config = state_dir / ".auth-login-config.json"
    atomic_write(
        temporary_config,
        json.dumps(config, indent=2) + "\n",
        0o600,
        service.pw_uid,
        service.pw_gid,
    )
    command = [
        "runuser",
        "-u",
        SERVICE_USER,
        "--",
        "env",
        f"HOME={state_dir}",
        f"PICOCLAW_HOME={state_dir}",
        f"PICOCLAW_CONFIG={temporary_config}",
        "/usr/bin/picoclaw",
        "auth",
        "login",
        "--provider",
        provider,
    ]
    command.append("--device-code" if provider == "openai" else "--setup-token")
    try:
        subprocess.run(command, check=True)
    finally:
        temporary_config.unlink(missing_ok=True)


def atomic_write(path: pathlib.Path, data: str, mode: int, uid: int, gid: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o750)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        os.fchmod(fd, mode)
        os.fchown(fd, uid, gid)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_name, path)
    except BaseException:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass
        raise


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    if os.geteuid() != 0:
        print("Run with sudo so credentials can be written with restricted ownership.", file=sys.stderr)
        return 1

    config_path = args.config_dir / "config.json"
    security_path = args.config_dir / ".security.yml"
    if not args.force and (config_path.exists() or security_path.exists()):
        print("Configuration already exists; inspect it, then re-run with --force to replace it.", file=sys.stderr)
        return 1

    try:
        if args.provider == "litellm" and args.from_env and not args.api_base:
            args.api_base = os.environ.get("LITELLM_API_BASE")
        config = build_config(args)
        selected_provider = PROVIDERS[args.provider]
        api_key = None
        if not selected_provider.get("oauth"):
            api_key = obtain_secret(
                file_path=args.api_key_file,
                from_env=args.from_env,
                env_name=selected_provider["env"],
                prompt=selected_provider["prompt"],
                label="api_key",
            )
        elif args.api_key_file or args.from_env:
            raise ValueError("OAuth providers do not accept --api-key-file or --from-env")
        telegram_token = None
        if not args.disable_telegram:
            telegram_token = obtain_secret(
                file_path=args.telegram_token_file,
                from_env=args.from_env,
                env_name="TELEGRAM_BOT_TOKEN",
                prompt="Telegram bot token: ",
                label="telegram_token",
            )
        discord_token = None
        if args.enable_discord:
            discord_token = obtain_secret(
                file_path=args.discord_token_file,
                from_env=args.from_env,
                env_name="DISCORD_BOT_TOKEN",
                prompt="Discord bot token: ",
                label="discord_token",
            )
        security = build_security(api_key, telegram_token, discord_token)
    except (OSError, ValueError) as exc:
        print(f"Configuration error: {exc}", file=sys.stderr)
        return 2

    service = pwd.getpwnam(SERVICE_USER)
    group = grp.getgrnam(SERVICE_GROUP)
    workspace_group = grp.getgrnam("cdmx-workspace")
    args.config_dir.mkdir(parents=True, exist_ok=True, mode=0o750)
    os.chown(args.config_dir, 0, group.gr_gid)
    os.chmod(args.config_dir, 0o750)
    (args.state_dir / "workspace").mkdir(parents=True, exist_ok=True, mode=0o750)
    # cdmx needs traverse-only access to the parent so its desktop can enter
    # the group-writable workspace, without exposing other agent state.
    os.chown(args.state_dir, service.pw_uid, workspace_group.gr_gid)
    os.chmod(args.state_dir, 0o710)
    os.chown(args.state_dir / "workspace", service.pw_uid, workspace_group.gr_gid)
    os.chmod(args.state_dir / "workspace", 0o2770)
    atomic_write(config_path, json.dumps(config, indent=2) + "\n", 0o640, 0, group.gr_gid)
    atomic_write(security_path, security, 0o640, 0, group.gr_gid)

    try:
        if selected_provider.get("oauth"):
            run_oauth_login(selected_provider["oauth"], config, args.state_dir)
        if not args.no_start:
            subprocess.run(
                ["systemctl", "enable", "--now", "cdmx-picoclaw.service"],
                check=True,
            )
    except subprocess.CalledProcessError as exc:
        print(f"Authentication/service error: {exc}", file=sys.stderr)
        return 3

    print(f"Configured {args.provider} with {len(args.telegram_user)} Telegram and {len(args.discord_user)} Discord users.")
    print("Secrets were written only to /etc/cdmx-picoclaw/.security.yml (root:cdmx-agent, mode 0640).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
