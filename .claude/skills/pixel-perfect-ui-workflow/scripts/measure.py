#!/usr/bin/env python3
"""Measurement helpers for reference screenshots. Every number printed is MEASURED from pixels.

Subcommands (coordinates are in PIXELS unless --dpr is given; then also printed in logical units):
  info     <img> [--logical-width 393]      size, sha256, mode, inferred DPR, alpha present
  sample   <img> x y [x y ...]              exact RGBA at points (and a 3x3 median)
  hline    <img> y [--x0 --x1 --tol 12]     colour runs along a row  -> edges/widths of elements
  vline    <img> x [--y0 --y1 --tol 12]     colour runs along a column -> heights/gaps
  bbox     <img> x y w h --bg "#RRGGBB" [--tol 12]   tight box of non-background pixels inside a rect
  palette  <img> x y w h [--top 8]          dominant colours inside a rect (counts)
  crop     <img> x y w h --out file.png [--scale 4]  zoomed crop for close inspection (nearest-neighbour)

Nothing here estimates typography. Font size/weight must be derived from measured cap/x-height and
glyph stem widths and is then an ESTIMATE; label it so in the spec.
"""
from __future__ import annotations

import argparse
import hashlib
import signal
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image


def load(p: str) -> np.ndarray:
    return np.asarray(Image.open(p).convert("RGBA"), dtype=np.int32)


def hexc(px) -> str:
    r, g, b, a = (int(v) for v in px)
    return f"#{r:02X}{g:02X}{b:02X}" + ("" if a == 255 else f" a={a}")


def lg(v: float, dpr: float | None) -> str:
    return f"{v}px" + (f" ({v / dpr:.2f}lp)" if dpr else "")


def runs(line: np.ndarray, start: int, tol: int, dpr):
    out, s = [], 0
    for i in range(1, len(line) + 1):
        if i == len(line) or np.abs(line[i, :3] - line[s, :3]).max() > tol:
            out.append((start + s, start + i - 1, line[s]))
            s = i
    for a, b, c in out:
        print(f"{lg(a, dpr):>18} .. {lg(b, dpr):<18} len={lg(b - a + 1, dpr):<18} {hexc(c)}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd")
    ap.add_argument("img")
    ap.add_argument("args", nargs="*", type=int)
    ap.add_argument("--dpr", type=float)
    ap.add_argument("--logical-width", type=float)
    ap.add_argument("--tol", type=int, default=12)
    ap.add_argument("--x0", type=int)
    ap.add_argument("--x1", type=int)
    ap.add_argument("--y0", type=int)
    ap.add_argument("--y1", type=int)
    ap.add_argument("--bg")
    ap.add_argument("--top", type=int, default=8)
    ap.add_argument("--out")
    ap.add_argument("--scale", type=int, default=4)
    a = ap.parse_args()
    im = load(a.img)
    h, w, _ = im.shape
    d = a.dpr

    if a.cmd == "info":
        raw = Image.open(a.img)
        print(f"file={a.img}\nsha256={hashlib.sha256(Path(a.img).read_bytes()).hexdigest()}")
        print(f"pixels={w}x{h} mode={raw.mode} alpha={'yes' if (im[..., 3] < 255).any() else 'no'}")
        if a.logical_width:
            dpr = w / a.logical_width
            print(f"inferred_dpr={dpr:.4f} (from logical width {a.logical_width}; VERIFY against the device)")
            print(f"logical_size={a.logical_width}x{h / dpr:.2f}")
    elif a.cmd == "sample":
        pts = a.args
        for i in range(0, len(pts), 2):
            x, y = pts[i], pts[i + 1]
            win = im[max(0, y - 1) : y + 2, max(0, x - 1) : x + 2].reshape(-1, 4)
            med = np.median(win, axis=0)
            print(f"({lg(x, d)}, {lg(y, d)}) exact={hexc(im[y, x])} median3x3={hexc(med)}")
    elif a.cmd == "hline":
        y = a.args[0]
        x0, x1 = a.x0 or 0, a.x1 or w
        runs(im[y, x0:x1], x0, a.tol, d)
    elif a.cmd == "vline":
        x = a.args[0]
        y0, y1 = a.y0 or 0, a.y1 or h
        runs(im[y0:y1, x], y0, a.tol, d)
    elif a.cmd == "bbox":
        x, y, bw, bh = a.args
        if not a.bg:
            raise SystemExit("--bg '#RRGGBB' required")
        bg = np.array([int(a.bg[i : i + 2], 16) for i in (1, 3, 5)])
        reg = im[y : y + bh, x : x + bw, :3]
        fg = np.abs(reg - bg).max(axis=2) > a.tol
        if not fg.any():
            print("no foreground pixels")
            return
        ys, xs = np.where(fg)
        bx0, by0, bx1, by1 = x + xs.min(), y + ys.min(), x + xs.max(), y + ys.max()
        print(f"bbox x={lg(bx0, d)} y={lg(by0, d)} w={lg(bx1 - bx0 + 1, d)} h={lg(by1 - by0 + 1, d)}")
    elif a.cmd == "palette":
        x, y, bw, bh = a.args
        reg = im[y : y + bh, x : x + bw].reshape(-1, 4)
        cnt = Counter(hexc(p) for p in reg)
        for c, n in cnt.most_common(a.top):
            print(f"{c:<16} {n:>8} px  {100 * n / len(reg):6.2f}%")
    elif a.cmd == "crop":
        x, y, bw, bh = a.args
        if not a.out:
            raise SystemExit("--out required")
        c = Image.open(a.img).crop((x, y, x + bw, y + bh))
        c.resize((bw * a.scale, bh * a.scale), Image.NEAREST).save(a.out)
        print(f"wrote {a.out}")
    else:
        raise SystemExit(f"unknown command {a.cmd}")


if __name__ == "__main__":
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)  # quiet when piped to `head`
    main()
