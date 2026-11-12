import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_global_strips.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart'
    show liveViewersPreviewProvider;
import 'package:kabso_live/features/live/application/live_level_ticker.dart';
import 'package:kabso_live/features/live/application/live_lucky_ticker.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/application/live_program.dart';
import 'package:kabso_live/features/live/application/live_quips.dart';
import 'package:kabso_live/features/live/application/live_room_provider.dart';
import 'package:kabso_live/features/live/application/live_room_session.dart';
import 'package:kabso_live/features/live/application/live_seat_emojis.dart';
import 'package:kabso_live/features/live/application/live_stickers.dart';
import 'package:kabso_live/features/live/application/live_top_viewers.dart';
import 'package:kabso_live/features/live/application/live_viewer_prefs.dart';
import 'package:kabso_live/features/live/application/live_vip_room.dart';
import 'package:kabso_live/features/live/application/live_watch.dart';
import 'package:kabso_live/features/live/data/live_host_targets_repository.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_permissions.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/streamer/live_screen_share.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_boost_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cinema.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cp_seats.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_newcomers_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_sheets.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_tools.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_score_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_emoji.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_settings_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_strip_settings.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_theme_art.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_video_podcast_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_video_podcast_studio.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_watch_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/live/presentation/go_live/viewer_live_ref_parts.dart';
import 'package:kabso_live/features/live/presentation/live_permission_sheet.dart';
import 'package:kabso_live/features/live/presentation/streamer/streamer_widgets.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_background_texts.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cp_entrance.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_games_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_guest_tiles.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_host_target_chip.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_interruption.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_lucky_combo_button.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_dare.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_side_cards.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_sticker_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_tap_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_vip_perks.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_watch_card.dart';
import 'package:kabso_live/features/live/tools/live_tools_stage.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile/public_profile_screen.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:kabso_live/features/recharge/presentation/live_recharge_entrance.dart';
import 'package:kabso_live/features/safety/safety_actions.dart';
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/features/staff/presentation/staff_entry_dialog.dart';
import 'package:kabso_live/features/staff/presentation/staff_tools_sheet.dart';
import 'package:kabso_live/features/vip/application/vip_entrance_plays.dart';
import 'package:kabso_live/features/vip/presentation/vip_entrance.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/live/room/:roomId` — the live room (KL-034, HOME_LIVE_LAYOUT_DECISIONS
/// §3), full screen above the shell (no bottom nav, HL-N1 §2).
///
/// Everything shown comes from the API: the room (`GET /live/rooms/{id}`:
/// title, category, host, status, end reason) and the host's public profile
/// (`GET /users/{username}`: follower count, follow state), with follow /
/// unfollow through `publicProfileProvider` (optimistic, rolled back with a
/// snack on failure).
///
/// What does not exist yet is shown honestly, never faked:
/// - video: no media provider (B1) → "Live video isn't available yet";
/// - chat: no chat API → a notice in the chat area and no composer;
/// - gifts: the sheet opens with Kabso's preview art, no prices, and Send
///   disabled with the reason (no catalogue or wallet, B5);
/// - viewers: no presence → nothing (`viewerCount` is 0), never a count;
///   D109: who is watching (`GET /live/rooms/{id}/viewers`, every 10 s):
///   the first faces and the count, opening the list read-only;
/// - share: no room link domain (B7) → no share button.
///
/// States (HL-L10): loading, live (video unavailable), ended (host ended /
/// heartbeat timeout / other), not found, error and offline with Try again.
class LiveRoomScreen extends ConsumerWidget {
  const new({required this.roomId, super.key, this.openStaffReports = false});

  /// v1.68-live (D273): «أدوات فريق كابسو» (staff accounts in the live).
  static const staffToolsKey = Key('room.staffTools');

  /// CP-012: the live's points next to the viewer count.
  static const scoreKey = Key('room.score');

  /// D347: the confirm of moving to another live from a global banner.
  static const openOtherLiveKey = Key('room.openOtherLive');
  static const rechargeKey = Key('room.recharge');

  /// D131: the host pill's taps line and the bar's gift button.
  static const tapsKey = Key('room.taps');
  static const giftKey = Key('room.gift');

  /// D154c: a moderator's Newcomers button.
  static const newcomersKey = Key('room.newcomers');

  /// D173: ≡, the room menu of everyone (viewer and moderator items).
  static const menuKey = Key('room.menu');

  /// D225: «إظهار الكل» while the screen is clean.
  static const cleanRestoreKey = Key('room.cleanRestore');

  /// D225: the host's picture in place of the video (data saver).
  static const dataSaverKey = Key('room.dataSaver');

  /// D173: the video bar's games (joystick) and guest (∞) buttons, and the
  /// cherry chip beside the board chip.
  static const gamesKey = Key('room.games');
  static const guestKey = Key('room.guest');

  /// D174: ∞ while the request waits (cancel) and while seated (leave).
  static const guestCancelKey = Key('room.guest.cancel');
  static const guestLeaveKey = Key('room.guest.leave');
  static const guestCameraKey = Key('room.guest.camera');

  /// D363: a video podcast's hand and questions buttons.
  static const podcastHandKey = Key('room.podcast.hand');
  static const podcastQuestionsKey = Key('room.podcast.questions');
  static const guestMicKey = Key('room.guest.mic');

  /// D181: minimize into the floating window (viewers and guests).
  static const minimizeKey = Key('room.minimize');

  /// v1.20-live (D105): this person was kicked out of the live.
  static const kickedKey = Key('room.kicked');

  /// D109: who is watching (faces and count); opens the list.
  static const viewersKey = Key('room.viewers');

  final String roomId;

  /// v1.68-live (D273): opened from a staff alert «بلاغ جديد على بث» — the
  /// staff tools open on the live's reports once joined.
  final bool openStaffReports;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = liveRoomProvider(roomId);
    final async = ref.watch(provider);
    void close() => closeLiveRoom(context);
    void retry() => ref.invalidate(provider);

    final room = async.value;
    final Widget body;
    if (room != null && !async.isLoading && room.kicked) {
      // Kicked out of this live (§10.20): opening it again says so.
      body = kickedMessage(l10n, close);
    } else if (room != null && !async.isLoading) {
      body = _RoomView(
        room: room,
        onClose: close,
        openStaffReports: openStaffReports,
      );
    } else if (async.hasError && !async.isLoading) {
      body = _failure(l10n, toAppFailure(async.error!), close, retry);
    } else {
      body = _LoadingRoom(onClose: close);
    }
    return Scaffold(backgroundColor: KPalette.dark.background, body: body);
  }

  /// "You were removed from this live" (v1.20-live, D105), in place of the
  /// room.
  static Widget kickedMessage(AppLocalizations l10n, VoidCallback close) =>
      KRoomMessage(
        key: kickedKey,
        icon: Icons.logout_rounded,
        iconColor: KPalette.dark.textSecondary,
        status: l10n.liveStatusRemoved,
        title: l10n.liveKickedTitle,
        message: l10n.liveKickedBody,
        onClose: close,
      );

  static Widget _failure(
    AppLocalizations l10n,
    AppFailure failure,
    VoidCallback close,
    VoidCallback retry,
  ) {
    const p = KPalette.dark;
    if (failure.code == ErrorCode.notFound) {
      return KRoomMessage(
        key: const Key('room.notFound'),
        icon: Icons.sensors_off_outlined,
        iconColor: p.textSecondary,
        status: l10n.liveStatusUnavailable,
        title: l10n.liveRoomNotFoundTitle,
        message: l10n.liveRoomNotFoundBody,
        onClose: close,
      );
    }
    if (failure.code == ErrorCode.networkOffline) {
      return KRoomMessage(
        key: const Key('room.offline'),
        icon: Icons.wifi_off_rounded,
        iconColor: p.textSecondary,
        status: l10n.liveStatusOffline,
        title: l10n.feedOfflineTitle,
        message: l10n.feedOfflineBody,
        onClose: close,
        onRetry: retry,
      );
    }
    final id = failureErrorId(failure);
    return KRoomMessage(
      key: const Key('room.error'),
      icon: Icons.error_outline_rounded,
      iconColor: p.error,
      status: l10n.liveStatusCantConnect,
      title: l10n.liveRoomErrorTitle,
      message: failureMessage(l10n, failure),
      detail: id == null ? null : l10n.errorIdLabel(id),
      onClose: close,
      onRetry: retry,
    );
  }
}

/// Leaves the room: back to where it was opened from (the Live hub), or to
/// the hub itself when the room was the first page (deep link).
void closeLiveRoom(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    Navigator.of(context).maybePop();
  } else if (router.canPop()) {
    router.pop();
  } else {
    router.go(AppRoutes.home);
  }
}

ImageProvider? _networkImage(String? url) =>
    url == null || url.isEmpty ? null : NetworkImage(url);

class _LoadingRoom extends StatelessWidget {
  const new({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const Key('room.loading'),
    container: true,
    label: context.l10n.liveRoomLoading,
    child: KLiveRoomScaffold(
      video: const KLiveVideoPlaceholder(child: SizedBox.shrink()),
      header: const KHostPillSkeleton(),
      onClose: onClose,
    ),
  );
}

class _RoomView extends ConsumerStatefulWidget {
  const new({
    required this.room,
    required this.onClose,
    this.openStaffReports = false,
  });

  final LiveRoom room;
  final VoidCallback onClose;
  final bool openStaffReports;

  @override
  ConsumerState<_RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends ConsumerState<_RoomView> {
  /// Latched once the ended overlay has offered Follow, so the button stays
  /// (as "Following") after the tap instead of vanishing.
  bool _endedOfferedFollow = false;

  String get _username => widget.room.host.username;

  /// D135 (owner: "the host changes the background and the others do not
  /// see it"): the room as last read — the session reads it again whenever
  /// the media room's `roomInfoVersion` moves (title, category, topic,
  /// cover and, v1.27.2-live, the theme), else the room it opened with.
  /// [build] watches the session, so every change redraws the room.
  LiveRoom get _room =>
      ref.read(liveRoomSessionProvider(widget.room.id)).room ?? widget.room;

  // The audio room's chat box (D94: the same as the host's).
  final _chat = TextEditingController();
  final _chatFocus = FocusNode();
  bool _writing = false;

  /// D141: this visit's rules line place, forgotten when the room closes
  /// (the next visit gets its own).
  late final Map<String, LiveChatVisit> _visits;

  /// D280: the VIP entrances this visit played (a new visit plays them
  /// again).
  late final VipEntrancePlays _plays;

  @override
  void initState() {
    super.initState();
    _visits = ref.read(liveChatVisitsProvider);
    _plays = ref.read(vipEntrancePlaysProvider);
    // D181: this room minimized comes back full screen (this screen holds
    // its session again); another minimized room is left.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mini = ref.read(liveViewerMinimizedProvider.notifier);
      final room = ref.read(liveViewerMinimizedProvider);
      if (room == null) return;
      if (room.id == widget.room.id) {
        mini.restore();
      } else {
        mini.leave();
      }
    });
  }

  /// D181: the room went into the floating window (the visit goes on).
  bool _minimized = false;

  @override
  void dispose() {
    _demoteTimer?.cancel();
    if (!_minimized) {
      endLiveChatVisit(_visits, widget.room.id);
      _plays.forget(widget.room.id);
    }
    _chat.dispose();
    _chatFocus.dispose();
    super.dispose();
  }

  bool _started = false;
  String? _inviteShown;
  bool _mutedShown = false;

  Future<void> _setFollowing({required bool follow}) =>
      setHostFollowing(context, ref, _username, follow: follow);

  /// D175 (owner): a pending request to a private host is cancelled after
  /// asking, as on the profile page.
  Future<void> _cancelRequest() async {
    final name = _room.host.displayName;
    if (await confirmCancelFollowRequest(context, name, live: true) &&
        mounted) {
      await _setFollowing(follow: false);
    }
  }

  /// D131 (owner, ref 160): leaving asks to follow first when this viewer
  /// can follow the host and does not (signed in, not the host, a live
  /// room); otherwise it leaves at once.
  bool get _askBeforeLeaving {
    final room = _room;
    if (room.status != LiveRoomStatus.live) return false;
    final me = ref.read(currentUserProvider);
    if (me == null || me.id == room.host.id) return false;
    final profile = ref.read(publicProfileProvider(_username)).value;
    // D175: a private host gets a follow request; a pending one asks nothing.
    return profile != null &&
        profile.canFollowOrRequest &&
        !profile.isFollowing &&
        !profile.followRequested;
  }

  /// ✕ and Back: the leave prompt when [_askBeforeLeaving]. "Follow and
  /// exit" follows, then leaves; a failed follow says why and stays.
  Future<void> _leave() async {
    if (!_askBeforeLeaving) return widget.onClose();
    final room = _room;
    final choice = await showLiveLeavePrompt(
      context,
      hostName: room.host.displayName,
      avatar: _networkImage(room.host.avatarUrl),
    );
    if (!mounted || choice == null) return;
    if (choice == LiveLeaveChoice.followAndExit) {
      try {
        await ref
            .read(publicProfileProvider(_username).notifier)
            .setFollowing(follow: true);
      } on Object catch (e) {
        if (mounted) {
          KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
        }
        return;
      }
      if (!mounted) return;
    }
    widget.onClose();
  }

