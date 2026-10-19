---
name: rtl-ltr-visual-specialist
description: Verify Arabic RTL and English LTR layout fidelity in Kabso Live Flutter screens — direction, logical alignment, mixed Arabic/Latin text and numbers, ellipsis placement, wrapping and font metrics, navigation order and selected states, directional icons and back behaviour, semantics, small viewports and safe areas. Use during IMPLEMENT and RETEST of pixel-perfect-ui-workflow and for any bilingual UI change.
---

# RTL / LTR visual specialist

Applying `TextDirection.rtl` to a screen does NOT make it a correct Arabic layout. Check every item
below in **both** `ar` and `en`, at 393×852 and 360×800, with text scale 1.0 and 1.3 (ar), and 2.0
for text-heavy screens.

## Checklist

1. **Direction and mirroring.**
   - The layout mirrors via `EdgeInsetsDirectional`, `AlignmentDirectional` and `start`/`end`.
   - Things that must NOT mirror: media timelines, phone numbers, logos, brand wordmarks, and the content of photos. In bidi text, numbers and Latin runs stay LTR.
2. **Logical alignment.**
   - Each text aligns to its own script inside a card.
   - `KUserText` (`design_system/components/k_user_text.dart`) picks the direction from the first strong character. It arrives with KL-050 (branch `a2/kl-050-room-fixes`) and is not on the default branch until that merges, so check that the file exists first. Otherwise set `textDirection` per text yourself.
   - Check for mixed alignments inside one card (a known open observation, N-2).
3. **Mixed Arabic/Latin titles and numbers.**
   - Test strings such as `Learning Arabic calligraphy, lesson 3 — …` in the ar UI and `تحدي الشطرنج …` in the en UI.
   - Check that punctuation stays with its run, and that numbers (viewer counts, levels, times) use the intended digits.
4. **Ellipsis.**
   - Truncation happens at the logical end of the text's own direction ("…" on the left for Arabic, on the right for Latin).
   - Never show a leading ellipsis like "…Learning".
5. **Wrapping and metrics.**
   - Arabic glyphs are taller (IBM Plex Sans Arabic): check line height, clipping of descenders and diacritics, and `maxLines`.
   - Nothing overflows at 360 dp with text scale 1.3. Run the overflow tests.
6. **Navigation.**
   - Bottom-nav and tab order mirror. Selected indicators sit under the right item.
   - Swipe direction follows the reading direction.
   - The center action stays centred.
7. **Directional icons.** Back and forward chevrons and arrows flip; use `Icons.arrow_back` with automatic mirroring or `Directionality`-aware icons. Android back and the iOS swipe-back still work.
8. **Semantics.** Screen-reader labels are localized, contain no raw keys, and read in the right order. Badges and counts have labels.
9. **Insets and small screens.** Safe areas and the floating nav don't cover content in either direction.

## How to verify

- **Widget tests:** pump both locales and assert positions (`tester.getTopLeft`) for start/end placement. Add an overflow test at 360 dp with ar at scale 1.3.
- **Goldens:** `test/goldens/` already run ar/en at 393×852 and 360×800. Update them, with reasons.
- **Real-app captures** (`screenshot-diff-and-visual-regression`) in both locales, using the reference locale's image for the comparison.
- **Report:** one line per checklist item, PASS or FAIL with evidence (test name or image).
