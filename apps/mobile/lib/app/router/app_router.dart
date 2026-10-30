import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/auth_redirect.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/features/agency/presentation/agency_screen.dart';
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
import 'package:kabso_live/features/bag/presentation/bag_screen.dart';
import 'package:kabso_live/features/cp/domain/cp_models.dart';
import 'package:kabso_live/features/cp/presentation/cp_screen.dart';
import 'package:kabso_live/features/cp/presentation/cp_space_screen.dart';
import 'package:kabso_live/features/create/create_screen.dart';
import 'package:kabso_live/features/create/new_reel_screen.dart';
import 'package:kabso_live/features/creator/presentation/creator_center_screen.dart';
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
import 'package:kabso_live/features/discover/trending_hashtags_screen.dart';
import 'package:kabso_live/features/families/presentation/create_family_screen.dart';
import 'package:kabso_live/features/families/presentation/families_screen.dart';
import 'package:kabso_live/features/families/presentation/family_chat_screen.dart';
import 'package:kabso_live/features/families/presentation/family_screen.dart';
import 'package:kabso_live/features/follows/domain/follow_list_models.dart';
import 'package:kabso_live/features/follows/presentation/follow_lists_screen.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_detail_screen.dart';
import 'package:kabso_live/features/levels/presentation/levels_screen.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_room_swipe.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:kabso_live/features/medals/presentation/medals_screen.dart';
import 'package:kabso_live/features/medals/presentation/showcase_picker_screen.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/posts/presentation/drafts_screen.dart';
import 'package:kabso_live/features/posts/presentation/edit_post_screen.dart';
import 'package:kabso_live/features/posts/presentation/likers_screen.dart';
import 'package:kabso_live/features/posts/presentation/post_screen.dart';
import 'package:kabso_live/features/premium/presentation/change_username_screen.dart';
import 'package:kabso_live/features/premium/presentation/premium_store_screen.dart';
import 'package:kabso_live/features/profile/edit_profile_screen.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/programs/presentation/event_center_screen.dart';
import 'package:kabso_live/features/programs/presentation/event_detail_screen.dart';
import 'package:kabso_live/features/programs/presentation/svip_screen.dart';
import 'package:kabso_live/features/programs/presentation/task_center_screen.dart';
import 'package:kabso_live/features/safety/safety_screens.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:kabso_live/features/stories/presentation/new_story_screen.dart';
import 'package:kabso_live/features/stories/presentation/story_archive_screen.dart';
import 'package:kabso_live/features/stories/presentation/story_viewer_screen.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_history_screen.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_screen.dart';
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
        path: AppRoutes.myProfile,
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatPattern,
        builder: (_, state) {
          final username = state.pathParameters['username']!;
          // D158: the display name alone, or with the premium tier.
          final (name, tier) = switch (state.extra) {
            final String n => (n, null),
            final ChatPeer peer => (peer.displayName, peer.premiumTier),
            _ => (null, null),
          };
          // D86: with Demo data the designed conversation (test data).
          return demoOn()
              ? MessagesPreviewScreen(peer: name ?? username)
              : ChatScreen(
                  username: username,
                  displayName: name,
                  premiumTier: tier,
                );
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
        path: AppRoutes.trendingHashtags,
        builder: (_, _) => const TrendingHashtagsScreen(),
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
      GoRoute(
        path: AppRoutes.newReel,
        builder: (_, _) => const NewReelScreen(),
      ),
      GoRoute(path: AppRoutes.goLive, builder: (_, _) => const GoLiveScreen()),
      GoRoute(
        path: AppRoutes.voiceRooms,
        builder: (_, _) => const VoiceRoomsScreen(),
      ),
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
      // CP-018: families, the relationship (CP) and medals.
      // D121: followers and following.
      GoRoute(
        path: AppRoutes.userFollowsPattern,
        builder: (_, state) => FollowListsScreen(
          username: state.pathParameters['username']!,
          initial: FollowListKind.parse(state.uri.queryParameters['tab']),
        ),
      ),
      GoRoute(
        path: AppRoutes.userMedalsPattern,
        builder: (_, state) =>
            MedalsScreen(username: state.pathParameters['username']),
      ),
      GoRoute(
        path: AppRoutes.families,
        builder: (_, _) => const FamiliesScreen(),
      ),
      GoRoute(
        path: AppRoutes.newFamily,
        builder: (_, _) => const CreateFamilyScreen(),
      ),
      GoRoute(
        path: AppRoutes.familyPattern,
        builder: (_, state) =>
            FamilyScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: AppRoutes.familyChatPattern,
        builder: (_, state) =>
            FamilyChatScreen(familyId: state.pathParameters['familyId']!),
      ),
      GoRoute(
        path: AppRoutes.cp,
        builder: (_, state) => CpScreen(
          initial: state.uri.queryParameters['tab'] == 'outgoing'
              ? CpDirection.outgoing
              : CpDirection.incoming,
        ),
      ),
      GoRoute(
        path: AppRoutes.cpSpace,
        builder: (_, _) => const CpSpaceScreen(),
      ),
      GoRoute(
        path: AppRoutes.cpCouplePattern,
        builder: (_, state) =>
            CpCoupleScreen(coupleId: state.pathParameters['coupleId']!),
      ),
      GoRoute(path: AppRoutes.medals, builder: (_, _) => const MedalsScreen()),
      GoRoute(
        path: AppRoutes.medalShowcase,
        builder: (_, _) => const ShowcasePickerScreen(),
      ),
      GoRoute(path: AppRoutes.bag, builder: (_, _) => const BagScreen()),
      // D146: premium usernames and the username change.
      GoRoute(
        path: AppRoutes.premium,
        builder: (_, state) =>
            PremiumStoreScreen(initialQuery: state.uri.queryParameters['q']),
      ),
      GoRoute(
        path: AppRoutes.changeUsername,
        builder: (_, _) => const ChangeUsernameScreen(),
      ),
      // D164: the Me hub's wallet, earnings and creator center.
      // D177: two tabs (gold coins, cherries); `/earnings` is the cherry tab.
      GoRoute(
        path: AppRoutes.wallet,
        builder: (_, state) => WalletScreen(
          initialTab: WalletTab.fromQuery(state.uri.queryParameters['tab']),
        ),
      ),
      GoRoute(
        path: AppRoutes.walletHistory,
        builder: (_, _) => const WalletHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.earnings,
        redirect: (_, _) => AppRoutes.walletCherries,
      ),
      GoRoute(
        path: AppRoutes.creatorCenter,
        builder: (_, _) => const CreatorCenterScreen(),
      ),
      // D179: host agencies.
      GoRoute(path: AppRoutes.agency, builder: (_, _) => const AgencyScreen()),
      // D166: the Me hub's Task Center, Event Center and SVIP.
      GoRoute(
        path: AppRoutes.taskCenter,
        builder: (_, _) => const TaskCenterScreen(),
      ),
      GoRoute(
        path: AppRoutes.eventCenter,
        builder: (_, _) => const EventCenterScreen(),
      ),
      GoRoute(
        path: AppRoutes.eventPattern,
        builder: (_, state) =>
            EventDetailScreen(eventId: state.pathParameters['eventId']!),
      ),
      GoRoute(path: AppRoutes.svip, builder: (_, _) => const SvipScreen()),
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
                      // D124: swipe to the next / previous live of
                      // the hub tab it was opened from.
                      return demo == null
                          ? LiveRoomSwipe(
                              roomId: id,
                              child: LiveRoomScreen(roomId: id),
                            )
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
              // D163: the Me tab is the hub; the profile opens from it.
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const MeHubScreen(),
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
