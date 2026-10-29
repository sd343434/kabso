import { Inject, Injectable } from '@nestjs/common';
import type { ContentLanguage } from '../../common/http/content-language.js';
import { Clock } from '../../common/time/clock.js';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { svipTierFor } from './programs-rules.js';

const DAY_MS = 86_400_000;

/** The ledger reasons that are gift spending (CP-024 §4: SVIP is earned by supporting people). */
export const SVIP_SPEND_REASONS = ['LIVE_GIFT', 'LUCKY_GIFT', 'DM_GIFT', 'CP_GIFT'] as const;

/** An SVIP perk (CP-024 §3–4). `available`: the app really does it today. */
export type SvipPerkCode =
  | 'BADGE'
  | 'AVATAR_FRAME'
  | 'CHAT_NAME_COLOR'
  | 'ENTRY_BANNER'
  | 'ENTRY_EFFECT'
  | 'DAILY_BULLET'
  | 'VIEWER_LIST_PRIORITY'
  | 'MONTHLY_GIFT';

interface SvipPerkDef {
  readonly code: SvipPerkCode;
  readonly unlockTier: number;
  readonly nameAr: string;
  readonly nameEn: string;
}

/**
 * The perks and the tier that unlocks each (CP-024 §3–4 mapped onto the three default tiers). None is
 * built yet — each needs Kabso-owned art or a change in the live room (follow-ups listed in the PR) —
 * so every one is `available: false` and the app shows it as coming, never as active.
 */
const SVIP_PERKS: readonly SvipPerkDef[] = [
  { code: 'BADGE', unlockTier: 1, nameAr: 'شارة SVIP', nameEn: 'SVIP badge' },
  { code: 'AVATAR_FRAME', unlockTier: 1, nameAr: 'إطار الصورة', nameEn: 'Avatar frame' },
  { code: 'CHAT_NAME_COLOR', unlockTier: 1, nameAr: 'اسم ملوّن في الدردشة', nameEn: 'Coloured chat name' },
  { code: 'ENTRY_BANNER', unlockTier: 2, nameAr: 'لافتة الدخول', nameEn: 'Entry banner' },
  { code: 'DAILY_BULLET', unlockTier: 2, nameAr: 'رسالة عامة مجانية يومياً', nameEn: 'Free daily bullet' },
  { code: 'ENTRY_EFFECT', unlockTier: 3, nameAr: 'مؤثر الدخول', nameEn: 'Entry effect' },
  {
    code: 'VIEWER_LIST_PRIORITY',
    unlockTier: 3,
    nameAr: 'أولوية في قائمة المشاهدين',
    nameEn: 'Viewer list priority',
  },
  { code: 'MONTHLY_GIFT', unlockTier: 3, nameAr: 'هدية شهرية في الحقيبة', nameEn: 'Monthly bag gift' },
];

/** `SvipStatus` (openapi v1.44-social, D166). */
export interface SvipStatusDto {
  /** 0 = not SVIP. */
  tier: number;
  /** When the status ends (null when not SVIP). */
  expiresAt: string | null;
  windowDays: number;
  statusDays: number;
  /** Coins spent on gifts in the last `windowDays` days. */
  spentCoins: number;
  tiers: { tier: number; thresholdCoins: number }[];
  /** The next tier above the caller's, null at the top. */
  nextTier: number | null;
  /** Coins still to spend in the window to reach `nextTier` (0 when the next spend would do it). */
  coinsToNext: number | null;
  perks: { code: SvipPerkCode; name: string; unlockTier: number; unlocked: boolean; available: boolean }[];
}

/**
 * SVIP (v1.44-social, D166, CP-024 §4 approved with defaults, CONVENTIONS §10.41): earned, never bought.
 * The status is computed from the ledger alone, so it needs no table and no job: at every gift spend
 * (`LIVE_GIFT`, `LUCKY_GIFT`, `DM_GIFT`, `CP_GIFT`) the rolling `SVIP_WINDOW_DAYS` total is taken; the
 * caller holds the highest tier whose threshold such a total met within the last `SVIP_STATUS_DAYS`
 * days, until `SVIP_STATUS_DAYS` after the last time it was met.
 */
@Injectable()
export class SvipService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly clock: Clock,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** `GET /me/svip`. */
  async mine(me: string, lang: ContentLanguage): Promise<SvipStatusDto> {
    const { svipTiers, svipWindowDays, svipStatusDays } = this.config.programs;
    const now = this.clock.now();
    const windowStart = new Date(now.getTime() - svipWindowDays * DAY_MS);
    const historyStart = new Date(now.getTime() - (svipWindowDays + svipStatusDays) * DAY_MS);
    const statusStart = new Date(now.getTime() - svipStatusDays * DAY_MS);
    // Every gift spend of the last window + status days, with the rolling window total at that moment
    // (the reasons are SVIP_SPEND_REASONS).
    const spends = await this.prisma.$queryRaw<{ at: Date; amount: bigint; total: bigint }[]>`
      SELECT created_at AS at, -delta AS amount,
             sum(-delta) OVER (ORDER BY created_at
                               RANGE BETWEEN make_interval(days => ${svipWindowDays}::int) PRECEDING
                                         AND CURRENT ROW)::bigint AS total
        FROM wallet_ledger
       WHERE user_id = ${me}::uuid AND reason IN ('LIVE_GIFT', 'LUCKY_GIFT', 'DM_GIFT', 'CP_GIFT') AND delta < 0
         AND created_at > ${historyStart}::timestamptz AND created_at <= ${now}::timestamptz
       ORDER BY created_at, id`;
    let tier = 0;
    let lastMet: Date | null = null;
    for (const s of spends) {
      if (s.at <= statusStart) continue;
      const reached = svipTierFor(Number(s.total), svipTiers);
      if (reached > 0 && reached >= tier) {
        tier = reached;
        lastMet = s.at;
      }
    }
    const spent = spends.filter((s) => s.at > windowStart).reduce((sum, s) => sum + Number(s.amount), 0);
    const nextTier = tier < svipTiers.length ? tier + 1 : null;
    return {
      tier,
      expiresAt: lastMet ? new Date(lastMet.getTime() + svipStatusDays * DAY_MS).toISOString() : null,
      windowDays: svipWindowDays,
      statusDays: svipStatusDays,
      spentCoins: spent,
      tiers: svipTiers.map((t, i) => ({ tier: i + 1, thresholdCoins: t })),
      nextTier,
      coinsToNext: nextTier === null ? null : Math.max(0, svipTiers[nextTier - 1]! - spent),
      perks: SVIP_PERKS.map((p) => ({
        code: p.code,
        name: lang === 'ar' ? p.nameAr : p.nameEn,
        unlockTier: p.unlockTier,
        unlocked: tier >= p.unlockTier,
        available: false,
      })),
    };
  }
}
