#!/usr/bin/env python3
"""Turn one or more visual_diff.py metrics.json files into a ranked defect list with an explicit
verification status, for the COMPARE/FIX steps and the final report.

It reads the numbers visual_diff.py produced; it never recomputes, rescales or edits images.

Status (exactly one per comparison):
  PASSED            criteria ran, every check passed, profile is a release gate (e.g. controlled)
  FAILED            criteria ran and at least one check failed
  ADVISORY_PASS     advisory profile (cross_environment) passed: evidence only, never a gate
  ADVISORY_FAIL     advisory profile failed
  NOT_RUN           no criteria were evaluated (no --criteria, or checks could not run)
A metric never upgrades a status: a reviewer's visual defect or a failing test still blocks.

Defects: adjacent grid cells whose MAE exceeds the minor band are merged into clusters, then ranked
by MAE x area. Severity bands are relative to the profile's max_region_mae when present
(critical >= 2x, major >= 1x, minor >= 0.5x), otherwise absolute (critical >= 40, major >= 20,
minor >= 8, on the 0-255 MAE scale). Named regions (visual_diff.py --regions) are listed separately
with the same bands; pass --components to label grid clusters by the named region they overlap most.

Usage:
  triage_diff.py METRICS.json [METRICS.json ...] [--md report.md] [--json triage.json] [--top 8]
Exit codes: 0 = every comparison PASSED or ADVISORY_PASS, 1 = any FAILED/ADVISORY_FAIL/NOT_RUN,
2 = usage error (unreadable or non-visual_diff file).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ABSOLUTE = {"critical": 40.0, "major": 20.0, "minor": 8.0}


def bands(metrics: dict) -> tuple[dict, str]:
    limit = None
    for c in (metrics.get("verdict") or {}).get("checks", []):
        if c.get("check", "").startswith("worst region mae"):
            limit = float(c["limit"])
    if limit:
        return {"critical": 2 * limit, "major": limit, "minor": 0.5 * limit}, f"relative to max_region_mae={limit}"
    return dict(ABSOLUTE), "absolute (no region criterion in this run)"


def severity(mae: float, b: dict) -> str | None:
    for name in ("critical", "major", "minor"):
        if mae >= b[name]:
            return name
    return None


def status(metrics: dict) -> str:
    v = metrics.get("verdict")
    if not v or not v.get("checks_run"):
        return "NOT_RUN"
    if v.get("not_run"):
        return "FAILED" if not v.get("advisory") else "ADVISORY_FAIL"
    if v.get("advisory"):
        return "ADVISORY_PASS" if v.get("pass") else "ADVISORY_FAIL"
    return "PASSED" if v.get("pass") else "FAILED"


def clusters(cells: list[dict], minor: float) -> list[dict]:
    hot = {(c["row"], c["col"]): c for c in cells if c["mae"] >= minor}
    seen, out = set(), []
    for key in sorted(hot):
        if key in seen:
            continue
        group, todo = [], [key]
        seen.add(key)
        while todo:
            r, c = todo.pop()
            group.append(hot[(r, c)])
            for n in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
                if n in hot and n not in seen:
                    seen.add(n)
                    todo.append(n)
        x0 = min(g["x"] for g in group)
        y0 = min(g["y"] for g in group)
        x1 = max(g["x"] + g["w"] for g in group)
        y1 = max(g["y"] + g["h"] for g in group)
        px = sum(g["pixels"] for g in group)
        mae = sum(g["mae"] * g["pixels"] for g in group) / max(px, 1)
        lg = [g["logical"] for g in group if "logical" in g]
        box_logical = None  # only when visual_diff.py ran with --dpr
        if len(lg) == len(group):
            lx0, ly0 = min(l["x"] for l in lg), min(l["y"] for l in lg)
            box_logical = [round(lx0, 1), round(ly0, 1),
                           round(max(l["x"] + l["w"] for l in lg) - lx0, 1),
                           round(max(l["y"] + l["h"] for l in lg) - ly0, 1)]
        out.append({
            "cells": len(group),
            "box_px": [x0, y0, x1 - x0, y1 - y0],
            "box_logical": box_logical,
            "mae": round(mae, 2),
            "peak_cell_mae": round(max(g["mae"] for g in group), 2),
            "min_ssim": round(min(g.get("ssim", 1.0) for g in group), 4),
            "impact": round(mae * px, 1),
        })
    return sorted(out, key=lambda c: -c["impact"])


def overlap(a: list[int], named: dict) -> int:
    ax, ay, aw, ah = a
    bx, by, bw, bh = named["x"], named["y"], named["w"], named["h"]
    return max(0, min(ax + aw, bx + bw) - max(ax, bx)) * max(0, min(ay + ah, by + bh) - max(ay, by))


def triage(path: Path, top: int) -> dict:
    m = json.loads(path.read_text(encoding="utf-8"))
    if "overall" not in m or "worst_regions" not in m:
        raise ValueError(f"{path}: not a visual_diff.py metrics.json")
    b, basis = bands(m)
    named = m.get("named_regions") or []
    if isinstance(named, dict):
        named = [dict(name=k, **v) for k, v in named.items()]
    defects = []
    for c in clusters(m["worst_regions"], b["minor"]):
        sev = severity(c["mae"], b) or severity(c["peak_cell_mae"], b)
        if not sev:
            continue
        label = None
        if named:
            best = max(named, key=lambda n: overlap(c["box_px"], n) if all(k in n for k in "xywh") else 0)
            if all(k in best for k in "xywh") and overlap(c["box_px"], best):
                label = best.get("name")
        defects.append({"severity": sev, "component": label, **c})
    named_rows = []
    for n in named:
        mae = n.get("mae")
        if mae is None:
            continue
        named_rows.append({"name": n.get("name"), "mae": mae, "ssim": n.get("ssim"),
                           "severity": severity(float(mae), b), "shift": n.get("shift")})
    named_rows.sort(key=lambda r: -float(r["mae"]))
    v = m.get("verdict") or {}
    return {
        "metrics": str(path),
        "status": status(m),
        "profile": v.get("profile"),
        "advisory_reason": v.get("advisory_reason"),
        "failed_checks": [c for c in v.get("checks", []) if not c.get("pass")],
        "not_run": v.get("not_run", []),
        "viewport": {"pixel_size": m["inputs"].get("pixel_size"), "dpr": m["inputs"].get("dpr"),
                     "logical_size": m["inputs"].get("logical_size")},
        "overall": {k: m["overall"].get(k) for k in ("mae", "ssim", "changed_pct")},
        "global_shift": m.get("global_shift"),
        "masks": m.get("masks", []),
        "severity_basis": basis,
        "defects": defects[:top],
        "defects_total": len(defects),
        "named_regions": named_rows,
    }


def markdown(results: list[dict]) -> str:
    lines = ["# Visual comparison triage", ""]
    for r in results:
        o = r["overall"]
        lines += [
            f"## `{r['metrics']}`",
            "",
            f"- **Status:** {r['status']}" + (f" (profile `{r['profile']}`)" if r["profile"] else ""),
            f"- **Viewport:** {r['viewport']['logical_size']} logical @ DPR {r['viewport']['dpr']}"
            f" ({r['viewport']['pixel_size']} px)",
            f"- **Overall:** MAE {o['mae']}, SSIM {o['ssim']}, changed % {o['changed_pct']}",
        ]
        if r["advisory_reason"]:
            lines.append(f"- **Advisory:** {r['advisory_reason']}")
        if r["masks"]:
            lines.append(f"- **Masks:** {json.dumps(r['masks'], ensure_ascii=False)}")
        if r["failed_checks"]:
            lines.append("- **Failed checks:** " + "; ".join(
                f"{c['check']} (value {c['value']}, limit {c['limit']})" for c in r["failed_checks"]))
        if r["not_run"]:
            lines.append(f"- **Not run:** {r['not_run']}")
        gs = r.get("global_shift") or {}
        if gs:
            lines.append(f"- **Global shift:** dx={gs.get('dx')} dy={gs.get('dy')}"
                         + (" (ambiguous)" if gs.get("ambiguous") else ""))
        lines += ["", f"Severity bands: {r['severity_basis']}.", ""]
        if r["defects"]:
            lines += ["| # | Severity | Component | Box x,y,w,h (logical, else px) | MAE | min SSIM | Cells |",
                      "| - | -------- | --------- | ------------------------------ | --- | -------- | ----- |"]
            for i, d in enumerate(r["defects"], 1):
                box = d["box_logical"] or f"{d['box_px']} px"
                lines.append(f"| {i} | {d['severity']} | {d['component'] or '—'} | {box} | "
                             f"{d['mae']} | {d['min_ssim']} | {d['cells']} |")
            if r["defects_total"] > len(r["defects"]):
                lines.append(f"\n{r['defects_total'] - len(r['defects'])} more not shown.")
        else:
            lines.append("No grid region reaches the minor band.")
        if r["named_regions"]:
            lines += ["", "| Named region | MAE | SSIM | Severity | Shift |", "| --- | --- | --- | --- | --- |"]
            for n in r["named_regions"]:
                lines.append(f"| {n['name']} | {n['mae']} | {n['ssim']} | {n['severity'] or '—'} | "
                             f"{json.dumps(n['shift']) if n['shift'] else '—'} |")
        lines.append("")
    lines.append("Metrics are evidence, not a verdict on their own: an obvious visual defect, a failing "
                 "test or an untested locale/viewport still blocks the screen.")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("metrics", nargs="+")
    ap.add_argument("--md")
    ap.add_argument("--json")
    ap.add_argument("--top", type=int, default=8)
    args = ap.parse_args(argv)
    try:
        results = [triage(Path(p), args.top) for p in args.metrics]
    except (OSError, ValueError, KeyError) as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        return 2
    md = markdown(results)
    print(md)
    if args.md:
        Path(args.md).write_text(md, encoding="utf-8")
    if args.json:
        Path(args.json).write_text(json.dumps(results, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    ok = all(r["status"] in ("PASSED", "ADVISORY_PASS") for r in results)
    return 0 if ok else 1

if __name__ == "__main__":
    sys.exit(main())
