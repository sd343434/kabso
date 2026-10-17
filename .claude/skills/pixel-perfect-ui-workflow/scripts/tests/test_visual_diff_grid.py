"""EXPERIMENT (claude/kl-054-grid-experiment): cell-size grid for the regional breakdown.

Run from the repo root:
  python3 -m unittest discover -s .claude/skills/pixel-perfect-ui-workflow/scripts/tests -v
"""
from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

SCRIPTS = Path(__file__).resolve().parents[1]
VISUAL_DIFF = SCRIPTS / "visual_diff.py"
THRESHOLDS = SCRIPTS.parent / "templates" / "thresholds.json"


def _load_vd():
    spec = importlib.util.spec_from_file_location("vd_grid_under_test", VISUAL_DIFF)
    mod = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(mod)
    return mod


class GridSpecTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.vd = _load_vd()

    def test_fixed_count(self):
        self.assertEqual(self.vd.parse_grid("4x12", 258, 562, None), (4, 12))

    def test_cell_pixels_round_up(self):
        self.assertEqual(self.vd.parse_grid("cell:32", 258, 562, None), (9, 18))

    def test_cell_logical_uses_dpr(self):
        self.assertEqual(self.vd.parse_grid("cell:16lp", 300, 600, 2.0), (10, 19))

    def test_invalid_specs_are_rejected(self):
        for bad in ("cell:16lp", "cell:0", "cell:abc", "4x0", "4", "x12"):
            with self.assertRaises(ValueError, msg=bad):
                self.vd.parse_grid(bad, 258, 562, None)


class GridDetectionTest(unittest.TestCase):
    """A 14x13 px change (the KL-054 bell-to-share icon swap) in a 258x562 image."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        t = Path(cls.tmp.name)
        a = np.full((562, 258, 3), 255, np.uint8)
        b = a.copy()
        # 14x13 px, delta 50: inside one cell at both 4x12 (64x46 px) and cell:24 (24x24 px).
        b[74:87, 218:232] -= 50
        Image.fromarray(a).save(t / "a.png")
        Image.fromarray(b).save(t / "b.png")

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tmp.cleanup()

    def run_vd(self, *args: str) -> tuple[int, dict]:
        t = Path(self.tmp.name)
        o = t / ("o_" + "_".join(a.replace(":", "") for a in args))
        r = subprocess.run([sys.executable, "-I", "-B", str(VISUAL_DIFF), "--reference", str(t / "a.png"), "--output", str(t / "b.png"),
                            "--out", str(o), "--criteria", str(THRESHOLDS), "--profile", "controlled", *args],
                           capture_output=True, text=True, check=False)
        return r.returncode, json.loads((o / "metrics.json").read_text())

    def test_default_cell_grid_catches_a_small_component(self):
        code, m = self.run_vd()
        self.assertEqual(m["inputs"]["grid"], {"spec": "cell:24", "cols": 11, "rows": 24})
        self.assertEqual(code, 1)
        self.assertGreater(m["worst_regions"][0]["mae"], 4.0)  # controlled max_region_mae

    def test_coarse_grid_is_still_available_and_recorded(self):
        _, m = self.run_vd("--grid", "4x12")
        self.assertEqual(m["inputs"]["grid"], {"spec": "4x12", "cols": 4, "rows": 12})
        self.assertLess(m["worst_regions"][0]["mae"], 4.0)  # averaged away in a 64x46 px cell

    def test_identical_images_pass_at_the_default_grid(self):
        t = Path(self.tmp.name)
        r = subprocess.run([sys.executable, "-I", "-B", str(VISUAL_DIFF), "--reference", str(t / "a.png"), "--output", str(t / "a.png"),
                            "--out", str(t / "same"), "--criteria", str(THRESHOLDS), "--profile", "controlled"],
                           capture_output=True, text=True, check=False)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_invalid_grid_exits_2(self):
        t = Path(self.tmp.name)
        r = subprocess.run([sys.executable, "-I", "-B", str(VISUAL_DIFF), "--reference", str(t / "a.png"), "--output", str(t / "b.png"),
                            "--out", str(t / "bad"), "--grid", "cell:8lp"], capture_output=True, text=True, check=False)
        self.assertEqual(r.returncode, 2)
        self.assertIn("needs --dpr", r.stderr)


if __name__ == "__main__":
    unittest.main()
