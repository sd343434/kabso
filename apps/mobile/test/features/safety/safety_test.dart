// KL-060 part D3: block, mute and report of users, the blocked accounts
// list and privacy settings (CONVENTIONS §11.7) — the wire calls, the
// profile and post menus, and the two Settings screens.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/features/safety/safety_screens.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_posts_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

UserSummary _user(String name) => UserSummary(
  id: 'u-$name',
  username: name,
  displayName: name.toUpperCase(),
  avatarUrl: null,
);

void main() {
  group('wire', () {
    late FakeHttpAdapter http;
    late SafetyRepositoryImpl repo;
    const base = '/api/v1';

    setUp(() {
      http = FakeHttpAdapter();
      repo = SafetyRepositoryImpl(
        Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
          ..httpClientAdapter = http,
      );
    });

    test('block, mute, blocks, report and privacy', () async {
      http
        ..on(
          'PUT',
          '$base/users/sam/block',
          (_) => const FakeResponse(200, body: {'blocked': true}),
        )
        ..on(
          'DELETE',
          '$base/users/sam/block',
          (_) => const FakeResponse(200, body: {'blocked': false}),
        )
        ..on(
          'PUT',
          '$base/users/sam/mute',
          (_) => const FakeResponse(200, body: {'muted': true}),
        )
        ..on(
          'GET',
          '$base/me/blocks',
          (_) => const FakeResponse(
            200,
            body: {
              'data': [
                {
                  'id': 'u1',
                  'username': 'sam',
                  'displayName': 'Sam',
                  'avatarUrl': null,
                },
              ],
              'page': {'nextCursor': null, 'hasMore': false},
            },
          ),
        )
        ..on(
          'POST',
          '$base/reports',
          (_) => const FakeResponse(201, body: {'id': 'r1'}),
        )
        ..on(
          'GET',
          '$base/me/privacy',
          (_) => const FakeResponse(
            200,
            body: {
              'whoCanMention': 'EVERYONE',
              'defaultWhoCanComment': 'FOLLOWERS',
            },
          ),
        )
        ..on(
          'PATCH',
          '$base/me/privacy',
          (_) => const FakeResponse(
            200,
            body: {
              'whoCanMention': 'NOBODY',
              'defaultWhoCanComment': 'FOLLOWERS',
            },
          ),
        );
      expect(await repo.setBlocked('sam', blocked: true), isTrue);
      expect(await repo.setBlocked('sam', blocked: false), isFalse);
      expect(await repo.setMuted('sam', muted: true), isTrue);
      expect((await repo.blocks()).items.single.username, 'sam');
      await repo.reportUser('u1', ReportReason.harassment);
      expect(http.requestsTo('POST', '$base/reports').single.data, {
        'targetType': 'USER',
        'targetId': 'u1',
        'reason': 'HARASSMENT',
      });
      final p = await repo.privacy();
      expect(p.defaultWhoCanComment, WhoCanComment.followers);
      final next = await repo.updatePrivacy(
        whoCanMention: MentionPolicy.nobody,
      );
      expect(next.whoCanMention, MentionPolicy.nobody);
      expect(http.requestsTo('PATCH', '$base/me/privacy').single.data, {
        'whoCanMention': 'NOBODY',
      });
    });
  });

  group('screens', () {
    Future<(FakeSafetyRepository, FakePostsRepository, GoRouter)> pump(
      WidgetTester tester, {
      String initial = '/settings',
      FakeSafetyRepository? safety,
      Widget? home,
      AppLanguage language = AppLanguage.en,
      GoldenViewport viewport = GoldenViewport.phone,
    }) async {
      final s = safety ?? FakeSafetyRepository();
      final posts = FakePostsRepository();
      final router = GoRouter(
        initialLocation: '/start',
        routes: [
          GoRoute(
            path: '/start',
            builder: (_, _) => const Scaffold(body: Text('start')),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, _) => const SettingsScreen(),
          ),
          GoRoute(
            path: AppRoutes.privacy,
            builder: (_, _) => const PrivacyScreen(),
          ),
          GoRoute(
            path: AppRoutes.blockedAccounts,
            builder: (_, _) => const BlockedAccountsScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => Scaffold(body: ListView(children: [?home])),
          ),
          GoRoute(
            path: AppRoutes.userProfilePattern,
            builder: (_, st) =>
                PublicProfileScreen(username: st.pathParameters['username']!),
          ),
        ],
      );
      setViewport(tester, viewport);
      final prefs = await testPrefs(language: language.name);
      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            safetyRepositoryProvider.overrideWithValue(s),
            postsRepositoryProvider.overrideWithValue(posts),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(apiProfile()),
            ),
            profileGridProvider.overrideWith(
              (ref, _) => const FeedItems<ProfileGridItem>([]),
            ),
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
      unawaited(router.push(initial));
      await tester.pumpAndSettle();
      return (s, posts, router);
    }

    testWidgets('profile menu: mute with Undo, report with a reason, block '
        'after confirming goes back', (tester) async {
      final (safety, _, router) = await pump(
        tester,
        initial: AppRoutes.userProfile('host0'),
      );
      Future<void> menu() async {
        await tester.tap(find.byKey(PublicProfileScreen.moreKey));
        await tester.pumpAndSettle();
      }

      await menu();
      await tester.tap(find.byKey(PublicProfileScreen.muteKey));
      await tester.pumpAndSettle();
      expect(safety.calls, contains('mute:host0:true'));
      expect(find.text(_en.safetyMuted('Sara')), findsOneWidget);
      await tester.tap(find.text(_en.safetyUndo));
      await tester.pumpAndSettle();
      expect(safety.calls, contains('mute:host0:false'));

      await menu();
      await tester.tap(find.byKey(PublicProfileScreen.reportKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.safetyReportTitle), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('feed.post.report.spam')));
      await tester.pumpAndSettle();
      expect(safety.calls, contains('reportUser:user-0:SPAM'));

      await menu();
      await tester.tap(find.byKey(PublicProfileScreen.blockKey));
      await tester.pumpAndSettle();
      expect(find.text(_en.safetyBlockTitle('Sara')), findsOneWidget);
      await tester.tap(find.byKey(const Key('safety.block.confirm')));
      await tester.pumpAndSettle();
      expect(safety.calls, contains('block:host0:true'));
      expect(router.state.uri.path, '/start');
    });

    testWidgets('post menu: mute the author', (tester) async {
      final (safety, _, _) = await pump(
        tester,
        initial: '/home',
        home: FeedPostTile(post: feedPostOf(testPost('p1'))),
      );
      await tester.tap(find.byKey(FeedPostTile.moreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FeedPostTile.muteActionKey));
      await tester.pumpAndSettle();
      expect(safety.calls, contains('mute:sara:true'));
      expect(find.text(_en.safetyMuted('Sara')), findsOneWidget);
    });

    testWidgets('Settings opens privacy: a change is saved at once; a failed '
        'change keeps the old choice', (tester) async {
      final (safety, _, router) = await pump(tester);
      await tester.tap(find.byKey(SettingsScreen.privacyKey));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.privacy);
      RadioGroup<MentionPolicy> group() =>
          tester.widget(find.byType(RadioGroup<MentionPolicy>));
      expect(group().groupValue, MentionPolicy.everyone);
      await tester.tap(
        find.byKey(PrivacyScreen.mentionKey(MentionPolicy.following)),
      );
      await tester.pumpAndSettle();
      expect(safety.calls, contains('updatePrivacy:FOLLOWING:'));
      expect(group().groupValue, MentionPolicy.following);
      expect(find.text(_en.privacySaved), findsOneWidget);

      safety.failWith = const NetworkFailure.offline();
      await tester.tap(
        find.byKey(PrivacyScreen.commentKey(WhoCanComment.nobody)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<RadioGroup<WhoCanComment>>(
              find.byType(RadioGroup<WhoCanComment>),
            )
            .groupValue,
        WhoCanComment.everyone,
      );
    });

    testWidgets('blocked accounts: Unblock removes them; none says so', (
      tester,
    ) async {
      final safety = FakeSafetyRepository(
        blockedUsers: [_user('sam'), _user('nora')],
      );
      final (_, _, router) = await pump(tester, safety: safety);
      await tester.tap(find.byKey(SettingsScreen.blockedKey));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.blockedAccounts);
      expect(find.text('SAM'), findsOneWidget);
      await tester.tap(find.byKey(BlockedAccountsScreen.unblockKey('sam')));
      await tester.pumpAndSettle();
      expect(safety.calls, contains('block:sam:false'));
      expect(find.text('SAM'), findsNothing);
      expect(find.text(_en.safetyUnblocked('SAM')), findsOneWidget);
      await tester.tap(find.byKey(BlockedAccountsScreen.unblockKey('nora')));
      await tester.pumpAndSettle();
      expect(find.byKey(BlockedAccountsScreen.emptyKey), findsOneWidget);
    });

    testWidgets('Arabic RTL at 360 dp and text scale 1.3: privacy and '
        'blocked screens fit', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (_, _, router) = await pump(
        tester,
        initial: AppRoutes.privacy,
        safety: FakeSafetyRepository(
          blockedUsers: [_user('a_very_long_username_for_testing')],
        ),
        language: AppLanguage.ar,
        viewport: GoldenViewport.android,
      );
      expect(tester.takeException(), isNull);
      router.go(AppRoutes.blockedAccounts);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
