/**
 * D229 «PK أحكام»: builds Kabso's dare library (generated for Kabso, 2026-11) from the hand-written blocks in
 * `content.ts` and writes `pk-dares.v1.jsonl` (one dare per line). Run: `pnpm --filter @kabso/api pk-dares:generate`.
 *
 * Each template joins three lists. So that no two dares of one template are near copies, the generator never
 * makes two dares that share two of the three slots: two lists are free and the third (the largest) is
 * derived, z = (x + y) mod |Z| — any two dares of a template differ in at least two slots. Then every dare must pass
 * the hard safety rules (`checkDareSafety`: blocklist + rules, Arabic ≤ 90 characters) and the duplicate check
 * (`findDuplicates`: exact, or a word-set Jaccard ≥ 0.8 in either language) against every earlier dare; the rest are
 * dropped (counted). Finally a seeded sample balances the nine categories and the three levels (owner: about a
 * third each: easy 33 %, medium 33 %, hard 34 %). Deterministic: the same content gives the same file.
 */
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  PK_DARE_CATEGORIES,
  checkDareSafety,
  findDuplicates,
  type PkDareCategory,
  type PkDareImport,
  type PkDareLevel,
} from '../../../src/modules/live/pk-dares/pk-dare-rules.js';
import * as C from './content.js';
import type { Item, Tag } from './content.js';

interface Template {
  readonly id: string;
  readonly category: PkDareCategory;
  readonly lists: readonly [Item[], Item[], Item[]];
  readonly ar: (a: Item, b: Item, c: Item) => string;
  readonly en: (a: Item, b: Item, c: Item) => string;
  /** The level when it does not come from the items' tags. */
  readonly level?: PkDareLevel;
}

/** Whether an Arabic noun phrase is grammatically feminine (its first word ends in ة or ات). */
const feminine = (ar: string) => /(ة|ات)$/.test(ar.split(' ')[0]!);

/** Number / seconds pairs for the quiz (48 of them, as a list the code can derive from). */
const COUNTS: Item[] = [];
for (const n of [5, 6, 7, 8, 9, 10, 12, 15]) {
  for (const t of [20, 30, 40, 45, 50, 60]) {
    COUNTS.push({ ar: `${n}|${t}`, en: `${n}|${t}`, tag: n >= 15 ? 'h' : n >= 10 && t <= 30 ? 'm' : 'e' });
  }
}
const nOf = (i: Item) => i.ar.split('|')[0]!;
const tOf = (i: Item) => i.ar.split('|')[1]!;

