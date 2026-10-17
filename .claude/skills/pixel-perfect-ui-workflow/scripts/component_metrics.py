#!/usr/bin/env python3
"""Per-component metrics, reported by category: geometry, typography, icons, images and colour.

Usage:
  component_metrics.py --reference ref.png --output out.png --spec spec.json --dpr 0.6565 --out metrics.json

The spec is a JSON list of components; every window is in PIXELS and is searched identically in both images:
  {"name": "title", "type": "text",  "window": [x,y,w,h], "bg": 255}
  {"name": "bell",  "type": "icon",  "window": [x,y,w,h], "bg": 255}
  {"name": "follow","type": "box",   "window": [x,y,w,h], "rgb": [255,42,86], "tol": 70}
  {"name": "grid",  "type": "image", "window": [x,y,w,h]}
  {"name": "bg",    "type": "color", "point": [x,y], "radius": 2, "note": "optional (e.g. 'brand override')"}

Metrics (all measured, nothing estimated):
  geometry   ink (or colour-box) bounding box of each text/icon/box component: centre offset dx, dy and size
             error dw, dh in logical px (output minus reference).
  typography ink ratio  = output ink / reference ink inside the tight box (1.0 = same weight x size);
             shape error = sum|ref-out| / sum(ref) of the normalised ink after aligning the tight boxes at their
             top-left with the best integer offset within +/-1 px (0 = identical, 1 = no overlap);
             width error = (w_out - w_ref) / w_ref.
  icons      IoU of the binarised ink (normalised ink > 0.35) after centring the two bounding boxes;
             stroke width = 2 x ink area / ink perimeter (px -> lp), a standard thin-shape estimate.
  images     MAE (RGB, 0-255) and mean luma SSIM (visual_diff.py's SSIM and border policy) inside the window, plus the
             mean-colour CIEDE2000 difference.
  colour     CIEDE2000 between the median colours in a (2r+1)^2 window at the point.
Ink normalisation: ink = clip(bg - luma, 0) / max of that inside the tight box (scale-invariant to text colour).
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path

import numpy as np
from PIL import Image

_spec = importlib.util.spec_from_file_location("vd", Path(__file__).with_name("visual_diff.py"))
vd = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(vd)

LUMA = np.array([0.299, 0.587, 0.114])


def srgb_to_lab(rgb: np.ndarray) -> np.ndarray:
    c = rgb / 255.0
    c = np.where(c > 0.04045, ((c + 0.055) / 1.055) ** 2.4, c / 12.92)
    m = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
    xyz = c @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 216 / 24389, np.cbrt(xyz), (24389 / 27 * xyz + 16) / 116)
    return np.stack([116 * f[..., 1] - 16, 500 * (f[..., 0] - f[..., 1]), 200 * (f[..., 1] - f[..., 2])], -1)


def ciede2000(lab1: np.ndarray, lab2: np.ndarray) -> float:
    L1, a1, b1 = lab1
    L2, a2, b2 = lab2
    C1, C2 = np.hypot(a1, b1), np.hypot(a2, b2)
    Cb = (C1 + C2) / 2
    G = 0.5 * (1 - np.sqrt(Cb**7 / (Cb**7 + 25**7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = np.hypot(a1p, b1), np.hypot(a2p, b2)
    h1p, h2p = np.degrees(np.arctan2(b1, a1p)) % 360, np.degrees(np.arctan2(b2, a2p)) % 360
    dLp, dCp = L2 - L1, C2p - C1p
    dhp = 0 if C1p * C2p == 0 else (h2p - h1p if abs(h2p - h1p) <= 180 else h2p - h1p - 360 * np.sign(h2p - h1p))
    dHp = 2 * np.sqrt(C1p * C2p) * np.sin(np.radians(dhp / 2))
    Lbp, Cbp = (L1 + L2) / 2, (C1p + C2p) / 2
    if C1p * C2p == 0:
        hbp = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        hbp = (h1p + h2p) / 2
    else:
        hbp = (h1p + h2p + 360) / 2 if h1p + h2p < 360 else (h1p + h2p - 360) / 2
    Tt = 1 - 0.17 * np.cos(np.radians(hbp - 30)) + 0.24 * np.cos(np.radians(2 * hbp)) + 0.32 * np.cos(np.radians(3 * hbp + 6)) - 0.20 * np.cos(np.radians(4 * hbp - 63))
    dth = 30 * np.exp(-(((hbp - 275) / 25) ** 2))
    Rc = 2 * np.sqrt(Cbp**7 / (Cbp**7 + 25**7))
    Sl = 1 + 0.015 * (Lbp - 50) ** 2 / np.sqrt(20 + (Lbp - 50) ** 2)
    Sc, Sh = 1 + 0.045 * Cbp, 1 + 0.015 * Cbp * Tt
    Rt = -np.sin(np.radians(2 * dth)) * Rc
    return float(np.sqrt((dLp / Sl) ** 2 + (dCp / Sc) ** 2 + (dHp / Sh) ** 2 + Rt * (dCp / Sc) * (dHp / Sh)))


def tight_ink(img: np.ndarray, win, bg: float, thr: float = 0.25):
    x, y, w, h = win
    lum = img[y : y + h, x : x + w] @ LUMA
    ink = np.clip(bg - lum, 0, None)
    if ink.max() <= 0:
        return None
    ink = ink / ink.max()
    ys, xs = np.where(ink > thr)
    if len(xs) == 0:
        return None
    box = (x + xs.min(), y + ys.min(), xs.max() - xs.min() + 1, ys.max() - ys.min() + 1)
    return box, ink[ys.min() : ys.max() + 1, xs.min() : xs.max() + 1]


def pad_to(a: np.ndarray, h: int, w: int, oy: int = 0, ox: int = 0) -> np.ndarray:
    out = np.zeros((h, w))
    hh, ww = min(a.shape[0], h - oy), min(a.shape[1], w - ox)
    if hh > 0 and ww > 0:
        out[oy : oy + hh, ox : ox + ww] = a[:hh, :ww]
    return out


def shape_error(r: np.ndarray, o: np.ndarray) -> float:
    h, w = max(r.shape[0], o.shape[0]) + 2, max(r.shape[1], o.shape[1]) + 2
    R = pad_to(r, h, w, 1, 1)
    best = 9.0
    for oy in range(0, 3):
        for ox in range(0, 3):
            O = pad_to(o, h, w, oy, ox)
            best = min(best, float(np.abs(R - O).sum() / max(R.sum(), 1e-9)))
    return best


def iou_centred(r: np.ndarray, o: np.ndarray, thr: float = 0.35) -> float:
    h, w = max(r.shape[0], o.shape[0]), max(r.shape[1], o.shape[1])
    R = pad_to(r, h, w, (h - r.shape[0]) // 2, (w - r.shape[1]) // 2) > thr
    O = pad_to(o, h, w, (h - o.shape[0]) // 2, (w - o.shape[1]) // 2) > thr
    u = (R | O).sum()
    return float((R & O).sum() / u) if u else 0.0


def stroke(a: np.ndarray, thr: float = 0.35) -> float:
    m = a > thr
    area = m.sum()
    per = (m[:, 1:] != m[:, :-1]).sum() + (m[1:, :] != m[:-1, :]).sum() + m[:, 0].sum() + m[:, -1].sum() + m[0, :].sum() + m[-1, :].sum()
    return float(2 * area / per) if per else 0.0


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--reference", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    ap.add_argument("--spec", required=True, type=Path)
    ap.add_argument("--dpr", type=float, required=True)
    ap.add_argument("--out", required=True, type=Path)
    a = ap.parse_args()
    ref, out = vd.load_rgb(a.reference), vd.load_rgb(a.output)
    if ref.shape != out.shape:
        raise SystemExit("size mismatch")
    D = a.dpr
    # Same SSIM policy as visual_diff.py (border excluded; no masks here).
    ssim, ssim_valid = vd.ssim_masked(ref, out, np.ones(ref.shape[:2], bool))
    res = {"geometry": [], "typography": [], "icons": [], "images": [], "colour": []}
    for c in json.loads(a.spec.read_text()):
        t, name = c["type"], c["name"]
        if t in ("text", "icon"):
            rr, oo = tight_ink(ref, c["window"], c.get("bg", 255)), tight_ink(out, c["window"], c.get("bg", 255))
            if rr is None or oo is None:
                res["geometry"].append({"name": name, "type": t, "missing": "reference" if rr is None else "output"})
                continue
            (rb, ri), (ob, oi) = rr, oo
            res["geometry"].append(geom(name, t, rb, ob, D))
            if t == "text":
                res["typography"].append({
                    "name": name,
                    "ink_ratio": round(float(oi.sum() / ri.sum()), 3),
                    "shape_error": round(shape_error(ri, oi), 3),
                    "width_error_pct": round(100 * (ob[2] - rb[2]) / rb[2], 1),
                    "height_error_pct": round(100 * (ob[3] - rb[3]) / rb[3], 1),
                })
            else:
                res["icons"].append({
                    "name": name,
                    "iou": round(iou_centred(ri, oi), 3),
                    "stroke_ref_lp": round(stroke(ri) / D, 2),
                    "stroke_out_lp": round(stroke(oi) / D, 2),
                    "ink_ratio": round(float(oi.sum() / ri.sum()), 3),
                })
        elif t == "box":
            tgt, tol = np.array(c["rgb"]), c.get("tol", 40)
            boxes = []
            for img in (ref, out):
                x, y, w, h = c["window"]
                m = np.abs(img[y : y + h, x : x + w] - tgt).max(-1) <= tol
                ys, xs = np.where(m)
                boxes.append(None if len(xs) == 0 else (x + xs.min(), y + ys.min(), xs.max() - xs.min() + 1, ys.max() - ys.min() + 1))
            if None in boxes:
                res["geometry"].append({"name": name, "type": t, "missing": "reference" if boxes[0] is None else "output"})
            else:
                res["geometry"].append(geom(name, t, boxes[0], boxes[1], D))
        elif t == "image":
            x, y, w, h = c["window"]
            R, O = ref[y : y + h, x : x + w], out[y : y + h, x : x + w]
            res["images"].append({
                "name": name,
                "mae": round(float(np.abs(R - O).mean()), 2),
                "ssim": round(float(ssim[y : y + h, x : x + w][ssim_valid[y : y + h, x : x + w]].mean()), 3),
                "mean_colour_de2000": round(ciede2000(srgb_to_lab(R.reshape(-1, 3).mean(0)), srgb_to_lab(O.reshape(-1, 3).mean(0))), 2),
            })
        elif t == "color":
            x, y = c["point"]
            r = c.get("radius", 2)
            cr = np.median(ref[y - r : y + r + 1, x - r : x + r + 1].reshape(-1, 3), 0)
            co = np.median(out[y - r : y + r + 1, x - r : x + r + 1].reshape(-1, 3), 0)
            res["colour"].append({
                "name": name,
                "ref": "#%02X%02X%02X" % tuple(int(v) for v in cr),
                "out": "#%02X%02X%02X" % tuple(int(v) for v in co),
                "de2000": round(ciede2000(srgb_to_lab(cr), srgb_to_lab(co)), 2),
                **({"note": c["note"]} if "note" in c else {}),
            })
    g = [e for e in res["geometry"] if "missing" not in e]
    res["summary"] = {
        "geometry": {"components": len(g), "max_centre_error_lp": max((e["centre_error_lp"] for e in g), default=None),
                     "mean_centre_error_lp": round(float(np.mean([e["centre_error_lp"] for e in g])), 2) if g else None,
                     "mean_abs_size_error_lp": round(float(np.mean([(abs(e["dw"]) + abs(e["dh"])) / 2 for e in g])), 2) if g else None,
                     "missing": [e["name"] for e in res["geometry"] if "missing" in e]},
        "typography": {"mean_shape_error": mean(res["typography"], "shape_error"),
                       "mean_abs_ink_deviation": round(float(np.mean([abs(1 - e["ink_ratio"]) for e in res["typography"]])), 3) if res["typography"] else None,
                       "mean_abs_width_error_pct": round(float(np.mean([abs(e["width_error_pct"]) for e in res["typography"]])), 1) if res["typography"] else None},
        "icons": {"mean_iou": mean(res["icons"], "iou"),
                  "mean_abs_stroke_error_lp": round(float(np.mean([abs(e["stroke_out_lp"] - e["stroke_ref_lp"]) for e in res["icons"]])), 2) if res["icons"] else None},
        "images": {"mean_mae": mean(res["images"], "mae"), "mean_ssim": mean(res["images"], "ssim")},
        "colour": {"mean_de2000": mean(res["colour"], "de2000"),
                   "mean_de2000_excluding_noted": mean([e for e in res["colour"] if "note" not in e], "de2000")},
    }
    a.out.write_text(json.dumps(res, indent=1))
    print(json.dumps(res["summary"], indent=1))


def mean(rows, key):
    return round(float(np.mean([r[key] for r in rows])), 3) if rows else None


def geom(name, t, rb, ob, D):
    dx = (ob[0] + ob[2] / 2 - rb[0] - rb[2] / 2) / D
    dy = (ob[1] + ob[3] / 2 - rb[1] - rb[3] / 2) / D
    return {"name": name, "type": t, "ref_px": [int(v) for v in rb], "out_px": [int(v) for v in ob],
            "dx": round(dx, 1), "dy": round(dy, 1), "dw": round((ob[2] - rb[2]) / D, 1), "dh": round((ob[3] - rb[3]) / D, 1),
            "centre_error_lp": round(float(np.hypot(dx, dy)), 1)}


if __name__ == "__main__":
    main()
