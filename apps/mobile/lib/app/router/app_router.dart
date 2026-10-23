import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/auth_redirect.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/features/auth/presentation/forgot_password_screen.dart';
import 'package:kabso_live/features/auth/presentation/join_screen.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/auth/presentation/onboarding.dart';
import 'package:kabso_live/features/auth/presentation/register_code_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/splash_intro.dart';
import 'package:kabso_live/features/auth/presentation/splash_screen.dart';
import 'package:kabso_live/features/auth/presentation/welcome_screen.dart';
import 'package:kabso_live/features/create/create_screen.dart';
import 'package:kabso_live/features/debug/component_gallery_screen.dart';
import 'package:kabso_live/features/debug/conversations_preview_screen.dart';
import 'package:kabso_live/features/debug/demo_data.dart';
import 'package:kabso_live/features/debug/discover_preview_screen.dart';
import 'package:kabso_live/features/debug/feed_preview_screen.dart';
import 'package:kabso_live/features/debug/live_preview_pk.dart';
import 'package:kabso_live/features/debug/live_preview_screen.dart';
import 'package:kabso_live/features/debug/messages_preview_screen.dart';
import 'package:kabso_live/features/debug/posts_preview_screen.dart';
import 'package:kabso_live/features/debug/previews_hub_screen.dart';
import 'package:kabso_live/features/debug/profile_preview_screen.dart';
import 'package:kabso_live/features/discover/discover_screen.dart';
import 'package:kabso_live/features/discover/hashtag_screen.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_detail_screen.dart';
import 'package:kabso_live/features/levels/presentation/levels_screen.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/posts/presentation/drafts_screen.dart';
import 'package:kabso_live/features/posts/presentation/edit_post_screen.dart';
import 'package:kabso_live/features/posts/presentation/likers_screen.dart';
import 'package:kabso_live/features/posts/presentation/post_screen.dart';
import 'package:kabso_live/features/profile/edit_profile_screen.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/safety/safety_screens.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:kabso_live/features/stories/presentation/new_story_screen.dart';
import 'package:kabso_live/features/stories/presentation/story_archive_screen.dart';
import 'package:kabso_live/features/stories/presentation/story_viewer_screen.dart';
import 'package:material_ui/material_ui.dart';

final rootNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(debugLabel: 'root'),
);

