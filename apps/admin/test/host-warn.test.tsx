/**
 * D273b «تحذير المضيف»: the panel's WARN — on the live card's ⋯ menu and the watch view's actions only for the roles
 * with `lives.moderate` (the capability the API requires), a written message required, the same
 * `POST /admin/lives/{roomId}/moderate` body as the app's staff tools; the moderation history names WARN «تحذير
 * للمضيف» / "Host warned" (and every other kind by its label, never the raw kind). Both languages.
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Key, type Lang } from '../src/i18n';
import { AR_D273B, EN_D273B } from '../src/i18n-d273b';
import { liveActions, moderateRequest, ModerateDialog, moderationKindLabel, type ModForm } from '../src/pages/LiveModeration';
import { LiveCard, type LiveRow } from '../src/pages/Lives';
import { ModerationHistory, type LiveModerationRow } from '../src/pages/LiveWatch';
import { PreviewPool } from '../src/live-media';
import type { Capability, PanelRole } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const state = (lang: Lang, can: (c: Capability) => boolean = () => true): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: null,
  can,
  toast: () => undefined,
});
const roleCan = (role: PanelRole) => (c: Capability) => (CAPABILITY_ROLES[c] ?? []).includes(role);
const html = (lang: Lang, node: React.ReactNode, can?: (c: Capability) => boolean) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, can)}>{node}</AppContext.Provider>);

const live: LiveRow = {
  id: '0192f1d0-1111-7aaa-8bbb-0c0d0e0f1011',
  title: 'سهرة',
  mode: 'SOLO',
  viewers: 42,
  startedAt: new Date().toISOString(),
  coverUrl: null,
  score: 0,
  categoryAr: null,
  categoryEn: null,
  host: { id: 'h1', username: 'coin0001', displayName: 'jgjg', avatarUrl: null },
  pk: null,
  openReports: 0,
};

describe('D273b strings', () => {
  it('has every string in both languages', () => {
    expect(Object.keys(EN_D273B).sort()).toEqual(Object.keys(AR_D273B).sort());
    for (const k of Object.keys(AR_D273B) as (keyof typeof AR_D273B)[]) {
      expect(DICTIONARIES.ar[k]).toBe(AR_D273B[k]);
      expect(DICTIONARIES.en[k]).toBe(EN_D273B[k]);
    }
    expect(AR_D273B.modWarn).toBe('تحذير المضيف');
    expect(AR_D273B.modKindWARN).toBe('تحذير للمضيف');
    expect(EN_D273B.modKindWARN).toBe('Host warned');
  });
});

describe('D273b «تحذير المضيف» by role', () => {
  it('the API capability: lives.moderate (OWNER, MODERATION)', () => {
    expect(CAPABILITY_ROLES['lives.moderate']).toEqual(['OWNER', 'MODERATION']);
  });

  for (const role of ['OWNER', 'MODERATION'] as const) {
    it(`${role}: WARN next to «إغلاق البث» on the card menu and the watch view (on air only)`, () => {
      expect(liveActions(roleCan(role) as never, true, 0)).toContain('WARN');
      expect(liveActions(roleCan(role) as never, false, 2)).not.toContain('WARN');
      const out = html(
        'ar',
        <LiveCard live={live} pool={new PreviewPool()} onOpen={() => undefined} onAction={() => undefined} menuOpen />,
        roleCan(role),
      );
      expect(out).toContain('data-action="END"');
      expect(out).toMatch(/<button role="menuitem" class="menu-row" data-action="WARN">.*تحذير المضيف<\/button>/);
      expect(out.indexOf('data-action="END"')).toBeLessThan(out.indexOf('data-action="WARN"'));
      const en = html(
        'en',
        <LiveCard live={live} pool={new PreviewPool()} onOpen={() => undefined} onAction={() => undefined} menuOpen />,
        roleCan(role),
      );
      expect(en).toContain('Warn the host');
    });
  }

  for (const role of ['SUPPORT', 'FINANCE'] as const) {
    it(`${role}: no WARN anywhere`, () => {
      expect(liveActions(roleCan(role) as never, true, 2)).not.toContain('WARN');
      const out = html(
        'ar',
        <LiveCard live={live} pool={new PreviewPool()} onOpen={() => undefined} onAction={() => undefined} menuOpen />,
        roleCan(role),
      );
      expect(out).not.toContain('data-action="WARN"');
      expect(out).not.toContain('تحذير المضيف');
    });
  }
});

describe('D273b the dialog', () => {
  const form = (patch: Partial<ModForm>): ModForm => ({
    action: 'WARN',
    scope: 'NO_LIVE',
    duration: '24h',
    until: '',
    reason: '',
    totpCode: '',
    ...patch,
  });

  it('sends the app’s body to the same route; a written message is required', () => {
    const id = live.id;
    expect(moderateRequest(id, form({ reason: '  لا ألفاظ  ' }))).toEqual({
      path: `/admin/lives/${id}/moderate`,
      body: { action: 'WARN', reason: 'لا ألفاظ' },
    });
    expect(moderateRequest(id, form({ reason: '' }))).toBeNull();
    expect(moderateRequest(id, form({ reason: '   ' }))).toBeNull();
    // Never a duration or a code with a warning.
    expect(moderateRequest(id, form({ reason: 'x', duration: '7d', totpCode: '123456' }))?.body).toEqual({
      action: 'WARN',
      reason: 'x',
    });
  });

  it('no scope, duration or code; the message field; the confirm stays off until written', () => {
    const empty = html(
      'ar',
      <ModerateDialog roomId={live.id} host="@coin0001" action="WARN" onClose={() => undefined} onDone={() => undefined} />,
    );
    expect(empty).toContain('data-mod-action="WARN"');
    expect(empty).toContain('تحذير المضيف — ⁦@coin0001⁩');
    expect(empty).toContain('رسالة التحذير (تصل للمضيف)');
    expect(empty).toContain('«فريق Kabso»');
    expect(empty).not.toContain('name="scope"');
    expect(empty).not.toContain('data-duration=');
    expect(empty).not.toContain('mod-code');
    expect(empty).toMatch(/<button type="submit" class="btn primary" disabled="">/);
    const filled = html(
      'en',
      <ModerateDialog
        roomId={live.id}
        host="@coin0001"
        action="WARN"
        initial={{ reason: 'Mind the language' }}
        onClose={() => undefined}
        onDone={() => undefined}
      />,
    );
    expect(filled).toContain('Warning message (sent to the host)');
    expect(filled).toMatch(/<button type="submit" class="btn primary">Warn the host<\/button>/);
  });
});

describe('D273b the moderation history', () => {
  const rows: LiveModerationRow[] = [
    {
      id: 'm2',
      kind: 'WARN',
      reason: 'Mind the language',
      endsAt: null,
      createdAt: '2026-11-05T10:00:00.000Z',
      actor: { id: 'a1', username: 'mod1', displayName: 'Mod', avatarUrl: null },
    },
    {
      id: 'm1',
      kind: 'NO_LIVE',
      reason: 'Spam',
      endsAt: '2026-11-06T10:00:00.000Z',
      createdAt: '2026-11-05T09:00:00.000Z',
      actor: null,
    },
  ];

  it('WARN reads «تحذير للمضيف» / "Host warned", never the raw kind', () => {
    const ar = html('ar', <ModerationHistory rows={rows} />);
    expect(ar).toContain('<b data-mod-kind="WARN">تحذير للمضيف</b>');
    expect(ar).toContain('<b data-mod-kind="NO_LIVE">منع من البث</b>');
    expect(ar).not.toMatch(/>WARN</);
    expect(ar).not.toMatch(/>NO_LIVE</);
    expect(ar).toContain('Mind the language');
    const en = html('en', <ModerationHistory rows={rows} />);
    expect(en).toContain('<b data-mod-kind="WARN">Host warned</b>');
    expect(en).toContain('<b data-mod-kind="NO_LIVE">Banned from going live</b>');
  });

  it('every kind has a label in both languages; an unknown kind shows as is; nothing without rows', () => {
    for (const lang of ['ar', 'en'] as const) {
      const t = (k: Key) => translate(lang, k);
      for (const k of ['END', 'WARN', 'NO_LIVE', 'SUSPEND', 'DEVICE_BAN']) expect(moderationKindLabel(t, k)).not.toBe(k);
      expect(moderationKindLabel(t, 'FUTURE')).toBe('FUTURE');
    }
    expect(html('ar', <ModerationHistory rows={[]} />)).toBe('');
  });
});
