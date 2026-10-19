#!/usr/bin/env python3
"""Find the individual app screens inside a composite reference image (marketing collage, design
board, side-by-side mock-ups) so each screen is measured on its own — never the composite as one
screen.

Method (deterministic, every number is MEASURED from pixels):
  1. Background = the most common colour on the image border.
  2. Content mask = pixels whose max-channel difference from the background exceeds --tol.
  3. Candidate screens = runs of content columns separated by background gutters of at least
     --gutter px; inside each run, the first..last content rows (a column band can hold several
     screens stacked vertically: rows are split the same way).
  4. Each edge is moved inwards (at most --refine px) to the first colour step that clearly exceeds
     the gradual ramp before it: a screen border jumps, drop shadows and halos change a few levels per
     pixel, and inner boundaries (photos, cards) lie further in. The step is the median over the
     scan lines of the middle 60 % of the edge.
  5. Boxes smaller than --min-size px on either side are discarded (icons, captions, logos).

Output: JSON on stdout (and --json FILE) with each box, its size, aspect ratio (h/w) and the DPR
each common phone logical width would imply; with --out DIR, one PNG crop per screen
(screen_1.png …, reading order left→right, top→bottom). Crops are exact pixel copies (no resize).

This tool only locates screens. It does not decide the logical viewport: pick the device width from
the recorded source (or ask), then pass the crop to measure.py with that --logical-width.

Exit codes: 0 = at least one screen found, 3 = none found, 2 = usage error.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

import numpy as np
from PIL import Image

PHONE_WIDTHS = (360, 375, 390, 393, 402, 412, 414, 430, 440)


def background(rgb: np.ndarray) -> tuple[int, int, int]:
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    return Counter(map(tuple, border.tolist())).most_common(1)[0][0]


def runs(flags: np.ndarray, min_gap: int) -> list[tuple[int, int]]:
    """[start, end) runs of True, merging runs separated by fewer than min_gap False values."""
    out: list[list[int]] = []
    idx = np.flatnonzero(flags)
    for i in idx.tolist():
        if out and i - out[-1][1] < min_gap:
            out[-1][1] = i + 1
        else:
            out.append([i, i + 1])
    return [(a, b) for a, b in out]


def border_step(lines: np.ndarray, lo: int, hi: int, outward: str, min_step: float = 12.0) -> int | None:
    """Walk from the outside of [lo, hi) inwards and return the first colour step that is clearly
    larger than the gradual ramp before it (a drop shadow or halo changes a few levels per pixel; a
    screen border jumps): step >= max(min_step, 3 x median of the steps already passed).

    lines: 2-D luminance, one row per scan line across the edge (rows for a vertical edge). The
    step at each position is the MEDIAN over scan lines of |p[i] - p[i-1]|, so a border that is not
    perfectly straight in the image (anti-aliasing, a slight tilt) still reads as one sharp step,
    and text or photos crossing a few scan lines do not.
    outward = "low" for left/top edges (returns the first inside pixel), "high" for right/bottom
    edges (returns one past the last inside pixel). None when no step qualifies."""
    lo = max(lo, 1)
    hi = min(hi, lines.shape[1])
    if hi <= lo:
        return None
    steps = np.median(np.abs(np.diff(lines[:, lo - 1 : hi], axis=1)), axis=0)
    order = range(len(steps)) if outward == "low" else range(len(steps) - 1, -1, -1)
    passed: list[float] = []
    for k in order:
        threshold = max(min_step, 3 * float(np.median(passed))) if passed else min_step
        if steps[k] >= threshold:
            return lo + k
        passed.append(float(steps[k]))
    return None


def refine(lum: np.ndarray, box: list[int], reach: int) -> list[int]:
    x0, y0, x1, y1 = box
    h, w = lum.shape
    my0, my1 = y0 + (y1 - y0) // 5, y1 - (y1 - y0) // 5
    mx0, mx1 = x0 + (x1 - x0) // 5, x1 - (x1 - x0) // 5
    across_x = lum[my0:my1]        # scan lines crossing the left/right edges
    across_y = lum[:, mx0:mx1].T   # scan lines crossing the top/bottom edges
    # The content box starts at the outer halo; the border lies at or inside it.
    nx0 = border_step(across_x, x0 - 2, x0 + reach, "low")
    nx1 = border_step(across_x, x1 - reach, x1 + 2, "high")
    ny0 = border_step(across_y, y0 - 2, y0 + reach, "low")
    ny1 = border_step(across_y, y1 - reach, y1 + 2, "high")
    nx0 = x0 if nx0 is None else max(0, nx0)
    ny0 = y0 if ny0 is None else max(0, ny0)
    nx1 = x1 if nx1 is None else min(w, max(nx1, nx0 + 1))
    ny1 = y1 if ny1 is None else min(h, max(ny1, ny0 + 1))
    return [nx0, ny0, nx1, ny1]


def find_screens(img: Image.Image, tol: int, gutter: int, min_size: int, reach: int,
                 min_fraction: float) -> tuple[tuple[int, int, int], list[list[int]]]:
    rgb = np.asarray(img.convert("RGB"), dtype=np.int16)
    bg = background(rgb)
    mask = np.abs(rgb - np.array(bg, dtype=np.int16)).max(axis=2) > tol
    lum = (rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114).astype(np.float64)
    boxes: list[list[int]] = []
    col_has = mask.mean(axis=0) > min_fraction
    for cx0, cx1 in runs(col_has, gutter):
        band = mask[:, cx0:cx1]
        row_has = band.mean(axis=1) > min_fraction
        for ry0, ry1 in runs(row_has, gutter):
            # Re-tighten the columns to this row run (stacked screens can differ in width).
            sub = mask[ry0:ry1, cx0:cx1]
            sub_cols = np.flatnonzero(sub.mean(axis=0) > min_fraction)
            if sub_cols.size == 0:
                continue
            box = [cx0 + int(sub_cols[0]), ry0, cx0 + int(sub_cols[-1]) + 1, ry1]
            if reach > 0:
                box = refine(lum, box, reach)
            if box[2] - box[0] >= min_size and box[3] - box[1] >= min_size:
                boxes.append(box)
    boxes.sort(key=lambda b: (round(b[1] / max(1, min_size)), b[0]))
    return bg, boxes


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("image")
    ap.add_argument("--out", help="directory for screen_N.png crops")
    ap.add_argument("--json", help="also write the JSON report here")
    ap.add_argument("--tol", type=int, default=18, help="max-channel difference from background (default 18)")
    ap.add_argument("--gutter", type=int, default=12, help="min background gap between screens, px (default 12)")
    ap.add_argument("--min-size", type=int, default=120, help="min screen width/height, px (default 120)")
    ap.add_argument("--refine", type=int, default=40, help="edge search reach, px; 0 disables (default 40)")
    ap.add_argument("--min-fraction", type=float, default=0.01,
                    help="share of content pixels that makes a row/column count (default 0.01)")
    args = ap.parse_args(argv)

    path = Path(args.image)
    if not path.is_file():
        print(json.dumps({"error": f"no such file: {path}"}), file=sys.stderr)
        return 2
    img = Image.open(path)
    bg, boxes = find_screens(img, args.tol, args.gutter, args.min_size, args.refine, args.min_fraction)
    screens = []
    for i, (x0, y0, x1, y1) in enumerate(boxes, start=1):
        w, h = x1 - x0, y1 - y0
        entry = {
            "index": i,
            "box": {"x": x0, "y": y0, "w": w, "h": h},
            "aspect_h_over_w": round(h / w, 4),
            "dpr_if_logical_width": {str(lw): round(w / lw, 4) for lw in PHONE_WIDTHS},
        }
        if args.out:
            out = Path(args.out)
            out.mkdir(parents=True, exist_ok=True)
            crop = out / f"screen_{i}.png"
            img.crop((x0, y0, x1, y1)).save(crop)
            entry["crop"] = str(crop)
        screens.append(entry)
    report = {
        "image": str(path),
        "pixel_size": list(img.size),
        "background": "#%02X%02X%02X" % tuple(bg),
        "params": {"tol": args.tol, "gutter": args.gutter, "min_size": args.min_size,
                   "refine": args.refine, "min_fraction": args.min_fraction},
        "screens": screens,
        "note": "Boxes are measured; the logical width/DPR must come from the recorded source.",
    }
    text = json.dumps(report, indent=2, ensure_ascii=False)
    print(text)
    if args.json:
        Path(args.json).write_text(text + "\n", encoding="utf-8")
    return 0 if screens else 3


if __name__ == "__main__":
    sys.exit(main())
