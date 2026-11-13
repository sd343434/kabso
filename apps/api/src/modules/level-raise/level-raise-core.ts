import type { LevelRaiseSettings, LevelRaiseSourceApp, Prisma } from '../../generated/prisma/client.js';
import {
  DEFAULT_RAISE_SETTINGS,
  KABSO_COINS_PER_USD,
  MAX_RAISE_LEVEL,
  type Confidence,
  type Proposal,
  type RaiseSettings,
  type SourceAppMath,
  type XpPoint,
} from './level-raise-math.js';

type Db = Prisma.TransactionClient;

/**
 * v1.89-social (D290, CONVENTIONS §10.103): the data side of level-raise requests — the weights, the source apps,
 * the supporter's recharge and levels — and the DTOs (`LevelRaiseRequest`, `LevelRaiseProposal`, `LevelRaiseSourceApp`,
 * `LevelRaiseSettings` in openapi).
 */

/** The coin-ledger reasons of a recharge (D190 card top-ups and their reversals / restores, D185 sales, D204 orders). */
export const RECHARGE_REASONS = [
  'CARD_TOPUP',
  'CARD_TOPUP_REVERSAL',
  'CARD_TOPUP_RESTORE',
  'RECHARGE_PURCHASE',
  'RECHARGE_ORDER',
  // v1.110-social (D345): coins bought in a store and their claw-back.
  'STORE_IAP',
  'STORE_IAP_REVERSAL',
] as const;

export async function settingsRowIn(db: Db): Promise<LevelRaiseSettings> {
  const row = await db.levelRaiseSettings.findUnique({ where: { id: 1 } });
  if (row) return row;
  return db.levelRaiseSettings.upsert({ where: { id: 1 }, create: { id: 1 }, update: {} });
}

export function settingsOf(row: LevelRaiseSettings): RaiseSettings {
  return {
    minRechargeCoins: row.minRechargeCoins,
    firstDays: row.firstDays,
    anchorCoins: row.anchorCoins,
    firstDaysBaseLevel: row.firstDaysBaseLevel,
    totalBaseLevel: row.totalBaseLevel,
    levelsPerDoublingTenths: row.levelsPerDoublingTenths,
    supportBonusPer10: row.supportBonusPer10,
    supportBonusMax: row.supportBonusMax,
    charmBonusPer10: row.charmBonusPer10,
    charmBonusMax: row.charmBonusMax,
    belowTableExponentTenths: row.belowTableExponentTenths,
  };
}

/** `LevelRaiseSettings` (the decimals as numbers: 4.0 levels per doubling, exponent 3.0). */
export interface RaiseSettingsDto {
  minRechargeCoins: number;
  firstDays: number;
  anchorCoins: number;
  firstDaysBaseLevel: number;
  totalBaseLevel: number;
  levelsPerDoubling: number;
  supportBonusPer10Levels: number;
  supportBonusMax: number;
  charmBonusPer10Levels: number;
  charmBonusMax: number;
  belowTableExponent: number;
  maxLevel: number;
  kabsoUsdPerMillion: number;
}

export function settingsDto(s: RaiseSettings): RaiseSettingsDto {
  return {
    minRechargeCoins: Number(s.minRechargeCoins),
    firstDays: s.firstDays,
    anchorCoins: Number(s.anchorCoins),
    firstDaysBaseLevel: s.firstDaysBaseLevel,
    totalBaseLevel: s.totalBaseLevel,
    levelsPerDoubling: s.levelsPerDoublingTenths / 10,
    supportBonusPer10Levels: s.supportBonusPer10,
    supportBonusMax: s.supportBonusMax,
    charmBonusPer10Levels: s.charmBonusPer10,
    charmBonusMax: s.charmBonusMax,
    belowTableExponent: s.belowTableExponentTenths / 10,
    maxLevel: MAX_RAISE_LEVEL,
    kabsoUsdPerMillion: 1_000_000 / Number(KABSO_COINS_PER_USD),
  };
}

export const DEFAULT_SETTINGS_DTO = settingsDto(DEFAULT_RAISE_SETTINGS);

// ---- source apps -----------------------------------------------------------------------------------------------------

export interface XpPointDto {
  level: number;
  xp: number;
  confidence: Confidence;
}

/** `LevelRaiseSourceApp`. */
export interface SourceAppDto {
  id: string;
  code: string;
  nameAr: string;
  nameEn: string;
  mode: 'MONEY' | 'FACTOR';
  usdPerMillion: number | null;
  coinsPerXp: number | null;
  xpTable: XpPointDto[];
  factor: number | null;
  confidence: Confidence;
  sourceNote: string;
  sourceUrl: string | null;
  sourceDate: string | null;
  enabled: boolean;
  isOther: boolean;
  sort: number;
  /** Other spellings matched by the name suggestion (Zafa / زفة / Zafa Live …). */
  aliases: string[];
  updatedAt: string;
}

