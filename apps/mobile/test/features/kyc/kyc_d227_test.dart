// v1.80-kyc (D227, CONVENTIONS §10.77): «تأكيد الهوية» with Didit — the step
// the host-apply, agency-open and recharge-apply forms show while Didit is on
// (in place of the manual ID card + selfie): not started, in progress, under
// review, approved, declined with the reasons and «إعادة المحاولة», expired,
// the daily limit; the hosted flow (faked) then the sync; the forms' gates (host /
// recharge: approved or under review; agency: approved) and the drafts sent
// without pictures; the notifications. Arabic RTL and English LTR, 393×852 and
// 360×800 with text ×1.3, light and dark, plus goldens. Fakes only (Didit is
// the API's e2e `d227-didit-kyc`, itself faked). With
// --dart-define=D227_CAPTURE_DIR=<dir> the owner's captures are written.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart';
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
import 'package:kabso_live/features/agency/presentation/agency_open_screen.dart';
import 'package:kabso_live/features/agency/presentation/host_apply_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/kyc/application/kyc_providers.dart';
import 'package:kabso_live/features/kyc/data/kyc_models.dart';
import 'package:kabso_live/features/kyc/data/kyc_repository.dart';
import 'package:kabso_live/features/kyc/presentation/kyc_flow.dart';
import 'package:kabso_live/features/kyc/presentation/kyc_step.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_apply_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_economy_repositories.dart';
import '../../helpers/fake_kyc_repository.dart';
import '../../helpers/fake_recharge_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _captureDir = String.fromEnvironment('D227_CAPTURE_DIR');
final AppLocalizations _ar = l10nFor(AppLanguage.ar);
final AppLocalizations _en = l10nFor(AppLanguage.en);
final GlobalKey _boundary = GlobalKey();
const _stepHarness = '/test/kyc-step';

/// The step alone (for the states and the goldens), in a padded scroll view.
class _StepPage extends StatelessWidget {
  const new({required this.purpose});

  final KycPurpose purpose;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.palette.background,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(KSpacing.lg),
        children: [KycStep(purpose: purpose)],
      ),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeKycRepository kyc,
  FakeKycFlow? flow,
  FakeAgencyRepository? agency,
  FakeRechargeRepository? recharge,
  String location = _stepHarness,
  KycPurpose purpose = KycPurpose.hostApplication,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: _stepHarness,
        builder: (_, _) => _StepPage(purpose: purpose),
      ),
      GoRoute(
        path: AppRoutes.agency,
        builder: (_, _) => const Scaffold(),
        routes: [
          GoRoute(path: 'open', builder: (_, _) => const AgencyOpenScreen()),
          GoRoute(
            path: 'host-apply',
            builder: (_, _) => const HostApplyScreen(),
          ),
        ],
      ),
      GoRoute(path: AppRoutes.recharge, builder: (_, _) => const Scaffold()),
      GoRoute(
        path: AppRoutes.rechargeApply,
        builder: (_, _) => const RechargeApplyScreen(),
      ),
    ],
  );
  await loadAppFonts();
  setViewport(tester, viewport);
  final prefs = await testPrefs(language: language.name);
  final user = testUser(displayName: 'Sara Ali').copyWith(country: 'SA');
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          currentUserProvider.overrideWithValue(user),
          kycRepositoryProvider.overrideWithValue(kyc),
          kycFlowLauncherProvider.overrideWithValue(flow ?? FakeKycFlow()),
          agencyRepositoryProvider.overrideWithValue(
            agency ??
                FakeAgencyRepository(
                  mine: testMyAgency(openRule: testOpenRule()),
                ),
          ),
          rechargeRepositoryProvider.overrideWithValue(
            recharge ?? FakeRechargeRepository(),
          ),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          locale: language.locale,
          supportedLocales: KabsoApp.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          theme: buildAppTheme(brightness: brightness, locale: language.locale),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureDir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await Directory(_captureDir).create(recursive: true);
    await File('$_captureDir/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
  });
}

Future<void> _at(Future<void> Function() body) =>
    withClock(Clock.fixed(economyAt), body);

FakeKycRepository _on(KycPurposeState state, {int started = 0}) =>
    FakeKycRepository(state: kycOn([state], started: started));

