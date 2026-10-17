"""D5: running the tooling must not leave generated files in the working tree.

Runs visual_diff.py and component_metrics.py (which imports visual_diff.py) the way a developer would,
without -B, then checks that git reports no new untracked file (with -uall, so files inside untracked
directories count) and that Python caches are ignored by the root .gitignore.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

SCRIPTS = Path(__file__).resolve().parents[1]
REPO = Path(subprocess.run(["git", "-C", str(SCRIPTS), "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=False).stdout.strip() or ".")


def untracked() -> set[str]:
    out = subprocess.run(["git", "-C", str(REPO), "status", "--porcelain", "-uall"], capture_output=True, text=True, check=True).stdout
    return {line[3:] for line in out.splitlines() if line.startswith("??")}


@unittest.skipUnless(shutil.which("git") and (REPO / ".git").exists(), "not inside a git checkout")
class GeneratedFilesTest(unittest.TestCase):
    def test_tool_runs_add_no_untracked_files(self):
        # A cache left by an earlier run would already be in `before` and hide a regression.
        shutil.rmtree(SCRIPTS / "__pycache__", ignore_errors=True)
        before = untracked()
        with tempfile.TemporaryDirectory() as tmp:
            t = Path(tmp)
            a = np.full((40, 30, 3), 255, np.uint8)
            b = a.copy()
            b[5:15, 5:20] = 0
            Image.fromarray(a).save(t / "a.png")
            Image.fromarray(b).save(t / "b.png")
            (t / "spec.json").write_text(json.dumps([{"name": "box", "type": "text", "window": [0, 0, 30, 40]}]))
            subprocess.run([sys.executable, str(SCRIPTS / "visual_diff.py"), "--reference", str(t / "a.png"), "--output", str(t / "b.png"), "--out", str(t / "o")], capture_output=True, check=False)
            subprocess.run([sys.executable, str(SCRIPTS / "component_metrics.py"), "--reference", str(t / "a.png"), "--output", str(t / "b.png"), "--spec", str(t / "spec.json"), "--dpr", "1", "--out", str(t / "c.json")], capture_output=True, check=False)
        new = untracked() - before
        self.assertEqual(new, set(), f"tool runs left untracked files: {sorted(new)}")

    def test_python_caches_are_ignored(self):
        for rel in (".claude/skills/pixel-perfect-ui-workflow/scripts/__pycache__/visual_diff.cpython-313.pyc", "any/dir/__pycache__/x.pyc", "tool.pyc"):
            r = subprocess.run(["git", "-C", str(REPO), "check-ignore", "-q", rel], check=False)
            self.assertEqual(r.returncode, 0, f"{rel} is not ignored")


if __name__ == "__main__":
    unittest.main()
