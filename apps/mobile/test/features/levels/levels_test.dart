// D72 + D169: the four level systems (CP-005) — models, art tiers (support:
// the owner's 21 badges), the repository against a mocked Dio adapter, the
// levels page (category cards) and the category page (header card, badge
// tiers) with honest states, Arabic RTL / English LTR and small screens.

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/auth_tokens.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/levels/data/levels_repository.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/levels/presentation/level_category_card.dart';
import 'package:kabso_live/features/levels/presentation/level_detail_screen.dart';
import 'package:kabso_live/features/levels/presentation/levels_screen.dart';
import 'package:kabso_live/features/levels/presentation/profile_levels.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/levels/levels_api_fixtures.dart';
import '../../helpers/contract_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// Answers from fixtures; [failure] makes every call fail.
class FakeLevelsRepository implements LevelsRepository {
  new({List<Map<String, dynamic>>? summaries, this.detail, this.failure})
    : summaries = summaries ?? mixedLevelsJson();

  List<Map<String, dynamic>> summaries;
  Map<String, dynamic>? detail;
  AppFailure? failure;
  int calls = 0;

  @override
  Future<List<LevelSummary>> getMyLevels() async {
    calls++;
    if (failure case final f?) throw f;
    return summaries.map(LevelSummary.fromJson).toList();
  }

  @override
  Future<List<PublicLevel>> getUserLevels(String username) async {
    calls++;
    if (failure case final f?) throw f;
    return summaries.map(PublicLevel.fromJson).toList();
  }

  /// The categories whose ladder was asked for, in order.
  final List<LevelCategory> detailCalls = [];

  /// [detail] when set; else the support ladder for Support, and for the
  /// others a ladder of the summary's own level and the next one.
  @override
  Future<LevelDetail> getMyLevel(LevelCategory category) async {
    calls++;
    detailCalls.add(category);
    if (failure case final f?) throw f;
    if (detail case final d?) return LevelDetail.fromJson(d);
    final summary = summaries[category.index];
    return LevelDetail.fromJson(
      category == LevelCategory.support
          ? {...supportDetailJson(), ...summary}
          : {
              ...summary,
              'levels': [?summary['level'], ?summary['nextLevel']],
            },
    );
  }
}

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

