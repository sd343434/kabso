/**
 * v1.50-live (D229, CONVENTIONS §10.80): the «PK أحكام» dare library's rules that need no database — the text
 * normalizer, the hard safety rules (a blocklist plus rule checks), exact and near-duplicate detection. Shared by
 * the generator (`prisma/seed/pk-dares/generate.ts`), the `pk-dares-admin` CLI, the admin panel's create / edit /
 * import and the unit test that runs over the whole seed file. No Nest or Prisma dependency here.
 */

export const PK_DARE_CATEGORIES = [
  'FUNNY',
  'SINGING',
  'ACTING',
  'TALK',
  'TRUTH',
  'DANCE_LIGHT',
  'IMITATION',
  'QUIZ',
  'DRAWING',
] as const;
export type PkDareCategory = (typeof PK_DARE_CATEGORIES)[number];

/** Owner (D229): three levels, about a third each; the result shows one of each. */
export const PK_DARE_LEVELS = ['EASY', 'MEDIUM', 'HARD'] as const;
export type PkDareLevel = (typeof PK_DARE_LEVELS)[number];

/** A dare as the library stores it (the seed file's line, without the database's own columns). */
export interface PkDareText {
  readonly textAr: string;
  readonly textEn: string;
}

export const PK_DARE_MAX_AR = 90;
export const PK_DARE_MAX_EN = 140;
/** A dare must be doable within the 3-minute timer: no stated duration longer than this. */
export const PK_DARE_MAX_STATED_SECONDS = 180;

const ARABIC_DIACRITICS = /[ؐ-ًؚ-ٰٟۖ-ۭـ]/g;

/** Arabic: no diacritics or tatweel, one alef, ى → ي, ة → ه; Latin lower case; punctuation → space; one space. */
export function normalizeDareText(text: string): string {
  return text
    .normalize('NFKC')
    .replace(ARABIC_DIACRITICS, '')
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/ؤ/g, 'و')
    .replace(/ئ/g, 'ي')
    .toLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

/** The words of a normalized text, Arabic one-letter prefixes (و ب ل) and the article (ال) also stripped. */
export function dareTokens(text: string): string[] {
  const words = normalizeDareText(text)
    .split(' ')
    .filter((w) => w.length > 0);
  const out: string[] = [];
  for (const w of words) {
    out.push(w);
    if (/^\p{Script=Arabic}/u.test(w)) {
      let s = w;
      if (s.length > 3 && /^[وبل]/.test(s)) s = s.slice(1);
      if (s.length > 3 && s.startsWith('ال')) s = s.slice(2);
      if (s !== w) out.push(s);
    }
  }
  return out;
}

/**
 * The hard rules (owner D229). Each entry: a rule name and the blocked words — Arabic ones match a whole word
 * after the prefixes are stripped (or as written), Latin ones match a whole word or, ending in `*`, a word start.
 */
