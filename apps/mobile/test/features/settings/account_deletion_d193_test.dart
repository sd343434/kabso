// D193 (owner 2026-10-31): the in-app account deletion «حذف الحساب» that
// Apple 5.1.1(v) and Google Play require — an explanation (what is deleted,
// lost and kept, the 30-day grace period, what must be settled first), the
// password again, the confirmation word, then the request (the app signs out
// locally); signing in during the grace period shows «طلب حذف قيد التنفيذ —
// إلغاء الحذف؟» and cancelling signs in again. Arabic RTL and English LTR,
// light and dark, 360×800 at text scale 1.3.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
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
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/splash_intro.dart';
import 'package:kabso_live/features/settings/account_deletion/account_deletion_repository.dart';
import 'package:kabso_live/features/settings/account_deletion/account_deletion_screen.dart';
import 'package:kabso_live/features/settings/account_deletion/deletion_pending_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

final _user = User(
  id: '0192f1c2-0000-7000-8000-000000000193',
  email: 'sara@example.com',
  emailVerified: true,
  username: 'sara_2026',
  displayName: 'Sara',
  locale: 'ar',
  role: UserRole.user,
  isPrivate: false,
  createdAt: DateTime.utc(2026, 10),
);

final _purgeAfter = DateTime.utc(2026, 11, 30, 10);

class FakeAccountDeletionRepository implements AccountDeletionRepository {
  new({this.blockers = const []});

  List<DeletionBlocker> blockers;
  AppFailure? requestFailure;
  AppFailure? cancelFailure;
  final List<(String, String)> requests = [];
  final List<(String, String)> cancels = [];

  @override
  Future<AccountDeletionInfo> info() async => AccountDeletionInfo(
    graceDays: 30,
    blockers: blockers,
    supportEmail: 'info@kabsolive.com',
  );

  @override
  Future<AccountDeletionRequest> request({
    required String password,
    required String confirmation,
  }) async {
    requests.add((password, confirmation));
    final failure = requestFailure;
    if (failure != null) throw failure;
    return AccountDeletionRequest(
      requestedAt: DateTime.utc(2026, 10, 31, 10),
      purgeAfter: _purgeAfter,
    );
  }

  @override
  Future<User> cancelAndSignIn({
    required String identifier,
    required String password,
  }) async {
    cancels.add((identifier, password));
    final failure = cancelFailure;
    if (failure != null) throw failure;
    return _user;
  }
}

/// Signed in; records the local sign-out after the request.
class _SignedIn extends SessionController {
  static int deletions = 0;
  static User? signedInAs;

  @override
  AuthState build() => Authenticated(_user);

  @override
  Future<void> deletionRequested() async {
    deletions++;
    state = const Unauthenticated(reason: ErrorCode.accountDeletionPending);
  }

  @override
  void signedIn(User user) {
    signedInAs = user;
    state = Authenticated(user);
  }
}

ServerFailure _failure(ErrorCode code, {List<FieldIssue> details = const []}) =>
    ServerFailure(
      code: code,
      rawCode: code.wire,
      debugMessage: code.wire,
      statusCode: code == ErrorCode.reauthFailed ? 403 : 409,
      details: details,
    );

