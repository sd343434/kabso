/**
 * v1.32-live (D154, CONVENTIONS §10.33): «إفيهات» quips — gifts of the QUIPS category that play a short
 * sound (and show its line of text) to everyone in the live, one at a time per room. Pure data and
 * arithmetic, shared by the API and the `gift-admin` CLI (no Nest dependencies).
 *
 * The sounds are the owner's own Kabso assets (D154 5c, 5d; provenance in the app's
 * `assets/sounds/quips/PROVENANCE.md`), bundled in the app under the same keys (`room/<id>`,
 * `kabi/<id>`, D349 `gulf/<id>`, `jordan/<id>`); their lengths below are the loudness-normalised files
 * the app ships.
 */
import type { GiftFields } from './gift-catalogue.js';

/** The media data topic of `quip` messages. */
export const QUIP_TOPIC = 'quip';

/** A short pause between two quips in a room's queue, so they never run into each other. */
export const QUIP_GAP_MS = 400;

/** One quip of the owner's pack, as `gift-admin quips-seed` / `quips-sync` adds it. */
export interface QuipPackEntry extends GiftFields {
  readonly code: string;
}

/**
 * The sub-categories (the panel's chips, in this order) and their prices. D349 (owner 2026-11-09): the
 * free sounds stay free under «مجانية»; every paid line is **100 000 coins**, by dialect — «مصري» (the
 * 27 Kabi lines of D154, formerly ghazal 99 · funny 199 · tease 299), «خليجي» and «أردني».
 */
export const QUIP_PRICES = { free: 0, egypt: 100_000, gulf: 100_000, jordan: 100_000 } as const;
export type QuipGroup = keyof typeof QUIP_PRICES;

/** Each sub-category's names and sort base (the chips follow the gifts' sort order). */
export const QUIP_GROUPS: Readonly<Record<QuipGroup, { ar: string; en: string; sort: number }>> = {
  free: { ar: 'مجانية', en: 'Free', sort: 0 },
  egypt: { ar: 'مصري', en: 'Egyptian', sort: 100 },
  gulf: { ar: 'خليجي', en: 'Gulf', sort: 200 },
  jordan: { ar: 'أردني', en: 'Jordanian', sort: 300 },
};

const ARABIC_DIGITS = '٠١٢٣٤٥٦٧٨٩';
const arabicNumber = (n: number): string => [...String(n)].map((d) => ARABIC_DIGITS[Number(d)]).join('');

/**
 * The cell art's key of a sound (the app draws it from its own art, no bundled image per quip):
 * `room/clap` → `quips/clap`, `kabi/ghazal_01` → `quips/ghazal`, `gulf/gulf_01` → `quips/gulf`.
 */
export const quipAssetKey = (soundKey: string): string => {
  const [folder, name] = soundKey.split('/') as [string, string];
  return folder === 'room' ? `quips/${name}` : `quips/${name.split('_')[0]!}`;
};

function entry(
  group: QuipGroup,
  code: string,
  names: { ar: string; en: string },
  soundKey: string,
  soundMs: number,
  order: number,
  quipText: string | null,
): QuipPackEntry {
  const tag = QUIP_GROUPS[group];
  return {
    code,
    category: 'QUIPS',
    nameAr: names.ar,
    nameEn: names.en,
    priceCoins: QUIP_PRICES[group],
    assetKey: quipAssetKey(soundKey),
    animationKey: null,
    sortOrder: tag.sort + order,
    badge: 'NONE',
    tagCode: group,
    tagNameAr: tag.ar,
    tagNameEn: tag.en,
    soundKey,
    soundMs,
    quipText,
  };
}

const free = (id: string, ar: string, en: string, ms: number, order: number): QuipPackEntry =>
  entry('free', `quip_${id}`, { ar, en }, `room/${id}`, ms, order, null);

/** D154's Kabi line names (kept: «غزل ١» … — the codes, names and texts of history stay valid). */
const KABI_NAMES = {
  ghazal: { ar: 'غزل', en: 'Flirty', first: 0 },
  funny: { ar: 'ضحك', en: 'Funny', first: 10 },
  tease: { ar: 'تريقة', en: 'Teasing', first: 18 },
} as const;