  /// D148 / D178 / D254 / D305 / D347: a global banner or strip opens the
  /// live it is about (like a swipe to another live: this one is left). D347
  /// (CONVENTIONS §10.146): it is read first — a live that ended (or is
  /// gone) says so and nothing moves; a seated guest (on a mic) is asked
  /// before leaving their seat; then the normal join of that live (its own
  /// rules: guests, bans, kicks) runs as for any opened live.
  Future<void> _openOtherLive(String roomId) async {
    if (roomId == _room.id) return;
    final l10n = context.l10n;
    final LiveRoom target;
    try {
      target = await ref.read(liveRepositoryProvider).getRoom(roomId);
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      if (failure.code == ErrorCode.notFound ||
          failure.code == ErrorCode.liveRoomEnded) {
        KSnack.info(context, l10n.errorLiveRoomEnded);
      } else {
        KSnack.error(context, failureMessage(l10n, failure));
      }
      return;
    }
    if (!mounted) return;
    if (target.status != LiveRoomStatus.live) {
      KSnack.info(context, l10n.errorLiveRoomEnded);
      return;
    }
    final seated =
        ref.read(liveRoomSessionProvider(_room.id)).mine?.seatIndex != null;
    if (seated) {
      final go = await showKLiveConfirm(
        context,
        title: l10n.liveLuckyGlobalLeaveSeat(target.title),
        confirmKey: LiveRoomScreen.openOtherLiveKey,
        confirmLabel: l10n.liveLuckyGlobalGo,
        cancelLabel: l10n.actionCancel,
      );
      if (!go || !mounted) return;
    }
    context.pushReplacement(AppRoutes.liveRoom(roomId));
  }

  /// D181 (owner «زر التصغير لا يظهر للمشاهد»): a viewer or a seated guest
  /// minimizes the room into the floating window like the host (D94): the
  /// live goes on while they use the app; a tap opens it again, its ✕
  /// leaves.
  void _minimize() {
    _minimized = true;
    ref.read(liveViewerMinimizedProvider.notifier).minimize(_room);
    closeLiveRoom(context);
  }

  /// v1.132-social (D379): «هذه الغرفة لأعضاء VIP n فما فوق».
  Future<void> _vipLocked(LiveRoom room) async {
    final router = GoRouter.of(context);
    var getVip = false;
    await showLiveVipLockSheet(
      context,
      tierName: room.vipMinTier?.name ?? 'VIP',
      onGetVip: () => getVip = true,
    );
    if (!mounted) return;
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    if (getVip) unawaited(router.push(AppRoutes.vip));
  }

  LiveRoomSession get _session =>
      ref.read(liveRoomSessionProvider(widget.room.id).notifier);

  /// v1.68-live (D273, §10.96.6): how a Kabso staff member enters — asked
  /// once per app run («دخول ظاهر» / «مراقبة خفية»), hidden only with
  /// `lives.watch.hidden` (D286: no code). Null for everyone else.
  Future<StaffVisibility?> _staffEntry() async {
    final me = ref.read(currentUserProvider);
    if (me == null || !me.kabsoTeam || me.id == widget.room.host.id) {
      return null;
    }
    var mode = ref.read(staffWatchModeProvider);
    StaffStatus? status;
    try {
      status = await ref.read(staffStatusProvider.future);
    } on Object {
      status = null;
    }
    final canHidden = status?.can(StaffCapability.watchHidden) ?? false;
    if (mode == null && mounted) {
      mode = canHidden
          ? await showStaffEntryChoice(context, canHidden: true)
          : StaffVisibility.visible;
      mode ??= StaffVisibility.visible;
      ref.read(staffWatchModeProvider.notifier).choose(mode);
    }
    if (mode == StaffVisibility.hidden && !canHidden) {
      mode = StaffVisibility.visible;
    }
    return mode;
  }

  /// D273: «أدوات فريق كابسو» in this live.
  Future<void> _staffTools() async {
    final session = ref.read(liveRoomSessionProvider(widget.room.id));
    final visibility =
        StaffVisibility.fromWire(session.staff) ?? StaffVisibility.visible;
    ref.invalidate(staffStatusProvider);
    await showStaffTools(
      context,
      roomId: widget.room.id,
      hostName: widget.room.host.displayName,
      visibility: visibility,
      onSwitchMode: (mode) async {
        ref.read(staffWatchModeProvider.notifier).choose(mode);
        await _session.rejoinAsStaff(_room, mode.wire);
      },
    );
  }

