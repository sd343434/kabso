/**
 * D301 «صندوق المؤسس» in the panel: the strings in both languages, the menu entry for the OWNER only (MODERATION,
 * SUPPORT, FINANCE and BD never see it: staff never see reports about staff), the table and an item with its private
 * pictures and status buttons (rendered from fixtures shaped like openapi v1.95-social).
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { translate, type Lang } from '../src/i18n';
import { AR_D301, EN_D301 } from '../src/i18n-d301';
import { visibleNav } from '../src/nav';
import { matchPath } from '../src/router';
import {
  DeleteConfirm,
  InboxDetail,
  InboxTable,
  inboxImageUrl,
  type InboxItem,
} from '../src/pages/OwnerInbox';
import type { Capability, PanelRole } from '../src/types';
import { CAPABILITY_ROLES } from './capabilities';

const capsOf = (role: PanelRole) =>
  (Object.keys(CAPABILITY_ROLES) as Capability[]).filter((c) => CAPABILITY_ROLES[c]!.includes(role));
const state = (lang: Lang, role: PanelRole = 'OWNER'): AppState => ({
  lang,
  t: (key, vars) => translate(lang, key, vars),
  session: {
    admin: {
      id: 'self',
      email: 'o@kabso.test',
      username: 'o',
      displayName: 'O',
    },
    roles: [role],
    capabilities: capsOf(role),
    csrfToken: 'csrf',
    expiresAt: '2026-11-07T20:00:00.000Z',
    idleSeconds: 1800,
  },
  can: (cap) => capsOf(role).includes(cap),
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode) =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang)}>{node}</AppContext.Provider>);

const report: InboxItem = {
  id: '0192f000-0000-7000-8000-000000000001',
  kind: 'STAFF_REPORT',
  status: 'READ',
  text: 'حظرني بدون سبب',
  category: 'ABUSE_OF_POWER',
  sender: {
    id: 'u1',
    username: 'bob',
    displayName: 'Bob',
    avatarUrl: null,
    staffId: null,
  },
  staff: {
    id: 's1',
    username: 'mod_sara',
    displayName: 'Sara',
    avatarUrl: null,
    staffId: 'Kabso01',
  },
  imageCount: 2,
  createdAt: '2026-11-07T09:00:00.000Z',
  readAt: '2026-11-07T09:05:00.000Z',
  doneAt: null,
};
const feature: InboxItem = {
  ...report,
  id: '0192f000-0000-7000-8000-000000000002',
  kind: 'FEATURE',
  status: 'NEW',
  text: 'Co-hosted lives please',
  category: null,
  staff: null,
  imageCount: 0,
  readAt: null,
};

describe('D301 «صندوق المؤسس»', () => {
  it('has every string in both languages', () => {
    expect(Object.keys(EN_D301).sort()).toEqual(Object.keys(AR_D301).sort());
    for (const v of [...Object.values(AR_D301), ...Object.values(EN_D301)]) expect(v.trim()).not.toBe('');
    expect(translate('ar', 'navOwnerInbox')).toBe('صندوق المؤسس');
    expect(translate('en', 'navOwnerInbox')).toBe("Founder's inbox");
  });

  it('is in the menu for the OWNER only; staff never see it', () => {
    const has = (role: PanelRole) =>
      visibleNav((cap) => capsOf(role).includes(cap)).some((g) =>
        g.items.some((i) => i.to === '/owner-inbox'),
      );
    expect(has('OWNER')).toBe(true);
    for (const role of ['MODERATION', 'SUPPORT', 'FINANCE', 'BD'] as PanelRole[])
      expect(has(role)).toBe(false);
    expect(matchPath('/owner-inbox')?.name).toBe('ownerInbox');
  });

  for (const lang of ['ar', 'en'] as Lang[]) {
    it(`${lang}: the table shows the kind, the status, who and about whom`, () => {
      const out = html(lang, <InboxTable rows={[report, feature]} onOpen={() => undefined} />);
      expect(out).toContain(`data-item="${report.id}"`);
      expect(out).toContain('data-status="NEW"');
      expect(out).toContain(translate(lang, 'oiKindSTAFF_REPORT'));
      expect(out).toContain(translate(lang, 'oiCatABUSE_OF_POWER'));
      expect(out).toContain('@mod_sara');
      expect(out).toContain('Kabso01');
      expect(out).toContain('Co-hosted lives please');
    });
  }

  it('an item shows its private pictures and the status buttons', () => {
    const out = html(
      'ar',
      <InboxDetail item={report} onStatus={() => undefined} onClose={() => undefined} />,
    );
    expect(out).toContain(inboxImageUrl(report.id, 0));
    expect(out).toContain(inboxImageUrl(report.id, 1));
    expect(out).toContain('referrerPolicy'.toLowerCase() === 'referrerpolicy' ? 'no-referrer' : '');
    expect(out).toContain(translate('ar', 'oiMarkDone'));
    expect(out).toContain('حظرني بدون سبب');
    const done = html('en', <InboxDetail item={{ ...report, status: 'DONE' }} onStatus={() => undefined} />);
    expect(done).toContain(translate('en', 'oiMarkRead'));
    expect(done).not.toContain('btn primary');
  });

  it('«حذف» asks first (owner, PP-58: kept until the owner deletes it)', () => {
    const item = html('ar', <InboxDetail item={report} onDelete={() => undefined} />);
    expect(item).toContain('data-delete');
    expect(item).toContain(translate('ar', 'oiDelete'));
    expect(html('ar', <InboxDetail item={report} />)).not.toContain('data-delete');
    const confirm = html('en', <DeleteConfirm onConfirm={() => undefined} onCancel={() => undefined} />);
    expect(confirm).toContain('role="dialog"');
    expect(confirm).toContain(translate('en', 'oiDeleteBody'));
    expect(confirm).toContain('data-confirm-delete');
  });

  it('an empty list says so', () => {
    expect(html('en', <InboxTable rows={[]} />)).toContain(translate('en', 'oiNone'));
  });
});
