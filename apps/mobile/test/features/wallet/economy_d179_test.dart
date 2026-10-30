// D179: the cherry economy in the app — the withdrawal request sheet
// (minimum, cherries ↔ money, payout details, the honest manual-payment
// note, one Idempotency-Key, refusals shown), the withdrawal requests, and
// the Agency page (join by code, the host's agency with leave / complaint,
// the agent's dashboard). Arabic RTL and English LTR, 360×800 and large
// text. Fakes only (labelled fixtures).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/agency/data/agency_repository.dart';
import 'package:kabso_live/features/agency/presentation/agency_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/data/home_banners_repository.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
import 'package:kabso_live/features/wallet/data/cherry_repository.dart';
import 'package:kabso_live/features/wallet/presentation/cherry_withdraw_sheet.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_cherry_tab.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_economy_repositories.dart';
import '../../helpers/fake_home_banners_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

class _Coins extends LiveCoinsController {
  @override
  Future<int> build() async => 1250;
}

class _NoPrograms implements ProgramsRepository {
  @override
  Future<RechargeOffer> rechargePackages() async => const RechargeOffer(
    currency: 'USD',
    purchasesEnabled: false,
    packages: [],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<void> _pump(
  WidgetTester tester,
  String location, {
  FakeCherryRepository? cherries,
  FakeAgencyRepository? agency,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: AppRoutes.wallet,
        builder: (_, state) => WalletScreen(
          initialTab: WalletTab.fromQuery(state.uri.queryParameters['tab']),
        ),
      ),
      GoRoute(path: AppRoutes.agency, builder: (_, _) => const AgencyScreen()),
    ],
  );
  await loadAppFonts();
  setViewport(tester, viewport);
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        currentUserProvider.overrideWithValue(testUser()),
        liveCoinsProvider.overrideWith(_Coins.new),
        cherryRepositoryProvider.overrideWithValue(
          cherries ?? FakeCherryRepository(),
        ),
        agencyRepositoryProvider.overrideWithValue(
          agency ?? FakeAgencyRepository(),
        ),
        programsRepositoryProvider.overrideWithValue(_NoPrograms()),
        homeBannersRepositoryProvider.overrideWithValue(
          FakeHomeBannersRepository(),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(
          brightness: Brightness.light,
          locale: language.locale,
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.byKey(WalletCherryTab.withdrawKey), 100);
  await tester.tap(find.byKey(WalletCherryTab.withdrawKey));
  await tester.pumpAndSettle();
  expect(find.byType(CherryWithdrawSheet), findsOneWidget);
}

void main() {
  test('amounts parse to minor units; the rate rounds the hold up', () {
    expect(parseAmountMinor('10'), 1000);
    expect(parseAmountMinor('12.5'), 1250);
    expect(parseAmountMinor('12,50'), 1250);
    expect(parseAmountMinor('1.234'), isNull);
    expect(parseAmountMinor('abc'), isNull);
    expect(testPayout.cherriesFor(1000), 9090910);
    expect(testPayout.valueOf(12500000), 1375);
  });

  group('withdrawal sheet', () {
    testWidgets('starts at the minimum with its cherries, needs payout '
        'details, says it is paid by hand, and sends one request', (
      tester,
    ) async {
      final cherries = FakeCherryRepository();
      await _pump(tester, AppRoutes.walletCherries, cherries: cherries);
      await _openSheet(tester);
      expect(find.text(_en.withdrawTitle), findsOneWidget);
      expect(
        find.text(_en.withdrawBalance(_iso('12,500,000'), _iso(r'$13.75'))),
        findsOneWidget,
      );
      expect(
        find.text(_en.withdrawAmountHelper(_iso('9,090,910'))),
        findsOneWidget,
      );
      expect(find.text(_en.withdrawManualNote(7)), findsOneWidget);
      KButton submit() =>
          tester.widget<KButton>(find.byKey(CherryWithdrawSheet.submitKey));
      // No payout details yet → the button waits.
      expect(submit().onPressed, isNull);
      await tester.enterText(find.byKey(CherryWithdrawSheet.amountKey), '9.99');
      await tester.pump();
      expect(find.text(_en.withdrawAmountMin(_iso(r'$10.00'))), findsOneWidget);
      await tester.enterText(find.byKey(CherryWithdrawSheet.amountKey), '14');
      await tester.pump();
      expect(
        find.text(_en.withdrawAmountShort(_iso(r'$13.75'))),
        findsOneWidget,
      );
      await tester.enterText(find.byKey(CherryWithdrawSheet.amountKey), '12.5');
      await tester.enterText(
        find.byKey(CherryWithdrawSheet.detailsKey),
        'Bank: IBAN SA00 TEST',
      );
      await tester.pump();
      expect(
        find.text(_en.withdrawAmountHelper(_iso('11,363,637'))),
        findsOneWidget,
      );
      expect(submit().onPressed, isNotNull);
      await tester.ensureVisible(find.byKey(CherryWithdrawSheet.submitKey));
      await tester.tap(find.byKey(CherryWithdrawSheet.submitKey));
      await tester.pumpAndSettle();
      expect(cherries.sent, hasLength(1));
      expect(cherries.sent.single.amountMinor, 1250);
      expect(cherries.sent.single.details, 'Bank: IBAN SA00 TEST');
      expect(
        RegExp(r'^[0-9a-f-]{36}$').hasMatch(cherries.sent.single.key),
        isTrue,
      );
      expect(find.byType(CherryWithdrawSheet), findsNothing);
      // The tab now shows the waiting request.
      expect(find.byKey(WalletCherryTab.pendingKey), findsOneWidget);
    });

    // D184 (CONVENTIONS §10.46.1): task cherries wait for the owner's
    // earnings condition; the tab says so and the sheet offers only the rest.
    testWidgets('locked task cherries: the line on the card, the history '
        'row, and the sheet limits the request to the withdrawable part', (
      tester,
    ) async {
      final cherries = FakeCherryRepository(
        wallet: testCherryWallet(lockedTask: 3500000),
        entries: [
          CherryLedgerEntry(
            id: 't1',
            reason: CherryLedgerReason.taskReward,
            delta: 500,
            balanceAfter: 12500000,
            createdAt: economyAt,
          ),
          ...testCherryLedger(),
        ],
      );
      await _pump(tester, AppRoutes.walletCherries, cherries: cherries);
      expect(
        tester.widget<Text>(find.byKey(WalletCherryTab.lockedKey)).data,
        _en.cherryTaskLocked(_iso('3,500,000')),
      );
      await tester.scrollUntilVisible(
        find.byKey(WalletCherryTab.entryKey('t1')),
        100,
      );
      expect(
        find.descendant(
          of: find.byKey(WalletCherryTab.entryKey('t1')),
          matching: find.text(_en.cherryReasonTask),
        ),
        findsOneWidget,
      );
      await _openSheet(tester);
      expect(find.text(_en.cherryTaskLocked(_iso('3,500,000'))), findsWidgets);
      // 12 500 000 − 3 500 000 = 9 000 000 withdrawable = $9.90: $10 is short.
      await tester.enterText(find.byKey(CherryWithdrawSheet.amountKey), '10');
      await tester.enterText(
        find.byKey(CherryWithdrawSheet.detailsKey),
        'Bank: IBAN SA00 TEST',
      );
      await tester.pump();
      expect(
        find.text(_en.withdrawAmountShort(_iso(r'$9.90'))),
        findsOneWidget,
      );
      expect(
        tester
            .widget<KButton>(find.byKey(CherryWithdrawSheet.submitKey))
            .onPressed,
        isNull,
      );
    });

    testWidgets('no locked task cherries: no lock line', (tester) async {
      await _pump(tester, AppRoutes.walletCherries);
      expect(find.byKey(WalletCherryTab.lockedKey), findsNothing);
    });

    testWidgets('a refusal is shown in the sheet; a retry keeps its key', (
      tester,
    ) async {
      final cherries = FakeCherryRepository(
        withdrawError: const ServerFailure(
          code: ErrorCode.insufficientCherries,
          rawCode: 'INSUFFICIENT_CHERRIES',
          debugMessage: 'short',
          statusCode: 409,
        ),
      );
      await _pump(tester, AppRoutes.walletCherries, cherries: cherries);
      await _openSheet(tester);
      await tester.enterText(
        find.byKey(CherryWithdrawSheet.detailsKey),
        'Wallet 0555',
      );
      await tester.pump();
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.byKey(CherryWithdrawSheet.submitKey));
        await tester.tap(find.byKey(CherryWithdrawSheet.submitKey));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(CherryWithdrawSheet.errorKey), findsOneWidget);
      expect(find.text(_en.errorInsufficientCherries), findsOneWidget);
      expect(cherries.sent.map((s) => s.key).toSet(), hasLength(1));
    });

    testWidgets('a waiting request: the sheet says so and offers no form; '
        'the requests show their status', (tester) async {
      final pending = testWithdrawal('w1');
      await _pump(
        tester,
        AppRoutes.walletCherries,
        cherries: FakeCherryRepository(
          wallet: testCherryWallet(held: 9090910, pending: pending),
          requests: [
            pending,
            testWithdrawal(
              'w0',
              status: CherryWithdrawalStatus.rejected,
              note: 'Wrong IBAN',
            ),
          ],
        ),
      );
      expect(find.text(_en.cherryHeld(_iso('9,090,910'))), findsNothing);
      expect(
        find.text(
          '${_en.cherryValue(_iso(r'$13.75'))} · '
          '${_en.cherryHeld(_iso('9,090,910'))}',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(WalletCherryTab.withdrawalKey('w0')),
        100,
      );
      expect(find.text(_en.cherryWithdrawalRejected), findsOneWidget);
      expect(find.text('Wrong IBAN'), findsOneWidget);
      await _openSheet(tester);
      expect(find.byKey(CherryWithdrawSheet.pendingKey), findsOneWidget);
      expect(find.byKey(CherryWithdrawSheet.submitKey), findsNothing);
    });
  });

