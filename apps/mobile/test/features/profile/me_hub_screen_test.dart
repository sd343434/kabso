// D163: the Me hub — the photo and name open the profile, the level badge
// beside the name, real counts only (no friends count in the API), every
// built feature opens its real screen, every unbuilt one is faded with
// "Soon" and does nothing, RTL/LTR and small screens.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/data/live_rankings_repository.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

class _Coins extends LiveCoinsController {
  @override
  Future<int> build() async => 1250;
}

/// Every destination the hub can open, as a labelled page.
const List<String> _destinations = [
  AppRoutes.myProfile,
  AppRoutes.settings,
  AppRoutes.notifications,
  AppRoutes.levels,
  AppRoutes.families,
  AppRoutes.bag,
  AppRoutes.medals,
  AppRoutes.cp,
  AppRoutes.premium,
  // D164.
  AppRoutes.wallet,
  AppRoutes.earnings,
  AppRoutes.creatorCenter,
];

Future<void> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  bool statsFail = false,
  List<Override> extra = const [],
}) async {
  final router = GoRouter(
    initialLocation: AppRoutes.profile,
    routes: [
      GoRoute(path: AppRoutes.profile, builder: (_, _) => const MeHubScreen()),
      for (final path in _destinations)
        GoRoute(path: path, builder: (_, _) => Text('page $path')),
      GoRoute(
        path: AppRoutes.userFollowsPattern,
        builder: (_, s) => Text(
          'follows ${s.pathParameters['username']} '
          '${s.uri.queryParameters['tab'] ?? 'followers'}',
        ),
      ),
    ],
  );
  // The bundled fonts, so widths (and overflow) are the real ones.
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
        meProvider.overrideWith((ref) => testUser()),
        profileStatsProvider.overrideWith((ref, _) {
          if (statsFail) throw const NetworkFailure.offline();
          return apiProfile(isSelf: true)
              .copyWith(medals: const ProfileMedals(owned: 5, total: 9));
        }),
        profileLevelsProvider.overrideWith(
          (ref, _) => [
            PublicLevel(
              category: LevelCategory.support,
              name: 'Support',
              level: LevelBrief(
                levelNumber: 35,
                name: 'L35',
                requiredPoints: BigInt.zero,
              ),
            ),
          ],
        ),
        liveCoinsProvider.overrideWith(_Coins.new),
        ...extra,
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

Future<void> _tapItem(WidgetTester tester, MeHubItem item) async {
  await tester.scrollUntilVisible(find.byKey(item.key), 100);
  await tester.ensureVisible(find.byKey(item.key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(item.key));
  await tester.pumpAndSettle();
}

/// The hub items that are not built yet (faded, "Soon", no action).
/// D164: Wallet, Earn money and Creator Center are built; these four wait
/// for the owner's decisions (CP-024).
const Set<MeHubItem> _soon = {
  MeHubItem.vip,
  MeHubItem.eventCenter,
  MeHubItem.svip,
  MeHubItem.taskCenter,
};

void main() {
  testWidgets('header: the name with the level badge on its line, the '
      'real Following and Fans counts and no invented friends count', (
    tester,
  ) async {
    await _pump(tester);
    final name = tester.getRect(find.byKey(MeHubScreen.nameKey));
    final badge = tester.getRect(find.byType(KLevelBadge));
    expect(find.text('Layla'), findsOneWidget);
    expect(badge.center.dy, moreOrLessEquals(name.center.dy, epsilon: 4));
    expect(badge.left, greaterThan(name.right));
    expect(
      find.descendant(
        of: find.byKey(MeHubScreen.followingKey),
        matching: find.text('40'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(MeHubScreen.fansKey),
        matching: find.text('1,234'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Friends'), findsNothing);
  });

  testWidgets('a failed count shows a dash, not a skeleton', (tester) async {
    await _pump(tester, statsFail: true);
    expect(
      find.descendant(
        of: find.byKey(MeHubScreen.fansKey),
        matching: find.text('–'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the photo and the name open the profile', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(MeHubScreen.avatarKey));
    await tester.pumpAndSettle();
    expect(find.text('page ${AppRoutes.myProfile}'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(MeHubScreen.nameKey));
    await tester.pumpAndSettle();
    expect(find.text('page ${AppRoutes.myProfile}'), findsOneWidget);
  });

  testWidgets('the counts open the follow lists', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(MeHubScreen.followingKey));
    await tester.pumpAndSettle();
    expect(find.text('follows layla.k following'), findsOneWidget);
  });

  // D168 (owner): «المنشورات» is no longer a row; an icon beside Settings
  // opens the profile page (posts, reels, reposts, saved).
  for (final language in AppLanguage.values) {
    testWidgets('the profile icon sits beside Settings, is labelled and '
        'opens the profile (${language.name})', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, language: language);
      final l10n = l10nFor(language);
      final icon = find.byKey(MeHubScreen.profileKey);
      final settings = find.byKey(MeHubScreen.settingsKey);
      expect(icon, findsOneWidget);
      expect(find.byTooltip(l10n.meHubMyProfile), findsOneWidget);
      expect(
        tester.getSemantics(icon),
        matchesSemantics(
          label: l10n.meHubMyProfile,
          isButton: true,
          hasTapAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      final a = tester.getRect(icon);
      final b = tester.getRect(settings);
      expect(a.center.dy, moreOrLessEquals(b.center.dy, epsilon: 0.5));
      // Adjacent, on the reading-start side of Settings.
      if (language == AppLanguage.ar) {
        expect(a.left, moreOrLessEquals(b.right, epsilon: 0.5));
      } else {
        expect(a.right, moreOrLessEquals(b.left, epsilon: 0.5));
      }
      expect(
        find.text(language == AppLanguage.ar ? 'المنشورات' : 'Post'),
        findsNothing,
      );
      await tester.tap(icon);
      await tester.pumpAndSettle();
      expect(find.text('page ${AppRoutes.myProfile}'), findsOneWidget);
      semantics.dispose();
    });
  }

  testWidgets('settings and notifications open their screens', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(MeHubScreen.settingsKey));
    await tester.pumpAndSettle();
    expect(find.text('page ${AppRoutes.settings}'), findsOneWidget);
  });

  for (final (item, path) in [
    (MeHubItem.levels, AppRoutes.levels),
    (MeHubItem.family, AppRoutes.families),
    (MeHubItem.bag, AppRoutes.bag),
    (MeHubItem.medals, AppRoutes.medals),
    (MeHubItem.relationship, AppRoutes.cp),
    (MeHubItem.premium, AppRoutes.premium),
    // D164.
    (MeHubItem.wallet, AppRoutes.wallet),
    (MeHubItem.earn, AppRoutes.earnings),
    (MeHubItem.creatorCenter, AppRoutes.creatorCenter),
  ]) {
    testWidgets('${item.name} opens its real screen ($path)', (tester) async {
      await _pump(tester);
      await _tapItem(tester, item);
      expect(find.text('page $path'), findsOneWidget);
    });
  }

  testWidgets('Ranking opens the popularity board (CP-016 A)', (tester) async {
    await _pump(
      tester,
      extra: [
        liveRankingsProvider.overrideWith(
          (ref, _) => throw const NetworkFailure.offline(),
        ),
      ],
    );
    await _tapItem(tester, MeHubItem.ranking);
    expect(find.byKey(LiveRankingsKeys.sheet), findsOneWidget);
  });

  testWidgets('unbuilt features are faded with "Soon" and do nothing', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    for (final item in _soon) {
      await _tapItem(tester, item);
      // Still on the hub: no stand-in screen opened.
      expect(find.byType(MeHubScreen), findsOneWidget);
      expect(find.textContaining('page '), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(item.key),
          matching: find.byKey(MeHubScreen.soonKey),
        ),
        findsOneWidget,
        reason: item.name,
      );
      final node = tester.getSemantics(find.byKey(item.key));
      expect(node.label, contains('coming soon'), reason: item.name);
      expect(
        node.flagsCollection.isEnabled.toBoolOrNull(),
        isFalse,
        reason: item.name,
      );
    }
    // The built ones carry no "Soon".
    for (final item in MeHubItem.values.where((i) => !_soon.contains(i))) {
      await tester.scrollUntilVisible(find.byKey(item.key), 100);
      expect(
        find.descendant(
          of: find.byKey(item.key),
          matching: find.byKey(MeHubScreen.soonKey),
        ),
        findsNothing,
        reason: item.name,
      );
    }
    semantics.dispose();
  });

  testWidgets('the wallet shows the real balance (GET /wallet/me)', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      find.descendant(
        of: find.byKey(MeHubItem.wallet.key),
        matching: find.text('1,250'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('medals show owned of total', (tester) async {
    await _pump(tester);
    await tester.scrollUntilVisible(find.byKey(MeHubItem.medals.key), 100);
    expect(
      find.descendant(
        of: find.byKey(MeHubItem.medals.key),
        matching: find.text(_en.medalsOwned(5, 9)),
      ),
      findsOneWidget,
    );
  });

  testWidgets('RTL: actions at the left, Following at the right, the '
      'first card at the right', (tester) async {
    await _pump(tester, language: AppLanguage.ar);
    const width = 393.0;
    expect(
      tester.getCenter(find.byKey(MeHubScreen.settingsKey)).dx,
      lessThan(width / 2),
    );
    expect(
      tester.getCenter(find.byKey(MeHubScreen.followingKey)).dx,
      greaterThan(width / 2),
    );
    expect(
      tester.getCenter(find.byKey(MeHubItem.levels.key)).dx,
      greaterThan(tester.getCenter(find.byKey(MeHubItem.earn.key)).dx),
    );
    expect(
      tester.getCenter(find.byKey(MeHubScreen.avatarKey)).dx,
      moreOrLessEquals(width / 2, epsilon: 1),
    );
  });

  testWidgets('LTR: actions at the right, the first card at the left', (
    tester,
  ) async {
    await _pump(tester);
    expect(
      tester.getCenter(find.byKey(MeHubScreen.settingsKey)).dx,
      greaterThan(393 / 2),
    );
    expect(
      tester.getCenter(find.byKey(MeHubItem.levels.key)).dx,
      lessThan(tester.getCenter(find.byKey(MeHubItem.earn.key)).dx),
    );
  });

  for (final language in AppLanguage.values) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('360x800 at $scale (${language.name}): no overflow', (
        tester,
      ) async {
        await _pump(
          tester,
          language: language,
          viewport: GoldenViewport.android,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        for (final item in MeHubItem.values) {
          await tester.scrollUntilVisible(find.byKey(item.key), 100);
          expect(tester.takeException(), isNull, reason: item.name);
        }
      });
    }
  }
}
