// D285 (owner, contract v1.75-live, CONVENTIONS §10.96.13): recruitment by
// staff «الاستقطاب» in the app —
//  - the recruiter field «إن كنت تابعاً لمشرف، ضع معرّفه هنا» on the forms:
//    checked live (debounced), the recruiter's name and «فريق كابسو» badge,
//    or «غير موجود»; the form blocks sending while it names nobody;
//  - the BD line «تطوير الأعمال — الوطن العربي»;
//  - the staff Me tab's «استقطاباتي» / «أرباحي» (MODERATION / BD, not
//    FINANCE / SUPPORT);
//  - «استقطاباتي» lists by type with status; «أرباحي» shows the balance, the
//    breakdown and history, and «سحب الأرباح» opens the withdrawal sheet.
// A fixed clock. The goldens are in test/goldens/recruits_d285_golden_test.dart.

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/recruits/data/recruits_repository.dart';
import 'package:kabso_live/features/recruits/presentation/recruiter_field.dart';
import 'package:kabso_live/features/recruits/presentation/staff_recruits_screen.dart';
import 'package:kabso_live/features/staff/domain/staff_identity.dart';
import 'package:kabso_live/features/wallet/presentation/cherry_withdraw_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_economy_repositories.dart' show testCherryWallet;
import '../../helpers/pump_app.dart';
import '../staff/staff_d283_test.dart';

final DateTime d285Now = DateTime.utc(2027, 3, 20, 9);

UserSummary _user(String id, String name, String username) =>
    UserSummary(id: id, username: username, displayName: name, avatarUrl: null);

const bdIdentity = KabsoStaffIdentity(
  role: StaffLineRole.bd,
  regions: [StaffRegion.arabWorld],
);

StaffRecruitList recruitsFixture({required bool ar}) => StaffRecruitList(
  counts: const {
    RecruitType.host: 2,
    RecruitType.agency: 1,
    RecruitType.rechargeAgent: 1,
    RecruitType.creator: 1,
  },
  recruits: [
    StaffRecruit(
      id: 'r1',
      type: RecruitType.host,
      recruit: _user('u1', ar ? 'ليلى المضيفة' : 'Layla Host', 'layla'),
      active: true,
      activatedAt: DateTime.utc(2027, 3, 18, 10),
      profitUsd: 5.35,
      commissionCherries: 48636,
    ),
    StaffRecruit(
      id: 'r2',
      type: RecruitType.host,
      recruit: _user('u2', ar ? 'سامي' : 'Sami', 'sami.live'),
      active: false,
      activatedAt: DateTime.utc(2027, 3, 10, 10),
      profitUsd: 0,
      commissionCherries: 0,
    ),
    StaffRecruit(
      id: 'r3',
      type: RecruitType.agency,
      recruit: _user('u3', ar ? 'وكالة النجوم' : 'Stars Agency', 'stars'),
      active: true,
      activatedAt: DateTime.utc(2027, 3, 12, 10),
      profitUsd: 42.78,
      commissionCherries: 388863,
    ),
    StaffRecruit(
      id: 'r4',
      type: RecruitType.rechargeAgent,
      recruit: _user(
        'u4',
        ar ? 'وكيل الشحن مصر' : 'Egypt Recharge',
        'eg.agent',
      ),
      active: true,
      activatedAt: DateTime.utc(2027, 3, 14, 10),
      profitUsd: 145.5,
      commissionCherries: 992045,
    ),
    StaffRecruit(
      id: 'r5',
      type: RecruitType.creator,
      recruit: _user('u5', ar ? 'نور تصنع المحتوى' : 'Nour Creates', 'nour'),
      active: true,
      activatedAt: DateTime.utc(2027, 3, 16, 10),
      profitUsd: 1.2,
      commissionCherries: 10909,
    ),
  ],
);

StaffEarnings earningsFixture({required bool ar}) {
  final list = recruitsFixture(ar: ar).recruits;
  return StaffEarnings(
    wallet: testCherryWallet(),
    totalCherries: 1440453,
    last30DaysCherries: 1440453,
    bps: const {
      RecruitType.host: 100,
      RecruitType.creator: 100,
      RecruitType.agency: 100,
      RecruitType.rechargeAgent: 75,
    },
    byRecruit: [
      for (final r in list)
        if (r.commissionCherries > 0)
          (type: r.type, recruit: r.recruit, cherries: r.commissionCherries),
    ],
    history: [
      StaffEarningDay(
        day: '2027-03-19',
        type: RecruitType.rechargeAgent,
        recruit: list[3].recruit,
        profitUsd: 145.5,
        bps: 75,
        cherries: 992045,
      ),
      StaffEarningDay(
        day: '2027-03-18',
        type: RecruitType.host,
        recruit: list[0].recruit,
        profitUsd: 5.35,
        bps: 100,
        cherries: 48636,
      ),
    ],
  );
}

