// CP-009 (D92): in-app notifications in the app — the bell and its badge
// on the Posts header (polled), the inbox grouped by day with navigation,
// and the settings page; wire format, Arabic RTL and English LTR.

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
import 'package:kabso_live/features/notifications/application/notifications_controller.dart';
import 'package:kabso_live/features/notifications/data/notifications_repository.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_notifications_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

UserSummary _user(String username, [String? name]) => UserSummary(
  id: 'u-$username',
  username: username,
  displayName: name ?? '',
  avatarUrl: null,
);

AppNotification _note(
  String id,
  NotificationType type, {
  List<UserSummary> actors = const [],
  int? actorCount,
  NotificationTarget? target,
  DateTime? at,
  bool read = false,
}) => AppNotification(
  id: id,
  type: type,
  actors: actors,
  actorCount: actorCount ?? actors.length,
  target: target,
  createdAt: at ?? DateTime.now(),
  read: read,
);

void main() {
  group('wire', () {
    late FakeHttpAdapter http;
    late NotificationsRepositoryImpl repo;
    const base = '/api/v1';

    setUp(() {
      http = FakeHttpAdapter();
      repo = NotificationsRepositoryImpl(
        Dio(BaseOptions(baseUrl: 'https://api.example.test/api/v1'))
          ..httpClientAdapter = http,
      );
    });

    test('inbox, unread count, mark read, settings', () async {
      const settings = {
        'likes': false,
        'comments': true,
        'mentions': true,
        'follows': true,
        'reposts': true,
      };
      http
        ..on(
          'GET',
          '$base/notifications',
          (_) => const FakeResponse(
            200,
            body: {
              'data': [
                {
                  'id': 'n1',
                  'type': 'LIKE_POST',
                  'actors': [
                    {
                      'id': 'u1',
                      'username': 'sara',
                      'displayName': 'Sara',
                      'avatarUrl': null,
                    },
                  ],
                  'actorCount': 3,
                  'target': {
                    'type': 'POST',
                    'id': 'p1',
                    'postId': null,
                    'thumbUrl': 'https://media.example.test/media/m1/320.webp',
                    'text': 'hello',
                  },
                  'createdAt': '2026-10-21T09:00:00.000Z',
                  'read': false,
                },
                {
                  'id': 'n2',
                  'type': 'SOMETHING_NEW',
                  'actors': <Object?>[],
                  'actorCount': 0,
                  'target': null,
                  'createdAt': '2026-10-21T08:00:00.000Z',
                  'read': true,
                },
              ],
              'page': {'nextCursor': 'c2', 'hasMore': true},
            },
          ),
        )
        ..on(
          'GET',
          '$base/notifications/unread-count',
          (_) => const FakeResponse(200, body: {'count': 7}),
        )
        ..on('POST', '$base/notifications/read', (_) => const FakeResponse(204))
        ..on(
          'GET',
          '$base/me/notification-settings',
          (_) => const FakeResponse(200, body: settings),
        )
        ..on(
          'PATCH',
          '$base/me/notification-settings',
          (_) => const FakeResponse(200, body: settings),
        );
      final page = await repo.list(cursor: 'c1');
      expect(http.requests.last.queryParameters, {'cursor': 'c1'});
      expect(page.next, 'c2');
      final n = page.items.first;
      expect(n.type, NotificationType.likePost);
      expect(n.actorCount, 3);
      expect(n.target!.type, NotificationTargetType.post);
      expect(n.target!.thumbUrl, endsWith('/320.webp'));
      expect(page.items.last.type, NotificationType.unknown);
      expect(await repo.unreadCount(), 7);
      await repo.markRead();
      expect(http.requests.last.data, {'all': true});
      await repo.markRead(ids: ['n1']);
      expect(http.requests.last.data, {
        'ids': ['n1'],
      });
      expect((await repo.settings()).likes, isFalse);
      await repo.updateSetting(NotificationSetting.likes, on: false);
      expect(http.requests.last.data, {'likes': false});
    });
  });

  group('screens', () {
    Future<(FakeNotificationsRepository, GoRouter)> pump(
      WidgetTester tester, {
      required FakeNotificationsRepository repo,
      String initial = '/home',
      AppLanguage language = AppLanguage.en,
      GoldenViewport viewport = GoldenViewport.phone,
    }) async {
      final router = GoRouter(
        initialLocation: initial,
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) =>
                Scaffold(appBar: AppBar(actions: const [NotificationsBell()])),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (_, _) => const NotificationsScreen(),
          ),
          GoRoute(
            path: AppRoutes.notificationSettings,
            builder: (_, _) => const NotificationSettingsScreen(),
          ),
          GoRoute(
            path: '/posts/:postId',
            builder: (_, s) => Text('post ${s.uri}'),
          ),
          GoRoute(
            path: '/users/:username',
            builder: (_, s) => Text('user ${s.pathParameters['username']}'),
          ),
          GoRoute(
            path: '/stories/:username',
            builder: (_, s) => Text('stories ${s.pathParameters['username']}'),
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
            notificationsRepositoryProvider.overrideWithValue(repo),
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
              brightness: Brightness.dark,
              locale: language.locale,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (repo, router);
    }

    testWidgets('the bell shows the unread count (99+ at 99), refreshes '
        'every 60 seconds and opens the inbox', (tester) async {
      final repo = FakeNotificationsRepository()..unread = 0;
      final (_, router) = await pump(tester, repo: repo);
      expect(find.byKey(NotificationsBell.badgeKey), findsNothing);
      expect(find.byTooltip(_en.notificationsBell(0)), findsOneWidget);
      repo.unread = 4;
      await tester.pump(unreadPollInterval);
      await tester.pump();
      expect(repo.calls.where((c) => c == 'unread'), hasLength(2));
      expect(
        find.descendant(
          of: find.byKey(NotificationsBell.badgeKey),
          matching: find.text('4'),
        ),
        findsOneWidget,
      );
      expect(find.byTooltip(_en.notificationsBell(4)), findsOneWidget);
      repo.unread = 99;
      await tester.pump(unreadPollInterval);
      await tester.pump();
      expect(find.text('99+'), findsOneWidget);
      // A failed refresh keeps the last count.
      repo.failWith = Exception('offline');
      await tester.pump(unreadPollInterval);
      await tester.pump();
      expect(find.text('99+'), findsOneWidget);
      await tester.tap(find.byKey(NotificationsBell.bellKey));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.notifications);
    });

    testWidgets('the inbox: grouped by day, who did what, marks everything '
        'read once and clears the badge', (tester) async {
      final now = DateTime.now();
      final repo = FakeNotificationsRepository()
        ..unread = 2
        ..items = [
          _note(
            'n1',
            NotificationType.likePost,
            actors: [_user('sara', 'Sara'), _user('omar')],
            actorCount: 13,
            target: const NotificationTarget(
              type: NotificationTargetType.post,
              id: 'p1',
              text: 'sunset',
            ),
            at: now,
          ),
          _note(
            'n2',
            NotificationType.follow,
            actors: [_user('lina', 'Lina')],
            target: const NotificationTarget(
              type: NotificationTargetType.user,
              id: 'lina',
            ),
            at: now.subtract(const Duration(days: 3)),
          ),
          _note(
            'n3',
            NotificationType.contentRemoved,
            target: const NotificationTarget(
              type: NotificationTargetType.post,
              id: 'p9',
            ),
            at: now.subtract(const Duration(days: 20)),
            read: true,
          ),
        ];
      final (_, router) = await pump(tester, repo: repo);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byKey(NotificationsBell.bellKey));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.notifications);
      for (final s in NotificationSection.values) {
        expect(find.byKey(NotificationsScreen.sectionKey(s)), findsOneWidget);
      }
      final who = _en.notifActors('Sara', 12);
      expect(who, 'Sara and 12 others');
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(_en.notifLikePost(who)))),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(_en.notifFollow(_en.notifActors('Lina', 0)))),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(_en.notifRemovedPost))),
        findsOneWidget,
      );
      expect(repo.calls.where((c) => c == 'read:all'), hasLength(1));
      // Rows keep their unread look for this visit.
      expect(
        find.bySemanticsLabel(RegExp('^${_en.notifUnread}')),
        findsNWidgets(2),
      );
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(NotificationsBell.badgeKey), findsNothing);
    });

    testWidgets('a row opens its post (a comment opens the comments), the '
        'profile or the story; removed content opens nothing', (tester) async {
      final repo = FakeNotificationsRepository()
        ..items = [
          _note(
            'c',
            NotificationType.reply,
            actors: [_user('sara', 'Sara')],
            target: const NotificationTarget(
              type: NotificationTargetType.comment,
              id: 'c1',
              postId: 'p1',
              text: 'agreed',
            ),
          ),
          _note(
            'f',
            NotificationType.follow,
            actors: [_user('lina')],
            target: const NotificationTarget(
              type: NotificationTargetType.user,
              id: 'lina',
            ),
          ),
          _note(
            's',
            NotificationType.mention,
            actors: [_user('omar')],
            target: const NotificationTarget(
              type: NotificationTargetType.story,
              id: 'st1',
            ),
          ),
          _note(
            'r',
            NotificationType.contentRemoved,
            target: const NotificationTarget(
              type: NotificationTargetType.comment,
              id: 'c9',
              postId: 'p9',
            ),
          ),
        ];
      final (_, router) = await pump(
        tester,
        repo: repo,
        initial: AppRoutes.notifications,
      );
      Future<String> open(String id) async {
        await tester.tap(find.byKey(NotificationsScreen.rowKey(id)));
        await tester.pumpAndSettle();
        final where = router.state.uri.toString();
        if (where != AppRoutes.notifications) {
          router.pop();
          await tester.pumpAndSettle();
        }
        return where;
      }

      expect(await open('c'), '/posts/p1?comments=1');
      expect(await open('f'), '/users/lina');
      expect(await open('s'), '/stories/omar');
      expect(await open('r'), AppRoutes.notifications);
    });

    testWidgets('empty inbox; settings switch at once and go back when the '
        'server refuses', (tester) async {
      final repo = FakeNotificationsRepository();
      final (_, router) = await pump(
        tester,
        repo: repo,
        initial: AppRoutes.notifications,
      );
      expect(find.byKey(NotificationsScreen.emptyKey), findsOneWidget);
      expect(repo.calls, isNot(contains('read:all')));
      await tester.tap(find.byKey(NotificationsScreen.settingsKey));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.notificationSettings);
      SwitchListTile tile(NotificationSetting s) =>
          tester.widget(find.byKey(NotificationSettingsScreen.switchKey(s)));
      expect(tile(NotificationSetting.likes).value, isTrue);
      await tester.tap(
        find.byKey(
          NotificationSettingsScreen.switchKey(NotificationSetting.likes),
        ),
      );
      await tester.pumpAndSettle();
      expect(tile(NotificationSetting.likes).value, isFalse);
      expect(repo.calls.last, 'setting:likes:false');
      repo.failWith = Exception('offline');
      await tester.tap(
        find.byKey(
          NotificationSettingsScreen.switchKey(NotificationSetting.follows),
        ),
      );
      await tester.pumpAndSettle();
      expect(tile(NotificationSetting.follows).value, isTrue);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Arabic RTL at 360 wide: sentences, sections and no '
        'overflow', (tester) async {
      final repo = FakeNotificationsRepository()
        ..items = [
          _note(
            'n1',
            NotificationType.comment,
            actors: [_user('sara', 'سارة')],
            target: const NotificationTarget(
              type: NotificationTargetType.comment,
              id: 'c1',
              postId: 'p1',
              text: '@omar رائع جدًا هذا المنشور',
            ),
          ),
          _note(
            'n2',
            NotificationType.likeComment,
            actors: [_user('omar', 'عمر'), _user('lina')],
            actorCount: 2,
            target: const NotificationTarget(
              type: NotificationTargetType.comment,
              id: 'c1',
              postId: 'p1',
            ),
          ),
        ];
      await pump(
        tester,
        repo: repo,
        initial: AppRoutes.notifications,
        language: AppLanguage.ar,
        viewport: GoldenViewport.android,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(_ar.notifSectionToday), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(_ar.notifComment(_ar.notifActors('سارة', 0)))),
        ),
        findsOneWidget,
      );
      expect(_ar.notifActors('عمر', 1), 'عمر وشخص آخر');
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(_ar.notifLikeComment('عمر وشخص آخر'))),
        ),
        findsOneWidget,
      );
      final row = tester.getRect(find.byKey(NotificationsScreen.rowKey('n1')));
      final avatar = tester.getRect(
        find.descendant(
          of: find.byKey(NotificationsScreen.rowKey('n1')),
          matching: find.byType(KAvatar),
        ),
      );
      // RTL: the avatar sits at the right.
      expect(avatar.center.dx, greaterThan(row.center.dx));
    });
  });

  test('sections: today, the last 7 days, earlier (local time)', () {
    final now = DateTime(2026, 10, 22, 0, 30);
    expect(
      sectionOf(DateTime(2026, 10, 22, 0, 5), now),
      NotificationSection.today,
    );
    expect(
      sectionOf(DateTime(2026, 10, 21, 23, 59), now),
      NotificationSection.week,
    );
    expect(sectionOf(DateTime(2026, 10, 15, 1), now), NotificationSection.week);
    expect(sectionOf(DateTime(2026, 10, 14), now), NotificationSection.earlier);
  });
}
