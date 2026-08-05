from __future__ import annotations

import importlib.util
from pathlib import Path
import tempfile
import unittest


MODULE_PATH = Path(__file__).parents[1] / "host" / "imager_app.py"
SPEC = importlib.util.spec_from_file_location("imager_app", MODULE_PATH)
assert SPEC and SPEC.loader
imager = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(imager)


REMOVABLE_SD = """
   Device Identifier:         disk10
   Device Node:               /dev/disk10
   Whole:                     Yes
   Device / Media Name:       Built In SDXC Reader
   Protocol:                  Secure Digital
   Disk Size:                 15.6 GB (15635841024 Bytes)
   Device Location:           Internal
   Removable Media:           Removable
"""

FIXED_INTERNAL = """
   Device Identifier:         disk0
   Whole:                     Yes
   Protocol:                  Apple Fabric
   Disk Size:                 1.0 TB (1000555581440 Bytes)
   Device Location:           Internal
   Removable Media:           Fixed
"""


class ImagerTests(unittest.TestCase):
    def test_team_range_and_admin_identity(self):
        self.assertEqual(imager.validate_team(0), 0)
        self.assertEqual(imager.validate_team(9), 9)
        self.assertEqual(imager.validate_team("admin"), "admin")
        self.assertEqual(imager.identity_name("admin"), "admin")
        self.assertEqual(imager.identity_name(4), "equipo4")
        for invalid in (-1, 10, "0", True, None):
            with self.assertRaises(ValueError):
                imager.validate_team(invalid)

    def test_raw_disk_path_has_no_shell_escapes(self):
        self.assertEqual(imager.raw_disk_path("/dev/disk10"), "/dev/rdisk10")
        with self.assertRaises(ValueError):
            imager.raw_disk_path("/dev/disk10s1")

    def test_builtin_sd_reader_is_safe_but_fixed_disk_is_not(self):
        sd = imager.parse_diskutil_info(REMOVABLE_SD)
        fixed = imager.parse_diskutil_info(FIXED_INTERNAL)
        self.assertTrue(imager.disk_is_safe("/dev/disk10", sd))
        self.assertFalse(imager.disk_is_safe("/dev/disk0", fixed))
        self.assertEqual(imager.disk_size(sd), 15_635_841_024)

    def test_env_parser_does_not_execute_shell(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "image.env"
            path.write_text("# note\nNAME=image.xz\nVALUE='quoted'\n", encoding="utf-8")
            self.assertEqual(
                imager.parse_env(path), {"NAME": "image.xz", "VALUE": "quoted"}
            )

    def test_ui_has_all_teams_and_progress_semantics(self):
        html = imager.UI_PATH.read_text(encoding="utf-8")
        self.assertIn("role=\"progressbar\"", html)
        self.assertIn("'admin'", html)
        self.assertIn("IDENTITIES", html)
        self.assertIn("__CDMX_TOKEN__", html)
        self.assertNotIn("/api/repair", html)

    def test_job_reservation_is_atomic(self):
        state = imager.JobState()
        self.assertTrue(state.reserve())
        self.assertFalse(state.reserve())
        state.update(running=False)
        self.assertTrue(state.reserve())


if __name__ == "__main__":
    unittest.main()
