/**
 * D395 (v1.119-live, CONVENTIONS §10.181): «البث الآن» — a live in a FREE_FOR_ALL «الكل ضد الكل» 4-way PK lists its hosts
 * each alone (no teams) with their places once it ended; a TEAMS PK with three hosts shows «@a + @b ضد @c»; the
 * format, the hosts playing and «PK أحكام» in the live's dialog. Both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { AR_D391, EN_D391 } from '../src/i18n-d391';
import {
  LiveCard,
  Pk4Hosts,
  pk4TeamsLine,
  type LivePk4,
  type LiveRow,
} from '../src/pages/Lives';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode) =>
  renderToStaticMarkup(
    <AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>,
  );

const ffa: LivePk4 = {
  matchId: '0192f1d0-3333-7aaa-8bbb-0c0d0e0f1099',
  status: 'RESULT',
  format: 'FREE_FOR_ALL',
  type: 'DARES',
  playerCount: 3,
  team: 'A',
  hosts: [
    {
      seat: 1,
      team: 'A',
      roomId: 'r1',
      username: 'sara',
      displayName: 'Sara',
      score: 500,
      out: false,
      place: 2,
    },
    {
      seat: 2,
      team: 'A',
      roomId: 'r2',
      username: 'layla',
      displayName: 'Layla',
      score: 900,
      out: false,
      place: 1,
    },
    {
      seat: 3,
      team: 'B',
      roomId: 'r3',
      username: 'karim',
      displayName: 'Karim',
      score: 100,
      out: true,
      place: 3,
    },
  ],
};

const base: LiveRow = {
  id: 'r1',
  title: 'سهرة',
  mode: 'SOLO',
  viewers: 12,
  startedAt: new Date().toISOString(),
  coverUrl: null,
  score: 0,
  categoryAr: null,
  categoryEn: null,
  host: { id: 'u1', username: 'sara', displayName: 'Sara', avatarUrl: null },
  pk: null,
};

describe('D395 4-way PK for two to four, FREE_FOR_ALL, in the panel', () => {
  it('has the new strings in both languages', () => {
    for (const k of [
      'livePk4Ffa',
      'livePk4Player',
      'livePk4Place',
      'livePk4Dares',
      'livePk4Players',
    ] as const) {
      expect(AR_D391[k]).toBeTruthy();
      expect(EN_D391[k]).toBeTruthy();
    }
  });

  it('the card: FREE_FOR_ALL lists each host alone (ar, en)', () => {
    const ar = html(
      'ar',
      <LiveCard live={{ ...base, pk4: ffa }} onOpen={() => undefined} />,
    );
    expect(ar).toContain('الكل ضد الكل: @sara · @layla · @karim');
    const en = html(
      'en',
      <LiveCard live={{ ...base, pk4: ffa }} onOpen={() => undefined} />,
    );
    expect(en).toContain('Free for all: @sara · @layla · @karim');
  });

  it('TEAMS with three hosts: two v one', () => {
    const three: LivePk4 = { ...ffa, format: 'TEAMS', type: 'NORMAL' };
    expect(pk4TeamsLine(three, (key, vars) => translate('en', key, vars))).toBe(
      '@sara + @layla vs @karim',
    );
  });

  it('the dialog: a player per place and the places at the end', () => {
    const out = html('ar', <Pk4Hosts pk4={ffa} />);
    expect(out.match(/data-pk4-seat=/g)).toHaveLength(3);
    expect(out).toContain('لاعب 1');
    expect(out).toContain('المركز 1');
    expect(out).toContain('غادر');
    expect(out).not.toContain('فريق A');
  });
});
