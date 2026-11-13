// D208 (owner 2026-10-31, contract v1.72-social): what the app needs of the
// team's account controls — a locked account's sign-in says until when and
// why; a restriction says what is switched off and until when; a password the
// team reset opens «كلمة مرور جديدة» and signs in with the new one. Arabic RTL
// and English LTR, 360×800 at text scale 1.3.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/auth/presentation/password_change_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/splash_intro.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

final _user = User(
  id: '0192f1c2-0000-7000-8000-000000000208',
  email: 'sara@example.com',
  emailVerified: true,
  username: 'sara_2026',
  displayName: 'Sara',
  locale: 'ar',
  role: UserRole.user,
  isPrivate: false,
  createdAt: DateTime.utc(2026, 10),
);

final _until = DateTime.utc(2026, 11, 7, 9, 30);

ServerFailure _failure(ErrorCode code, {List<FieldIssue> details = const []}) =>
    ServerFailure(
      code: code,
      rawCode: code.wire,
      debugMessage: code.wire,
      statusCode: 403,
      details: details,
    );

class _Pending extends PendingPasswordChangeController {
  @override
  PendingPasswordChange? build() => const PendingPasswordChange(
    identifier: 'sara@example.com',
    password: 'temporary password',
  );
}

class _SignedOut extends SessionController {
  static User? signedInAs;

  @override
  AuthState build() => const Unauthenticated();

  @override
  void signedIn(User user) {
    signedInAs = user;
    state = Authenticated(user);
  }
}

class _IntroDone extends SplashIntro {
  @override
  bool build() => true;
}

