# Kabso Live — Claude instructions

The project rules live in `docs/AI_WORKFORCE_BOARD.md` (decision log D1+), `docs/contracts/` (contract-first;
`CONVENTIONS.md`, `openapi.yaml`, `design-tokens.json`) and `docs/PRE_PRODUCTION_CHECKLIST.md`. Follow them.
This file adds only the following.

## Implementing UI from a screenshot

When the user supplies a reference screenshot and asks for a faithful implementation ("match this",
"make it look like this", "pixel-perfect"), use the skill **`pixel-perfect-ui-workflow`**
(`.claude/skills/pixel-perfect-ui-workflow/SKILL.md`).

That skill runs the specialist skills in order:
1. `pixel-perfect-reference-analyzer`
2. `asset-and-typography-forensics`
3. `reference-to-flutter-implementer`
4. `rtl-ltr-visual-specialist`
5. `screenshot-diff-and-visual-regression`

It enforces gates A–G. Compiling or passing tests is not completion: the real app must be captured and compared.

For any other UI work that must be verified visually (no reference, polishing a screen, a composite
reference, or a non-Flutter stack), start with **`elite-design-engineering`**
(`.claude/skills/elite-design-engineering/SKILL.md`): it audits the stack, then drives the skills above.

Keep these four things separate:
- **Visual reference fidelity:** match the authorized reference as measured.
- **Functional behaviour:** real routing, state, API and honest states are never replaced by fixtures.
- **Responsive adaptation:** other widths (360×800), text scales, Arabic RTL and English LTR are checked separately.
- **Authorized reference assets:** a screenshot is NOT permission to copy another product's logo, wordmark,
  mascot, icons, illustrations or user photos. Use Kabso assets or ask for them.

The repository is public (D40). Third-party reference screenshots, and anything showing real users, stay out of git.
