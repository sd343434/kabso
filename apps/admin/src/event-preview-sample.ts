/**
 * D356 (CONVENTIONS §10.152) — SAMPLE DATA, the live preview only. The leaderboards the event page preview draws while
 * an event is being designed: made-up entrants (no real user, no photo — the app shows Kabso's default picture), in the
 * API's `EventLeaderboard` shape so the preview reads them with the app's own `EventLeaderboard.fromJson`. The page
 * says «معاينة · بيانات المتصدرين تجريبية» over them. Never sent to the server, never shown outside the preview.
 */
import type { PreviewState } from './event-design';

const NAMES_AR = ['سارة', 'خالد', 'ليان', 'عمر', 'نورة', 'أحمد', 'ريم', 'يوسف', 'هدى', 'كريم', 'لمى', 'زياد'];
const NAMES_EN = ['Sara', 'Khaled', 'Layan', 'Omar', 'Noura', 'Ahmed', 'Reem', 'Yousef', 'Huda', 'Karim', 'Lama', 'Ziad'];

/** The viewer's sample place (the gold «مركزي» bar). */
export const SAMPLE_MY_RANK = 8;

const sampleUser = (i: number, names: readonly string[], suffix = '') => ({
  id: `sample-${String(i)}${suffix}`,
  username: `sample${String(i)}${suffix}`,
  displayName: names[i % names.length]!,
  avatarUrl: null,
});

/** One board's sample rows (12 entrants above the board's minimum; CP pairs; AGENCIES agencies). */
export function sampleLeaderboard(kind: string, minPoints: number, lang: 'ar' | 'en', state: PreviewState) {
  const names = lang === 'ar' ? NAMES_AR : NAMES_EN;
  const data = names.map((_, i) => ({
    rank: i + 1,
    user: sampleUser(i, names),
    ...(kind === 'CP' ? { partner: sampleUser(names.length - 1 - i, names, 'p') } : {}),
    ...(kind === 'AGENCIES' ? { agency: { name: lang === 'ar' ? `وكالة ${names[i]!}` : `${names[i]!} Agency` } } : {}),
    score: Math.round(8_650_000 / (i + 1) / (i + 1)) + minPoints,
    qualified: true,
    prize: [],
    prizeCoins: 0,
  }));
  const me = data[SAMPLE_MY_RANK - 1]!;
  return {
    board: kind,
    minPoints,
    final: state === 'ENDED',
    data,
    me: { rank: SAMPLE_MY_RANK, score: me.score, prizeCoins: 0, qualified: true, pointsToQualify: 0, prize: [] },
  };
}

/** The sample boards of a draft (`previewEvent`'s `boards`), by board kind. */
export function sampleLeaderboards(
  event: Record<string, unknown>,
  lang: 'ar' | 'en',
  state: PreviewState,
): Record<string, ReturnType<typeof sampleLeaderboard>> {
  const boards = (Array.isArray(event.boards) ? event.boards : []) as { kind: string; minPoints?: number }[];
  return Object.fromEntries(boards.map((b) => [b.kind, sampleLeaderboard(b.kind, Number(b.minPoints) || 0, lang, state)]));
}
