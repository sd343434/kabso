"""Regression tests for capture_web.mjs resource cleanup (D6).

Each run must exit on its own (no external timeout) and leave no headless Chromium processes behind,
on success and on failure. Requires node + Playwright + the preinstalled Chromium; skipped otherwise.

Run from the repo root:
  python3 -m unittest discover -s .claude/skills/pixel-perfect-ui-workflow/scripts/tests -v
"""
from __future__ import annotations

import http.server
import json
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import unittest
from functools import partial
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parents[1]
CAPTURE = SCRIPTS / "capture_web.mjs"
PLAYWRIGHT = Path("/opt/node-tools/node_modules/playwright")
BROWSERS = "/opt/pw-browsers"
RUN_LIMIT_S = 60  # a hung process fails the test instead of being waited for


def browser_pids() -> set[int]:
    out = subprocess.run(["pgrep", "-f", BROWSERS], capture_output=True, text=True, check=False).stdout
    return {int(p) for p in out.split()}


def free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@unittest.skipUnless(shutil.which("node") and PLAYWRIGHT.exists() and Path(BROWSERS).exists(), "node/Playwright/Chromium not available")
class CaptureLifecycleTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.TemporaryDirectory()
        site = Path(cls.tmp.name) / "site"
        site.mkdir()
        (site / "index.html").write_text("<!doctype html><body style='margin:0;background:#c8080f'><h1>capture test</h1></body>")
        handler = partial(http.server.SimpleHTTPRequestHandler, directory=str(site))
        handler.log_message = lambda *a, **k: None
        cls.port = free_port()
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", cls.port), handler)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.tmp.cleanup()

    def capture(self, *args: str) -> tuple[subprocess.CompletedProcess, float]:
        before = browser_pids()
        t0 = time.monotonic()
        try:
            r = subprocess.run(["node", str(CAPTURE), *args], capture_output=True, text=True, timeout=RUN_LIMIT_S, check=False)
        except subprocess.TimeoutExpired:
            self.fail(f"capture_web.mjs did not exit within {RUN_LIMIT_S}s: {args}")
        elapsed = time.monotonic() - t0
        time.sleep(0.5)
        leaked = browser_pids() - before
        self.assertEqual(leaked, set(), f"browser processes left running: {leaked}")
        return r, elapsed

    def out(self, name: str) -> Path:
        return Path(self.tmp.name) / name

    def test_success_exits_and_closes_the_browser(self):
        r, _ = self.capture("--url", f"http://127.0.0.1:{self.port}/", "--out", str(self.out("ok.png")), "--dpr", "1", "--wait", "200")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(self.out("ok.png").exists())
        info = json.loads(r.stdout.strip().splitlines()[-1])
        self.assertEqual(info["viewport"], {"width": 393, "height": 852})

    def test_persistent_profile_success_exits_and_closes(self):
        profile = Path(self.tmp.name) / "profile"
        r, _ = self.capture("--url", f"http://127.0.0.1:{self.port}/", "--out", str(self.out("p.png")), "--dpr", "1", "--wait", "200", "--profile-dir", str(profile))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(self.out("p.png").exists())

    def test_navigation_failure_exits_1_and_closes(self):
        dead = free_port()  # nothing listens here
        r, _ = self.capture("--url", f"http://127.0.0.1:{dead}/", "--out", str(self.out("fail.png")), "--dpr", "1", "--wait", "200")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertIn('"error"', r.stderr)
        self.assertFalse(self.out("fail.png").exists())

    def test_held_document_times_out_exits_1_and_closes(self):
        r, elapsed = self.capture("--url", f"http://127.0.0.1:{self.port}/", "--out", str(self.out("hold.png")), "--dpr", "1",
                                  "--hold", f"127.0.0.1:{self.port}/", "--nav-timeout", "2000")
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)
        self.assertLess(elapsed, RUN_LIMIT_S)

    def test_usage_error_exits_2_without_launching(self):
        r, _ = self.capture("--url", f"http://127.0.0.1:{self.port}/")
        self.assertEqual(r.returncode, 2, r.stderr)


if __name__ == "__main__":
    unittest.main()