export const TEMPLATES: readonly Template[] = [
  {
    id: 'imitate-animal',
    category: 'IMITATION',
    lists: [C.ANIMALS, C.ACTIVITIES, C.STYLE],
    ar: (a, b, c) => `تقليد ${a.ar} أثناء ${b.ar} ${c.ar}`,
    en: (a, b, c) => `Imitate ${a.en} ${b.en}, ${c.en}`,
  },
  {
    id: 'imitate-winner',
    category: 'IMITATION',
    lists: [C.TOPICS, C.GESTURES, C.STYLE],
    ar: (a, b, c) => `تقليد كلام الفائز عن ${a.ar} ${b.ar} ${c.ar}`,
    en: (a, b, c) => `Imitate how the winner talks about ${a.en}, ${b.en}, ${c.en}`,
    level: 'HARD',
  },
  {
    id: 'act-role',
    category: 'ACTING',
    lists: [C.CHARACTERS, C.SITUATIONS, C.STYLE],
    ar: (a, b, c) => `تمثيل دور ${a.ar} ${b.ar} ${c.ar}`,
    en: (a, b, c) => `Act as ${a.en} ${b.en}, ${c.en}`,
  },
  {
    id: 'act-mime',
    category: 'ACTING',
    lists: [C.MIME_ACTIONS, C.PLACES, C.EMOTIONS],
    ar: (a, b, c) => `مشهد صامت: ${a.ar} ${b.ar} ${c.ar}`,
    en: (a, b, c) => `Silent scene: ${a.en} ${b.en}, ${c.en}`,
  },
  {
    id: 'sing-topic',
    category: 'SINGING',
    lists: [C.SONG_TYPES, C.TOPICS, C.STYLE],
    ar: (a, b, c) => `غناء ${a.ar} عن ${b.ar} ${c.ar}`,
    en: (a, b, c) => `Sing ${a.en} about ${b.en}, ${c.en}`,
  },
  {
    id: 'sing-whole',
    category: 'SINGING',
    lists: [C.TOPICS, C.SONG_TYPES, C.EMOTIONS],
    ar: (a, b, c) => `غناء ${b.ar} كاملة عن ${a.ar} بصوت عالٍ وتمثيل ${c.ar}`,
    en: (a, b, c) => `Sing ${b.en} about ${a.en} all the way through, loudly and acted out, ${c.en}`,
    level: 'HARD',
  },
  {
    id: 'talk-speech',
    category: 'TALK',
    lists: [C.SPEECH_KINDS, C.TOPICS, C.STYLE],
    ar: (a, b, c) => `${a.ar} لمدة دقيقة عن ${b.ar} ${c.ar}`,
    en: (a, b, c) => `Give ${a.en} for one minute about ${b.en}, ${c.en}`,
  },
  {
    id: 'talk-explain',
    category: 'TALK',
    lists: [C.TASKS, C.AUDIENCES, C.STYLE],
    ar: (a, b, c) => `شرح ${a.ar} لـ${b.ar} ${c.ar}`,
    en: (a, b, c) => `Explain ${a.en} to ${b.en}, ${c.en}`,
  },
  {
    id: 'talk-rule',
    category: 'TALK',
    lists: [C.SPEECH_RULES, C.SPEECH_EXTRAS, C.SPEECH_EXTRAS],
    ar: (a, b) => `الكلام ${a.ar} ${b.ar}`,
    en: (a, b) => `Speak ${a.en} ${b.en}`,
    level: 'HARD',
  },
  {
    id: 'truth-question',
    category: 'TRUTH',
    lists: [C.STEMS, C.DOMAINS, C.ANSWER_MANNERS],
    ar: (a, b, c) => `سؤال صراحة: ${a.ar} ${b.ar}؟ الإجابة ${c.ar}`,
    en: (a, b, c) => `Truth: ${a.en} ${b.en}? Answer ${c.en}.`,
  },
  {
    id: 'truth-confess',
    category: 'TRUTH',
    lists: [C.CONFESS_STEMS, C.DOMAINS, C.ANSWER_MANNERS],
    ar: (a, b, c) => `${a.ar} ${b.ar}، ${c.ar}`,
    en: (a, b, c) => `${a.en} ${b.en}, ${c.en}`,
    level: 'HARD',
  },
  {
    id: 'dance-rhythm',
    category: 'DANCE_LIGHT',
    lists: [C.DANCES, C.RHYTHMS, C.DANCE_MODS],
    ar: (a, b, c) => `أداء ${a.ar} على إيقاع ${b.ar} ${c.ar}`,
    en: (a, b, c) => `Do ${a.en} to ${b.en}, ${c.en}`,
  },
  {
    id: 'dance-invent',
    category: 'DANCE_LIGHT',
    lists: [C.DANCE_NAMES, C.BODY_PARTS, C.STYLE],
    ar: (a, b, c) => `ابتكار رقصة اسمها ${a.ar} بـ${b.ar} فقط ${c.ar}`,
    en: (a, b, c) => `Invent a dance called ${a.en} using only your ${b.en}, ${c.en}`,
  },
  {
    id: 'dance-victory',
    category: 'DANCE_LIGHT',
    lists: [C.DANCES, C.DANCE_MODS, C.STYLE],
    ar: (a, b, c) => `أداء ${a.ar} احتفالاً بالفائز ${b.ar} ${c.ar}`,
    en: (a, b, c) => `Do ${a.en} to celebrate the winner, ${b.en}, ${c.en}`,
    level: 'HARD',
  },
  {
    id: 'funny-present',
    category: 'FUNNY',
    lists: [C.OBJECTS, C.IMAGINARY, C.STYLE],
    ar: (a, b, c) => `تقديم ${a.ar} على ${feminine(a.ar) ? 'أنها' : 'أنه'} ${b.ar} ${c.ar}`,
    en: (a, b, c) => `Present ${a.en} as ${b.en}, ${c.en}`,
  },
  {
    id: 'funny-forbidden',
    category: 'FUNNY',
    lists: [C.TOPICS, C.FORBIDDEN, C.PENALTIES],
    ar: (a, b, c) => `الحديث دقيقة عن ${a.ar} دون قول ${b.ar}، ${c.ar}`,
    en: (a, b, c) => `Talk for a minute about ${a.en} without saying ${b.en}; ${c.en}`,
  },
  {
    id: 'quiz-name',
    category: 'QUIZ',
    lists: [C.QUIZ_CATS, C.QUIZ_MANNERS, COUNTS],
    ar: (a, b, c) => `ذكر ${nOf(c)} ${a.ar} خلال ${tOf(c)} ثانية ${b.ar}`,
    en: (a, b, c) => `Name ${nOf(c)} ${a.en} in ${tOf(c)} seconds, ${b.en}`,
  },
  {
    id: 'quiz-winner',
    category: 'QUIZ',
    lists: [C.TOPICS, C.QUIZ_MANNERS, COUNTS],
    ar: (a, b, c) => `الإجابة عن ${nOf(c)} أسئلة من الفائز عن ${a.ar} خلال ${tOf(c)} ثانية ${b.ar}`,
    en: (a, b, c) => `Answer ${nOf(c)} questions from the winner about ${a.en} in ${tOf(c)} seconds, ${b.en}`,
    level: 'HARD',
  },
  {
    id: 'draw-thing',
    category: 'DRAWING',
    lists: [C.DRAW_SUBJECTS, C.DRAW_RULES, C.SHOW_MANNERS],
    ar: (a, b, c) => `رسم ${a.ar} ${b.ar} ${c.ar}`,
    en: (a, b, c) => `Draw ${a.en} ${b.en}, ${c.en}`,
  },
  {
    id: 'draw-winner',
    category: 'DRAWING',
    lists: [C.DRAW_AS, C.DRAW_RULES, C.SHOW_MANNERS],
    ar: (a, b, c) => `رسم وجه الفائز ${a.ar} ${b.ar} ${c.ar}`,
    en: (a, b, c) => `Draw the winner's face ${a.en} ${b.en}, ${c.en}`,
    level: 'HARD',
  },
];