/// A fake API: `Kabso05` / `@nour.bd` is BD «نور», `Kabso02` a moderator;
/// anything else «غير موجود».
class FakeRecruitsRepository implements RecruitsRepository {
  new({this.recruits, this.earnings});

  final StaffRecruitList? recruits;
  final StaffEarnings? earnings;
  final List<String> lookups = [];

  @override
  Future<StaffRecruiter?> lookup(String q) async {
    lookups.add(q);
    final v = q.toLowerCase().replaceAll('@', '');
    if (v == 'kabso05' || v == 'kabso5' || v == 'nour.bd') {
      return const StaffRecruiter(
        staffId: 'Kabso05',
        username: 'nour.bd',
        displayName: 'نور',
        avatarUrl: null,
        bd: true,
      );
    }
    if (v == 'kabso02') {
      return const StaffRecruiter(
        staffId: 'Kabso02',
        username: 'sara.mod',
        displayName: 'Sara',
        avatarUrl: null,
        bd: false,
      );
    }
    return null;
  }

  @override
  Future<StaffRecruitList> myRecruits() async => recruits!;

  @override
  Future<StaffEarnings> myEarnings() async => earnings!;

  @override
  Future<MyCreatorApplication> creatorApplication() async =>
      const MyCreatorApplication(
        member: false,
        status: null,
        rejectReason: null,
        canApply: true,
        refusal: null,
      );

  @override
  Future<MyCreatorApplication> applyCreator(CreatorApplicationDraft d) =>
      creatorApplication();

  @override
  Future<MyCreatorApplication> cancelCreator() => creatorApplication();
}

/// The recruiter field alone in a screen; returns the checks it reported.
Future<List<RecruiterCheck>> pumpRecruiterField(
  WidgetTester tester, {
  required AppLanguage language,
  required FakeRecruitsRepository repo,
  bool showError = false,
}) async {
  final checks = <RecruiterCheck>[];
  await pumpScreen(
    tester,
    Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: RecruiterField(showError: showError, onChanged: checks.add),
      ),
    ),
    language: language,
    overrides: [recruitsRepositoryProvider.overrideWithValue(repo)],
  );
  return checks;
}