export function xpTableOf(json: Prisma.JsonValue): XpPoint[] {
  if (!Array.isArray(json)) return [];
  const out: XpPoint[] = [];
  for (const p of json) {
    if (p && typeof p === 'object' && !Array.isArray(p)) {
      const level = Number((p as Record<string, unknown>).level);
      const xp = Number((p as Record<string, unknown>).xp);
      const c = (p as Record<string, unknown>).confidence === 'CONFIRMED' ? 'CONFIRMED' : 'ESTIMATE';
      if (Number.isInteger(level) && level >= 1 && Number.isSafeInteger(xp) && xp >= 0) {
        out.push({ level, xp: BigInt(xp), confidence: c });
      }
    }
  }
  return out.sort((a, b) => a.level - b.level);
}

export function appMath(row: LevelRaiseSourceApp): SourceAppMath {
  return {
    mode: row.mode === 'MONEY' ? 'MONEY' : 'FACTOR',
    usdPerMillionCents: row.usdPerMillionCents,
    coinsPerXpMilli: row.coinsPerXpMilli,
    xpTable: xpTableOf(row.xpTable),
    factorMilli: row.factorMilli,
    confidence: row.confidence === 'CONFIRMED' ? 'CONFIRMED' : 'ESTIMATE',
  };
}

export function sourceAppDto(row: LevelRaiseSourceApp): SourceAppDto {
  return {
    id: row.id,
    code: row.code,
    nameAr: row.nameAr,
    nameEn: row.nameEn,
    mode: row.mode === 'MONEY' ? 'MONEY' : 'FACTOR',
    usdPerMillion: row.usdPerMillionCents === null ? null : Number(row.usdPerMillionCents) / 100,
    coinsPerXp: row.coinsPerXpMilli === null ? null : Number(row.coinsPerXpMilli) / 1000,
    xpTable: xpTableOf(row.xpTable).map((p) => ({
      level: p.level,
      xp: Number(p.xp),
      confidence: p.confidence,
    })),
    factor: row.factorMilli === null ? null : row.factorMilli / 1000,
    confidence: row.confidence === 'CONFIRMED' ? 'CONFIRMED' : 'ESTIMATE',
    sourceNote: row.sourceNote,
    sourceUrl: row.sourceUrl,
    sourceDate: row.sourceDate ? row.sourceDate.toISOString().slice(0, 10) : null,
    enabled: row.enabled,
    isOther: row.isOther,
    sort: row.sort,
    aliases: [...row.aliases],
    updatedAt: row.updatedAt.toISOString(),
  };
}

/** The short form staff see in the request form (no prices or notes). */
export interface SourceAppOptionDto {
  code: string;
  nameAr: string;
  nameEn: string;
  confidence: Confidence;
  isOther: boolean;
}

export function sourceAppOption(row: LevelRaiseSourceApp): SourceAppOptionDto {
  return {
    code: row.code,
    nameAr: row.nameAr,
    nameEn: row.nameEn,
    confidence: row.confidence === 'CONFIRMED' ? 'CONFIRMED' : 'ESTIMATE',
    isOther: row.isOther,
  };
}

// ---- the supporter's evidence ------------------------------------------------------------------------------------------

export interface EvidenceDto {
  /** Net recharged coins since the account's creation (top-ups, agent sales, recharge orders; reversals taken off). */
  totalRechargeCoins: number;
  /** The same in the first `firstDays` days after the account's creation. */
  firstDaysRechargeCoins: number;
  firstDays: number;
  accountCreatedAt: string;
  firstDaysEndAt: string;
  supportLevel: number;
  charmLevel: number;
  minRechargeCoins: number;
  eligible: boolean;
}

export interface Evidence {
  readonly totalRechargeCoins: bigint;
  readonly firstDaysRechargeCoins: bigint;
  readonly accountCreatedAt: Date;
  readonly firstDaysEndAt: Date;
  readonly supportLevel: number;
  readonly charmLevel: number;
}

