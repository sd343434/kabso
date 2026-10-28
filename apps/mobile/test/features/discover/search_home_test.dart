// D147: the search home (owner's layout reference) — hot searches from
// GET /search/trending, the hashtags of the week, popular lives, the
// rotating hint, Cancel, counting submitted searches (POST /search/queries)
// and the trending hashtags page; honest empty states, Arabic RTL and a
// small screen with large text. D157: the home always shows under an empty
// field — this device's Recent searches, and one quiet hint line when
// there is nothing else (no big empty state).

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/discover/discover_screen.dart';
import 'package:kabso_live/features/discover/recent_searches.dart';
import 'package:kabso_live/features/discover/search_home.dart';
import 'package:kabso_live/features/discover/trending_hashtags_screen.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/hub/live_grid_card.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

const _terms = [
  TrendingSearch(term: 'rising stars', tag: TrendingSearchTag.trending),
  TrendingSearch(term: 'live pk', tag: TrendingSearchTag.trending),
  TrendingSearch(term: 'karaoke'),
  TrendingSearch(term: 'viral moves'),
  TrendingSearch(term: 'cooking'),
  TrendingSearch(term: 'makeup show', tag: TrendingSearchTag.newTerm),
];

const _tags = [
  Hashtag(tag: 'تعارف_عربي', postCount: 41),
  Hashtag(tag: 'musicnight', postCount: 33),
  Hashtag(tag: 'today_meme', postCount: 20),
  Hashtag(tag: 'mood_song', postCount: 12),
  Hashtag(tag: 'petra', postCount: 9),
];

List<LiveRoomSummary> _rooms() => [
  for (final (i, r) in apiRooms(4).indexed)
    r.copyWith(
      viewerCount: 10 * (i + 1),
      mode: i == 0 ? LiveRoomMode.pk : LiveRoomMode.solo,
    ),
];