  group('agency', () {
    testWidgets('no agency: the code shows the agency first, then accept '
        'joins it', (tester) async {
      final agency = FakeAgencyRepository();
      await _pump(tester, AppRoutes.agency, agency: agency);
      expect(find.text(_en.agencyJoinTitle), findsOneWidget);
      await tester.enterText(find.byKey(AgencyScreen.codeFieldKey), 'nope1234');
      await tester.pump();
      await tester.tap(find.byKey(AgencyScreen.findKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.agencyNotFound), findsOneWidget);
      expect(find.byKey(AgencyScreen.acceptKey), findsNothing);
      await tester.enterText(find.byKey(AgencyScreen.codeFieldKey), 'kab5q7xz');
      await tester.pump();
      await tester.tap(find.byKey(AgencyScreen.findKey));
      await tester.pumpAndSettle();
      expect(find.byKey(AgencyScreen.previewKey), findsOneWidget);
      expect(find.text(_en.agencyLeaveRule(14)), findsOneWidget);
      // Nothing joined before accepting.
      expect(agency.calls.where((c) => c.startsWith('join')), isEmpty);
      await tester.ensureVisible(find.byKey(AgencyScreen.acceptKey));
      await tester.tap(find.byKey(AgencyScreen.acceptKey));
      await tester.pumpAndSettle();
      expect(agency.calls, contains('join KAB5Q7XZ'));
      expect(find.byKey(AgencyScreen.membershipKey), findsOneWidget);
      expect(find.byKey(AgencyScreen.leaveKey), findsOneWidget);
    });

    testWidgets('a host within the window leaves after confirming', (
      tester,
    ) async {
      final agency = FakeAgencyRepository(
        mine: testMyAgency(membership: testMembership()),
      );
      await _pump(tester, AppRoutes.agency, agency: agency);
      await tester.tap(find.byKey(AgencyScreen.leaveKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.agencyLeaveConfirm), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, _en.agencyLeave),
        ),
      );
      await tester.pumpAndSettle();
      expect(agency.calls, contains('leave'));
      expect(find.text(_en.agencyJoinTitle), findsOneWidget);
    });