/// Pumps [screen] at [size] in [language] / [brightness] with [textScale],
/// under a router whose other routes record where the screen went.
Future<List<String>> _pump(
  WidgetTester tester,
  Widget screen, {
  required FakeAccountDeletionRepository repo,
  AppLanguage language = AppLanguage.en,
  Brightness brightness = Brightness.dark,
  Size size = const Size(393, 852),
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
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
  _SignedIn.deletions = 0;
  _SignedIn.signedInAs = null;
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        accountDeletionRepositoryProvider.overrideWithValue(repo),
        sessionControllerProvider.overrideWith(_SignedIn.new),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(brightness: brightness, locale: language.locale),
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
  return pushed;
}

KButton _button(WidgetTester tester, Key key) =>
    tester.widget<KButton>(find.byKey(key));

Future<void> _tap(WidgetTester tester, Key key, {bool settle = true}) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // The spinner stays until the router leaves the screen (signed out / in).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Overrides the pending-deletion sign-in (what login stores on the 409).
class _Pending extends PendingDeletionSignInController {
  @override
  PendingDeletionSignIn? build() => PendingDeletionSignIn(
    identifier: 'sara@example.com',
    password: 'correct horse battery staple',
    purgeAfter: _purgeAfter,
  );
}

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  testWidgets('step 1 explains what is deleted, lost and kept and the grace '
      'period', (tester) async {
    final repo = FakeAccountDeletionRepository();
    await _pump(tester, const AccountDeletionScreen(), repo: repo);
    expect(find.text(en.deleteAccountStep(1, 3)), findsOneWidget);
    expect(find.text(en.deleteAccountIntroTitle), findsOneWidget);
    expect(find.text(en.deleteAccountWhatGoes), findsOneWidget);
    expect(find.text(en.deleteAccountForfeitBody), findsOneWidget);
    expect(find.text(en.deleteAccountKeptBody), findsOneWidget);
    expect(find.text(en.deleteAccountGrace(30)), findsOneWidget);
    expect(find.byKey(AccountDeletionScreen.blockersKey), findsNothing);
    expect(
      _button(tester, AccountDeletionScreen.continueKey).onPressed,
      isNotNull,
    );
  });

  testWidgets('blockers are listed with what to do and stop the flow', (
    tester,
  ) async {
    final repo = FakeAccountDeletionRepository(
      blockers: [DeletionBlocker.hostAgency, DeletionBlocker.pendingWithdrawal],
    );
    await _pump(tester, const AccountDeletionScreen(), repo: repo);
    expect(find.byKey(AccountDeletionScreen.blockersKey), findsOneWidget);
    expect(find.text(en.deleteAccountBlockerHostAgency), findsOneWidget);
    expect(find.text(en.deleteAccountBlockerPendingWithdrawal), findsOneWidget);
    expect(
      _button(tester, AccountDeletionScreen.continueKey).onPressed,
      isNull,
    );
    expect(DeletionBlocker.fromWire('something_new'), DeletionBlocker.other);
  });

  testWidgets('password, then the confirmation word, then the request; the '
      'app signs out locally', (tester) async {
    final repo = FakeAccountDeletionRepository();
    await _pump(tester, const AccountDeletionScreen(), repo: repo);
    await _tap(tester, AccountDeletionScreen.continueKey);

    expect(find.text(en.deleteAccountStep(2, 3)), findsOneWidget);
    expect(find.text(en.deleteAccountPasswordTitle), findsOneWidget);
    expect(
      _button(tester, AccountDeletionScreen.continueKey).onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(AccountDeletionScreen.passwordKey),
      'correct horse battery staple',
    );
    await tester.pump();
    await _tap(tester, AccountDeletionScreen.continueKey);

    expect(find.text(en.deleteAccountStep(3, 3)), findsOneWidget);
    expect(find.text(en.deleteAccountConfirmBody('DELETE')), findsOneWidget);
    expect(_button(tester, AccountDeletionScreen.submitKey).onPressed, isNull);
    await tester.enterText(find.byKey(AccountDeletionScreen.confirmKey), 'yes');
    await tester.pump();
    expect(find.text(en.deleteAccountConfirmMismatch), findsOneWidget);
    expect(_button(tester, AccountDeletionScreen.submitKey).onPressed, isNull);
    await tester.enterText(
      find.byKey(AccountDeletionScreen.confirmKey),
      ' delete ',
    );
    await tester.pump();
    expect(find.text(en.deleteAccountConfirmMismatch), findsNothing);
    await _tap(tester, AccountDeletionScreen.submitKey, settle: false);

    expect(repo.requests, [('correct horse battery staple', 'delete')]);
    expect(_SignedIn.deletions, 1);
  });

  testWidgets('a wrong password returns to step 2 with the message; a new '
      'blocker returns to step 1', (tester) async {
    final repo = FakeAccountDeletionRepository()
      ..requestFailure = _failure(ErrorCode.reauthFailed);
    await _pump(
      tester,
      const AccountDeletionScreen(initialStep: 1),
      repo: repo,
    );
    await tester.enterText(find.byKey(AccountDeletionScreen.passwordKey), 'x');
    await tester.pump();
    await _tap(tester, AccountDeletionScreen.continueKey);
    await tester.enterText(
      find.byKey(AccountDeletionScreen.confirmKey),
      'DELETE',
    );
    await tester.pump();
    await _tap(tester, AccountDeletionScreen.submitKey);
    expect(find.text(en.deleteAccountStep(2, 3)), findsOneWidget);
    expect(find.text(en.errorReauthFailed), findsOneWidget);
    expect(_SignedIn.deletions, 0);

    repo
      ..requestFailure = _failure(ErrorCode.accountDeletionBlocked)
      ..blockers = [DeletionBlocker.negativeBalance];
    await _tap(tester, AccountDeletionScreen.continueKey);
    await _tap(tester, AccountDeletionScreen.submitKey);
    expect(find.text(en.deleteAccountStep(1, 3)), findsOneWidget);
    expect(find.text(en.deleteAccountBlockerNegativeBalance), findsOneWidget);
  });

  testWidgets('Arabic RTL: the Arabic word «حذف» confirms; back goes to the '
      'previous step', (tester) async {
    final repo = FakeAccountDeletionRepository();
    await _pump(
      tester,
      const AccountDeletionScreen(initialStep: 1),
      repo: repo,
      language: AppLanguage.ar,
    );
    final context = tester.element(find.byType(AccountDeletionScreen));
    expect(Directionality.of(context), TextDirection.rtl);
    await tester.enterText(find.byKey(AccountDeletionScreen.passwordKey), 'pw');
    await tester.pump();
    await _tap(tester, AccountDeletionScreen.continueKey);
    expect(find.text(ar.deleteAccountConfirmBody('حذف')), findsOneWidget);
    // System back: one step back, not out of the flow.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(ar.deleteAccountStep(2, 3)), findsOneWidget);
    await _tap(tester, AccountDeletionScreen.continueKey);
    await tester.enterText(find.byKey(AccountDeletionScreen.confirmKey), 'حذف');
    await tester.pump();
    await _tap(tester, AccountDeletionScreen.submitKey, settle: false);
    expect(repo.requests, [('pw', 'حذف')]);
  });

  testWidgets('«طلب حذف قيد التنفيذ — إلغاء الحذف؟»: cancelling signs in with '
      'the credentials typed', (tester) async {
    final repo = FakeAccountDeletionRepository();
    await _pump(
      tester,
      const DeletionPendingScreen(),
      repo: repo,
      language: AppLanguage.ar,
      overrides: [pendingDeletionSignInProvider.overrideWith(_Pending.new)],
    );
    expect(find.text(ar.deletionPendingTitle), findsWidgets);
    expect(find.text(ar.deletionPendingQuestion), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);
    await _tap(tester, DeletionPendingScreen.cancelKey, settle: false);
    expect(repo.cancels, [
      ('sara@example.com', 'correct horse battery staple'),
    ]);
    expect(_SignedIn.signedInAs, _user);
  });

  testWidgets('keeping the deletion clears the credentials and goes back to '
      'login', (tester) async {
    final repo = FakeAccountDeletionRepository();
    final pushed = await _pump(
      tester,
      const DeletionPendingScreen(),
      repo: repo,
      overrides: [pendingDeletionSignInProvider.overrideWith(_Pending.new)],
    );
    await _tap(tester, DeletionPendingScreen.keepKey);
    expect(repo.cancels, isEmpty);
    expect(pushed, [AppRoutes.login]);
  });

  testWidgets('login: an account in its grace period opens the pending '
      'screen; the request banner shows after the request', (tester) async {
    final auth = FakeAuthRepository()
      ..loginFailure = _failure(
        ErrorCode.accountDeletionPending,
        details: [
          FieldIssue(field: 'purgeAfter', issue: _purgeAfter.toIso8601String()),
        ],
      );
    await pumpKabsoApp(
      tester,
      prefs: const {PreferenceKeys.welcomeSeen: true},
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        accountDeletionRepositoryProvider.overrideWithValue(
          FakeAccountDeletionRepository(),
        ),
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
      'correct horse battery staple',
    );
    await tester.ensureVisible(find.byKey(LoginScreen.submitKey));
    await tester.tap(find.byKey(LoginScreen.submitKey));
    await tester.pumpAndSettle();
    expect(find.byType(DeletionPendingScreen), findsOneWidget);
    expect(
      find.text(
        en.deletionPendingBody(KFormat.date(_purgeAfter.toLocal(), 'en')),
      ),
      findsOneWidget,
    );
  });

  for (final language in AppLanguage.values) {
    for (final brightness in Brightness.values) {
      testWidgets('360×800 at text scale 1.3, ${language.name} '
          '${brightness.name}: every step and the pending screen fit', (
        tester,
      ) async {
        for (final step in [0, 1, 2]) {
          await _pump(
            tester,
            AccountDeletionScreen(initialStep: step),
            repo: FakeAccountDeletionRepository(
              blockers: step == 0 ? [DeletionBlocker.rechargeAgent] : [],
            ),
            language: language,
            brightness: brightness,
            size: const Size(360, 800),
            textScale: 1.3,
            overrides: [
              pendingDeletionSignInProvider.overrideWith(_Pending.new),
            ],
          );
          expect(tester.takeException(), isNull, reason: 'step $step');
        }
        await _pump(
          tester,
          const DeletionPendingScreen(),
          repo: FakeAccountDeletionRepository(),
          language: language,
          brightness: brightness,
          size: const Size(360, 800),
          textScale: 1.3,
          overrides: [pendingDeletionSignInProvider.overrideWith(_Pending.new)],
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _IntroDone extends SplashIntro {
  @override
  bool build() => true;
}
