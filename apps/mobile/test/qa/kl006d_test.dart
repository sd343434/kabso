// KL-006d (A6, QA): independent re-test of the QA-009 / QA-011 fixes and of
// the contract v1.2.3 "Resend code" journey (KL-024m), end to end where
// possible.

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/app_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/locale_sync.dart';
import 'package:kabso_live/features/auth/presentation/register_code_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/auth/presentation/registration_flow.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_overlay.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/live/live_fixtures.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

const _usernameTaken = ServerFailure(
  code: ErrorCode.usernameTaken,
  rawCode: 'USERNAME_TAKEN',
  debugMessage: 'taken',
  statusCode: 409,
);

/// Register succeeds once (202), then answers 409 like the v1.2.3 server
/// does for a username held by a pending registration (any caller).
class _PendingRepo extends FakeAuthRepository {
  @override
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String displayName,
    required Gender gender,
    required String locale,
  }) async {
    registerCalls++;
    registerLocales.add(locale);
    registerGenders.add(gender);
    if (registerCalls > 1) throw _usernameTaken;
  }
}

/// PATCH /me takes 50 ms; the "server" keeps the last value it received.
class _SlowLocaleRepo extends FakeAuthRepository {
  String serverLocale = 'ar';

  @override
  Future<User> updateLocale(String locale) async {
    localeUpdates.add(locale);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    serverLocale = locale;
    return me = me.copyWith(locale: locale);
  }
}