  void _start() {
    if (_started || widget.room.status != LiveRoomStatus.live) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final room = _room;
      final staff = await _staffEntry();
      if (!mounted) return;
      unawaited(
        _session
            .start(
              room,
              background: liveBackgroundTexts(context.l10n),
              onLeave: () {
                if (mounted) closeLiveRoom(context);
              },
              staffVisibility: staff?.wire,
            )
            .then((_) {
              if (!mounted) return;
              final asStaff =
                  ref.read(liveRoomSessionProvider(room.id)).staff != null;
              // D286 (§10.96.14): entering as staff is staff work — the
              // server switched the shift on; the switch shows it at once.
              if (asStaff) ref.read(staffStatusProvider.notifier).staffWorked();
              // D273: a staff alert opens the live on its reports.
              if (widget.openStaffReports && asStaff) {
                unawaited(_staffTools());
              }
            }),
      );
      // CP-020: the room's gifts, on the same media session.
      ref
          .read(liveGiftEffectsProvider(room.id).notifier)
          .attach(_session.engine);
      // v1.43-live (D195): the room's PK (snapshot + `pk` data messages).
      if (room.mode == LiveRoomMode.solo) {
        ref
            .read(livePkProvider(room.id).notifier)
            .attach(_session.engine.pkEvents, host: false);
      }
      // D138: the emojis people play on their seats.
      ref
          .read(liveSeatEmojisProvider(room.id).notifier)
          .attach(_session.engine);
      // D148: big lucky wins in other lives (the gold ticker).
      ref
          .read(liveLuckyTickersProvider(room.id).notifier)
          .attach(_session.engine);
      // D178 / D305: the global strips (gifts and games).
      ref
          .read(liveGlobalStripsProvider(room.id).notifier)
          .attach(_session.engine);
      // v1.132-social (D379): the VIP pin, greeting card and rain effect.
      ref.read(liveVipRoomProvider(room.id).notifier).attach(_session.engine);
      // D254: the level banner (a high level reached in any live).
      ref
          .read(liveLevelTickersProvider(room.id).notifier)
          .attach(_session.engine);
      // D154: the room's quips (one at a time, after their delay).
      ref.read(liveQuipsProvider(room.id).notifier).attach(_session.engine);
      // D154e: the live's program (late joiners load it).
      ref.read(liveProgramProvider(room.id).notifier).attach(_session.engine);
      // D154h: the live's stickers.
      ref.read(liveStickersProvider(room.id).notifier).attach(_session.engine);
      // D154i: watch-together (late joiners start in the right place).
      ref
          .read(liveWatchProvider(room.id).notifier)
          .attach(_session.engine, host: false);
      // CP-013: the room chat, on the same media session.
      unawaited(
        ref
            .read(liveChatProvider(room.id).notifier)
            .attach(
              _session.engine,
              enabled: room.chatEnabled,
              muted: room.chatMuted,
            ),
      );
    });
  }

  /// Opens [username]'s card with what this person may do in the room
  /// (owner, 2026-10-26): points for everyone; kick and chat mute for the
  /// host and moderators; the moderator choice for the host.
  void _person(
    String username, {
    ({bool enabled, Future<void> Function({required bool enabled}) set})?
    selfMic,
  }) {
    final room = _room;
    final session = ref.read(liveRoomSessionProvider(room.id));
    final me = ref.read(currentUserProvider);
    final mine = session.mine?.role;
    final viewer = me != null && me.id == room.host.id
        ? LivePersonRole.host
        : switch (mine) {
            LiveSeatRole.host => LivePersonRole.host,
            LiveSeatRole.moderator => LivePersonRole.moderator,
            _ => LivePersonRole.viewer,
          };
    final moderators = session.seats?.moderators ?? const <UserSummary>[];
    final target = username == room.host.username
        ? LivePersonRole.host
        : moderators.any((m) => m.username == username)
        ? LivePersonRole.moderator
        : LivePersonRole.viewer;
    unawaited(
      showHostSheet(
        context,
        username,
        scope: LivePersonScope(
          roomId: room.id,
          viewer: viewer,
          target: target,
          onModerator: viewer == LivePersonRole.host
              ? (username, {required moderator}) => moderator
                    ? _session.addModerator(username)
                    : _session.removeModerator(username)
              : null,
          onKicked: () => unawaited(_session.refreshSeats()),
          seat: session.seats?.seats
              .where((s) => s.user?.username == username)
              .firstOrNull,
          onSeatMute: (index, {required muted}) =>
              _session.mute(index, muted: muted),
          selfMic: selfMic,
          onGift: (person) => unawaited(_openGifts(preselect: person)),
          // D154b: on the host's card, a traffic card for this live.
          onBoost: me == null || target != LivePersonRole.host
              ? null
              : () => unawaited(
                  showLiveBoostSheet(
                    context,
                    roomId: room.id,
                    hostName: room.host.displayName,
                  ),
                ),
          // D135: Mention — "@username" in the chat box, opened.
          onMention: me == null
              ? null
              : (username) {
                  insertMention(_chat, username);
                  unawaited(
                    _openChat(
                      liveChatComposerHint(
                        context.l10n,
                        chat: ref.read(liveChatProvider(room.id)),
                        role: _chatRole(
                          ref.read(liveRoomSessionProvider(room.id)),
                        ),
                      ),
                    ),
                  );
                },
        ),
      ),
    );
  }

  /// D109: who is watching — the first faces and the count from
  /// `GET /live/rooms/{id}/viewers` (refreshed every 10 s, as the host's),
  /// opening the list read-only. Until the list arrives (or when it cannot
  /// be read or shows nobody) the room's own `viewerCount`, without faces or
  /// a list.
  Widget? _viewers(LiveRoomSessionState session, {bool video = false}) {
    final l10n = context.l10n;
    final room = _room;
    if (room.status != LiveRoomStatus.live) return null;
    final preview = ref.watch(liveViewersPreviewProvider(room.id)).value;
    // D135 (owner: "why can't the viewer see the viewers and their
    // count?"): the viewer always sees the count — at least themself — and
    // can open the list, also before the faces arrive.
    void open() => unawaited(
      showLiveViewers(
        context,
        roomId: room.id,
        moderators: session.seats?.moderators ?? const [],
        seated: session.seats?.seats ?? const [],
        onPerson: (u) => _person(u.username),
      ),
    );
    if (preview == null || preview.items.isEmpty) {
      final count = math.max(room.viewerCount, 1);
      return LiveViewersStack(
        key: LiveRoomScreen.viewersKey,
        // D257 (the viewer's reference): 27 pt faces 31 pt apart, the count
        // in a 32 × 25 pt pill.
        avatarSize: video ? 27 : LiveViewersStack.size,
        pitch: video ? 31 : LiveViewersStack.size - 7,
        countHeight: video ? 25 : LiveViewersStack.size,
        countMinWidth: video ? 32 : null,
        // D260: the Kabso Team's shield while staff watch.
        team: (preview?.staff.isNotEmpty ?? false)
            ? KabsoTeamShield(size: video ? 27 : LiveViewersStack.size)
            : null,
        avatars: const [],
        count: KFormat.compact(count, l10n),
        label: l10n.liveViewers(count, KFormat.grouped(count)),
        onTap: open,
      );
    }
    final ranked = rankViewersBySupport(
      preview.items,
      ref
              .watch(
                liveTopContributorsProvider((
                  roomId: room.id,
                  version:
                      (session.score ?? room.score) -
                      (session.scoreParts?.tapPoints ??
                          room.scoreParts?.tapPoints ??
                          0),
                )),
              )
              .value ??
          const [],
    );
    final n = math.max(preview.items.length, room.viewerCount);
    final more = preview.next == null || n > preview.items.length ? '' : '+';
    return LiveViewersStack(
      key: LiveRoomScreen.viewersKey,
      // D131 (ref 158: 25.6 pt pictures 30.6 pt apart, a 25 pt count);
      // D141: about 12 % larger.
      // D257 (the viewer's reference): 27 pt faces 31 pt apart, the count
      // in a 32 × 25 pt pill.
      avatarSize: video ? 27 : LiveViewersStack.size,
      pitch: video ? 31 : LiveViewersStack.size - 7,
      countHeight: video ? 25 : LiveViewersStack.size,
      countMinWidth: video ? 32 : null,
      // D260: the Kabso Team's shield while staff watch (never ranked).
      team: preview.staff.isEmpty
          ? null
          : KabsoTeamShield(size: video ? 27 : LiveViewersStack.size),
      // D256: the top supporters first, the first three ringed.
      avatars: [
        for (final v in ranked)
          KAvatar(
            name: v.user.displayName,
            imageUrl: v.user.avatarUrl,
            size: video ? 27 : LiveViewersStack.size,
          ),
      ],
      ranks: [for (final v in ranked) v.rank],
      rankPoints: [
        for (final v in ranked)
          rankPointsLabel(v, (p) => KFormat.compact(p, l10n)),
      ],
      count: '${KFormat.compact(n, l10n)}$more',
      label: l10n.liveViewers(n, '${KFormat.grouped(n)}$more'),
      onTap: open,
    );
  }

  /// CP-013: what the chat offers this person.
  LiveChatViewerRole _chatRole(LiveRoomSessionState session) {
    final me = ref.read(currentUserProvider);
    if (me == null) return LiveChatViewerRole.guest;
    if (me.id == widget.room.host.id) return LiveChatViewerRole.host;
    if (session.mine?.role == LiveSeatRole.moderator) {
      return LiveChatViewerRole.moderator;
    }
    return LiveChatViewerRole.member;
  }

  /// D131 (ref 162): the chat box opened from 😊 shows the emoji panel.
  bool _emojiMode = false;

  Future<void> _openChat(
    ({bool canWrite, String hint}) composer, {
    bool emoji = false,
  }) async {
    final chat = ref.read(liveChatProvider(widget.room.id));
    if (!composer.canWrite && chat.muted && chat.enabled) {
      // The mute may have been lifted: nothing tells the room live.
      await ref.read(liveChatProvider(widget.room.id).notifier).refresh();
      if (!mounted) return;
      if (!ref.read(liveChatProvider(widget.room.id)).muted) {
        setState(() => _writing = true);
        _chatFocus.requestFocus();
        return;
      }
    }
    if (!mounted) return;
    if (!composer.canWrite) {
      KSnack.info(context, composer.hint);
      return;
    }
    setState(() {
      _writing = true;
      _emojiMode = emoji;
    });
    if (!emoji) _chatFocus.requestFocus();
  }

  void _sendChat() => unawaited(
    sendLiveChatFrom(context, ref, roomId: widget.room.id, field: _chat),
  );

  Widget _roomChat(LiveRoomSessionState session, {Color? bubble}) => _chatText(
    LiveRoomChatLines(
      // D135: a bright theme darkens the rules line's fill a little.
      brightNotice: LiveRoomRulesNotice.isBrightTheme(_room.theme),
      roomId: widget.room.id,
      role: _chatRole(session),
      // D212: a podcast's chat is the mockup's one-line bubbles.
      inline: _room.mode == LiveRoomMode.podcast,
      compact: _room.mode == LiveRoomMode.podcast,
      bubble:
          bubble ??
          (_room.mode == LiveRoomMode.podcast
              ? KPodcast.chatBubble
              : KAudioRoom.bubble),
      onProfile: _person,
    ),
  );

  /// D225: «حجم خط الدردشة» — the chat's text size on this phone.
  Widget _chatText(Widget chat) {
    final scale = ref.watch(liveViewerPrefsProvider).chatTextSize.scale;
    if (scale == 1) return chat;
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(media.textScaler.scale(1) * scale),
      ),
      child: chat,
    );
  }

  /// D225: «شاشة نظيفة» — the chat and the cards are hidden for this visit;
  /// «إظهار الكل» brings them back.
  bool _clean = false;

  Widget _cleanRestore() => Align(
    alignment: AlignmentDirectional.bottomStart,
    child: Semantics(
      button: true,
      child: GestureDetector(
        key: LiveRoomScreen.cleanRestoreKey,
        onTap: () => setState(() => _clean = false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: KLiveColors.chatScrim,
            borderRadius: BorderRadius.circular(KRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.visibility_rounded,
                size: 16,
                color: Color(0xFFFFFFFF),
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n.liveViewerCleanRestore,
                style: context.textStyles.caption.copyWith(
                  color: const Color(0xFFFFFFFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// The chat box while writing; it closes by itself when this person may
  /// no longer write (muted, or the host turned the chat off), so the pill
  /// says why.
  Widget? _chatComposer(({bool canWrite, String hint}) composer) {
    if (_writing && !composer.canWrite) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _chatFocus.unfocus();
        setState(() => _writing = false);
      });
      return null;
    }
    return _writing
        ? TapRegion(
            onTapOutside: (_) => setState(() {
              _writing = false;
              _chatFocus.unfocus();
            }),
            child: LiveRoomComposer(
              roomId: widget.room.id,
              emoji: _emojiMode,
              // CP-017: a seated guest's mic pauses while a clip records.
              liveMic: _session.engine,
              controller: _chat,
              focusNode: _chatFocus,
              onSend: _sendChat,
              // CP-017: private messages (the Messages tab; this live
              // closes).
              onMessages: () =>
                  GoRouter.maybeOf(context)?.go(AppRoutes.messages),
              onEmoji: (emoji) => unawaited(
                sendLiveChatText(
                  context,
                  ref,
                  roomId: widget.room.id,
                  text: emoji.token,
                ),
              ),
            ),
          )
        : null;
  }

  /// An invitation (CP-011): Join or Not now.
  Future<void> _showInvite(LiveSeatInvite invite) async {
    final l10n = context.l10n;
    // D232: the live's card style (a tap outside answers nothing).
    final join = await showKLiveDialog<bool>(
      context,
      builder: (dialog) => KLiveDialogCard(
        key: const Key('room.seatInvite'),
        leading: KAvatar(
          name: invite.invitedBy.displayName,
          imageUrl: invite.invitedBy.avatarUrl,
          size: 64,
        ),
        title: l10n.liveSeatInviteTitle,
        message: l10n.liveSeatInviteBody(invite.invitedBy.displayName),
        actions: [
          KLiveDialogAction(
            key: const Key('room.seatInvite.accept'),
            label: l10n.liveSeatInviteAccept,
            primary: true,
            onPressed: () => Navigator.of(dialog).pop(true),
          ),
          KLiveDialogAction(
            key: const Key('room.seatInvite.decline'),
            label: l10n.liveSeatInviteDecline,
            onPressed: () => Navigator.of(dialog).pop(false),
          ),
        ],
      ),
    );
    if (!mounted || join == null) return;
    if (join && !await _seatPermission()) {
      if (mounted) await runSeatAction(context, _session.declineInvite);
      return;
    }
    if (!mounted) return;
    await runSeatAction(
      context,
      join ? _session.acceptInvite : _session.declineInvite,
    );
  }

  /// D144a: before taking a seat — the rationale, the system prompt once,
  /// or the settings when refused for good. An audio room asks for the
  /// microphone only; a multi-guest video room for the camera too.
  Future<bool> _seatPermission() async {
    final ok = await ensureSeatCapturePermission(
      context,
      ref.read(livePermissionsProvider),
      // D174: a SOLO live's guests are on camera too; D363: a video
      // podcast's speakers.
      camera: !_room.voiceOnly,
    );
    if (!ok && mounted) {
      KSnack.info(context, context.l10n.livePermissionSeatRefused);
    }
    return ok;
  }

  void _onSeat(LiveRoomSessionState session, LiveSeat seat) {
    final seats = session.seats;
    if (seats == null) return;
    if (session.canModerate) {
      unawaited(
        showSeatActions(
          context,
          seat: seat,
          isHost: session.mine?.role == LiveSeatRole.host,
          moderators: seats.moderators,
          onMute: ({required muted}) => _session.mute(seat.index, muted: muted),
          onRemove: () => _session.remove(seat.index),
          onLock: ({required locked}) =>
              _session.lock(seat.index, locked: locked),
          onModerator: (username, {required moderator}) => moderator
              ? _session.addModerator(username)
              : _session.removeModerator(username),
        ),
      );
      return;
    }
    // A viewer taps someone on a seat: their card (owner, 2026-10-26).
    if (seat.user case final user? when seat.state == LiveSeatState.taken) {
      _person(user.username);
      return;
    }
    final signedIn = ref.read(currentUserProvider) != null;
    if (signedIn &&
        !session.seated &&
        session.mine?.request == null &&
        seat.state == LiveSeatState.empty) {
      unawaited(_requestSeat(index: seat.index));
    }
  }

  Future<void> _requestSeat({int? index}) async {
    if (!await _seatPermission() || !mounted) return;
    await runSeatAction(context, () => _session.requestSeat(seatIndex: index));
  }

  /// D212: a podcast listener raises a hand (an optional short question).
  Future<void> _raiseHand() async {
    final l10n = context.l10n;
    if (!(_room.podcast?.questionsOpen ?? true)) {
      KSnack.info(context, l10n.podcastQuestionsClosed);
      return;
    }
    if (!await _seatPermission() || !mounted) return;
    final question = await showPodcastAskSheet(context);
    if (question == null || !mounted) return;
    await runSeatAction(
      context,
      () => _session.requestSeat(question: question),
    );
  }

  /// D212: a podcast speaker's own question time: their app leaves the
  /// seat when it ends (the server's sweeper does it too, within 15 s).
  Timer? _demoteTimer;
  DateTime? _demoteAt;

  void _watchDemote(LiveRoomSessionState session) {
    final mine = session.mine?.seatIndex;
    DateTime? at;
    if (mine != null && _room.mode == LiveRoomMode.podcast) {
      for (final seat in session.seats?.seats ?? const <LiveSeat>[]) {
        if (seat.index == mine) at = seat.demoteAt;
      }
    }
    if (at == _demoteAt) return;
    _demoteAt = at;
    _demoteTimer?.cancel();
    _demoteTimer = null;
    if (at == null) return;
    final left = at.difference(clock.now());
    _demoteTimer = Timer(left.isNegative ? Duration.zero : left, () {
      if (mounted) unawaited(_session.leaveSeat().catchError((Object _) {}));
    });
  }

  /// D212: the podcast's stage — the episode card, the four speaker seats
  /// and the listeners row.
  Widget _podcastStage(
    LiveRoomSessionState session,
    LiveMediaEngine engine,
    LivePodcast podcast,
    int cherries,
    void Function(int index) onSeat,
  ) {
    final room = _room;
    final host = room.host;
    final me = ref.watch(currentUserProvider)?.id;
    final seats = session.seats?.seats ?? const <LiveSeat>[];
    // D225: the emojis played on the speaker seats (D138), drawn on them.
    final seatOverlay = seatEmojiOverlay(
      ref,
      room.id,
      picture: KPodcast.speaker,
    );
    final speakers = <PodcastSpeakerData>[
      PodcastSpeakerData(
        userId: host.id,
        name: host.displayName,
        avatarUrl: host.avatarUrl,
        points: cherries,
        host: true,
        speaking: engine.speaking.contains(host.id),
        onTap: () => _person(host.username),
        overlay: seatOverlay(0),
      ),
      for (var i = 1; i < 4; i++)
        switch (seats.where((s) => s.index == i).firstOrNull) {
          LiveSeat(:final user?) && final seat => PodcastSpeakerData(
            userId: user.id,
            name: user.displayName,
            avatarUrl: user.avatarUrl,
            points: seat.points,
            muted: seat.mutedByHost || (user.id == me && !engine.micEnabled),
            speaking: engine.speaking.contains(user.id),
            demoteAt: seat.demoteAt,
            seatIndex: i,
            onTap: () => onSeat(i),
            overlay: seatOverlay(i),
          ),
          _ => PodcastSpeakerData.empty(i, onTap: () => onSeat(i)),
        },
    ];
    final onStage = {for (final s in speakers) ?s.userId};
    final preview = ref.watch(liveViewersPreviewProvider(room.id)).value;
    final listeners = podcastListenerOrder([
      for (final v in preview?.items ?? const <LiveViewer>[])
        if (v.user case final u? when !onStage.contains(u.id))
          PodcastListenerData(
            userId: u.id,
            name: u.displayName,
            avatarUrl: u.avatarUrl,
            onTap: () => _person(u.username),
          ),
    ], session.seats?.handsUp ?? const []);
    return PodcastStage(
      title: room.title,
      podcast: podcast,
      startedAt: room.startedAt,
      speakers: speakers,
      listeners: listeners,
      listenerCount: math.max(room.viewerCount, listeners.length),
      onSeeAll: () => unawaited(
        showLiveViewers(
          context,
          roomId: room.id,
          moderators: session.seats?.moderators ?? const [],
          seated: seats,
          onPerson: (u) => _person(u.username),
        ),
      ),
    );
  }

  /// D212: the hands sheet for a moderator (no settings: the host's).
  Future<void> _openHands(LiveRoomSessionState session) {
    final free = (session.seats?.seats ?? const <LiveSeat>[])
        .where((s) => s.state == LiveSeatState.empty)
        .length;
    final repo = ref.read(liveRepositoryProvider);
    return showPodcastHandsSheet(
      context,
      load: () async => (await repo.seatRequests(_room.id)).items,
      freeSeats: free,
      podcast: _room.podcast!,
      config: const LivePodcastConfig(),
      onBringUp: _session.accept,
      onLater: _session.defer,
      // D363: «الكرسي الساخن» and the hands by votes (a video podcast).
      onHotSeat: _room.videoPodcast
          ? (r) => _session.accept(r, hotSeat: true)
          : null,
    );
  }

  /// D363 scope extension: this phone's guest waits backstage (a video
  /// podcast's accepted invitation, until the host brings them on air).
  bool _backstage(LiveRoomSessionState session) {
    if (!_room.videoPodcast) return false;
    final mine = session.mine?.seatIndex;
    if (mine == null) return false;
    return session.seats?.seats.any((s) => s.index == mine && s.backstage) ??
        false;
  }

  /// The last subscriber rule sent to the media server (null: everyone).
  bool? _restricted;

  /// D363 scope extension: backstage, only the host receives this phone's
  /// camera and microphone; on air (or as a listener), everyone.
  void _syncBackstage(LiveRoomSessionState session, LiveMediaEngine engine) {
    final backstage = _backstage(session);
    if (_restricted == backstage) return;
    if (_restricted == null && !backstage) {
      _restricted = false;
      return;
    }
    _restricted = backstage;
    unawaited(engine.restrictSubscribers(backstage ? _room.host.id : null));
  }

  /// D363 (§10.157): a video podcast's questions with their upvotes.
  Future<void> _openQuestions(LiveRoomSessionState session) =>
      showPodcastQuestionsSheet(
        context,
        questions: session.seats?.questions ?? const [],
        me: ref.read(currentUserProvider)?.id,
        onVote: _session.vote,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final room = _room;
    _start();
    final session = ref.watch(liveRoomSessionProvider(room.id));
    // v1.20-live (D105): kicked out (the kick message, the media server's
    // removal, LiveRoom.kicked or LIVE_KICKED): leave and say so.
    final chatKicked = ref.watch(
      liveChatProvider(room.id).select((c) => c.kicked),
    );
    if (chatKicked && !session.kicked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _session.markKicked();
      });
    }
    ref.listen(liveRoomSessionProvider(room.id), (previous, next) {
      _watchDemote(next);
      // v1.132-social (D379, §10.169.9): a VIP room this person's tier does
      // not reach — the lock sheet, then out of the room.
      final refused = next.joinFailure;
      if (refused != null &&
          refused.code == ErrorCode.liveVipOnly &&
          previous?.joinFailure != refused) {
        unawaited(_vipLocked(room));
      }
      // The media session dropped (the host ended the live): re-read the
      // room so the ended state shows.
      if (next.disconnected && !(previous?.disconnected ?? false)) {
        ref.invalidate(liveRoomProvider(room.id));
      }
      final invite = next.mine?.invite;
      if (invite != null && invite.id != _inviteShown) {
        _inviteShown = invite.id;
        unawaited(_showInvite(invite));
      }
      // D173: the room became a cinema of 10 seats and this person sat
      // beyond them: the server moved them down or off the seat.
      final had = previous?.mine?.seatIndex;
      if (had != null &&
          had >= LiveCinema.seatCount &&
          next.mine?.seatIndex != had &&
          ref.read(liveWatchProvider(room.id)).watch?.video != null) {
        final moved = next.mine?.seatIndex;
        KSnack.info(
          context,
          moved == null ? l10n.liveCinemaOffSeat : l10n.liveCinemaMoved(moved),
        );
      }
      final mySeat = next.mine?.seatIndex;
      final muted =
          mySeat != null &&
          (next.seats?.seats.any((s) => s.index == mySeat && s.mutedByHost) ??
              false);
      if (muted && !_mutedShown) KSnack.info(context, l10n.liveSeatMutedByHost);
      _mutedShown = muted;
    });
    if (session.kicked || chatKicked) {
      return LiveRoomScreen.kickedMessage(l10n, widget.onClose);
    }
    final engine = _session.engine;
    _syncBackstage(session, engine);
    final viewerPrefs = ref.watch(liveViewerPrefsProvider);
    final entrancesHidden = viewerPrefs.entrancesHidden;
    _syncDataSaver(room, viewerPrefs.dataSaver);
    // D131: Back asks before leaving like ✕ (the leave prompt).
    ref.watch(publicProfileProvider(_username));
    final ask = _askBeforeLeaving;
    // CP-017: bullets from every live show in the chat (owner, 2026-10-26).
    return PopScope(
      canPop: !ask,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: ListenableBuilder(
        listenable: engine.changes,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            _scaffold(context, session, engine),
            // CP-020: gift banners and effects over the room.
            if (room.status == LiveRoomStatus.live)
              LiveGiftEffectsLayer(
                roomId: room.id,
                onSender: (u) => _person(u.username),
                // D148 / D347: the global banners open the live they are
                // about (checked first: ended → a toast; seated → asked).
                onOpenRoom: (id) => unawaited(_openOtherLive(id)),
                // D145c: the strips centred at the reading start in audio
                // and video alike; beside a video live's wish column.
                stripsStart: LiveGiftEffectsLayer.videoStripsStart(
                  sideColumn:
                      !room.voiceOnly &&
                      (room.wishGifts.isNotEmpty ||
                          LiveRoomPromoBox.shows(ref, room.id)),
                ),
              ),
            // v1.132-social (D379): a VIP big gift plays the uploaded rain.
            if (room.status == LiveRoomStatus.live)
              Positioned.fill(child: LiveVipGiftRainLayer(roomId: room.id)),
            // D154i: the video the live watches together. D225 (owner):
            // the audio room only.
            if (room.status == LiveRoomStatus.live &&
                room.mode == LiveRoomMode.audio)
              LiveWatchLayer(roomId: room.id, host: false),
            // D145: the lucky combo button after a lucky gift is sent.
            if (room.status == LiveRoomStatus.live)
              LuckyComboLayer(
                roomId: room.id,
                hostUsername: room.host.username,
                // Over the audio bar, or over the video live's quick
                // replies.
                bottom: room.voiceOnly
                    ? LuckyComboLayer.audioBottom
                    : LuckyComboLayer.videoBottom,
              ),
            // CP-021 (D112): the CP Entrance Effect. D225: hidden on this
            // phone with «إخفاء تأثيرات الدخول».
            if (room.status == LiveRoomStatus.live && !entrancesHidden)
              LiveCpEntranceLayer(roomId: room.id),
            // D185: a recharge agent's entrance bar.
            if (!entrancesHidden) LiveRechargeEntranceLayer(roomId: room.id),
            // D258: a VIP's entry banner and entry car.
            if (!entrancesHidden)
              LiveVipEntranceLayer(
                key: LiveVipEntranceLayer.layerKey,
                roomId: room.id,
              ),
            // D363 scope extension: a video podcast's guest waiting
            // backstage checks their camera and microphone (the host only
            // sees them); «مغادرة الكواليس» is back to the audience.
            if (_backstage(session) && room.status == LiveRoomStatus.live)
              Positioned.fill(
                child: VideoPodcastBackstageCheck(
                  preview: engine.videoPaused ? null : engine.preview(),
                  speaking: engine.speaking.contains(
                    ref.read(currentUserProvider)?.id,
                  ),
                  name: ref.read(currentUserProvider)?.displayName ?? '',
                  avatarUrl: ref.read(currentUserProvider)?.avatarUrl,
                  onLeave: () =>
                      unawaited(runSeatAction(context, _session.leaveSeat)),
                ),
              ),
            // D273: «أدوات فريق كابسو» while in the live as staff.
            if (session.staff != null && room.status == LiveRoomStatus.live)
              PositionedDirectional(
                end: KSpacing.md,
                top: MediaQuery.paddingOf(context).top + 112,
                child: StaffToolsButton(
                  key: LiveRoomScreen.staffToolsKey,
                  hidden: session.staff == StaffVisibility.hidden.wire,
                  onTap: () => unawaited(_staffTools()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _scaffold(
    BuildContext context,
    LiveRoomSessionState session,
    LiveMediaEngine engine,
  ) {
    final l10n = context.l10n;
    final room = _room;
    final host = room.host;
    final avatar = _networkImage(host.avatarUrl);
    final profile = ref.watch(publicProfileProvider(_username)).value;
    // D175 (owner): Follow on a private host sends a request («تم الطلب»).
    final canFollow = profile?.canFollowOrRequest ?? false;
    final following = profile?.isFollowing ?? false;
    final requested = profile?.followRequested ?? false;
    final ended = room.status == LiveRoomStatus.ended;
    if (ended && canFollow && !following && !requested) {
      _endedOfferedFollow = true;
    }

    // CP-012: signed-in people tap to cheer (D95); D120 (owner): the host's
    // own taps count too.
    final me = ref.watch(currentUserProvider);
    // D273: «فريق كابسو» does not tap for points in a live.
    final canTap = !ended && me != null && session.staff == null;
    // D259: the host pill shows the real cherries (the score is points);
    // D310 (owner: «ترتيب الغرف اجعله بالكرز»): the room's — the host's and
    // the seated guests' — the value the hub ranks this live by.
    final cherries = _roomCherries(session, engine);
    final composer = liveChatComposerHint(
      l10n,
      chat: ref.watch(liveChatProvider(room.id)),
      role: _chatRole(session),
    );
    // D363: a video podcast is drawn as a video live (its stage is the
    // video layer).
    if (!ended && room.voiceOnly) {
      return _audioRoom(
        session: session,
        engine: engine,
        cherries: cherries,
        canTap: canTap,
        signedIn: me != null,
        canFollow: canFollow && !following,
        following: following,
        requested: requested,
        composer: composer,
      );
    }
    // D131 (owner): the host pill's second line takes turns between this
    // live's points (the cherry) and its taps (a heart), when known.
    final taps = session.scoreParts?.tapPoints ?? room.scoreParts?.tapPoints;
    // v1.43-live (D195): a PK replaces the full-screen video with the split
    // stage (both hosts, the bar, the boosters, the result).
    final pkState = ended ? null : ref.watch(livePkProvider(room.id));
    final pkStage = pkState?.match == null ? null : _pkStage(pkState!, engine);
    return KLiveRoomScaffold(
      // D145c: the gift strips keep above the chat text.
      onChatTop: (top) =>
          ref.read(liveChatTopProvider(room.id).notifier).set(top),
      // Ended: the overlay explains; no video message underneath it.
      video: ended
          ? const KLiveVideoPlaceholder(child: SizedBox.shrink())
          : Stack(
              fit: StackFit.expand,
              children: [
                LiveTapLayer(
                  onTap: canTap ? _session.tap : null,
                  // D131 (ref 159): the characters start 37 pt above the
                  // bar, right over the gift button.
                  laneBottomInset: 59,
                  child: pkStage != null
                      ? const KLiveVideoPlaceholder(child: SizedBox.shrink())
                      : _video(session, engine),
                ),
                // D154h: the host's stickers (no touches here).
                LiveStickerLayer(roomId: room.id),
              ],
            ),
      // D238b: the PK videos edge to edge.
      stageEdgeToEdge: pkStage != null,
      stage:
          pkStage ??
          (!ended && room.mode.hasSeats && !room.videoPodcast
              ? _stage(session, engine)
              : null),
      // D238: the «PK أحكام» card, small at the bottom over the chat; a
      // signed-in viewer may report the dare (⚠️).
      dock: pkState?.match == null
          ? null
          : LivePkStage.dareDock(
              match: pkState!.match!,
              roomId: room.id,
              now: pkState.now,
              actions: PkDareActions(
                onReport: me == null
                    ? null
                    : ref.read(livePkProvider(room.id).notifier).reportDare,
              ),
            ),
      header: KHostPill(
        // D257 (the viewer's reference): the name alone (no @username;
        // the room ID is on the second row).
        premiumTier: host.premiumTier,
        agentCode: host.rechargeAgentCode,
        hostAgentCode: host.hostAgentCode,
        rechargeBadge: host.rechargeBadge,
        hostIsCreator: room.hostIsCreator,
        hostName: host.displayName,
        avatar: avatar,
        lines: ended
            ? const []
            : [
                Semantics(
                  label: l10n.liveHostPillCherries(KFormat.grouped(cherries)),
                  excludeSemantics: true,
                  child: KHostPillLine(
                    key: LiveRoomScreen.scoreKey,
                    icon: const KCherryIcon(size: 11),
                    text: KFormat.grouped(cherries),
                  ),
                ),
                if (taps != null)
                  Semantics(
                    label: l10n.liveHostPillTaps(KFormat.grouped(taps)),
                    excludeSemantics: true,
                    child: KHostPillLine(
                      key: LiveRoomScreen.tapsKey,
                      icon: const Icon(
                        Icons.favorite_rounded,
                        size: 11,
                        color: Color(0xFFFF6B9A),
                      ),
                      text: KFormat.grouped(taps),
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
              ],
        following: following,
        onFollow: canFollow && !requested
            ? () => unawaited(_setFollowing(follow: true))
            : null,
        requested: requested,
        onCancelRequest: requested ? () => unawaited(_cancelRequest()) : null,
        onTap: profile == null ? null : () => _person(_username),
      ),
      // Presence does not exist yet: a count only when the API has one.
      viewers: ended ? null : _viewers(session, video: true),
      // D257 (the viewer's reference): no minimize at the top (it is in
      // ≡, D181).
      onClose: () => unawaited(_leave()),
      roomInfo: ended
          ? null
          // D232 (owner): no level chip and no points chip beside the
          // cherries — the points stay on the host pill and in ≡'s
          // «نقاط البث».
          : KRoomChipsRow(
              // D257 (the viewer's reference «ID:…»): the host's ID, faint,
              // at the end.
              idText: 'ID:${host.username}',
              // D199: the host's «تارجت» chip (the ranking sheet on tap).
              targetChip:
                  LiveHostTargetChip.shows(
                    ref
                        .watch(liveHostTargetsProvider(room.host.username))
                        .value,
                  )
                  ? LiveHostTargetChip(
                      username: room.host.username,
                      isHost: false,
                      // D199b: the sheet's «ادعم» opens the gift panel.
                      onSupport: me == null
                          ? null
                          : () => unawaited(_openGifts()),
                    )
                  : null,
            ),
      // D136: the host's wish list (a row opens the gift panel with that
      // gift and the host); D137: the promo box.
      sideStart: ended || _clean
          ? null
          : LiveWishCard(
              wishes: room.wishGifts,
              onWish: me == null
                  ? null
                  : (w) => unawaited(_openGifts(preselectGift: w.giftCode)),
            ),
      // D173 (owner: «يجب أن يظهر عند الجميع»): every viewer, signed in or
      // not (guests read the ROOM banners too, v1.39-live).
      // D199: under «ترتيب الغرف»; hidden during a PK (the bar's place).
      sidePromo: ended || _clean || pkState?.match != null
          ? null
          : LiveRoomPromoColumn(roomId: room.id),
      // D257 (the viewer's reference «Regional Daily Host»): the host's
      // place on today's popularity board.
      sideEnd: ended || _clean || pkState?.match != null
          ? null
          : HostDailyRankCard(
              hostId: host.id,
              hostName: host.displayName,
              avatar: avatar,
            ),
      // D145a: the lucky combo beside the chat, over the quick replies.
      // D174: a solo live's guests stacked at the end over the chat; D145a:
      // the lucky combo under them.
      chatEnd: ended || _clean ? null : _chatEnd(session, engine, room),
      chat: ended
          ? null
          : _clean
          ? _cleanRestore()
          : Align(
              alignment: AlignmentDirectional.bottomStart,
              child: _chatText(
                LiveRoomChatLines(
                  roomId: widget.room.id,
                  role: _chatRole(session),
                  bubble: KLiveColors.chatScrim,
                  onProfile: _person,
                  inline: true,
                  // D230: the video live's chat (bottom-anchored like every
                  // room; the rules line steps aside while typing).
                  video: true,
                  // D257: the reference's boxed one-line rows (as the
                  // host's, D253).
                  flat: true,
                ),
              ),
            ),
      actionBar: ended
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (room.mode.hasSeats) ...[
                  _SeatBar(
                    session: session,
                    signedIn: ref.watch(currentUserProvider) != null,
                    onRequest: _requestSeat,
                    onCancel: () =>
                        runSeatAction(context, _session.cancelRequest),
                    onLeave: () => runSeatAction(context, _session.leaveSeat),
                    onRequests: () => showSeatRequests(
                      context,
                      roomId: room.id,
                      onAccept: _session.accept,
                      onDecline: _session.decline,
                    ),
                  ),
                  const SizedBox(height: KSpacing.sm),
                ],
                // D257: the quick replies are in ≡ (the reference's bar).
                _chatComposer(composer) ??
                    KViewerBar(
                      pillKey: AudioRoomViewKeys.chat,
                      // D257 (the viewer's reference): 210 × 35 pt.
                      pillWidth: 210,
                      pillHeight: 35,
                      hint: composer.canWrite
                          ? l10n.liveChatSayHi
                          : composer.hint,
                      onChat: () => unawaited(_openChat(composer)),
                      onEmoji: () =>
                          unawaited(_openChat(composer, emoji: true)),
                      actions: [
                        // D173 (owner): ≡ for everyone; a moderator's
                        // Newcomers (D154c) moved into it.
                        KViewerBarButton(
                          key: LiveRoomScreen.menuKey,
                          // D257: 42 pt apart (the reference).
                          target: KViewerRoom.viewerTarget,
                          asset: 'assets/live_bar/menu.png',
                          label: l10n.liveViewerMenu,
                          onTap: () => _openMenu(session),
                        ),
                        // D173 (owner: «لا يوجد زر طلب جست»): ∞ — joining
                        // as a guest. A multi-guest live asks for a seat
                        // with the seat bar above (CP-011); a solo live has
                        // no guest seats (the API refuses), so ∞ says so.
                        // D174 (owner «نعم بالطبع»): in a solo live ∞
                        // asks to join as a guest (3 at most), then shows
                        // the request (tap: cancel) or the seat (tap: leave).
                        // D257: the solo live's ∞ (join as a guest) is in
                        // ≡ (the reference's bar has none).
                        // D174a (owner: «الضيوف في البث الفردي يمكن إقفال
                        // الكاميرا»): a seated guest on camera turns their
                        // own camera and mic off or on.
                        // D363: a video podcast's hand (with a question),
                        // the questions to upvote, and the host's or a
                        // moderator's hands sheet («الكرسي الساخن»).
                        if (room.videoPodcast && me != null) ...[
                          if (!session.seated && session.mine != null)
                            KViewerBarButton(
                              key: LiveRoomScreen.podcastHandKey,
                              icon: Icons.front_hand_rounded,
                              label: session.mine!.request != null
                                  ? l10n.podcastLowerHand
                                  : l10n.podcastRaiseHand,
                              onTap: () => unawaited(
                                session.mine!.request != null
                                    ? runSeatAction(
                                        context,
                                        _session.cancelRequest,
                                      )
                                    : _raiseHand(),
                              ),
                            ),
                          KViewerBarButton(
                            key: LiveRoomScreen.podcastQuestionsKey,
                            icon: Icons.how_to_vote_rounded,
                            label: l10n.podcastQuestionsTitle,
                            onTap: () => unawaited(
                              session.canModerate
                                  ? _openHands(session)
                                  : _openQuestions(session),
                            ),
                          ),
                        ],
                        if (session.seated && !room.voiceOnly) ...[
                          KViewerBarButton(
                            key: LiveRoomScreen.guestCameraKey,
                            icon: engine.videoPaused
                                ? Icons.videocam_off_rounded
                                : Icons.videocam_rounded,
                            label: engine.videoPaused
                                ? l10n.liveGuestCameraOff
                                : l10n.liveGuestCamera,
                            onTap: () => unawaited(
                              _session.setCamera(on: engine.videoPaused),
                            ),
                          ),
                          KViewerBarButton(
                            key: LiveRoomScreen.guestMicKey,
                            icon: engine.micEnabled
                                ? Icons.mic_rounded
                                : Icons.mic_off_rounded,
                            label: engine.micEnabled
                                ? l10n.goLiveMic
                                : l10n.goLiveMicOff,
                            onTap: () => unawaited(_toggleMic(engine)),
                          ),
                        ],
                        // D257 (the reference's «SALE»): recharge coins.
                        if (me != null)
                          KViewerBarButton(
                            key: LiveRoomScreen.rechargeKey,
                            // D257: 42 pt apart (the reference).
                            target: KViewerRoom.viewerTarget,
                            asset: 'assets/live_bar/bar_sale.png',
                            art: true,
                            label: l10n.liveToolRecharge,
                            onTap: () =>
                                unawaited(context.push(AppRoutes.wallet)),
                          ),
                        // D173: games (none yet: the sheet says so); D257:
                        // the orange box in the reference's event slot.
                        KViewerBarButton(
                          key: LiveRoomScreen.gamesKey,
                          // D257: 42 pt apart (the reference).
                          target: KViewerRoom.viewerTarget,
                          asset: 'assets/live_bar/bar_box.png',
                          art: true,
                          label: l10n.liveGames,
                          onTap: () => unawaited(showLiveGamesSheet(context)),
                        ),
                        KViewerBarButton(
                          key: LiveRoomScreen.giftKey,
                          // D257: 42 pt apart (the reference).
                          target: KViewerRoom.viewerTarget,
                          // D135: the owner's colourful gift box.
                          asset: 'assets/live_bar/bar_gift.png',
                          art: true,
                          label: l10n.liveGifts,
                          onTap: () => unawaited(_openGifts()),
                        ),
                      ],
                    ),
              ],
            ),
      cover: ended
          ? KRoomEndedOverlay(
              hostName: host.displayName,
              avatar: avatar,
              reason: endReasonText(l10n, room.endReason),
              reasonIcon: endReasonIcon(room.endReason),
              onBack: widget.onClose,
              followAction: _endedOfferedFollow && canFollow
                  ? _FollowButton(
                      following: following,
                      requested: requested,
                      onPressed: () => unawaited(
                        requested
                            ? _cancelRequest()
                            : _setFollowing(follow: !following),
                      ),
                    )
                  : null,
            )
          : null,
    );
  }

  /// AUDIO (owner D94): the host's audio room, seen by a viewer — the room
  /// bar (Follow, share, ✕), LIVE · time and the viewer count, the seats,
  /// the chat bubble, and the bar: the chat pill, emoji, the seat button
  /// (ask, cancel, leave), the requests for moderators, gifts, and the
  /// microphone while seated.
  Widget _audioRoom({
    required LiveRoomSessionState session,
    required LiveMediaEngine engine,
    required int cherries,
    required bool canTap,
    required bool signedIn,
    required bool canFollow,
    required ({bool canWrite, String hint}) composer,
    bool following = false,
    bool requested = false,
  }) {
    final l10n = context.l10n;
    final room = _room;
    final host = room.host;
    final mine = session.mine;
    final pending = session.seats?.pendingRequests ?? 0;

    // The seat button follows the viewer's state (CP-011).
    Widget? seatButton;
    final podcast = room.mode == LiveRoomMode.podcast;
    if (podcast && signedIn && mine != null && !session.seated) {
      // D212: the red ✋ in the ∞ button's place.
      seatButton = mine.request != null
          ? PodcastHandButton(
              raised: true,
              label: l10n.podcastLowerHand,
              onTap: () =>
                  unawaited(runSeatAction(context, _session.cancelRequest)),
            )
          : PodcastHandButton(
              label: l10n.podcastRaiseHand,
              onTap: () => unawaited(_raiseHand()),
            );
    } else if (signedIn && mine != null) {
      if (session.seated) {
        seatButton = LiveRoundButton(
          key: AudioRoomViewKeys.leave,
          icon: Icons.logout_rounded,
          bare: true,
          label: l10n.liveSeatLeave,
          onTap: () => unawaited(runSeatAction(context, _session.leaveSeat)),
        );
      } else if (mine.request != null) {
        seatButton = LiveRoundButton(
          key: AudioRoomViewKeys.cancel,
          icon: Icons.hourglass_top_rounded,
          bare: true,
          label: l10n.liveSeatRequested,
          onTap: () =>
              unawaited(runSeatAction(context, _session.cancelRequest)),
        );
      } else {
        seatButton = LiveRoundButton(
          key: AudioRoomViewKeys.request,
          // D141 (owner): the video bar's ∞ icon.
          icon: Icons.all_inclusive_rounded,
          bare: true,
          label: l10n.liveSeatRequest,
          onTap: () => unawaited(_requestSeat()),
        );
      }
    }
    // D173: YouTube together turns the room into the owner's cinema.
    // D225 (owner): YouTube together is the audio room's only.
    final cinema =
        room.mode == LiveRoomMode.audio && LiveWatchScreen.shows(ref, room.id);
    final stage = _stage(session, engine);
    return KLiveSurface(
      child: Material(
        color: KPalette.dark.background,
        // The whole room cheers (the stage scrolls, so a tap layer under it
        // would never be hit); seats, buttons and the chat keep their taps.
        child: LiveTapLayer(
          onTap: canTap ? _session.tap : null,
          // D120: the lane starts just above the room's bar.
          laneBottomInset: 56,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _video(session, engine),
              LiveAudioRoomLayout(
                // D145c: the gift strips keep above the chat text.
                onChatTop: (top) =>
                    ref.read(liveChatTopProvider(room.id).notifier).set(top),
                // D145a: the combo in the promo box's place.
                combo: LuckyComboCluster.shows(ref, room.id)
                    ? LuckyComboCluster(roomId: room.id)
                    : null,
                // D141a (owner): the promo box over the gift button.
                // D173: for everyone in the room, signed in or not.
                promo:
                    room.status != LiveRoomStatus.ended &&
                        !_clean &&
                        LiveRoomPromoBox.shows(ref, room.id)
                    ? LiveRoomPromoBox(
                        roomId: room.id,
                        boxWidth: LiveRoomPromoBox.audioWidth,
                      )
                    : null,
                // D173: YouTube together turns the room into a cinema —
                // the player on top, the seats under it.
                screen: cinema
                    ? LiveWatchScreen(
                        roomId: room.id,
                        host: false,
                        part: LiveWatchPart.player,
                      )
                    : null,
                screenBar: cinema
                    ? LiveWatchScreen(
                        roomId: room.id,
                        host: false,
                        part: LiveWatchPart.bar,
                      )
                    : null,
                cinemaSeat: cinema && stage is AudioSeatRing
                    ? stage.cinemaTile
                    : null,
                cinemaSeats: room.seatCount ?? 0,
                // D173: the host's wish list (D136), over the promo box.
                wish: room.wishGifts.isEmpty || _clean
                    ? null
                    : LiveWishCard(
                        wishes: room.wishGifts,
                        onWish: signedIn
                            ? (w) => unawaited(
                                _openGifts(preselectGift: w.giftCode),
                              )
                            : null,
                      ),
                header: LiveAudioRoomHeader(
                  // D232 (owner: «وحّد الجميع واجعلهم مثل البث الحي»): the
                  // video live's host pill — the host's picture, name,
                  // @username, this live's cherries / taps and the follow
                  // capsule — in place of the room card.
                  pill: KHostPill(
                    key: AudioRoomViewKeys.pill,
                    username: host.username,
                    premiumTier: host.premiumTier,
                    agentCode: host.rechargeAgentCode,
                    hostAgentCode: host.hostAgentCode,
                    rechargeBadge: host.rechargeBadge,
                    hostIsCreator: room.hostIsCreator,
                    hostName: host.displayName,
                    avatar: _networkImage(host.avatarUrl),
                    lines: KHostPill.pointLines(
                      context,
                      cherries: cherries,
                      taps:
                          session.scoreParts?.tapPoints ??
                          room.scoreParts?.tapPoints,
                      scoreKey: LiveRoomScreen.scoreKey,
                      tapsKey: LiveRoomScreen.tapsKey,
                    ),
                    following: following,
                    onFollow: canFollow && !requested
                        ? () => unawaited(_setFollowing(follow: true))
                        : null,
                    requested: requested,
                    onCancelRequest: requested
                        ? () => unawaited(_cancelRequest())
                        : null,
                    onTap: () => _person(_username),
                  ),
                  // D181: minimize for viewers and guests too.
                  minimizeKey: LiveRoomScreen.minimizeKey,
                  minimizeTooltip: l10n.goLiveMinimize,
                  onMinimize: _canMinimize(room) ? _minimize : null,
                  shareKey: AudioRoomViewKeys.share,
                  shareTooltip: l10n.goLiveShare,
                  onShare: () => unawaited(
                    _share(
                      room.title,
                      KHandle.plain(
                        host.username,
                        premiumTier: host.premiumTier,
                        staffId: host.staffId,
                      ),
                    ),
                  ),
                  endKey: AudioRoomViewKeys.close,
                  endTooltip: l10n.liveClose,
                  onEnd: () => unawaited(_leave()),
                ),
                chips: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          // Ref 83: the room rank. D232 (owner): the
                          // live's points chip is gone (the pill shows them).
                          children: [
                            const Flexible(child: LiveRankChip()),
                            // D214: the host's «تارجت» chip in every live
                            // (voice too; the ranking sheet on tap).
                            if (LiveHostTargetChip.shows(
                              ref
                                  .watch(
                                    liveHostTargetsProvider(room.host.username),
                                  )
                                  .value,
                            )) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: LiveHostTargetChip(
                                  username: room.host.username,
                                  isHost: false,
                                  onSupport: signedIn
                                      ? () => unawaited(_openGifts())
                                      : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ?_viewers(session),
                  ],
                ),
                stage: stage,
                chat: [if (_clean) _cleanRestore() else _roomChat(session)],
                composer: _chatComposer(composer),
                // Ref 83/147: chat and emoji on one side; the seat, requests,
                // gifts and the mic on the other.
                // D173 (owner: «لماذا لا تجعل الشريط الذي في الأسفل، زر
                // الرسائل في الغرف الصوتية، مثله»): the video bar's chat pill
                // with the emoji inside it, taking the free width (was D94's
                // separate chat and emoji circles).
                barLead: KViewerChatPill(
                  pillKey: AudioRoomViewKeys.chat,
                  hint: composer.canWrite ? l10n.liveChatSayHi : composer.hint,
                  onChat: () => unawaited(_openChat(composer)),
                  onEmoji: () => unawaited(_openChat(composer, emoji: true)),
                ),
                barStart: [
                  // D173 (owner): ≡ for everyone (a viewer's own menu;
                  // a moderator's Newcomers moved into it).
                  LiveRoundButton(
                    key: AudioRoomViewKeys.menu,
                    icon: Icons.menu_rounded,
                    asset: 'assets/live_bar/menu.png',
                    bare: true,
                    label: l10n.liveViewerMenu,
                    onTap: () => _openMenu(session),
                  ),
                  // D138: someone seated plays an emoji on their seat.
                  if (mine?.seatIndex case final seat?)
                    LiveRoundButton(
                      key: AudioRoomViewKeys.seatEmoji,
                      icon: Icons.add_reaction_rounded,
                      bare: true,
                      label: l10n.liveSeatEmoji,
                      onTap: () => unawaited(
                        showSeatEmojiSheet(
                          context,
                          ref,
                          roomId: room.id,
                          seat: seat,
                        ),
                      ),
                    ),
                ],
                barEnd: [
                  ?seatButton,

                  if (session.canModerate)
                    LiveRoundButton(
                      key: AudioRoomViewKeys.requests,
                      icon: Icons.front_hand_rounded,
                      bare: true,
                      label: l10n.liveSeatRequests,
                      badge: pending,
                      onTap: () => unawaited(
                        room.mode == LiveRoomMode.podcast &&
                                room.podcast != null
                            ? _openHands(session)
                            : showSeatRequests(
                                context,
                                roomId: room.id,
                                onAccept: _session.accept,
                                onDecline: _session.decline,
                              ),
                      ),
                    ),
                  // D173: games (none yet: the sheet says so), with the
                  // owner's controller art as on the host's bar.
                  LiveRoundButton(
                    key: AudioRoomViewKeys.games,
                    icon: Icons.sports_esports_rounded,
                    asset: LiveGamesSheet.art,
                    art: true,
                    bare: true,
                    label: l10n.liveGames,
                    onTap: () => unawaited(showLiveGamesSheet(context)),
                  ),
                  LiveRoundButton(
                    key: AudioRoomViewKeys.gift,
                    icon: Icons.card_giftcard_rounded,
                    // D135/D141: the owner's colourful gift box.
                    asset: 'assets/live_bar/bar_gift.png',
                    art: true,
                    bare: true,
                    label: l10n.liveGifts,
                    onTap: () => unawaited(_openGifts()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// D181: only a live room the person is in can be minimized.
  bool _canMinimize(LiveRoom room) =>
      room.status == LiveRoomStatus.live &&
      !ref.read(liveRoomSessionProvider(room.id)).kicked;

  /// D225: the data saver follows the setting on this phone (video lives).
  bool? _dataSaverSent;

  void _syncDataSaver(LiveRoom room, bool on) {
    final want = on && !room.voiceOnly;
    if (_dataSaverSent == want) return;
    _dataSaverSent = want;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_session.setReceiveVideo(receive: !want));
    });
  }

  /// D225 (owner): «إعدادات المشاهدة» — all on this phone only (nothing is
  /// sent, nobody else is affected): this live's sound (muted for this
  /// visit, decision 7) and its volume; the gift sounds and effects, the
  /// quips' sounds and the entrance effects (kept on this device); the
  /// clean screen; the chat's text size; the data saver (video lives);
  /// minimize and report.
  Future<void> _openViewerSettings() {
    final l10n = context.l10n;
    final room = _room;
    final me = ref.read(currentUserProvider);
    return showLiveSettingsSheet(
      context,
      title: l10n.liveViewerSettings,
      groups: (sheet, sheetRef) {
        final session = sheetRef.watch(liveRoomSessionProvider(room.id));
        final prefs = sheetRef.watch(liveViewerPrefsProvider);
        final prefsCtl = sheetRef.read(liveViewerPrefsProvider.notifier);
        final quipsMuted = sheetRef.watch(quipsMutedProvider);
        return [
          LiveSettingsGroup(
            title: l10n.liveViewerThisLive,
            items: [
              LiveSettingsSwitch(
                id: 'muteLive',
                icon: session.soundMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                label: l10n.liveViewerMuteLive,
                hint: l10n.liveViewerMuteLiveHint,
                value: session.soundMuted,
                onChanged: (on) => unawaited(_session.setSoundMuted(muted: on)),
              ),
              LiveSettingsSlider(
                id: 'volume',
                icon: Icons.volume_down_rounded,
                label: l10n.liveViewerVolume,
                value: session.volume,
                onChanged: session.soundMuted
                    ? null
                    : (v) => unawaited(_session.setVolume(v)),
              ),
            ],
          ),
          LiveSettingsGroup(
            title: l10n.liveViewerEffects,
            items: [
              LiveSettingsSwitch(
                id: 'giftSounds',
                icon: Icons.music_off_rounded,
                label: l10n.liveViewerGiftSounds,
                value: prefs.giftSoundsMuted,
                onChanged: (on) => prefsCtl.setGiftSoundsMuted(muted: on),
              ),
              LiveSettingsSwitch(
                id: 'giftEffects',
                icon: Icons.auto_awesome_rounded,
                label: l10n.liveViewerGiftEffects,
                hint: l10n.liveViewerGiftEffectsHint,
                value: prefs.giftEffectsHidden,
                onChanged: (on) => prefsCtl.setGiftEffectsHidden(hidden: on),
              ),
              LiveSettingsSwitch(
                id: 'quipSounds',
                icon: Icons.campaign_outlined,
                label: l10n.liveViewerQuipSounds,
                value: quipsMuted,
                onChanged: (on) =>
                    sheetRef.read(quipsMutedProvider.notifier).set(muted: on),
              ),
              LiveSettingsSwitch(
                id: 'entrances',
                icon: Icons.door_front_door_outlined,
                label: l10n.liveViewerEntrances,
                value: prefs.entrancesHidden,
                onChanged: (on) => prefsCtl.setEntrancesHidden(hidden: on),
              ),
              // D305: the global strips, for this account in every live.
              ...liveStripSwitches(sheet, sheetRef),
            ],
          ),
          LiveSettingsGroup(
            title: l10n.liveViewerDisplay,
            items: [
              LiveSettingsLink(
                id: 'clean',
                icon: Icons.fullscreen_rounded,
                label: l10n.liveToolClearScreen,
                hint: l10n.liveViewerCleanHint,
                closes: true,
                onTap: () => setState(() => _clean = true),
              ),
              LiveSettingsChoice(
                id: 'chatText',
                icon: Icons.format_size_rounded,
                label: l10n.liveViewerChatText,
                options: [
                  l10n.liveViewerChatSmall,
                  l10n.liveViewerChatNormal,
                  l10n.liveViewerChatLarge,
                ],
                selected: prefs.chatTextSize.index,
                onSelected: (i) =>
                    prefsCtl.setChatTextSize(LiveChatTextSize.values[i]),
              ),
              if (!room.voiceOnly)
                LiveSettingsSwitch(
                  id: 'dataSaver',
                  icon: Icons.data_saver_on_rounded,
                  label: l10n.liveViewerDataSaver,
                  hint: l10n.liveViewerDataSaverHint,
                  value: prefs.dataSaver,
                  onChanged: (on) => prefsCtl.setDataSaver(on: on),
                ),
            ],
          ),
          LiveSettingsGroup(
            title: l10n.liveSettingsGeneral,
            items: [
              if (_canMinimize(room))
                LiveSettingsLink(
                  id: 'minimize',
                  icon: Icons.picture_in_picture_alt_rounded,
                  label: l10n.goLiveMinimize,
                  closes: true,
                  onTap: _minimize,
                ),
              // v1.60-live (D250): «الإبلاغ عن البث» (the live itself).
              if (me != null && me.id != room.host.id)
                LiveSettingsLink(
                  id: 'reportLive',
                  icon: Icons.report_outlined,
                  label: l10n.liveToolReportLive,
                  closes: true,
                  onTap: () =>
                      unawaited(reportLive(context, ref, roomId: room.id)),
                ),
              if (me != null && me.id != room.host.id)
                LiveSettingsLink(
                  id: 'report',
                  icon: Icons.flag_outlined,
                  label: l10n.liveToolReportHost,
                  closes: true,
                  onTap: () =>
                      unawaited(reportUser(context, ref, userId: room.host.id)),
                ),
            ],
          ),
        ];
      },
    );
  }

  /// D173 (owner: «ضع زر الثلاث شخطات عند الجميع، لكن إعدادات المضيف تختلف
  /// عن إعدادات المشاهد»): the ≡ menu of everyone in the room — the host has
  /// the Room Tools on their own screen; here viewers, seated guests and
  /// moderators get only what already works for them, and the features
  /// not built yet greyed «قريباً» (no toggle that does nothing).
  /// Moderators also get their tools (Newcomers; seat requests in a room
  /// with seats).
  void _openMenu(LiveRoomSessionState session) {
    final l10n = context.l10n;
    final room = _room;
    final host = room.host;
    final me = ref.read(currentUserProvider);
    final profile = ref.read(publicProfileProvider(_username)).value;
    final watch = ref.read(liveWatchProvider(room.id));
    // D225 (owner): YouTube is the audio room's only.
    final audio = room.mode == LiveRoomMode.audio;
    final viewer = <GoLiveTool>[
      // D225 (owner): «إعدادات المشاهدة» first — this phone only.
      GoLiveTool(
        id: 'viewerSettings',
        icon: Icons.tune_rounded,
        label: l10n.liveViewerSettings,
        onTap: () => unawaited(_openViewerSettings()),
      ),
      GoLiveTool(
        id: 'share',
        icon: Icons.share_rounded,
        label: l10n.goLiveShare,
        onTap: () => unawaited(
          _share(
            room.title,
            KHandle.plain(
              host.username,
              premiumTier: host.premiumTier,
              staffId: host.staffId,
            ),
          ),
        ),
      ),
      if (profile != null && profile.canFollow && !profile.isFollowing)
        GoLiveTool(
          id: 'follow',
          icon: Icons.person_add_alt_1_rounded,
          label: l10n.liveFollow,
          onTap: () => unawaited(_setFollowing(follow: true)),
        ),
      GoLiveTool(
        id: 'viewers',
        icon: Icons.groups_rounded,
        label: l10n.liveToolViewers,
        onTap: () => unawaited(
          showLiveViewers(
            context,
            roomId: room.id,
            moderators: session.seats?.moderators ?? const [],
            seated: session.seats?.seats ?? const [],
            onPerson: (u) => _person(u.username),
          ),
        ),
      ),
      GoLiveTool(
        id: 'contributions',
        icon: Icons.emoji_events_rounded,
        label: l10n.liveToolContributions,
        onTap: () => unawaited(showLiveScoreSheet(context, room.id)),
      ),
      GoLiveTool(
        id: 'rankings',
        icon: Icons.bar_chart_rounded,
        label: l10n.liveRankChip,
        onTap: () => unawaited(showLiveRankings(context)),
      ),
      GoLiveTool(
        id: 'games',
        icon: Icons.sports_esports_rounded,
        label: l10n.liveGames,
        onTap: () => unawaited(showLiveGamesSheet(context)),
      ),
      // D257: the quick replies and the solo live's ∞ (off the bar).
      if (liveChatComposerHint(
        l10n,
        chat: ref.read(liveChatProvider(room.id)),
        role: _chatRole(session),
      ).canWrite)
        GoLiveTool(
          id: 'quickReplies',
          icon: Icons.quickreply_outlined,
          label: l10n.liveToolQuickReplies,
          onTap: () => unawaited(
            showHostQuickReplies(
              context,
              host: false,
              onSend: (text) => unawaited(
                sendLiveChatText(context, ref, roomId: room.id, text: text),
              ),
            ),
          ),
        ),
      if (me != null &&
          room.mode == LiveRoomMode.solo &&
          room.status == LiveRoomStatus.live)
        _guestTool(session),
      if (audio && me != null && room.status == LiveRoomStatus.live)
        GoLiveTool(
          id: 'suggestVideo',
          icon: Icons.add_link_rounded,
          label: l10n.liveWatchSuggest,
          onTap: () =>
              unawaited(showLiveWatchSuggestSheet(context, roomId: room.id)),
        ),
      if (audio && watch.watch?.video != null)
        GoLiveTool(
          id: 'video',
          icon: Icons.smart_display_rounded,
          label: watch.hidden ? l10n.liveWatchShow : l10n.liveWatchHide,
          onTap: () =>
              ref.read(liveWatchProvider(room.id).notifier).toggleHidden(),
        ),
      if (session.seated)
        GoLiveTool(
          id: 'leaveSeat',
          icon: Icons.logout_rounded,
          label: l10n.liveSeatLeave,
          onTap: () => unawaited(runSeatAction(context, _session.leaveSeat)),
        ),
      // v1.60-live (D250): «الإبلاغ عن البث» (the live itself).
      if (me != null && me.id != host.id)
        GoLiveTool(
          id: 'reportLive',
          icon: Icons.report_outlined,
          label: l10n.liveToolReportLive,
          onTap: () => unawaited(reportLive(context, ref, roomId: room.id)),
        ),
      if (me != null && me.id != host.id)
        GoLiveTool(
          id: 'report',
          icon: Icons.flag_outlined,
          label: l10n.liveToolReportHost,
          onTap: () => unawaited(reportUser(context, ref, userId: host.id)),
        ),
      // D181: minimize works for viewers too.
      if (_canMinimize(room))
        GoLiveTool(
          id: 'minimize',
          icon: Icons.picture_in_picture_alt_rounded,
          label: l10n.goLiveMinimize,
          onTap: _minimize,
        ),
      // D225: the gift sounds, the gift effects and the clean screen (were
      // «قريباً») work now, in «إعدادات المشاهدة».
    ];
    final moderator = <GoLiveTool>[
      if (session.canModerate) ...[
        GoLiveTool(
          id: 'newcomers',
          icon: Icons.fiber_new_outlined,
          label: l10n.liveToolNewcomers,
          onTap: () => unawaited(showLiveNewcomers(context, roomId: room.id)),
        ),
        if (room.mode.hasGuestSeats)
          GoLiveTool(
            id: 'seatRequests',
            icon: Icons.front_hand_rounded,
            label: l10n.liveToolSeatRequests,
            badge: (session.seats?.pendingRequests ?? 0) > 0,
            onTap: () => unawaited(
              showSeatRequests(
                context,
                roomId: room.id,
                onAccept: _session.accept,
                onDecline: _session.decline,
              ),
            ),
          ),
      ],
    ];
    unawaited(
      showLiveRoomTools(
        context,
        room: viewer,
        other: moderator,
        roomTitle: l10n.liveViewerMenu,
        otherTitle: l10n.liveToolsModerator,
      ),
    );
  }

  /// D174: the end of the chat row — a solo live's guest tiles, then the
  /// lucky combo (D145a); null when neither shows.
  Widget? _chatEnd(
    LiveRoomSessionState session,
    LiveMediaEngine engine,
    LiveRoom room,
  ) {
    final combo = LuckyComboCluster.shows(ref, room.id)
        ? LuckyComboCluster(roomId: room.id)
        : null;
    // v1.43-live (D195): in a PK the guests are circles in the stage.
    final inPk = ref.watch(livePkProvider(room.id)).match != null;
    final guests = room.mode == LiveRoomMode.solo && !inPk
        ? (session.seats?.seats ?? const <LiveSeat>[])
              .where((s) => s.state == LiveSeatState.taken)
              .toList()
        : const <LiveSeat>[];
    if (guests.isEmpty) return combo;
    final me = ref.read(currentUserProvider)?.id;
    final tiles = LiveGuestTiles(
      seats: guests,
      // D174a: my camera off, my tile shows my picture (as the others see).
      video: (u) => u.id == me
          ? (engine.videoPaused ? null : engine.preview())
          : engine.remoteVideo(u.id),
      onTap: (u) => _person(u.username),
    );
    if (combo == null) return tiles;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [tiles, const SizedBox(height: 6), combo],
    );
  }

  /// D174a: the seated guest's own mic; muted by the host it stays off.
  Future<void> _toggleMic(LiveMediaEngine engine) async {
    final ok = await _session.setMic(on: !engine.micEnabled);
    if (!mounted) return;
    if (!ok) KSnack.info(context, context.l10n.liveSeatMutedByHost);
    setState(() {});
  }

  /// D257: the solo live's ∞ as a ≡ item — join as a guest, the request
  /// (tap: cancel) or the seat (tap: leave).
  GoLiveTool _guestTool(LiveRoomSessionState session) {
    final l10n = context.l10n;
    if (session.seated) {
      return GoLiveTool(
        id: 'guest',
        icon: Icons.logout_rounded,
        label: l10n.liveSeatLeave,
        onTap: () => unawaited(runSeatAction(context, _session.leaveSeat)),
      );
    }
    if (session.mine?.request != null) {
      return GoLiveTool(
        id: 'guest',
        icon: Icons.hourglass_top_rounded,
        label: l10n.liveSeatRequested,
        onTap: () => unawaited(runSeatAction(context, _session.cancelRequest)),
      );
    }
    final seats = session.seats?.seats;
    final full =
        seats != null &&
        seats.isNotEmpty &&
        seats.every((s) => s.state != LiveSeatState.empty);
    return GoLiveTool(
      id: 'guest',
      icon: Icons.all_inclusive_rounded,
      label: l10n.liveGuestJoin,
      onTap: full
          ? () => KSnack.info(context, l10n.liveGuestsFull)
          : () => unawaited(_requestSeat()),
    );
  }

  Future<void> _share(String title, String handle) async {
    final l10n = context.l10n;
    await Clipboard.setData(
      ClipboardData(text: l10n.goLiveShareText(title, handle)),
    );
    if (mounted) KSnack.success(context, l10n.goLiveShareCopied);
  }

  /// v1.43-live (D195): the PK stage: this room's host from the room's
  /// session, the other host and their guests from the PK connection.
  Widget _pkStage(LivePkState pk, LiveMediaEngine engine) {
    final match = pk.match!;
    final room = _room;
    final opponent = ref.read(livePkProvider(room.id).notifier).opponent;
    final (_, other) = match.of(room.id);
    final me = ref.read(currentUserProvider)?.id;
    final follow = pkFollowOpponent(context, ref, other.host);
    Widget stage() => LivePkStage(
      match: match,
      roomId: room.id,
      now: pk.now,
      ownVideo: engine.remoteVideo(room.host.id),
      opponentVideo: opponent?.video(other.host.id),
      guestVideo: (id) => id == me
          ? (engine.videoPaused ? null : engine.preview())
          : engine.remoteVideo(id) ?? opponent?.video(id),
      speaking: {...engine.speaking, ...?opponent?.speaking},
      announcement: pk.announcement,
      // D242: «جولة أخرى!» as the rematch starts.
      rematchBanner: pk.rematchBanner != null,
      onPerson: (u) => _person(u.username),
      // D231: a tap on a half — that host's card (the other room's host:
      // their room's card); the «+» to follow the other host.
      onHost: (u, {required opponent}) => opponent
          ? unawaited(showPkOpponentCard(context, other))
          : _person(room.host.username),
      onFollowOpponent: follow,
    );
    // D215: the same subtree with or without the other room's connection
    // (the stage and its video renderers are not rebuilt from scratch when
    // the connection comes up mid-PK).
    return ListenableBuilder(
      listenable: opponent?.changes ?? const AlwaysStoppedAnimation<double>(0),
      builder: (context, _) => stage(),
    );
  }

  /// SOLO: the host's video, "the host will be right back" while they are
  /// away, or the join failure. Seat rooms: the theme (seats are the stage).
  Widget _video(LiveRoomSessionState session, LiveMediaEngine engine) {
    final room = _room;
    // D363 (§10.157): a video podcast — the director's full-screen shot.
    if (room.videoPodcast) {
      return VideoPodcastRoomStage(
        roomId: room.id,
        host: room.host,
        seats: session.seats,
        engine: engine,
        me: ref.read(currentUserProvider)?.id,
      );
    }
    if (room.mode.hasSeats) {
      if (room.mode.isVoice && room.theme == LiveThemes.classic) {
        return const LiveAudioRoomBackground();
      }
      return LiveThemeBackground(theme: room.theme);
    }
    // D213: a streamer — the host's screen fitted to its orientation, the
    // camera bubble at the host's corner (the data saver and a failed join
    // keep their notes below).
    if (room.mode == LiveRoomMode.streamer &&
        engine is LiveScreenShare &&
        !(_dataSaverSent ?? false) &&
        session.joinFailure == null) {
      return StreamerViewerStage(
        engine: engine as LiveScreenShare,
        changes: engine.changes,
        hostId: room.host.id,
        hostName: room.host.displayName,
        initial: room.streamer ?? const LiveStreamer(),
        joined: session.joined,
        reload: () => ref
            .read(liveRepositoryProvider)
            .getRoom(room.id)
            .then((r) => r.streamer),
      );
    }
    final picture = engine.remoteVideo(room.host.id);
    // D201: the host's second camera (small picture, tap to swap) and the
    // recording indicator.
    if (picture != null) {
      return LiveViewerToolsStage(
        engine: engine,
        hostId: room.host.id,
        picture: SizedBox.expand(child: picture),
      );
    }
    // D225: the data saver on this phone: the host's picture, no video.
    if (_dataSaverSent ?? false) {
      return KLiveVideoPlaceholder(
        child: _StageNote(
          key: LiveRoomScreen.dataSaverKey,
          child: KLiveInterruption(
            leading: KAvatar(
              name: room.host.displayName,
              imageUrl: room.host.avatarUrl,
              size: KLiveInterruption.picture,
            ),
            badgeIcon: Icons.data_saver_on_rounded,
            title: context.l10n.liveViewerDataSaverOn,
            liveRegion: false,
          ),
        ),
      );
    }
    final failure = session.joinFailure;
    if (failure != null) {
      return KLiveVideoPlaceholder(
        child: _StageNote(
          key: const Key('room.joinFailed'),
          child: KLiveInterruption(
            icon: Icons.videocam_off_rounded,
            status: context.l10n.liveStatusCantConnect,
            title: context.l10n.liveRoomJoinFailedTitle,
            message: failureMessage(context.l10n, failure),
          ),
        ),
      );
    }
    // D170: a host away (app in the background, camera muted) too.
    if (session.joined &&
        (!engine.isPresent(room.host.id) || engine.videoMuted(room.host.id))) {
      return KLiveVideoPlaceholder(
        child: _StageNote(
          key: const Key('room.hostAway'),
          child: KLiveInterruption(
            leading: KLiveHostPicture(
              imageUrl: room.host.avatarUrl,
              size: KLiveInterruption.picture,
            ),
            badgeIcon: Icons.hourglass_top_rounded,
            busy: true,
            status: context.l10n.liveStatusHostAway,
            title: context.l10n.liveHostAway,
            message: context.l10n.liveHostAwayBody,
          ),
        ),
      );
    }
    return const KLiveVideoPlaceholder(child: SizedBox.shrink());
  }

  /// D259 (§10.95): the live's real host cherries — the media room's
  /// metadata, else this viewer's last tap batch, else the room's.
  int _hostCherries(LiveRoomSessionState session, LiveMediaEngine engine) =>
      engine.hostCherries ??
      session.scoreParts?.hostCherries ??
      _room.scoreParts?.hostCherries ??
      0;

  /// D310 (§10.116): the room's cherries (host and seated guests) for the
  /// host pill — the media room's metadata, else this viewer's last tap
  /// batch, else the room's; an older server sends none, so the pill keeps
  /// the host's own (D259).
  int _roomCherries(LiveRoomSessionState session, LiveMediaEngine engine) =>
      engine.roomCherries ??
      session.scoreParts?.roomCherries ??
      _room.scoreParts?.roomCherries ??
      _room.cherries ??
      _hostCherries(session, engine);

  /// MULTI: the host's tile and the seats; AUDIO: the crowned circle and
  /// rows of seats. A seated viewer sees their own camera in their tile.
  Widget _stage(LiveRoomSessionState session, LiveMediaEngine engine) {
    final room = _room;
    final seats = session.seats;
    final art = LiveThemeArt.of(room.theme);
    final count = seats?.seatCount ?? room.seatCount ?? 0;
    // D259: the host's real cherries under the host (ref 83).
    final cherries = _hostCherries(session, engine);
    final me = ref.watch(currentUserProvider)?.id;
    final host = room.host;
    final hostPicture = KAvatar(
      name: host.displayName,
      imageUrl: host.avatarUrl,
      size: 96,
    );
    void onSeat(int index) {
      final seat = seats?.seats.firstWhere(
        (s) => s.index == index,
        orElse: () =>
            LiveSeat(index: index, state: LiveSeatState.empty, user: null),
      );
      // Owner (2026-10-26): a tap on my own seat opens my card (not a
      // mute); I turn my mic on or off from there.
      if (seat != null && me != null && seat.user?.id == me) {
        _person(
          seat.user!.username,
          selfMic: (
            enabled: engine.micEnabled,
            set: ({required enabled}) => engine.setMicEnabled(enabled: enabled),
          ),
        );
        return;
      }
      if (seat != null) _onSeat(session, seat);
    }

    if (room.podcast case final podcast?
        when room.mode == LiveRoomMode.podcast) {
      return _podcastStage(session, engine, podcast, cherries, onSeat);
    }
    final height = MediaQuery.sizeOf(context).height;
    if (room.mode == LiveRoomMode.multi) {
      return SizedBox(
        height: height * 0.42,
        child: VideoSeatGrid(
          count: count,
          accent: art.accent,
          seats: seats?.seats ?? const [],
          host: engine.remoteVideo(host.id) ?? Center(child: hostPicture),
          guestVideo: (seat) => seat.user!.id == me
              ? (engine.videoPaused ? null : engine.preview())
              : engine.remoteVideo(seat.user!.id),
          onSeat: onSeat,
        ),
      );
    }
    final speaking = <int>{
      if (engine.speaking.contains(host.id)) 0,
      for (final seat in seats?.seats ?? const <LiveSeat>[])
        if (seat.user != null && engine.speaking.contains(seat.user!.id))
          seat.index,
    };
    // The room's stage scrolls; seats keep one size in every room (D123).
    return AudioSeatRing(
      count: count,
      // D173: the cinema rows under the YouTube screen (big rooms).
      // D173: no points pills on the cinema's seats.
      compact:
          room.mode == LiveRoomMode.audio &&
          LiveWatchScreen.shows(ref, room.id),
      seats: seats?.seats ?? const [],
      // D111: CP partners on adjacent seats are drawn joined.
      cpPairs: cpSeatPairs(seats, hostId: host.id),
      host: KAvatar(
        name: host.displayName,
        imageUrl: host.avatarUrl,
        size: AudioSeatRing.picture,
      ),
      // D186: the avatar frame the host wears.
      hostFrame: host.avatarFrame,
      // D265: the host's VIP frame.
      hostVip: host.vip,
      // D376: the host's status over their picture.
      hostStatusEmojiId: host.statusEmojiId,
      hostName: host.displayName,
      hostPoints: KFormat.compact(cherries, context.l10n),
      speaking: speaking,
      micOff: {
        if (session.mine?.seatIndex case final mine? when !engine.micEnabled)
          mine,
      },
      onSeat: onSeat,
      // D138: the emojis played on the seats.
      overlay: seatEmojiOverlay(
        ref,
        widget.room.id,
        picture: AudioSeatRing.picture,
      ),
    );
  }

  /// CP-020: the gift panel for this live (the host and the people on a
  /// seat now), [preselect] chosen when they can receive.
  Future<void> _openGifts({
    LiveGiftPreselect? preselect,
    String? preselectGift,
  }) async {
    // D273: «فريق كابسو» sends no gifts in a live (the server refuses too).
    if (ref.read(liveRoomSessionProvider(widget.room.id)).staff != null) {
      KSnack.info(context, context.l10n.staffNoEconomy);
      return;
    }
    await _showGifts(preselect: preselect, preselectGift: preselectGift);
  }

  Future<void> _showGifts({
    LiveGiftPreselect? preselect,
    String? preselectGift,
  }) => KLiveGiftSheet.show(
    context,
    preselect: preselect,
    preselectGift: preselectGift,
    room: LiveGiftRoom(
      roomId: widget.room.id,
      host: widget.room.host,
      seated: (ref) => [
        for (final seat
            in ref
                    .watch(liveRoomSessionProvider(widget.room.id))
                    .seats
                    ?.seats ??
                const <LiveSeat>[])
          // D363 scope extension: a guest backstage is not on stage yet.
          if (!seat.backstage) ?seat.user,
      ],
      onSeatsStale: () {
        if (mounted) unawaited(_session.refreshSeats());
      },
      // D154: a moderator's free quips are the soundboard's.
      soundboard: (ref) =>
          ref.watch(liveRoomSessionProvider(widget.room.id)).canModerate,
      // v1.43-live (D195): the boosters' «PK» tab during a battle.
      pk: (ref) => ref.watch(livePkProvider(widget.room.id)).match,
    ),
  );
}

/// The localized end reason (HL-L10).
String endReasonText(AppLocalizations l10n, LiveRoomEndReason? reason) =>
    switch (reason) {
      LiveRoomEndReason.hostEnded => l10n.liveRoomEndedByHost,
      LiveRoomEndReason.heartbeatTimeout => l10n.liveRoomEndedTimeout,
      LiveRoomEndReason.hostAwayTimeout => l10n.liveRoomEndedHostAway,
      LiveRoomEndReason.hostSuspended ||
      LiveRoomEndReason.admin ||
      LiveRoomEndReason.unknown ||
      null => l10n.liveRoomEndedOther,
    };

/// D216: the badge on the host's picture saying why the live ended.
IconData endReasonIcon(LiveRoomEndReason? reason) => switch (reason) {
  LiveRoomEndReason.hostEnded => Icons.stop_rounded,
  LiveRoomEndReason.heartbeatTimeout => Icons.wifi_off_rounded,
  LiveRoomEndReason.hostAwayTimeout => Icons.hourglass_bottom_rounded,
  LiveRoomEndReason.hostSuspended ||
  LiveRoomEndReason.admin ||
  LiveRoomEndReason.unknown ||
  null => Icons.sensors_off_rounded,
};

/// A person's card in a live ([LivePersonSheet], D220; the host's
/// mini-profile of HL-L2 too), from `GET /users/{username}` and
/// `GET /users/{username}/levels`. In a room ([scope]) its top row adds
/// «إبلاغ», the person's points in this live (everyone), kick and chat mute
/// (the host and moderators), make or remove moderator (the host) and ⋯
/// with report and block (LivePersonTools); the host may invite the person
/// to a seat ([onInvite]).
Future<void> showHostSheet(
  BuildContext context,
  String username, {
  LivePersonScope? scope,
  VoidCallback? onInvite,
  KabsoProfileHeader? header,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  // Owner (2026-10-26): the card stays still; no swipe moves it.
  enableDrag: false,
  backgroundColor: const Color(0x00000000),
  barrierColor: KMetrics.roomSheetBarrier,
  // Owner (2026-10-26): the card is as tall as its content, laid out to
  // stay under the middle of a common phone (393×852); a small phone lets
  // it grow a little rather than scroll (the card must not move). Only
  // very large text scrolls.
  constraints: KMetrics.sheetConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * 0.62,
  ),
  builder: (_) => LivePersonSheet(
    username: username,
    scope: scope,
    onInvite: onInvite,
    header: header,
  ),
);

/// D231 (owner: «عند الضغط على الخصم لا تظهر البطاقة التعريفية»): the other
/// PK room's host's card, from either room's screen. It belongs to *their*
/// room: the points are theirs, nobody here moderates them, and there is
/// no gift button — a gift is sent in the room it is watched in, to its
/// host or a seated guest (§10.23), and the other host is in neither, so
/// the server would refuse it (409 `LIVE_GIFT_RECIPIENT_UNAVAILABLE`).
/// Follow, chat, report and the profile work as on any card.
Future<void> showPkOpponentCard(BuildContext context, PkSide opponent) =>
    showHostSheet(
      context,
      opponent.host.username,
      scope: LivePersonScope(
        roomId: opponent.roomId,
        target: LivePersonRole.host,
      ),
    );

/// D231: the «+» on the other PK host's chip — only when the profile is
/// read, this person may follow them (not yourself) and does not yet (a
/// pending request hides it too); a tap follows through the real API
/// (`publicProfileProvider`, optimistic; a failure says why).
VoidCallback? pkFollowOpponent(
  BuildContext context,
  WidgetRef ref,
  UserSummary host,
) {
  if (ref.watch(currentUserProvider)?.id == host.id) return null;
  final profile = ref.watch(publicProfileProvider(host.username)).value;
  if (profile == null ||
      !profile.canFollowOrRequest ||
      profile.isFollowing ||
      profile.followRequested) {
    return null;
  }
  return () =>
      unawaited(setHostFollowing(context, ref, host.username, follow: true));
}

class _FollowButton extends StatelessWidget {
  const new({
    required this.following,
    required this.onPressed,
    this.requested = false,
  });

  final bool following;
  final VoidCallback onPressed;

  /// D175: a pending request to the private host («تم الطلب»).
  final bool requested;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // D221: the ended card's full-width red «متابعة» with a boxed plus;
    // following / requested keep the dark one (still a toggle, as before).
    return KLiveInterruptionButton(
      key: const Key('room.follow'),
      label: following
          ? l10n.liveFollowing
          : requested
          ? l10n.followRequested
          : l10n.liveFollow,
      icon: following
          ? Icons.check_rounded
          : requested
          ? Icons.hourglass_top_rounded
          : Icons.add_box_outlined,
      primary: !following && !requested,
      onPressed: onPressed,
    );
  }
}

/// D216: an interruption card over the empty video, a little above the
/// centre so the chat under it stays clear.
class _StageNote extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.25),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(KSpacing.xl),
      child: child,
    ),
  );
}

/// The seat button of a MULTI or AUDIO room (CP-011): ask / cancel /
/// leave; moderators also get the requests. Guests without an account only
/// watch (owner D94), so they see nothing here.
class _SeatBar extends StatelessWidget {
  const new({
    required this.session,
    required this.signedIn,
    required this.onRequest,
    required this.onCancel,
    required this.onLeave,
    required this.onRequests,
  });

  final LiveRoomSessionState session;
  final bool signedIn;
  final Future<void> Function() onRequest;
  final Future<void> Function() onCancel;
  final Future<void> Function() onLeave;
  final Future<void> Function() onRequests;

  static const requestKey = Key('room.seat.request');
  static const cancelKey = Key('room.seat.cancel');
  static const leaveKey = Key('room.seat.leave');
  static const requestsKey = Key('room.seat.requests');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mine = session.mine;
    if (!signedIn || mine == null) return const SizedBox.shrink();
    final Widget main;
    if (session.seated) {
      main = _pill(
        context,
        leaveKey,
        Icons.logout_rounded,
        l10n.liveSeatLeave,
        onLeave,
      );
    } else if (mine.request != null) {
      main = _pill(
        context,
        cancelKey,
        Icons.hourglass_top_rounded,
        l10n.liveSeatRequested,
        onCancel,
      );
    } else {
      main = _pill(
        context,
        requestKey,
        Icons.front_hand_rounded,
        l10n.liveSeatRequest,
        onRequest,
        filled: true,
      );
    }
    final pending = session.seats?.pendingRequests ?? 0;
    return Row(
      children: [
        Expanded(child: main),
        if (session.canModerate) ...[
          const SizedBox(width: KSpacing.sm),
          Badge(
            isLabelVisible: pending > 0,
            label: Text(KFormat.compact(pending, l10n)),
            child: _pill(
              context,
              requestsKey,
              Icons.shield_rounded,
              l10n.liveSeatRequests,
              onRequests,
            ),
          ),
        ],
      ],
    );
  }

  Widget _pill(
    BuildContext context,
    Key key,
    IconData icon,
    String label,
    Future<void> Function() onTap, {
    bool filled = false,
  }) {
    const p = KPalette.dark;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: key,
        onTap: () => unawaited(onTap()),
        child: Container(
          height: KSizes.minTouchTarget - 4,
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          decoration: BoxDecoration(
            gradient: filled
                ? const LinearGradient(colors: KBrandColors.gradientLive)
                : null,
            color: filled ? null : p.scrim,
            borderRadius: BorderRadius.circular(KRadius.pill),
            border: Border.all(color: p.textPrimary.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: p.textPrimary),
              const SizedBox(width: KSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.label.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The viewer's audio room buttons (D94).
abstract final class AudioRoomViewKeys {
  /// D232: the host pill (the video live's [KHostPill]; its follow capsule
  /// replaced the card's follow circle).
  static const pill = Key('audioRoom.pill');
  static const share = Key('audioRoom.share');
  static const close = Key('audioRoom.close');
  static const chat = Key('audioRoom.chat');
  static const request = Key('audioRoom.seat.request');
  static const cancel = Key('audioRoom.seat.cancel');
  static const leave = Key('audioRoom.seat.leave');
  static const requests = Key('audioRoom.requests');
  static const gift = Key('audioRoom.gift');

  /// D173: games (the joystick).
  static const games = Key('audioRoom.games');

  /// D173: ≡, the room menu (viewer and moderator items).
  static const menu = Key('audioRoom.menu');
  static const mic = Key('audioRoom.mic');

  /// D138: an emoji on my own seat (seated only).
  static const seatEmoji = Key('audioRoom.seatEmoji');
}