/// Initial location; tests may override it.
/// The splash, or in a test build the debug route passed with
/// `--dart-define=KABSO_START_ROUTE=/debug/...` (ignored in release).
final initialLocationProvider = Provider<String>((ref) {
  const start = String.fromEnvironment('KABSO_START_ROUTE');
  if (!kReleaseMode && start.startsWith(AppRoutes.debugPrefix)) return start;
  return AppRoutes.splash;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ValueNotifier<AuthState>(
    ref.read(sessionControllerProvider),
  );
  final introDone = ValueNotifier<bool>(ref.read(splashIntroProvider));
  ref
    ..listen<AuthState>(
      sessionControllerProvider,
      (_, next) => authState.value = next,
    )
    ..listen<bool>(splashIntroProvider, (_, next) => introDone.value = next)
    ..onDispose(authState.dispose)
    ..onDispose(introDone.dispose);

  final rootNavigatorKey = ref.watch(rootNavigatorKeyProvider);
  // D86: Demo data (test builds only) is read when a route builds.
  bool demoOn() => kDemoAvailable && ref.read(demoModeProvider);
  LivePreviewMode? demoRoom(String id) =>
      demoOn() ? DemoData.roomMode(id) : null;

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ref.watch(initialLocationProvider),
    refreshListenable: Listenable.merge([authState, introDone]),
    redirect: (context, state) => authRedirect(
      authState.value,
      state.matchedLocation,
      introDone: introDone.value,
      welcomeSeen: ref.read(welcomeSeenProvider),
    ),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.home),
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(path: AppRoutes.join, builder: (_, _) => const JoinScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.registerCode,
        builder: (_, _) => const RegisterCodeScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      // D86: Discover and search open above the tabs (search buttons).
      GoRoute(
        path: AppRoutes.discover,
        builder: (_, _) => demoOn()
            ? const DiscoverPreviewScreen(inApp: true)
            : const DiscoverScreen(),
      ),
      GoRoute(path: AppRoutes.levels, builder: (_, _) => const LevelsScreen()),
      GoRoute(
        path: AppRoutes.levelPattern,
        redirect: (_, state) =>
            LevelCategory.fromSlug(state.pathParameters['category']!) == null
            ? AppRoutes.levels
            : null,
        builder: (_, state) => LevelDetailScreen(
          category: LevelCategory.fromSlug(state.pathParameters['category']!)!,
        ),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatPattern,
        builder: (_, state) {
          final username = state.pathParameters['username']!;
          final name = state.extra is String ? state.extra! as String : null;
          // D86: with Demo data the designed conversation (test data).
          return demoOn()
              ? MessagesPreviewScreen(peer: name ?? username)
              : ChatScreen(username: username, displayName: name);
        },
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
        path: AppRoutes.mutedAccounts,
        builder: (_, _) => const MutedAccountsScreen(),
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
        path: AppRoutes.hashtagPattern,
        builder: (_, state) => HashtagScreen(tag: state.pathParameters['tag']!),
      ),
      GoRoute(path: AppRoutes.drafts, builder: (_, _) => const DraftsScreen()),
      GoRoute(
        path: AppRoutes.storiesPattern,
        builder: (_, state) =>
            StoryViewerScreen(username: state.pathParameters['username']!),
      ),
      GoRoute(
        path: AppRoutes.newStory,
        builder: (_, _) => const NewStoryScreen(),
      ),
      GoRoute(path: AppRoutes.goLive, builder: (_, _) => const GoLiveScreen()),
      GoRoute(
        path: AppRoutes.storyArchive,
        builder: (_, _) => const StoryArchiveScreen(),
      ),
      GoRoute(
        path: AppRoutes.editPostPattern,
        builder: (_, state) =>
            EditPostScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: AppRoutes.postLikesPattern,
        builder: (_, state) =>
            LikersScreen(postId: state.pathParameters['postId']!),
      ),
      GoRoute(
        path: AppRoutes.postPattern,
        builder: (_, state) => PostScreen(
          postId: state.pathParameters['postId']!,
          openComments: state.uri.queryParameters['comments'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.userProfilePattern,
        builder: (_, state) =>
            PublicProfileScreen(username: state.pathParameters['username']!),
      ),
      // Debug/profile only; `kReleaseMode` is a compile-time constant, so
      // the route and the gallery are tree-shaken out of release builds.
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.debugComponents,
          builder: (_, _) => const ComponentGalleryScreen(),
        ),
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.debugFeedPreview,
          builder: (_, _) => const FeedPreviewScreen(),
        ),
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.debugLivePreview,
          // D71: `?mode=pk2` or `?mode=pk4` for the PK layouts.
          builder: (_, state) => LivePreviewScreen(
            mode: LivePreviewMode.values.firstWhere(
              (m) => m.name == state.uri.queryParameters['mode'],
              orElse: () => LivePreviewMode.solo,
            ),
            // D73: `&simulate=1` plays a whole PK round on open.
            simulate: state.uri.queryParameters['simulate'] == '1',
            // D80: `&host=1` shows the host's own view (Host settings).
            host: state.uri.queryParameters['host'] == '1',
          ),
        ),
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.debugPreviews,
          builder: (_, _) => const PreviewsHubScreen(),
        ),
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.debugConversationsPreview,
          builder: (_, _) => const ConversationsPreviewScreen(),
        ),
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.debugDiscoverPreview,
          builder: (_, _) => const DiscoverPreviewScreen(),
        ),
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.debugReelsPreview,
          // D75 (owner): the reels preview is the real Reels tab's reels.
          builder: (_, _) =>
              const PostsPreviewScreen(initialTab: HomeTab.reels),
        ),
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.debugProfilePreview,
          builder: (_, _) => const ProfilePreviewScreen(),
        ),
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.debugProfileEditPreview,
          builder: (_, _) => const ProfilePreviewScreen(edit: true),
        ),
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.debugUserPreview,
          builder: (_, _) => const UserPreviewScreen(),
        ),
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.debugChatPreview,
          builder: (context, _) => ChatScreen(
            username: 'omar.test',
            displayName: Directionality.of(context) == TextDirection.rtl
                ? 'عمر (تجربة)'
                : 'Omar (test)',
          ),
        ),
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.debugPostsPreview,
          builder: (_, _) => const PostsPreviewScreen(),
        ),
      if (!kReleaseMode)
        GoRoute(
          path: AppRoutes.debugMessagesPreview,
          builder: (_, _) => const MessagesPreviewScreen(),
        ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const LiveScreen(),
                routes: [
                  // Full screen above the shell: no bottom nav (HL-N1 §2).
                  GoRoute(
                    path: AppRoutes.liveRoomSegment,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, state) {
                      final id = state.pathParameters['roomId']!;
                      // D86: a demo room opens the designed live room.
                      final demo = demoRoom(id);
                      return demo == null
                          ? LiveRoomScreen(roomId: id)
                          : LivePreviewScreen(mode: demo);
                    },
                  ),
                ],
              ),
            ],
          ),
          // D86: Posts · Reels, the second tab.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reels,
                builder: (_, _) => const FeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.create,
                builder: (_, _) => const CreateScreen(),
              ),
            ],
          ),
          // D86: Messages, the fourth tab.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.messages,
                builder: (_, _) => const MessagesTab(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