const RANK: Record<Tag, number> = { e: 0, m: 1, h: 2 };
const LEVEL_OF: readonly PkDareLevel[] = ['EASY', 'MEDIUM', 'HARD'];

interface Candidate extends Omit<PkDareImport, 'code'> {
  readonly template: string;
}

/** Every combination of a template with any two dares differing in at least two slots. */
export function expand(t: Template): Candidate[] {
  const sizes = t.lists.map((l) => l.length);
  const z = sizes.indexOf(Math.max(...sizes));
  const [xi, yi] = [0, 1, 2].filter((i) => i !== z) as [number, number];
  const X = t.lists[xi]!;
  const Y = t.lists[yi]!;
  const Z = t.lists[z]!;
  if (Z.length < Math.max(X.length, Y.length)) throw new Error(`${t.id}: derived list too short`);
  // `talk-rule` uses the same list twice: one dare per rule (x), paired with one extra.
  const pairs: [number, number][] = [];
  if (t.lists[1] === t.lists[2]) X.forEach((_, x) => pairs.push([x, x % Y.length]));
  else for (let x = 0; x < X.length; x += 1) for (let y = 0; y < Y.length; y += 1) pairs.push([x, y]);
  const out: Candidate[] = [];
  for (const [x, y] of pairs) {
    const slots: Item[] = [];
    slots[xi] = X[x]!;
    slots[yi] = Y[y]!;
    slots[z] = Z[(x + y) % Z.length]!;
    const [a, b, c] = slots as [Item, Item, Item];
    const level = t.level ?? LEVEL_OF[Math.max(RANK[a.tag], RANK[b.tag], RANK[c.tag])]!;
    out.push({
      template: t.id,
      category: t.category,
      level,
      textAr: t.ar(a, b, c).replace(/\s+/g, ' ').trim(),
      textEn: t.en(a, b, c).replace(/\s+/g, ' ').trim(),
    });
  }
  return out;
}

