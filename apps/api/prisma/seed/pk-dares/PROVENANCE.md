# «PK أحكام» dare library — provenance

- **Source:** generated for Kabso, 2026-11 (D229). Kabso's own content.
- **How:** `content.ts` holds the hand-written building blocks (Arabic and English phrases, each tagged easy /
  medium / hard); `generate.ts` composes them in 20 templates so that no two dares of a template share two of their
  three parts, drops every line the safety checker (`src/modules/live/pk-dares/pk-dare-rules.ts`) refuses or finds
  to be an exact or near duplicate, and takes a seeded, balanced sample: 20 000 dares, 6 600 easy / 6 600 medium /
  6 800 hard, nine categories.
- **Nothing copied** from other apps, sites or lists.
- **Rebuild:** `pnpm --filter @kabso/api pk-dares:generate` (deterministic: the same blocks give the same file).
- **Load:** `pk-dares-admin import` (docs/DEPLOYMENT.md §5.44). The unit test `pk-dare-library.spec.ts` runs the
  checker over the whole file (0 violations, 0 duplicates).
