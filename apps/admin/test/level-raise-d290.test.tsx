/**
 * D290 «طلب رفع ليفيل» in the panel: the strings in both languages, the menu by role (MODERATION / SUPPORT see the
 * requests only; the OWNER also the source-app data and the weights), the review page's proposal with every step of its
 * reasoning (the owner's Zafa example), the approval field that only lowers, the source-app table's confidence labels,
 * the requests table, the XP-table and settings helpers (rendered from fixtures shaped like openapi v1.89-social).
 */
import { renderToStaticMarkup } from 'react-dom/server';
import { describe, expect, it } from 'vitest';
import { AppContext, type AppState } from '../src/context';
import { DICTIONARIES, translate, type Lang } from '../src/i18n';
import { AR_D290, EN_D290 } from '../src/i18n-d290';
import { visibleNav } from '../src/nav';
import { matchPath } from '../src/router';
import { ApiError } from '../src/api';
import {
  PreviousRejection,
  SuggestionList,
  VideoDeleted,
  duplicateText,
  suggestionLabel,
  type Suggestion,
  ApproveForm,
  AppsTable,
  EvidenceList,
  ProposalCard,
  RequestTable,
  approvalBounds,
  clampApproval,
  formatXpTable,
  parseXpTable,
  reasoningLines,
  settingChanges,
  type LevelRaise,
  type Proposal,
  type SourceApp,
} from '../src/pages/LevelRaises';
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
    expiresAt: '2026-11-06T20:00:00.000Z',
    idleSeconds: 1800,
  },
  can: (cap) => capsOf(role).includes(cap),
  toast: () => undefined,
});
const html = (lang: Lang, node: React.ReactNode, role: PanelRole = 'OWNER') =>
  renderToStaticMarkup(<AppContext.Provider value={state(lang, role)}>{node}</AppContext.Provider>);
const t = (lang: Lang) => state(lang).t;

/** The API's proposal for the owner's Zafa example with 1 000 000 recharged in the first week (e2e d290). */
const zafa: Proposal = {
  proposedLevel: 20,
  limitedBy: 'RECHARGE',
  eligible: true,
  maxLevel: 40,
  app: { code: 'ZAFA', name: 'Zafa', mode: 'MONEY', confidence: 'CONFIRMED' },
  sourceLevel: 32,
  source: {
    mode: 'MONEY',
    level: 58,
    xp: 27_742_536,
    xpMethod: 'TABLE',
    xpFrom: [{ level: 32, xp: 27_742_536, confidence: 'CONFIRMED' }],
    sourceCoins: 277_425_360,
    usd: 5548.5,
    usdPerMillion: 20,
    coinsPerXp: 10,
    kabsoCoins: 443_880_576,
    kabsoPoints: 44_388_057,
    kabsoUsdPerMillion: 12.5,
  },
  firstDaysCap: 20,
  totalCap: 15,
  rechargeCap: 20,
  supportBonus: 0,
  charmBonus: 0,
  beforeClamp: 20,
  evidence: {
    totalRechargeCoins: 1_000_000,
    firstDaysRechargeCoins: 1_000_000,
    firstDays: 7,
    accountCreatedAt: '2026-11-01T10:00:00.000Z',
    firstDaysEndAt: '2026-11-08T10:00:00.000Z',
    supportLevel: 3,
    charmLevel: 12,
    minRechargeCoins: 1_000_000,
    eligible: true,
  },
};

const request = (over: Partial<LevelRaise> = {}): LevelRaise => ({
  id: '11111111-1111-4111-8111-111111111111',
  status: 'PENDING',
  via: 'app',
  supporter: {
    id: 's',
    username: 'big_fan',
    displayName: 'داعم',
    avatarUrl: null,
  },
  requestedBy: {
    id: 'm',
    username: 'mod_one',
    displayName: 'مشرف',
    avatarUrl: null,
  },
  sourceApp: {
    code: 'ZAFA',
    nameAr: 'زفة',
    nameEn: 'Zafa',
    confidence: 'CONFIRMED',
    isOther: false,
  },
  sourceAppName: 'Zafa',
  sourceAccountId: '88123456',
  sourceLevel: 32,
  note: null,
  video: {
    id: 'v',
    durationMs: 20000,
    width: 1080,
    height: 1920,
    byteSize: 12_582_912,
    posterUrl: null,
    deletedAt: null,
  },
  previousRejection: null,
  createdAt: '2026-11-06T10:00:00.000Z',
  decidedAt: null,
  decidedBy: null,
  rejectReason: null,
  proposedLevel: null,
  approvedLevel: null,
  levelBefore: null,
  levelAfter: null,
  ...over,
});

