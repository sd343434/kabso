// D60: another user's public profile — header with live ring, Follow /
// Following (with confirm) / Watch live, private and missing accounts,
// Posts and Reels tabs only, RTL/LTR, small screens, and the way in from a
// post's author.

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/l10n/gen/app_localizations.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../fixtures/live/live_fixtures.dart';
import '../../helpers/fake_dm_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

Future<FakeProfileRepository> _pump(
  WidgetTester tester, {
  FakeProfileRepository? repo,
  AppLanguage language = AppLanguage.en,
  GoldenViewport viewport = GoldenViewport.phone,
  List<Override> extra = const [],
}) async {
  final r = repo ?? FakeProfileRepository(apiProfile());
  setViewport(tester, viewport);
  await pumpScreen(
    tester,
    const PublicProfileScreen(username: 'host0'),
    language: language,
    overrides: [
      profileRepositoryProvider.overrideWithValue(r),
      profileGridProvider.overrideWith(
        (ref, _) =>
            FeedItems([for (var i = 0; i < 6; i++) const ProfileGridItem()]),
      ),
      ...extra,
    ],
  );
  await tester.pumpAndSettle();
  return r;
}

void main() {
  testWidgets('header from GET /users/{username}: @username, photo with the '
      'live ring and badge, counts, name, bio; Follow and Watch live', (
    tester,
  ) async {
    final repo = await _pump(tester);
    expect(repo.calls, ['GET host0']);
    expect(find.text('@host0'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('Arabic music every evening'), findsOneWidget);
    expect(find.text('1,234'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    final avatar = tester.widget<KAvatar>(find.byType(KAvatar).first);
    expect(avatar.ring, KAvatarRing.live);
    expect(find.byType(KBadge), findsOneWidget);
    expect(find.byKey(PublicProfileScreen.followKey), findsOneWidget);
    expect(find.byKey(PublicProfileScreen.watchLiveKey), findsOneWidget);
    expect(find.bySemanticsLabel(_en.profileWatchLive), findsWidgets);
    expect(find.text(_en.liveFollow), findsOneWidget);
    // D61: Message beside Follow; the LIVE button stays compact.
    final follow = tester.getRect(find.byKey(PublicProfileScreen.followKey));
    final message = tester.getRect(find.byKey(PublicProfileScreen.messageKey));
    final live = tester.getRect(find.byKey(PublicProfileScreen.watchLiveKey));
    expect(message.width, moreOrLessEquals(follow.width, epsilon: 0.5));
    expect(live.width, lessThan(follow.width));
    expect(follow.right, lessThan(message.left));
    expect(message.right, lessThan(live.left));
    // Posts and Reels only: Saved is private.
    expect(find.byKey(ProfileScreen.tabKey(ProfileTab.posts)), findsOneWidget);
    expect(find.byKey(ProfileScreen.tabKey(ProfileTab.reels)), findsOneWidget);
    expect(find.byKey(ProfileScreen.tabKey(ProfileTab.saved)), findsNothing);
  });

  testWidgets('Follow calls the API and turns into Following; Following asks '
      'before unfollowing', (tester) async {
    final repo = await _pump(tester);
    await tester.tap(find.byKey(PublicProfileScreen.followKey));
    await tester.pumpAndSettle();
    expect(repo.calls, ['GET host0', 'PUT host0']);
    expect(
      find.descendant(
        of: find.byKey(PublicProfileScreen.followKey),
        matching: find.text(_en.liveFollowing),
      ),
      findsOneWidget,
    );
    expect(find.text('1,235'), findsOneWidget);
    await tester.tap(find.byKey(PublicProfileScreen.followKey));
    await tester.pumpAndSettle();
    expect(find.text(_en.profileUnfollowConfirm('Sara')), findsOneWidget);
    await tester.tap(find.byKey(PublicProfileScreen.unfollowKey));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'DELETE host0');
    expect(find.text(_en.liveFollow), findsOneWidget);
  });

  testWidgets('D62: the three dots copy the username; copy link and report '
      'are "Coming soon", not buttons', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pump(tester);
    await tester.tap(find.byKey(PublicProfileScreen.moreKey));
    await tester.pumpAndSettle();
    // KL-060: report (and mute, block) now work; only the link waits.
    expect(
      tester
          .widget<ListTile>(find.byKey(PublicProfileScreen.reportKey))
          .enabled,
      isTrue,
    );
    for (final key in [PublicProfileScreen.copyLinkKey]) {
      expect(tester.widget<ListTile>(find.byKey(key)).enabled, isFalse);
      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.text(_en.profileEditSoon),
        ),
        findsOneWidget,
      );
    }
    await tester.tap(find.byKey(PublicProfileScreen.copyUsernameKey));
    await tester.pumpAndSettle();
    expect(copied, '@host0');
    expect(find.text(_en.profileCopied), findsOneWidget);
  });

  testWidgets('a failed follow comes back with a message', (tester) async {
    final repo = FakeProfileRepository(apiProfile())
      ..followFailure = const NetworkFailure.offline();
    await _pump(tester, repo: repo);
    await tester.tap(find.byKey(PublicProfileScreen.followKey));
    await tester.pumpAndSettle();
    expect(find.text(_en.liveFollow), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  // D175 (owner): following a private account sends a request (until
  // v1.47-social Follow was disabled there: no follow requests existed).
  testWidgets('private and not followed: no grid, "This account is private"; '
      'Follow sends a request ("Requested"), which can be cancelled', (
    tester,
  ) async {
    final repo = await _pump(
      tester,
      repo: FakeProfileRepository(apiProfile(isPrivate: true)),
    );
    expect(find.byKey(PublicProfileScreen.privateKey), findsOneWidget);
    expect(find.text(_en.profilePrivateTitle), findsOneWidget);
    expect(find.byType(SliverGrid), findsNothing);
    final followers = repo.profile.followerCount;
    await tester.tap(find.byKey(PublicProfileScreen.followKey));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'PUT host0');
    expect(
      find.descendant(
        of: find.byKey(PublicProfileScreen.followKey),
        matching: find.text(_en.followRequested),
      ),
      findsOneWidget,
    );
    expect(find.text(_en.profileRequestSent), findsOneWidget);
    // Still locked; the count does not move for a request.
    expect(find.byKey(PublicProfileScreen.privateKey), findsOneWidget);
    expect(repo.profile.followerCount, followers);
    await tester.tap(find.byKey(PublicProfileScreen.followKey));
    await tester.pumpAndSettle();
    expect(find.text(_en.profileCancelRequestConfirm('Sara')), findsOneWidget);
    await tester.tap(find.byKey(PublicProfileScreen.cancelRequestKey));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'DELETE host0');
    expect(find.text(_en.liveFollow), findsOneWidget);
  });

  testWidgets('private but followed: the grid shows', (tester) async {
    await _pump(
      tester,
      repo: FakeProfileRepository(
        apiProfile(isPrivate: true, isFollowing: true),
      ),
    );
    expect(find.byKey(PublicProfileScreen.privateKey), findsNothing);
    expect(find.byType(SliverGrid), findsOneWidget);
  });

  testWidgets('your own username: Edit profile instead of Follow', (
    tester,
  ) async {
    await _pump(tester, repo: FakeProfileRepository(apiProfile(isSelf: true)));
    expect(find.byKey(PublicProfileScreen.followKey), findsNothing);
    expect(find.text(_en.profileEditTitle), findsOneWidget);
  });

  testWidgets('404: "This account isn\'t available"', (tester) async {
    await _pump(
      tester,
      repo: FakeProfileRepository(
        apiProfile(),
        profileFailure: const ServerFailure(
          code: ErrorCode.notFound,
          rawCode: 'NOT_FOUND',
          debugMessage: 'x',
          statusCode: 404,
        ),
      ),
    );
    expect(find.byKey(PublicProfileScreen.notFoundKey), findsOneWidget);
    expect(find.text(_en.profileNotFoundTitle), findsOneWidget);
  });

  testWidgets('RTL: the photo at the right, Follow at the reading start', (
    tester,
  ) async {
    await _pump(tester, language: AppLanguage.ar);
    final avatar = tester.getRect(find.byType(KAvatar).first);
    expect(avatar.center.dx, greaterThan(393 / 2));
    final follow = tester.getRect(find.byKey(PublicProfileScreen.followKey));
    final message = tester.getRect(find.byKey(PublicProfileScreen.messageKey));
    expect(follow.left, greaterThan(message.right));
  });

  for (final language in AppLanguage.values) {
    for (final scale in [1.3, 2.0]) {
      testWidgets('360x800 at $scale (${language.name}): no overflow', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(
          tester,
          language: language,
          viewport: GoldenViewport.android,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('D155: the chat screen is connected: the person, the 24-hour '
      'notice, a working composer', (tester) async {
    setViewport(tester, GoldenViewport.phone);
    final dm = FakeDmRepository()
      ..people['host0'] = dmPerson('host0', name: 'Sara');
    await pumpScreen(
      tester,
      const ChatScreen(username: 'host0', displayName: 'Sara'),
      dmRepository: dm,
    );
    await tester.pumpAndSettle();
    expect(find.text('Sara'), findsWidgets);
    expect(find.text(_en.dmRetentionNotice), findsOneWidget);
    expect(find.text(_en.chatUnavailable), findsNothing);
    expect(
      tester.widget<TextField>(find.byKey(ChatScreen.composerKey)).enabled,
      isTrue,
    );
    expect(dm.calls, contains('peer:host0'));
  });

  testWidgets("a post's author opens their public profile", (tester) async {
    setViewport(tester, GoldenViewport.phone);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: FeedPostTile(
              post: FeedPostData(
                authorName: 'Sara',
                authorUsername: 'host0',
                isFollowingAuthor: false,
                postedAt: fixtureNow,
                text: 'Hello',
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.userProfilePattern,
          builder: (_, state) =>
              PublicProfileScreen(username: state.pathParameters['username']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await withClock(Clock.fixed(fixtureNow), () async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(apiProfile()),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: AppLanguage.en.locale,
            supportedLocales: KabsoApp.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: buildAppTheme(
              brightness: Brightness.dark,
              locale: AppLanguage.en.locale,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FeedPostTile.authorKey));
      await tester.pumpAndSettle();
    });
    expect(find.byType(PublicProfileScreen), findsOneWidget);
    expect(find.text('@host0'), findsOneWidget);
  });

  testWidgets('D61: Message opens the conversation with the user', (
    tester,
  ) async {
    setViewport(tester, GoldenViewport.phone);
    final router = GoRouter(
      initialLocation: AppRoutes.userProfile('host0'),
      routes: [
        GoRoute(
          path: AppRoutes.userProfilePattern,
          builder: (_, state) =>
              PublicProfileScreen(username: state.pathParameters['username']!),
        ),
        GoRoute(
          path: AppRoutes.chatPattern,
          // D158: the display name and the premium tier (ChatPeer).
          builder: (_, state) => ChatScreen(
            username: state.pathParameters['username']!,
            displayName: (state.extra! as ChatPeer).displayName,
            premiumTier: (state.extra! as ChatPeer).premiumTier,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            FakeProfileRepository(apiProfile()),
          ),
          // D155: the conversation reads the DM API (a fake here).
          dmRepositoryProvider.overrideWithValue(
            FakeDmRepository()
              ..people['host0'] = dmPerson('host0', name: 'Sara'),
          ),
          sharedPreferencesProvider.overrideWithValue(await testPrefs()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: AppLanguage.en.locale,
          supportedLocales: KabsoApp.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: buildAppTheme(
            brightness: Brightness.dark,
            locale: AppLanguage.en.locale,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(PublicProfileScreen.messageKey));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.text('Sara'), findsWidgets);
  });
}
