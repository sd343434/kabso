/**
 * D391 (v1.118-live, CONVENTIONS §10.180): «البث الآن» — a live in a 4-way PK «PK رباعي» shows its badge and the two
 * teams (this room's team first); the live's dialog lists the four places; the moderator's end is
 * `lives.moderate` (OWNER, MODERATION). Both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D391, EN_D391 } from '../src/i18n-d391';
import { LiveCard, Pk4Hosts, type LivePk4, type LiveRow } from '../src/pages/Lives';
import { CAPABILITY_ROLES } from './capabilities';

const state = (lang: Lang): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can: () => true,
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>);

const pk4: LivePk4 = {
  matchId: '0192f1d0-3333-7aaa-8bbb-0c0d0e0f1011',
  status: 'BATTLE',
  format: 'TEAMS',
  team: 'B',
  hosts: [
    { seat: 1, team: 'A', roomId: 'r1', username: 'sara', displayName: 'Sara', score: 53200, out: false },
    { seat: 2, team: 'A', roomId: 'r2', username: 'layla', displayName: 'Layla', score: 12400, out: true },
    { seat: 3, team: 'B', roomId: 'r3', username: 'karim', displayName: 'Karim', score: 50300, out: false },
    { seat: 4, team: 'B', roomId: 'r4', username: 'ziad', displayName: 'Ziad', score: 13000, out: false },
  ],
};

const base: LiveRow = {
  id: 'r3',
  title: 'سهرة',
  mode: 'SOLO',
  viewers: 12,
  startedAt: new Date().toISOString(),
  coverUrl: null,
  score: 0,
  categoryAr: null,
  categoryEn: null,
  host: { id: 'u3', username: 'karim', displayName: 'Karim', avatarUrl: null },
  pk: null,
};

describe('D391 4-way PK lives in the panel', () => {
  it('has every string in both languages', () => {
    expect(Object.keys(EN_D391).sort()).toEqual(Object.keys(AR_D391).sort());
    for (const k of Object.keys(AR_D391) as (keyof typeof AR_D391)[]) {
      expect(DICTIONARIES.ar[k]).toBe(AR_D391[k]);
      expect(DICTIONARIES.en[k]).toBe(EN_D391[k]);
    }
  });

  it('the card: the 4-way badge and the teams, this room’s team first (ar, en)', () => {
    const ar = html('ar', <LiveCard live={{ ...base, pk4 }} onOpen={() => undefined} />);
    expect(ar).toContain('data-live-pk4="true"');
    expect(ar).toContain('PK رباعي');
    expect(ar).toContain('@karim + @ziad ضد @sara + @layla');
    const en = html('en', <LiveCard live={{ ...base, pk4 }} onOpen={() => undefined} />);
    expect(en).toContain('4-way PK');
    expect(en).toContain('@karim + @ziad vs @sara + @layla');
  });

  it('a live not in a 4-way PK shows no 4-way badge', () => {
    const out = html('ar', <LiveCard live={base} onOpen={() => undefined} />);
    expect(out).not.toContain('data-live-pk4');
    expect(out).not.toContain('PK رباعي');
  });

  it('the dialog lists the four places with their teams, scores and who left', () => {
    const out = html('en', <Pk4Hosts pk4={pk4} />);
    expect(out.match(/data-pk4-seat=/g)).toHaveLength(4);
    expect(out).toContain('Team A');
    expect(out).toContain('@layla');
    expect(out).toContain('Left');
    expect(out).toMatch(/data-pk4-seat="3" data-pk4-team="B" data-own-team="true"/);
  });

  it('the moderator’s end needs lives.moderate (OWNER, MODERATION)', () => {
    expect(CAPABILITY_ROLES['lives.moderate']).toEqual(['OWNER', 'MODERATION']);
  });
});
