// D198 (owner: Kabso Live is a GLOBAL app — privacy compliance): «تنزيل
// بياناتي» (Settings › Privacy: what the copy holds, the 24-hour rule, the
// password again, «نجهّز بياناتك», the single download) and the blocking but
// polite consent screen after a new version of the terms or the privacy
// policy (summary of changes, the full text, «أوافق وأتابع», and the ways out:
// the data export, the deletion, signing out); the router keeps a person who
// must accept on that screen; sign-up asks for the 18+ statement and the
// acceptance. Arabic RTL and English LTR, 360×800 at text scale 1.3.
//
// Run with `--dart-define=CAP_DIR=<dir>` to also write the owner captures.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/auth_redirect.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/consent_required.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/privacy/consent_screen.dart';
import 'package:kabso_live/features/privacy/data_export_screen.dart';
import 'package:kabso_live/features/privacy/privacy_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_privacy_repository.dart';
import '../../helpers/golden.dart' show loadAppFonts;
import '../../helpers/pump_app.dart';

const _capDir = String.fromEnvironment('CAP_DIR');
const ValueKey<String> _boundary = ValueKey('d198-boundary');

final _user = User(
  id: '0192f1c2-0000-7000-8000-000000000198',
  email: 'sara@example.com',
  emailVerified: true,
  username: 'sara_2026',
  displayName: 'Sara',
  locale: 'ar',
  role: UserRole.user,
  isPrivate: false,
  createdAt: DateTime.utc(2026, 10),
);

final _privacyV2 = LegalDocument(
  kind: LegalKind.privacy,
  version: '2026-12-01',
  effectiveAt: DateTime.utc(2026, 12),
  url: 'https://kabsolive.com/privacy',
  summaryAr:
      'أضفنا حقوقك حسب منطقتك (أوروبا، كاليفورنيا، البرازيل، الخليج) '
      'وميزة «تنزيل بياناتي»، ووضّحنا مدة الاحتفاظ بالبيانات.',
  summaryEn:
      'We added your rights by region (Europe, California, Brazil, the Gulf) '
      'and “Download my data”, and explained how long we keep data.',
);

final _termsV2 = LegalDocument(
  kind: LegalKind.terms,
  version: '2026-12-01',
  effectiveAt: DateTime.utc(2026, 12),
  url: 'https://kabsolive.com/terms',
  summaryAr: 'وضّحنا طريقة حذف الحساب من التطبيق أو بالبريد.',
  summaryEn: 'We explained how to delete your account in the app or by email.',
);

class _SignedIn extends SessionController {
  static int logouts = 0;

  @override
  AuthState build() => Authenticated(_user);

  @override
  Future<void> logout() async {
    logouts++;
    state = const Unauthenticated();
  }
}

ServerFailure _failure(ErrorCode code, int status) => ServerFailure(
  code: code,
  rawCode: code.wire,
  debugMessage: code.wire,
  statusCode: status,
);