/// The levels routes on a real GoRouter, so taps navigate as in the app.
Future<void> _pumpRouted(
  WidgetTester tester,
  FakeLevelsRepository repo, {
  AppLanguage language = AppLanguage.en,
  String initial = AppRoutes.levels,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
}) async {
  setViewport(tester, viewport);
  final prefs = await testPrefs(language: language.name);
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(path: AppRoutes.levels, builder: (_, _) => const LevelsScreen()),
      GoRoute(
        path: AppRoutes.levelPattern,
        builder: (_, state) => LevelDetailScreen(
          category: LevelCategory.fromSlug(state.pathParameters['category']!)!,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        levelsRepositoryProvider.overrideWithValue(repo),
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

void main() {
  group('models', () {
    test('parse the contract shape, with exact 64-bit points', () {
      final list = mixedLevelsJson().map(LevelSummary.fromJson).toList();
      expect(list.map((s) => s.category), LevelCategory.values);
      expect(list[0].points, BigInt.from(12500));
      expect(list[0].level!.levelNumber, 37);
      expect(list[2].maxLevel, isTrue);
      expect(list[3].available, isFalse);
      expect(list[3].level, isNull);
      final big = LevelSummary.fromJson(
        levelSummaryJson('SUPPORT', points: '9223372036854775807'),
      );
      expect(big.points.toString(), '9223372036854775807');
    });

    test('reject what the contract does not allow', () {
      expect(
        () => LevelSummary.fromJson({
          ...levelSummaryJson('SUPPORT'),
          'status': 'MAYBE',
        }),
        throwsFormatException,
      );
      expect(
        () => LevelSummary.fromJson({
          ...levelSummaryJson('SUPPORT'),
          'points': 12,
        }),
        throwsFormatException,
      );
      expect(
        () => LevelSummary.fromJson({
          ...levelSummaryJson('SUPPORT'),
          'category': 'CHARM',
        }),
        throwsFormatException,
      );
    });

    test('slugs map to the four categories only', () {
      expect(LevelCategory.fromSlug('wizard'), LevelCategory.wizard);
      expect(LevelCategory.fromSlug('WIZARD'), isNull);
      expect(LevelCategory.fromSlug('magic'), isNull);
    });
  });

  group('art', () {
    test('tiers follow the pack: 1–9, 10–19 … 90–99, 100', () {
      expect(KLevelArt.tier(1), 1);
      expect(KLevelArt.tier(9), 1);
      expect(KLevelArt.tier(10), 2);
      expect(KLevelArt.tier(37), 4);
      expect(KLevelArt.tier(99), 10);
      expect(KLevelArt.tier(100), 11);
      expect(KLevelArt.tier(180), 11);
    });

    test('a server iconKey tier_NN wins; anything else is ignored', () {
      expect(KLevelArt.tier(1, iconKey: 'tier_05'), 5);
      expect(KLevelArt.tier(1, iconKey: 'tier_12'), 1);
      expect(KLevelArt.tier(25, iconKey: 'gold'), 3);
    });

    test("every category has its emblems bundled (support: the owner's 21 "
        'badges and pills)', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final c in LevelCategory.values) {
        for (var t = 1; t <= KLevelArt.tiersOf(c); t++) {
          final data = await rootBundle.load(KLevelArt.asset(c, t));
          expect(data.lengthInBytes, greaterThan(1000));
        }
      }
      expect(KLevelArt.tiersOf(LevelCategory.support), 21);
      for (var t = 1; t <= 21; t++) {
        final data = await rootBundle.load(KLevelArt.supportPill(t));
        expect(data.lengthInBytes, greaterThan(1000));
      }
      expect(KLevelArt.supportPillAspect, hasLength(21));
      // D169: 21 tier frames, one per tier.
      for (var t = 1; t <= 21; t++) {
        final data = await rootBundle.load(KLevelArt.supportFrame(t));
        expect(data.lengthInBytes, greaterThan(1000));
      }
      expect(KLevelArt.supportFrame(21), isNot(KLevelArt.supportFrame(20)));
      expect(KLevelArt.supportGems, hasLength(21));
    });

    test('support tiers: five levels each, 96–99 in tier 20, 100 alone', () {
      expect(KLevelArt.supportTier(1), 1);
      expect(KLevelArt.supportTier(5), 1);
      expect(KLevelArt.supportTier(6), 2);
      expect(KLevelArt.supportTier(37), 8);
      expect(KLevelArt.supportTier(95), 19);
      expect(KLevelArt.supportTier(99), 20);
      expect(KLevelArt.supportTier(100), 21);
      // The server's iconKey names the 11-tier pack: Support ignores it.
      expect(
        KLevelArt.tierOf(LevelCategory.support, 37, iconKey: 'tier_04'),
        8,
      );
      expect(KLevelArt.levelRange(LevelCategory.support, 1), (1, 5));
      expect(KLevelArt.levelRange(LevelCategory.support, 20), (96, 99));
      expect(KLevelArt.levelRange(LevelCategory.support, 21), (100, 100));
      expect(KLevelArt.levelRange(LevelCategory.wizard, 1), (1, 9));
      expect(KLevelArt.levelRange(LevelCategory.wizard, 4), (30, 39));
      expect(KLevelArt.levelRange(LevelCategory.wizard, 11), (100, 100));
      // Every level 1–100 falls in exactly one tier.
      for (final c in LevelCategory.values) {
        for (var n = 1; n <= 100; n++) {
          final (from, to) = KLevelArt.levelRange(c, KLevelArt.tierOf(c, n));
          expect(n, inInclusiveRange(from, to), reason: '$c $n');
        }
      }
    });

    test('points use separators and stay exact', () {
      expect(formatPoints(BigInt.zero), '0');
      expect(formatPoints(BigInt.from(999)), '999');
      expect(formatPoints(BigInt.from(12500)), '12,500');
      expect(
        formatPoints(BigInt.parse('9223372036854775807')),
        '9,223,372,036,854,775,807',
      );
    });
  });

  group('LevelsRepository', () {
    late FakeHttpAdapter http;
    late LevelsRepository repo;

    setUp(() async {
      http = FakeHttpAdapter();
      final prefs = await testPrefs(language: 'ar');
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: 'http://test', appVersion: '1.2.3'),
          ),
          httpClientAdapterProvider.overrideWithValue(http),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      await container
          .read(tokenManagerProvider)
          .saveTokens(AuthTokens.fromJson(tokenPairJson(accessToken: 'acc')));
      repo = container.read(levelsRepositoryProvider);
    });

    test('getMyLevels: GET /levels/me with bearer + Accept-Language', () async {
      http.on(
        'GET',
        '/api/v1/levels/me',
        (_) => FakeResponse(200, body: {'data': mixedLevelsJson(arabic: true)}),
      );
      final levels = await repo.getMyLevels();
      expect(levels, hasLength(4));
      expect(levels.first.name, 'مستوى الجاذبية');
      final req = http.requestsTo('GET', '/api/v1/levels/me').single;
      expect(req.headers['Authorization'], 'Bearer acc');
      expect(req.headers['Accept-Language'], 'ar');
    });

    test('getMyLevel: GET /levels/me/{category} in lower case', () async {
      http.on(
        'GET',
        '/api/v1/levels/me/support',
        (_) => FakeResponse(200, body: supportDetailJson()),
      );
      final detail = await repo.getMyLevel(LevelCategory.support);
      expect(detail.levels, hasLength(4));
      expect(detail.summary.category, LevelCategory.support);
    });

    test('a contract mismatch is an UnexpectedFailure, not a crash', () async {
      http.on(
        'GET',
        '/api/v1/levels/me',
        (_) => const FakeResponse(
          200,
          body: {
            'data': [
              {'category': 'SUPPORT'},
            ],
          },
        ),
      );
      await expectLater(repo.getMyLevels(), throwsA(isA<AppFailure>()));
    });
  });

  group('LevelsScreen (D169: tabs and category pages)', () {
    testWidgets('opens on the highest active level; four tabs side by side', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpRouted(tester, FakeLevelsRepository());
      final rects = [
        for (final c in LevelCategory.values)
          tester.getRect(find.byKey(LevelsScreen.tabKey(c))),
      ];
      // One row, reading order, equal widths.
      expect(rects.map((r) => r.top).toSet(), hasLength(1));
      expect(
        rects.map((r) => r.left).toList(),
        orderedEquals([...rects.map((r) => r.left)]..sort()),
      );
      for (final r in rects) {
        expect(r.width, closeTo(rects.first.width, 0.5));
      }
      expect(find.text(_en.levelsTabAttractiveness), findsOneWidget);
      // Wizard is at level 100, the highest active one.
      expect(
        tester.getSemantics(
          find.byKey(LevelsScreen.tabKey(LevelCategory.wizard)),
        ),
        isSemantics(isSelected: true, isButton: true, label: 'Wizard'),
      );
      expect(find.text('Legend · ${_en.levelsLv(100)}'), findsOneWidget);
      expect(find.byKey(LevelsScreen.preparingKey), findsNothing);
      handle.dispose();
    });

    testWidgets('/levels/support: the header card, "Need X" and 21 tiers '
        'with frames, the current one marked', (tester) async {
      await _pumpRouted(
        tester,
        FakeLevelsRepository(),
        initial: AppRoutes.level('support'),
      );
      expect(find.byType(LevelDetailScreen), findsOneWidget);
      final header = find.byKey(LevelsScreen.headerKey);
      expect(
        find.descendant(
          of: header,
          matching: find.text('Supporter · ${_en.levelsLv(2)}'),
        ),
        findsOneWidget,
      );
      final need = tester.widget<Text>(find.byKey(LevelCategoryCard.needKey));
      final spans = (need.textSpan! as TextSpan).children!.cast<TextSpan>();
      final x = spans.singleWhere((s) => s.text!.contains('350'));
      expect(x.style!.color, KLevelCard.highlight);
      expect(
        spans
            .map((s) => s.text)
            .join()
            .replaceAll(RegExp('[\u2066\u2069]'), ''),
        _en.levelsNeedXp('350'),
      );
      expect(find.text(_en.levelsHowItGrows), findsOneWidget);
      // Level 2 is support tier 1 (levels 1–5), with its avatar frame.
      expect(find.byKey(LevelTierGrid.currentKey), findsOneWidget);
      expect(find.byKey(LevelTierGrid.frameKey(1)), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(LevelTierGrid.tierKey(21)),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(_en.levelsLv(100)), findsOneWidget);
      expect(find.text(_en.levelsTierRange(96, 99)), findsOneWidget);
    });

    testWidgets('a tab and a swipe both move between categories', (
      tester,
    ) async {
      await _pumpRouted(tester, FakeLevelsRepository());
      await tester.tap(
        find.byKey(LevelsScreen.tabKey(LevelCategory.attractiveness)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rising star · ${_en.levelsLv(37)}'), findsOneWidget);
      // The pack has 11 tiers; no frames outside Support.
      expect(find.byKey(LevelTierGrid.frameKey(1)), findsNothing);
      // Swipe towards the reading end: the next category (Support).
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Supporter · ${_en.levelsLv(2)}'), findsOneWidget);
      final handle = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester.getSemantics(
          find.byKey(LevelsScreen.tabKey(LevelCategory.support)),
        ),
        isSemantics(isSelected: true),
      );
      handle.dispose();
    });

    testWidgets('an inactive category: honest header, explanation, tiers '
        'dimmed', (tester) async {
      await _pumpRouted(
        tester,
        FakeLevelsRepository(),
        initial: AppRoutes.level('gaming'),
      );
      expect(
        find.descendant(
          of: find.byKey(LevelsScreen.headerKey),
          matching: find.text('Gaming · ${_en.levelsUnavailable}'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(LevelTierGrid.unavailableKey), findsOneWidget);
      expect(find.byKey(LevelCategoryCard.needKey), findsNothing);
      expect(find.byKey(LevelTierGrid.currentKey), findsNothing);
      final tile = find.byKey(LevelTierGrid.tierKey(1));
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      // Locked: desaturated, a lock in the pill.
      expect(
        find.descendant(of: tile, matching: find.text(_en.levelsTierLocked)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tile, matching: find.byType(ColorFiltered)),
        findsOneWidget,
      );
    });

    testWidgets('only the tier the caller is on is lit; passed ones are dim '
        'but say so', (tester) async {
      await _pumpRouted(
        tester,
        FakeLevelsRepository(),
        initial: AppRoutes.level('attractiveness'),
      );
      // Level 37 = pack tier 4; tier 1 is passed.
      final current = find.byKey(LevelTierGrid.currentKey);
      await tester.scrollUntilVisible(
        current,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.descendant(of: current, matching: find.byType(ColorFiltered)),
        findsNothing,
      );
      final passed = find.byKey(LevelTierGrid.tierKey(1));
      expect(
        find.descendant(of: passed, matching: find.byType(ColorFiltered)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: passed, matching: find.text(_en.levelsTierOpen)),
        findsOneWidget,
      );
    });

    testWidgets('all four inactive: the "on their way" banner, Charm first', (
      tester,
    ) async {
      await _pumpRouted(
        tester,
        FakeLevelsRepository(summaries: allUnavailableJson()),
      );
      expect(find.byKey(LevelsScreen.preparingKey), findsOneWidget);
      expect(
        LevelsScreen.defaultCategory(
          allUnavailableJson().map(LevelSummary.fromJson).toList(),
        ),
        LevelCategory.attractiveness,
      );
      expect(find.byKey(LevelTierGrid.unavailableKey), findsOneWidget);
    });

    testWidgets('an error offers retry, which reloads', (tester) async {
      final repo = FakeLevelsRepository(
        failure: const NetworkFailure.offline(),
      );
      await _pumpRouted(tester, repo);
      expect(find.text(_en.levelsLoadError), findsOneWidget);
      repo.failure = null;
      await tester.tap(find.text(_en.actionRetry));
      await tester.pumpAndSettle();
      expect(find.byKey(LevelsScreen.tabBarKey), findsOneWidget);
    });

    testWidgets('tier cards read their name, levels, state, frame and pill', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpRouted(
        tester,
        FakeLevelsRepository(),
        initial: AppRoutes.level('support'),
      );
      expect(
        tester.getSemantics(find.byKey(LevelTierGrid.currentKey)),
        matchesSemantics(
          isSelected: true,
          hasSelectedState: true,
          label: [
            'Starter ${_en.levelsTierRange(1, 5)}',
            _en.levelsTierUnlocked,
            _en.levelsTierFrom('0'),
            _en.levelsTierFrame,
            _en.levelsTierCurrent,
          ].join('، '),
        ),
      );
      handle.dispose();
    });
  });

  group('RTL / small screens', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: 360×800 at text scale 1.3 — the four '
          'tabs stay on one row, no page overflows', (tester) async {
        final arabic = language == AppLanguage.ar;
        await _pumpRouted(
          tester,
          FakeLevelsRepository(summaries: mixedLevelsJson(arabic: arabic)),
          language: language,
          viewport: GoldenViewport.android,
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        final tops = {
          for (final c in LevelCategory.values)
            tester.getRect(find.byKey(LevelsScreen.tabKey(c))).top,
        };
        expect(tops, hasLength(1));
        for (final c in LevelCategory.values) {
          await tester.tap(find.byKey(LevelsScreen.tabKey(c)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets("Arabic: tabs read right to left; the card's badge sits at "
        'the top left', (tester) async {
      await _pumpRouted(
        tester,
        FakeLevelsRepository(summaries: mixedLevelsJson(arabic: true)),
        language: AppLanguage.ar,
        initial: AppRoutes.level('support'),
      );
      final first = tester.getCenter(
        find.byKey(LevelsScreen.tabKey(LevelCategory.attractiveness)),
      );
      final second = tester.getCenter(
        find.byKey(LevelsScreen.tabKey(LevelCategory.support)),
      );
      expect(first.dx, greaterThan(second.dx));
      expect(find.text(_ar.levelsTabSupport), findsOneWidget);
      final header = tester.getRect(find.byKey(LevelsScreen.headerKey));
      final medal = tester.getRect(
        find.descendant(
          of: find.byKey(LevelsScreen.headerKey),
          matching: find.byKey(LevelCategoryCard.medalKey),
        ),
      );
      expect(medal.center.dx, lessThan(header.center.dx));
    });
  });

  group('ProfileLevels', () {
    Future<FakeLevelsRepository> pump(
      WidgetTester tester, {
      String? username,
      List<Map<String, dynamic>>? summaries,
      VoidCallback? onOpen,
      AppLanguage language = AppLanguage.en,
    }) async {
      final repo = FakeLevelsRepository(summaries: summaries);
      await pumpScreen(
        tester,
        Scaffold(
          body: ProfileLevels(username: username, onOpen: onOpen),
        ),
        language: language,
        overrides: [levelsRepositoryProvider.overrideWithValue(repo)],
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('one badge per active category, never points', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, username: 'layla.k');
      expect(find.byType(KLevelBadge), findsNWidgets(3));
      expect(find.text('37'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.textContaining('12,500'), findsNothing);
      expect(
        tester.getSemantics(find.byKey(ProfileLevels.rowKey)),
        matchesSemantics(
          label: [
            'Attractiveness: ${_en.levelsLevelNumber(37)}',
            'Support: ${_en.levelsLevelNumber(2)}',
            'Wizard: ${_en.levelsLevelNumber(100)}',
          ].join('، '),
        ),
      );
      handle.dispose();
    });

    testWidgets('nothing when no category is active', (tester) async {
      await pump(tester, summaries: allUnavailableJson());
      expect(find.byKey(ProfileLevels.rowKey), findsNothing);
    });

    testWidgets('your own badges open My levels', (tester) async {
      var opened = 0;
      await pump(tester, onOpen: () => opened++);
      await tester.tap(find.byType(KLevelBadge).first);
      expect(opened, 1);
    });

    testWidgets('sits under the name in the profile header (RTL)', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        const Scaffold(
          body: ProfileHeaderView(
            displayName: 'ليلى',
            followers: 5,
            following: 3,
            levels: ProfileLevels(username: 'layla.k'),
            actions: SizedBox(height: 40),
          ),
        ),
        language: AppLanguage.ar,
        overrides: [
          levelsRepositoryProvider.overrideWithValue(
            FakeLevelsRepository(summaries: mixedLevelsJson(arabic: true)),
          ),
        ],
      );
      await tester.pumpAndSettle();
      final name = tester.getRect(find.text('ليلى'));
      final first = tester.getRect(find.byType(KLevelBadge).first);
      expect(first.top, greaterThan(name.bottom));
      // Reading start in Arabic is the right.
      expect(first.right, closeTo(name.right, 1));
    });
  });

  group('goldens', () {
    forEachLanguage((language) {
      final arabic = language == AppLanguage.ar;
      testWidgets('levels screen (${language.name})', tags: [goldenTag], (
        tester,
      ) async {
        await loadAppFonts();
        await _pumpRouted(
          tester,
          FakeLevelsRepository(summaries: mixedLevelsJson(arabic: arabic)),
          language: language,
        );
        await precacheImages(tester);
        await expectLater(
          find.byType(LevelsScreen),
          matchesGoldenFile(
            '../../goldens/png/levels.${language.name}.phone.png',
          ),
        );
      });

      testWidgets(
        'profile header with level badges (${language.name})',
        tags: [goldenTag],
        (tester) async {
          await loadAppFonts();
          setViewport(tester, GoldenViewport.phone);
          final prefs = await testPrefs(language: language.name);
          await tester.pumpWidget(
            ProviderScope(
              retry: (_, _) => null,
              overrides: [
                sharedPreferencesProvider.overrideWithValue(prefs),
                levelsRepositoryProvider.overrideWithValue(
                  FakeLevelsRepository(
                    summaries: mixedLevelsJson(arabic: arabic),
                  ),
                ),
              ],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
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
                home: Scaffold(
                  body: SafeArea(
                    child: ProfileHeaderView(
                      displayName: arabic ? 'ليلى' : 'Layla',
                      bio: arabic ? 'موسيقى كل مساء' : 'Music every evening',
                      followers: 5600,
                      following: 120,
                      levels: const ProfileLevels(username: 'layla.k'),
                      actions: const SizedBox(height: 40),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await precacheImages(tester);
          await expectLater(
            find.byType(ProfileHeaderView),
            matchesGoldenFile(
              '../../goldens/png/profile_levels.${language.name}.phone.png',
            ),
          );
        },
      );

      testWidgets('level detail (${language.name})', tags: [goldenTag], (
        tester,
      ) async {
        await loadAppFonts();
        await _pumpRouted(
          tester,
          FakeLevelsRepository(
            summaries: mixedLevelsJson(arabic: arabic),
            detail: supportDetailJson(arabic: arabic),
          ),
          language: language,
          initial: AppRoutes.level('support'),
        );
        await precacheImages(tester);
        await expectLater(
          find.byType(LevelDetailScreen),
          matchesGoldenFile(
            '../../goldens/png/level_detail.${language.name}.phone.png',
          ),
        );
      });
    });
  });
}