const app = (over: Partial<SourceApp> = {}): SourceApp => ({
  id: 'a',
  code: 'ZAFA',
  nameAr: 'زفة',
  nameEn: 'Zafa',
  aliases: ['زافا', 'Zafa Live'],
  mode: 'MONEY',
  usdPerMillion: 20,
  coinsPerXp: 10,
  xpTable: [{ level: 32, xp: 27_742_536, confidence: 'CONFIRMED' }],
  factor: null,
  confidence: 'CONFIRMED',
  sourceNote: 'Owner (Zafa), 2026-11-06',
  sourceUrl: null,
  sourceDate: '2026-11-06',
  enabled: true,
  isOther: false,
  sort: 10,
  updatedAt: '2026-11-06T10:00:00.000Z',
  ...over,
});

describe('D290 strings and menu', () => {
  it('has every string in both languages, merged into the dictionaries', () => {
    expect(Object.keys(EN_D290).sort()).toEqual(Object.keys(AR_D290).sort());
    for (const k of Object.keys(AR_D290) as (keyof typeof AR_D290)[]) {
      expect(DICTIONARIES.ar[k]).toBe(AR_D290[k]);
      expect(DICTIONARIES.en[k]).toBe(EN_D290[k]);
    }
    expect(AR_D290.navLevelRaises).toBe('طلبات رفع الليفيل');
  });

  it('MODERATION and SUPPORT see the requests; only the OWNER the data and the weights; FINANCE / BD nothing', () => {
    const items = (role: PanelRole) =>
      visibleNav((c) => capsOf(role).includes(c))
        .flatMap((g) => g.items)
        .map((i) => i.to)
        .filter((to) => to.startsWith('/level-raise'));
    expect(items('OWNER')).toEqual(['/level-raises', '/level-raise/apps', '/level-raise/settings']);
    expect(items('MODERATION')).toEqual(['/level-raises']);
    expect(items('SUPPORT')).toEqual(['/level-raises']);
    expect(items('FINANCE')).toEqual([]);
    expect(items('BD')).toEqual([]);
    expect(matchPath('/level-raises/abc')?.name).toBe('levelRaise');
    expect(matchPath('/level-raise/apps')?.name).toBe('levelRaiseApps');
  });
});

