import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/families/data/families_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/medals/data/medals_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_bonds_repositories.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

/// The fakes behind a bonds screen.
class BondFakes {
  final families = FakeFamiliesRepository();
  final cp = FakeCpRepository();
  final medals = FakeMedalsRepository();
  final live = FakeLiveRepository();

  /// Every location pushed or gone to (other than the start).
  final List<String> visited = [];
}

/// Pumps [screen] at `/` under a real GoRouter; any other location shows
/// its path as text (and is recorded), so navigation is visible.
Future<BondFakes> pumpBonds(
  WidgetTester tester,
  Widget screen, {
  AppLanguage language = AppLanguage.en,
  BondFakes? fakes,
  List<Override> overrides = const [],
  bool signedIn = true,
  Brightness brightness = Brightness.dark,
}) async {
  final f = fakes ?? BondFakes();
  final prefs = await testPrefs(language: language.name);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => screen)],
    // Every other location: a page saying where it is.
    errorBuilder: (_, state) {
      f.visited.add(state.uri.toString());
      return Scaffold(body: Text('at ${state.uri}'));
    },
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        familiesRepositoryProvider.overrideWithValue(f.families),
        cpRepositoryProvider.overrideWithValue(f.cp),
        medalsRepositoryProvider.overrideWithValue(f.medals),
        liveRepositoryProvider.overrideWithValue(f.live),
        currentUserProvider.overrideWithValue(signedIn ? testUser() : null),
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
      ),
    ),
  );
  await tester.pumpAndSettle();
  return f;
}
