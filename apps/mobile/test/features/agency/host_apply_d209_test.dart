// v1.73-social (D209, CONVENTIONS §10.68): «كن مضيفاً مع الإدارة» — the card
// under «انضم إلى وكالة» and «افتح وكالة», the form (the name to check, the
// country, the date of birth 18+, the contact, the bio, links, the mandatory
// ID check, the host rules), the pending / approved / rejected states, the
// notifications and the push route. Arabic RTL and English LTR, 393×852 and
// 360×800 with text ×1.3, light and dark. Fakes only (the real flow is the
// API's e2e `d209-host-apply`). With --dart-define=D209_CAPTURE_DIR=<dir> the
// owner's captures are written (393×852 @3x).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/agency/data/agency_repository.dart';
import 'package:kabso_live/features/agency/data/hosting_application.dart';
import 'package:kabso_live/features/agency/presentation/agency_open_screen.dart';
import 'package:kabso_live/features/agency/presentation/agency_screen.dart';
import 'package:kabso_live/features/agency/presentation/host_apply_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_economy_repositories.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _captureDir = String.fromEnvironment('D209_CAPTURE_DIR');
final AppLocalizations _ar = l10nFor(AppLanguage.ar);
final AppLocalizations _en = l10nFor(AppLanguage.en);
final GlobalKey _boundary = GlobalKey();
const _goLivePage = Key('test.goLive');

/// The form's own list (the agency page stays under it in the stack).
final Finder _formList = find
    .descendant(
      of: find.byType(HostApplyScreen),
      matching: find.byType(Scrollable),
    )
    .first;

/// A 1×1 PNG (the "photo" the fake picker returns).
final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13, 0x49, 0x48, //
  0x44, 0x52, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 0x1F, 0x15, 0xC4, 0x89,
  0, 0, 0, 13, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0, 1, 0, 0, 5, 0, 1,
  0x0D, 0x0A, 0x2D, 0xB4, 0, 0, 0, 0, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class _Picker implements AvatarPhotoPicker {
  new([this.bytes]);

  final Uint8List? bytes;
  final asked = <AvatarSource>[];

  @override
  Future<Uint8List?> pick(AvatarSource source) async {
    asked.add(source);
    return bytes ?? _png;
  }
}

/// A labelled stand-in picture for the captures (a plain card, never a real
/// document or face), decodable by the engine.
Future<Uint8List> _standIn(WidgetTester tester) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..drawRect(
        const Rect.fromLTWH(0, 0, 240, 240),
        Paint()..color = const Color(0xFFB9C2CF),
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(30, 70, 180, 110),
          const Radius.circular(12),
        ),
        Paint()..color = const Color(0xFFF4F6F9),
      )
      ..drawCircle(
        const Offset(75, 125),
        24,
        Paint()..color = const Color(0xFF8A96A8),
      );
    final image = await recorder.endRecording().toImage(240, 240);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeAgencyRepository agency,
  _Picker? picker,
  String location = AppRoutes.agency,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool canHost = false,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: AppRoutes.agency,
        builder: (_, _) => const AgencyScreen(),
        routes: [
          GoRoute(path: 'open', builder: (_, _) => const AgencyOpenScreen()),
          GoRoute(
            path: 'host-apply',
            builder: (_, state) => switch (state.extra) {
              final int minAge => HostApplyScreen(minAge: minAge),
              _ => const HostApplyScreen(),
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.goLive,
        builder: (_, _) => const Scaffold(key: _goLivePage),
      ),
    ],
  );
  await loadAppFonts();
  setViewport(tester, viewport);
  final prefs = await testPrefs(language: language.name);
  final user = testUser(displayName: 'Sara Ali')
      .copyWith(canHost: canHost, country: 'SA');
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          currentUserProvider.overrideWithValue(user),
          agencyRepositoryProvider.overrideWithValue(agency),
          avatarPhotoPickerProvider.overrideWithValue(picker ?? _Picker()),
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

/// The owner's capture (only with D209_CAPTURE_DIR).
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

/// The test's "now": 2026-10-29 09:30 UTC.
Future<void> _at(Future<void> Function() body) =>
    withClock(Clock.fixed(economyAt), body);

