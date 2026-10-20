// D72: the four level systems (CP-005) — models, art tiers, the repository
// against a mocked Dio adapter, the levels and detail screens with honest
// states, navigation, Arabic RTL / English LTR and small screens.

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

  @override
  Future<LevelDetail> getMyLevel(LevelCategory category) async {
    calls++;
    if (failure case final f?) throw f;
    return LevelDetail.fromJson(detail ?? supportDetailJson());
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

    test('every category has its 11 emblems bundled', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      for (final c in LevelCategory.values) {
        for (var t = 1; t <= KLevelArt.tiers; t++) {
          final data = await rootBundle.load(KLevelArt.asset(c, t));
          expect(data.lengthInBytes, greaterThan(1000));
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

  group('LevelsScreen', () {
    testWidgets('four cards in order with level, points and progress', (
      tester,
    ) async {
      await _pumpRouted(tester, FakeLevelsRepository());
      for (final c in LevelCategory.values) {
        expect(find.byKey(LevelsScreen.cardKey(c)), findsOneWidget);
      }
      expect(
        find.text('Rising star · ${_en.levelsLevelNumber(37)}'),
        findsOneWidget,
      );
      expect(
        find.textContaining(_en.levelsPoints('12,500'), findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(_en.levelsToNext('500'), findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining(_en.levelsMax, findRichText: true),
        findsOneWidget,
      );
      expect(find.text(_en.levelsUnavailable), findsOneWidget);
      expect(find.byType(KLevelProgressBar), findsNWidgets(3));
      expect(find.byKey(LevelsScreen.preparingKey), findsNothing);
    });

    testWidgets('all four unavailable: honest "on their way" banner', (
      tester,
    ) async {
      await _pumpRouted(
        tester,
        FakeLevelsRepository(summaries: allUnavailableJson()),
      );
      expect(find.byKey(LevelsScreen.preparingKey), findsOneWidget);
      expect(find.text(_en.levelsUnavailable), findsNWidgets(4));
      expect(find.byType(KLevelProgressBar), findsNothing);
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
      expect(
        find.byKey(LevelsScreen.cardKey(LevelCategory.support)),
        findsOneWidget,
      );
    });

    testWidgets('a card reads as one button with its whole state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpRouted(tester, FakeLevelsRepository());
      expect(
        tester.getSemantics(
          find.byKey(LevelsScreen.cardKey(LevelCategory.support)),
        ),
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          label: [
            'Support',
            'Supporter · ${_en.levelsLevelNumber(2)}',
            _en.levelsPoints('150'),
            _en.levelsToNext('350'),
          ].join('، '),
        ),
      );
      handle.dispose();
    });

    testWidgets('tapping a card opens its detail with the ladder', (
      tester,
    ) async {
      await _pumpRouted(tester, FakeLevelsRepository());
      await tester.tap(find.byKey(LevelsScreen.cardKey(LevelCategory.support)));
      await tester.pumpAndSettle();
      expect(find.byType(LevelDetailScreen), findsOneWidget);
      expect(find.text(_en.levelsLadder), findsOneWidget);
      expect(find.byKey(LevelDetailScreen.currentKey), findsOneWidget);
      expect(
        find.text(_en.levelsToNamed('350', 'Silver supporter')),
        findsOneWidget,
      );
    });
  });

  group('LevelDetailScreen', () {
    testWidgets('an unavailable category shows its honest state', (
      tester,
    ) async {
      await _pumpRouted(
        tester,
        FakeLevelsRepository(
          detail: {
            ...levelSummaryJson('GAMING', available: false),
            'levels': <Object>[],
          },
        ),
        initial: AppRoutes.level('gaming'),
      );
      expect(find.text(_en.levelsUnavailableBody), findsOneWidget);
      expect(find.text(_en.levelsLadder), findsNothing);
    });

    testWidgets('marks reached and current levels for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpRouted(
        tester,
        FakeLevelsRepository(),
        initial: AppRoutes.level('support'),
      );
      expect(
        tester.getSemantics(find.byKey(LevelDetailScreen.currentKey)),
        matchesSemantics(
          isSelected: true,
          hasSelectedState: true,
          label: [
            'Supporter',
            _en.levelsLevelNumber(2),
            _en.levelsPoints('100'),
            _en.levelsCurrent,
          ].join('، '),
        ),
      );
      handle.dispose();
    });
  });

  group('RTL / small screens', () {
    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: 360×800 at text scale 1.3 does not '
          'overflow', (tester) async {
        final arabic = language == AppLanguage.ar;
        await _pumpRouted(
          tester,
          FakeLevelsRepository(
            summaries: mixedLevelsJson(arabic: arabic),
            detail: supportDetailJson(arabic: arabic),
          ),
          language: language,
          viewport: GoldenViewport.android,
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byKey(LevelsScreen.cardKey(LevelCategory.support)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Arabic: emblems sit at the reading start (right)', (
      tester,
    ) async {
      await _pumpRouted(
        tester,
        FakeLevelsRepository(summaries: mixedLevelsJson(arabic: true)),
        language: AppLanguage.ar,
      );
      final card = find.byKey(LevelsScreen.cardKey(LevelCategory.support));
      final emblem = find.descendant(
        of: card,
        matching: find.byType(KLevelEmblem),
      );
      expect(
        tester.getCenter(emblem).dx,
        greaterThan(tester.getCenter(card).dx),
      );
      expect(
        find.textContaining(_ar.levelsPoints('150'), findRichText: true),
        findsOneWidget,
      );
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
          FakeLevelsRepository(detail: supportDetailJson(arabic: arabic)),
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