void main() {
  group('the step «تأكيد الهوية»', () {
    final cases =
        <(String, KycPurposeState, String Function(AppLocalizations))>[
          (
            'notStarted',
            kycState(KycPurpose.hostApplication, KycStatus.notStarted),
            (l) => l.kycStatusNotStarted,
          ),
          (
            'inProgress',
            kycState(KycPurpose.hostApplication, KycStatus.inProgress),
            (l) => l.kycStatusInProgress,
          ),
          (
            'inReview',
            kycState(KycPurpose.hostApplication, KycStatus.inReview),
            (l) => l.kycStatusInReview,
          ),
          (
            'approved',
            kycState(KycPurpose.hostApplication, KycStatus.approved),
            (l) => l.kycStatusApproved,
          ),
          (
            'declined',
            kycState(
              KycPurpose.hostApplication,
              KycStatus.declined,
              reasons: [
                'LIVENESS_FACE_ATTACK',
                'UNDER_MIN_AGE',
                'SOMETHING_NEW',
              ],
            ),
            (l) => l.kycStatusDeclined,
          ),
          (
            'expired',
            kycState(KycPurpose.hostApplication, KycStatus.expired),
            (l) => l.kycStatusExpired,
          ),
        ];
    for (final language in AppLanguage.values) {
      final l10n = language == AppLanguage.ar ? _ar : _en;
      for (final (name, state, title) in cases) {
        testWidgets('$name (${language.name})', (tester) async {
          await _pump(tester, kyc: _on(state), language: language);
          expect(find.byKey(KycStep.cardKey), findsOneWidget);
          expect(find.text(title(l10n)), findsOneWidget);
          final button = find.byKey(KycStep.startKey);
          final shows =
              state.status != KycStatus.approved &&
              state.status != KycStatus.inReview;
          expect(button, shows ? findsOneWidget : findsNothing);
          if (state.status == KycStatus.declined) {
            expect(find.text(l10n.kycRetry), findsOneWidget);
            expect(find.text(l10n.kycReasonLiveness), findsOneWidget);
            expect(find.text(l10n.kycReasonUnderAge), findsOneWidget);
            // An unknown code: the general sentence, never the code.
            expect(find.text(l10n.kycReasonOther), findsOneWidget);
            expect(find.textContaining('SOMETHING_NEW'), findsNothing);
          }
          if (state.status == KycStatus.inProgress) {
            expect(find.text(l10n.kycContinue), findsOneWidget);
          }
          final dir = Directionality.of(
            tester.element(find.byKey(KycStep.cardKey)),
          );
          expect(
            dir,
            language == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr,
          );
          await _capture(tester, 'kyc_step.$name.${language.name}');
        });
      }
    }

    testWidgets('the daily limit: the button is off and it says why', (
      tester,
    ) async {
      await _pump(
        tester,
        kyc: _on(
          kycState(
            KycPurpose.hostApplication,
            KycStatus.declined,
            canStart: false,
            refusal: KycRefusal.dailyLimit,
          ),
          started: 3,
        ),
        language: AppLanguage.ar,
      );
      expect(find.text(_ar.kycRefusedDailyLimit), findsOneWidget);
      expect(
        tester.widget<KButton>(find.byKey(KycStep.startKey)).onPressed,
        isNull,
      );
    });

    testWidgets('start → the hosted flow (faked) → sync → approved', (
      tester,
    ) async {
      final kyc = _on(kycState(KycPurpose.agencyOpen, KycStatus.notStarted))
        ..afterSync = kycState(KycPurpose.agencyOpen, KycStatus.approved);
      final flow = FakeKycFlow();
      await _pump(
        tester,
        kyc: kyc,
        flow: flow,
        purpose: KycPurpose.agencyOpen,
        language: AppLanguage.ar,
      );
      await tester.tap(find.byKey(KycStep.startKey));
      await tester.pumpAndSettle();
      expect(kyc.starts, [(KycPurpose.agencyOpen, 'ar')]);
      expect(flow.opened.single.url, 'https://verify.didit.me/session/test');
      expect(kyc.syncs, ['check-1']);
      expect(find.text(_ar.kycStatusApproved), findsOneWidget);
      expect(find.byKey(KycStep.startKey), findsNothing);
    });

    testWidgets('a flow closed early: no sync; the state stays', (
      tester,
    ) async {
      final kyc = _on(
        kycState(KycPurpose.hostApplication, KycStatus.notStarted),
      );
      await _pump(tester, kyc: kyc, flow: FakeKycFlow(finishes: false));
      await tester.tap(find.byKey(KycStep.startKey));
      await tester.pumpAndSettle();
      expect(kyc.starts, hasLength(1));
      expect(kyc.syncs, isEmpty);
      expect(find.text(_en.kycStatusNotStarted), findsOneWidget);
    });

    testWidgets('Didit off on the server: the start error is said', (
      tester,
    ) async {
      final kyc =
          _on(kycState(KycPurpose.hostApplication, KycStatus.notStarted))
            ..startError = const ServerFailure(
              code: ErrorCode.kycUnavailable,
              rawCode: 'KYC_UNAVAILABLE',
              debugMessage: 'off',
              statusCode: 503,
            );
      await _pump(tester, kyc: kyc);
      await tester.tap(find.byKey(KycStep.startKey));
      await tester.pumpAndSettle();
      expect(find.byKey(KycStep.errorKey), findsOneWidget);
    });

    for (final language in AppLanguage.values) {
      for (final brightness in Brightness.values) {
        testWidgets('no overflow at 360×800, text ×1.3 '
            '(${language.name}, ${brightness.name})', (tester) async {
          for (final (_, state, _) in cases) {
            await _pump(
              tester,
              kyc: _on(state),
              language: language,
              viewport: GoldenViewport.android,
              textScale: 1.3,
              brightness: brightness,
            );
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  });

  group('the forms with Didit on', () {
    testWidgets('host apply: the step instead of the ID tiles; blocked until '
        'approved or in review; sent without pictures', (tester) async {
      await _at(() async {
        final agency = FakeAgencyRepository(
          mine: testMyAgency(openRule: testOpenRule()),
          hostingState: testHosting(),
        );
        final kyc = _on(
          kycState(KycPurpose.hostApplication, KycStatus.notStarted),
        );
        await _pump(
          tester,
          kyc: kyc,
          agency: agency,
          location: '${AppRoutes.agency}/host-apply',
        );
        expect(find.byKey(HostApplyScreen.idCardKey), findsNothing);
        expect(find.byKey(HostApplyScreen.selfieKey), findsNothing);
        await tester.scrollUntilVisible(
          find.byKey(KycStep.cardKey),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(_en.kycStepTitle), findsWidgets);
        await _capture(tester, 'host_apply.kyc_step.en');
        // The rest of the form filled in: not sent while not verified.
        await _fillHost(tester);
        await tester.tap(find.byKey(HostApplyScreen.submitKey));
        await tester.pumpAndSettle();
        expect(agency.applied, isEmpty);
        await tester.scrollUntilVisible(
          find.text(_en.kycRequiredToSubmit),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(_en.kycRequiredToSubmit), findsOneWidget);
        // Under Didit's review: may be sent (the team approves after an
        // approved check), and without pictures.
        kyc.state = kycOn([
          kycState(KycPurpose.hostApplication, KycStatus.inReview),
        ]);
        ProviderScope.containerOf(tester.element(find.byType(HostApplyScreen)))
            .invalidate(myKycProvider);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(HostApplyScreen.submitKey));
        await tester.pumpAndSettle();
        expect(agency.applied, hasLength(1));
        expect(agency.applied.single.idCard, isNull);
        expect(agency.applied.single.selfie, isNull);
      });
    });

    testWidgets('agency open: refused until approved (in review is not '
        'enough); the draft carries no pictures', (tester) async {
      await _at(() async {
        final agency = FakeAgencyRepository(
          mine: testMyAgency(openRule: testOpenRule()),
        );
        final kyc = _on(kycState(KycPurpose.agencyOpen, KycStatus.inReview));
        await _pump(
          tester,
          kyc: kyc,
          agency: agency,
          location: AppRoutes.agencyOpen,
          language: AppLanguage.ar,
        );
        expect(find.byKey(AgencyOpenScreen.idCardKey), findsNothing);
        await _fillAgency(tester);
        await tester.tap(find.byKey(AgencyOpenScreen.submitKey));
        await tester.pumpAndSettle();
        expect(agency.opened, isEmpty);
        await tester.scrollUntilVisible(
          find.text(_ar.kycRequiredApproved),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(_ar.kycRequiredApproved), findsOneWidget);
        await _capture(tester, 'agency_open.kyc_in_review.ar');
        // Approved now: sent, without pictures.
        kyc.state = kycOn([
          kycState(KycPurpose.agencyOpen, KycStatus.approved),
        ]);
        final element = tester.element(find.byType(AgencyOpenScreen));
        ProviderScope.containerOf(element).invalidate(myKycProvider);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(AgencyOpenScreen.submitKey));
        await tester.pumpAndSettle();
        expect(agency.opened, hasLength(1));
        expect(agency.opened.single.idCard, isNull);
        expect(agency.opened.single.selfie, isNull);
      });
    });

    testWidgets('recharge apply: the step instead of the photos', (
      tester,
    ) async {
      await _pump(
        tester,
        kyc: _on(kycState(KycPurpose.rechargeAgent, KycStatus.approved)),
        location: AppRoutes.rechargeApply,
        language: AppLanguage.ar,
      );
      expect(find.byKey(RechargeApplyScreen.photoKey), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(KycStep.cardKey),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(_ar.kycStatusApproved), findsOneWidget);
      await _capture(tester, 'recharge_apply.kyc_approved.ar');
    });

    testWidgets('Didit off: the forms keep the ID tiles (as before)', (
      tester,
    ) async {
      await _pump(
        tester,
        kyc: FakeKycRepository(),
        location: AppRoutes.agencyOpen,
      );
      expect(find.byKey(KycStep.cardKey), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(AgencyOpenScreen.idCardKey),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(AgencyOpenScreen.idCardKey), findsOneWidget);
    });
  });

  group('the notifications', () {
    test('three system types, open «الوكالة» from the inbox and the push', () {
      for (final (wire, type) in [
        ('KYC_APPROVED', NotificationType.kycApproved),
        ('KYC_DECLINED', NotificationType.kycDeclined),
        ('KYC_IN_REVIEW', NotificationType.kycInReview),
      ]) {
        expect(NotificationType.fromWire(wire), type);
        expect(type.isSystem, isTrue);
        expect(type.isKyc, isTrue);
        expect(
          PushPayload({'kind': 'notification', 'type': wire}).route(),
          AppRoutes.agency,
        );
      }
      expect(_ar.notifKycApproved, isNotEmpty);
      expect(_en.notifKycDeclined, isNotEmpty);
    });
  });

  group('goldens', () {
    for (final language in AppLanguage.values) {
      testWidgets('kyc_step.declined + approved (${language.name})', (
        tester,
      ) async {
        await _pump(
          tester,
          kyc: _on(
            kycState(
              KycPurpose.hostApplication,
              KycStatus.declined,
              reasons: ['LIVENESS_FACE_ATTACK', 'DOCUMENT_EXPIRED'],
            ),
          ),
          language: language,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/kyc_step.declined.${language.name}.phone.png',
          ),
        );
        await _pump(
          tester,
          kyc: _on(kycState(KycPurpose.hostApplication, KycStatus.approved)),
          language: language,
          brightness: Brightness.dark,
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            '../../goldens/png/kyc_step.approved_dark.${language.name}.phone.png',
          ),
        );
      }, tags: goldenTag);
    }
  });
}

/// The host form without the pictures (the date through the picker's text
/// entry, en-US).
Future<void> _fillHost(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(HostApplyScreen.birthKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(HostApplyScreen.birthKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
    '05/01/2000',
  );
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(HostApplyScreen.contactKey),
    '+966511111111',
  );
  await tester.enterText(
    find.byKey(HostApplyScreen.bioKey),
    'Cooking and chat every evening',
  );
  // The checkbox in the middle of the screen (never under the sticky bar).
  // The checkbox clear of the sticky bar: the list at its end.
  final list = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  for (var i = 0; i < 5; i++) {
    // A lazy list grows its extent as the last items are built.
    list.jumpTo(list.maxScrollExtent);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(HostApplyScreen.acceptKey));
  await tester.pumpAndSettle();
  expect(
    tester.widget<Checkbox>(find.byKey(HostApplyScreen.acceptKey)).value,
    isTrue,
  );
}

Future<void> _fillAgency(WidgetTester tester) async {
  await tester.enterText(find.byKey(AgencyOpenScreen.nameKey), 'وكالة النجوم');
  await tester.ensureVisible(find.byKey(AgencyOpenScreen.countryKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(AgencyOpenScreen.countryKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text('السعودية').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(AgencyOpenScreen.contactKey),
    '+966500000000',
  );
  await tester.enterText(find.byKey(AgencyOpenScreen.expectedKey), '25');
}