export async function evidenceIn(db: Db, userId: string, settings: RaiseSettings): Promise<Evidence> {
  const user = await db.user.findUniqueOrThrow({ where: { id: userId }, select: { createdAt: true } });
  const end = new Date(user.createdAt.getTime() + settings.firstDays * 86_400_000);
  const [sums] = await db.$queryRaw<{ total: bigint; first: bigint }[]>`
    SELECT COALESCE(sum(delta), 0)::bigint AS total,
           COALESCE(sum(delta) FILTER (WHERE created_at < ${end}), 0)::bigint AS first
      FROM wallet_ledger
     WHERE user_id = ${userId}::uuid
       AND reason::text = ANY(${[...RECHARGE_REASONS]}::text[])`;
  const levels = await db.$queryRaw<{ code: string; level: number | null }[]>`
    SELECT c.code::text AS code, s.current_level AS level
      FROM user_level_states s JOIN level_categories c ON c.id = s.category_id
     WHERE s.user_id = ${userId}::uuid AND c.code IN ('SUPPORT', 'ATTRACTIVENESS')`;
  const of = (code: string) => levels.find((l) => l.code === code)?.level ?? 0;
  const clamp = (v: bigint | undefined) => (v === undefined || v < 0n ? 0n : v);
  return {
    totalRechargeCoins: clamp(sums?.total),
    firstDaysRechargeCoins: clamp(sums?.first),
    accountCreatedAt: user.createdAt,
    firstDaysEndAt: end,
    supportLevel: of('SUPPORT'),
    charmLevel: of('ATTRACTIVENESS'),
  };
}

export function evidenceDto(e: Evidence, s: RaiseSettings): EvidenceDto {
  return {
    totalRechargeCoins: Number(e.totalRechargeCoins),
    firstDaysRechargeCoins: Number(e.firstDaysRechargeCoins),
    firstDays: s.firstDays,
    accountCreatedAt: e.accountCreatedAt.toISOString(),
    firstDaysEndAt: e.firstDaysEndAt.toISOString(),
    supportLevel: e.supportLevel,
    charmLevel: e.charmLevel,
    minRechargeCoins: Number(s.minRechargeCoins),
    eligible: e.totalRechargeCoins >= s.minRechargeCoins,
  };
}

// ---- the proposal as shown --------------------------------------------------------------------------------------------

/** `LevelRaiseProposal`: the result and every number of its reasoning (the panel words each step). */
export interface ProposalDto {
  proposedLevel: number;
  limitedBy: Proposal['limitedBy'];
  eligible: boolean;
  maxLevel: number;
  app: { code: string | null; name: string; mode: 'MONEY' | 'FACTOR'; confidence: Confidence };
  sourceLevel: number;
  source:
    | {
        mode: 'MONEY';
        level: number;
        xp: number;
        xpMethod: string;
        xpFrom: XpPointDto[];
        sourceCoins: number;
        usd: number;
        usdPerMillion: number;
        coinsPerXp: number;
        kabsoCoins: number;
        kabsoPoints: number;
        kabsoUsdPerMillion: number;
      }
    | { mode: 'FACTOR'; level: number; factor: number }
    | { mode: 'NONE'; level: number };
  firstDaysCap: number;
  totalCap: number;
  rechargeCap: number;
  supportBonus: number;
  charmBonus: number;
  beforeClamp: number;
  evidence: EvidenceDto;
  settings: RaiseSettingsDto;
}

export function proposalDto(
  p: Proposal,
  app: { code: string | null; name: string; math: SourceAppMath },
  sourceLevel: number,
  evidence: Evidence,
  settings: RaiseSettings,
): ProposalDto {
  const s = p.source;
  const source: ProposalDto['source'] =
    s.mode === 'MONEY'
      ? {
          mode: 'MONEY',
          level: s.level,
          xp: Number(s.xp),
          xpMethod: s.xpMethod,
          xpFrom: s.xpFrom.map((x) => ({ level: x.level, xp: Number(x.xp), confidence: x.confidence })),
          sourceCoins: Number(s.sourceCoins),
          usd: Number(s.usdCents) / 100,
          usdPerMillion: Number(app.math.usdPerMillionCents ?? 0n) / 100,
          coinsPerXp: Number(app.math.coinsPerXpMilli ?? 0n) / 1000,
          kabsoCoins: Number(s.kabsoCoins),
          kabsoPoints: Number(s.kabsoPoints),
          kabsoUsdPerMillion: 1_000_000 / Number(KABSO_COINS_PER_USD),
        }
      : s.mode === 'FACTOR'
        ? { mode: 'FACTOR', level: s.level, factor: s.factorMilli / 1000 }
        : { mode: 'NONE', level: 0 };
  return {
    proposedLevel: p.proposedLevel,
    limitedBy: p.limitedBy,
    eligible: p.eligible,
    maxLevel: MAX_RAISE_LEVEL,
    app: { code: app.code, name: app.name, mode: app.math.mode, confidence: app.math.confidence },
    sourceLevel,
    source,
    firstDaysCap: p.firstDaysCap,
    totalCap: p.totalCap,
    rechargeCap: p.rechargeCap,
    supportBonus: p.supportBonus,
    charmBonus: p.charmBonus,
    beforeClamp: p.beforeClamp,
    evidence: evidenceDto(evidence, settings),
    settings: settingsDto(settings),
  };
}
