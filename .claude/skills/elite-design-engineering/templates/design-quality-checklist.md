# Design quality review — <screen> (<locale>, <viewport>, <theme>, text scale <n>)

Review the **captured screenshots of the running app**, not the code. Mark each item
`pass` / `fail (critical|major|minor)` / `n/a`, with the screenshot file and a short note.
A critical item blocks "verified". Fidelity to an authorized reference wins over unrequested
redesign; when there is no reference, the existing design system wins over taste.

## Hierarchy and layout
- [ ] One clear primary focus; the main action is obvious within 2 seconds.
- [ ] Spacing uses the token scale; equal things have equal gaps; groups are separated more than items.
- [ ] Alignment: one start edge per column; nothing 1–3 px off a shared edge.
- [ ] Nothing clipped, overlapping or cut by safe areas, the status bar, the keyboard or the bottom bar.
- [ ] Density matches the product (no cramped rows, no accidental voids).

## Typography
- [ ] Sizes/weights come from the type scale; at most 3 weights visible.
- [ ] Arabic shaping correct (joined letters, ligatures, diacritics not clipped, no letter-spacing).
- [ ] Mixed Arabic/Latin and numbers read in the right order; Latin digits where the product uses them.
- [ ] Long names/titles truncate at the reading end with an ellipsis; wrapping is intentional.

## Colour, imagery and icons
- [ ] Brand colour used for emphasis only; text contrast ≥ 4.5:1 (≥ 3:1 for large text and icons).
- [ ] Images: correct aspect ratio and crop, faces/subjects inside the crop, no stretching, sharp at DPR 3.
- [ ] Icons from the project set, one stroke/fill style per context, optically centred, ≥ 48 dp targets.
- [ ] No third-party logos, watermarks or embedded UI text in images.

## States and behaviour
- [ ] Loading, empty, error/offline and populated states exist and look designed (not a lone line).
- [ ] Every visible control does something real; disabled/unavailable features are honest.
- [ ] Scroll, gestures, sheets, dialogs and back navigation behave as specified; no gesture conflicts.
- [ ] Motion is purposeful and respects reduce-motion.

## Localization and direction
- [ ] Arabic RTL and English LTR both captured; order, alignment and directional icons correct.
- [ ] Bottom navigation, tabs and back affordances mirror correctly; media is not mirrored.

## Accessibility
- [ ] Every control has a label; reading order follows the visual order; selected states announced.
- [ ] Works at text scale 1.3 (2.0 for text-heavy screens) without overflow.
- [ ] Touch targets ≥ 48 × 48 dp.

## Craft and maintainability
- [ ] Built from tokens and existing components; no one-off magic numbers without a named constant.
- [ ] No fixture data reachable from production code; debug previews labelled as test data.
- [ ] Images sized for their slot; no unnecessary large assets.

Result: <n> critical · <n> major · <n> minor open. Reviewer: <who>. Screens: <files>.