const BLOCKLIST: Record<string, readonly string[]> = {
  danger: [
    'نار',
    'حريق',
    'ولاعه',
    'ولاعة',
    'شمعه',
    'شمعة',
    'سكين',
    'سكاكين',
    'مقص',
    'شفره',
    'شفرة',
    'كهرباء',
    'مقبس',
    'سطح',
    'شرفه',
    'شرفة',
    'نافذه',
    'نافذة',
    'مرتفع',
    'ارتفاع',
    'قفز',
    'القفز',
    'شقلبه',
    'شقلبة',
    'دم',
    'جرح',
    'خنق',
    'حبل',
    'خطير',
    'خطيره',
    'خطر',
    'تسلق',
    'ركض',
    'دوران',
    'غاز',
    'زجاج',
    'ثلج',
    'حبس',
    'fire',
    'flame*',
    'lighter',
    'candle*',
    'knife',
    'knives',
    'scissor*',
    'blade*',
    'razor*',
    'electric*',
    'socket*',
    'roof*',
    'balcony',
    'window*',
    'height*',
    'jump*',
    'climb*',
    'blood*',
    'cut',
    'choke*',
    'rope*',
    'danger*',
    'flip*',
    'handstand*',
    'spin*',
    'run',
    'running',
    'sprint*',
    'gas',
    'glass',
    'ice',
    'breath*',
  ],
  ingest: [
    'اكل',
    'الاكل',
    'تناول',
    'شرب',
    'الشرب',
    'ابتلاع',
    'بلع',
    'مضغ',
    'تذوق',
    'لعق',
    'eat',
    'eating',
    'eats',
    'drink*',
    'swallow*',
    'chew*',
    'taste',
    'tasting',
    'lick*',
    'sip*',
    'gulp*',
  ],
  sexual: [
    'خلع',
    'ملابس داخليه',
    'عاري',
    'عاريه',
    'تعري',
    'قبله',
    'قبلة',
    'تقبيل',
    'بوسه',
    'بوسة',
    'حبيب',
    'حبيبه',
    'حبيبة',
    'غزل',
    'رومانسي',
    'رومانسيه',
    'معجب',
    'معجبه',
    'عشق',
    'غرام',
    'حضن',
    'عناق',
    'غمز',
    'مثير',
    'جسد',
    'undress*',
    'naked',
    'nude*',
    'underwear',
    'strip*',
    'kiss*',
    'flirt*',
    'romanc*',
    'romantic',
    'crush*',
    'sexy',
    'sex*',
    'hug',
    'hugs',
    'hugging',
    'cuddl*',
    'wink*',
    'date',
    'dating',
    'boyfriend*',
    'girlfriend*',
    'lover*',
    'body',
    'seduc*',
  ],
  insult: [
    'غبي',
    'غبيه',
    'احمق',
    'حمقاء',
    'قبيح',
    'قبيحه',
    'سمين',
    'سمينه',
    'بدين',
    'بدينه',
    'تافه',
    'فاشل',
    'فاشله',
    'حقير',
    'سخيف',
    'سخيفه',
    'اهانه',
    'شتم',
    'سب',
    'تنمر',
    'عنصري',
    'stupid',
    'idiot*',
    'dumb',
    'ugly',
    'fat',
    'fatty',
    'loser*',
    'moron*',
    'insult*',
    'mock*',
    'bully*',
    'racis*',
    'lame',
    'jerk*',
  ],
  substances: [
    'خمر',
    'كحول',
    'بيره',
    'بيرة',
    'نبيذ',
    'مخدر',
    'مخدرات',
    'حشيش',
    'سيجاره',
    'سيجارة',
    'تدخين',
    'دخان',
    'شيشه',
    'شيشة',
    'ارجيله',
    'ارجيلة',
    'قمار',
    'رهان',
    'مراهنه',
    'كازينو',
    'alcohol*',
    'beer*',
    'wine*',
    'vodka',
    'whisk*',
    'drug*',
    'weed',
    'cigar*',
    'smok*',
    'vape*',
    'hookah',
    'shisha',
    'gambl*',
    'bet',
    'betting',
    'casino*',
    'poker',
    'drunk*',
  ],
  personal_info: [
    'هاتف',
    'جوال',
    'موبايل',
    'عنوان',
    'عنوانك',
    'موقعك',
    'هويه',
    'هويتك',
    'جواز',
    'كلمه السر',
    'كلمة السر',
    'رقمك',
    'رقم',
    'سكنك',
    'تسكن',
    'بيتك',
    'مدرستك',
    'عملك',
    'phone*',
    'address*',
    'location*',
    'passport*',
    'password*',
    'pin',
    'id',
    'whatsapp',
    'email*',
    'instagram',
    'snapchat',
    'tiktok',
  ],
  third_parties: [
    'اتصال',
    'اتصل',
    'مكالمه',
    'مكالمة',
    'رساله',
    'رسالة',
    'راسل',
    'مراسله',
    'صديق',
    'صديقه',
    'اصدقاء',
    'اخ',
    'اخت',
    'ام',
    'اب',
    'امك',
    'ابوك',
    'اهل',
    'اهلك',
    'جار',
    'جيران',
    'جاره',
    'طفل',
    'اطفال',
    'طفله',
    'رضيع',
    'زوج',
    'زوجه',
    'زوجة',
    'خطيب',
    'خطيبه',
    'عائله',
    'عائلة',
    'call',
    'calls',
    'calling',
    'phone call*',
    'text',
    'texting',
    'message*',
    'dm',
    'friend',
    'friends',
    'mom',
    'mum',
    'mother*',
    'dad',
    'father*',
    'brother*',
    'sister*',
    'neighbo*',
    'kid',
    'kids',
    'child*',
    'baby',
    'babies',
    'husband*',
    'wife',
    'wives',
    'family',
    'families',
    'parent*',
    'cousin*',
    'stranger*',
  ],
  money: [
    'شراء',
    'اشتري',
    'اشتر',
    'دفع',
    'مال',
    'فلوس',
    'نقود',
    'تحويل',
    'هديه',
    'هدية',
    'هدايا',
    'تسوق',
    'سعر',
    'عمله',
    'عملات',
    'كوينز',
    'دعم',
    'تبرع',
    'buy*',
    'pay*',
    'money',
    'cash',
    'coin*',
    'gift*',
    'donat*',
    'shop*',
    'price*',
    'purchas*',
    'spend*',
    'dollar*',
  ],
  illegal: [
    'سرقه',
    'سرقة',
    'سرق',
    'تزوير',
    'غش',
    'شرطه',
    'شرطة',
    'سجن',
    'جريمه',
    'جريمة',
    'مخالفه',
    'steal*',
    'stole*',
    'theft',
    'illegal*',
    'police*',
    'prison*',
    'jail*',
    'crime*',
    'cheat*',
    'hack*',
  ],
  disability: [
    'اعمي',
    'اعمى',
    'اطرش',
    'اصم',
    'ابكم',
    'اعرج',
    'معاق',
    'معاقه',
    'اعاقه',
    'اعاقة',
    'مجنون',
    'مجنونه',
    'متخلف',
    'تاتاه',
    'تأتأة',
    'تاتاة',
    'احول',
    'blind*',
    'deaf*',
    'mute',
    'cripple*',
    'disab*',
    'crazy',
    'insane',
    'retard*',
    'stutter*',
    'lisp*',
    'mental*',
    'psycho*',
    'handicap*',
  ],
  religion: [
    'الله',
    'دين',
    'ديني',
    'صلاه',
    'صلاة',
    'مسجد',
    'كنيسه',
    'كنيسة',
    'قران',
    'انجيل',
    'نبي',
    'رسول',
    'صوم',
    'صيام',
    'رمضان',
    'عيد',
    'حج',
    'شيخ',
    'ملاك',
    'شيطان',
    'جن',
    'جني',
    'دعاء',
    'اذان',
    'آذان',
    'تسبيح',
    'ميلاد',
    'god*',
    'allah',
    'pray*',
    'church*',
    'mosque*',
    'bible',
    'quran',
    'religio*',
    'prophet*',
    'ramadan',
    'eid',
    'christmas',
    'easter',
    'halloween',
    'angel*',
    'devil*',
    'demon*',
    'satan',
    'ghost*',
    'spirit*',
    'holy',
    'saint*',
    'birthday*',
    'heaven',
    'hell',
  ],
  politics: [
    'سياسه',
    'سياسة',
    'سياسي',
    'رئيس',
    'حكومه',
    'حكومة',
    'انتخابات',
    'حزب',
    'وزير',
    'ملك',
    'ملكه',
    'امير',
    'جيش',
    'حرب',
    'مظاهره',
    'برلمان',
    'دوله',
    'دولة',
    'وطن',
    'علم البلد',
    'جنسيه',
    'جنسية',
    'قبيله',
    'قبيلة',
    'politic*',
    'president*',
    'government*',
    'election*',
    'minister*',
    'king*',
    'queen*',
    'prince*',
    'army',
    'armies',
    'war',
    'wars',
    'flag*',
    'protest*',
    'parliament*',
    'party',
    'parties',
    'nation*',
    'tribe*',
    'country',
    'countries',
  ],
};