/** An Egyptian Kabi line of D154 (code `quip_<kind>_NN`, sound `kabi/<kind>_NN`), now under «مصري». */
const kabi = (kind: keyof typeof KABI_NAMES, n: number, ms: number, text: string): QuipPackEntry => {
  const id = `${kind}_${String(n).padStart(2, '0')}`;
  const names = {
    ar: `${KABI_NAMES[kind].ar} ${arabicNumber(n)}`,
    en: `${KABI_NAMES[kind].en} ${String(n)}`,
  };
  // In D154's order: ghazal 1–10, funny 1–8, tease 1–9 → «مصري» 1–27.
  return entry('egypt', `quip_${id}`, names, `kabi/${id}`, ms, KABI_NAMES[kind].first + n, text);
};

/**
 * D349: a line of the owner's Gulf / Jordanian pack (code `quip_<group>_NN`, sound `<group>/<group>_NN`,
 * named «خليجي ١» / "Gulf 1"), with its words (the owner's ElevenLabs texts, direction tags removed).
 */
const dialect = (group: 'gulf' | 'jordan', n: number, ms: number, text: string): QuipPackEntry => {
  const id = `${group}_${String(n).padStart(2, '0')}`;
  const names = {
    ar: `${QUIP_GROUPS[group].ar} ${arabicNumber(n)}`,
    en: `${QUIP_GROUPS[group].en} ${String(n)}`,
  };
  return entry(group, `quip_${id}`, names, `${group}/${id}`, ms, n, text);
};

/**
 * The owner's pack: 8 free room sounds and 27 Egyptian Kabi lines (2026-10-28, D154; the texts are the
 * owner's `lines.json`, tease_02 confirmed by the owner, D154 5f), then 14 Gulf and 4 Jordanian lines
 * (2026-11-09, D349; ElevenLabs voices, numbered in the order the owner made them; texts from the owner's
 * ElevenLabs history, matched by that order and the clips' lengths — owner to confirm by ear, PP-83).
 * Lengths are the loudness-normalised files the app bundles (`assets/sounds/quips/`).
 */
