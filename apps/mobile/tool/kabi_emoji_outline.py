"""Adds a sticker outline to the Kabi emoji Lottie files (D66).

The white body gets a thin dark outline (visible on light backgrounds), the
black antenna stalks and feet a thin white halo (visible on dark ones). The
added strokes sit under the existing paint, so only their outer half shows.
Usage: python3 -I tool/kabi_emoji_outline.py <owner_json_dir> assets/emojis
"""
import json
import sys
from pathlib import Path

INK = [0.058823529411764705, 0.058823529411764705, 0.058823529411764705, 1]
WHITE = [1, 1, 1, 1]
BODY_OUTLINE = 3.0   # outer half visible: 1.5 units
HALO = 3.0           # extra width around black strokes / fills


def stroke(color, width):
    return {"ty": "st", "nm": "outline", "c": {"a": 0, "k": color},
            "o": {"a": 0, "k": 100}, "w": {"a": 0, "k": width},
            "lc": 2, "lj": 2, "ml": 4, "bm": 0}


def static_color(item):
    k = item["c"].get("k")
    return k if isinstance(k, list) and k and not isinstance(k[0], dict) else None


def insert_before_transform(items, new):
    idx = next((i for i, it in enumerate(items) if it.get("ty") == "tr"), len(items))
    items.insert(idx, new)


def is_ink(c):
    return c is not None and all(abs(a - b) < .02 for a, b in zip(c[:3], INK[:3]))


def process(doc):
    added = 0
    for layer in doc["layers"]:
        name = layer.get("nm")
        for group in layer.get("shapes", []):
            items = group.get("it", [])
            fills = [it for it in items if it.get("ty") == "fl"]
            strokes = [it for it in items if it.get("ty") == "st"]
            if name in ("body", "puddle") and fills:
                insert_before_transform(items, stroke(INK, BODY_OUTLINE))
                added += 1
            elif name in ("antL", "antR") and strokes and is_ink(static_color(strokes[0])):
                w = strokes[0]["w"].get("k", 5.5)
                insert_before_transform(items, stroke(WHITE, w + HALO))
                added += 1
            elif name == "feet" and fills and is_ink(static_color(fills[0])):
                insert_before_transform(items, stroke(WHITE, HALO))
                added += 1
    return added


def main(src, dst):
    out = Path(dst)
    out.mkdir(parents=True, exist_ok=True)
    for f in sorted(Path(src).glob("kabi_*.json")):
        doc = json.loads(f.read_text())
        n = process(doc)
        (out / f.name).write_text(json.dumps(doc, separators=(",", ":")))
        print(f.name, "strokes added:", n)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
