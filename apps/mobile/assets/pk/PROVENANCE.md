# PK art (owner-supplied)

| File | Source | Used for |
| ---- | ------ | -------- |
| `kabi_pk.json` | Owner-supplied Lottie (D73) | Kabi on D195's KabsoPkBar (no longer on the battle screen since D199; kept for its widget and tests) |
| `pk_power_double.png`, `pk_power_double_turbo.png`, `pk_power_triple.png`, `pk_power_triple_turbo.webp` | Owner's `kabso_pk_powers` pack (2026-10-31, second version), used as supplied | The booster banners (D199): «دبل» / «دبل تيربو» / «تربل» / «تربل تيربو», Kabi in the centre |
| `score_bar/parts/frame_neutral_L.png`, `frame_neutral_R.png`, `frameL_t1..t4.png`, `emblem_t1..t4.png` | Same pack, used as supplied | The PK battle bar (D199): neutral frames; the boosted side's tier frame (mirrored on the right) and the highest tier's PK emblem |
| `score_bar/kabi/kabi_push.png`, `kabi_pull.png`, `kabi_win.png` | Same pack, used as supplied | Kabi on the battle bar's seam: push (side gains), pull (side loses), win (big lead, or the winner at the end) |

The owner's pack also held Dart widgets (adapted into
`lib/features/live/presentation/widgets/pk_power/`), widget tests (adapted into
`test/features/live/pk_power/`) and reference videos (`pk_powers_4tiers.mp4`, `pk_score_line_4tiers.mp4`,
`pk_battle_bar_kabi.mp4`), which stay outside git. Re-encoding the PNGs as lossless WebP saved only about 15 %
(40–55 KB each), so the files are kept as supplied.
