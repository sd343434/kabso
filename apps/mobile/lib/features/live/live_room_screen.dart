import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_room_provider.dart';
import 'package:kabso_live/features/live/application/live_room_session.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_theme_art.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_overlay.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
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
    if (room != null && !async.isLoading) {
      body = _RoomView(room: room, onClose: close);
    } else if (async.hasError && !async.isLoading) {
      body = _failure(l10n, toAppFailure(async.error!), close, retry);
    } else {
      body = _LoadingRoom(onClose: close);
    }
    return Scaffold(backgroundColor: KPalette.dark.background, body: body);
  }

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
      if (mounted) unawaited(_session.start(widget.room));
    });
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
    ref.listen(liveRoomSessionProvider(room.id), (_, next) {
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
    final engine = _session.engine;
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

    return KLiveRoomScaffold(
      // Ended: the overlay explains; no video message underneath it.
      video: ended
          ? const KLiveVideoPlaceholder(child: SizedBox.shrink())
          : _video(session, engine),
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
        onTap: profile == null
            ? null
            : () => unawaited(showHostSheet(context, _username)),
      ),
      // Presence does not exist yet: a count only when the API has one.
      viewers: room.viewerCount > 0
          ? KViewerStrip(count: room.viewerCount)
          : null,
      onClose: widget.onClose,
      roomInfo: KRoomInfoRow(title: room.title, category: room.category?.name),
      chat: ended
          ? null
          : KLiveChatOverlay(
              key: const Key('room.chatUnavailable'),
              lines: [LiveChatSystem(text: l10n.liveRoomChatUnavailable)],
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
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height * 0.55),
      child: SingleChildScrollView(
        child: AudioSeatRing(
          count: count,
          seats: seats?.seats ?? const [],
          host: KAvatar(
            name: host.displayName,
            imageUrl: host.avatarUrl,
            size: 50,
          ),
          hostName: host.displayName,
          speaking: speaking,
          onSeat: onSeat,
        ),
      ),
    );
  }

  static Future<void> _openGifts(BuildContext context) =>
      KGiftPanel.show(context, builder: (_) => const _GiftSheet());
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

/// The host's profile as a non-dimming room sheet (HL-L2 "tap opens the
/// host mini-profile"): avatar, name, @username, followers, bio and the
/// follow toggle, all from `GET /users/{username}`.
Future<void> showHostSheet(BuildContext context, String username) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KPalette.dark.surfaceRaised.withValues(alpha: 0),
      barrierColor: KMetrics.roomSheetBarrier,
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height * KMetrics.sheetMaxHeightFactor,
      ),
      builder: (_) => KLiveSurface(child: _HostSheet(username: username)),
    );

class _HostSheet extends ConsumerWidget {
  const new({required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final profile = ref.watch(publicProfileProvider(username)).value;
    final bio = profile?.bio;
    return Container(
      key: const Key('room.hostSheet'),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(KRadius.xl),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.xl,
            KSpacing.sm,
            KSpacing.xl,
            KSpacing.xl,
          ),
          child: profile == null
              ? const SizedBox(height: KSizes.avatarLg)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: KMetrics.sheetHandleWidth,
                      height: KMetrics.sheetHandleHeight,
                      decoration: BoxDecoration(
                        color: p.border,
                        borderRadius: BorderRadius.circular(KRadius.pill),
                      ),
                    ),
                    const SizedBox(height: KSpacing.lg),
                    KAvatar(
                      name: profile.displayName,
                      image: _networkImage(profile.avatarUrl),
                      size: KSizes.avatarLg,
                    ),
                    const SizedBox(height: KSpacing.md),
                    Semantics(
                      header: true,
                      child: Text(
                        profile.displayName,
                        textAlign: TextAlign.center,
                        style: text.title,
                      ),
                    ),
                    Text(
                      l10n.liveRoomUsername(profile.username),
                      textDirection: TextDirection.ltr,
                      style: text.caption,
                    ),
                    const SizedBox(height: KSpacing.sm),
                    Text(
                      l10n.liveRoomFollowers(
                        profile.followerCount,
                        KFormat.compact(profile.followerCount, l10n),
                      ),
                      style: text.body.copyWith(color: p.textSecondary),
                    ),
                    if (bio != null && bio.isNotEmpty) ...[
                      const SizedBox(height: KSpacing.sm),
                      Text(bio, textAlign: TextAlign.center, style: text.body),
                    ],
                    if (profile.canFollow) ...[
                      const SizedBox(height: KSpacing.lg),
                      _FollowButton(
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
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Follow / Following toggle button (ended overlay, host sheet).
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
class _GiftSheet extends StatefulWidget {
  const new();

  @override
  State<_GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends State<_GiftSheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) => KGiftPanel(
    gifts: KGiftPanel.preview(context.l10n),
    selectedId: _selected,
    onSelected: (gift) => setState(() => _selected = gift.id),
  );
}

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
