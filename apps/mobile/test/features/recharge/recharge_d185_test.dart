// D185: recharge agents «وكلاء الشحن» in the app — the page by status (apply,
// pending, approved, the agent's dashboard with the frame and the code, the
// employee), the application form (checks, private uploads), the sell sheet
// (confirmation, one Idempotency-Key), employees with their statistics, the
// directory («تواصل» → D175's leaving sheet → WhatsApp; no button when not
// available now), cherry sales (confirm by the other side), and the perks
// (the frame with the code in its plate, the badge, the entrance bar's text).
// Arabic RTL and English LTR, 360×800 and large text. Fakes only.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';
import 'package:kabso_live/features/profile/profile_fields_view.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';
import 'package:kabso_live/features/recharge/presentation/live_recharge_entrance.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_apply_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_cherry_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_directory_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_employees_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_hub_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_recharge_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

/// A 1×1 PNG.
final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, //
  0x44, 0x52, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 0x1F, 0x15, 0xC4, 0x89,
  0, 0, 0, 13, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0, 1, 0, 0, 5, 0, 1,
  0x0D, 0x0A, 0x2D, 0xB4, 0, 0, 0, 0, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class _Picker implements AvatarPhotoPicker {
  final asked = <AvatarSource>[];

  @override
  Future<Uint8List?> pick(AvatarSource source) async {
    asked.add(source);
    return _png;
  }
}

class _Opener implements ExternalLinkOpener {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return true;
  }
}

