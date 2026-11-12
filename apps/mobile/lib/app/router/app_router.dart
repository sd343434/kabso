import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/auth_redirect.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/core/network/consent_required.dart';
import 'package:kabso_live/features/agency/data/agency_repository.dart'
    show AgencyOpenRule;
import 'package:kabso_live/features/agency/presentation/agency_open_screen.dart';
import 'package:kabso_live/features/agency/presentation/agency_screen.dart';
import 'package:kabso_live/features/agency/presentation/host_apply_screen.dart';
import 'package:kabso_live/features/auth/presentation/forgot_password_screen.dart';
import 'package:kabso_live/features/auth/presentation/join_screen.dart';
import 'package:kabso_live/features/auth/presentation/login_screen.dart';
import 'package:kabso_live/features/auth/presentation/onboarding.dart';
import 'package:kabso_live/features/auth/presentation/password_change_screen.dart';
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
import 'package:kabso_live/features/creator/presentation/creator_stats_screen.dart';
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
import 'package:kabso_live/features/follows/presentation/follow_requests_screen.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/level_raise/presentation/level_raise_screens.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_detail_screen.dart';
import 'package:kabso_live/features/levels/presentation/levels_screen.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_room_swipe.dart';
import 'package:kabso_live/features/live/tools/second_camera/second_camera_screen.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:kabso_live/features/medals/presentation/medals_screen.dart';
import 'package:kabso_live/features/medals/presentation/showcase_picker_screen.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/messages/group_chat_screen.dart';
import 'package:kabso_live/features/messages/group_info_screen.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/messages/new_group_screen.dart';
import 'package:kabso_live/features/notifications/presentation/notifications_screen.dart';
import 'package:kabso_live/features/posts/presentation/drafts_screen.dart';
import 'package:kabso_live/features/posts/presentation/edit_post_screen.dart';
import 'package:kabso_live/features/posts/presentation/likers_screen.dart';
import 'package:kabso_live/features/posts/presentation/post_screen.dart';
import 'package:kabso_live/features/premium/presentation/change_username_screen.dart';
import 'package:kabso_live/features/premium/presentation/premium_store_screen.dart';
import 'package:kabso_live/features/privacy/consent_gate.dart';
import 'package:kabso_live/features/privacy/consent_screen.dart';
import 'package:kabso_live/features/privacy/data_export_screen.dart';
import 'package:kabso_live/features/profile/edit_profile_screen.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/programs/presentation/event_center_screen.dart';
import 'package:kabso_live/features/programs/presentation/event_detail_screen.dart';
import 'package:kabso_live/features/programs/presentation/svip_screen.dart';
import 'package:kabso_live/features/programs/presentation/task_center_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_apply_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_cherry_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_directory_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_employees_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_hub_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_order_new_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_order_screen.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_orders_screen.dart';
import 'package:kabso_live/features/recruits/presentation/creator_apply_screen.dart';
import 'package:kabso_live/features/recruits/presentation/staff_recruits_screen.dart';
import 'package:kabso_live/features/referrals/presentation/invite_friends_screen.dart';
import 'package:kabso_live/features/safety/safety_screens.dart';
import 'package:kabso_live/features/settings/account_deletion/account_deletion_screen.dart';
import 'package:kabso_live/features/settings/account_deletion/deletion_pending_screen.dart';
import 'package:kabso_live/features/settings/sessions/sessions_screen.dart';
import 'package:kabso_live/features/settings/settings_screen.dart';
import 'package:kabso_live/features/staff/presentation/staff_report_detail_screen.dart';
import 'package:kabso_live/features/staff/presentation/staff_reports_screen.dart';
import 'package:kabso_live/features/staff/presentation/staff_screen.dart';
import 'package:kabso_live/features/staff/presentation/staff_unavailable_screen.dart';
import 'package:kabso_live/features/store/presentation/store_screen.dart';
import 'package:kabso_live/features/stories/presentation/new_story_screen.dart';
import 'package:kabso_live/features/stories/presentation/story_archive_screen.dart';
import 'package:kabso_live/features/stories/presentation/story_viewer_screen.dart';
import 'package:kabso_live/features/vip/animated_avatar/animated_avatar_screen.dart';
import 'package:kabso_live/features/vip/presentation/vip_gift_perks.dart';
import 'package:kabso_live/features/vip/presentation/vip_identity_screen.dart';
import 'package:kabso_live/features/vip/presentation/vip_screen.dart';
import 'package:kabso_live/features/vip/presentation/vip_visitors_screen.dart';
import 'package:kabso_live/features/wallet/presentation/recharge_points_screen.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_history_screen.dart';
import 'package:kabso_live/features/wallet/presentation/wallet_screen.dart';
import 'package:kabso_live/features/whatsapp/presentation/wa_screens.dart';
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
  // D198: the consent screen after a new version of the terms or the policy.
  final consentRequired = ValueNotifier<bool>(
    ref.read(consentRequiredProvider),
  );
  ref
    ..listen<AuthState>(sessionControllerProvider, (previous, next) {
      authState.value = next;
      if (next is Authenticated && previous is! Authenticated) {
        unawaited(checkConsent(ref));
      } else if (next is! Authenticated) {
        ref.read(consentRequiredProvider.notifier).value = false;
      }
    })
    ..listen<bool>(consentRequiredProvider, (_, next) {
      consentRequired.value = next;
    })
    ..onDispose(consentRequired.dispose)
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
    refreshListenable: Listenable.merge([
      authState,
      introDone,
      consentRequired,
    ]),
    redirect: (context, state) => authRedirect(
      authState.value,
      state.matchedLocation,
      introDone: introDone.value,
      welcomeSeen: ref.read(welcomeSeenProvider),
      consentRequired: consentRequired.value,
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
      // D226: the full list of active sessions.
      GoRoute(
        path: AppRoutes.sessions,
        builder: (_, _) => const SessionsScreen(),
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
      // D339 (§10.133): group messages.
      GoRoute(
        path: AppRoutes.newGroup,
        builder: (_, _) => const NewGroupScreen(),
      ),
      GoRoute(
        path: AppRoutes.groupInfoPattern,
        builder: (_, state) =>
            GroupInfoScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: AppRoutes.groupAddPattern,
        builder: (_, state) =>
            NewGroupScreen(addTo: state.pathParameters['groupId']),
      ),
      GoRoute(
        path: AppRoutes.groupChatPattern,
        builder: (_, state) => GroupChatScreen(
          groupId: state.pathParameters['groupId']!,
          name: state.extra is String ? state.extra! as String : null,
        ),
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
        path: AppRoutes.followRequests,
        builder: (_, _) => const FollowRequestsScreen(),
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
      // D377: `?mode=audio|podcast|solo` preselects a mode (the party
      // page's «+»); anything else opens go-live on its default mode.
      GoRoute(
        path: AppRoutes.goLive,
        builder: (_, state) => GoLiveScreen(
          initialMode: GoLiveScreen.modeFromQuery(
            state.uri.queryParameters['mode'],
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.liveSecondCamera,
        builder: (_, _) => const SecondCameraScreen(),
      ),
      // D322: Create (KL-060) is full screen above the shell — opened from
      // Moments' «+» (the bar's centre button is gone); its Close and its
      // publish go to Moments.
      GoRoute(path: AppRoutes.create, builder: (_, _) => const CreateScreen()),
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
      // D193: the in-app account deletion and the grace-period sign-in.
      GoRoute(
        path: AppRoutes.deleteAccount,
        builder: (_, _) => const AccountDeletionScreen(),
      ),
      GoRoute(
        path: AppRoutes.deletionPending,
        builder: (_, _) => const DeletionPendingScreen(),
      ),
      // D208: the team reset the password — choose a new one to sign in.
      GoRoute(
        path: AppRoutes.passwordChange,
        builder: (_, _) => const PasswordChangeScreen(),
      ),
      // D198: «تنزيل بياناتي» and the consent screen.
      GoRoute(
        path: AppRoutes.dataExport,
        builder: (_, _) => const DataExportScreen(),
      ),
      GoRoute(
        path: AppRoutes.legalConsent,
        builder: (_, _) => const ConsentScreen(),
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
        path: AppRoutes.rechargePoints,
        builder: (_, _) => const RechargePointsScreen(),
      ),
      GoRoute(
        path: AppRoutes.earnings,
        redirect: (_, _) => AppRoutes.walletCherries,
      ),
      GoRoute(
        path: AppRoutes.creatorCenter,
        builder: (_, _) => const CreatorCenterScreen(),
      ),
      // D172: D164's detailed statistics, opened from the Creator Center.
      GoRoute(
        path: AppRoutes.creatorStats,
        builder: (_, _) => const CreatorStatsScreen(),
      ),
      // D179: host agencies.
      GoRoute(path: AppRoutes.agency, builder: (_, _) => const AgencyScreen()),
      // v1.74-social (D217): «دعوة صديق».
      GoRoute(
        path: AppRoutes.inviteFriends,
        builder: (_, _) => const InviteFriendsScreen(),
      ),
      // v1.70-social (D206): «افتح وكالة».
      GoRoute(
        path: AppRoutes.agencyOpen,
        builder: (_, state) => switch (state.extra) {
          final AgencyOpenRule rule => AgencyOpenScreen(
            probationDays: rule.probationDays,
            requiredHosts: rule.requiredHosts,
          ),
          _ => const AgencyOpenScreen(),
        },
      ),
      // v1.73-social (D209): «كن مضيفاً مع الإدارة».
      GoRoute(
        path: AppRoutes.agencyHostApply,
        builder: (_, state) => switch (state.extra) {
          final int minAge => HostApplyScreen(minAge: minAge),
          _ => const HostApplyScreen(),
        },
      ),
      // D185: recharge agents.
      GoRoute(
        path: AppRoutes.recharge,
        builder: (_, _) => const RechargeHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.rechargeApply,
        builder: (_, _) => const RechargeApplyScreen(),
      ),
      GoRoute(
        path: AppRoutes.rechargeEmployees,
        builder: (_, _) => const RechargeEmployeesScreen(),
      ),
      GoRoute(
        path: AppRoutes.rechargeAgents,
        builder: (_, _) => const RechargeDirectoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.rechargeCherries,
        builder: (_, _) => const RechargeCherryScreen(),
      ),
      // D204: recharge orders with escrow.
      GoRoute(
        path: AppRoutes.rechargeOrders,
        builder: (_, state) => RechargeOrdersScreen(
          incoming: state.uri.queryParameters['incoming'] == '1',
        ),
      ),
      GoRoute(
        path: AppRoutes.rechargeOrderPattern,
        builder: (_, state) =>
            RechargeOrderScreen(orderId: state.pathParameters['orderId']!),
      ),
      GoRoute(
        path: AppRoutes.rechargeOrderNew,
        builder: (_, state) => RechargeOrderNewScreen(
          agentCode: state.uri.queryParameters['agent'] ?? '',
          country: (state.uri.queryParameters['country'] ?? 'EG').toUpperCase(),
        ),
      ),
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
      // D252: «شراء VIP».
      GoRoute(path: AppRoutes.vip, builder: (_, _) => const VipScreen()),
      // D270: «المتجر».
      GoRoute(path: AppRoutes.store, builder: (_, _) => const StoreScreen()),
      // D273: «فريق كابسو» (staff accounts; the server checks every tool).
      GoRoute(path: AppRoutes.staff, builder: (_, _) => const StaffScreen()),
      // v1.75-live (D285): «استقطاباتي», «أرباحي», «انضم كصانع محتوى».
      GoRoute(
        path: AppRoutes.staffRecruits,
        builder: (_, _) => const StaffRecruitsScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffEarnings,
        builder: (_, _) => const StaffEarningsScreen(),
      ),
      // v1.116-social (D355): «واتساب» — the inbox and one conversation.
      GoRoute(
        path: AppRoutes.staffWhatsApp,
        builder: (_, _) => const WaInboxScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffWhatsAppChatPattern,
        builder: (_, state) => WaChatScreen(
          conversationId: state.pathParameters['conversationId']!,
        ),
      ),
      // v1.78-live (D288): «بلاغات» — the shared report queue.
      GoRoute(
        path: AppRoutes.staffReports,
        builder: (_, state) => StaffReportsScreen(
          focusReportId: state.uri.queryParameters['report'],
        ),
      ),
      // v1.93-social (D296): one report — the content and the actions.
      GoRoute(
        path: AppRoutes.staffReportPattern,
        builder: (_, state) => StaffReportDetailScreen(
          reportId: state.pathParameters['reportId']!,
        ),
      ),
      // D296 follow-up: the reported conversation, opened on a tap.
      GoRoute(
        path: AppRoutes.staffReportChatPattern,
        builder: (_, state) =>
            StaffReportChatScreen(reportId: state.pathParameters['reportId']!),
      ),
      // v1.89-social (D290): «طلب رفع ليفيل».
      GoRoute(
        path: AppRoutes.staffLevelRaises,
        builder: (_, _) => const StaffLevelRaisesScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffLevelRaiseNew,
        builder: (_, _) => const LevelRaiseFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.creatorApply,
        builder: (_, _) => const CreatorApplyScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffUnavailable,
        builder: (_, _) => const StaffUnavailableScreen(),
      ),
      GoRoute(
        path: AppRoutes.vipVisitors,
        builder: (_, _) => const VipVisitorsScreen(),
      ),
      GoRoute(
        path: AppRoutes.vipIdentity,
        builder: (_, _) => const VipIdentityScreen(),
      ),
      GoRoute(
        path: AppRoutes.vipScheduledGifts,
        builder: (_, _) => const VipScheduledGiftsScreen(),
      ),
      GoRoute(
        path: AppRoutes.vipAnimatedAvatar,
        builder: (_, _) => const AnimatedAvatarScreen(),
      ),
      // Debug/profile only; `kReleaseMode` is a compile-time constant, so
      // the routes and the previews are tree-shaken out of release builds.
      // D226: the KL-022 component gallery route is removed.
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
                              child: LiveRoomScreen(
                                roomId: id,
                                // D273: from a staff alert, the reports.
                                openStaffReports:
                                    state.uri.queryParameters['staff'] ==
                                    'reports',
                              ),
                            )
                          : LivePreviewScreen(mode: demo);
                    },
                  ),
                ],
              ),
            ],
          ),
          // D322: «الحفلة» (the voice rooms, D131/D246), the second tab.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.voiceRooms,
                builder: (_, _) => const VoiceRoomsScreen(),
              ),
            ],
          ),
          // D86: Posts · Reels — D322: the third tab, «اللحظات».
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reels,
                builder: (_, _) => const FeedScreen(),
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