/** Mulberry32: a small seeded generator (the same file every run). */
function rng(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffle<T>(items: T[], random: () => number): T[] {
  for (let i = items.length - 1; i > 0; i -= 1) {
    const j = Math.floor(random() * (i + 1));
    [items[i], items[j]] = [items[j]!, items[i]!];
  }
  return items;
}

export const TARGET = 20000;
export const LEVEL_SHARE: Record<PkDareLevel, number> = { EASY: 0.33, MEDIUM: 0.33, HARD: 0.34 };

export function generate(): { dares: PkDareImport[]; report: Record<string, unknown> } {
  const random = rng(229);
  const all = TEMPLATES.flatMap(expand);
  let unsafe = 0;
  const safe = all.filter((d) => {
    const ok = checkDareSafety(d).length === 0;
    if (!ok) unsafe += 1;
    return ok;
  });
  // Duplicates: of each pair the later one goes (the pool is shuffled first so no template is favoured).
  shuffle(safe, random);
  const dup = new Set(findDuplicates(safe).map((p) => Math.max(p.a, p.b)));
  const pool = safe.filter((_, i) => !dup.has(i));
  // Balance: per level its share of TARGET, spread evenly over the categories, any shortfall taken from the
  // categories with the most left at that level.
  const chosen: Candidate[] = [];
  for (const level of LEVEL_OF) {
    const target =
      level === 'HARD'
        ? TARGET - Math.round(TARGET * LEVEL_SHARE.EASY) - Math.round(TARGET * LEVEL_SHARE.MEDIUM)
        : Math.round(TARGET * LEVEL_SHARE[level]);
    const byCat = new Map<PkDareCategory, Candidate[]>(
      PK_DARE_CATEGORIES.map((c) => [c, pool.filter((d) => d.level === level && d.category === c)]),
    );
    const take = new Map<PkDareCategory, number>(PK_DARE_CATEGORIES.map((c) => [c, 0]));
    let left = target;
    while (left > 0) {
      const open = PK_DARE_CATEGORIES.filter((c) => take.get(c)! < byCat.get(c)!.length);
      if (open.length === 0) break;
      // The category with the fewest taken so far (ties: the most available) gets the next one.
      open.sort((a, b) => take.get(a)! - take.get(b)! || byCat.get(b)!.length - byCat.get(a)!.length);
      take.set(open[0]!, take.get(open[0]!)! + 1);
      left -= 1;
    }
    for (const c of PK_DARE_CATEGORIES) chosen.push(...byCat.get(c)!.slice(0, take.get(c)));
  }
  const dares: PkDareImport[] = [];
  const counters = new Map<string, number>();
  for (const c of PK_DARE_CATEGORIES) {
    for (const level of LEVEL_OF) {
      for (const d of chosen.filter((x) => x.category === c && x.level === level)) {
        const prefix = `${c.toLowerCase().replace('_', '-')}`;
        const n = (counters.get(prefix) ?? 0) + 1;
        counters.set(prefix, n);
        dares.push({
          code: `v1-${prefix}-${String(n).padStart(5, '0')}`,
          category: d.category,
          level: d.level,
          textAr: d.textAr,
          textEn: d.textEn,
        });
      }
    }
  }
  const count = (key: (d: PkDareImport) => string) =>
    dares.reduce<Record<string, number>>((m, d) => ({ ...m, [key(d)]: (m[key(d)] ?? 0) + 1 }), {});
  return {
    dares,
    report: {
      combinations: all.length,
      droppedUnsafe: unsafe,
      droppedDuplicates: dup.size,
      pool: pool.length,
      written: dares.length,
      byLevel: count((d) => d.level),
      byCategory: count((d) => d.category),
    },
  };
}

const here = dirname(fileURLToPath(import.meta.url));
if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const { dares, report } = generate();
  writeFileSync(
    join(here, 'pk-dares.v1.jsonl'),
    dares.map((d) => JSON.stringify(d)).join('\n') + '\n',
    'utf8',
  );
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
}
