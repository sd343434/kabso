/**
 * v1.32-live (D154, CONVENTIONS §10.33): «إفيهات» quips — gifts of the QUIPS category that play a short
 * sound (and show its line of text) to everyone in the live, one at a time per room. Pure data and
 * arithmetic, shared by the API and the `gift-admin` CLI (no Nest dependencies).
 *
 * The sounds are the owner's own Kabso assets (D154 5c, 5d; provenance in the app's
 * `assets/sounds/quips/PROVENANCE.md`), bundled in the app under the same keys (`room/<id>`,
 * `kabi/<id>`); their lengths below are the loudness-normalised files the app ships.
 */
import type { GiftFields } from './gift-catalogue.js';

/** The media data topic of `quip` messages. */
export const QUIP_TOPIC = 'quip';

/** A short pause between two quips in a room's queue, so they never run into each other. */
export const QUIP_GAP_MS = 400;

/** One quip of the owner's pack, as `gift-admin quips-seed` adds it. */
export interface QuipPackEntry extends GiftFields {
  readonly code: string;
}

/** The owner's prices by group (D154 5d): ghazal 99, funny 199, tease 299 coins; the free sounds 0. */
export const QUIP_PRICES = { free: 0, ghazal: 99, funny: 199, tease: 299 } as const;
type QuipGroup = keyof typeof QUIP_PRICES;

const GROUPS: Readonly<Record<QuipGroup, { ar: string; en: string; sort: number }>> = {
  free: { ar: 'مجانية', en: 'Free', sort: 0 },
  ghazal: { ar: 'غزل', en: 'Flirty', sort: 100 },
  funny: { ar: 'ضحك', en: 'Funny', sort: 200 },
  tease: { ar: 'تريقة', en: 'Teasing', sort: 300 },
};

const ARABIC_DIGITS = '٠١٢٣٤٥٦٧٨٩';
const arabicNumber = (n: number): string => [...String(n)].map((d) => ARABIC_DIGITS[Number(d)]).join('');

function entry(
  group: QuipGroup,
  code: string,
  names: { ar: string; en: string },
  soundKey: string,
  soundMs: number,
  order: number,
  quipText: string | null,
): QuipPackEntry {
  const tag = GROUPS[group];
  return {
    code,
    category: 'QUIPS',
    nameAr: names.ar,
    nameEn: names.en,
    priceCoins: QUIP_PRICES[group],
    // The app draws a quip's cell from its own art for this key (no bundled image per quip).
    assetKey: group === 'free' ? `quips/${soundKey.slice('room/'.length)}` : `quips/${group}`,
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

const line = (group: Exclude<QuipGroup, 'free'>, n: number, ms: number, text: string): QuipPackEntry => {
  const id = `${group}_${String(n).padStart(2, '0')}`;
  const names = { ar: `${GROUPS[group].ar} ${arabicNumber(n)}`, en: `${GROUPS[group].en} ${String(n)}` };
  return entry(group, `quip_${id}`, names, `kabi/${id}`, ms, n, text);
};

/**
 * The owner's pack (2026-10-28): 8 free room sounds and 27 paid Kabi lines (Egyptian Arabic; the
 * texts are the owner's `lines.json`, tease_02 confirmed by the owner, D154 5f).
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
  line('ghazal', 1, 4362, 'إيه الجمال ده! تحفة بجد!'),
  line('ghazal', 2, 4911, 'يا فتّان يا جامد!'),
  line('ghazal', 3, 5930, 'ده إنت حكاية!'),
  line('ghazal', 4, 6478, 'يا لهوي يا ناس!'),
  line('ghazal', 5, 4493, 'مين القمر ده؟'),
  line('ghazal', 6, 8934, 'يا خراب بيت الحلاوة!'),
  line('ghazal', 7, 8620, 'الجمال ده مش قانوني!'),
  line('ghazal', 8, 7367, 'خد قلبي وسيبلي عقلي!'),
  line('ghazal', 9, 6922, 'يا جامد يا ابن اللذينة!'),
  line('ghazal', 10, 9953, 'ده إنت محتاج حراسة من المعجبين!'),
  line('funny', 1, 7654, 'يا جماعة حد يلمّ الجمال ده من على الأرض!'),
  line('funny', 2, 10815, 'ادخلوا بالراحة، الكاريزما هنا عليها أحمال زيادة!'),
  line('funny', 3, 12304, 'يا نجم، النور عندك عالي لدرجة إننا هنطلب فاتورة كهربا!'),
  line('funny', 4, 10240, 'صاحبنا دخل الشات، يا ريت حد يشرحله قواعد الجاذبية!'),
  line('funny', 5, 9247, 'إيه يا عم، داخل تسلّم ولا تستلم قلوب؟'),
  line('funny', 6, 12382, 'تم رصد كمية ثقة غير مرخصة في الغرفة!'),
  line('funny', 7, 10710, 'الرجاء عدم الاقتراب، الشخصية تحت الاختبار!'),
  line('funny', 8, 11180, 'اللي داخل يتغزل ياخد رقم، الدور طويل!'),
  line('tease', 1, 7210, 'إنت مش غبي، إنت بس بتدي الذكاء فرصة يثبت نفسه بعيد عنك!'),
  line('tease', 2, 5721, 'إنت لو التركيز فلوس، كنت استلفت مننا.'),
  line('tease', 3, 7811, 'يا ابني إنت محتاج تحديث نظام، واضح إن النسخة دي فيها مشاكل!'),
  line('tease', 4, 5198, 'مخك مش فاضي، ده لسه تحت التشطيب!'),
  line('tease', 5, 6713, 'يا عم إنت لو كنت إجابة، كنت هتبقى «حاول مرة أخرى»!'),
  line('tease', 6, 5564, 'إنت مش بتقول أي كلام، إنت بتعمل محتوى تجريبي!'),
  line('tease', 7, 6504, 'ربنا مديك قبول، بس واضح إنه مشغول دلوقتي!'),
  line('tease', 8, 5172, 'إنت مش غامض، إنت بس محدش مهتم يسأل!'),
  line('tease', 9, 7079, 'طب جرّب تتكلم من غير ما تفكر، يمكن نوصل لنفس النتيجة بس أسرع!'),
];

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
