#!/usr/bin/env python3
"""Compare an implementation screenshot against an authorized reference screenshot.

Produces (in --out):
  side_by_side.png   reference | output | heatmap
  overlay50.png      output blended 50 % over the reference
  heatmap.png        per-pixel max-channel difference (black = identical, red/yellow = large)
  regions.png        reference with the worst grid regions outlined
  metrics.json       every number below plus the methodology and all inputs

Metrics (methodology is written into metrics.json):
  MAE      mean absolute error over RGB, 0-255 scale, also as a fraction of 255
  SSIM     luminance (Rec. 601) SSIM, Gaussian window sigma=1.5 (11x11), K1=0.01, K2=0.03,
           data range 255; computed in numpy (no scikit-image needed)
  changed  % of pixels whose max-channel difference exceeds each threshold (default 8/16/32/64)
  regions  the same metrics per grid cell, ranked worst first. --grid COLSxROWS fixes the cell count;
           --grid cell:N (pixels) or cell:Nlp (logical px, needs --dpr) sizes cells to about N
           (cols = ceil(w/N), rows = ceil(h/N)). Default cell:24: a small changed component dominates
           its cell instead of being averaged away. EXPERIMENTAL, calibrated on ONE machine only
           (templates/CALIBRATION.md); the grid used is recorded in metrics.json inputs.grid.
           Not a release gate. A PASS does not prove that small icons are unchanged: subtle icon
           colour, opacity and stroke-weight changes may go undetected at any grid size.
  named    --regions FILE: the same metrics per named region ([{"name","x","y","w","h"}] in pixels)
  shift    --shift-search N: the integer (dx, dy) within +/-N px that minimises the luma MAE between the
           reference and the shifted output, globally and per named region. Reported only, never
           applied. Positive dx/dy = the output content sits right/below the reference. A shift is
           flagged "ambiguous" when it improves the MAE by less than 5 % (flat or textureless areas).

Rules enforced:
  * The two images must have identical pixel dimensions. There is no silent resize.
    --resample-reference exists only for a documented DPR mismatch; it is recorded in metrics.json.
  * Masks (e.g. status-bar clock) are allowed only via --mask with a stated reason; every masked
    rectangle and its reason is recorded and drawn on regions.png. Masks never apply to the output alone.
  * The output image is never altered (no blur, crop or filter) before measuring.
  * Criteria fail closed. --criteria accepts a single profile object or the nested templates/thresholds.json
    with --profile NAME. A missing/malformed file, an unknown profile, unrecognised keys, invalid values,
    a changed-pixel threshold that is not computed, or a profile with no checks is rejected (exit 2) before
    anything is measured. A configured check that cannot be evaluated (e.g. everything masked) is listed in
    verdict.not_run and makes the verdict FAIL. A verdict never passes with zero checks run.
  * Advisory profiles (ADVISORY_PROFILES: cross_environment) are marked verdict.advisory = true with the reason,
    and a line on stderr. Their PASS is evidence only, never a release gate. Exit codes are unchanged.

Usage:
  visual_diff.py --reference ref.png --output out.png --out diffdir \
      [--dpr 3] [--mask "x,y,w,h:reason" ...] [--thresholds 8,16,32,64] [--grid cell:24 | 4x12] \
      [--criteria thresholds.json --profile cross_environment] [--resample-reference "reason"] \
      [--regions regions.json] [--shift-search 4]
Exit code: 0 = all configured criteria pass, 1 = a criterion fails, 2 = invalid input.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

METHOD = {
    "mae": "mean |ref-out| over R,G,B for all unmasked pixels; 0-255 scale",
    "ssim": (
        "SSIM (Wang et al. 2004) on Rec.601 luma; Gaussian window sigma=1.5 truncated at 11x11; K1=0.01, K2=0.03, "
        "L=255; population (not sample) covariance; reflect padding. Border policy: the mean excludes pixels within "
        "5 px (the window radius) of the image edge, where the window is padded, which matches "
        "skimage.metrics.structural_similarity(gaussian_weights=True, sigma=1.5, use_sample_covariance=False, "
        "data_range=255). Mask policy: before SSIM the output's masked pixels are replaced by the reference's, so "
        "masked content cannot change the score of neighbouring valid pixels; the mean is over unmasked, "
        "non-border pixels. MAE and changed % use every unmasked pixel (no border exclusion)."
    ),
    "changed": "pixel counted as changed when max(|dR|,|dG|,|dB|) > threshold",
    "alignment": "no automatic translation/scaling; images must match in pixel size; offsets are reported, not corrected",
    "shift": "integer (dx,dy) in +/-N px minimising luma MAE of ref vs shifted output over unmasked pixels; reported, never applied",
}


def sha256(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def load_rgb(p: Path) -> np.ndarray:
    im = Image.open(p)
    if im.mode in ("RGBA", "LA", "P"):
        im = im.convert("RGBA")
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
        bg.alpha_composite(im)
        im = bg
    return np.asarray(im.convert("RGB"), dtype=np.float64)


def gaussian_kernel(sigma: float = 1.5, size: int = 11) -> np.ndarray:
    ax = np.arange(size) - (size - 1) / 2
    k = np.exp(-(ax**2) / (2 * sigma**2))
    return k / k.sum()


def blur(img: np.ndarray, k: np.ndarray) -> np.ndarray:
    pad = len(k) // 2
    p = np.pad(img, pad, mode="reflect")
    # separable convolution
    tmp = np.apply_along_axis(lambda r: np.convolve(r, k, mode="valid"), 1, p)
    return np.apply_along_axis(lambda c: np.convolve(c, k, mode="valid"), 0, tmp)


def ssim_map(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    la = a @ np.array([0.299, 0.587, 0.114])
    lb = b @ np.array([0.299, 0.587, 0.114])
    k = gaussian_kernel()
    c1, c2 = (0.01 * 255) ** 2, (0.03 * 255) ** 2
    mu_a, mu_b = blur(la, k), blur(lb, k)
    saa = blur(la * la, k) - mu_a**2
    sbb = blur(lb * lb, k) - mu_b**2
    sab = blur(la * lb, k) - mu_a * mu_b
    return ((2 * mu_a * mu_b + c1) * (2 * sab + c2)) / ((mu_a**2 + mu_b**2 + c1) * (saa + sbb + c2))


def best_shift(ref_l: np.ndarray, out_l: np.ndarray, keep: np.ndarray, box: tuple[int, int, int, int], n: int) -> dict:
    """Integer shift of the output that best matches the reference inside box (x, y, w, h)."""
    x, y, w, h = box
    hh, ww = ref_l.shape
    best = None
    zero = None
    for dy in range(-n, n + 1):
        for dx in range(-n, n + 1):
            x0, y0 = max(x, -dx, 0), max(y, -dy, 0)
            x1, y1 = min(x + w, ww - dx, ww), min(y + h, hh - dy, hh)
            if x1 - x0 < 4 or y1 - y0 < 4:
                continue
            sel = keep[y0:y1, x0:x1]
            if sel.sum() < 16:
                continue
            d = np.abs(ref_l[y0:y1, x0:x1] - out_l[y0 + dy : y1 + dy, x0 + dx : x1 + dx])[sel].mean()
            if dx == 0 and dy == 0:
                zero = float(d)
            if best is None or d < best[0] - 1e-9 or (abs(d - best[0]) <= 1e-9 and abs(dx) + abs(dy) < abs(best[1]) + abs(best[2])):
                best = (float(d), dx, dy)
    if best is None or zero is None:
        return {"dx": None, "dy": None}
    gain = 0.0 if zero == 0 else (zero - best[0]) / zero
    return {
        "dx": best[1],
        "dy": best[2],
        "luma_mae_at_zero": round(zero, 3),
        "luma_mae_at_best": round(best[0], 3),
        "ambiguous": gain < 0.05,
    }


KNOWN_CHECKS = ("max_mae", "min_ssim", "max_changed_pct", "max_region_mae", "max_masked_pixel_pct")

# Profiles whose verdict is evidence only, never a release gate. A profile leaves this list only after it has been
# calibrated on at least two genuinely different rendering environments (templates/CALIBRATION.md).
ADVISORY_PROFILES = {
    "cross_environment": "not calibrated on two genuinely different rendering environments; in the D7 calibration "
    "5 of 7 seeded defects passed this profile (templates/CALIBRATION.md). Evidence only, never a release gate.",
}


class CriteriaError(ValueError):
    """The acceptance criteria cannot be loaded; the run is invalid (exit 2)."""


def _number(name: str, v, lo: float | None = None, hi: float | None = None) -> float:
    if isinstance(v, bool) or not isinstance(v, (int, float)) or v != v or v in (float("inf"), float("-inf")):
        raise CriteriaError(f"{name} must be a finite number, got {v!r}")
    if (lo is not None and v < lo) or (hi is not None and v > hi):
        raise CriteriaError(f"{name} must be within [{lo}, {hi}], got {v!r}")
    return float(v)


def load_criteria(path: Path, profile: str | None, thresholds: list[int]) -> tuple[dict, str | None]:
    """Loads and validates one acceptance profile. Raises CriteriaError (fail closed) on any problem."""
    if not path.is_file():
        raise CriteriaError(f"criteria file not found: {path}")
    try:
        data = json.loads(path.read_text())
    except (json.JSONDecodeError, UnicodeDecodeError) as e:
        raise CriteriaError(f"criteria file is not valid JSON: {e}") from e
    if not isinstance(data, dict):
        raise CriteriaError("criteria must be a JSON object")
    if "profiles" in data:
        profiles = data["profiles"]
        if not isinstance(profiles, dict) or not profiles:
            raise CriteriaError("'profiles' must be a non-empty object")
        if profile is None:
            raise CriteriaError(f"{path.name} holds several profiles; pass --profile one of {sorted(profiles)}")
        if profile not in profiles:
            raise CriteriaError(f"unknown profile {profile!r}; available: {sorted(profiles)}")
        crit = profiles[profile]
    else:
        crit = data
        if profile is not None and crit.get("profile") not in (None, profile):
            raise CriteriaError(f"--profile {profile!r} does not match the file's profile {crit.get('profile')!r}")
    if not isinstance(crit, dict):
        raise CriteriaError("a profile must be a JSON object")
    unknown = sorted(k for k in crit if k not in KNOWN_CHECKS and k != "profile" and not str(k).startswith("$"))
    if unknown:
        raise CriteriaError(f"unrecognised criteria keys {unknown}; known checks: {list(KNOWN_CHECKS)}")
    configured = [k for k in KNOWN_CHECKS if k in crit]
    if not configured:
        raise CriteriaError(f"no checks configured; expected at least one of {list(KNOWN_CHECKS)}")
    if "max_mae" in crit:
        _number("max_mae", crit["max_mae"], 0, 255)
    if "min_ssim" in crit:
        _number("min_ssim", crit["min_ssim"], -1, 1)
    if "max_region_mae" in crit:
        _number("max_region_mae", crit["max_region_mae"], 0, 255)
    if "max_masked_pixel_pct" in crit:
        _number("max_masked_pixel_pct", crit["max_masked_pixel_pct"], 0, 100)
    if "max_changed_pct" in crit:
        cp = crit["max_changed_pct"]
        if not isinstance(cp, dict) or not cp:
            raise CriteriaError("max_changed_pct must be a non-empty object {threshold: max %}")
        for t, lim in cp.items():
            if not str(t).isdigit():
                raise CriteriaError(f"max_changed_pct threshold {t!r} must be a non-negative integer")
            if int(t) not in thresholds:
                raise CriteriaError(f"max_changed_pct threshold {t} is not computed; add it to --thresholds (have {thresholds})")
            _number(f"max_changed_pct[{t}]", lim, 0, 100)
    return crit, crit.get("profile", profile)


def evaluate(crit: dict, overall: dict, regions: list, masked_pct: float) -> dict:
    """Runs every configured check. A check that cannot run is recorded in not_run and fails the verdict."""
    checks, not_run = [], []

    def add(name, value, limit, ok):
        checks.append({"check": name, "value": value, "limit": limit, "pass": bool(ok)})

    has_pixels = overall.get("pixels", 0) > 0
    if "max_mae" in crit:
        if has_pixels:
            add("mae <= max_mae", overall["mae"], crit["max_mae"], overall["mae"] <= crit["max_mae"])
        else:
            not_run.append({"check": "max_mae", "reason": "no unmasked pixels"})
    if "min_ssim" in crit:
        if has_pixels and overall.get("ssim") is not None:
            add("ssim >= min_ssim", overall["ssim"], crit["min_ssim"], overall["ssim"] >= crit["min_ssim"])
        else:
            not_run.append({"check": "min_ssim", "reason": "no unmasked pixels outside the SSIM border"})
    for t, lim in crit.get("max_changed_pct", {}).items():
        v = overall.get("changed_pct", {}).get(str(t))
        if v is None:
            not_run.append({"check": f"max_changed_pct[{t}]", "reason": "not computed or no unmasked pixels"})
        else:
            add(f"changed_pct@{t} <= limit", v, lim, v <= lim)
    if "max_region_mae" in crit:
        if regions:
            add("worst region mae <= max_region_mae", regions[0]["mae"], crit["max_region_mae"], regions[0]["mae"] <= crit["max_region_mae"])
        else:
            not_run.append({"check": "max_region_mae", "reason": "no unmasked grid region"})
    if "max_masked_pixel_pct" in crit:
        add("masked % <= max_masked_pixel_pct", masked_pct, crit["max_masked_pixel_pct"], masked_pct <= crit["max_masked_pixel_pct"])
    return {
        "checks": checks,
        "checks_run": len(checks),
        "not_run": not_run,
        "not_configured": [k for k in KNOWN_CHECKS if k not in crit],
        "pass": len(checks) > 0 and not not_run and all(c["pass"] for c in checks),
    }


SSIM_WINDOW = 11
SSIM_SIGMA = 1.5
SSIM_BORDER = (SSIM_WINDOW - 1) // 2


def ssim_masked(ref: np.ndarray, out: np.ndarray, keep: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """SSIM map with the documented mask and border policy.

    Returns (map, valid): `valid` marks the pixels the SSIM mean may use: unmasked and at least
    SSIM_BORDER px from every edge. Masked output pixels are replaced by the reference's first, so a
    difference inside a mask cannot lower the score of valid pixels whose window overlaps the mask.
    """
    neutral = out.copy()
    neutral[~keep] = ref[~keep]
    smap = ssim_map(ref, neutral)
    valid = keep.copy()
    b = SSIM_BORDER
    h, w = keep.shape
    if h <= 2 * b or w <= 2 * b:
        valid[:] = False
    else:
        valid[:b, :] = valid[-b:, :] = False
        valid[:, :b] = valid[:, -b:] = False
    return smap, valid


def parse_masks(items: list[str], h: int, w: int) -> tuple[np.ndarray, list[dict]]:
    keep = np.ones((h, w), dtype=bool)
    recorded = []
    for it in items:
        if ":" not in it:
            raise SystemExit(f"mask '{it}' needs a reason: x,y,w,h:reason")
        box, reason = it.split(":", 1)
        x, y, mw, mh = (int(v) for v in box.split(","))
        if not reason.strip():
            raise SystemExit("every mask needs a non-empty reason")
        keep[max(0, y) : y + mh, max(0, x) : x + mw] = False
        recorded.append({"x": x, "y": y, "w": mw, "h": mh, "reason": reason.strip()})
    return keep, recorded


def parse_grid(spec: str, w: int, h: int, dpr: float | None) -> tuple[int, int]:
    """COLSxROWS, or cell:N (pixels) / cell:Nlp (logical px) -> (cols, rows) of cells of about N."""
    spec = spec.strip().lower()
    if spec.startswith("cell:"):
        size = spec[5:]
        if size.endswith("lp"):
            if not dpr:
                raise ValueError(f"{spec!r} needs --dpr")
            px = float(size[:-2]) * dpr
        else:
            px = float(size)
        if not px >= 1:
            raise ValueError(f"cell size must be >= 1 px, got {spec!r}")
        return max(1, -(-w // int(round(px)))), max(1, -(-h // int(round(px))))
    parts = spec.split("x")
    if len(parts) != 2 or not all(p.isdigit() and int(p) > 0 for p in parts):
        raise ValueError(f"expected COLSxROWS or cell:N[lp], got {spec!r}")
    return int(parts[0]), int(parts[1])


def heat_image(d: np.ndarray) -> Image.Image:
    v = np.clip(d / 128.0, 0, 1)
    r = np.clip(v * 2, 0, 1)
    g = np.clip(v * 2 - 1, 0, 1)
    rgb = np.stack([r, g, np.zeros_like(v)], axis=-1) * 255
    return Image.fromarray(rgb.astype(np.uint8))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--reference", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--dpr", type=float, default=None, help="device pixel ratio of BOTH images (for logical coordinates)")
    ap.add_argument("--mask", action="append", default=[], help="x,y,w,h:reason in PIXELS; applied to both images")
    ap.add_argument("--thresholds", default="8,16,32,64")
    ap.add_argument("--grid", default="cell:24", help="COLSxROWS, or cell:N / cell:Nlp (about N px per cell) for the regional breakdown")
    ap.add_argument("--criteria", type=Path, default=None, help="one profile object, or thresholds.json with --profile; when given, pass/fail is evaluated (fail closed)")
    ap.add_argument("--profile", default=None, help="profile name inside a nested criteria file (e.g. cross_environment)")
    ap.add_argument("--resample-reference", default=None, help="REASON; resizes the reference to the output size (recorded)")
    ap.add_argument("--regions", type=Path, default=None, help='named regions JSON [{"name","x","y","w","h"}] in pixels')
    ap.add_argument("--shift-search", type=int, default=0, help="report the best integer shift within +/-N px (0 = off)")
    a = ap.parse_args()

    try:
        thresholds = [int(t) for t in a.thresholds.split(",")]
    except ValueError:
        print(f"invalid --thresholds {a.thresholds!r}", file=sys.stderr)
        return 2
    crit = crit_profile = None
    if a.criteria is not None:
        try:
            crit, crit_profile = load_criteria(a.criteria, a.profile, thresholds)
        except CriteriaError as e:
            print(f"invalid criteria: {e}", file=sys.stderr)
            return 2
    elif a.profile is not None:
        print("--profile requires --criteria", file=sys.stderr)
        return 2

    for p in (a.reference, a.output):
        if not p.is_file():
            print(f"missing file: {p}", file=sys.stderr)
            return 2
    ref, out = load_rgb(a.reference), load_rgb(a.output)
    notes = []
    if ref.shape != out.shape:
        if not a.resample_reference:
            print(
                f"size mismatch: reference {ref.shape[1]}x{ref.shape[0]} vs output {out.shape[1]}x{out.shape[0]}. "
                "Capture at the reference viewport and DPR, or pass --resample-reference 'reason'.",
                file=sys.stderr,
            )
            return 2
        im = Image.open(a.reference).convert("RGB").resize((out.shape[1], out.shape[0]), Image.LANCZOS)
        ref = np.asarray(im, dtype=np.float64)
        notes.append(f"reference resampled to {out.shape[1]}x{out.shape[0]} (LANCZOS): {a.resample_reference}")

    h, w, _ = out.shape
    keep, masks = parse_masks(a.mask, h, w)
    diff = np.abs(ref - out)
    dmax = diff.max(axis=2)
    ssim, ssim_valid = ssim_masked(ref, out, keep)

    def stats(sel: np.ndarray) -> dict:
        n = int(sel.sum())
        if n == 0:
            return {"pixels": 0}
        sv = sel & ssim_valid
        return {
            "pixels": n,
            "mae": round(float(diff[sel].mean()), 4),
            "mae_fraction": round(float(diff[sel].mean() / 255), 6),
            "ssim": round(float(ssim[sv].mean()), 6) if sv.any() else None,
            "ssim_pixels": int(sv.sum()),
            "changed_pct": {str(t): round(100 * float((dmax[sel] > t).sum()) / n, 4) for t in thresholds},
        }

    overall = stats(keep)
    try:
        cols, rows = parse_grid(a.grid, w, h, a.dpr)
    except ValueError as e:
        print(f"invalid --grid: {e}", file=sys.stderr)
        return 2
    regions = []
    for r in range(rows):
        for c in range(cols):
            y0, y1 = r * h // rows, (r + 1) * h // rows
            x0, x1 = c * w // cols, (c + 1) * w // cols
            sel = np.zeros_like(keep)
            sel[y0:y1, x0:x1] = True
            sel &= keep
            s = stats(sel)
            if s["pixels"]:
                box = {"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0}
                if a.dpr:
                    box["logical"] = {k: round(v / a.dpr, 1) for k, v in box.items()}
                regions.append({"row": r, "col": c, **box, **s})
    regions.sort(key=lambda s: s["mae"], reverse=True)

    luma = np.array([0.299, 0.587, 0.114])
    ref_l, out_l = ref @ luma, out @ luma
    named = []
    if a.regions:
        for rg in json.loads(a.regions.read_text()):
            sel = np.zeros_like(keep)
            sel[rg["y"] : rg["y"] + rg["h"], rg["x"] : rg["x"] + rg["w"]] = True
            entry = {**rg, "masked_pct": round(100 * float((sel & ~keep).sum()) / max(int(sel.sum()), 1), 2), **stats(sel & keep)}
            if a.shift_search:
                entry["shift"] = best_shift(ref_l, out_l, keep, (rg["x"], rg["y"], rg["w"], rg["h"]), a.shift_search)
            named.append(entry)
    global_shift = best_shift(ref_l, out_l, keep, (0, 0, w, h), a.shift_search) if a.shift_search else None

    a.out.mkdir(parents=True, exist_ok=True)
    ref_im = Image.fromarray(ref.astype(np.uint8))
    out_im = Image.fromarray(out.astype(np.uint8))
    heat = heat_image(dmax)
    sbs = Image.new("RGB", (w * 3 + 40, h), (128, 128, 128))
    for i, im in enumerate((ref_im, out_im, heat)):
        sbs.paste(im, (i * (w + 20), 0))
    sbs.save(a.out / "side_by_side.png")
    Image.blend(ref_im, out_im, 0.5).save(a.out / "overlay50.png")
    heat.save(a.out / "heatmap.png")
    marked = ref_im.copy()
    dr = ImageDraw.Draw(marked)
    for m in masks:
        dr.rectangle([m["x"], m["y"], m["x"] + m["w"], m["y"] + m["h"]], outline=(0, 128, 255), width=4)
    for s in regions[:5]:
        dr.rectangle([s["x"], s["y"], s["x"] + s["w"] - 1, s["y"] + s["h"] - 1], outline=(255, 0, 0), width=5)
    marked.save(a.out / "regions.png")

    result = {
        "inputs": {
            "reference": str(a.reference),
            "reference_sha256": sha256(a.reference),
            "output": str(a.output),
            "output_sha256": sha256(a.output),
            "pixel_size": [w, h],
            "dpr": a.dpr,
            "logical_size": [round(w / a.dpr, 2), round(h / a.dpr, 2)] if a.dpr else None,
            "grid": {"spec": a.grid, "cols": cols, "rows": rows},
        },
        "methodology": METHOD,
        "notes": notes,
        "masks": masks,
        "masked_pixel_pct": round(100 * float((~keep).sum()) / (h * w), 4),
        "overall": overall,
        "worst_regions": regions[:10],
        "named_regions": named,
        "global_shift": global_shift,
        "verdict": None,
    }

    rc = 0
    if crit is not None:
        result["verdict"] = {"criteria_file": str(a.criteria), "profile": crit_profile,
                             "advisory": crit_profile in ADVISORY_PROFILES,
                             "advisory_reason": ADVISORY_PROFILES.get(crit_profile),
                             **evaluate(crit, overall, regions, result["masked_pixel_pct"])}
        rc = 0 if result["verdict"]["pass"] else 1

    (a.out / "metrics.json").write_text(json.dumps(result, indent=2, ensure_ascii=False))
    v = result["verdict"]
    summary = None if v is None else {
        "pass": v["pass"], "profile": v["profile"], "advisory": v["advisory"], "checks_run": v["checks_run"],
        "failed": [c["check"] for c in v["checks"] if not c["pass"]], "not_run": v["not_run"]}
    print(json.dumps({"overall": overall, "verdict": summary, "out": str(a.out)}, ensure_ascii=False))
    if v is not None and v["advisory"]:
        print(f"ADVISORY profile {v['profile']!r}: {v['advisory_reason']}", file=sys.stderr)
    return rc


if __name__ == "__main__":
    sys.exit(main())