describe('D290 the review page', () => {
  it('words every step of the Zafa example (level 32 → $5 548.5 → level 58, capped to 20 by the recharge)', () => {
    const ar = reasoningLines(zafa, t('ar'), 'ar');
    expect(ar[0]).toBe('التطبيق «Zafa» (مؤكد) — المستوى 32');
    expect(ar).toContain('الخبرة اللازمة: 27,742,536 XP (من جدول التطبيق)');
    expect(ar).toContain('27,742,536 XP × 10 عملة لكل XP = 277,425,360 عملة في التطبيق');
    expect(ar).toContain('277,425,360 عملة × $20 لكل مليون = $5,548.50');
    expect(ar).toContain('$5,548.50 بسعر كابسو ($12.5 لكل مليون) = 443,880,576 عملة = 44,388,057 نقطة دعم');
    expect(ar).toContain('= ليفيل الدعم 58 في كابسو (المستوى المكافئ)');
    expect(ar).toContain('شحن أول 7 أيام: 1,000,000 عملة ← سقف 20');
    expect(ar).toContain('الأقل بين 58 + 0 وسقف الشحن 20 = 20');
    expect(ar).toContain('لا أقل من الليفيل الحالي 3 ولا أكثر من 40 ← المقترح 20');
    expect(ar.at(-1)).toBe('حدّده شحن الداعم في كابسو (السقف).');
    const en = reasoningLines(zafa, t('en'), 'en');
    expect(en).toContain('= Kabso support level 58 (the equivalent level)');
    expect(en.join('\n')).not.toMatch(/\{\w+\}/);
    expect(ar.join('\n')).not.toMatch(/\{\w+\}/);
  });

  it('words the factor estimate and the interpolated XP', () => {
    const factor: Proposal = {
      ...zafa,
      app: {
        code: 'OTHER',
        name: 'تطبيق صوتي',
        mode: 'FACTOR',
        confidence: 'ESTIMATE',
      },
      source: { mode: 'FACTOR', level: 16, factor: 0.5 },
      limitedBy: 'SOURCE',
      proposedLevel: 16,
    };
    const ar = reasoningLines(factor, t('ar'), 'ar');
    expect(ar[0]).toContain('(تقدير)');
    expect(ar).toContain('لا يوجد جدول موثّق لهذا التطبيق: 32 × 0.5 = المستوى 16 (تقدير محافظ)');
    const between: Proposal = {
      ...zafa,
      source: {
        ...(zafa.source as Extract<Proposal['source'], { mode: 'MONEY' }>),
        xpMethod: 'INTERPOLATED',
        xpFrom: [
          { level: 10, xp: 1000, confidence: 'ESTIMATE' },
          { level: 20, xp: 100000, confidence: 'ESTIMATE' },
        ],
      },
    };
    expect(reasoningLines(between, t('en'), 'en')[1]).toContain('between levels 10 and 20');
  });

  it('renders the proposal card with the level, the confidence label and the steps, in both languages', () => {
    const ar = html('ar', <ProposalCard p={zafa} />);
    expect(ar).toContain('data-proposal="20"');
    expect(ar).toContain('data-confidence="CONFIRMED"');
    expect((ar.match(/<li>/g) ?? []).length).toBe(reasoningLines(zafa, t('ar'), 'ar').length);
    expect(html('en', <ProposalCard p={zafa} />)).toContain('Proposed level');
  });

  it('the approval field only lowers: from the current level to the proposal, never higher', () => {
    expect(approvalBounds(zafa)).toEqual({ min: 3, max: 20 });
    const b = approvalBounds(zafa);
    expect(clampApproval(25, b)).toBe(20);
    expect(clampApproval(12, b)).toBe(12);
    expect(clampApproval(1, b)).toBe(3);
    expect(clampApproval(Number.NaN, b)).toBe(20);
    // Already at or above the proposal: the only choice is the current level.
    const high = {
      ...zafa,
      proposedLevel: 45,
      evidence: { ...zafa.evidence, supportLevel: 45 },
    };
    expect(approvalBounds(high)).toEqual({ min: 45, max: 45 });
    const form = html('ar', <ApproveForm p={zafa} onApprove={() => Promise.resolve()} />);
    expect(form).toContain('min="3"');
    expect(form).toContain('max="20"');
    expect(form).toContain('value="20"');
    expect(form).toContain('المقترح أو أقل فقط (من 3 إلى 20).');
    // Not eligible: the button is disabled.
    const blocked = html('en', <ApproveForm p={{ ...zafa, eligible: false }} onApprove={() => Promise.resolve()} />);
    expect(blocked).toMatch(/<button[^>]*disabled/);
  });

  it('shows the recharge and the levels with the eligibility', () => {
    const ok = html('ar', <EvidenceList e={zafa.evidence} />);
    expect(ok).toContain('data-eligible="true"');
    expect(ok).toContain('شحن أول 7 أيام');
    expect(ok).toContain('1,000,000');
    const no = html('en', <EvidenceList e={{ ...zafa.evidence, totalRechargeCoins: 50_000, eligible: false }} />);
    expect(no).toContain('Not eligible yet: needs at least 1,000,000 coins recharged');
  });
});

