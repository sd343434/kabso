// v1.70-social (D206, CONVENTIONS §10.65): «افتح وكالة» — the button under
// «انضم إلى وكالة», the form with the mandatory ID check (the D185 picture
// tiles), the owner's dashboard with the probation card (time left, X / 3,
// each host's steps, copy / share the invite code), the closed state, the
// notifications and the push route. Arabic RTL and English LTR, 393×852 and
// 360×800 with large text. Fakes only (the real flow is the API's e2e
// `d206-agency-open`). With --dart-define=D206_CAPTURE_DIR=<dir> the owner's
// captures are written (393×852 @3x).

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
import 'package:kabso_live/features/agency/presentation/agency_open_screen.dart';
import 'package:kabso_live/features/agency/presentation/agency_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart'
    show ReelSharer, reelSharerProvider;
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_economy_repositories.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _captureDir = String.fromEnvironment('D206_CAPTURE_DIR');
final AppLocalizations _ar = l10nFor(AppLanguage.ar);
final AppLocalizations _en = l10nFor(AppLanguage.en);
final GlobalKey _boundary = GlobalKey();

/// The form's own list (the agency page stays under it in the stack).
final Finder _formList = find
    .descendant(
      of: find.byType(AgencyOpenScreen),
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

  /// What it returns (the 1×1 PNG by default).
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

class _Sharer implements ReelSharer {
  final shared = <String>[];

  @override
  Future<bool> share(String text, {Rect? origin}) async {
    shared.add(text);
    return true;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeAgencyRepository agency,
  _Picker? picker,
  _Sharer? sharer,
  String location = AppRoutes.agency,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      GoRoute(
        path: AppRoutes.agency,
        builder: (_, _) => const AgencyScreen(),
        routes: [
          GoRoute(
            path: 'open',
            builder: (_, state) => switch (state.extra) {
              final AgencyOpenRule rule => AgencyOpenScreen(
                probationDays: rule.probationDays,
                requiredHosts: rule.requiredHosts,
              ),
              _ => const AgencyOpenScreen(),
            },
          ),
        ],
      ),
    ],
  );
  await loadAppFonts();
  setViewport(tester, viewport);
  final prefs = await testPrefs(language: language.name);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          currentUserProvider.overrideWithValue(testUser()),
          agencyRepositoryProvider.overrideWithValue(agency),
          avatarPhotoPickerProvider.overrideWithValue(picker ?? _Picker()),
          reelSharerProvider.overrideWithValue(sharer ?? _Sharer()),
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

/// The owner's capture (only with D206_CAPTURE_DIR).
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

/// The test's "now" (the fixtures' probation ends 5 d 6 h later).
Future<void> _at(Future<void> Function() body) =>
    withClock(Clock.fixed(economyAt), body);

Future<void> _fillForm(
  WidgetTester tester, {
  String country = 'Saudi Arabia',
}) async {
  await tester.enterText(find.byKey(AgencyOpenScreen.nameKey), 'وكالة النجوم');
  await tester.ensureVisible(find.byKey(AgencyOpenScreen.countryKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(AgencyOpenScreen.countryKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(country).last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(AgencyOpenScreen.contactKey),
    '+966500000000',
  );
  await tester.enterText(find.byKey(AgencyOpenScreen.expectedKey), '25');
  await tester.enterText(
    find.byKey(AgencyOpenScreen.bioKey),
    'نبحث عن مضيفين موهوبين',
  );
  // The round preview at the top of each tile (its centre may sit under the
  // sticky submit bar).
  for (final key in [AgencyOpenScreen.idCardKey, AgencyOpenScreen.selfieKey]) {
    final preview = find.descendant(
      of: find.byKey(key),
      matching: find.byType(ClipOval),
    );
    await tester.ensureVisible(preview);
    await tester.pumpAndSettle();
    await tester.tap(preview);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('«افتح وكالة» under «انضم إلى وكالة»', () {
    testWidgets('in no agency: join stays, «Open an agency» is under it, '
        'free, with the 7-day rule', (tester) async {
      final agency = FakeAgencyRepository(
        mine: testMyAgency(openRule: testOpenRule()),
      );
      await _pump(tester, agency: agency);
      final join = tester.getTopLeft(find.text(_en.agencyJoinTitle));
      final open = tester.getTopLeft(find.byKey(AgencyScreen.openKey));
      expect(open.dy, greaterThan(join.dy));
      expect(find.text(_en.agencyOpenButton), findsOneWidget);
      expect(find.text(_en.agencyOpenButtonHint), findsOneWidget);
      expect(
        find.text(
          _en.agencyProbationRuleShort(
            _en.agencyHostsCount(3),
            _en.agencyDaysCount(7),
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<KButton>(find.byKey(AgencyScreen.openKey)).onPressed,
        isNotNull,
      );
    });

    testWidgets('an older server (no openRule): no open button', (
      tester,
    ) async {
      await _pump(tester, agency: FakeAgencyRepository());
      expect(find.text(_en.agencyJoinTitle), findsOneWidget);
      expect(find.byKey(AgencyScreen.openKey), findsNothing);
    });

    testWidgets('the form: the rule first, required fields and pictures, '
        'then the draft goes up and the page becomes the dashboard', (
      tester,
    ) async {
      await _at(() async {
        final agency = FakeAgencyRepository(
          mine: testMyAgency(openRule: testOpenRule()),
        );
        final picker = _Picker();
        await _pump(tester, agency: agency, picker: picker);
        await tester.ensureVisible(find.byKey(AgencyScreen.openKey));
        await tester.tap(find.byKey(AgencyScreen.openKey));
        await tester.pumpAndSettle();
        expect(find.byType(AgencyOpenScreen), findsOneWidget);
        expect(find.text(_en.agencyOpenFree), findsOneWidget);
        expect(
          find.text(
            _en.agencyOpenRule(_en.agencyDaysCount(7), _en.agencyHostsCount(3)),
          ),
          findsOneWidget,
        );
        // Nothing filled in: every message, nothing sent.
        await tester.tap(find.byKey(AgencyOpenScreen.submitKey));
        await tester.pumpAndSettle();
        expect(find.text(_en.agencyOpenNameError), findsOneWidget);
        expect(find.text(_en.agencyOpenCountryError), findsOneWidget);
        expect(find.text(_en.agencyOpenContactError), findsOneWidget);
        expect(find.text(_en.agencyOpenExpectedError), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(_en.agencyOpenIdMissing),
          100,
          scrollable: _formList,
        );
        expect(find.text(_en.agencyOpenIdMissing), findsOneWidget);
        expect(agency.opened, isEmpty);

        await tester.scrollUntilVisible(
          find.byKey(AgencyOpenScreen.nameKey),
          -100,
          scrollable: _formList,
        );
        await _fillForm(tester);
        expect(picker.asked, [AvatarSource.library, AvatarSource.camera]);
        await tester.tap(find.byKey(AgencyOpenScreen.submitKey));
        await tester.pumpAndSettle();
        expect(agency.opened, hasLength(1));
        final d = agency.opened.single;
        expect(d.name, 'وكالة النجوم');
        expect(d.country, 'SA');
        expect(d.contactType, AgencyContactType.whatsapp);
        expect(d.contactValue, '+966500000000');
        expect(d.expectedHosts, 25);
        expect(d.bio, 'نبحث عن مضيفين موهوبين');
        expect(d.idCard, _png);
        expect(d.selfie, _png);
        expect(d.idCardType, 'image/png');
        expect(d.idempotencyKey, isNotEmpty);
        // Back on «الوكالة»: the owner's dashboard with the probation on top.
        expect(find.byType(AgencyOpenScreen), findsNothing);
        expect(find.text(_en.agencyOpenDone), findsOneWidget);
        expect(find.byKey(AgencyScreen.probationKey), findsOneWidget);
        expect(
          find.text(
            _en.agencyProbationActivated(
              KFormat.bidiIsolate('0'),
              KFormat.bidiIsolate('3'),
            ),
          ),
          findsOneWidget,
        );
        expect(find.text(_en.agencyProbationNoHosts), findsOneWidget);
        expect(find.text('وكالة النجوم'), findsOneWidget);
        expect(
          tester.getTopLeft(find.byKey(AgencyScreen.probationKey)).dy,
          lessThan(tester.getTopLeft(find.byKey(AgencyScreen.inviteKey)).dy),
        );
      });
    });

    testWidgets('a refusal from the server is said in its words', (
      tester,
    ) async {
      final agency = FakeAgencyRepository(
        mine: testMyAgency(openRule: testOpenRule()),
        openFailure: const ServerFailure(
          code: ErrorCode.agencyOpenNotAllowed,
          rawCode: 'AGENCY_OPEN_NOT_ALLOWED',
          debugMessage: 'no',
          statusCode: 409,
          details: [FieldIssue(field: 'agency', issue: 'HOST_OF_AGENCY')],
        ),
      );
      await _pump(tester, agency: agency, location: AppRoutes.agencyOpen);
      await _fillForm(tester);
      await tester.tap(find.byKey(AgencyOpenScreen.submitKey));
      await tester.pumpAndSettle();
      expect(find.byKey(AgencyOpenScreen.errorKey), findsOneWidget);
      expect(find.text(_en.agencyOpenIsHost), findsOneWidget);
      expect(find.byType(AgencyOpenScreen), findsOneWidget);
      // A retry of the same form reuses the key; a change makes a new one.
      await tester.tap(find.byKey(AgencyOpenScreen.submitKey));
      await tester.pumpAndSettle();
      expect(agency.opened[1].idempotencyKey, agency.opened[0].idempotencyKey);
      await tester.enterText(find.byKey(AgencyOpenScreen.expectedKey), '30');
      await tester.tap(find.byKey(AgencyOpenScreen.submitKey));
      await tester.pumpAndSettle();
      expect(
        agency.opened[2].idempotencyKey,
        isNot(agency.opened[0].idempotencyKey),
      );
    });
  });

  group('the probation card', () {
    testWidgets("time left, X / 3, each host's steps, copy and share", (
      tester,
    ) async {
      await _at(() async {
        final sharer = _Sharer();
        await _pump(
          tester,
          sharer: sharer,
          agency: FakeAgencyRepository(
            mine: testMyAgency(
              own: testOwnAgency(
                rank: AgencyRank.newAgency,
                name: 'وكالة النجوم',
                probation: testProbation(),
              ),
              openRule: testOpenRule(refusal: AgencyOpenRefusal.ownsAgency),
            ),
          ),
        );
        expect(
          find.text(
            _en.agencyProbationLeft(
              _en.agencyDaysCount(5),
              _en.agencyHoursCount(6),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            _en.agencyProbationActivated(
              KFormat.bidiIsolate('1'),
              KFormat.bidiIsolate('3'),
            ),
          ),
          findsOneWidget,
        );
        final sara = find.byKey(
          AgencyScreen.probationHostKey(testProbationHost1.id),
        );
        final lina = find.byKey(
          AgencyScreen.probationHostKey(testProbationHost2.id),
        );
        expect(sara, findsOneWidget);
        expect(lina, findsOneWidget);
        expect(
          find.descendant(
            of: sara,
            matching: find.byIcon(Icons.verified_rounded),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: lina,
            matching: find.byIcon(Icons.remove_rounded),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: lina, matching: find.byIcon(Icons.check_rounded)),
          findsNWidgets(2),
        );
        // No open button on the owner's page.
        expect(find.byKey(AgencyScreen.openKey), findsNothing);

        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied =
                  (call.arguments as Map<Object?, Object?>)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.tap(find.byKey(AgencyScreen.probationCopyKey));
        await tester.pump();
        expect(copied, 'KAB5Q7XZ');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(AgencyScreen.probationShareKey));
        await tester.pump();
        expect(sharer.shared, [_en.agencyShareText('KAB5Q7XZ')]);
      });
    });

    testWidgets('the last hours, then «checking now» once the time is up', (
      tester,
    ) async {
      await _at(() async {
        await _pump(
          tester,
          agency: FakeAgencyRepository(
            mine: testMyAgency(
              own: testOwnAgency(
                probation: testProbation(left: const Duration(hours: 5)),
              ),
            ),
          ),
        );
        expect(
          find.text(_en.agencyProbationLeftHours(_en.agencyHoursCount(5))),
          findsOneWidget,
        );
      });
      await _at(() async {
        await _pump(
          tester,
          agency: FakeAgencyRepository(
            mine: testMyAgency(
              own: testOwnAgency(
                probation: testProbation(left: const Duration(minutes: -5)),
              ),
            ),
          ),
        );
        expect(find.text(_en.agencyProbationEnding), findsOneWidget);
      });
    });

    testWidgets('a passed probation: a success note, no card', (tester) async {
      await _at(() async {
        await _pump(
          tester,
          agency: FakeAgencyRepository(
            mine: testMyAgency(
              own: testOwnAgency(
                probation: AgencyProbation(
                  running: false,
                  endsAt: economyAt.add(const Duration(days: 2)),
                  passedAt: economyAt.subtract(const Duration(days: 1)),
                  days: 7,
                  requiredHosts: 3,
                  activatedHosts: 3,
                  hosts: const [],
                ),
              ),
            ),
          ),
        );
        expect(find.byKey(AgencyScreen.probationKey), findsNothing);
        expect(find.text(_en.agencyProbationPassed), findsOneWidget);
      });
    });
  });

  group('closed', () {
    testWidgets('«The agency was closed» with the reason, the count, the date '
        'and when to reopen; the open button waits', (tester) async {
      await _at(() async {
        await _pump(
          tester,
          agency: FakeAgencyRepository(
            mine: testMyAgency(
              closed: testClosedAgency(),
              openRule: testOpenRule(refusal: AgencyOpenRefusal.reopenCooldown),
            ),
          ),
        );
        expect(find.byKey(AgencyScreen.closedKey), findsOneWidget);
        expect(find.text(_en.agencyClosedTitle), findsOneWidget);
        expect(
          find.text(
            _en.agencyClosedProbation(
              _en.agencyHostsCount(3),
              KFormat.bidiIsolate('2'),
            ),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Closed on: '), findsOneWidget);
        expect(
          find.textContaining('You can open a new agency from'),
          findsOneWidget,
        );
        // Join stays; open is shown but disabled until the date.
        expect(find.text(_en.agencyJoinTitle), findsOneWidget);
        expect(
          tester.widget<KButton>(find.byKey(AgencyScreen.openKey)).onPressed,
          isNull,
        );
      });
    });

    testWidgets('after the cooldown: «you can open a new agency now»', (
      tester,
    ) async {
      await _at(() async {
        await _pump(
          tester,
          agency: FakeAgencyRepository(
            mine: testMyAgency(
              closed: testClosedAgency(reopenable: true),
              openRule: testOpenRule(),
            ),
          ),
        );
        expect(find.text(_en.agencyReopenNow), findsOneWidget);
        expect(
          tester.widget<KButton>(find.byKey(AgencyScreen.openKey)).onPressed,
          isNotNull,
        );
      });
    });
  });

  group('notifications and push', () {
    AppNotification note(String type, [Map<String, dynamic>? target]) =>
        AppNotification.fromJson({
          'id': 'n1',
          'type': type,
          'actors': const <Object>[],
          'actorCount': 0,
          'target': target,
          'createdAt': economyAt.toIso8601String(),
          'read': false,
        });

    test('the five types and the AGENCY target are read', () {
      for (final type in [
        'AGENCY_OPENED',
        'AGENCY_PROBATION_REMINDER',
        'AGENCY_PROBATION_PASSED',
        'AGENCY_CLOSED',
        'AGENCY_HOST_RELEASED',
      ]) {
        final n = note(type, {
          'type': 'AGENCY',
          'id': 'a1',
          'postId': null,
          'thumbUrl': null,
          'text': 'وكالة',
          'activatedHosts': 2,
          'requiredHosts': 3,
        });
        expect(n.type.isAgency, isTrue, reason: type);
        expect(n.type.isSystem, isTrue, reason: type);
        expect(n.target?.type, NotificationTargetType.agency);
        expect(n.target?.activatedHosts, 2);
        expect(n.target?.requiredHosts, 3);
      }
    });

    test('a push of any agency type opens «الوكالة»', () {
      for (final type in ['AGENCY_CLOSED', 'AGENCY_HOST_RELEASED']) {
        final payload = PushPayload({
          'kind': 'notification',
          'type': type,
          'targetType': 'AGENCY',
          'targetId': 'a1',
        });
        expect(payload.route(), AppRoutes.agency, reason: type);
      }
    });

    test('the Arabic copy keeps the owner sentence and the rules', () {
      expect(
        _ar.notifAgencyClosedProbation(_ar.agencyHostsCount(3), '2'),
        'أُغلقت وكالتك لأنها لم تفعّل 3 مضيفين (بثّ واستلام هدايا) خلال '
        'فترة التجربة. المفعّلون: 2',
      );
      expect(_ar.agencyDaysCount(7), '7 أيام');
      expect(_ar.agencyDaysCount(1), 'يوم واحد');
      expect(_ar.agencyHostsCount(3), '3 مضيفين');
      expect(_ar.agencyHoursCount(11), '11 ساعة');
      expect(_en.agencyDaysCount(7), '7 days');
      expect(_ar.agencyOpenPrivacy, contains('Kabso Live'));
    });
  });

  group('Arabic RTL, English LTR, 360×800, large text, dark', () {
    for (final language in AppLanguage.values) {
      for (final viewport in GoldenViewport.values) {
        testWidgets('no overflow: ${language.name} ${viewport.name} ×1.3', (
          tester,
        ) async {
          await _at(() async {
            final scale = viewport == GoldenViewport.android ? 1.3 : 1.0;
            await _pump(
              tester,
              language: language,
              viewport: viewport,
              textScale: scale,
              agency: FakeAgencyRepository(
                mine: testMyAgency(openRule: testOpenRule()),
              ),
            );
            expect(tester.takeException(), isNull);
            final l10n = language == AppLanguage.ar ? _ar : _en;
            expect(find.text(l10n.agencyOpenButton), findsOneWidget);
            if (language == AppLanguage.ar) {
              // RTL: the join card's text starts at the right.
              expect(
                Directionality.of(
                  tester.element(find.byKey(AgencyScreen.openKey)),
                ),
                TextDirection.rtl,
              );
            }
            await tester.ensureVisible(find.byKey(AgencyScreen.openKey));
            await tester.tap(find.byKey(AgencyScreen.openKey));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await _pump(
              tester,
              language: language,
              viewport: viewport,
              textScale: scale,
              brightness: Brightness.dark,
              agency: FakeAgencyRepository(
                mine: testMyAgency(
                  own: testOwnAgency(
                    rank: AgencyRank.newAgency,
                    name: 'وكالة النجوم',
                    probation: testProbation(),
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull);
            expect(find.byKey(AgencyScreen.probationKey), findsOneWidget);
            await tester.pumpWidget(const SizedBox());
            await _pump(
              tester,
              language: language,
              viewport: viewport,
              textScale: scale,
              agency: FakeAgencyRepository(
                mine: testMyAgency(
                  closed: testClosedAgency(),
                  openRule: testOpenRule(
                    refusal: AgencyOpenRefusal.reopenCooldown,
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull);
          });
        });
      }
    }
  });

  group('captures (D206_CAPTURE_DIR)', () {
    testWidgets("the owner's Arabic screens at 393×852 @3x", (tester) async {
      if (_captureDir.isEmpty) return;
      final picture = await _standIn(tester);
      await _at(() async {
        await _pump(
          tester,
          language: AppLanguage.ar,
          picker: _Picker(picture),
          agency: FakeAgencyRepository(
            mine: testMyAgency(openRule: testOpenRule()),
          ),
        );
        await tester.ensureVisible(find.byKey(AgencyScreen.openKey));
        await tester.pumpAndSettle();
        await _capture(tester, '01-agency-join-and-open.ar');
        await tester.tap(find.byKey(AgencyScreen.openKey));
        await tester.pumpAndSettle();
        await _capture(tester, '02-open-form.ar');
        await _fillForm(tester, country: 'السعودية');
        await tester.scrollUntilVisible(
          find.byKey(AgencyOpenScreen.selfieKey),
          200,
          scrollable: _formList,
        );
        await precacheImages(tester);
        await _capture(tester, '03-open-form-id-check.ar');
        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          language: AppLanguage.ar,
          agency: FakeAgencyRepository(
            mine: testMyAgency(
              own: testOwnAgency(
                rank: AgencyRank.newAgency,
                name: 'وكالة النجوم',
                probation: testProbation(),
              ),
            ),
          ),
        );
        await _capture(tester, '04-dashboard-probation.ar');
        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          language: AppLanguage.ar,
          brightness: Brightness.dark,
          agency: FakeAgencyRepository(
            mine: testMyAgency(
              own: testOwnAgency(
                rank: AgencyRank.newAgency,
                name: 'وكالة النجوم',
                probation: testProbation(),
              ),
            ),
          ),
        );
        await _capture(tester, '05-dashboard-probation.dark.ar');
        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          language: AppLanguage.ar,
          agency: FakeAgencyRepository(
            mine: testMyAgency(
              closed: testClosedAgency(),
              openRule: testOpenRule(refusal: AgencyOpenRefusal.reopenCooldown),
            ),
          ),
        );
        await _capture(tester, '06-closed.ar');
      });
    });
  });
}
