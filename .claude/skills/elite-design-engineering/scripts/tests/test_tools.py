"""Tests for the elite-design-engineering scripts (stdlib unittest; run from the repo root:
python3 -m unittest discover -s .claude/skills/elite-design-engineering/scripts/tests).

They use small generated images and temporary directories only, plus visual_diff.py from
pixel-perfect-ui-workflow to prove the triage reads its real output (including a deliberately
introduced layout defect)."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
SCRIPTS = HERE.parent
VISUAL_DIFF = SCRIPTS.parents[1] / "pixel-perfect-ui-workflow" / "scripts" / "visual_diff.py"
THRESHOLDS = SCRIPTS.parents[1] / "pixel-perfect-ui-workflow" / "templates" / "thresholds.json"
sys.path.insert(0, str(SCRIPTS))

import detect_stack  # noqa: E402
import split_composite  # noqa: E402
import triage_diff  # noqa: E402


def run(script: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(script), *args], capture_output=True, text=True)


def phone(w: int, h: int, accent: tuple[int, int, int]) -> Image.Image:
    """A fake screen: white body, coloured header, a few content rows."""
    im = Image.new("RGB", (w, h), (255, 255, 255))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, w - 1, 40), fill=accent)
    for y in range(70, h - 60, 50):
        d.rectangle((16, y, w - 16, y + 24), fill=(60, 60, 60))
    d.rectangle((0, h - 50, w - 1, h - 1), fill=(20, 20, 20))
    return im


def screen_image(shift_card: int = 0) -> Image.Image:
    """A deterministic app-like screen; shift_card moves one card down (a layout defect)."""
    im = Image.new("RGB", (390, 844), (245, 245, 247))
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 389, 96), fill=(229, 9, 20))
    for i, y in enumerate((130, 330, 530)):
        dy = shift_card if i == 1 else 0
        d.rounded_rectangle((16, y + dy, 373, y + dy + 170), radius=12, fill=(255, 255, 255),
                            outline=(220, 220, 225))
        d.rectangle((32, y + dy + 24, 200, y + dy + 44), fill=(30, 30, 30))
        d.rectangle((32, y + dy + 60, 340, y + dy + 76), fill=(120, 120, 120))
    d.rectangle((0, 780, 389, 843), fill=(15, 15, 15))
    return im


class SplitCompositeTest(unittest.TestCase):
    def test_finds_each_screen_on_a_board_with_shadows(self):
        board = Image.new("RGB", (900, 700), (250, 250, 250))
        shadow = Image.new("RGB", (900, 700), (250, 250, 250))
        sd = ImageDraw.Draw(shadow)
        boxes = [(60, 50, 330, 640), (420, 60, 690, 620)]
        for x0, y0, x1, y1 in boxes:  # soft halo, gradually darker towards the screen
            for k in range(14, 0, -1):
                g = 250 - (15 - k) * 3
                sd.rectangle((x0 - k, y0 - k, x1 + k, y1 + k), fill=(g, g, g))
        board.paste(shadow)
        for (x0, y0, x1, y1), accent in zip(boxes, [(229, 9, 20), (20, 120, 220)]):
            board.paste(phone(x1 - x0, y1 - y0, accent), (x0, y0))
        with tempfile.TemporaryDirectory() as t:
            src = Path(t) / "board.png"
            board.save(src)
            res = run(SCRIPTS / "split_composite.py", str(src), "--out", t)
            self.assertEqual(res.returncode, 0, res.stderr)
            report = json.loads(res.stdout)
            got = [(s["box"]["x"], s["box"]["y"], s["box"]["x"] + s["box"]["w"], s["box"]["y"] + s["box"]["h"])
                   for s in report["screens"]]
            self.assertEqual(len(got), 2)
            for g, e in zip(got, boxes):
                for a, b in zip(g, e):
                    self.assertLessEqual(abs(a - b), 2, (g, e))
            self.assertTrue((Path(t) / "screen_2.png").is_file())
            self.assertIn("393", report["screens"][0]["dpr_if_logical_width"])

    def test_single_full_bleed_screen_and_empty_image(self):
        with tempfile.TemporaryDirectory() as t:
            blank = Path(t) / "blank.png"
            Image.new("RGB", (400, 400), (255, 255, 255)).save(blank)
            self.assertEqual(run(SCRIPTS / "split_composite.py", str(blank)).returncode, 3)
            self.assertEqual(run(SCRIPTS / "split_composite.py", str(Path(t) / "missing.png")).returncode, 2)


class DetectStackTest(unittest.TestCase):
    def test_flutter_app_conventions(self):
        with tempfile.TemporaryDirectory() as t:
            app = Path(t) / "apps" / "mobile"
            (app / "lib" / "design_system" / "tokens").mkdir(parents=True)
            (app / "lib" / "core" / "network").mkdir(parents=True)
            (app / "lib" / "l10n").mkdir(parents=True)
            (app / "pubspec.yaml").write_text(
                "name: x\nenvironment:\n  sdk: ^3.9.0\ndependencies:\n  flutter:\n    sdk: flutter\n"
                "  go_router: ^1.0.0\n  flutter_riverpod: ^3.0.0\n  flutter_svg: ^2.0.0\n"
                "flutter:\n  generate: true\n  assets:\n    - assets/icons/\n  fonts:\n    - family: Inter\n")
            (app / "lib" / "design_system" / "tokens" / "tokens.dart").write_text("class K {}\n")
            (app / "lib" / "core" / "network" / "auth_tokens.dart").write_text("class A {}\n")
            (app / "lib" / "l10n" / "app_ar.arb").write_text("{}")
            (app / "lib" / "l10n" / "app_en.arb").write_text("{}")
            (app / "lib" / "main.dart").write_text("final x = NetworkImage('u'); // kReleaseMode\n")
            out = run(SCRIPTS / "detect_stack.py", t)
            self.assertEqual(out.returncode, 0, out.stderr)
            data = json.loads(out.stdout)
            a = data["apps"][0]
            self.assertEqual(a["framework"], "flutter")
            c = a["conventions"]
            self.assertEqual(c["router"], "go_router")
            self.assertEqual(c["state"], "flutter_riverpod")
            self.assertTrue(c["localization"]["gen_l10n"])
            self.assertEqual(c["rtl_locales"], ["ar"])
            self.assertEqual(c["design_tokens"], ["apps/mobile/lib/design_system/tokens/tokens.dart"])
            self.assertEqual(c["bundled_fonts"], ["Inter"])
            self.assertEqual(c["asset_dirs"], ["assets/icons/"])
            self.assertTrue(c["svg"])
            self.assertEqual(c["network_images_in_lib"], 1)
            self.assertTrue(any("web/" in w for w in data["warnings"]))

    def test_next_app_and_nothing_found(self):
        with tempfile.TemporaryDirectory() as t:
            (Path(t) / "web").mkdir()
            (Path(t) / "web" / "package.json").write_text(json.dumps({
                "dependencies": {"next": "15.0.0", "react": "19.0.0", "next-intl": "3", "zustand": "4"},
                "devDependencies": {"tailwindcss": "4", "@playwright/test": "1"},
                "scripts": {"dev": "next dev"}}))
            data = json.loads(run(SCRIPTS / "detect_stack.py", t).stdout)
            a = data["apps"][0]
            self.assertEqual(a["framework"], "next")
            self.assertEqual(a["conventions"]["localization"], "next-intl")
            self.assertEqual(a["conventions"]["state"], "zustand")
            self.assertIn("tailwindcss", a["conventions"]["styling"])
            self.assertIn("@playwright/test", a["conventions"]["visual_tests"])
        with tempfile.TemporaryDirectory() as t:
            self.assertEqual(run(SCRIPTS / "detect_stack.py", t).returncode, 3)


@unittest.skipUnless(VISUAL_DIFF.is_file(), "pixel-perfect-ui-workflow/scripts/visual_diff.py not present")
class TriageAgainstVisualDiffTest(unittest.TestCase):
    """End-to-end on visual_diff.py output: identical renders pass; a deliberately introduced
    layout defect (one card moved 24 px down) fails and is located and ranked first."""

    def diff(self, t: Path, ref: Image.Image, out: Image.Image, profile: str) -> Path:
        ref.save(t / "ref.png")
        out.save(t / "out.png")
        res = run(VISUAL_DIFF, "--reference", str(t / "ref.png"), "--output", str(t / "out.png"),
                  "--out", str(t / profile), "--dpr", "1", "--criteria", str(THRESHOLDS),
                  "--profile", profile, "--shift-search", "4")
        self.assertIn(res.returncode, (0, 1), res.stderr)
        return t / profile / "metrics.json"

    def test_identical_passes_controlled(self):
        with tempfile.TemporaryDirectory() as t:
            m = self.diff(Path(t), screen_image(), screen_image(), "controlled")
            r = triage_diff.triage(m, 8)
            self.assertEqual(r["status"], "PASSED")
            self.assertEqual(r["defects"], [])

    def test_introduced_layout_defect_is_found(self):
        with tempfile.TemporaryDirectory() as t:
            m = self.diff(Path(t), screen_image(), screen_image(shift_card=24), "controlled")
            r = triage_diff.triage(m, 8)
            self.assertEqual(r["status"], "FAILED")
            self.assertTrue(r["defects"])
            top = r["defects"][0]
            self.assertIn(top["severity"], ("critical", "major"))
            x, y, w, h = top["box_logical"]
            # The moved card spans y 330..524 logical; the defect must overlap it.
            self.assertLess(y, 524)
            self.assertGreater(y + h, 330)
            self.assertEqual(run(SCRIPTS / "triage_diff.py", str(m)).returncode, 1)

    def test_advisory_profile_is_never_a_plain_pass(self):
        with tempfile.TemporaryDirectory() as t:
            m = self.diff(Path(t), screen_image(), screen_image(shift_card=2), "cross_environment")
            r = triage_diff.triage(m, 8)
            self.assertIn(r["status"], ("ADVISORY_PASS", "ADVISORY_FAIL"))
            self.assertNotEqual(r["status"], "PASSED")

    def test_no_criteria_is_not_run(self):
        with tempfile.TemporaryDirectory() as t:
            tp = Path(t)
            screen_image().save(tp / "a.png")
            run(VISUAL_DIFF, "--reference", str(tp / "a.png"), "--output", str(tp / "a.png"), "--out", str(tp / "d"))
            r = triage_diff.triage(tp / "d" / "metrics.json", 8)
            self.assertEqual(r["status"], "NOT_RUN")
            self.assertEqual(run(SCRIPTS / "triage_diff.py", str(tp / "d" / "metrics.json")).returncode, 1)

    def test_rejects_non_metrics_file(self):
        with tempfile.TemporaryDirectory() as t:
            bad = Path(t) / "x.json"
            bad.write_text("{}")
            self.assertEqual(run(SCRIPTS / "triage_diff.py", str(bad)).returncode, 2)


if __name__ == "__main__":
    unittest.main()