export const QUIP_PACK: readonly QuipPackEntry[] = [
  free('clap', 'تصفيق', 'Clap', 2038, 0),
  free('laugh', 'ضحك', 'Laugh', 1123, 1),
  free('welcome', 'أهلاً وسهلاً', 'Welcome', 2038, 2),
  free('wow', 'واو', 'Wow', 836, 3),
  free('tada', 'تا-دا', 'Ta-da', 2299, 4),
  free('ya_salam', 'يا سلام', 'Ya salam', 1750, 5),
  free('bell', 'جرس', 'Bell', 1698, 6),
  free('sad', 'أوووه', 'Ooh', 2220, 7),
  kabi('ghazal', 1, 4362, 'إيه الجمال ده! تحفة بجد!'),
  kabi('ghazal', 2, 4911, 'يا فتّان يا جامد!'),
  kabi('ghazal', 3, 5930, 'ده إنت حكاية!'),
  kabi('ghazal', 4, 6478, 'يا لهوي يا ناس!'),
  kabi('ghazal', 5, 4493, 'مين القمر ده؟'),
  kabi('ghazal', 6, 8934, 'يا خراب بيت الحلاوة!'),
  kabi('ghazal', 7, 8620, 'الجمال ده مش قانوني!'),
  kabi('ghazal', 8, 7367, 'خد قلبي وسيبلي عقلي!'),
  kabi('ghazal', 9, 6922, 'يا جامد يا ابن اللذينة!'),
  kabi('ghazal', 10, 9953, 'ده إنت محتاج حراسة من المعجبين!'),
  kabi('funny', 1, 7654, 'يا جماعة حد يلمّ الجمال ده من على الأرض!'),
  kabi('funny', 2, 10815, 'ادخلوا بالراحة، الكاريزما هنا عليها أحمال زيادة!'),
  kabi('funny', 3, 12304, 'يا نجم، النور عندك عالي لدرجة إننا هنطلب فاتورة كهربا!'),
  kabi('funny', 4, 10240, 'صاحبنا دخل الشات، يا ريت حد يشرحله قواعد الجاذبية!'),
  kabi('funny', 5, 9247, 'إيه يا عم، داخل تسلّم ولا تستلم قلوب؟'),
  kabi('funny', 6, 12382, 'تم رصد كمية ثقة غير مرخصة في الغرفة!'),
  kabi('funny', 7, 10710, 'الرجاء عدم الاقتراب، الشخصية تحت الاختبار!'),
  kabi('funny', 8, 11180, 'اللي داخل يتغزل ياخد رقم، الدور طويل!'),
  kabi('tease', 1, 7210, 'إنت مش غبي، إنت بس بتدي الذكاء فرصة يثبت نفسه بعيد عنك!'),
  kabi('tease', 2, 5721, 'إنت لو التركيز فلوس، كنت استلفت مننا.'),
  kabi('tease', 3, 7811, 'يا ابني إنت محتاج تحديث نظام، واضح إن النسخة دي فيها مشاكل!'),
  kabi('tease', 4, 5198, 'مخك مش فاضي، ده لسه تحت التشطيب!'),
  kabi('tease', 5, 6713, 'يا عم إنت لو كنت إجابة، كنت هتبقى «حاول مرة أخرى»!'),
  kabi('tease', 6, 5564, 'إنت مش بتقول أي كلام، إنت بتعمل محتوى تجريبي!'),
  kabi('tease', 7, 6504, 'ربنا مديك قبول، بس واضح إنه مشغول دلوقتي!'),
  kabi('tease', 8, 5172, 'إنت مش غامض، إنت بس محدش مهتم يسأل!'),
  kabi('tease', 9, 7079, 'طب جرّب تتكلم من غير ما تفكر، يمكن نوصل لنفس النتيجة بس أسرع!'),
  dialect('gulf', 1, 6713, 'يا زينك بس، حتى الحظ إذا شافك قال: أنا مالي شغل!'),
  dialect('gulf', 2, 5355, 'وش هالثقة؟ داخل علينا كأن التطبيق باسمك!'),
  dialect('gulf', 3, 5094, 'هدي اللعب يا وحش، ترى القلوب مو كلها تتحمل! ❤️'),
  dialect('gulf', 4, 5355, 'يا جماعة الخير، عطوه هدية يمكن يسكت شوي!'),
  dialect('gulf', 5, 5512, 'لا تسوي نفسك مشغول، شفناك متصل من الفجر!'),
  dialect('gulf', 6, 4624, 'يا بعد حيي، حضورك لحاله يسوى مليون كوين! 💎'),
  dialect('gulf', 7, 3997, 'تكفى لا تطلع، توّنا بدينا نستانس! 🥹'),
  dialect('gulf', 8, 5355, 'وش السالفة؟ داخل دخول الملوك وطالع بدون سلام؟'),
  dialect('gulf', 9, 6296, 'يا ساتر، منو عطاه المايك؟ شكله ما راح يسكته أحد! 🎤'),
  dialect('gulf', 10, 5512, 'وش هالحلا؟ تكفى خف علينا، قلوبنا مو قد هالجمال!'),
  dialect('gulf', 11, 5904, 'تدري إنك مشكلة؟ كل ما أشوفك أنسى وش كنت بقول!'),
  dialect('gulf', 12, 5277, 'يا زين ضحكتك، أحسها تسوي إعادة تشغيل لقلبي!'),
  dialect('gulf', 13, 6296, 'أنت وش تستخدم؟ عسل ولا سحر؟ لأنك مسوي فيني عمايل!'),
  dialect('gulf', 14, 7340, 'تدري وش ناقص الدنيا؟ نسخة ثانية منك، عشان إذا اشتقت لك أروح لها! 😂'),
  dialect('jordan', 1, 5016, 'ولك شو هالحلا؟ إنت مش بني آدم، إنت مخالفِة جمال!'),
  dialect('jordan', 2, 6870, 'يا زلمة قلبي مش واتساب، بس إنت كل ما تطلّ عليّ... بعملك اتصال!'),
  dialect('jordan', 3, 5172, 'يا ريتني شاحن تلفون، عشان أضل قريب منك وما تِفصل عني!'),
  dialect('jordan', 4, 7340, 'ولك إنت حلو بطريقة بتخليني أستحي أحكي معك، وبنفس الوقت نفسي ما أسكُت!'),
];

/** The fields `quips-sync` keeps in line with the pack on a quip that exists already. */
export const QUIP_SYNC_FIELDS = ['priceCoins', 'tagCode', 'tagNameAr', 'tagNameEn', 'sortOrder'] as const;
type SyncField = (typeof QUIP_SYNC_FIELDS)[number];