    testWidgets('after the window: no leave, a complaint to the admin', (
      tester,
    ) async {
      final agency = FakeAgencyRepository(
        mine: testMyAgency(membership: testMembership(canLeave: false)),
      );
      await _pump(tester, AppRoutes.agency, agency: agency);
      expect(find.byKey(AgencyScreen.leaveKey), findsNothing);
      expect(find.text(_en.agencyLeaveClosed(14)), findsOneWidget);
      await tester.tap(find.byKey(AgencyScreen.complainKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('agency.complaint.text')),
        'No answer from the agent',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('agency.complaint.send')));
      await tester.pumpAndSettle();
      expect(agency.calls, contains('complain No answer from the agent'));
      expect(find.byKey(AgencyScreen.complaintKey), findsOneWidget);
      // One open complaint at a time.
      expect(
        tester.widget<KButton>(find.byKey(AgencyScreen.complainKey)).onPressed,
        isNull,
      );
    });

    testWidgets('the agent: code, rank, rate, progress, commissions and '
        'hosts with activity', (tester) async {
      await _pump(
        tester,
        AppRoutes.agency,
        agency: FakeAgencyRepository(mine: testMyAgency(own: testOwnAgency())),
      );
      expect(find.text('KAB5Q7XZ'), findsOneWidget);
      expect(find.text(_en.agencyRankAgent), findsOneWidget);
      expect(find.text(_en.agencyRate('15')), findsOneWidget);
      expect(find.text(_en.agencyActiveHosts(4, 5)), findsOneWidget);
      expect(find.text(_en.agencyMonthCherries('126,500,000')), findsOneWidget);
      expect(find.text('18,975,000'), findsOneWidget);
      // Not an agency admin: no sub-agency progress or parent commission.
      expect(find.text(_en.agencyParentCommissionTitle), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(AgencyScreen.hostKey('u-h2')),
        100,
      );
      expect(find.text(_en.agencyHostActive), findsOneWidget);
      expect(find.text(_en.agencyHostInactive), findsOneWidget);
      expect(find.text(_en.agencyHostNoCommission), findsOneWidget);
    });

    // v1.58-social (D189): the owner's host-agent code, its badge and what
    // the code does now (shown, reserved behind a recharge code, suspended).
    testWidgets('the host-agent card: code, badge and note', (tester) async {
      for (final (shown, active, note) in [
        (true, true, _en.hostAgentPerksNote),
        (false, true, null),
        (false, false, _en.hostAgentSuspendedNote('\u2068host07\u2069')),
      ]) {
        await _pump(
          tester,
          AppRoutes.agency,
          agency: FakeAgencyRepository(
            mine: testMyAgency(
              own: testOwnAgency(
                hostAgentCode: 'host07',
                hostAgentActive: active,
                hostAgentUsernameShown: shown,
              ),
            ),
          ),
        );
        expect(find.byKey(AgencyScreen.hostAgentKey), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(AgencyScreen.hostAgentCodeKey)).data,
          'host07',
        );
        expect(
          find.descendant(
            of: find.byKey(AgencyScreen.hostAgentKey),
            matching: find.byType(HostAgentBadge),
          ),
          findsOneWidget,
        );
        final text = tester
            .widget<Text>(find.byKey(AgencyScreen.hostAgentNoteKey))
            .data!;
        if (note != null) {
          expect(text, note);
        } else {
          expect(text, contains('host07'));
        }
      }
      // An older server: no card.
      await _pump(
        tester,
        AppRoutes.agency,
        agency: FakeAgencyRepository(mine: testMyAgency(own: testOwnAgency())),
      );
      expect(find.byKey(AgencyScreen.hostAgentKey), findsNothing);
    });

    testWidgets('an agency admin sees the sub-agencies and the 3 %', (
      tester,
    ) async {
      await _pump(
        tester,
        AppRoutes.agency,
        agency: FakeAgencyRepository(
          mine: testMyAgency(
            own: testOwnAgency(rank: AgencyRank.admin, subs: true),
          ),
        ),
      );
      expect(find.text(_en.agencyRankAdmin), findsOneWidget);
      expect(find.text(_en.agencySubProgress(2, 3)), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(AgencyScreen.subKey('SUB22222')),
        100,
      );
      expect(find.text(_en.agencyParentCommissionTitle), findsOneWidget);
      expect(find.text(_en.agencyQualified), findsOneWidget);
    });

    testWidgets('Arabic RTL: the rank chip at the right of the rate', (
      tester,
    ) async {
      await _pump(
        tester,
        AppRoutes.agency,
        language: AppLanguage.ar,
        agency: FakeAgencyRepository(mine: testMyAgency(own: testOwnAgency())),
      );
      final chip = tester.getCenter(find.text(_ar.agencyRankAgent));
      final rate = tester.getCenter(find.text(_ar.agencyRate('15')));
      expect(chip.dx, greaterThan(rate.dx));
    });
  });

  for (final language in AppLanguage.values) {
    for (final scale in [1.0, 1.3]) {
      for (final (name, location, agency) in [
        ('cherries', AppRoutes.walletCherries, null),
        ('join', AppRoutes.agency, FakeAgencyRepository()),
        (
          'host',
          AppRoutes.agency,
          FakeAgencyRepository(
            mine: testMyAgency(membership: testMembership(canLeave: false)),
          ),
        ),
        (
          'agent',
          AppRoutes.agency,
          FakeAgencyRepository(
            mine: testMyAgency(
              own: testOwnAgency(rank: AgencyRank.admin, subs: true),
            ),
          ),
        ),
      ]) {
        testWidgets('360x800 at $scale (${language.name}) $name: no overflow', (
          tester,
        ) async {
          await _pump(
            tester,
            location,
            agency: agency,
            language: language,
            viewport: GoldenViewport.android,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
          await tester.fling(
            find.byType(Scrollable).first,
            const Offset(0, -4000),
            3000,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (name == 'cherries') {
            await _openSheet(tester);
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }
}

String _iso(String s) => '\u2068$s\u2069';