describe('D290 lists', () => {
  it('the requests table: status, app with its confidence, the way it was sent; review only for the OWNER', () => {
    const rows = [
      request(),
      request({ id: '2', status: 'APPROVED', approvedLevel: 20, via: 'panel' }),
      request({
        id: '3',
        status: 'REJECTED',
        sourceApp: {
          code: 'OTHER',
          nameAr: 'تطبيق آخر',
          nameEn: 'Other app',
          confidence: 'ESTIMATE',
          isOther: true,
        },
        sourceAppName: 'تطبيق صوتي',
      }),
    ];
    const owner = html('ar', <RequestTable rows={rows} canDecide />);
    expect(owner).toContain('data-status="PENDING"');
    expect(owner).toContain('تمت الموافقة');
    expect(owner).toContain('تطبيق صوتي');
    expect(owner).toContain('من اللوحة');
    expect(owner).toContain('مراجعة');
    const staff = html('en', <RequestTable rows={rows} canDecide={false} />, 'SUPPORT');
    expect(staff).not.toContain('Review');
    expect(staff).toContain('Rejected');
    expect(html('ar', <RequestTable rows={[]} canDecide />)).toContain('data-empty');
  });

  it('the source-app table shows the confidence label of each app and of each table point', () => {
    const rows = [
      app(),
      app({
        id: 'b',
        code: 'BIGO_LIVE',
        nameAr: 'بيقو لايف',
        nameEn: 'Bigo Live',
        mode: 'FACTOR',
        usdPerMillion: null,
        coinsPerXp: null,
        xpTable: [],
        factor: 0.5,
        confidence: 'ESTIMATE',
        sourceNote: 'Estimate.',
      }),
      app({
        id: 'c',
        code: 'OTHER',
        nameAr: 'تطبيق آخر',
        nameEn: 'Other app',
        mode: 'FACTOR',
        usdPerMillion: null,
        coinsPerXp: null,
        xpTable: [],
        factor: 0.5,
        confidence: 'ESTIMATE',
        isOther: true,
      }),
    ];
    const ar = html('ar', <AppsTable rows={rows} onEdit={() => undefined} />);
    expect(ar).toContain('data-app="ZAFA"');
    expect((ar.match(/data-confidence="CONFIRMED"/g) ?? []).length).toBe(2); // the app and its one point
    expect((ar.match(/data-confidence="ESTIMATE"/g) ?? []).length).toBe(2);
    expect(ar).toContain('مؤكد');
    expect(ar).toContain('تقدير');
    expect(ar).toContain('× 0.5');
    expect(ar).toContain('الافتراضي لتطبيق غير موجود');
    expect(html('en', <AppsTable rows={rows} />)).toContain('Estimate');
  });

  it('parses and prints the XP table; refuses a malformed line', () => {
    expect(parseXpTable('32:27742536!\n 10 : 1000 ')).toEqual([
      { level: 10, xp: 1000, confidence: 'ESTIMATE' },
      { level: 32, xp: 27742536, confidence: 'CONFIRMED' },
    ]);
    expect(parseXpTable('')).toEqual([]);
    expect(parseXpTable('level 32 = 5')).toBeNull();
    expect(formatXpTable([{ level: 32, xp: 27742536, confidence: 'CONFIRMED' }])).toBe('32:27742536!');
  });

  it('sends only the changed weights; refuses an empty field', () => {
    const saved = {
      minRechargeCoins: 1_000_000,
      firstDays: 7,
      anchorCoins: 1_000_000,
      firstDaysBaseLevel: 20,
      totalBaseLevel: 15,
      levelsPerDoubling: 4,
      supportBonusPer10Levels: 1,
      supportBonusMax: 2,
      charmBonusPer10Levels: 1,
      charmBonusMax: 2,
      belowTableExponent: 3,
      maxLevel: 40,
      kabsoUsdPerMillion: 12.5,
    };
    const draft = Object.fromEntries(Object.entries(saved).map(([k, v]) => [k, String(v)])) as never;
    expect(settingChanges(saved, draft)).toEqual({});
    expect(
      settingChanges(saved, {
        ...(draft as object),
        firstDaysBaseLevel: '18',
      } as never),
    ).toEqual({ firstDaysBaseLevel: 18 });
    expect(settingChanges(saved, { ...(draft as object), firstDays: '' } as never)).toBeNull();
  });
});

