import argparse
import importlib.util
import os
import pathlib
import tempfile
import unittest
from types import SimpleNamespace
from unittest import mock


MODULE_PATH = pathlib.Path(__file__).parents[1] / "setup.py"
SPEC = importlib.util.spec_from_file_location("cdmx_agent_setup", MODULE_PATH)
setup = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(setup)


def args(**overrides):
    values = {
        "provider": "openai",
        "model": None,
        "api_base": None,
        "disable_telegram": False,
        "telegram_user": ["123", "456"],
        "enable_discord": False,
        "discord_user": [],
        "state_dir": pathlib.Path("/var/lib/cdmx-picoclaw"),
    }
    values.update(overrides)
    return argparse.Namespace(**values)


class SetupTests(unittest.TestCase):
    def test_v3_config_is_workspace_restricted_and_allowlisted(self):
        cfg = setup.build_config(args())
        self.assertEqual(cfg["version"], 3)
        self.assertTrue(cfg["agents"]["defaults"]["restrict_to_workspace"])
        self.assertFalse(cfg["agents"]["defaults"]["allow_read_outside_workspace"])
        self.assertEqual(cfg["channel_list"]["telegram"]["allow_from"], ["123", "456"])
        self.assertTrue(cfg["tools"]["exec"]["allow_remote"])
        self.assertEqual(cfg["model_list"][0]["model"], "gpt-5.4")

    def test_openrouter_is_the_free_router_default(self):
        cfg = setup.build_config(args(provider="openrouter"))
        self.assertEqual(cfg["model_list"][0]["provider"], "openrouter")
        self.assertEqual(cfg["model_list"][0]["model"], "openrouter/free")

    def test_oauth_config_needs_no_api_key(self):
        cfg = setup.build_config(args(provider="openai-oauth"))
        self.assertEqual(cfg["model_list"][0]["provider"], "openai")
        self.assertEqual(cfg["model_list"][0]["auth_method"], "oauth")
        security = setup.build_security(None, "123:token", None)
        self.assertNotIn("model_list:", security)
        self.assertIn("channel_list:", security)

    def test_litellm_config(self):
        cfg = setup.build_config(
            args(provider="litellm", model="team-model", api_base="https://llm.example/v1")
        )
        self.assertEqual(cfg["model_list"][0]["api_base"], "https://llm.example/v1")

    def test_provider_defaults_and_model_override(self):
        self.assertEqual(
            setup.build_config(args(provider="gemini"))["model_list"][0]["model"],
            "gemini-2.5-flash",
        )
        self.assertEqual(
            setup.build_config(args(provider="moonshot", model="kimi-custom"))["model_list"][0]["model"],
            "kimi-custom",
        )

    def test_empty_or_six_user_allowlist_is_rejected(self):
        with self.assertRaises(ValueError):
            setup.build_config(args(telegram_user=[]))
        with self.assertRaises(ValueError):
            setup.build_config(args(telegram_user=[str(i) for i in range(6)]))

    def test_at_least_one_channel_is_required(self):
        with self.assertRaises(ValueError):
            setup.build_config(args(disable_telegram=True, telegram_user=[]))

    def test_security_uses_v3_nested_settings_and_escapes_values(self):
        data = setup.build_security('key:"x"', "123:token", None)
        self.assertIn('      - "key:\\"x\\""', data)
        self.assertIn("channel_list:\n  telegram:\n    settings:\n      token:", data)
        self.assertNotIn("discord:", data)

    def test_only_loopback_may_use_plain_http(self):
        self.assertEqual(setup.validate_base_url("http://127.0.0.1:4000/v1"), "http://127.0.0.1:4000/v1")
        with self.assertRaises(ValueError):
            setup.validate_base_url("http://llm.example/v1")

    def test_secret_file_must_be_private_regular_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "key"
            path.write_text("not-a-real-key\n", encoding="utf-8")
            os.chmod(path, 0o644)
            with self.assertRaises(ValueError):
                setup.secret_from_file(path, "api_key")
            os.chmod(path, 0o600)
            self.assertEqual(setup.secret_from_file(path, "api_key"), "not-a-real-key")

    def test_oauth_login_runs_as_service_user_with_headless_flow(self):
        with tempfile.TemporaryDirectory() as directory:
            state_dir = pathlib.Path(directory)
            with (
                mock.patch.object(
                    setup.pwd,
                    "getpwnam",
                    return_value=SimpleNamespace(pw_uid=123, pw_gid=456),
                ),
                mock.patch.object(setup, "atomic_write") as write,
                mock.patch.object(setup.subprocess, "run") as run,
            ):
                setup.run_oauth_login("openai", {"version": 3}, state_dir)
            write.assert_called_once()
            command = run.call_args.args[0]
            self.assertIn("PICOCLAW_HOME=" + str(state_dir), command)
            self.assertEqual(command[-3:], ["--provider", "openai", "--device-code"])


if __name__ == "__main__":
    unittest.main()