Future<List<(String, String, String)>> _pumpChange(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  Size size = const Size(393, 852),
  double textScale = 1,
  AppFailure? failure,
}) async {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final calls = <(String, String, String)>[];
  _SignedOut.signedInAs = null;
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const PasswordChangeScreen()),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        pendingPasswordChangeProvider.overrideWith(_Pending.new),
        sessionControllerProvider.overrideWith(_SignedOut.new),
        changePasswordAtSignInProvider.overrideWithValue(({
          required identifier,
          required password,
          required newPassword,
        }) async {
          calls.add((identifier, password, newPassword));
          if (failure != null) throw failure;
          return _user;
        }),
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
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: app!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(PasswordChangeScreen.submitKey));
  await tester.tap(find.byKey(PasswordChangeScreen.submitKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUpAll(initializeDateFormatting);
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);
  String when(AppLocalizations l, DateTime at) =>
      '${KFormat.date(at, l.localeName)} ${KFormat.time(at, l.localeName)}';

  test('a lock says until when and why; a restriction says what and until '
      'when (ar and en)', () {
    final locked = _failure(
      ErrorCode.accountLocked,
      details: [
        FieldIssue(field: 'lockedUntil', issue: _until.toIso8601String()),
        const FieldIssue(field: 'reason', issue: 'مراجعة بلاغات'),
      ],
    );
    expect(
      failureMessage(ar, locked),
      ar.errorAccountLockedUntil(when(ar, _until.toLocal()), 'مراجعة بلاغات'),
    );
    expect(failureMessage(en, locked), contains('Reason: مراجعة بلاغات'));
    for (final (kind, what) in [
      ('CHAT_MUTE', en.restrictionChatMute),
      ('NO_LIVE', en.restrictionNoLive),
      ('NO_GIFTS', en.restrictionNoGifts),
      ('NO_POSTING', en.restrictionNoPosting),
    ]) {
      final f = _failure(
        ErrorCode.accountRestricted,
        details: [
          FieldIssue(field: 'restriction', issue: kind),
          FieldIssue(field: 'until', issue: _until.toIso8601String()),
        ],
      );
      expect(
        failureMessage(en, f),
        en.errorAccountRestrictedUntil(what, when(en, _until.toLocal())),
      );
    }
    // Without details (an older server): the plain sentence.
    expect(
      failureMessage(ar, _failure(ErrorCode.accountLocked)),
      ar.errorAccountLocked,
    );
    expect(
      failureMessage(en, _failure(ErrorCode.accountRestricted)),
      en.errorAccountRestricted,
    );
    expect(
      ErrorCode.fromWire('PASSWORD_CHANGE_REQUIRED'),
      ErrorCode.passwordChangeRequired,
    );
  });

  testWidgets('«كلمة مرور جديدة»: too short, the same, not matching, then '
      'signs in with the new password', (tester) async {
    final calls = await _pumpChange(tester, language: AppLanguage.ar);
    expect(find.text(ar.passwordChangeBody), findsOneWidget);
    await tester.enterText(find.byKey(PasswordChangeScreen.newKey), 'short');
    await _submit(tester);
    expect(find.text(ar.passwordChangeTooShort), findsOneWidget);
    await tester.enterText(
      find.byKey(PasswordChangeScreen.newKey),
      'temporary password',
    );
    await _submit(tester);
    expect(find.text(ar.passwordChangeSame), findsOneWidget);
    await tester.enterText(
      find.byKey(PasswordChangeScreen.newKey),
      'my own new pass 2026',
    );
    await tester.enterText(
      find.byKey(PasswordChangeScreen.confirmKey),
      'my own new pass 2025',
    );
    await _submit(tester);
    expect(find.text(ar.passwordChangeMismatch), findsOneWidget);
    expect(calls, isEmpty);
    await tester.enterText(
      find.byKey(PasswordChangeScreen.confirmKey),
      'my own new pass 2026',
    );
    await _submit(tester);
    expect(calls, [
      ('sara@example.com', 'temporary password', 'my own new pass 2026'),
    ]);
    expect(_SignedOut.signedInAs, _user);
  });

  testWidgets('a lock reached on the new-password screen shows its end', (
    tester,
  ) async {
    await _pumpChange(
      tester,
      failure: _failure(
        ErrorCode.accountLocked,
        details: [
          FieldIssue(field: 'lockedUntil', issue: _until.toIso8601String()),
          const FieldIssue(field: 'reason', issue: 'spam'),
        ],
      ),
    );
    await tester.enterText(
      find.byKey(PasswordChangeScreen.newKey),
      'my own new pass 2026',
    );
    await tester.enterText(
      find.byKey(PasswordChangeScreen.confirmKey),
      'my own new pass 2026',
    );
    await _submit(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text(en.errorAccountLockedUntil(when(en, _until.toLocal()), 'spam')),
      findsOneWidget,
    );
    expect(_SignedOut.signedInAs, isNull);
  });

  Future<void> signIn(WidgetTester tester, AppFailure failure) async {
    final auth = FakeAuthRepository()..loginFailure = failure;
    await pumpKabsoApp(
      tester,
      prefs: const {PreferenceKeys.welcomeSeen: true},
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        splashIntroProvider.overrideWith(_IntroDone.new),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.enterText(
      find.byKey(LoginScreen.identifierKey),
      'sara@example.com',
    );
    await tester.enterText(
      find.byKey(LoginScreen.passwordKey),
      'temporary password',
    );
    await tester.ensureVisible(find.byKey(LoginScreen.submitKey));
    await tester.tap(find.byKey(LoginScreen.submitKey));
    await tester.pumpAndSettle();
  }

  testWidgets('login: a password the team reset opens «كلمة مرور جديدة»', (
    tester,
  ) async {
    await signIn(tester, _failure(ErrorCode.passwordChangeRequired));
    expect(find.byType(PasswordChangeScreen), findsOneWidget);
  });

  testWidgets('login: a locked account shows the end and the reason', (
    tester,
  ) async {
    await signIn(
      tester,
      _failure(
        ErrorCode.accountLocked,
        details: [
          FieldIssue(field: 'lockedUntil', issue: _until.toIso8601String()),
          const FieldIssue(field: 'reason', issue: 'spam reports'),
        ],
      ),
    );
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('spam reports'), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('360×800 at text scale 1.3, ${language.name}: the new-password '
        'screen fits', (tester) async {
      await _pumpChange(
        tester,
        language: language,
        size: const Size(360, 800),
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(
        Directionality.of(tester.element(find.byType(PasswordChangeScreen))),
        language == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr,
      );
    });
  }
}