void main() {
  test('the BD line «تطوير الأعمال — الوطن العربي» (ar / en), alone too', () {
    final ar = l10nFor(AppLanguage.ar);
    final en = l10nFor(AppLanguage.en);
    expect(bdIdentity.line(ar), 'تطوير الأعمال — الوطن العربي');
    expect(bdIdentity.line(en), 'Business development — Arab World');
    const alone = KabsoStaffIdentity(role: StaffLineRole.bd);
    expect(alone.line(ar), 'تطوير الأعمال');
    expect(StaffLineRole.fromWire('BD'), StaffLineRole.bd);
  });

  test('basis points as percentages: 1 %, 0.75 %', () {
    expect(bpsPercent(100), '1%');
    expect(bpsPercent(75), '0.75%');
    expect(bpsPercent(150), '1.5%');
  });

  test('the wire: StaffRecruitList and StaffEarnings', () {
    final list = StaffRecruitList.fromJson({
      'counts': {
        'HOST': 1,
        'AGENCY': 0,
        'RECHARGE_AGENT': 2,
        'CREATOR': 0,
        'total': 3,
      },
      'data': [
        {
          'id': 'r1',
          'type': 'RECHARGE_AGENT',
          'recruit': {
            'id': 'u',
            'username': 'a',
            'displayName': 'A',
            'avatarUrl': null,
          },
          'status': 'INACTIVE',
          'activatedAt': '2027-03-18T10:00:00.000Z',
          'profitUsd': 145.5,
          'profitUsd30d': 145.5,
          'commissionCherries': 992045,
          'lastDay': '2027-03-18',
        },
      ],
    });
    expect(list.total, 3);
    expect(list.recruits.single.type, RecruitType.rechargeAgent);
    expect(list.recruits.single.active, isFalse);
    expect(list.recruits.single.commissionCherries, 992045);
  });

  for (final language in AppLanguage.values) {
    final name = language.name;
    final ar = language == AppLanguage.ar;
    final l10n = l10nFor(language);

    testWidgets('the recruiter field: Kabso05 → the name and badge; '
        'unknown → «غير موجود» ($name)', (tester) async {
      final repo = FakeRecruitsRepository();
      final checks = await pumpRecruiterField(
        tester,
        language: language,
        repo: repo,
      );
      expect(find.text(l10n.recruiterFieldLabel), findsOneWidget);
      await tester.enterText(find.byKey(RecruiterField.fieldKey), 'kabso5');
      await tester.pump();
      expect(find.byKey(RecruiterField.checkingKey), findsOneWidget);
      expect(checks.last.ok, isFalse);
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(find.byKey(RecruiterField.foundKey), findsOneWidget);
      expect(find.text('نور'), findsOneWidget);
      expect(
        find.textContaining('Kabso05 · ${l10n.staffRoleBd}'),
        findsOneWidget,
      );
      expect(checks.last.ok, isTrue);
      expect(checks.last.value, 'kabso5');
      // Debounced: one lookup for the whole word.
      expect(repo.lookups, ['kabso5']);

      await tester.enterText(find.byKey(RecruiterField.fieldKey), 'Kabso77');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(find.byKey(RecruiterField.notFoundKey), findsOneWidget);
      expect(find.text(l10n.recruiterNotFound), findsOneWidget);
      expect(checks.last.ok, isFalse);

      // Emptied: nothing to check, the form may send (no recruiter).
      await tester.enterText(find.byKey(RecruiterField.fieldKey), '  ');
      await tester.pump();
      expect(checks.last.ok, isTrue);
      expect(checks.last.value, isNull);
    });

    testWidgets('after a send attempt a recruiter naming nobody shows the '
        'fix-it error ($name)', (tester) async {
      await pumpRecruiterField(
        tester,
        language: language,
        repo: FakeRecruitsRepository(),
        showError: true,
      );
      await tester.enterText(find.byKey(RecruiterField.fieldKey), 'nobody');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
      expect(find.text(l10n.recruiterFixError), findsOneWidget);
    });

    testWidgets('«استقطاباتي»: counts by type, the rows with status and '
        'commissions; a type filter ($name)', (tester) async {
      await withClock(Clock.fixed(d285Now), () async {
        await pumpScreen(
          tester,
          const StaffRecruitsScreen(),
          language: language,
          overrides: [
            recruitsRepositoryProvider.overrideWithValue(
              FakeRecruitsRepository(recruits: recruitsFixture(ar: ar)),
            ),
          ],
        );
        await tester.pumpAndSettle();
      });
      expect(find.text(l10n.staffMyRecruits), findsOneWidget);
      expect(find.text('${l10n.recruitTypeAll} (5)'), findsOneWidget);
      expect(find.text('${l10n.recruitTypeHost} (2)'), findsOneWidget);
      expect(find.byKey(const Key('staffRecruits.row.r1')), findsOneWidget);
      expect(find.text(l10n.recruitStatusInactive), findsOneWidget);
      await tester.tap(
        find.byKey(StaffRecruitsScreen.tabKey(RecruitType.agency)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('staffRecruits.row.r1')), findsNothing);
      expect(find.byKey(const Key('staffRecruits.row.r3')), findsOneWidget);
    });

    testWidgets('«أرباحي»: balance, shares, breakdown, history; «سحب الأرباح» '
        'opens the withdrawal sheet ($name)', (tester) async {
      await withClock(Clock.fixed(d285Now), () async {
        await pumpScreen(
          tester,
          const StaffEarningsScreen(),
          language: language,
          overrides: [
            recruitsRepositoryProvider.overrideWithValue(
              FakeRecruitsRepository(earnings: earningsFixture(ar: ar)),
            ),
          ],
        );
        await tester.pumpAndSettle();
      });
      expect(find.byKey(StaffEarningsScreen.balanceKey), findsOneWidget);
      expect(find.textContaining('1,440,453'), findsWidgets);
      expect(
        find.text(l10n.staffEarningsShares('1%', '1%', '1%', '0.75%')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(StaffEarningsScreen.historyKey),
        200,
      );
      expect(
        find.text(l10n.staffEarningsDayLine(r'$145.50', '0.75%')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(StaffEarningsScreen.withdrawKey),
        -200,
      );
      await tester.tap(find.byKey(StaffEarningsScreen.withdrawKey));
      await tester.pumpAndSettle();
      expect(find.byType(CherryWithdrawSheet), findsOneWidget);
    });

    testWidgets('the staff Me tab: «استقطاباتي» and «أرباحي» for BD '
        '($name)', (tester) async {
      await pumpStaffHub(tester, language: language, staff: bdIdentity);
      expect(find.byKey(MeHubScreen.staffRecruitsKey), findsOneWidget);
      expect(find.byKey(MeHubScreen.staffEarningsKey), findsOneWidget);
    });

    testWidgets('the staff Me tab: a moderator has them too ($name)', (
      tester,
    ) async {
      await pumpStaffHub(tester, language: language);
      expect(find.byKey(MeHubScreen.staffRecruitsKey), findsOneWidget);
    });

    testWidgets('the staff Me tab: FINANCE has neither ($name)', (
      tester,
    ) async {
      await pumpStaffHub(
        tester,
        language: language,
        staff: const KabsoStaffIdentity(role: StaffLineRole.finance),
      );
      expect(find.byKey(MeHubScreen.staffRecruitsKey), findsNothing);
      expect(find.byKey(MeHubScreen.staffEarningsKey), findsNothing);
    });
  }
}
