# Host target badges «تارجت» (D277): slots waiting for the owner's art

Owner (D277): «واستبدل الشارة بشارة اخرى ساقوم بارفاقها». The owner is replacing the gifts target's badge with
art they will send. Each of the host's two daily targets draws its badge from a fixed file here
(`KHostTargetBadge`, `lib/features/live/presentation/widgets/host_target_badge.dart`), on the «تارجت» chip and in
its sheet. To swap a badge, replace the file and keep its name. No code changes.

| File | Target | Now (temporary stand-in) | Source |
| ---- | ------ | ------------------------ | ------ |
| `gifts_target.png` | «هدف الهدايا» (gifts outside the lucky category, in cherries) | The Kabso cherry | `assets/currency/kabso_cherry.webp` (D182, owner-supplied; sha256 `545939d6…f49232`), re-saved as PNG at 256×256 and otherwise unchanged |
| `lucky_target.png` | «هدف هدايا الحظ» (lucky gifts, in cherries) | The D199 wizard hat | Kabso's own `WizardHatPainter` (drawn in code, no third-party art), rendered at 256×256 |

Replacement art: a square PNG with a transparent background, at least 192×192 (the chip draws it at 12–16 pt, the
sheet at 13 pt, so 256 px is enough for @3x). A missing or unreadable file falls back to the same marks drawn in
code (`KCherryIcon` / `KWizardHatIcon`). After a swap, re-run the chip and sheet goldens
(`flutter test --update-goldens test/goldens/live_target_sheet_golden_test.dart test/goldens/live_target_chip_d277_golden_test.dart`).
