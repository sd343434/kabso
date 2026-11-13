# Support tier avatar frames (owner-supplied, 2026-10-30)

Supplied by the owner in chat («هذه الإطارات لكل فئة من فئات مستوى الدعم، يحصل عليها المستخدم عند
وصوله فئة جديدة», D169): one AI-generated sheet, 1125×750 RGBA, 20 avatar frames in 4 rows of 5,
rising rank, each with an empty transparent centre for the photo. The sheet stays outside git.

Sliced by alpha (threshold 32) with no other change than trimming and resizing: the five columns
are separated by clear gaps; the rows touch at the frames' diamond tips (7–14 px of contact on the
cut row, no body overlap), so each column was cut at its thinnest row in each band; faint haze
outside a frame's box was dropped. Each frame is scaled so its longer side is 256 px and centred on a
transparent 256×256 canvas (`support_frame_NN.webp`, WebP q90).

`support_frame_21.webp` (tier 21, level 100): a separate owner-supplied AI-generated image sent
the same day (1254×1254 RGBA, transparent background and hole, the crimson-and-gold winged crown
frame), trimmed and scaled the same way.

The bag item code and `assetKey` are both `support_frame_NN` (`bag_category` `AVATAR_FRAME`).

Mapping (owner, 2026-10-30): frame NN for support tier NN, tiers 1–21 (levels 1–5 … 96–99, 100).
Frames are kept for good once earned (owner).

The photo's hole, as fractions of the 256-px canvas (centre x, centre y, width, height):

| Frame | cx | cy | w | h |
| ----- | -- | -- | - | - |
| 01 | 0.498 | 0.583 | 0.562 | 0.473 |
| 02 | 0.503 | 0.580 | 0.539 | 0.457 |
| 03 | 0.492 | 0.572 | 0.531 | 0.453 |
| 04 | 0.496 | 0.579 | 0.531 | 0.453 |
| 05 | 0.492 | 0.575 | 0.539 | 0.461 |
| 06 | 0.498 | 0.561 | 0.512 | 0.422 |
| 07 | 0.501 | 0.553 | 0.512 | 0.410 |
| 08 | 0.491 | 0.552 | 0.492 | 0.398 |
| 09 | 0.497 | 0.559 | 0.512 | 0.414 |
| 10 | 0.493 | 0.558 | 0.512 | 0.414 |
| 11 | 0.500 | 0.555 | 0.512 | 0.414 |
| 12 | 0.494 | 0.554 | 0.512 | 0.406 |
| 13 | 0.495 | 0.555 | 0.492 | 0.391 |
| 14 | 0.495 | 0.557 | 0.508 | 0.410 |
| 15 | 0.495 | 0.554 | 0.508 | 0.410 |
| 16 | 0.499 | 0.458 | 0.469 | 0.387 |
| 17 | 0.494 | 0.457 | 0.465 | 0.387 |
| 18 | 0.498 | 0.458 | 0.480 | 0.391 |
| 19 | 0.496 | 0.455 | 0.461 | 0.391 |
| 20 | 0.491 | 0.454 | 0.469 | 0.387 |
| 21 | 0.498 | 0.498 | 0.480 | 0.391 |
