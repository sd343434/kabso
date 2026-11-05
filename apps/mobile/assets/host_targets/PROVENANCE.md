# Host target badges «تارجت» (D277): slots waiting for the owner's art

Owner (D277): «واستبدل الشارة بشارة اخرى ساقوم بارفاقها». The owner is replacing the gifts target's badge with
art they will send. Each of the host's two daily targets draws its badge from a fixed file here
(`KHostTargetBadge`, `lib/features/live/presentation/widgets/host_target_badge.dart`), on the «تارجت» chip and in
its sheet. To swap a badge, replace the file and keep its name. No code changes.

| File | Target | Now (temporary stand-in) | Source |
| ---- | ------ | ------------------------ | ------ |
| `gifts_target.png` | «هدف الهدايا» (gifts outside the lucky category, in cherries) | The gift box (owner, 2026-11-05: «ضع محل الكرز صندوق الهدايا لكن بنفس حجم الكرز») | `assets/live_bar/bar_gift.png` (D135, owner-supplied): trimmed to its visible box and scaled to fill 246 px of a 256×256 transparent square, so it reads at the cherry's size |
| `lucky_target.png` | «هدف هدايا الحظ» (lucky gifts, in cherries) | The D199 wizard hat | Kabso's own `WizardHatPainter` (drawn in code, no third-party art), rendered at 256×256 |

Replacement art: a square PNG with a transparent background, at least 192×192 (the chip draws it at 12–16 pt, the
sheet at 13 pt, so 256 px is enough for @3x). A missing or unreadable file falls back to the same marks drawn in
code (`KCherryIcon` / `KWizardHatIcon`). After a swap, re-run the chip and sheet goldens
(`flutter test --update-goldens test/goldens/live_target_sheet_golden_test.dart test/goldens/live_target_chip_d277_golden_test.dart`).
