import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/premium/data/premium_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_premium_repository.dart';
import '../../helpers/fakes.dart';

/// Signed in as [user] without restoring anything.
class FixedSession extends SessionController {
  new(this.user);

  final User user;

  @override
  AuthState build() => Authenticated(user);
}

/// The availability check answers from the fake auth repository.
final Override usernameCheckOverride = authRepositoryProvider.overrideWithValue(
  FakeAuthRepository(),
);

/// A fixed coin balance.
class FakeCoins extends LiveCoinsController {
  new(this.coins);

  final int coins;

  @override
  Future<int> build() async => coins;
}

/// Pumps [screen] at 393×852 in [language] with [premium] and [coins], under
/// a router whose other routes record where the screen went.
Future<List<String>> pumpPremium(
  WidgetTester tester,
  Widget screen, {
  required FakePremiumRepository premium,
  int coins = 100000,
  AppLanguage language = AppLanguage.en,
  List<Override> overrides = const [],
}) async {
  tester.view
    ..physicalSize = const Size(393, 852) * 3
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
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        premiumRepositoryProvider.overrideWithValue(premium),
        liveCoinsProvider.overrideWith(() => FakeCoins(coins)),
        usernameCheckOverride,
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
        theme: buildAppTheme(
          brightness: Brightness.dark,
          locale: language.locale,
        ),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: app!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return pushed;
}