void main() {
  setUp(() => KLiveEqualizer.animate = false);
  tearDown(() => KLiveEqualizer.animate = true);

  test(
    'wire: trending, trending hashtags (limit) and recording a search',
    () async {
      final http = FakeHttpAdapter();
      final repo = PostsRepositoryImpl(
        Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
          ..httpClientAdapter = http,
      );
      const base = '/api/v1';
      http
        ..on(
          'GET',
          '$base/search/trending',
          (_) => const FakeResponse(
            200,
            body: {
              'data': [
                {'term': 'live pk', 'tag': 'TRENDING'},
                {'term': 'karaoke', 'tag': null},
                {'term': 'makeup', 'tag': 'NEW'},
                {'term': 'future', 'tag': 'SOMETHING_ELSE'},
              ],
            },
          ),
        )
        ..on(
          'GET',
          '$base/search/trending-hashtags',
          (_) => const FakeResponse(
            200,
            body: {
              'data': [
                {'tag': 'petra', 'postCount': 4},
              ],
            },
          ),
        )
        ..on('POST', '$base/search/queries', (_) => const FakeResponse(204));
      expect(await repo.trendingSearches(), const [
        TrendingSearch(term: 'live pk', tag: TrendingSearchTag.trending),
        TrendingSearch(term: 'karaoke'),
        TrendingSearch(term: 'makeup', tag: TrendingSearchTag.newTerm),
        TrendingSearch(term: 'future'),
      ]);
      final tags = await repo.trendingHashtags(limit: 5);
      expect(tags.single.tag, 'petra');
      expect(http.requests.last.queryParameters, {'limit': 5});
      await repo.recordSearch('live pk');
      expect(http.requests.last.data, {'q': 'live pk'});
    },
  );

  Future<(FakePostsRepository, GoRouter)> pump(
    WidgetTester tester, {
    List<TrendingSearch> terms = _terms,
    List<Hashtag> tags = _tags,
    List<LiveRoomSummary>? rooms,
    AppLanguage language = AppLanguage.en,
    GoldenViewport viewport = GoldenViewport.phone,
    FakePostsRepository? repo,
    FakeLiveRepository? live,
    List<String>? recent,
  }) async {
    final posts = (repo ?? FakePostsRepository())
      ..trending = terms
      ..trendingTags = tags;
    final lives =
        live ?? FakeLiveRepository(rooms: (_) => apiPage(rooms ?? _rooms()));
    final router = GoRouter(
      initialLocation: '/start',
      routes: [
        GoRoute(
          path: '/start',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push(AppRoutes.discover),
              child: const Text('open search'),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.discover,
          builder: (_, _) => const DiscoverScreen(),
        ),
        GoRoute(
          path: AppRoutes.trendingHashtags,
          builder: (_, _) => const TrendingHashtagsScreen(),
        ),
        GoRoute(
          path: AppRoutes.hashtagPattern,
          builder: (_, s) =>
              Scaffold(body: Text('tag ${s.pathParameters['tag']}')),
        ),
        GoRoute(
          path: AppRoutes.userProfilePattern,
          builder: (_, s) =>
              Scaffold(body: Text('profile ${s.pathParameters['username']}')),
        ),
        GoRoute(
          path: '${AppRoutes.home}/room/:roomId',
          builder: (_, s) =>
              Scaffold(body: Text('room ${s.pathParameters['roomId']}')),
        ),
      ],
    );
    // A fresh tree for each pump within one test.
    await tester.pumpWidget(const SizedBox());
    setViewport(tester, viewport);
    final prefs = await testPrefs(
      language: language.name,
      extra: {_recentKey: ?recent},
    );
    _prefs = prefs;
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          postsRepositoryProvider.overrideWithValue(posts),
          liveRepositoryProvider.overrideWithValue(lives),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          currentUserProvider.overrideWithValue(testUser()),
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
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open search'));
    await tester.pumpAndSettle();
    return (posts, router);
  }

  testWidgets('the three sections from real endpoints: ranks, tags, '
      'hashtags with More, lives', (tester) async {
    final (repo, _) = await pump(tester);
    expect(find.byKey(SearchHome.hotKey), findsOneWidget);
    expect(find.text(_en.searchHotTitle), findsOneWidget);
    for (final t in _terms) {
      expect(find.byKey(SearchHome.hotRowKey(t.term)), findsOneWidget);
    }
    expect(find.text(_en.searchTagTrending), findsNWidgets(2));
    expect(find.text(_en.searchTagNew), findsOneWidget);
    expect(find.text(_en.searchHotTakeTitle), findsOneWidget);
    // Four hashtags on the home, a fifth exists: More is offered.
    expect(find.byKey(SearchHome.topicKey('petra')), findsNothing);
    expect(find.byKey(SearchHome.topicKey('mood_song')), findsOneWidget);
    expect(find.byKey(SearchHome.moreKey), findsOneWidget);
    expect(repo.calls, contains('trendingTags:5'));
    await tester.scrollUntilVisible(
      find.byKey(SearchHome.liveKey('room-0')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(_en.searchMayLikeTitle), findsOneWidget);
    expect(find.text(_en.pkBadge), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hot search searches it; opening a result counts it once; '
      'typing alone never counts', (tester) async {
    final repo = FakePostsRepository()
      ..people = const [
        UserSummary(
          id: 'u1',
          username: 'karaoke_k1',
          displayName: 'Karaoke King',
          avatarUrl: null,
        ),
      ];
    final (_, router) = await pump(tester, repo: repo);
    await tester.tap(find.byKey(SearchHome.hotRowKey('karaoke')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(DiscoverScreen.fieldKey));
    expect(field.controller!.text, 'karaoke');
    expect(repo.calls, contains('search:users:karaoke:'));
    expect(repo.recorded, isEmpty);
    await tester.tap(find.byKey(DiscoverScreen.userKey('karaoke_k1')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.userProfile('karaoke_k1'));
    expect(repo.recorded, ['karaoke']);
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(DiscoverScreen.userKey('karaoke_k1')));
    await tester.pumpAndSettle();
    expect(repo.recorded, ['karaoke']);
    router.pop();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(DiscoverScreen.fieldKey), 'kar');
    await tester.pump(DiscoverScreen.debounce);
    await tester.pumpAndSettle();
    expect(repo.recorded, ['karaoke']);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(repo.recorded, ['karaoke', 'kar']);
  });

  testWidgets('a hashtag opens its page; More opens the week list; a live '
      'opens the room', (tester) async {
    final (_, router) = await pump(tester);
    await tester.tap(find.byKey(SearchHome.topicKey('musicnight')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.hashtag('musicnight'));
    router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(SearchHome.moreKey));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.trendingHashtags);
    expect(find.text(_en.trendingHashtagsTitle), findsOneWidget);
    expect(find.byKey(TrendingHashtagsScreen.rowKey('petra')), findsOneWidget);
    expect(find.text(_en.trendingHashtagWeekCount(41)), findsOneWidget);
    await tester.tap(find.byKey(TrendingHashtagsScreen.rowKey('petra')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.hashtag('petra'));
    router
      ..pop()
      ..pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(SearchHome.liveKey('room-1')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(SearchHome.liveKey('room-1')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, AppRoutes.liveRoom('room-1'));
  });

  testWidgets('honest states: fewer than 3 terms hide Hot Searches; no '
      'hashtags or lives hide theirs; nothing at all shows the search home '
      'with a one-line hint (D157); failures hide a section', (tester) async {
    await pump(
      tester,
      terms: _terms.take(2).toList(),
      tags: _tags.take(4).toList(),
    );
    expect(find.byKey(SearchHome.hotKey), findsNothing);
    expect(find.byKey(SearchHome.topicsKey), findsOneWidget);
    // Exactly four: no More (it would lead nowhere new).
    expect(find.byKey(SearchHome.moreKey), findsNothing);
    // The hint still rotates through the terms there are.
    expect(find.text(_en.searchTryHint('rising stars')), findsOneWidget);

    await pump(tester, terms: const [], tags: const [], rooms: const []);
    expect(find.byKey(SearchHome.hotKey), findsNothing);
    expect(find.byKey(SearchHome.topicsKey), findsNothing);
    expect(find.byKey(SearchHome.livesKey), findsNothing);
    // D157: still the search home (not the old big empty state), with one
    // quiet line; nothing made up.
    expect(find.byType(SearchHome), findsOneWidget);
    expect(find.byType(KEmptyState), findsNothing);
    expect(find.text(_en.searchPromptTitle), findsNothing);
    expect(find.byKey(SearchHome.hintKey), findsOneWidget);
    expect(find.text(_en.searchPromptBody), findsOneWidget);
    expect(find.byKey(SearchHome.recentKey), findsNothing);
    expect(find.text(_en.searchHint), findsOneWidget);

    final failing = FakeLiveRepository(rooms: (_) => throw roomNotFound);
    await pump(tester, live: failing);
    expect(find.byKey(SearchHome.hotKey), findsOneWidget);
    expect(find.byKey(SearchHome.livesKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the hint rotates through the trending terms', (tester) async {
    await pump(tester);
    expect(find.text(_en.searchTryHint('rising stars')), findsOneWidget);
    await tester.pump(KSearchHome.hintPeriod);
    expect(find.text(_en.searchTryHint('live pk')), findsOneWidget);
  });

  testWidgets('Cancel closes the search', (tester) async {
    final (_, router) = await pump(tester);
    await tester.tap(find.byKey(DiscoverScreen.cancelKey));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/start');
  });

  testWidgets('the trending hashtags page says when there are none', (
    tester,
  ) async {
    final (_, router) = await pump(tester, tags: const []);
    unawaited(router.push<void>(AppRoutes.trendingHashtags));
    await tester.pumpAndSettle();
    expect(find.byKey(TrendingHashtagsScreen.emptyKey), findsOneWidget);
    expect(find.text(_en.trendingHashtagsEmpty), findsOneWidget);
  });

  testWidgets('Arabic RTL: mirrored rows (rank at the start, tag at the '
      'end), "#" in front of Latin tags, Cancel at the end', (tester) async {
    await pump(tester, language: AppLanguage.ar);
    final row = find.byKey(SearchHome.hotRowKey('rising stars'));
    final rank = tester.getRect(
      find.descendant(of: row, matching: find.text('1')),
    );
    final tag = tester.getRect(
      find.descendant(of: row, matching: find.text(_ar.searchTagTrending)),
    );
    expect(rank.left, greaterThan(tag.right));
    final cancel = tester.getRect(find.byKey(DiscoverScreen.cancelKey));
    final field = tester.getRect(find.byKey(DiscoverScreen.fieldKey));
    expect(cancel.right, lessThan(field.left));
    final latin = tester.widget<Text>(
      find.descendant(
        of: find.byKey(SearchHome.topicKey('musicnight')),
        matching: find.byType(Text),
      ),
    );
    expect(latin.textDirection, TextDirection.ltr);
    expect(find.text(_ar.searchHotTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final language in AppLanguage.values) {
    testWidgets('${language.name} at 360 dp and text scale 1.3: no overflow', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(
        tester,
        language: language,
        viewport: GoldenViewport.android,
        terms: [
          ..._terms.take(5),
          const TrendingSearch(
            term: 'a very long trending search term that cannot fit at all',
            tag: TrendingSearchTag.trending,
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(SearchHome.liveKey('room-3')),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(tester.takeException(), isNull);
    });
  }

  group('D157 recent searches', () {
    testWidgets('staging-like (no trends, no hashtags, no lives): the search '
        "home with this device's history; no hint then", (tester) async {
      await pump(
        tester,
        terms: const [],
        tags: const [],
        rooms: const [],
        recent: const ['karaoke', 'Petra'],
      );
      expect(find.byType(SearchHome), findsOneWidget);
      expect(find.byKey(SearchHome.recentKey), findsOneWidget);
      expect(find.text(_en.searchRecentTitle), findsOneWidget);
      expect(find.byKey(SearchHome.recentTermKey('karaoke')), findsOneWidget);
      expect(find.byKey(SearchHome.recentTermKey('Petra')), findsOneWidget);
      expect(find.byKey(SearchHome.hintKey), findsNothing);
      expect(find.byKey(SearchHome.hotKey), findsNothing);
      expect(find.byType(KEmptyState), findsNothing);
    });

    testWidgets('a submitted search, a hot term and an opened result go to '
        'the front of the history, once each; kept on the device', (
      tester,
    ) async {
      final repo = FakePostsRepository()
        ..people = const [
          UserSummary(
            id: 'u1',
            username: 'karaoke_k1',
            displayName: 'Karaoke King',
            avatarUrl: null,
          ),
        ];
      final (_, router) = await pump(tester, repo: repo);
      expect(find.byKey(SearchHome.recentKey), findsNothing);

      await tester.enterText(find.byKey(DiscoverScreen.fieldKey), '  #Petra ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(_saved(), ['Petra']);

      await tester.tap(find.byKey(DiscoverScreen.clearKey));
      await tester.pumpAndSettle();
      expect(find.byKey(SearchHome.recentTermKey('Petra')), findsOneWidget);
      // Above Hot Searches.
      expect(
        tester.getTopLeft(find.byKey(SearchHome.recentKey)).dy,
        lessThan(tester.getTopLeft(find.byKey(SearchHome.hotKey)).dy),
      );

      await tester.tap(find.byKey(SearchHome.hotRowKey('karaoke')));
      await tester.pumpAndSettle();
      expect(_saved(), ['karaoke', 'Petra']);
      await tester.tap(find.byKey(DiscoverScreen.userKey('karaoke_k1')));
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      expect(_saved(), ['karaoke', 'Petra'], reason: 'no duplicates');

      // The same query in other letters replaces the old one.
      await tester.enterText(find.byKey(DiscoverScreen.fieldKey), 'petra');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(_saved(), ['petra', 'karaoke']);
    });

    testWidgets('a chip searches again; ✕ forgets one; Clear all forgets '
        'all', (tester) async {
      final repo = FakePostsRepository();
      await pump(tester, repo: repo, recent: const ['alpha', 'beta', 'gamma']);
      await tester.tap(find.byKey(SearchHome.recentTermKey('beta')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(DiscoverScreen.fieldKey),
      );
      expect(field.controller!.text, 'beta');
      expect(repo.calls, contains('search:users:beta:'));
      expect(_saved(), ['beta', 'alpha', 'gamma']);
      expect(repo.recorded, isEmpty, reason: 'history is not a trend count');
      await tester.tap(find.byKey(DiscoverScreen.clearKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(SearchHome.recentRemoveKey('alpha')));
      await tester.pumpAndSettle();
      expect(find.byKey(SearchHome.recentTermKey('alpha')), findsNothing);
      expect(_saved(), ['beta', 'gamma']);
      expect(find.byTooltip(_en.searchRecentRemove('gamma')), findsOneWidget);

      await tester.tap(find.byKey(SearchHome.recentClearKey));
      await tester.pumpAndSettle();
      expect(find.byKey(SearchHome.recentKey), findsNothing);
      expect(_saved(), isNull);
      // The other sections are untouched.
      expect(find.byKey(SearchHome.hotKey), findsOneWidget);
    });

    test('at most ten, newest first, per account', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      );
      addTearDown(container.dispose);
      final recent = container.read(recentSearchesProvider.notifier);
      for (var i = 0; i < 12; i++) {
        recent.add('term $i');
      }
      expect(container.read(recentSearchesProvider), [
        for (var i = 11; i >= 2; i--) 'term $i',
      ]);
      expect(RecentSearchesController.maxCount, 10);
      recent.add('   ');
      expect(container.read(recentSearchesProvider).length, 10);

      // Another account on the phone sees none of them.
      final other = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentUserProvider.overrideWithValue(
            testUser().copyWith(id: 'someone-else'),
          ),
        ],
      );
      addTearDown(other.dispose);
      expect(other.read(recentSearchesProvider), isEmpty);
    });

    testWidgets('Arabic RTL: the title at the start (right), Clear all at '
        'the end; Latin terms read left to right', (tester) async {
      await pump(
        tester,
        language: AppLanguage.ar,
        recent: const ['طبخ', 'karaoke'],
      );
      final title = tester.getRect(find.text(_ar.searchRecentTitle));
      final clear = tester.getRect(find.byKey(SearchHome.recentClearKey));
      expect(title.right, greaterThan(clear.right));
      final first = tester.getRect(find.byKey(SearchHome.recentTermKey('طبخ')));
      final second = tester.getRect(
        find.byKey(SearchHome.recentTermKey('karaoke')),
      );
      expect(first.top, second.top, reason: 'one line');
      expect(first.left, greaterThan(second.left), reason: 'newest first');
      final latin = tester.widget<Text>(
        find.descendant(
          of: find.byKey(SearchHome.recentTermKey('karaoke')),
          matching: find.byType(Text),
        ),
      );
      expect(latin.textDirection, TextDirection.ltr);
      expect(tester.takeException(), isNull);
    });

    for (final language in AppLanguage.values) {
      testWidgets('${language.name} at 360 dp, text scale 1.3: long recent '
          'terms and the hint do not overflow', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pump(
          tester,
          language: language,
          viewport: GoldenViewport.android,
          recent: const [
            'a very long recent search term that cannot fit on one line',
            'pk',
          ],
        );
        expect(tester.takeException(), isNull);
        await pump(
          tester,
          language: language,
          viewport: GoldenViewport.android,
          terms: const [],
          tags: const [],
          rooms: const [],
        );
        expect(find.byKey(SearchHome.hintKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

final _recentKey = 'pref.recentSearches.${testUser().id}';
late SharedPreferences _prefs;
List<String>? _saved() => _prefs.getStringList(_recentKey);
