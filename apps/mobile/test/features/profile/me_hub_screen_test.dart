// D163: the Me hub — the photo and name open the profile, the level badge
// beside the name, real counts only (no friends count in the API), every
// built feature opens its real screen, every unbuilt one is faded with
// "Soon" and does nothing, RTL/LTR and small screens.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/verification_badge.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/levels/presentation/profile_levels.dart';
import 'package:kabso_live/features/live/application/live_wallet_controller.dart';
import 'package:kabso_live/features/live/data/live_rankings_repository.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/features/medals/domain/medal_models.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
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
  // D252.
  AppRoutes.vip,
  // D270.
  AppRoutes.store,
];

Future<void> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  bool statsFail = false,
  List<Override> extra = const [],
  User? user,
  Brightness brightness = Brightness.light,
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
        currentUserProvider.overrideWithValue(user ?? testUser()),
        meProvider.overrideWith((ref) => user ?? testUser()),
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
        theme: buildAppTheme(brightness: brightness, locale: language.locale),
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
/// Center, SVIP and Task Center too. D252: Purchase VIP too. D267 (owner):
/// SVIP is gone. D270: «المتجر» (the store) is built — nothing is «Soon».
const Set<MeHubItem> _soon = {};

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

  testWidgets('D293: the verification badge right after the name, spoken '
      'and explained on a tap (D388); none without one', (tester) async {
    await _pump(
      tester,
      user: testUser().copyWith(verification: VerificationBadge.creator),
    );
    final name = tester.getRect(find.byKey(MeHubScreen.nameKey));
    final seal = tester.getRect(find.byKey(MeHubScreen.verificationBadgeKey));
    final level = tester.getRect(find.byType(KLevelBadge));
    expect(seal.left, greaterThan(name.right));
    expect(seal.right, lessThan(level.left));
    expect(seal.center.dy, moreOrLessEquals(name.center.dy, epsilon: 4));
    expect(seal.width, ProfileVerificationBadge.sizeForFont(KMeHub.nameSize));
    expect(find.bySemanticsLabel('Verified: content creator'), findsOneWidget);
    // D388: a tap shows the explainer bubble (was a long-press tooltip).
    await tester.tap(find.byKey(MeHubScreen.verificationBadgeKey));
    await tester.pump();
    expect(
      find.text(
        'Verified: content creator — granted automatically when the '
        'conditions are met',
      ),
      findsOneWidget,
    );
    await tester.pump(KBadgeExplainer.showFor);
    expect(find.byKey(KBadgeExplainer.bubbleKey), findsNothing);
  });

  for (final language in AppLanguage.values) {
    testWidgets('D293: the badge fits the name row at 360x800 and 1.3 '
        '(${language.name})', (tester) async {
      await _pump(
        tester,
        language: language,
        viewport: GoldenViewport.android,
        textScale: 1.3,
        user: testUser().copyWith(verification: VerificationBadge.staff),
      );
      expect(tester.takeException(), isNull);
      final name = tester.getRect(find.byKey(MeHubScreen.nameKey));
      final seal = tester.getRect(find.byKey(MeHubScreen.verificationBadgeKey));
      expect(seal.left, greaterThanOrEqualTo(0));
      expect(seal.right, lessThanOrEqualTo(360));
      expect(seal.center.dy, moreOrLessEquals(name.center.dy, epsilon: 4));
    });
  }

  testWidgets('D357: never the OWNER seal beside the name (owner: «ازيلها»)', (
    tester,
  ) async {
    await _pump(
      tester,
      user: testUser().copyWith(verification: VerificationBadge.owner),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(MeHubScreen.nameKey), findsOneWidget);
    expect(find.byKey(MeHubScreen.verificationBadgeKey), findsNothing);
    expect(find.byType(ProfileVerificationBadge), findsNothing);
    expect(find.bySemanticsLabel('Verified: app owner'), findsNothing);
  });

  // D357: the founder's own Me tab — his name with no seal beside it.
  final founderDir = Platform.environment['D357_CAPTURE_DIR'];
  for (final language in AppLanguage.values) {
    testWidgets(
      'D357 capture: the founder Me tab, no seal '
      '(${language.name})',
      skip: founderDir == null,
      (tester) async {
        final ar = language == AppLanguage.ar;
        await _pump(
          tester,
          language: language,
          user: testUser().copyWith(
            displayName: ar ? 'مؤسس كابسو' : 'Kabso Founder',
            verification: VerificationBadge.owner,
          ),
          extra: [isKabsoOwnerProvider.overrideWithValue(true)],
        );
        expect(find.byKey(MeHubScreen.verificationBadgeKey), findsNothing);
        expect(find.byType(ProfileVerificationBadge), findsNothing);
        await precacheImages(tester);
        await tester.runAsync(() async {
          final element = find.byType(MaterialApp).evaluate().first;
          final image = await captureImage(element);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${founderDir!}/founder.me_tab.${language.name}.light.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
        });
      },
    );
  }

  // D361 (owner: «المؤسس ليس له ليفيل»): decision — no level card on the
  // founder's Me tab (his levels page shows the neutral state).
  testWidgets('D361: anyone but the founder has the level card', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(ProfileLevels), findsOneWidget);
    expect(find.byType(KLevelBadge), findsWidgets);
  });

  testWidgets("D361: the founder's Me tab has no level", (tester) async {
    await _pump(
      tester,
      user: testUser().copyWith(displayName: 'Kabso Founder'),
      extra: [isKabsoOwnerProvider.overrideWithValue(true)],
    );
    expect(find.byType(ProfileLevels), findsNothing);
    expect(find.byType(KLevelBadge), findsNothing);
  });

  final d361Dir = Platform.environment['D361_CAPTURE_DIR'];
  for (final (language, brightness) in [
    (AppLanguage.ar, Brightness.light),
    (AppLanguage.ar, Brightness.dark),
    (AppLanguage.en, Brightness.light),
    (AppLanguage.en, Brightness.dark),
  ]) {
    testWidgets(
      'D361 capture: the founder Me tab, no level '
      '(${language.name} ${brightness.name})',
      skip: d361Dir == null,
      (tester) async {
        final ar = language == AppLanguage.ar;
        await _pump(
          tester,
          language: language,
          brightness: brightness,
          user: testUser().copyWith(
            displayName: ar ? 'مؤسس كابسو' : 'Kabso Founder',
          ),
          extra: [isKabsoOwnerProvider.overrideWithValue(true)],
        );
        expect(find.byType(ProfileLevels), findsNothing);
        await precacheImages(tester);
        await tester.runAsync(() async {
          final element = find.byType(MaterialApp).evaluate().first;
          final image = await captureImage(element);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '${d361Dir!}/founder.me_tab.${language.name}.${brightness.name}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
      },
    );
  }

  testWidgets('D293: no verification badge without one', (tester) async {
    await _pump(tester);
    expect(find.byType(ProfileVerificationBadge), findsNothing);
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
    // D217 (owner): «اربح المال» opens «دعوة صديق».
    (MeHubItem.earn, AppRoutes.inviteFriends),
    (MeHubItem.creatorCenter, AppRoutes.creatorCenter),
    // D166.
    (MeHubItem.taskCenter, AppRoutes.taskCenter),
    (MeHubItem.eventCenter, AppRoutes.eventCenter),
    // D252.
    (MeHubItem.vip, AppRoutes.vip),
    // D179.
    (MeHubItem.agency, AppRoutes.agency),
    // D270.
    (MeHubItem.store, AppRoutes.store),
  ]) {
    testWidgets('${item.name} opens its real screen ($path)', (tester) async {
      await _pump(tester);
      await _tapItem(tester, item);
      expect(find.text('page $path'), findsOneWidget);
    });
  }

  testWidgets('D217: «اربح المال» opens the cherry wallet when the referral '
      'programme was found off', (tester) async {
    await _pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MeHubScreen)),
    );
    container.read(referralEnabledProvider.notifier).enabled = false;
    await _tapItem(tester, MeHubItem.earn);
    expect(find.text('page ${AppRoutes.walletCherries}'), findsOneWidget);
  });

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
      greaterThan(tester.getCenter(find.byKey(MeHubItem.store.key)).dx),
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
      lessThan(tester.getCenter(find.byKey(MeHubItem.store.key)).dx),
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