Future<void> _pump(
  WidgetTester tester,
  String location, {
  required FakeRechargeRepository repo,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  _Picker? picker,
  _Opener? opener,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(
        path: AppRoutes.recharge,
        builder: (_, _) => const RechargeHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.rechargeApply,
        builder: (_, _) => const RechargeApplyScreen(),
      ),
      GoRoute(
        path: AppRoutes.rechargeEmployees,
        builder: (_, _) => const RechargeEmployeesScreen(),
      ),
      GoRoute(
        path: AppRoutes.rechargeAgents,
        builder: (_, _) => const RechargeDirectoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.rechargeCherries,
        builder: (_, _) => const RechargeCherryScreen(),
      ),
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
        rechargeRepositoryProvider.overrideWithValue(repo),
        avatarPhotoPickerProvider.overrideWithValue(picker ?? _Picker()),
        externalLinkOpenerProvider.overrideWithValue(opener ?? _Opener()),
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

RechargeAgentListing _listing(String code, {bool now = true}) =>
    RechargeAgentListing(
      code: code,
      user: UserSummaryFixtures.agent(code),
      locations: const [
        (country: 'EG', cities: ['القاهرة', 'الجيزة']),
      ],
      paymentTypes: const [RechargePaymentType.mobileWallet],
      whatsappNow: now ? '+201001234567' : null,
      paymentMethodNow: now ? 'فودافون كاش' : null,
    );

abstract final class UserSummaryFixtures {
  static UserSummary agent(String code) => UserSummary(
    id: 'u-$code',
    username: 'agent_$code',
    displayName: code == 'coin0007' ? 'نور للشحن' : 'Store $code',
    avatarUrl: null,
    rechargeAgentCode: code,
  );
}

void main() {
  group('the page by status', () {
    for (final language in AppLanguage.values) {
      final l10n = language == AppLanguage.ar ? _ar : _en;
      testWidgets('nobody yet: what an agent is and «كن وكيل شحن» '
          '(${language.name}, 360×800 ×1.3)', (tester) async {
        await _pump(
          tester,
          AppRoutes.recharge,
          repo: FakeRechargeRepository(),
          language: language,
          viewport: GoldenViewport.android,
          textScale: 1.3,
        );
        expect(find.text(l10n.rechargeIntroTitle), findsOneWidget);
        expect(find.byKey(RechargeHubScreen.applyKey), findsOneWidget);
        expect(find.text(l10n.rechargeBecome), findsOneWidget);
        expect(find.byKey(RechargeHubScreen.directoryKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('applied: under review, nothing private shown', (tester) async {
      await _pump(
        tester,
        AppRoutes.recharge,
        repo: FakeRechargeRepository(
          mine: const RechargeAgentMe(
            status: RechargeAgentStatus.pending,
            canApply: false,
            rules: fixtureRules,
          ),
        ),
      );
      expect(find.byKey(RechargeHubScreen.pendingKey), findsOneWidget);
      expect(find.byKey(RechargeHubScreen.applyKey), findsNothing);
    });

    testWidgets('rejected: the reason and «apply again»', (tester) async {
      await _pump(
        tester,
        AppRoutes.recharge,
        repo: FakeRechargeRepository(
          mine: const RechargeAgentMe(
            status: RechargeAgentStatus.rejected,
            canApply: true,
            rules: fixtureRules,
            rejectReason: 'Photo unclear',
          ),
        ),
      );
      expect(
        find.textContaining(_en.rechargeRejectedReason('Photo unclear')),
        findsOneWidget,
      );
      expect(find.text(_en.rechargeApplyAgain), findsOneWidget);
    });

    testWidgets('approved: waiting for the first top-up of 30,000,000', (
      tester,
    ) async {
      await _pump(
        tester,
        AppRoutes.recharge,
        repo: FakeRechargeRepository(
          mine: fixtureActive(status: RechargeAgentStatus.approved),
        ),
      );
      expect(find.byKey(RechargeHubScreen.approvedKey), findsOneWidget);
      expect(
        find.text(_en.rechargeApprovedBody(KFormat.bidiIsolate('30,000,000'))),
        findsOneWidget,
      );
      expect(find.byKey(RechargeHubScreen.sellKey), findsNothing);
    });

    for (final language in AppLanguage.values) {
      final l10n = language == AppLanguage.ar ? _ar : _en;
      testWidgets('active: the frame with the code, the badge, the stock, '
          'sales and the cherry cap (${language.name})', (tester) async {
        await _pump(
          tester,
          AppRoutes.recharge,
          repo: FakeRechargeRepository(mine: fixtureActive()),
          language: language,
        );
        expect(find.byKey(RechargeHubScreen.dashboardKey), findsOneWidget);
        expect(find.byType(RechargeAgentFrame), findsOneWidget);
        expect(find.byKey(RechargeAgentFrame.plateKey), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(RechargeAgentFrame.plateKey)).data,
          // Owner (D185, same day): the plate shows the display name.
          testUser().displayName,
        );
        expect(find.byType(RechargeAgentBadge), findsOneWidget);
        expect(find.text('28,750,000'), findsOneWidget);
        expect(
          find.text(
            l10n.rechargeCherryToday(
              KFormat.bidiIsolate('2,000,000'),
              KFormat.bidiIsolate('1,000,000,000'),
            ),
          ),
          findsOneWidget,
        );
        expect(find.byKey(RechargeHubScreen.employeesKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('suspended: selling off, the perks gone, the reason', (
      tester,
    ) async {
      await _pump(
        tester,
        AppRoutes.recharge,
        repo: FakeRechargeRepository(
          mine: fixtureActive(status: RechargeAgentStatus.suspended),
        ),
      );
      expect(find.byKey(RechargeHubScreen.suspendedKey), findsOneWidget);
      expect(find.byType(RechargeAgentFrame), findsNothing);
      expect(find.byType(RechargeAgentBadge), findsNothing);
      final sell = tester.widget<KButton>(
        find.byKey(RechargeHubScreen.sellKey),
      );
      expect(sell.onPressed, isNull);
    });

    testWidgets('an employee off shift cannot sell', (tester) async {
      await _pump(
        tester,
        AppRoutes.recharge,
        repo: FakeRechargeRepository(
          mine: RechargeAgentMe(
            status: RechargeAgentStatus.none,
            canApply: false,
            rules: fixtureRules,
            employment: RechargeEmployment(
              agentCode: 'coin0007',
              agent: UserSummaryFixtures.agent('coin0007'),
              timeZone: 'Africa/Cairo',
              schedule: const [
                WeeklySlot(days: [6], start: '10:00', end: '18:00'),
              ],
              onShiftNow: false,
            ),
          ),
        ),
      );
      expect(find.byKey(RechargeHubScreen.employmentKey), findsOneWidget);
      expect(
        tester.widget<KButton>(find.byKey(RechargeHubScreen.sellKey)).onPressed,
        isNull,
      );
      expect(find.text(_en.errorRechargeOffShift), findsOneWidget);
    });
  });

  group('selling', () {
    testWidgets('confirm, then one sale with an Idempotency-Key', (
      tester,
    ) async {
      final repo = FakeRechargeRepository(mine: fixtureActive());
      await _pump(tester, AppRoutes.recharge, repo: repo);
      await tester.tap(find.byKey(RechargeHubScreen.sellKey));
      await tester.pumpAndSettle();
      // Nothing typed: an honest error, no request.
      await tester.tap(find.byKey(RechargeSellSheet.submitKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.rechargeSellInvalid), findsOneWidget);
      await tester.enterText(
        find.byKey(RechargeSellSheet.buyerKey),
        '@layla.k',
      );
      await tester.enterText(find.byKey(RechargeSellSheet.coinsKey), '50000');
      await tester.tap(find.byKey(RechargeSellSheet.submitKey));
      await tester.pumpAndSettle();
      expect(
        find.text(
          _en.rechargeSellConfirm(
            KFormat.bidiIsolate('50,000'),
            KFormat.bidiIsolate('@layla.k'),
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('recharge.sell.confirm')));
      await tester.pumpAndSettle();
      expect(repo.sold, hasLength(1));
      expect(repo.sold.single.buyer, '@layla.k');
      expect(repo.sold.single.coins, 50000);
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(repo.sold.single.key), isTrue);
      expect(
        find.text(
          _en.rechargeSold(
            KFormat.bidiIsolate('50,000'),
            KFormat.bidiIsolate('ليلى'),
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group('the application', () {
    for (final language in AppLanguage.values) {
      final l10n = language == AppLanguage.ar ? _ar : _en;
      testWidgets('checks the name, the phone and the pictures, then sends '
          '(${language.name})', (tester) async {
        final repo = FakeRechargeRepository();
        final picker = _Picker();
        await _pump(
          tester,
          AppRoutes.rechargeApply,
          repo: repo,
          language: language,
          picker: picker,
          viewport: GoldenViewport.android,
        );
        expect(find.text(l10n.rechargePrivacyNote), findsOneWidget);
        await tester.enterText(
          find.byKey(RechargeApplyScreen.nameKey),
          'Mohamed Ali',
        );
        await tester.enterText(
          find.byKey(RechargeApplyScreen.phoneKey),
          '0100',
        );
        await tester.enterText(
          find.byKey(RechargeApplyScreen.countryKey(0)),
          'eg',
        );
        await tester.enterText(
          find.byKey(RechargeApplyScreen.citiesKey(0)),
          'Cairo, Giza',
        );
        await tester.pump();
        await tester.scrollUntilVisible(
          find.byKey(RechargeApplyScreen.submitKey),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        // A payment method in EG.
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('EG').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.descendant(
            of: find.byKey(RechargeApplyScreen.paymentKey(0)),
            matching: find.byType(TextField),
          ),
          'Vodafone Cash',
        );
        await tester.tap(find.byKey(RechargeApplyScreen.submitKey));
        await tester.pumpAndSettle();
        expect(repo.applied, isEmpty);
        await tester.scrollUntilVisible(
          find.byKey(RechargeApplyScreen.nameKey),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(l10n.rechargeFullNameError), findsOneWidget);
        expect(find.text(l10n.rechargePhoneError), findsOneWidget);
        await tester.enterText(
          find.byKey(RechargeApplyScreen.nameKey),
          'Mohamed Ahmed Ali Hassan',
        );
        await tester.enterText(
          find.byKey(RechargeApplyScreen.phoneKey),
          '+201001234567',
        );
        await tester.ensureVisible(find.byKey(RechargeApplyScreen.photoKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(RechargeApplyScreen.photoKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(RechargeApplyScreen.selfieKey));
        await tester.pumpAndSettle();
        // The selfie is taken with the camera (face confirmation).
        expect(picker.asked, [AvatarSource.library, AvatarSource.camera]);
        await tester.scrollUntilVisible(
          find.byKey(RechargeApplyScreen.submitKey),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byKey(RechargeApplyScreen.submitKey));
        await tester.pumpAndSettle();
        expect(repo.applied, hasLength(1));
        final d = repo.applied.single;
        expect(d.fullName, 'Mohamed Ahmed Ali Hassan');
        expect(d.phone, '+201001234567');
        expect(d.photoType, 'image/png');
        expect(d.locations.single.country, 'EG');
        expect(d.locations.single.cities, ['Cairo', 'Giza']);
        expect(d.paymentMethods.single.details, 'Vodafone Cash');
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('employees', () {
    testWidgets('hours, on shift, per-employee sales; remove asks first', (
      tester,
    ) async {
      final repo = FakeRechargeRepository(
        mine: fixtureActive(),
        staff: [
          RechargeEmployee(
            user: fixtureStaff,
            timeZone: 'Africa/Cairo',
            schedule: const [
              WeeklySlot(days: [6, 7], start: '10:00', end: '18:00'),
            ],
            onShiftNow: true,
            addedAt: DateTime.utc(2026, 10, 20),
            sales: (
              today: (count: 2, coins: 300000),
              last7Days: (count: 9, coins: 2100000),
              last30Days: (count: 30, coins: 8000000),
            ),
          ),
        ],
      );
      await _pump(tester, AppRoutes.rechargeEmployees, repo: repo);
      expect(
        find.byKey(RechargeEmployeesScreen.rowKey('sami')),
        findsOneWidget,
      );
      expect(find.text(_en.rechargeOnShift), findsOneWidget);
      expect(
        find.text(_en.rechargeSalesTotals(2, KFormat.bidiIsolate('300,000'))),
        findsOneWidget,
      );
      await tester.tap(find.text(_en.rechargeRemove));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en.rechargeRemove).last);
      await tester.pumpAndSettle();
      expect(repo.removed, ['sami']);
      expect(find.byKey(RechargeEmployeesScreen.emptyKey), findsOneWidget);
    });
  });

  group('the directory', () {
    for (final language in AppLanguage.values) {
      final l10n = language == AppLanguage.ar ? _ar : _en;
      testWidgets('agents of the country; «تواصل» → leaving sheet → WhatsApp '
          '(${language.name}, 360×800 ×1.3)', (tester) async {
        final opener = _Opener();
        final repo = FakeRechargeRepository(
          agents: [_listing('coin0007'), _listing('coin0012', now: false)],
        );
        await _pump(
          tester,
          AppRoutes.rechargeAgents,
          repo: repo,
          language: language,
          opener: opener,
          viewport: GoldenViewport.android,
          textScale: 1.3,
        );
        expect(repo.lastCountry, isNotNull);
        expect(
          find.byKey(RechargeDirectoryScreen.cardKey('coin0007')),
          findsOneWidget,
        );
        expect(
          find.text(l10n.rechargeIdLine(KFormat.bidiIsolate('coin0007'))),
          findsOneWidget,
        );
        expect(find.byType(RechargeAgentBadge), findsWidgets);
        // Not available now: no contact button.
        expect(
          find.byKey(RechargeDirectoryScreen.contactKey('coin0012')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(RechargeDirectoryScreen.contactKey('coin0007')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(ProfileLinkKeys.leavingSheet), findsOneWidget);
        expect(find.text('https://wa.me/201001234567'), findsOneWidget);
        await tester.tap(find.byKey(ProfileLinkKeys.leavingOpen));
        await tester.pumpAndSettle();
        expect(opener.opened, [Uri.parse('https://wa.me/201001234567')]);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('empty country', (tester) async {
      await _pump(
        tester,
        AppRoutes.rechargeAgents,
        repo: FakeRechargeRepository(),
      );
      expect(find.byKey(RechargeDirectoryScreen.emptyKey), findsOneWidget);
    });
  });

  group('cherry sales', () {
    testWidgets('the other side confirms; the creator may only cancel', (
      tester,
    ) async {
      final me = testUser();
      final byAgent = RechargeCherryRequest(
        id: 'r1',
        status: RechargeCherryStatus.pending,
        cherries: 2000000,
        coins: 186440,
        payoutMinor: 220,
        currency: 'USD',
        agentCode: 'coin0007',
        agent: UserSummaryFixtures.agent('coin0007'),
        host: UserSummary(
          id: me.id,
          username: me.username,
          displayName: me.displayName,
          avatarUrl: null,
        ),
        byHost: false,
        createdAt: DateTime.utc(2026, 10, 30, 12),
        expiresAt: DateTime.utc(2026, 10, 30, 12, 30),
      );
      final repo = FakeRechargeRepository(requests: [byAgent]);
      await _pump(tester, AppRoutes.rechargeCherries, repo: repo);
      expect(
        find.text(
          _en.rechargeCherryLine(
            KFormat.bidiIsolate('2,000,000'),
            KFormat.bidiIsolate('186,440'),
          ),
        ),
        findsOneWidget,
      );
      expect(find.byKey(RechargeCherryScreen.cancelKey('r1')), findsNothing);
      await tester.tap(find.byKey(RechargeCherryScreen.confirmKey('r1')));
      await tester.pumpAndSettle();
      expect(repo.answered, [('r1', 'confirm')]);
    });
  });

  group('perks', () {
    for (final language in AppLanguage.values) {
      final l10n = language == AppLanguage.ar ? _ar : _en;
      testWidgets('the frame writes the code in its plate; the entrance bar '
          'and the badge (${language.name})', (tester) async {
        await pumpScreen(
          tester,
          const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RechargeAgentFrame(
                    width: 200,
                    name: 'Nour',
                    code: 'coin0007',
                  ),
                  SizedBox(
                    width: 360,
                    child: RechargeEntranceBar(name: 'Nour'),
                  ),
                  RechargeAgentBadge(code: 'coin0007', height: 22),
                ],
              ),
            ),
          ),
          language: language,
        );
        // The bar names the agent by the display name, never the code.
        final bar = find.byKey(LiveRechargeEntranceLayer.barKey);
        expect(
          find.descendant(of: bar, matching: find.textContaining('Nour')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: bar, matching: find.textContaining('coin0007')),
          findsNothing,
        );
        expect(
          find.bySemanticsLabel(
            l10n.rechargeEntranceJoined(KFormat.bidiIsolate('Nour')),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            l10n.rechargeAgentBadgeLabel(KFormat.bidiIsolate('coin0007')),
          ),
          findsOneWidget,
        );
        // The display name sits inside the plate.
        final plate = tester.getRect(find.byKey(RechargeAgentFrame.plateKey));
        final frame = tester.getRect(find.byKey(RechargeAgentFrame.frameKey));
        expect(plate.top, greaterThan(frame.top + frame.height * 0.7));
        expect(plate.bottom, lessThanOrEqualTo(frame.bottom));
        expect(LiveRechargeEntranceLayer.duration.inMilliseconds, 3200);
        expect(tester.takeException(), isNull);
      });
    }

    test('wire: rechargeAgent on UserSummary is the code; absent → null', () {
      final base = {
        'id': 'u-1',
        'username': 'a',
        'displayName': 'A',
        'avatarUrl': null,
      };
      expect(
        UserSummary.fromJson({
          ...base,
          'rechargeAgent': {'code': 'coin0001'},
        }).rechargeAgentCode,
        'coin0001',
      );
      expect(UserSummary.fromJson(base).rechargeAgentCode, isNull);
      expect(
        UserSummary.fromJson({...base, 'rechargeAgent': 'x'}).rechargeAgentCode,
        isNull,
      );
      expect(
        UserSummary.fromJson(base).toJson().containsKey('rechargeAgent'),
        isFalse,
      );
    });
  });
}
