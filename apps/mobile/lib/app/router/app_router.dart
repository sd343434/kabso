import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/auth_redirect.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/features/auth/presentation/forgot_password_screen.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_code_screen.dart';
import 'package:kabso_live/features/auth/presentation/register_screen.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/auth/presentation/splash_screen.dart';
import 'package:kabso_live/features/create/create_screen.dart';
import 'package:kabso_live/features/debug/component_gallery_screen.dart';
import 'package:kabso_live/features/debug/conversations_preview_screen.dart';
import 'package:kabso_live/features/debug/discover_preview_screen.dart';
import 'package:kabso_live/features/debug/feed_preview_screen.dart';
import 'package:kabso_live/features/debug/live_preview_screen.dart';
import 'package:kabso_live/features/debug/messages_preview_screen.dart';
import 'package:kabso_live/features/debug/posts_preview_screen.dart';
import 'package:kabso_live/features/debug/previews_hub_screen.dart';
import 'package:kabso_live/features/debug/profile_preview_screen.dart';
import 'package:kabso_live/features/debug/reels_preview_screen.dart';
import 'package:kabso_live/features/discover/discover_screen.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_detail_screen.dart';
import 'package:kabso_live/features/levels/presentation/levels_screen.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/profile/edit_profile_screen.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
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
  ref
    ..listen<AuthState>(
      sessionControllerProvider,
      (_, next) => authState.value = next,
    )
    ..onDispose(authState.dispose);

  final rootNavigatorKey = ref.watch(rootNavigatorKeyProvider);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: ref.watch(initialLocationProvider),
    refreshListenable: authState,
    redirect: (context, state) =>
        authRedirect(authState.value, state.matchedLocation),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.home),
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
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
        builder: (_, state) => ChatScreen(
          username: state.pathParameters['username']!,
          displayName: state.extra is String ? state.extra! as String : null,
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
          builder: (_, _) => const LivePreviewScreen(),
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
          builder: (_, _) => const ReelsPreviewScreen(),
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
                    builder: (_, state) =>
                        LiveRoomScreen(roomId: state.pathParameters['roomId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.discover,
                builder: (_, _) => const DiscoverScreen(),
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
