import { existsSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { giftFieldProblems, giftQuipProblem, giftTagProblem } from './gift-catalogue.js';
import {
  parseQuipTexts,
  QUIP_GAP_MS,
  QUIP_GROUPS,
  QUIP_PACK,
  QUIP_PRICES,
  QUIP_SYNC_FIELDS,
  quipAssetKey,
  quipSlot,
  quipSyncPlan,
  QuipTextsError,
  type QuipSyncRow,
} from './quips.js';

/** The catalogue rows of `pack` as `quips-sync` reads them, optionally changed. */
const rowsOf = (pack = QUIP_PACK): QuipSyncRow[] =>
  pack.map((q) => ({
    code: q.code,
    category: q.category,
    priceCoins: q.priceCoins,
    tagCode: q.tagCode,
    tagNameAr: q.tagNameAr,
    tagNameEn: q.tagNameEn,
    sortOrder: q.sortOrder,
    quipText: q.quipText ?? null,
  }));

describe('quips (v1.32-live, D154; D349)', () => {
  it("the pack is the owner's 8 free sounds and 45 lines at 100 000 coins in four sub-categories", () => {
    expect(QUIP_PACK).toHaveLength(53);
    const by = (tag: string) => QUIP_PACK.filter((q) => q.tagCode === tag);
    expect(by('free')).toHaveLength(8);
    expect(by('egypt')).toHaveLength(27);
    expect(by('gulf')).toHaveLength(14);
    expect(by('jordan')).toHaveLength(4);
    expect(QUIP_PRICES).toEqual({ free: 0, egypt: 100_000, gulf: 100_000, jordan: 100_000 });
    expect(Object.values(QUIP_GROUPS).map((g) => [g.ar, g.en])).toEqual([
      ['مجانية', 'Free'],
      ['مصري', 'Egyptian'],
      ['خليجي', 'Gulf'],
      ['أردني', 'Jordanian'],
    ]);
    for (const q of QUIP_PACK) {
      const group = q.tagCode as keyof typeof QUIP_PRICES;
      expect(q.priceCoins).toBe(QUIP_PRICES[group]);
      expect([q.tagNameAr, q.tagNameEn]).toEqual([QUIP_GROUPS[group].ar, QUIP_GROUPS[group].en]);
      expect(q.category).toBe('QUIPS');
      expect(giftFieldProblems(q)).toEqual([]);
      expect(giftQuipProblem(q)).toBeNull();
      expect(giftTagProblem(q)).toBeNull();
      expect(q.assetKey).toBe(quipAssetKey(q.soundKey!));
      // Every paid line has its words (no ElevenLabs direction tag left); the free sounds have none.
      expect(q.quipText === null).toBe(group === 'free');
      expect(q.quipText ?? '').not.toMatch(/[[\]]|\s{2}/);
    }
    expect(new Set(QUIP_PACK.map((q) => q.code)).size).toBe(53);
    expect(new Set(QUIP_PACK.map((q) => q.soundKey)).size).toBe(53);
    // D154 5f: tease_02's text as the owner confirmed it; the D154 codes, names and sounds are kept.
    expect(QUIP_PACK.find((q) => q.code === 'quip_tease_02')).toMatchObject({
      nameAr: 'تريقة ٢',
      nameEn: 'Teasing 2',
      soundKey: 'kabi/tease_02',
      assetKey: 'quips/tease',
      quipText: 'إنت لو التركيز فلوس، كنت استلفت مننا.',
    });
    expect(QUIP_PACK.find((q) => q.code === 'quip_ghazal_10')?.soundKey).toBe('kabi/ghazal_10');
    expect(QUIP_PACK.find((q) => q.code === 'quip_clap')).toMatchObject({
      soundKey: 'room/clap',
      assetKey: 'quips/clap',
    });
    expect(QUIP_PACK.find((q) => q.code === 'quip_gulf_14')).toMatchObject({
      nameAr: 'خليجي ١٤',
      nameEn: 'Gulf 14',
      soundKey: 'gulf/gulf_14',
      assetKey: 'quips/gulf',
      priceCoins: 100_000,
      quipText: 'تدري وش ناقص الدنيا؟ نسخة ثانية منك، عشان إذا اشتقت لك أروح لها! 😂',
    });
    // Each code has the text of its own clip (timestamp order): the shortest Gulf clip is the shortest line.
    expect(QUIP_PACK.find((q) => q.code === 'quip_gulf_07')).toMatchObject({
      soundMs: 3997,
      quipText: 'تكفى لا تطلع، توّنا بدينا نستانس! 🥹',
    });
    expect(QUIP_PACK.find((q) => q.code === 'quip_jordan_01')).toMatchObject({
      nameAr: 'أردني ١',
      nameEn: 'Jordanian 1',
      soundKey: 'jordan/jordan_01',
      assetKey: 'quips/jordan', // gitleaks:allow (an asset name)
      quipText: 'ولك شو هالحلا؟ إنت مش بني آدم، إنت مخالفِة جمال!',
    });
  });

  it('every sound of the pack is bundled in the app, and every bundled sound is in the pack', () => {
    const dir = fileURLToPath(new URL('../../../../mobile/assets/sounds/quips/', import.meta.url));
    for (const q of QUIP_PACK) {
      const file = `${dir}${q.soundKey!}.mp3`;
      expect(existsSync(file), q.soundKey!).toBe(true);
      expect(statSync(file).size, q.soundKey!).toBeGreaterThan(10_000);
    }
    const bundled = readdirSync(dir, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .flatMap((d) => readdirSync(`${dir}${d.name}`).map((f) => `${d.name}/${f.replace(/\.mp3$/, '')}`));
    expect(bundled.sort()).toEqual(QUIP_PACK.map((q) => q.soundKey!).sort());
  });

  it('the sub-categories come in the order مجانية, مصري, خليجي, أردني (the chips follow the sort order)', () => {
    const sorted = [...QUIP_PACK].sort((a, b) => a.sortOrder - b.sortOrder);
    const chips = [...new Set(sorted.map((q) => q.tagCode))];
    expect(chips).toEqual(['free', 'egypt', 'gulf', 'jordan']);
    expect(new Set(QUIP_PACK.map((q) => q.sortOrder)).size).toBe(53);
    // «مصري» keeps D154's order: ghazal 1–10, funny 1–8, tease 1–9.
    expect(sorted.filter((q) => q.tagCode === 'egypt').map((q) => q.code.slice('quip_'.length))).toEqual([
      ...Array.from({ length: 10 }, (_, i) => `ghazal_${String(i + 1).padStart(2, '0')}`),
      ...Array.from({ length: 8 }, (_, i) => `funny_${String(i + 1).padStart(2, '0')}`),
      ...Array.from({ length: 9 }, (_, i) => `tease_${String(i + 1).padStart(2, '0')}`),
    ]);
  });

  it('quips-sync adds the missing quips and moves the D154 lines to «مصري» at 100 000; a second run plans nothing', () => {
    // A catalogue seeded by D154: the 35 quips at the old prices and tags, a custom text on one.
    const d154 = rowsOf(
      QUIP_PACK.filter((q) => q.soundKey!.startsWith('room/') || q.soundKey!.startsWith('kabi/')),
    ).map((r) =>
      r.tagCode === 'free'
        ? r
        : {
            ...r,
            priceCoins: 99,
            tagCode: 'ghazal',
            tagNameAr: 'غزل',
            tagNameEn: 'Flirty',
            sortOrder: r.sortOrder + 1,
            quipText: r.code === 'quip_ghazal_01' ? 'نص عدّله المشرف' : r.quipText,
          },
    );
    const plan = quipSyncPlan(d154);
    expect(plan.filter((s) => s.kind === 'add').map((s) => (s.kind === 'add' ? s.entry.code : ''))).toEqual(
      QUIP_PACK.filter((q) => q.tagCode === 'gulf' || q.tagCode === 'jordan').map((q) => q.code),
    );
    const updates = plan.filter((s) => s.kind === 'update');
    expect(updates).toHaveLength(27);
    for (const u of updates) {
      if (u.kind !== 'update') continue;
      // Price, sub-category and order only: the admin's text, the names and the sound are left alone.
      expect(Object.keys(u.fields).sort()).toEqual([...QUIP_SYNC_FIELDS].sort());
      expect(u.fields).toMatchObject({
        priceCoins: 100_000,
        tagCode: 'egypt',
        tagNameAr: 'مصري',
        tagNameEn: 'Egyptian',
      });
    }
    // After the sync the catalogue is the pack (but the admin's text): nothing more to do.
    const synced = rowsOf().map((r) =>
      r.code === 'quip_ghazal_01' ? { ...r, quipText: 'نص عدّله المشرف' } : r,
    );
    expect(quipSyncPlan(synced)).toEqual([]);
    // A pack code taken by a gift that is not a quip is refused.
    expect(() => quipSyncPlan([{ ...rowsOf()[0]!, category: 'POPULAR' }])).toThrow(QuipTextsError);
  });

  it("quips-sync --texts sets the named quips' texts once (idempotent); new quips get theirs when added", () => {
    const texts = parseQuipTexts({ quip_gulf_01: '  نص الخليجي ١  ', quip_ghazal_01: null }, 200);
    expect([...texts]).toEqual([
      ['quip_gulf_01', 'نص الخليجي ١'],
      ['quip_ghazal_01', null],
    ]);
    // Added with its text.
    const add = quipSyncPlan(rowsOf(QUIP_PACK.filter((q) => q.code !== 'quip_gulf_01')), texts);
    expect(add).toContainEqual({
      kind: 'add',
      entry: { ...QUIP_PACK.find((q) => q.code === 'quip_gulf_01')!, quipText: 'نص الخليجي ١' },
    });
    // Existing: only the text changes; then nothing.
    const rows = rowsOf();
    const plan = quipSyncPlan(rows, texts);
    expect(plan).toEqual([
      { kind: 'update', code: 'quip_ghazal_01', fields: { quipText: null } },
      { kind: 'update', code: 'quip_gulf_01', fields: { quipText: 'نص الخليجي ١' } },
    ]);
    const after = rows.map((r) =>
      r.code === 'quip_gulf_01'
        ? { ...r, quipText: 'نص الخليجي ١' }
        : r.code === 'quip_ghazal_01'
          ? { ...r, quipText: null }
          : r,
    );
    expect(quipSyncPlan(after, texts)).toEqual([]);
  });

  it('a texts file must be an object of pack codes to 1–max characters or null', () => {
    expect(() => parseQuipTexts([], 200)).toThrow(QuipTextsError);
    expect(() => parseQuipTexts('x', 200)).toThrow(QuipTextsError);
    expect(() => parseQuipTexts({ quip_nope: 'x' }, 200)).toThrow(/quip_nope: not a quip of the pack/);
    expect(() => parseQuipTexts({ quip_gulf_01: '   ' }, 200)).toThrow(/1–200 characters/);
    expect(() => parseQuipTexts({ quip_gulf_01: 'x'.repeat(201) }, 200)).toThrow(/1–200 characters/);
    expect(() => parseQuipTexts({ quip_gulf_01: 3 }, 200)).toThrow(/a string or null/);
    expect(parseQuipTexts({}, 200).size).toBe(0);
  });

  it("a quip starts when the room's queue is free and keeps it busy for its length plus the gap", () => {
    const now = new Date('2026-10-28T12:00:00.000Z');
    const free = quipSlot(now, null, 4000, 60_000)!;
    expect(free.delayMs).toBe(0);
    expect(free.startsAt).toEqual(now);
    expect(free.busyUntil.getTime()).toBe(now.getTime() + 4000 + QUIP_GAP_MS);
    // A queue that freed in the past counts as free.
    expect(quipSlot(now, new Date(now.getTime() - 5000), 1000, 60_000)!.delayMs).toBe(0);
    // Behind one that is playing.
    const next = quipSlot(now, free.busyUntil, 2000, 60_000)!;
    expect(next.delayMs).toBe(4000 + QUIP_GAP_MS);
    expect(next.busyUntil.getTime()).toBe(free.busyUntil.getTime() + 2000 + QUIP_GAP_MS);
    // Exactly at the limit is accepted; past it the queue is full.
    expect(quipSlot(now, new Date(now.getTime() + 60_000), 1000, 60_000)?.delayMs).toBe(60_000);
    expect(quipSlot(now, new Date(now.getTime() + 60_001), 1000, 60_000)).toBeNull();
  });
});