describe('D290 follow-up: deleted video, duplicates, «هل تقصد», aliases', () => {
  it('a decided request shows «حُذف الفيديو بعد القرار» with the evidence kept', () => {
    const r = request({ status: 'APPROVED', video: { ...request().video, deletedAt: '2026-11-06T12:00:00.000Z' } });
    const ar = html('ar', <VideoDeleted r={r} />);
    expect(ar).toContain('حُذف الفيديو بعد القرار');
    expect(ar).toContain('20 ث');
    expect(ar).toContain('12.0 ميغابايت');
    expect(html('en', <VideoDeleted r={r} />)).toContain('The video was deleted after the decision');
  });

  it('words the duplicate refusal with status, date and staff member; nothing for other errors', () => {
    const err = new ApiError(409, 'LEVEL_RAISE_DUPLICATE', 'dup', null, [
      { field: 'status', issue: 'APPROVED' },
      { field: 'createdAt', issue: '2026-11-05T09:30:00.000Z' },
      { field: 'requestedBy', issue: 'مشرف كابسو' },
    ]);
    const ar = duplicateText(err, t('ar'), 'ar')!;
    expect(ar).toContain('(تمت الموافقة)');
    expect(ar).toContain('مشرف كابسو');
    expect(ar).toContain('2026');
    expect(duplicateText(err, t('en'), 'en')).toContain('already has a request (Approved)');
    expect(duplicateText(new ApiError(409, 'ADMIN_ACTION_REFUSED', 'x'), t('en'), 'en')).toBeNull();
    expect(duplicateText(new Error('x'), t('en'), 'en')).toBeNull();
  });

  it('suggests «هل تقصد: …؟» for listed apps (with the confidence) and earlier names', () => {
    const items: Suggestion[] = [
      {
        kind: 'APP',
        app: { code: 'ZAFA', nameAr: 'زفة', nameEn: 'Zafa', confidence: 'CONFIRMED', isOther: false },
        name: null,
        count: null,
      },
      { kind: 'NAME', app: null, name: 'Voice X', count: 3 },
    ];
    expect(suggestionLabel(items[0]!, 'ar')).toBe('زفة');
    expect(suggestionLabel(items[0]!, 'en')).toBe('Zafa');
    expect(suggestionLabel(items[1]!, 'ar')).toBe('Voice X');
    const ar = html('ar', <SuggestionList items={items} onPick={() => undefined} />);
    expect(ar).toContain('هل تقصد: زفة؟ · مؤكد');
    expect(ar).toContain('هل تقصد: Voice X؟');
    expect(ar).toContain('data-suggestion="ZAFA"');
    expect(html('en', <SuggestionList items={items} onPick={() => undefined} />)).toContain(
      'Did you mean: Zafa? · Confirmed',
    );
    expect(html('en', <SuggestionList items={[]} onPick={() => undefined} />)).toBe('');
  });

  it('flags a request after an earlier rejection and shows that rejection to the owner', () => {
    const pr = {
      id: 'old',
      createdAt: '2026-11-01T10:00:00.000Z',
      decidedAt: '2026-11-02T10:00:00.000Z',
      rejectReason: 'الفيديو لا يظهر الآيدي',
      requestedBy: { id: 'm', username: 'mod_one', displayName: 'مشرف', avatarUrl: null },
    };
    const table = html('ar', <RequestTable rows={[request({ previousRejection: pr })]} canDecide />);
    expect(table).toContain('data-previously-rejected');
    expect(table).toContain('سبق رفض طلب بنفس الحساب');
    const card = html('ar', <PreviousRejection pr={pr} />);
    expect(card).toContain('الفيديو لا يظهر الآيدي');
    expect(card).toContain('أرسله مشرف');
    expect(html('en', <PreviousRejection pr={pr} />)).toContain('Reason: الفيديو لا يظهر الآيدي');
  });

  it("lists each app's aliases", () => {
    const ar = html('ar', <AppsTable rows={[app()]} />);
    expect(ar).toContain('data-aliases');
    expect(ar).toContain('أسماء أخرى: زافا، Zafa Live');
  });
});