void main() {
  group('QA-011 last language choice wins (strict)', () {
    Future<(ProviderContainer, _SlowLocaleRepo, SharedPreferences)>
    signedIn() async {
      final repo = _SlowLocaleRepo();
      SharedPreferences.setMockInitialValues({
        PreferenceKeys.languageCode: 'ar',
      });
      final sp = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sp),
          deviceLocalesProvider.overrideWithValue(const [Locale('ar')]),
          authRepositoryProvider.overrideWithValue(repo),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        ],
      );
      addTearDown(container.dispose);
      container.read(sessionControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      container
          .read(sessionControllerProvider.notifier)
          .signedIn(testUser().copyWith(locale: 'ar'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return (container, repo, sp);
    }

    Future<void> choose(ProviderContainer c, AppLanguage l) async {
      await c.read(languageControllerProvider.notifier).select(l);
      // Not awaited on purpose: the next choice arrives mid-flight.
      // ignore: unawaited_futures
      c.read(localeSyncProvider).languageChanged();
    }

    test(
      'en → ar during the PATCH: server ends on ar, nothing pending',
      () async {
        final (c, repo, sp) = await signedIn();
        await choose(c, AppLanguage.en);
        await choose(c, AppLanguage.ar);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(repo.serverLocale, 'ar');
        expect(repo.localeUpdates, ['en', 'ar']);
        expect(sp.getBool(PreferenceKeys.localeSyncPending), isNull);
        expect(c.read(currentUserProvider)?.locale, 'ar');
      },
    );

    test('en → ar → en quickly: coalesced, server ends on en', () async {
      final (c, repo, sp) = await signedIn();
      await choose(c, AppLanguage.en);
      await choose(c, AppLanguage.ar);
      await choose(c, AppLanguage.en);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(repo.serverLocale, 'en');
      expect(repo.localeUpdates.last, 'en');
      expect(repo.localeUpdates.length, lessThanOrEqualTo(3));
      expect(sp.getBool(PreferenceKeys.localeSyncPending), isNull);
    });
  });

  group('QA-009 host name readable at real widths', () {
    for (final (width, avatars) in const [
      (360.0, false),
      (393.0, false),
      (430.0, true),
    ]) {
      for (final (language, host) in const [
        (AppLanguage.en, 'Nour Al-Huda Abdulrahman'),
        (AppLanguage.ar, 'نور الهدى عبد الرحمن'),
      ]) {
        testWidgets('${language.name} ${width.toInt()} dp: ≥ 8 characters '
            'of a long host name visible; viewer avatars '
            '${avatars ? 'shown' : 'hidden'}', (tester) async {
          await pumpGolden(
            tester,
            KLiveRoomScaffold(
              header: KHostPill(hostName: host, onFollow: () {}),
              viewers: const KViewerStrip(names: viewerNames, count: 12345),
              onClose: () {},
              chat: KLiveChatOverlay(lines: chatLines(language)),
              actionBar: const KRoomActionBar(),
            ),
            language: language,
            bare: true,
          );
          tester.view.physicalSize =
              Size(width, 852) * GoldenViewport.pixelRatio;
          await tester.pumpAndSettle();

          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(host),
          );
          final eight = TextPainter(
            text: TextSpan(
              text: host.characters.take(8).toString(),
              style: paragraph.text.style,
            ),
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
          )..layout();
          expect(
            paragraph.size.width,
            greaterThanOrEqualTo(eight.width - 0.5),
            reason: 'visible ${paragraph.size.width} < 8 chars ${eight.width}',
          );
          eight.dispose();
          expect(
            find.descendant(
              of: find.byType(KViewerStrip),
              matching: find.byType(KAvatar),
            ),
            avatars ? findsWidgets : findsNothing,
          );
          expect(find.byType(KViewerCountChip), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group(
    'v1.2.3 (KL-024m) user journey: own pending username → Resend code',
    () {
      testWidgets('register → code → change email → 409 → Resend code → code '
          'screen → verify → Home', (tester) async {
        final repo = _PendingRepo();
        SharedPreferences.setMockInitialValues({
          PreferenceKeys.languageCode: 'en',
        });
        final sp = await SharedPreferences.getInstance();
        await tester.pumpWidget(
          ProviderScope(
            retry: (_, _) => null,
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sp),
              authRepositoryProvider.overrideWithValue(repo),
              secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
              usernameDebounceProvider.overrideWithValue(Duration.zero),
            ],
            child: const KabsoApp(),
          ),
        );
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(KabsoApp)),
        );
        container.read(routerProvider).go(AppRoutes.register);
        await tester.pumpAndSettle();
        final l10n = l10nFor(AppLanguage.en);

        Future<void> submit() async {
          await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
          await tester.tap(find.byKey(RegisterScreen.submitKey));
          await tester.pumpAndSettle();
        }

        await tester.enterText(find.byKey(RegisterScreen.emailKey), 'a@b.co');
        await tester.enterText(
          find.byKey(RegisterScreen.usernameKey),
          'layla_22',
        );
        await tester.enterText(find.byKey(RegisterScreen.displayNameKey), 'L');
        await tester.enterText(
          find.byKey(RegisterScreen.passwordKey),
          'pa55word!',
        );
        await chooseGender(tester);
        await tester.pump();
        await submit();
        expect(find.byType(RegisterCodeScreen), findsOneWidget);

        // Back to the form ("Change email") and submit the same data again.
        await tester.tap(find.byKey(RegisterCodeScreen.changeEmailKey));
        await tester.pumpAndSettle();
        expect(find.byType(RegisterScreen), findsOneWidget);
        await submit();
        expect(repo.registerCalls, 2);
        expect(find.byKey(RegisterScreen.usernameReservedKey), findsOneWidget);
        expect(find.text(l10n.registerUsernameReservedHint), findsOneWidget);
        // The neutral hint never confirms that the email has an account.
        expect(
          l10n.registerUsernameReservedHint.toLowerCase(),
          isNot(matches(RegExp('already (registered|exists)|has an account'))),
        );

        await tester.ensureVisible(find.byKey(RegisterScreen.resendCodeKey));
        await tester.tap(find.byKey(RegisterScreen.resendCodeKey));
        await tester.pumpAndSettle();
        expect(repo.resendCalls, 1);
        expect(find.byType(RegisterCodeScreen), findsOneWidget);

        await tester.enterText(
          find.byKey(RegisterCodeScreen.codeFieldKey),
          '48210937',
        );
        await tester.pumpAndSettle();
        expect(repo.verifyCalls, ['48210937']);
        expect(find.byKey(const Key('nav.home')), findsOneWidget);
      });

      testWidgets('editing the username hides the Resend option', (
        tester,
      ) async {
        final repo = _PendingRepo();
        await pumpScreen(
          tester,
          const RegisterScreen(),
          overrides: [
            authRepositoryProvider.overrideWithValue(repo),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
            usernameDebounceProvider.overrideWithValue(Duration.zero),
          ],
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(RegisterScreen)),
        );
        await tester.enterText(find.byKey(RegisterScreen.emailKey), 'a@b.co');
        await tester.enterText(
          find.byKey(RegisterScreen.usernameKey),
          'layla_22',
        );
        await tester.enterText(find.byKey(RegisterScreen.displayNameKey), 'L');
        await tester.enterText(
          find.byKey(RegisterScreen.passwordKey),
          'pa55word!',
        );
        await chooseGender(tester);
        await tester.pump();
        for (var i = 0; i < 2; i++) {
          await tester.ensureVisible(find.byKey(RegisterScreen.submitKey));
          await tester.tap(find.byKey(RegisterScreen.submitKey));
          await tester.pumpAndSettle();
        }
        expect(container.read(registrationFlowProvider), isNotNull);
        expect(find.byKey(RegisterScreen.resendCodeKey), findsOneWidget);
        await tester.enterText(
          find.byKey(RegisterScreen.usernameKey),
          'layla2',
        );
        await tester.pump();
        expect(find.byKey(RegisterScreen.resendCodeKey), findsNothing);
      });
    },
  );
}