/** Rules that are not single words. */
const PATTERNS: readonly { rule: string; re: RegExp }[] = [
  { rule: 'contact', re: /(@|#|https?:|www\.|\.com\b)/i },
  { rule: 'personal_info', re: /\d{4,}/ },
  { rule: 'gendered', re: /(^|\s)(و?انت|و?أنت|و?أنتِ|و?أنتَ|انتي)(\s|$)/ },
  { rule: 'danger', re: /\b(hold (your|the) breath|stand on (a|the) (chair|table))\b/i },
];

interface CompiledBlocklist {
  exact: Map<string, string>;
  phrases: { rule: string; text: string }[];
  prefixes: Map<string, { rule: string; prefix: string }[]>;
}

let compiled: CompiledBlocklist | null = null;

function blocklist(): CompiledBlocklist {
  if (compiled) return compiled;
  const exact = new Map<string, string>();
  const phrases: { rule: string; text: string }[] = [];
  const prefixes = new Map<string, { rule: string; prefix: string }[]>();
  for (const [rule, words] of Object.entries(BLOCKLIST)) {
    for (const raw of words) {
      if (raw.endsWith('*')) {
        const prefix = raw.slice(0, -1).toLowerCase();
        if (prefix.length < 2) throw new Error(`blocklist prefix too short: ${raw}`);
        const key = prefix.slice(0, 2);
        prefixes.set(key, [...(prefixes.get(key) ?? []), { rule, prefix }]);
        continue;
      }
      const w = normalizeDareText(raw);
      if (w.includes(' ')) phrases.push({ rule, text: ` ${w} ` });
      else exact.set(w, rule);
    }
  }
  compiled = { exact, phrases, prefixes };
  return compiled;
}

/** Durations stated in a dare, in seconds (Arabic and English; «دقيقة» = 60, «دقيقتين» = 120). */
export function statedSeconds(text: string): number[] {
  const out: number[] = [];
  const norm = normalizeDareText(text);
  for (const m of norm.matchAll(/(\d+)\s*(ثانيه|ثواني|ثوان|second|seconds|sec)\b/g)) out.push(Number(m[1]));
  for (const m of norm.matchAll(/(\d+)\s*(دقيقه|دقائق|minute|minutes|min)\b/g)) out.push(Number(m[1]) * 60);
  if (/(^| )(دقيقه|minute|one minute|a minute)( |$)/.test(norm)) out.push(60);
  if (/(^| )(دقيقتين|دقيقتان|two minutes)( |$)/.test(norm)) out.push(120);
  if (/(^| )(ثلاث دقائق|three minutes)( |$)/.test(norm)) out.push(180);
  return out;
}

/** A broken rule of one dare (empty list: the dare passes). */
export interface PkDareViolation {
  readonly rule: string;
  readonly detail: string;
}

/** The hard rules (D229): both languages present and short, no blocked word or pattern, doable in 3 minutes. */
export function checkDareSafety(dare: PkDareText): PkDareViolation[] {
  const out: PkDareViolation[] = [];
  const ar = dare.textAr.trim();
  const en = dare.textEn.trim();
  if (ar.length === 0) out.push({ rule: 'missing', detail: 'textAr' });
  if (en.length === 0) out.push({ rule: 'missing', detail: 'textEn' });
  if ([...ar].length > PK_DARE_MAX_AR) out.push({ rule: 'length', detail: `textAr ${[...ar].length}` });
  if ([...en].length > PK_DARE_MAX_EN) out.push({ rule: 'length', detail: `textEn ${[...en].length}` });
  if (ar.length > 0 && !/\p{Script=Arabic}/u.test(ar))
    out.push({ rule: 'language', detail: 'textAr not Arabic' });
  if (/[A-Za-z]/.test(ar)) out.push({ rule: 'language', detail: 'Latin letters in textAr' });
  if (/\p{Script=Arabic}/u.test(en)) out.push({ rule: 'language', detail: 'Arabic letters in textEn' });
  for (const s of [...statedSeconds(ar), ...statedSeconds(en)]) {
    if (s > PK_DARE_MAX_STATED_SECONDS) out.push({ rule: 'duration', detail: `${s} s` });
  }
  const list = blocklist();
  for (const text of [ar, en]) {
    const tokens = dareTokens(text);
    for (const t of tokens) {
      const rule = list.exact.get(t);
      if (rule) out.push({ rule, detail: t });
      // Latin word starts, looked up by the first two letters (every prefix has at least two).
      if (/^[a-z]/.test(t)) {
        for (const p of list.prefixes.get(t.slice(0, 2)) ?? []) {
          if (t.startsWith(p.prefix)) out.push({ rule: p.rule, detail: t });
        }
      }
    }
    const spaced = ` ${normalizeDareText(text)} `;
    for (const p of list.phrases)
      if (spaced.includes(p.text)) out.push({ rule: p.rule, detail: p.text.trim() });
    for (const p of PATTERNS) if (p.re.test(text)) out.push({ rule: p.rule, detail: p.re.source });
  }
  return out;
}

// ---- Duplicates ------------------------------------------------------------------------------------------

/** Two dares are near-duplicates when the word sets of either language overlap this much (Jaccard). */
export const PK_DARE_NEAR_DUPLICATE_JACCARD = 0.8;

function wordSet(text: string): Set<string> {
  return new Set(
    normalizeDareText(text)
      .split(' ')
      .filter((w) => w.length > 0),
  );
}

export function jaccard(a: ReadonlySet<string>, b: ReadonlySet<string>): number {
  if (a.size === 0 && b.size === 0) return 1;
  let inter = 0;
  for (const x of a) if (b.has(x)) inter += 1;
  return inter / (a.size + b.size - inter);
}

/** FNV-1a 32-bit of a string with a seed (the MinHash family). */
function hash32(s: string, seed: number): number {
  let h = (0x811c9dc5 ^ seed) >>> 0;
  for (let i = 0; i < s.length; i += 1) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  h ^= h >>> 16;
  h = Math.imul(h, 0x85ebca6b) >>> 0;
  h ^= h >>> 13;
  return h >>> 0;
}

const BANDS = 16;
const ROWS = 8;

/** One near-duplicate (or exact duplicate) pair: the indexes in the list given and the similarity. */
export interface PkDareDuplicate {
  readonly a: number;
  readonly b: number;
  readonly lang: 'ar' | 'en';
  readonly similarity: number;
  readonly exact: boolean;
}

/**
 * Exact duplicates (the normalized text of either language) and near-duplicates (word-set Jaccard ≥ 0.8 in
 * either language), found with MinHash LSH (16 bands × 8 rows: a pair at 0.8 is a candidate with p ≈ 0.95,
 * at 0.9 with p > 0.999) and confirmed with the exact Jaccard. `against` (optional): only pairs with at least one
 * index ≥ `against` are reported (checking new dares against an existing library).
 */
export function findDuplicates(dares: readonly PkDareText[], against = 0): PkDareDuplicate[] {
  const out: PkDareDuplicate[] = [];
  const seen = new Set<string>();
  for (const lang of ['ar', 'en'] as const) {
    const sets = dares.map((d) => wordSet(lang === 'ar' ? d.textAr : d.textEn));
    const exact = new Map<string, number>();
    sets.forEach((s, i) => {
      const key = [...s].sort().join(' ');
      const prev = exact.get(key);
      if (prev !== undefined && (i >= against || prev >= against)) {
        const k = `${prev}:${i}`;
        if (!seen.has(k)) {
          seen.add(k);
          out.push({ a: prev, b: i, lang, similarity: 1, exact: true });
        }
      } else if (prev === undefined) exact.set(key, i);
    });
    const buckets = new Map<string, number[]>();
    sets.forEach((s, i) => {
      const words = [...s];
      for (let band = 0; band < BANDS; band += 1) {
        const mins: number[] = [];
        for (let r = 0; r < ROWS; r += 1) {
          const seed = band * ROWS + r + 1;
          let min = 0xffffffff;
          for (const w of words) {
            const h = hash32(w, seed);
            if (h < min) min = h;
          }
          mins.push(min);
        }
        const key = `${band}:${mins.join(',')}`;
        const list = buckets.get(key);
        if (list) list.push(i);
        else buckets.set(key, [i]);
      }
    });
    for (const list of buckets.values()) {
      if (list.length < 2) continue;
      for (let x = 0; x < list.length; x += 1) {
        for (let y = x + 1; y < list.length; y += 1) {
          const a = list[x]!;
          const b = list[y]!;
          if (a < against && b < against) continue;
          const k = `${a}:${b}`;
          if (seen.has(k)) continue;
          const sim = jaccard(sets[a]!, sets[b]!);
          if (sim >= PK_DARE_NEAR_DUPLICATE_JACCARD) {
            seen.add(k);
            out.push({ a, b, lang, similarity: sim, exact: sim === 1 });
          }
        }
      }
    }
  }
  return out;
}

// ---- Import lines ------------------------------------------------------------------------------------------

/** One dare of an import (the seed file's JSON line, or a CSV row). */
export interface PkDareImport extends PkDareText {
  readonly code: string;
  readonly category: PkDareCategory;
  readonly level: PkDareLevel;
}

const CODE = /^[a-z0-9][a-z0-9_-]{2,39}$/;

/** Checks one import line's fields (the safety rules apart). */
export function parseDareImport(raw: unknown): PkDareImport | string {
  if (typeof raw !== 'object' || raw === null) return 'not an object';
  const r = raw as Record<string, unknown>;
  const code = typeof r.code === 'string' ? r.code.trim() : '';
  if (!CODE.test(code)) return 'code';
  if (typeof r.textAr !== 'string' || typeof r.textEn !== 'string') return 'text';
  const category = typeof r.category === 'string' ? r.category.toUpperCase() : '';
  if (!(PK_DARE_CATEGORIES as readonly string[]).includes(category)) return 'category';
  const level = typeof r.level === 'string' ? r.level.toUpperCase() : '';
  if (!(PK_DARE_LEVELS as readonly string[]).includes(level)) return 'level';
  return {
    code,
    textAr: r.textAr.trim(),
    textEn: r.textEn.trim(),
    category: category as PkDareCategory,
    level: level as PkDareLevel,
  };
}

/** A minimal CSV reader (RFC 4180 quotes) for the panel's and the CLI's import: header row first. */
export function parseCsv(text: string): Record<string, string>[] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let quoted = false;
  const src = text.replace(/^\uFEFF/, '');
  for (let i = 0; i < src.length; i += 1) {
    const c = src[i]!;
    if (quoted) {
      if (c === '"' && src[i + 1] === '"') {
        field += '"';
        i += 1;
      } else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') {
      row.push(field);
      field = '';
    } else if (c === '\n' || c === '\r') {
      if (c === '\r' && src[i + 1] === '\n') i += 1;
      row.push(field);
      field = '';
      if (row.some((f) => f.length > 0)) rows.push(row);
      row = [];
    } else field += c;
  }
  row.push(field);
  if (row.some((f) => f.length > 0)) rows.push(row);
  const [header, ...body] = rows;
  if (!header) return [];
  const keys = header.map((h) => h.trim());
  return body.map((r) => Object.fromEntries(keys.map((k, i) => [k, r[i] ?? ''])));
}

/** CSV export of dares (the same columns the import reads). */
export function toCsv(rows: readonly (PkDareImport & { active?: boolean })[]): string {
  const q = (s: string) => (/[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s);
  const lines = ['code,category,level,textAr,textEn,active'];
  for (const r of rows) {
    lines.push([r.code, r.category, r.level, r.textAr, r.textEn, String(r.active ?? true)].map(q).join(','));
  }
  return `${lines.join('\n')}\n`;
}
