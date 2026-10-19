"""Regression tests for the SSIM methodology of visual_diff.py: border policy (D3) and mask policy (D4).

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
LUMA = np.array([0.299, 0.587, 0.114])

# scikit-image 0.26.0 structural_similarity(gaussian_weights=True, sigma=1.5, use_sample_covariance=False,
# data_range=255) on the luma of the deterministic pair below. Recorded on 2026-10-16; the live comparison test
# re-checks it whenever scikit-image is importable.
SKIMAGE_REFERENCE = 0.638935701787


def _load_vd():
    spec = importlib.util.spec_from_file_location("vd_under_test", VISUAL_DIFF)
    mod = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(mod)
    return mod


def deterministic_pair() -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(20261016)
    a = rng.integers(0, 256, (64, 48, 3)).astype(np.uint8)
    yy, xx = np.mgrid[0:64, 0:48]
    a[..., 1] = (xx * 5) % 256
    b = a.astype(int).copy()
    b[20:40, 10:30] = 255 - b[20:40, 10:30]
    b = np.clip(b + rng.integers(-6, 7, b.shape), 0, 255).astype(np.uint8)
    return a, b


class SsimPolicyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.vd = _load_vd()
        cls.tmp = tempfile.TemporaryDirectory()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.tmp.cleanup()

    def run_vd(self, ref: np.ndarray, out: np.ndarray, *args: str) -> tuple[int, dict | None, str]:
        d = Path(self.tmp.name) / self.id().split(".")[-1]
        d.mkdir(exist_ok=True)
        Image.fromarray(ref).save(d / "ref.png")
        Image.fromarray(out).save(d / "out.png")
        r = subprocess.run(
            [sys.executable, "-I", "-B", str(VISUAL_DIFF), "--reference", str(d / "ref.png"), "--output", str(d / "out.png"), "--out", str(d / "o"), *args],
            capture_output=True, text=True, check=False,
        )
        m = d / "o" / "metrics.json"
        return r.returncode, json.loads(m.read_text()) if m.exists() else None, r.stdout + r.stderr

    def criteria(self, obj: dict) -> str:
        p = Path(self.tmp.name) / f"crit_{self.id().split('.')[-1]}.json"
        p.write_text(json.dumps(obj))
        return str(p)

    # --- D3: methodology and border policy -----------------------------------------------------------
    def test_identical_images_score_one(self):
        a, _ = deterministic_pair()
        _, m, log = self.run_vd(a, a)
        self.assertAlmostEqual(m["overall"]["ssim"], 1.0, places=9, msg=log)

    def test_constant_images_match_the_closed_form(self):
        # Zero variance: SSIM = (2*mu_a*mu_b + C1) / (mu_a^2 + mu_b^2 + C1) exactly.
        a = np.full((40, 40, 3), 100, np.uint8)
        b = np.full((40, 40, 3), 120, np.uint8)
        c1 = (0.01 * 255) ** 2
        expected = (2 * 100 * 120 + c1) / (100**2 + 120**2 + c1)
        _, m, log = self.run_vd(a, b)
        self.assertAlmostEqual(m["overall"]["ssim"], expected, places=6, msg=log)

    def test_matches_recorded_scikit_image_value(self):
        a, b = deterministic_pair()
        _, m, log = self.run_vd(a, b)
        self.assertAlmostEqual(m["overall"]["ssim"], SKIMAGE_REFERENCE, places=6, msg=log)

    def test_matches_live_scikit_image_when_available(self):
        try:
            from skimage.metrics import structural_similarity
        except ImportError:
            self.skipTest("scikit-image not installed (the recorded value is checked by another test)")
        a, b = deterministic_pair()
        expected = structural_similarity(a.astype(float) @ LUMA, b.astype(float) @ LUMA, data_range=255,
                                         gaussian_weights=True, sigma=1.5, use_sample_covariance=False)
        smap, valid = self.vd.ssim_masked(a.astype(float), b.astype(float), np.ones(a.shape[:2], bool))
        self.assertAlmostEqual(float(smap[valid].mean()), expected, places=9)

    def test_border_pixels_are_excluded_from_the_mean(self):
        a, b = deterministic_pair()
        smap, valid = self.vd.ssim_masked(a.astype(float), b.astype(float), np.ones(a.shape[:2], bool))
        border = self.vd.SSIM_BORDER
        self.assertEqual(border, 5)
        self.assertEqual(int(valid.sum()), (64 - 2 * border) * (48 - 2 * border))
        self.assertFalse(valid[:border].any() or valid[-border:].any() or valid[:, :border].any() or valid[:, -border:].any())
        _, m, _ = self.run_vd(a, b)
        self.assertEqual(m["overall"]["ssim_pixels"], int(valid.sum()))
        self.assertEqual(m["overall"]["pixels"], 64 * 48)  # MAE still uses every pixel

    def test_methodology_is_recorded(self):
        a, _ = deterministic_pair()
        _, m, _ = self.run_vd(a, a)
        text = m["methodology"]["ssim"]
        for part in ("11x11", "sigma=1.5", "5 px", "skimage", "Mask policy"):
            self.assertIn(part, text)

    def test_image_too_small_for_ssim_fails_closed(self):
        a = np.full((8, 8, 3), 255, np.uint8)
        code, m, log = self.run_vd(a, a, "--criteria", self.criteria({"max_mae": 1, "min_ssim": 0.99}))
        self.assertEqual(code, 1, log)
        self.assertIsNone(m["overall"]["ssim"])
        self.assertEqual([n["check"] for n in m["verdict"]["not_run"]], ["min_ssim"])
        self.assertFalse(m["verdict"]["pass"])

    # --- D4: masked pixels cannot contaminate valid pixels ---------------------------------------------
    def test_masked_difference_does_not_change_scores(self):
        a, _ = deterministic_pair()
        b = a.copy()
        b[20:40, 15:35] = 255 - b[20:40, 15:35]  # large difference, entirely inside the mask
        code, m, log = self.run_vd(a, b, "--mask", "15,20,20,20:test: masked block",
                                   "--criteria", self.criteria({"max_mae": 0, "min_ssim": 1.0}))
        self.assertEqual(m["overall"]["mae"], 0.0, log)
        self.assertAlmostEqual(m["overall"]["ssim"], 1.0, places=9)
        self.assertEqual(m["overall"]["changed_pct"]["8"], 0.0)
        self.assertEqual(code, 0, log)

    def test_unmasked_difference_next_to_a_mask_is_still_detected(self):
        a, _ = deterministic_pair()
        b = a.copy()
        b[20:40, 15:35] = 255 - b[20:40, 15:35]
        b[20:40, 35:38] = 255 - b[20:40, 35:38]  # 3 px strip just outside the mask
        _, m, log = self.run_vd(a, b, "--mask", "15,20,20,20:test: masked block")
        self.assertGreater(m["overall"]["mae"], 0.0, log)
        self.assertLess(m["overall"]["ssim"], 0.99)

    def test_without_the_fix_the_mask_would_bleed(self):
        # Documents the defect: the raw SSIM map (no neutralisation) is < 1 next to the mask.
        a, _ = deterministic_pair()
        b = a.copy()
        b[20:40, 15:35] = 255 - b[20:40, 15:35]
        keep = np.ones(a.shape[:2], bool)
        keep[20:40, 15:35] = False
        raw = self.vd.ssim_map(a.astype(float), b.astype(float))
        smap, valid = self.vd.ssim_masked(a.astype(float), b.astype(float), keep)
        self.assertLess(float(raw[valid].mean()), 0.99)
        self.assertAlmostEqual(float(smap[valid].mean()), 1.0, places=9)


if __name__ == "__main__":
    unittest.main()
