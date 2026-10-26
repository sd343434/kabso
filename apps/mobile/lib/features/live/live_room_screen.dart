import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_room_provider.dart';
import 'package:kabso_live/features/live/application/live_room_session.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_theme_art.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_boxes.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_tap_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/medals/presentation/medal_showcase_row.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
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
/// - share: no room link domain (B7) → no share button.
///
/// States (HL-L10): loading, live (video unavailable), ended (host ended /
/// heartbeat timeout / other), not found, error and offline with Try again.
class LiveRoomScreen extends ConsumerWidget {
  const new({required this.roomId, super.key});

  /// CP-012: the live's points next to the viewer count.
  static const scoreKey = Key('room.score');

  /// v1.20-live (D105): this person was kicked out of the live.
  static const kickedKey = Key('room.kicked');

  final String roomId;

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
      body = _RoomView(room: room, onClose: close);
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
  const new({required this.room, required this.onClose});

  final LiveRoom room;
  final VoidCallback onClose;

  @override
  ConsumerState<_RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends ConsumerState<_RoomView> {
  /// Latched once the ended overlay has offered Follow, so the button stays
  /// (as "Following") after the tap instead of vanishing.
  bool _endedOfferedFollow = false;

  String get _username => widget.room.host.username;

  // The audio room's chat box (D94: the same as the host's).
  final _chat = TextEditingController();
  final _chatFocus = FocusNode();
  bool _writing = false;

  @override
  void dispose() {
    _chat.dispose();
    _chatFocus.dispose();
    super.dispose();
  }

  bool _started = false;
  String? _inviteShown;
  bool _mutedShown = false;

  Future<void> _setFollowing({required bool follow}) =>
      setHostFollowing(context, ref, _username, follow: follow);

  LiveRoomSession get _session =>
      ref.read(liveRoomSessionProvider(widget.room.id).notifier);

  void _start() {
    if (_started || widget.room.status != LiveRoomStatus.live) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final room = widget.room;
      unawaited(_session.start(room));
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
  void _person(String username) {
    final room = widget.room;
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
        ),
      ),
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

  Future<void> _openChat(({bool canWrite, String hint}) composer) async {
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
    setState(() => _writing = true);
    _chatFocus.requestFocus();
  }

  void _sendChat() => unawaited(
    sendLiveChatFrom(context, ref, roomId: widget.room.id, field: _chat),
  );

  Widget _roomChat(LiveRoomSessionState session, {Color? bubble}) =>
      LiveRoomChatLines(
        roomId: widget.room.id,
        role: _chatRole(session),
        bubble: bubble ?? KAudioRoom.bubble,
        onProfile: _person,
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
    final join = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        key: const Key('room.seatInvite'),
        title: Text(l10n.liveSeatInviteTitle),
        content: Text(l10n.liveSeatInviteBody(invite.invitedBy.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.liveSeatInviteDecline),
          ),
          FilledButton(
            key: const Key('room.seatInvite.accept'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.liveSeatInviteAccept),
          ),
        ],
      ),
    );
    if (!mounted || join == null) return;
    await runSeatAction(
      context,
      join ? _session.acceptInvite : _session.declineInvite,
    );
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
      unawaited(
        runSeatAction(
          context,
          () => _session.requestSeat(seatIndex: seat.index),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final room = widget.room;
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
    // CP-017: bullets from every live show in the chat (owner, 2026-10-26).
    return ListenableBuilder(
      listenable: engine.changes,
      builder: (context, _) => _scaffold(context, session, engine),
    );
  }

  Widget _scaffold(
    BuildContext context,
    LiveRoomSessionState session,
    LiveMediaEngine engine,
  ) {
    final l10n = context.l10n;
    final room = widget.room;
    final host = room.host;
    final avatar = _networkImage(host.avatarUrl);
    final profile = ref.watch(publicProfileProvider(_username)).value;
    final canFollow = profile?.canFollow ?? false;
    final following = profile?.isFollowing ?? false;
    final ended = room.status == LiveRoomStatus.ended;
    if (ended && canFollow && !following) _endedOfferedFollow = true;

    // CP-012: signed-in viewers other than the host tap to cheer (D95).
    final me = ref.watch(currentUserProvider);
    final canTap = !ended && me != null && me.id != host.id;
    final score = engine.score ?? session.score ?? room.score;
    final composer = liveChatComposerHint(
      l10n,
      chat: ref.watch(liveChatProvider(room.id)),
      role: _chatRole(session),
    );
    if (!ended && room.mode == LiveRoomMode.audio) {
      return _audioRoom(
        session: session,
        engine: engine,
        score: score,
        canTap: canTap,
        signedIn: me != null,
        canFollow: canFollow && !following,
        composer: composer,
      );
    }
    return KLiveRoomScaffold(
      // Ended: the overlay explains; no video message underneath it.
      video: ended
          ? const KLiveVideoPlaceholder(child: SizedBox.shrink())
          : LiveTapLayer(
              onTap: canTap ? _session.tap : null,
              // D101: only the charm tiers the host has reached.
              maxTier: CharmTier.of(room.roomLevel ?? 1).number,
              child: _video(session, engine),
            ),
      stage: !ended && room.mode.hasSeats ? _stage(session, engine) : null,
      header: KHostPill(
        hostName: host.displayName,
        avatar: avatar,
        subtitle: profile == null
            ? null
            : l10n.liveRoomFollowers(
                profile.followerCount,
                KFormat.compact(profile.followerCount, l10n),
              ),
        following: following,
        onFollow: canFollow
            ? () => unawaited(_setFollowing(follow: true))
            : null,
        onTap: profile == null ? null : () => _person(_username),
      ),
      // Presence does not exist yet: a count only when the API has one.
      viewers: room.viewerCount > 0 || score > 0
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (score > 0)
                  KScoreChip(key: LiveRoomScreen.scoreKey, score: score),
                if (score > 0 && room.viewerCount > 0)
                  const SizedBox(width: KSpacing.xs),
                if (room.viewerCount > 0) KViewerStrip(count: room.viewerCount),
              ],
            )
          : null,
      onClose: widget.onClose,
      roomInfo: KRoomInfoRow(
        title: room.title,
        category: room.category?.name,
        level: room.roomLevel,
      ),
      chat: ended
          ? null
          : Align(
              alignment: AlignmentDirectional.bottomStart,
              child: _roomChat(session, bubble: KLiveColors.chatScrim),
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
                    onRequest: () =>
                        runSeatAction(context, () => _session.requestSeat()),
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
                _chatComposer(composer) ??
                    LiveChatPill(
                      key: AudioRoomViewKeys.chat,
                      hint: composer.hint,
                      onTap: () => unawaited(_openChat(composer)),
                    ),
                const SizedBox(height: KSpacing.sm),
                KRoomActionBar(onGift: () => unawaited(_openGifts(context))),
              ],
            ),
      cover: ended
          ? KRoomEndedOverlay(
              hostName: host.displayName,
              avatar: avatar,
              reason: endReasonText(l10n, room.endReason),
              onBack: widget.onClose,
              followAction: _endedOfferedFollow && canFollow
                  ? _FollowButton(
                      following: following,
                      onPressed: () =>
                          unawaited(_setFollowing(follow: !following)),
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
    required int score,
    required bool canTap,
    required bool signedIn,
    required bool canFollow,
    required ({bool canWrite, String hint}) composer,
  }) {
    final l10n = context.l10n;
    final room = widget.room;
    final host = room.host;
    final mine = session.mine;
    final pending = session.seats?.pendingRequests ?? 0;

    // The seat button follows the viewer's state (CP-011).
    LiveRoundButton? seatButton;
    if (signedIn && mine != null) {
      if (session.seated) {
        seatButton = LiveRoundButton(
          key: AudioRoomViewKeys.leave,
          icon: Icons.logout_rounded,
          label: l10n.liveSeatLeave,
          onTap: () => unawaited(runSeatAction(context, _session.leaveSeat)),
        );
      } else if (mine.request != null) {
        seatButton = LiveRoundButton(
          key: AudioRoomViewKeys.cancel,
          icon: Icons.hourglass_top_rounded,
          label: l10n.liveSeatRequested,
          onTap: () =>
              unawaited(runSeatAction(context, _session.cancelRequest)),
        );
      } else {
        seatButton = LiveRoundButton(
          key: AudioRoomViewKeys.request,
          icon: Icons.weekend_rounded,
          asset: 'assets/live_bar/seat.png',
          bare: true,
          label: l10n.liveSeatRequest,
          onTap: () =>
              unawaited(runSeatAction(context, () => _session.requestSeat())),
        );
      }
    }
    return KLiveSurface(
      child: Material(
        color: KPalette.dark.background,
        // The whole room cheers (the stage scrolls, so a tap layer under it
        // would never be hit); seats, buttons and the chat keep their taps.
        child: LiveTapLayer(
          onTap: canTap ? _session.tap : null,
          // D101: only the charm tiers the host has reached.
          maxTier: CharmTier.of(room.roomLevel ?? 1).number,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _video(session, engine),
              LiveAudioRoomLayout(
                header: LiveAudioRoomHeader(
                  cover: KAvatar(
                    name: host.displayName,
                    imageUrl: host.avatarUrl,
                    size: 30,
                  ),
                  title: room.title,
                  level: room.roomLevel,
                  // CP-016 G (ref 83): the room number, else the username.
                  subtitle: switch (room.roomNumber) {
                    final n? => l10n.liveRoomNumber('$n'),
                    null => '@${host.username}',
                  },
                  onTap: () => _person(_username),
                  action: canFollow
                      ? LiveRoundButton(
                          key: AudioRoomViewKeys.follow,
                          icon: Icons.person_add_alt_1_rounded,
                          label: l10n.liveFollow,
                          size: 24,
                          iconSize: 14,
                          color: const Color(0xFFFF4D7A),
                          onTap: () => unawaited(_setFollowing(follow: true)),
                        )
                      : null,
                  showMinimize: false,
                  minimizeTooltip: '',
                  onMinimize: null,
                  shareKey: AudioRoomViewKeys.share,
                  shareTooltip: l10n.goLiveShare,
                  onShare: () => unawaited(_share(room.title, host.username)),
                  endKey: AudioRoomViewKeys.close,
                  endTooltip: l10n.liveClose,
                  onEnd: widget.onClose,
                ),
                chips: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          // Ref 83/84: the room rank, then the live's points.
                          children: [
                            const Flexible(child: LiveRankChip()),
                            if (score > 0) ...[
                              const SizedBox(width: 8),
                              LiveScoreChip(
                                text: KFormat.compact(score, l10n),
                                label: l10n.liveScore(
                                  score,
                                  KFormat.grouped(score),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (room.viewerCount > 0)
                      LiveViewersStack(
                        avatars: const [],
                        count: KFormat.compact(room.viewerCount, l10n),
                        label: l10n.liveViewers(
                          room.viewerCount,
                          KFormat.grouped(room.viewerCount),
                        ),
                      ),
                  ],
                ),
                stage: _stage(session, engine),
                chat: [_roomChat(session)],
                composer: _chatComposer(composer),
                // Ref 83: chat and emoji on one side; the seat, requests,
                // gifts and the mic on the other.
                barStart: [
                  LiveRoundButton(
                    key: AudioRoomViewKeys.chat,
                    icon: Icons.chat_bubble_outline_rounded,
                    asset: 'assets/live_bar/chat.png',
                    bare: true,
                    label: composer.hint,
                    onTap: () => unawaited(_openChat(composer)),
                  ),
                  LiveRoundButton(
                    icon: Icons.emoji_emotions_rounded,
                    asset: 'assets/live_bar/emoji.png',
                    bare: true,
                    label: l10n.livePreviewEmoji,
                    onTap: () => unawaited(_openChat(composer)),
                  ),
                ],
                barEnd: [
                  ?seatButton,
                  if (session.canModerate)
                    LiveRoundButton(
                      key: AudioRoomViewKeys.requests,
                      icon: Icons.front_hand_rounded,
                      label: l10n.liveSeatRequests,
                      badge: pending,
                      onTap: () => unawaited(
                        showSeatRequests(
                          context,
                          roomId: room.id,
                          onAccept: _session.accept,
                          onDecline: _session.decline,
                        ),
                      ),
                    ),
                  LiveRoundButton(
                    key: AudioRoomViewKeys.gift,
                    icon: Icons.card_giftcard_rounded,
                    asset: 'assets/live_bar/gift.png',
                    bare: true,
                    label: l10n.liveGifts,
                    onTap: () => unawaited(_openGifts(context)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(String title, String username) async {
    final l10n = context.l10n;
    await Clipboard.setData(
      ClipboardData(text: l10n.goLiveShareText(title, username)),
    );
    if (mounted) KSnack.success(context, l10n.goLiveShareCopied);
  }

  /// SOLO: the host's video, "the host will be right back" while they are
  /// away, or the join failure. Seat rooms: the theme (seats are the stage).
  Widget _video(LiveRoomSessionState session, LiveMediaEngine engine) {
    final room = widget.room;
    if (room.mode.hasSeats) {
      if (room.mode == LiveRoomMode.audio && room.theme == LiveThemes.classic) {
        return const LiveAudioRoomBackground();
      }
      return LiveThemeBackground(theme: room.theme);
    }
    final picture = engine.remoteVideo(room.host.id);
    if (picture != null) return SizedBox.expand(child: picture);
    final failure = session.joinFailure;
    if (failure != null) {
      return KLiveVideoPlaceholder(
        child: _StageNote(
          key: const Key('room.joinFailed'),
          icon: Icons.videocam_off_outlined,
          text: failureMessage(context.l10n, failure),
        ),
      );
    }
    if (session.joined && !engine.isPresent(room.host.id)) {
      return KLiveVideoPlaceholder(
        child: _StageNote(
          key: const Key('room.hostAway'),
          icon: Icons.hourglass_top_rounded,
          text: context.l10n.liveHostAway,
        ),
      );
    }
    return const KLiveVideoPlaceholder(child: SizedBox.shrink());
  }

  /// MULTI: the host's tile and the seats; AUDIO: the crowned circle and
  /// rows of seats. A seated viewer sees their own camera in their tile.
  Widget _stage(LiveRoomSessionState session, LiveMediaEngine engine) {
    final room = widget.room;
    final seats = session.seats;
    final art = LiveThemeArt.of(room.theme);
    final count = seats?.seatCount ?? room.seatCount ?? 0;
    // CP-012: the live's points under the host (ref 83).
    final score = engine.score ?? session.score ?? room.score;
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
      // Owner (2026-10-26): on my own seat, a tap mutes or unmutes me.
      if (seat != null && me != null && seat.user?.id == me) {
        unawaited(engine.setMicEnabled(enabled: !engine.micEnabled));
        return;
      }
      if (seat != null) _onSeat(session, seat);
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
              ? engine.preview()
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
    // The room's stage scrolls, and rows of seats shrink to fit it
    // (AudioStageBounds).
    return AudioSeatRing(
      count: count,
      seats: seats?.seats ?? const [],
      host: KAvatar(
        name: host.displayName,
        imageUrl: host.avatarUrl,
        size: AudioSeatRing.hostSize,
      ),
      hostName: host.displayName,
      hostPoints: KFormat.compact(score, context.l10n),
      speaking: speaking,
      micOff: {
        if (session.mine?.seatIndex case final mine? when !engine.micEnabled)
          mine,
      },
      onSeat: onSeat,
    );
  }

  static Future<void> _openGifts(BuildContext context) =>
      KGiftPreviewSheet.show(context);
}

/// The localized end reason (HL-L10).
String endReasonText(AppLocalizations l10n, LiveRoomEndReason? reason) =>
    switch (reason) {
      LiveRoomEndReason.hostEnded => l10n.liveRoomEndedByHost,
      LiveRoomEndReason.heartbeatTimeout => l10n.liveRoomEndedTimeout,
      LiveRoomEndReason.hostSuspended ||
      LiveRoomEndReason.admin ||
      LiveRoomEndReason.unknown ||
      null => l10n.liveRoomEndedOther,
    };

/// Follows or unfollows the host through [publicProfileProvider]
/// (optimistic); a failure has already been rolled back and shows a snack.
Future<void> setHostFollowing(
  BuildContext context,
  WidgetRef ref,
  String username, {
  required bool follow,
}) async {
  final l10n = context.l10n;
  try {
    await ref
        .read(publicProfileProvider(username).notifier)
        .setFollowing(follow: follow);
  } on Object catch (e) {
    if (!context.mounted) return;
    KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
  }
}

/// A person's card in a live (owner, 2026-10-26; the host's mini-profile of
/// HL-L2 too): a white sheet with the picture over its top edge, the name
/// with their charm level, @username, their public levels and the medals
/// they chose to show (CP-018), the family, relationship and gift wall boxes
/// (the family and couple from the profile; the gift wall is coming),
/// followers and following, Follow, and Invite to a seat (the host,
/// [onInvite]) or their full profile. All from `GET /users/{username}` and
/// `GET /users/{username}/levels`.
///
/// In a room ([scope]) the top row adds the person's points in this live
/// (everyone), kick and chat mute (the host and moderators), make or remove
/// moderator (the host) and ⋯ with report and block (LivePersonTools).
Future<void> showHostSheet(
  BuildContext context,
  String username, {
  LivePersonScope? scope,
  VoidCallback? onInvite,
  KabsoProfileHeader? header,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0x00000000),
  barrierColor: KMetrics.roomSheetBarrier,
  // Owner (2026-10-26): the card never goes above the middle of the
  // screen; the rest scrolls.
  constraints: KMetrics.sheetConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * 0.5,
  ),
  builder: (_) => _HostSheet(
    username: username,
    scope: scope,
    onInvite: onInvite,
    header: header,
  ),
);

abstract final class _Card {
  static const ink = Color(0xFF2E3130);
  static const soft = Color(0xFF9A9BA5);
  static const avatar = 92.0;

  /// The gold edge and the picture's ring (owner's reference, 2026-10-26).
  static const gold = [Color(0xFFFFE58A), Color(0xFFF2B84B), Color(0xFFD9922E)];
}

class _HostSheet extends ConsumerWidget {
  const new({required this.username, this.scope, this.onInvite, this.header});

  final String username;
  final LivePersonScope? scope;
  final VoidCallback? onInvite;

  /// The person's header decoration on the card's top edge (owner,
  /// 2026-10-26); null: the plain gold edge.
  final KabsoProfileHeader? header;

  static const inviteKey = Key('room.userCard.invite');

  /// The picture: opens the person's full profile (owner, 2026-10-26).
  static const profileKey = Key('room.userCard.profile');
  static const messageKey = Key('room.userCard.message');
  static const giftKey = Key('room.userCard.gift');
  static const copyKey = Key('room.userCard.copy');
  static const medalsKey = Key('room.userCard.medals');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final loaded = ref.watch(publicProfileProvider(username));
    final profile = loaded.value;
    final levels = ref.watch(profileLevelsProvider(username)).value ?? const [];
    final shown = [
      for (final l in levels)
        if (l.level != null) l,
    ];
    final charm = shown
        .where((l) => l.category == LevelCategory.attractiveness)
        .firstOrNull
        ?.level;
    final onInvite = this.onInvite;
    // CP-018: what the relationship box does for this viewer.
    final cpAction = profile == null
        ? BondTap.none
        : cpTap(profile, signedIn: ref.watch(currentUserProvider) != null);
    final scope = this.scope;
    void close(VoidCallback then) {
      Navigator.of(context).pop();
      then();
    }

    Widget stat(int value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            KFormat.compact(value, l10n),
            style: text.title.copyWith(color: _Card.ink, fontSize: 20),
          ),
          const SizedBox(height: 2),
          Text(label, style: text.caption.copyWith(color: _Card.soft)),
        ],
      ),
    );
    Widget action({
      required Key key,
      required String label,
      required VoidCallback onTap,
      String? asset,
      Widget? glyph,
    }) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        key: key,
        onTap: onTap,
        radius: 32,
        child: SizedBox(
          width: 70,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              glyph ?? Image.asset(asset!, width: 32, height: 32),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.caption.copyWith(color: _Card.ink),
              ),
            ],
          ),
        ),
      ),
    );

    final body = profile == null
        ? SizedBox(
            height: 200,
            child: Center(
              child: switch (loaded.error) {
                final error? => Text(
                  failureMessage(l10n, toAppFailure(error)),
                  textAlign: TextAlign.center,
                  style: text.body.copyWith(color: _Card.soft),
                ),
                null => const CircularProgressIndicator(),
              },
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Room for the picture.
              const SizedBox(height: _Card.avatar / 2 + 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(
                        profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.title.copyWith(
                          color: _Card.ink,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  // Owner (2026-10-26): everyone sees that the person is the
                  // host or a moderator of this live.
                  if (scope?.target case final role?
                      when role != LivePersonRole.viewer) ...[
                    const SizedBox(width: 6),
                    _RoleBadge(host: role == LivePersonRole.host),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              // @username, copied with one tap (the reference's ID line).
              InkWell(
                key: copyKey,
                borderRadius: BorderRadius.circular(KRadius.pill),
                onTap: () {
                  unawaited(
                    Clipboard.setData(
                      ClipboardData(text: '@${profile.username}'),
                    ),
                  );
                  KSnack.info(context, l10n.profileCopied);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.liveRoomUsername(profile.username),
                        textDirection: TextDirection.ltr,
                        style: text.body.copyWith(color: _Card.soft),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: _Card.soft,
                      ),
                    ],
                  ),
                ),
              ),
              // Owner (2026-10-26): every level in one row, the charm level
              // first; a long row scrolls sideways.
              if (shown.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (charm != null)
                          CharmLevelBadge(level: charm.levelNumber, height: 18),
                        for (final l in shown)
                          if (l.category != LevelCategory.attractiveness) ...[
                            const SizedBox(width: 8),
                            Semantics(
                              label: '${l.name} ${l.level!.levelNumber}',
                              excludeSemantics: true,
                              child: KLevelBadge(
                                category: l.category,
                                levelNumber: l.level!.levelNumber,
                                iconKey: l.level!.iconKey,
                              ),
                            ),
                          ],
                      ],
                    ),
                  ),
                ),
              // CP-018 (owner): the medals the person chose to show, up to
              // six in one row under the levels; nothing when none are
              // chosen.
              if (profile.medals.showcase.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: MedalShowcaseRow(
                    key: medalsKey,
                    medals: profile.medals.showcase,
                    size: 24,
                    onTap: () => close(
                      () => unawaited(
                        context.push(
                          profile.isSelf
                              ? AppRoutes.medals
                              : AppRoutes.userMedals(username),
                        ),
                      ),
                    ),
                  ),
                ),
              if (profile.bio case final bio? when bio.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: text.body.copyWith(color: _Card.ink),
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  stat(profile.followerCount, l10n.profileFollowers),
                  stat(profile.followingCount, l10n.profileFollowingCount),
                ],
              ),
              // Owner (2026-10-26; under the stats): family, relationship
              // and gift wall as three small boxes side by side. CP-018: the
              // family and the couple come from the profile and open what
              // exists; the gift wall has no API yet.
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: LivePersonBoxes(
                  familyValue: switch (profile.family) {
                    // The box is narrow: the name only (the level is on
                    // the family page).
                    final f? => KFormat.bidiIsolate(f.name),
                    null => null,
                  },
                  cpValue: profile.cp == null && cpAction == BondTap.sendCp
                      ? l10n.cpSendShort
                      : null,
                  // Owner: the partner's picture, name and a heart.
                  cpPartner: switch (profile.cp) {
                    final cp? => (
                      name: KFormat.bidiIsolate(
                        cp.partner.displayName.isEmpty
                            ? cp.partner.username
                            : cp.partner.displayName,
                      ),
                      avatar: _networkImage(cp.partner.avatarUrl),
                    ),
                    null => null,
                  },
                  onFamily: bondAction(
                    context,
                    ref,
                    profile,
                    familyTap(profile),
                    before: Navigator.of(context).pop,
                  ),
                  onCp: bondAction(
                    context,
                    ref,
                    profile,
                    cpAction,
                    before: Navigator.of(context).pop,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFEDEEF2)),
              const SizedBox(height: 12),
              Row(
                children: [
                  action(
                    key: giftKey,
                    asset: 'assets/live_bar/gift.png',
                    label: l10n.liveGifts,
                    onTap: () =>
                        close(() => unawaited(KGiftPreviewSheet.show(context))),
                  ),
                  if (onInvite != null)
                    action(
                      key: inviteKey,
                      asset: 'assets/live_bar/seat.png',
                      label: l10n.liveSeatInviteSend,
                      onTap: () => close(onInvite),
                    )
                  else if (!profile.isSelf)
                    // Owner (2026-10-26): Message here; the picture opens
                    // the profile.
                    action(
                      key: messageKey,
                      glyph: const _MessageGlyph(),
                      label: l10n.profileMessage,
                      onTap: () => close(
                        () => unawaited(
                          context.push(
                            AppRoutes.chat(profile.username),
                            extra: profile.displayName,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (profile.canFollow)
                    Expanded(
                      child: _FollowButton(
                        following: profile.isFollowing,
                        onPressed: () => unawaited(
                          setHostFollowing(
                            context,
                            ref,
                            username,
                            follow: !profile.isFollowing,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );

    final header = this.header;
    return LayoutBuilder(
      builder: (context, box) {
        // The card's top edge: under the middle of the picture, or lower when
        // the header decoration rises higher than the picture.
        final edge = header == null
            ? _Card.avatar / 2
            : math.max(_Card.avatar / 2, header.overhang(box.maxWidth));
        return Stack(
          key: const Key('room.hostSheet'),
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            // Attached to the bottom (not a floating card), with a gold edge.
            Container(
              margin: EdgeInsets.only(top: edge),
              // The header's own bar is the edge: no gold line under it.
              padding: EdgeInsets.only(top: header == null ? 3 : 0),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(colors: _Card.gold),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFFFFFF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: SafeArea(
                  top: false,
                  // Large text: the card scrolls instead of overflowing.
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: body,
                  ),
                ),
              ),
            ),
            if (header != null)
              Positioned(
                top: edge - header.overhang(box.maxWidth),
                left: 0,
                child: KabsoProfileHeaderArt(
                  header,
                  key: const Key('room.userCard.header'),
                  width: box.maxWidth,
                ),
              ),
            // The top row: points, kick, mute, moderator at the start; ⋯ at
            // the end (owner's reference), either side of the picture.
            if (scope != null && profile != null)
              PositionedDirectional(
                top: edge + 8,
                start: 10,
                end: 10,
                child: LivePersonTools(
                  scope: scope,
                  person: (
                    id: profile.id,
                    username: username,
                    name: profile.displayName,
                  ),
                  self: profile.isSelf,
                  middle: _Card.avatar + 16,
                ),
              ),
            // The picture in a gold ring, the charm level on a plate under it.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: edge - _Card.avatar / 2),
                Semantics(
                  button: true,
                  label: l10n.liveUserViewProfile,
                  child: GestureDetector(
                    key: profileKey,
                    onTap: () => close(
                      () => unawaited(
                        context.push(AppRoutes.userProfile(username)),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: _Card.gold,
                        ),
                        boxShadow: [
                          BoxShadow(color: Color(0x55F2B84B), blurRadius: 14),
                        ],
                      ),
                      child: ClipOval(
                        child: SizedBox.square(
                          dimension: _Card.avatar,
                          child: KAvatar(
                            name: profile?.displayName ?? username,
                            image: _networkImage(profile?.avatarUrl),
                            size: _Card.avatar,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The card's Message button art (owner, 2026-10-26: the flat bubble looked
/// poor): a glossy bubble in a blue-to-violet gradient with a soft shine and
/// three white dots, sized like the gift icon beside it.
class _MessageGlyph extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 32,
    child: Stack(
      alignment: Alignment.center,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6FB6FF), Color(0xFF6A5CFF)],
          ).createShader(r),
          child: const Icon(Icons.mode_comment_rounded, size: 32),
        ),
        // A soft shine on the upper part.
        Positioned(
          top: 5,
          left: 7,
          child: Container(
            width: 10,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0x66FFFFFF),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 2.5),
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

/// The host's or a moderator's badge next to the name on a person's card.
class _RoleBadge extends StatelessWidget {
  const new({required this.host});

  final bool host;

  static const badgeKey = Key('room.userCard.roleBadge');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = host ? l10n.goLiveHostTag : l10n.liveSeatModeratorTag;
    final colors = host
        ? const [Color(0xFFFFC94D), Color(0xFFF29A1F)]
        : const [Color(0xFF6FA8FF), Color(0xFF3B6FE0)];
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        key: badgeKey,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KRadius.pill),
          gradient: LinearGradient(colors: colors),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              host ? Icons.mic_rounded : Icons.shield_rounded,
              size: 13,
              color: const Color(0xFFFFFFFF),
            ),
            const SizedBox(width: 3),
            Text(
              label,
              style: context.textStyles.caption.copyWith(
                color: const Color(0xFFFFFFFF),
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  const new({required this.following, required this.onPressed});

  final bool following;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return KButton(
      key: const Key('room.follow'),
      label: following ? l10n.liveFollowing : l10n.liveFollow,
      icon: following ? Icons.check_rounded : Icons.add_rounded,
      variant: following ? KButtonVariant.secondary : KButtonVariant.primary,
      onPressed: onPressed,
      expand: false,
    );
  }
}

/// The gift sheet's selection (sending is disabled; no combo counter).
class _StageNote extends StatelessWidget {
  const new({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    const p = KPalette.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: KSpacing.xxxl, color: p.textSecondary),
            const SizedBox(height: KSpacing.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyStrong.copyWith(
                color: p.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  static const follow = Key('audioRoom.follow');
  static const share = Key('audioRoom.share');
  static const close = Key('audioRoom.close');
  static const chat = Key('audioRoom.chat');
  static const request = Key('audioRoom.seat.request');
  static const cancel = Key('audioRoom.seat.cancel');
  static const leave = Key('audioRoom.seat.leave');
  static const requests = Key('audioRoom.requests');
  static const gift = Key('audioRoom.gift');
  static const mic = Key('audioRoom.mic');
}
