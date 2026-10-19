#!/usr/bin/env python3
"""Detect the frontend stack and its UI conventions before any design work, so the workflow applies
the matching rules (Flutter vs React/Next.js vs other) and reuses what the project already has.

Reads only manifest and config files (no network, no installs). Prints JSON:
  apps[]        one entry per frontend app found (path, framework, version hints)
  conventions   per app: router, state, localization, styling/design tokens, image loading,
                test/golden tooling, RTL support hints, web-capture readiness
  warnings      things the workflow must not assume (e.g. no localization set up)

Every value is evidence from a file (the file path is reported next to it). Missing evidence is
reported as null, never guessed.

Usage: detect_stack.py [ROOT] [--max-depth 4]
Exit codes: 0 = at least one app found, 3 = none found, 2 = usage error.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SKIP = {".git", "node_modules", "build", ".dart_tool", ".next", "dist", ".claude", "ios", "android",
        "macos", "linux", "windows", ".venv", "venv", "coverage"}


def walk(root: Path, max_depth: int):
    stack = [(root, 0)]
    while stack:
        d, depth = stack.pop()
        try:
            entries = sorted(d.iterdir())
        except OSError:
            continue
        for e in entries:
            if e.is_dir():
                if e.name not in SKIP and depth < max_depth:
                    stack.append((e, depth + 1))
            else:
                yield e


def yaml_deps(text: str) -> set[str]:
    """Package names under dependencies/dev_dependencies of a pubspec (no YAML library needed)."""
    names: set[str] = set()
    section = None
    for line in text.splitlines():
        if re.match(r"^(dependencies|dev_dependencies):\s*$", line):
            section = line.split(":")[0]
            continue
        if re.match(r"^\S", line):
            section = None
        m = re.match(r"^  ([A-Za-z0-9_]+):", line)
        if section and m:
            names.add(m.group(1))
    return names


def first(paths: list[Path], root: Path) -> str | None:
    return str(paths[0].relative_to(root)) if paths else None


def flutter_app(pubspec: Path, root: Path) -> dict:
    app = pubspec.parent
    text = pubspec.read_text(encoding="utf-8", errors="replace")
    deps = yaml_deps(text)
    lib = app / "lib"
    dart = list(lib.rglob("*.dart")) if lib.is_dir() else []

    def grep(pattern: str) -> list[Path]:
        rx = re.compile(pattern)
        return [p for p in dart if rx.search(p.read_text(encoding="utf-8", errors="replace"))]

    l10n_yaml = app / "l10n.yaml"
    arbs = sorted(app.rglob("*.arb"))
    goldens = [p for p in (app / "test").rglob("*golden*") if p.is_file()] if (app / "test").is_dir() else []
    # Design tokens: tokens/palette/theme/colors files inside a design-system or theme folder
    # (not e.g. network/auth_tokens.dart).
    token_files = [
        p for p in dart
        if re.search(r"(^|_)(tokens?|palette|theme|colou?rs)\.dart$", p.name)
        and re.search(r"design|theme|style", str(p.parent.relative_to(lib)))
    ]
    return {
        "path": str(app.relative_to(root)) or ".",
        "framework": "flutter",
        "evidence": str(pubspec.relative_to(root)),
        "sdk_constraint": (re.search(r"sdk:\s*['\"]?([^'\"\n]+)", text) or [None, None])[1],
        "conventions": {
            "router": next((d for d in ("go_router", "auto_route", "beamer") if d in deps), None),
            "state": next((d for d in ("flutter_riverpod", "hooks_riverpod", "riverpod", "flutter_bloc",
                                       "provider", "get", "mobx") if d in deps), None),
            "localization": {
                "gen_l10n": l10n_yaml.is_file() or "generate: true" in text,
                "arb_files": [str(p.relative_to(root)) for p in arbs[:10]],
                "locales": sorted({p.stem.split("_", 1)[-1] for p in arbs}),
            },
            "rtl_locales": sorted({p.stem.split("_", 1)[-1] for p in arbs} & {"ar", "fa", "he", "ur"}),
            "design_tokens": [str(p.relative_to(root)) for p in token_files[:8]],
            "bundled_fonts": sorted(set(re.findall(r"family:\s*([^\n]+)", text))),
            "asset_dirs": re.findall(r"^\s*-\s*(assets/[^\s#]+)", text, re.M),
            "svg": "flutter_svg" in deps,
            "image_cache": next((d for d in ("cached_network_image", "extended_image") if d in deps), None),
            "network_images_in_lib": len(grep(r"NetworkImage\(|Image\.network\(")),
            "golden_tests": len(goldens),
            "web_platform_in_repo": (app / "web").is_dir(),
            "debug_only_routes": first(grep(r"kReleaseMode"), root),
        },
    }


def node_app(pkg: Path, root: Path) -> dict | None:
    try:
        data = json.loads(pkg.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    deps = {**data.get("dependencies", {}), **data.get("devDependencies", {})}
    if not any(k in deps for k in ("react", "next", "vue", "svelte", "@angular/core", "solid-js")):
        return None
    framework = ("next" if "next" in deps else "react" if "react" in deps else "vue" if "vue" in deps
                 else "svelte" if "svelte" in deps else "angular" if "@angular/core" in deps else "solid")
    app = pkg.parent
    return {
        "path": str(app.relative_to(root)) or ".",
        "framework": framework,
        "evidence": str(pkg.relative_to(root)),
        "versions": {k: deps[k] for k in ("next", "react", "vue", "svelte", "@angular/core") if k in deps},
        "conventions": {
            "router": "next (app/ or pages/)" if framework == "next" else
            next((d for d in ("react-router-dom", "@tanstack/react-router", "vue-router") if d in deps), None),
            "state": next((d for d in ("@reduxjs/toolkit", "redux", "zustand", "jotai", "recoil", "mobx",
                                       "@tanstack/react-query", "pinia") if d in deps), None),
            "localization": next((d for d in ("next-intl", "next-i18next", "react-i18next", "i18next",
                                              "react-intl", "vue-i18n") if d in deps), None),
            "styling": [d for d in ("tailwindcss", "styled-components", "@emotion/react", "sass",
                                    "@mui/material", "@chakra-ui/react", "@radix-ui/themes") if d in deps],
            "tailwind_config": first(sorted(app.glob("tailwind.config.*")), root),
            "image_component": "next/image" if framework == "next" else None,
            "visual_tests": [d for d in ("@playwright/test", "storybook", "@storybook/react", "chromatic",
                                         "backstopjs", "jest-image-snapshot") if d in deps],
            "dev_script": data.get("scripts", {}).get("dev"),
        },
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root", nargs="?", default=".")
    ap.add_argument("--max-depth", type=int, default=4)
    args = ap.parse_args(argv)
    root = Path(args.root).resolve()
    if not root.is_dir():
        print(json.dumps({"error": f"not a directory: {root}"}), file=sys.stderr)
        return 2
    apps, warnings = [], []
    for f in walk(root, args.max_depth):
        if f.name == "pubspec.yaml" and "flutter:" in f.read_text(encoding="utf-8", errors="replace"):
            apps.append(flutter_app(f, root))
        elif f.name == "package.json":
            app = node_app(f, root)
            if app:
                apps.append(app)
    for a in apps:
        c = a["conventions"]
        if a["framework"] == "flutter":
            if not c["localization"]["gen_l10n"]:
                warnings.append(f"{a['path']}: no gen-l10n; do not assume translated strings exist")
            if not c["web_platform_in_repo"]:
                warnings.append(f"{a['path']}: no web/ folder; web capture needs a scratch copy "
                                "(never add a platform to the repo for screenshots)")
        elif not c.get("localization"):
            warnings.append(f"{a['path']}: no i18n library found")
    print(json.dumps({"root": str(root), "apps": apps, "warnings": warnings}, indent=2))
    return 0 if apps else 3


if __name__ == "__main__":
    sys.exit(main())
