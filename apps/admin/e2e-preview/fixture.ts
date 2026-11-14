import type { PreviewState } from '../src/event-design';
import { sampleLeaderboards } from '../src/event-preview-sample';

/**
 * A render message of protocol v2 as the panel sends it: [m] plus the panel's SAMPLE leaderboards of its event's boards
 * (a message without an `event` object is left as it is: the bad-message case).
 */
export function render(m: Record<string, unknown>): Record<string, unknown> {
  const event = m.event as Record<string, unknown> | undefined;
  const ok = event && Array.isArray(event.boards);
  return {
    type: 'kabso.eventPreview.render',
    v: 2,
    ...m,
    ...(ok
      ? { leaderboards: sampleLeaderboards(event, m.language === 'en' ? 'en' : 'ar', (m.state ?? 'RUNNING') as PreviewState) }
      : {}),
  };
}

/** D356: a draft gift event as the panel posts it to the preview (`EventDetail` JSON, no art). */
export function sampleEvent(design: unknown, ar = true): Record<string, unknown> {
  return {
    id: 'preview',
    title: ar ? 'ملك الهدايا' : 'Gift King',
    rules: ar ? 'شارك بإرسال هدايا الفعالية في أي بث.' : 'Send the event gifts in any live.',
    metric: 'EVENT_GIFTS',
    audience: 'EVERYONE',
    permanent: false,
    featured: true,
    timeZone: 'Asia/Riyadh',
    art: { background: null, titleUrl: null, overlay: null },
    gifts: [
      { code: 'rose', name: ar ? 'وردة' : 'Rose', priceCoins: 100, assetKey: 'rose', imageUrl: null, pointsPerCoin: 1, pointsPerGift: 0, pointsEach: 100 },
    ],
    boards: [
      {
        kind: 'SENDERS',
        minPoints: 1000,
        shown: 20,
        prizes: [
          { rankFrom: 1, rankTo: 1, items: [{ type: 'COINS', amount: 100000 }] },
          { rankFrom: 2, rankTo: 3, items: [{ type: 'COINS', amount: 50000 }] },
          { rankFrom: 4, rankTo: 10, items: [{ type: 'COINS', amount: 5000 }] },
        ],
      },
    ],
    milestones: [],
    paidAt: null,
    payoutDueAt: null,
    design,
  };
}

export const DESIGN = {
  v: 1,
  layout: 'HERO_PODIUM',
  leaderboard: 'PODIUM',
  countdown: 'FLIP',
  preset: 'LUXURY_GOLD',
  rulesButton: { style: 'GOLD_PILL', edge: 'END' },
  sections: ['BOARDS', 'GIFTS', 'RULES', 'REWARDS', 'MILESTONES'].map((id) => ({ id, visible: true })),
  leaderboardBackgroundMediaId: null,
  leaderboardBackgroundUrl: null,
  rewards: null,
  motion: { entrance: 'FADE', durationMs: 450, shimmer: true, pulseFirst: true, overlaySpeed: 1, overlayOpacity: 1 },
};
