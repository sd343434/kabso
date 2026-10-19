"""Regression tests for visual_diff.py acceptance criteria (fail closed; defect D1).

Run from the repo root:
  python3 -m unittest discover -s .claude/skills/pixel-perfect-ui-workflow/scripts/tests -v
"""
from __future__ import annotations

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


class CriteriaTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        d = Path(cls.tmp.name)
        ref = np.full((60, 40, 3), 255, np.uint8)
        same = ref.copy()
        diff = ref.copy()
        diff[10:20, 10:30] = 0  # 8.3 % of the pixels fully changed
        cls.ref, cls.same, cls.diff = d / "ref.png", d / "same.png", d / "diff.png"
        Image.fromarray(ref).save(cls.ref)
        Image.fromarray(same).save(cls.same)
        Image.fromarray(diff).save(cls.diff)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tmp.cleanup()

    def criteria(self, obj) -> Path:
        p = Path(self.tmp.name) / f"c{self.id().split('.')[-1]}.json"
        p.write_text(obj if isinstance(obj, str) else json.dumps(obj))
        return p

    def run_vd(self, output: Path, *args: str) -> tuple[int, str, dict | None]:
        out = Path(self.tmp.name) / ("o_" + self.id().split(".")[-1])
        r = subprocess.run(
            [sys.executable, "-I", str(VISUAL_DIFF), "--reference", str(self.ref), "--output", str(output), "--out", str(out), *args],
            capture_output=True,
            text=True,
            check=False,
        )
        metrics = out / "metrics.json"
        return r.returncode, r.stdout + r.stderr, json.loads(metrics.read_text()) if metrics.exists() else None

    # --- the original defect: a nested thresholds file evaluated zero checks and passed -------------
    def test_nested_file_without_profile_is_rejected(self):
        code, log, metrics = self.run_vd(self.diff, "--criteria", str(THRESHOLDS))
        self.assertEqual(code, 2, log)
        self.assertIn("--profile", log)
        self.assertIsNone(metrics, "an invalid run must not write metrics")

    def test_nested_file_with_profile_runs_every_check(self):
        code, log, m = self.run_vd(self.diff, "--criteria", str(THRESHOLDS), "--profile", "controlled")
        self.assertEqual(code, 1, log)  # 8.3 % of pixels changed cannot pass "controlled"
        v = m["verdict"]
        self.assertEqual(v["profile"], "controlled")
        self.assertEqual(v["checks_run"], 6)  # mae, ssim, changed@16, changed@32, region, masked
        self.assertEqual(v["not_run"], [])
        self.assertFalse(v["pass"])

    def test_identical_images_pass_with_checks_reported(self):
        code, log, m = self.run_vd(self.same, "--criteria", str(THRESHOLDS), "--profile", "controlled")
        self.assertEqual(code, 0, log)
        self.assertTrue(m["verdict"]["pass"])
        self.assertGreater(m["verdict"]["checks_run"], 0)
        self.assertTrue(all(c["pass"] for c in m["verdict"]["checks"]))

    def test_unknown_profile_is_rejected(self):
        code, log, _ = self.run_vd(self.diff, "--criteria", str(THRESHOLDS), "--profile", "lenient")
        self.assertEqual(code, 2, log)
        self.assertIn("unknown profile", log)

    def test_profile_mismatch_on_flat_file_is_rejected(self):
        c = self.criteria({"profile": "controlled", "max_mae": 1.0})
        code, log, _ = self.run_vd(self.diff, "--criteria", str(c), "--profile", "cross_environment")
        self.assertEqual(code, 2, log)

    # --- missing / malformed / empty --------------------------------------------------------------------
    def test_missing_file_is_rejected(self):
        code, log, _ = self.run_vd(self.diff, "--criteria", str(Path(self.tmp.name) / "nope.json"))
        self.assertEqual(code, 2, log)
        self.assertIn("not found", log)

    def test_malformed_json_is_rejected(self):
        code, log, _ = self.run_vd(self.diff, "--criteria", str(self.criteria("{max_mae: 1")))
        self.assertEqual(code, 2, log)
        self.assertIn("not valid JSON", log)

    def test_non_object_is_rejected(self):
        code, log, _ = self.run_vd(self.diff, "--criteria", str(self.criteria([1, 2])))
        self.assertEqual(code, 2, log)

    def test_empty_object_is_rejected(self):
        code, log, _ = self.run_vd(self.diff, "--criteria", str(self.criteria({})))
        self.assertEqual(code, 2, log)
        self.assertIn("no checks configured", log)

    def test_only_metadata_is_rejected(self):
        c = self.criteria({"profile": "x", "$comment": "nothing to check"})
        code, log, _ = self.run_vd(self.diff, "--criteria", str(c))
        self.assertEqual(code, 2, log)
        self.assertIn("no checks configured", log)

    def test_empty_profiles_object_is_rejected(self):
        code, log, _ = self.run_vd(self.diff, "--criteria", str(self.criteria({"profiles": {}})), "--profile", "x")
        self.assertEqual(code, 2, log)

    def test_empty_changed_pct_is_rejected(self):
        code, log, _ = self.run_vd(self.diff, "--criteria", str(self.criteria({"max_mae": 1, "max_changed_pct": {}})))
        self.assertEqual(code, 2, log)

    # --- unrecognised keys / invalid values --------------------------------------------------------------
    def test_misspelt_key_is_rejected(self):
        code, log, _ = self.run_vd(self.diff, "--criteria", str(self.criteria({"max_mea": 1})))
        self.assertEqual(code, 2, log)
        self.assertIn("unrecognised criteria keys", log)

    def test_invalid_values_are_rejected(self):
        for bad in (
            {"max_mae": "high"},
            {"max_mae": True},
            {"max_mae": -1},
            {"min_ssim": 1.5},
            {"max_masked_pixel_pct": 101},
            {"max_region_mae": None},
            {"max_changed_pct": {"32": "x"}},
            {"max_changed_pct": {"abc": 1}},
            {"max_changed_pct": [1, 2]},
        ):
            with self.subTest(bad=bad):
                code, log, _ = self.run_vd(self.diff, "--criteria", str(self.criteria(bad)))
                self.assertEqual(code, 2, f"{bad}: {log}")
                self.assertIn("invalid criteria", log)
                self.assertNotIn("Traceback", log)

    def test_threshold_not_computed_is_rejected(self):
        c = self.criteria({"max_changed_pct": {"48": 1}})
        code, log, _ = self.run_vd(self.diff, "--criteria", str(c))
        self.assertEqual(code, 2, log)
        self.assertIn("not computed", log)

    def test_profile_without_criteria_is_rejected(self):
        code, log, _ = self.run_vd(self.diff, "--profile", "controlled")
        self.assertEqual(code, 2, log)

    # --- checks that cannot run fail the verdict ---------------------------------------------------------
    def test_everything_masked_fails_closed(self):
        c = self.criteria({"max_mae": 255, "min_ssim": -1, "max_changed_pct": {"32": 100}, "max_region_mae": 255})
        code, log, m = self.run_vd(self.diff, "--criteria", str(c), "--mask", "0,0,40,60:test: everything")
        self.assertEqual(code, 1, log)
        v = m["verdict"]
        self.assertFalse(v["pass"])
        self.assertEqual(v["checks_run"], 0)
        self.assertEqual({n["check"] for n in v["not_run"]}, {"max_mae", "min_ssim", "max_changed_pct[32]", "max_region_mae"})

    def test_report_lists_run_and_unconfigured_checks(self):
        code, log, m = self.run_vd(self.diff, "--criteria", str(self.criteria({"max_mae": 50})))
        self.assertEqual(code, 0, log)
        v = m["verdict"]
        self.assertEqual([c["check"] for c in v["checks"]], ["mae <= max_mae"])
        self.assertEqual(v["not_configured"], ["min_ssim", "max_changed_pct", "max_region_mae", "max_masked_pixel_pct"])

    def test_flat_single_profile_still_supported(self):
        flat = json.loads(THRESHOLDS.read_text())["profiles"]["cross_environment"]
        code, log, m = self.run_vd(self.same, "--criteria", str(self.criteria(flat)))
        self.assertEqual(code, 0, log)
        self.assertEqual(m["verdict"]["profile"], "cross_environment")
        self.assertEqual(m["verdict"]["checks_run"], 6)


    # --- C: cross_environment is advisory until calibrated on two real environments ------------------
    def test_cross_environment_verdict_is_marked_advisory(self):
        code, log, m = self.run_vd(self.same, "--criteria", str(THRESHOLDS), "--profile", "cross_environment")
        self.assertEqual(code, 0, log)  # exit codes are unchanged; the marking is the signal
        self.assertTrue(m["verdict"]["advisory"])
        self.assertIn("never a release gate", m["verdict"]["advisory_reason"])
        self.assertIn("ADVISORY profile 'cross_environment'", log)
        self.assertTrue(json.loads(log.splitlines()[0])["verdict"]["advisory"])

    def test_flat_cross_environment_file_is_also_advisory(self):
        flat = json.loads(THRESHOLDS.read_text())["profiles"]["cross_environment"]
        _, _, m = self.run_vd(self.same, "--criteria", str(self.criteria(flat)))
        self.assertTrue(m["verdict"]["advisory"])

    def test_controlled_verdict_is_not_advisory(self):
        _, log, m = self.run_vd(self.same, "--criteria", str(THRESHOLDS), "--profile", "controlled")
        self.assertFalse(m["verdict"]["advisory"])
        self.assertIsNone(m["verdict"]["advisory_reason"])
        self.assertNotIn("ADVISORY", log)


class ThresholdsUnchangedTest(unittest.TestCase):
    """Guards against loosening the shipped acceptance profiles to force a pass."""

    def test_profiles_keep_their_values(self):
        p = json.loads(THRESHOLDS.read_text())["profiles"]
        self.assertEqual(
            {k: v for k, v in p["controlled"].items() if not k.startswith("$")},
            {"profile": "controlled", "max_mae": 1.0, "min_ssim": 0.995, "max_changed_pct": {"16": 0.5, "32": 0.1}, "max_region_mae": 4.0, "max_masked_pixel_pct": 5.0},
        )
        self.assertEqual(
            {k: v for k, v in p["cross_environment"].items() if not k.startswith("$")},
            {"profile": "cross_environment", "max_mae": 18.0, "min_ssim": 0.8, "max_changed_pct": {"32": 25.0, "64": 10.0}, "max_region_mae": 45.0, "max_masked_pixel_pct": 10.0},
        )


if __name__ == "__main__":
    unittest.main()