Future<List<String>> _pump(
  WidgetTester tester,
  Widget screen, {
  required FakePrivacyRepository repo,
  AppLanguage language = AppLanguage.en,
  Size size = const Size(393, 852),
  double textScale = 1,
  List<Uint8List>? saved,
}) async {
  await loadAppFonts();
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final pushed = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(
        path: '/:rest(.*)',
        builder: (_, state) {
          pushed.add(state.uri.toString());
          return const Scaffold(body: Text('pushed'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  _SignedIn.logouts = 0;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: ProviderScope(
        retry: (_, _) => null,
        overrides: [
          privacyRepositoryProvider.overrideWithValue(repo),
          sessionControllerProvider.overrideWith(_SignedIn.new),
          exportFileSaverProvider.overrideWithValue((bytes, name) async {
            saved?.add(bytes);
            return '/storage/emulated/0/Android/data/com.kabso.kabsolive/files/$name';
          }),
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
          theme: buildAppTheme(
            brightness: Brightness.dark,
            locale: language.locale,
          ),
          builder: (context, app) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(textScale),
            ),
            child: app!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return pushed;
}

/// Writes the screen to CAP_DIR (only when it is defined).
Future<void> _capture(WidgetTester tester, String name) async {
  if (_capDir.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_capDir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

KButton _button(WidgetTester tester, Key key) =>
    tester.widget<KButton>(find.byKey(key));

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  group('«تنزيل بياناتي»', () {
    testWidgets('explains the copy; asks for the password; then «preparing» '
        'and no second request', (tester) async {
      final repo = FakePrivacyRepository();
      await _pump(tester, const DataExportScreen(), repo: repo);
      expect(find.text(en.dataExportIntro), findsOneWidget);
      expect(find.text(en.dataExportRules), findsOneWidget);
      expect(find.text(en.dataExportNoSecrets), findsOneWidget);
      expect(_button(tester, DataExportScreen.requestKey).onPressed, isNotNull);

      await _tap(tester, DataExportScreen.requestKey);
      expect(find.text(en.dataExportPasswordTitle), findsOneWidget);
      expect(
        _button(tester, DataExportScreen.passwordSubmitKey).onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(DataExportScreen.passwordKey),
        'correct horse battery staple',
      );
      await tester.pump();
      await _tap(tester, DataExportScreen.passwordSubmitKey);

      expect(repo.requests, ['correct horse battery staple']);
      expect(find.text(en.dataExportRequested), findsOneWidget);
      expect(find.text(en.dataExportPreparing), findsOneWidget);
      expect(_button(tester, DataExportScreen.requestKey).onPressed, isNull);
    });

    testWidgets('a wrong password is explained', (tester) async {
      final repo = FakePrivacyRepository()
        ..requestFailure = _failure(ErrorCode.reauthFailed, 403);
      await _pump(tester, const DataExportScreen(), repo: repo);
      await _tap(tester, DataExportScreen.requestKey);
      await tester.enterText(find.byKey(DataExportScreen.passwordKey), 'x');
      await tester.pump();
      await _tap(tester, DataExportScreen.passwordSubmitKey);
      expect(find.text(en.errorReauthFailed), findsOneWidget);
    });

    testWidgets('after a download, the next request waits 24 hours', (
      tester,
    ) async {
      final repo = FakePrivacyRepository()
        ..list = DataExportList(
          items: [
            DataExport(
              id: 'e1',
              status: DataExportStatus.downloaded,
              requestedAt: DateTime.utc(2026, 11),
              downloadedAt: DateTime.utc(2026, 11, 1, 10),
            ),
          ],
          nextAllowedAt: DateTime.utc(2026, 11, 2),
        );
      await _pump(tester, const DataExportScreen(), repo: repo);
      expect(find.text(en.dataExportDownloaded('1 Nov 2026')), findsOneWidget);
      expect(find.text(en.dataExportNextAt('2 Nov 2026')), findsOneWidget);
      expect(_button(tester, DataExportScreen.requestKey).onPressed, isNull);
    });

    testWidgets('a ready copy downloads once and is saved', (tester) async {
      final repo = FakePrivacyRepository()
        ..list = DataExportList(
          items: [
            DataExport(
              id: 'e2',
              status: DataExportStatus.ready,
              requestedAt: DateTime.utc(2026, 11),
              expiresAt: DateTime.utc(2026, 11, 8),
              sizeBytes: 48211,
            ),
          ],
          nextAllowedAt: DateTime.utc(2026, 11, 2),
        );
      final saved = <Uint8List>[];
      await _pump(tester, const DataExportScreen(), repo: repo, saved: saved);
      expect(find.text(en.dataExportReady('8 Nov 2026')), findsOneWidget);
      await _tap(tester, DataExportScreen.downloadKey);
      expect(repo.downloads, ['e2']);
      expect(saved.single, [0x50, 0x4b, 0x05, 0x06]);
      expect(find.textContaining('kabso-data-'), findsOneWidget);
    });

    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: 360×800 at text scale 1.3 (captures)', (
        tester,
      ) async {
        final l10n = language == AppLanguage.ar ? ar : en;
        final repo = FakePrivacyRepository()
          ..list = DataExportList(
            items: [
              DataExport(
                id: 'e3',
                status: DataExportStatus.ready,
                requestedAt: DateTime.utc(2026, 11),
                expiresAt: DateTime.utc(2026, 11, 8),
              ),
            ],
          );
        await _pump(
          tester,
          const DataExportScreen(),
          repo: repo,
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(DataExportScreen));
        expect(
          Directionality.of(context),
          language == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(find.text(l10n.dataExportTitle), findsWidgets);
        await _capture(tester, 'app-data-export.${language.name}.360x800.t13');
        await tester.ensureVisible(find.byKey(DataExportScreen.downloadKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _capture(
          tester,
          'app-data-export.${language.name}.360x800.t13.bottom',
        );
      });
    }
  });

  group('consent screen', () {
    testWidgets('shows each new version with its summary; accepting records '
        'it and clears the gate', (tester) async {
      final repo = FakePrivacyRepository(
        documents: [_termsV2, _privacyV2],
        required: [_termsV2, _privacyV2],
      );
      await _pump(tester, const ConsentScreen(), repo: repo);
      expect(find.text(en.consentTitle), findsOneWidget);
      expect(find.text(_privacyV2.summaryEn), findsOneWidget);
      expect(find.text(_termsV2.summaryEn), findsOneWidget);
      expect(find.text(en.consentPrivacyName), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ConsentScreen)),
      );
      container.read(consentRequiredProvider.notifier).value = true;

      await _tap(tester, ConsentScreen.acceptKey);
      expect(repo.accepted, [
        ['TERMS@2026-12-01', 'PRIVACY@2026-12-01'],
      ]);
      expect(container.read(consentRequiredProvider), isFalse);
      expect(find.text(en.consentAccepted), findsOneWidget);
    });

    testWidgets('a newer version while open reloads; the ways out work', (
      tester,
    ) async {
      final repo = FakePrivacyRepository(
        documents: [_privacyV2],
        required: [_privacyV2],
      )..acceptFailure = _failure(ErrorCode.consentVersionMismatch, 409);
      final pushed = await _pump(tester, const ConsentScreen(), repo: repo);
      await _tap(tester, ConsentScreen.acceptKey);
      expect(find.text(en.errorConsentVersionMismatch), findsOneWidget);
      await _tap(tester, ConsentScreen.exportKey);
      expect(pushed, [AppRoutes.dataExport]);
      GoRouter.of(tester.element(find.text('pushed'))).pop();
      await tester.pumpAndSettle();
      await _tap(tester, ConsentScreen.deleteKey);
      expect(pushed.last, AppRoutes.deleteAccount);
      GoRouter.of(tester.element(find.text('pushed'))).pop();
      await tester.pumpAndSettle();
      await _tap(tester, ConsentScreen.logoutKey);
      expect(_SignedIn.logouts, 1);
    });

    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: 360×800 at text scale 1.3 (captures)', (
        tester,
      ) async {
        final l10n = language == AppLanguage.ar ? ar : en;
        final repo = FakePrivacyRepository(
          documents: [_termsV2, _privacyV2],
          required: [_privacyV2],
        );
        await _pump(
          tester,
          const ConsentScreen(),
          repo: repo,
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.consentTitle), findsOneWidget);
        expect(
          find.text(
            language == AppLanguage.ar
                ? _privacyV2.summaryAr
                : _privacyV2.summaryEn,
          ),
          findsOneWidget,
        );
        await _capture(tester, 'app-consent.${language.name}.360x800.t13');
      });
    }
  });

  group('router', () {
    test('a person who must accept stays on the consent screen (only the '
        'export and the deletion are reachable)', () {
      final signedIn = Authenticated(_user);
      expect(
        authRedirect(signedIn, AppRoutes.home, consentRequired: true),
        AppRoutes.legalConsent,
      );
      expect(
        authRedirect(signedIn, AppRoutes.settings, consentRequired: true),
        AppRoutes.legalConsent,
      );
      for (final allowed in AppRoutes.consentAllowedRoutes) {
        expect(authRedirect(signedIn, allowed, consentRequired: true), isNull);
      }
      expect(authRedirect(signedIn, AppRoutes.legalConsent), AppRoutes.home);
      expect(authRedirect(signedIn, AppRoutes.home), isNull);
      expect(
        authRedirect(
          const Unauthenticated(),
          AppRoutes.legalConsent,
          consentRequired: true,
          welcomeSeen: true,
        ),
        AppRoutes.login,
      );
    });
  });
}
