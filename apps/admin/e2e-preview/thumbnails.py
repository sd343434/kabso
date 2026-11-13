"""D356: the PNG captures of thumbnails.spec.ts -> small WebP thumbnails (2x of the picker's 92 x 120 box; layouts 92 x 200).

    python3 -I e2e-preview/thumbnails.py IN_DIR OUT_DIR
"""
import pathlib
import sys

from PIL import Image

src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
dst.mkdir(parents=True, exist_ok=True)
for png in sorted(src.glob('*.png')):
    im = Image.open(png).convert('RGB')
    w, h = (184, 400) if png.stem.startswith('layout-') else (184, 240)
    # Cover: scale to the box's width, crop the height from the top.
    scale = w / im.width
    im = im.resize((w, max(h, round(im.height * scale))), Image.LANCZOS).crop((0, 0, w, h))
    im.save(dst / f'{png.stem}.webp', 'WEBP', quality=72, method=6)
    print(png.stem, (dst / f'{png.stem}.webp').stat().st_size)