FakeAgencyRepository _canApply() => FakeAgencyRepository(
  mine: testMyAgency(openRule: testOpenRule()),
  hostingState: testHosting(),
);

/// Picks a date of birth through the Material picker's text entry (en-US).
Future<void> _pickBirth(WidgetTester tester, String mmddyyyy) async {
  await tester.ensureVisible(find.byKey(HostApplyScreen.birthKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(HostApplyScreen.birthKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)),
    mmddyyyy,
  );
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> _fillForm(
  WidgetTester tester, {
  String birth = '05/01/2000',
}) async {
  await _pickBirth(tester, birth);
  await tester.enterText(
    find.byKey(HostApplyScreen.contactKey),
    '+966511111111',
  );
  await tester.enterText(
    find.byKey(HostApplyScreen.bioKey),
    'Cooking and chat every evening',
  );
  await tester.enterText(
    find.byKey(HostApplyScreen.linkKey(0)),
    'https://www.tiktok.com/@sara',
  );
  for (final key in [HostApplyScreen.idCardKey, HostApplyScreen.selfieKey]) {
    final preview = find.descendant(
      of: find.byKey(key),
      matching: find.byType(ClipOval),
    );
    await tester.ensureVisible(preview);
    await tester.pumpAndSettle();
    await tester.tap(preview);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byKey(HostApplyScreen.acceptKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(HostApplyScreen.acceptKey));
  await tester.pumpAndSettle();
}

void main() {
  group('«كن مضيفاً مع الإدارة» on «الوكالة»', () {
    testWidgets('in no agency: the third card under join and open, with what '
        'it means; the button opens the form', (tester) async {
      await _pump(tester, agency: _canApply());
      final join = tester.getTopLeft(find.text(_en.agencyJoinTitle));
      final open = tester.getTopLeft(find.byKey(AgencyScreen.openKey));
      await tester.ensureVisible(find.byKey(AgencyScreen.hostApplyKey));
      await tester.pumpAndSettle();
      final host = tester.getTopLeft(find.byKey(AgencyScreen.hostCardKey));
      expect(open.dy, greaterThan(join.dy));
      expect(
        host.dy,
        greaterThan(tester.getTopLeft(find.byKey(AgencyScreen.openKey)).dy),
      );
      expect(find.text(_en.hostApplyTitle), findsOneWidget);
      expect(find.text(_en.hostApplyIntro), findsOneWidget);
      expect(
        tester.widget<KButton>(find.byKey(AgencyScreen.hostApplyKey)).onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(AgencyScreen.hostApplyKey));
      await tester.pumpAndSettle();
      expect(find.byType(HostApplyScreen), findsOneWidget);
      // The profile's name is there to check.
      expect(find.text('Sara Ali'), findsOneWidget);
    });

    testWidgets('an older server (no route): no card; in an agency or an '
        'agency owner: no card', (tester) async {
      await _pump(
        tester,
        agency: FakeAgencyRepository(
          mine: testMyAgency(openRule: testOpenRule()),
        ),
      );
      expect(find.byKey(AgencyScreen.openKey), findsOneWidget);
      expect(find.byKey(AgencyScreen.hostCardKey), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        agency: FakeAgencyRepository(
          mine: testMyAgency(membership: testMembership()),
          hostingState: testHosting(refusal: HostingApplyRefusal.hostOfAgency),
        ),
      );
      expect(find.byKey(AgencyScreen.membershipKey), findsOneWidget);
      expect(find.byKey(AgencyScreen.hostCardKey), findsNothing);
    });

    testWidgets('pending: «under review» with the date; cancel asks, then '
        'the card offers to apply again', (tester) async {
      await _at(() async {
        final agency = FakeAgencyRepository(
          mine: testMyAgency(openRule: testOpenRule()),
          hostingState: testHosting(
            application: testHostingApplication(),
            refusal: HostingApplyRefusal.pending,
          ),
        );
        await _pump(tester, agency: agency);
        await tester.ensureVisible(find.byKey(AgencyScreen.hostPendingKey));
        await tester.pumpAndSettle();
        expect(find.text(_en.hostApplyPendingTitle), findsOneWidget);
        expect(find.byKey(AgencyScreen.hostApplyKey), findsNothing);
        await tester.tap(find.byKey(AgencyScreen.hostCancelKey));
        await tester.pumpAndSettle();
        expect(find.text(_en.hostApplyCancelConfirmTitle), findsOneWidget);
        // «Keep it» changes nothing.
        await tester.tap(find.text(_en.hostApplyCancelKeep));
        await tester.pumpAndSettle();
        expect(agency.calls, isNot(contains('cancelHosting')));
        await tester.tap(find.byKey(AgencyScreen.hostCancelKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_en.hostApplyCancel).last);
        await tester.pumpAndSettle();
        expect(agency.calls, contains('cancelHosting'));
        expect(find.byKey(AgencyScreen.hostPendingKey), findsNothing);
        await tester.ensureVisible(find.byKey(AgencyScreen.hostApplyKey));
        expect(
          tester
              .widget<KButton>(find.byKey(AgencyScreen.hostApplyKey))
              .onPressed,
          isNotNull,
        );
      });
    });

    testWidgets('approved: «You host with the team ✓» and «Go live» opens '
        'go-live; an agency-given permission says only that they may', (
      tester,
    ) async {
      await _pump(
        tester,
        canHost: true,
        agency: FakeAgencyRepository(
          mine: testMyAgency(openRule: testOpenRule()),
          hostingState: testHosting(
            host: HostingSource.identity,
            application: testHostingApplication(
              status: HostingApplicationStatus.approved,
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.byKey(AgencyScreen.hostApprovedKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.hostApplyApprovedTitle), findsOneWidget);
      expect(find.text(_en.hostApplyApprovedBody), findsOneWidget);
      expect(find.byKey(AgencyScreen.hostApplyKey), findsNothing);
      await tester.tap(find.byKey(AgencyScreen.hostGoLiveKey));
      await tester.pumpAndSettle();
      expect(find.byKey(_goLivePage), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        canHost: true,
        agency: FakeAgencyRepository(
          mine: testMyAgency(openRule: testOpenRule()),
          hostingState: testHosting(host: HostingSource.agency),
        ),
      );
      await tester.ensureVisible(find.byKey(AgencyScreen.hostApprovedKey));
      expect(find.text(_en.hostApplyHostAgencyTitle), findsOneWidget);
      expect(find.text(_en.hostApplyApprovedTitle), findsNothing);
    });

    testWidgets('rejected: the reason and when to apply again (disabled '
        'until then), then «you can apply again now»', (tester) async {
      await _at(() async {
        final later = economyAt.add(const Duration(days: 29));
        await _pump(
          tester,
          agency: FakeAgencyRepository(
            mine: testMyAgency(openRule: testOpenRule()),
            hostingState: testHosting(
              application: testHostingApplication(
                status: HostingApplicationStatus.rejected,
                rejectReason: 'The ID photo is blurry',
                reapplyAt: later,
              ),
              refusal: HostingApplyRefusal.reapplyCooldown,
            ),
          ),
        );
        await tester.ensureVisible(find.byKey(AgencyScreen.hostRejectedKey));
        await tester.pumpAndSettle();
        expect(find.text(_en.hostApplyRejectedTitle), findsOneWidget);
        expect(
          find.text(_en.hostApplyRejectedReason('The ID photo is blurry')),
          findsOneWidget,
        );
        expect(find.textContaining('You can apply again from'), findsOneWidget);
        expect(
          tester
              .widget<KButton>(find.byKey(AgencyScreen.hostApplyKey))
              .onPressed,
          isNull,
        );
      });
      await tester.pumpWidget(const SizedBox());
      await _at(() async {
        await _pump(
          tester,
          agency: FakeAgencyRepository(
            mine: testMyAgency(openRule: testOpenRule()),
            hostingState: testHosting(
              application: testHostingApplication(
                status: HostingApplicationStatus.rejected,
                rejectReason: 'The ID photo is blurry',
                reapplyAt: economyAt.subtract(const Duration(minutes: 1)),
              ),
            ),
          ),
        );
        await tester.ensureVisible(find.byKey(AgencyScreen.hostRejectedKey));
        expect(find.text(_en.hostApplyReapplyNow), findsOneWidget);
        expect(
          tester
              .widget<KButton>(find.byKey(AgencyScreen.hostApplyKey))
              .onPressed,
          isNotNull,
        );
      });
    });
  });

  group('the form', () {
    testWidgets('everything is required but the links; under 18 is refused '
        'on the phone; then the draft goes up and the page says pending', (
      tester,
    ) async {
      await _at(() async {
        final agency = _canApply();
        final picker = _Picker();
        await _pump(tester, agency: agency, picker: picker);
        await tester.ensureVisible(find.byKey(AgencyScreen.hostApplyKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(AgencyScreen.hostApplyKey));
        await tester.pumpAndSettle();
        expect(find.byKey(HostApplyScreen.introKey), findsOneWidget);
        // Nothing filled in (but the name and country from the profile).
        await tester.tap(find.byKey(HostApplyScreen.submitKey));
        await tester.pumpAndSettle();
        expect(find.text(_en.hostApplyBirthError), findsOneWidget);
        expect(find.text(_en.hostApplyContactError), findsOneWidget);
        expect(find.text(_en.hostApplyBioError), findsOneWidget);
        expect(find.text(_en.hostApplyCountryError), findsNothing);
        await tester.scrollUntilVisible(
          find.text(_en.hostApplyRulesError),
          100,
          scrollable: _formList,
        );
        expect(find.text(_en.agencyOpenIdMissing), findsOneWidget);
        expect(find.text(_en.hostApplyRulesError), findsOneWidget);
        expect(find.byKey(HostApplyScreen.rulesKey), findsOneWidget);
        expect(agency.applied, isEmpty);

        // 17 years and 364 days old: refused before sending.
        await tester.scrollUntilVisible(
          find.byKey(HostApplyScreen.birthKey),
          -100,
          scrollable: _formList,
        );
        await _fillForm(tester, birth: '10/30/2008');
        await tester.tap(find.byKey(HostApplyScreen.submitKey));
        await tester.pumpAndSettle();
        expect(agency.applied, isEmpty);
        await tester.scrollUntilVisible(
          find.byKey(HostApplyScreen.birthKey),
          -100,
          scrollable: _formList,
        );
        // The helper and the error both say 18+.
        expect(
          find.text(_en.hostApplyMinAge(KFormat.bidiIsolate('18'))),
          findsWidgets,
        );
        // A bad link is refused too.
        await tester.enterText(
          find.byKey(HostApplyScreen.linkKey(0)),
          'http://insecure.example.com',
        );
        // Exactly 18 today.
        await _pickBirth(tester, '10/29/2008');
        await tester.tap(find.byKey(HostApplyScreen.submitKey));
        await tester.pumpAndSettle();
        expect(agency.applied, isEmpty);
        expect(find.text(_en.hostApplyLinkError), findsOneWidget);
        await tester.enterText(
          find.byKey(HostApplyScreen.linkKey(0)),
          'https://www.tiktok.com/@sara',
        );
        await tester.tap(find.byKey(HostApplyScreen.addLinkKey));
        await tester.pumpAndSettle();
        expect(find.byKey(HostApplyScreen.linkKey(1)), findsOneWidget);
        await tester.tap(find.byKey(HostApplyScreen.submitKey));
        await tester.pumpAndSettle();
        expect(picker.asked, [AvatarSource.library, AvatarSource.camera]);
        expect(agency.applied, hasLength(1));
        final d = agency.applied.single;
        expect(d.displayName, 'Sara Ali');
        expect(d.country, 'SA');
        expect(d.dateOfBirthWire, '2008-10-29');
        expect(d.contactType, HostingContactType.whatsapp);
        expect(d.contactValue, '+966511111111');
        expect(d.bio, 'Cooking and chat every evening');
        expect(d.links, ['https://www.tiktok.com/@sara']);
        expect(d.idCardType, 'image/png');
        // Back on «الوكالة»: under review.
        expect(find.byType(HostApplyScreen), findsNothing);
        await tester.ensureVisible(find.byKey(AgencyScreen.hostPendingKey));
        expect(find.text(_en.hostApplyPendingTitle), findsOneWidget);
      });
    });

    testWidgets('a server refusal says why; a retry of the same form keeps '
        'its Idempotency-Key', (tester) async {
      await _at(() async {
        final agency = _canApply()
          ..applyFailure = const ServerFailure(
            code: ErrorCode.hostApplicationNotAllowed,
            rawCode: 'HOST_APPLICATION_NOT_ALLOWED',
            debugMessage: 'no',
            statusCode: 409,
            details: [FieldIssue(field: 'application', issue: 'PENDING')],
          );
        await _pump(
          tester,
          agency: agency,
          location: AppRoutes.agencyHostApply,
        );
        await _fillForm(tester);
        await tester.tap(find.byKey(HostApplyScreen.submitKey));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.byKey(HostApplyScreen.errorKey)).data,
          _en.hostApplyRefusedPending,
        );
        await tester.tap(find.byKey(HostApplyScreen.submitKey));
        await tester.pumpAndSettle();
        expect(agency.applied, hasLength(2));
        expect(
          agency.applied.first.idempotencyKey,
          agency.applied.last.idempotencyKey,
        );
      });
    });
  });

  group('notifications and copy', () {
    test('the decision types open «الوكالة» (inbox and push)', () {
      for (final wire in [
        'HOST_APPLICATION_APPROVED',
        'HOST_APPLICATION_REJECTED',
      ]) {
        final type = NotificationType.fromWire(wire);
        expect(type.isHostApplication, isTrue, reason: wire);
        expect(type.isSystem, isTrue, reason: wire);
        expect(
          PushPayload({'kind': 'notification', 'type': wire}).route(),
          AppRoutes.agency,
        );
      }
      expect(
        ErrorCode.fromWire('HOST_APPLICATION_NOT_ALLOWED'),
        ErrorCode.hostApplicationNotAllowed,
      );
    });

    test("Arabic copy: the brand in Latin script, the owner's words", () {
      expect(_ar.hostApplyTitle, 'كن مضيفاً مع الإدارة');
      expect(_ar.hostApplyPendingTitle, 'طلبك قيد المراجعة');
      expect(_ar.hostApplyApprovedTitle, 'أنت مضيف مع الإدارة ✓');
      expect(_ar.hostApplyGoLive, 'ابدأ البث');
      expect(_ar.hostApplyIntro, contains('Kabso Live'));
      expect(_ar.hostApplyIntro, contains('بلا وكالة'));
      expect(_en.hostApplyIntro, contains('no agency commission'));
      expect(ageOn(DateTime(2008, 10, 29), DateTime(2026, 10, 29)), 18);
      expect(ageOn(DateTime(2008, 10, 30), DateTime(2026, 10, 29)), 17);
    });
  });

  group('Arabic RTL, English LTR, 360×800 ×1.3, light and dark', () {
    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        for (final brightness in Brightness.values) {
          testWidgets(
            'no overflow: ${language.name} ${viewport.name} ${brightness.name}',
            (tester) async {
              await _at(() async {
                final scale = viewport == GoldenViewport.android ? 1.3 : 1.0;
                Future<void> page(FakeAgencyRepository agency) async {
                  await tester.pumpWidget(const SizedBox());
                  await _pump(
                    tester,
                    language: language,
                    viewport: viewport,
                    textScale: scale,
                    brightness: brightness,
                    agency: agency,
                  );
                  expect(tester.takeException(), isNull);
                  await tester.ensureVisible(
                    find.byKey(AgencyScreen.hostCardKey),
                  );
                  await tester.pumpAndSettle();
                  expect(tester.takeException(), isNull);
                }

                await page(_canApply());
                final l10n = language == AppLanguage.ar ? _ar : _en;
                expect(find.text(l10n.hostApplyTitle), findsOneWidget);
                if (language == AppLanguage.ar) {
                  expect(
                    Directionality.of(
                      tester.element(find.byKey(AgencyScreen.hostApplyKey)),
                    ),
                    TextDirection.rtl,
                  );
                }
                await tester.tap(find.byKey(AgencyScreen.hostApplyKey));
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                await tester.tap(find.byKey(HostApplyScreen.submitKey));
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                await tester.scrollUntilVisible(
                  find.byKey(HostApplyScreen.acceptKey),
                  200,
                  scrollable: _formList,
                );
                expect(tester.takeException(), isNull);
                await page(
                  FakeAgencyRepository(
                    mine: testMyAgency(openRule: testOpenRule()),
                    hostingState: testHosting(
                      application: testHostingApplication(),
                      refusal: HostingApplyRefusal.pending,
                    ),
                  ),
                );
                await page(
                  FakeAgencyRepository(
                    mine: testMyAgency(openRule: testOpenRule()),
                    hostingState: testHosting(
                      application: testHostingApplication(
                        status: HostingApplicationStatus.rejected,
                        rejectReason: 'صورة الهوية غير واضحة',
                        reapplyAt: economyAt.add(const Duration(days: 29)),
                      ),
                      refusal: HostingApplyRefusal.reapplyCooldown,
                    ),
                  ),
                );
                await page(
                  FakeAgencyRepository(
                    mine: testMyAgency(openRule: testOpenRule()),
                    hostingState: testHosting(
                      host: HostingSource.identity,
                      application: testHostingApplication(
                        status: HostingApplicationStatus.approved,
                      ),
                    ),
                  ),
                );
              });
            },
          );
        }
      }
    }
  });

  group('captures (D209_CAPTURE_DIR)', () {
    testWidgets("the owner's Arabic screens at 393×852 @3x", (tester) async {
      if (_captureDir.isEmpty) return;
      final picture = await _standIn(tester);
      await _at(() async {
        Future<void> shot(
          String name,
          FakeAgencyRepository agency, {
          Brightness brightness = Brightness.light,
        }) async {
          await tester.pumpWidget(const SizedBox());
          await _pump(
            tester,
            language: AppLanguage.ar,
            brightness: brightness,
            picker: _Picker(picture),
            agency: agency,
          );
          await tester.ensureVisible(find.byKey(AgencyScreen.hostCardKey));
          await tester.pumpAndSettle();
          await _capture(tester, name);
        }

        await shot('01-agency-three-paths.ar', _canApply());
        await tester.tap(find.byKey(AgencyScreen.hostApplyKey));
        await tester.pumpAndSettle();
        await _capture(tester, '02-form.ar');
        await tester.scrollUntilVisible(
          find.byKey(HostApplyScreen.selfieKey),
          200,
          scrollable: _formList,
        );
        for (final key in [
          HostApplyScreen.idCardKey,
          HostApplyScreen.selfieKey,
        ]) {
          final preview = find.descendant(
            of: find.byKey(key),
            matching: find.byType(ClipOval),
          );
          await tester.ensureVisible(preview);
          await tester.pumpAndSettle();
          await tester.tap(preview);
          await tester.pumpAndSettle();
        }
        await tester.scrollUntilVisible(
          find.byKey(HostApplyScreen.acceptKey),
          200,
          scrollable: _formList,
        );
        await tester.tap(find.byKey(HostApplyScreen.acceptKey));
        await tester.pumpAndSettle();
        await precacheImages(tester);
        await _capture(tester, '03-form-id-and-rules.ar');
        await shot(
          '04-pending.ar',
          FakeAgencyRepository(
            mine: testMyAgency(openRule: testOpenRule()),
            hostingState: testHosting(
              application: testHostingApplication(),
              refusal: HostingApplyRefusal.pending,
            ),
          ),
        );
        await shot(
          '05-approved.ar',
          FakeAgencyRepository(
            mine: testMyAgency(openRule: testOpenRule()),
            hostingState: testHosting(
              host: HostingSource.identity,
              application: testHostingApplication(
                status: HostingApplicationStatus.approved,
              ),
            ),
          ),
        );
        await shot(
          '06-approved.dark.ar',
          brightness: Brightness.dark,
          FakeAgencyRepository(
            mine: testMyAgency(openRule: testOpenRule()),
            hostingState: testHosting(
              host: HostingSource.identity,
              application: testHostingApplication(
                status: HostingApplicationStatus.approved,
              ),
            ),
          ),
        );
        await shot(
          '07-rejected.ar',
          FakeAgencyRepository(
            mine: testMyAgency(openRule: testOpenRule()),
            hostingState: testHosting(
              application: testHostingApplication(
                status: HostingApplicationStatus.rejected,
                rejectReason: 'صورة الهوية غير واضحة',
                reapplyAt: economyAt.add(const Duration(days: 29)),
              ),
              refusal: HostingApplyRefusal.reapplyCooldown,
            ),
          ),
        );
      });
    });
  });
}
