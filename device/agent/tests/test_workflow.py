import json
import pathlib
import unittest


ROOT = pathlib.Path(__file__).parents[3]
AGENT = ROOT / "device" / "agent"


class NativePicoClawWorkflowTests(unittest.TestCase):
    def test_workshop_material_is_visible_at_repository_root(self):
        skills = sorted(
            path.parent.name for path in (ROOT / "skills").glob("*/SKILL.md")
        )
        self.assertEqual(skills, ["coding", "color-sensor", "led"])
        self.assertTrue((ROOT / "tools" / "cdmx_hardware.py").is_file())
        self.assertFalse((AGENT / "workspace" / "skills").exists())
        self.assertFalse((AGENT / "workspace" / "tools").exists())

    def test_example_uses_native_v3_schema_without_secrets(self):
        config = json.loads(
            (AGENT / "examples" / "config.telegram.json").read_text(
                encoding="utf-8"
            )
        )
        defaults = config["agents"]["defaults"]
        self.assertEqual(config["version"], 3)
        self.assertEqual(defaults["workspace"], "/home/cdmx/workspace")
        self.assertTrue(defaults["restrict_to_workspace"])
        self.assertEqual(config["model_list"][0]["provider"], "openrouter")
        self.assertNotIn("api_keys", config["model_list"][0])
        telegram = config["channel_list"]["telegram"]
        self.assertEqual(telegram["type"], "telegram")
        self.assertNotIn("token", telegram.get("settings", {}))

    def test_security_example_uses_picoclaw_overlay_keys(self):
        security = (
            AGENT / "examples" / "security.telegram.example.yml"
        ).read_text(encoding="utf-8")
        self.assertIn("model_list:\n  workshop:\n    api_keys:", security)
        self.assertIn("channels:\n  telegram:\n    token:", security)
        self.assertNotIn("sk-", security)

    def test_docs_use_native_cli_and_not_the_removed_wrapper(self):
        for filename in ("README.md", "README.en.md"):
            documentation = (ROOT / filename).read_text(encoding="utf-8")
            self.assertIn("picoclaw version", documentation)
            self.assertIn("picoclaw onboard", documentation)
            self.assertIn("picoclaw agent", documentation)
            self.assertIn("picoclaw gateway", documentation)
            self.assertIn("picoclaw skills install", documentation)
            self.assertIn("npx skills add", documentation)
            self.assertIn("for skill in coding color-sensor led", documentation)
            self.assertIn("--skill '*'", documentation)
            self.assertIn("~/.picoclaw/config.json", documentation)
            self.assertNotIn("cdmx-agent-setup", documentation)

    def test_image_installer_does_not_preload_skills_or_tools(self):
        installer = (AGENT / "install-agent.sh").read_text(encoding="utf-8")
        self.assertNotIn("setup.py", installer)
        self.assertNotIn("cdmx-picoclaw.service", installer)
        self.assertNotIn("cdmx-agent-setup", installer)
        self.assertNotIn("repo_root", installer)
        self.assertNotIn("SKILL.md", installer)
        self.assertNotIn("cdmx_hardware.py", installer)
        self.assertIn("skills and tools are not preinstalled", installer)
        self.assertIn('echo "Each team configures its own gateway', installer)


if __name__ == "__main__":
    unittest.main()
