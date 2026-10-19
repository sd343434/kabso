---
name: asset-and-typography-forensics
description: Inventory and match the assets and typography a reference screenshot needs — project images/SVGs/icon fonts/bundled fonts, exact asset identification, dimensions/aspect/transparency/crop, font family/weight/fallback — and record missing or unauthorized assets instead of approximating. Use inside the SPECIFY step of pixel-perfect-ui-workflow or whenever a screen needs a specific image, icon or font.
---

# Asset and typography forensics

## 1. Inventory (run every time; the project changes)

```bash
cd apps/mobile
find assets -type f | sort                                   # images, fonts, other assets
grep -n "assets:\|fonts:\|family:\|asset:" pubspec.yaml      # what is actually bundled
grep -rn "Icons\.\|CupertinoIcons\.\|SvgPicture\|Image.asset" lib | wc -l   # icon and image usage
python3 ../../.claude/skills/pixel-perfect-ui-workflow/scripts/measure.py info <image> --logical-width <w>
```

At the time this skill was written, the only bundled assets were fonts:
- Inter 400/600/700;
- IBM Plex Sans Arabic 400/600/700.

Icons come from Material `Icons`. There is no emoji font, no SVG package and no image assets. Re-check before relying on this.

## 2. For each asset in the reference

| Question | How |
| -------- | --- |
| Does the exact asset exist in the project? | inventory plus visual comparison (`measure.py crop --scale 8`) |
| What are its size, aspect, transparency and crop? | `measure.py info`, `bbox`, alpha check; record fit (cover/contain) and focal point |
| Is it ours to use? | Kabso-owned or licensed → OK. A third-party logo, mascot, proprietary icon, illustration or user photo → **do not copy** |
| If it's missing, what's the source? | Ask the owner for the original file (SVG/PNG at 3x) or for a licensed alternative. Record it as a blocker |

- Material icons are acceptable substitutes only when the owner accepts the visual difference. Record the difference (shape, stroke, size).
- Never use emoji as a substitute for a designed icon: they render as boxes without an emoji font, and they differ per platform.
- Placeholder images are allowed only in tests and the preview gallery, labelled. They never stand in for an approved original that exists.
- Never download copyrighted or proprietary assets, stock photos or fonts without authorization and a recorded licence.

## 3. Typography

1. **Family.**
   - Compare letterforms in a zoomed crop: Latin `a g R 1`, Arabic `ك ه ي`.
   - Only Inter and IBM Plex Sans Arabic are bundled. A reference using another family (e.g. SF Pro on iOS) can only be approximated. Record it as **E** and as a blocker for exactness.
2. **Size.** Cap height (px) ÷ DPR ÷ the font's cap-height ratio → font size (**E**). Read the ratios from the font files (fontTools isn't installed; get the OS/2 `sCapHeight` from the font if a tool is available, otherwise mark the value **E**).
3. **Weight.** Compare stem width with test renders of the bundled weights at the same size: 400/600/700 are available. 500 and 800 are not, so record the nearest weight.
4. **Line height.** Measure the baseline-to-baseline pitch for multi-line text.
5. **Fallback.** If a script or glyph isn't covered (emoji, rare symbols), Flutter falls back to a platform font in a device build and to boxes in headless tests. Record it.

## Output

An asset table (inside the spec §6) and a typography table with tags:

| Column | Meaning |
| ------ | ------- |
| element | the text element being matched |
| reference measurement | what was measured on the reference |
| chosen family/size/weight/height | what the implementation uses |
| M/E | measured or estimated |
| gap | the difference that remains |
| blocker | yes/no, and why |
