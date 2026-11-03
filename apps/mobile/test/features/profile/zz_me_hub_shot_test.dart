// D163: the Me hub — the photo and name open the profile, the level badge
// beside the name, real counts only (no friends count in the API), every
// built feature opens its real screen, every unbuilt one is faded with
// "Soon" and does nothing, RTL/LTR and small screens.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:kabso_live/features/referrals/application/referral_providers.dart';
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
  AppRoutes.creatorCenter,
  // D217: «اربح المال» → «دعوة صديق».
  AppRoutes.inviteFriends,
  // D179.
  AppRoutes.agency,
  // D166.
  AppRoutes.taskCenter,
  AppRoutes.eventCenter,
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
        GoRoute(
          path: path,
          // D177: the earn card opens the wallet on its cherry tab.
          builder: (_, s) => Text('page ${s.uri}'),
        ),
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
/// D164: Wallet, Earn money and Creator Center are built. D166: Event
/// Center and Task Center too (D249: SVIP removed from the hub); Purchase
/// VIP waits for the owner's prices (CP-024).
const Set<MeHubItem> _soon = {MeHubItem.vip};


// TEMPORARY (screenshot for the owner, never merged): renders the Me hub in
// Arabic on a tall phone and writes it to build/shots/.
void main() {
  testWidgets('SHOT me hub ar', (tester) async {
    await _pump(tester, language: AppLanguage.ar);
    tester.view
      ..physicalSize = const Size(393 * 2, 1400 * 2)
      ..devicePixelRatio = 2;
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(MeHubScreen));
    final tag = Platform.environment['SHOT_TAG'] ?? 'after';
    await tester.runAsync(() async {
      final ui.Image img = await captureImage(element);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/shots').createSync(recursive: true);
      File('build/shots/me_hub_$tag.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
    });
  });
}