/** What `quips-sync` reads of an existing gift. */
export type QuipSyncRow = Pick<GiftFields, SyncField | 'category'> & {
  readonly code: string;
  readonly quipText: string | null;
};

/** One change of `quips-sync`: a quip to add, or the fields of an existing one to update. */
export type QuipSyncStep =
  | { readonly kind: 'add'; readonly entry: QuipPackEntry }
  | { readonly kind: 'update'; readonly code: string; readonly fields: Partial<GiftFields> };

export class QuipTextsError extends Error {}

/**
 * The owner's texts file (`--texts <file.json>`): a JSON object of quip code → its words (1–`max`
 * characters after trimming; null removes them). Every code must be in the pack. Throws
 * {@link QuipTextsError} with every problem.
 */
export function parseQuipTexts(json: unknown, max: number): ReadonlyMap<string, string | null> {
  if (json === null || typeof json !== 'object' || Array.isArray(json)) {
    throw new QuipTextsError('the texts file must be a JSON object of quip code → text');
  }
  const codes = new Set(QUIP_PACK.map((q) => q.code));
  const out = new Map<string, string | null>();
  const problems: string[] = [];
  for (const [code, value] of Object.entries(json as Record<string, unknown>)) {
    if (!codes.has(code)) problems.push(`${code}: not a quip of the pack`);
    else if (value === null) out.set(code, null);
    else if (typeof value !== 'string') problems.push(`${code}: the text must be a string or null`);
    else {
      const text = value.trim();
      if (text.length === 0 || text.length > max) {
        problems.push(`${code}: the text must be 1–${String(max)} characters`);
      } else out.set(code, text);
    }
  }
  if (problems.length > 0) throw new QuipTextsError(problems.join('; '));
  return out;
}

/**
 * D349: what `gift-admin quips-sync` does to bring the catalogue's quips in line with the pack: adds
 * the pack's missing quips (with their text from `texts` when given), and on the existing ones sets the
 * pack's price, sub-category and sort order ({@link QUIP_SYNC_FIELDS}) and the text from `texts` (only
 * the codes it names). Nothing else of an existing gift is touched (names, sound, art, on/off). A
 * second run plans nothing (idempotent). A code of the pack that is not a QUIPS gift is refused.
 */
export function quipSyncPlan(
  existing: readonly QuipSyncRow[],
  texts: ReadonlyMap<string, string | null> = new Map(),
): QuipSyncStep[] {
  const byCode = new Map(existing.map((g) => [g.code, g]));
  const steps: QuipSyncStep[] = [];
  for (const q of QUIP_PACK) {
    const g = byCode.get(q.code);
    const text = texts.has(q.code) ? (texts.get(q.code) ?? null) : undefined;
    if (!g) {
      steps.push({ kind: 'add', entry: text === undefined ? q : { ...q, quipText: text } });
      continue;
    }
    if (g.category !== 'QUIPS') throw new QuipTextsError(`${q.code} exists and is not a QUIPS gift`);
    const fields: Record<string, unknown> = {};
    for (const k of QUIP_SYNC_FIELDS) if (g[k] !== q[k]) fields[k] = q[k];
    if (text !== undefined && g.quipText !== text) fields.quipText = text;
    if (Object.keys(fields).length > 0) {
      steps.push({ kind: 'update', code: q.code, fields });
    }
  }
  return steps;
}

/** Where a new quip goes in a room's queue: when it starts, how long from now, and the new tail. */
export interface QuipSlot {
  readonly startsAt: Date;
  readonly delayMs: number;
  readonly busyUntil: Date;
}

/**
 * The slot of a quip of `durationMs` asked for at `now` in a room whose queue is busy until
 * `busyUntil` (null: never used): it starts when the queue is free (now at the earliest) and keeps
 * the queue busy for its length plus {@link QUIP_GAP_MS}. Null when it would wait longer than
 * `maxWaitMs` (the room's queue is full). A clock that went backwards counts as no time passed.
 */
export function quipSlot(
  now: Date,
  busyUntil: Date | null,
  durationMs: number,
  maxWaitMs: number,
): QuipSlot | null {
  const start = Math.max(now.getTime(), busyUntil?.getTime() ?? 0);
  const delayMs = start - now.getTime();
  if (delayMs > maxWaitMs) return null;
  return {
    startsAt: new Date(start),
    delayMs,
    busyUntil: new Date(start + durationMs + QUIP_GAP_MS),
  };
}
