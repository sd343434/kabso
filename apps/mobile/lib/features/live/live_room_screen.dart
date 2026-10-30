import 'dart:async';
import 'dart:math' as math;

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
import 'package:kabso_live/features/cp/presentation/cp_special_frame.dart';
import 'package:kabso_live/features/levels/application/levels_providers.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart'
    show liveViewersPreviewProvider;
import 'package:kabso_live/features/live/application/live_lucky_ticker.dart';
import 'package:kabso_live/features/live/application/live_program.dart';
import 'package:kabso_live/features/live/application/live_quips.dart';
import 'package:kabso_live/features/live/application/live_room_provider.dart';
import 'package:kabso_live/features/live/application/live_room_session.dart';
import 'package:kabso_live/features/live/application/live_seat_emojis.dart';
import 'package:kabso_live/features/live/application/live_stickers.dart';
import 'package:kabso_live/features/live/application/live_watch.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_permissions.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_boost_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cinema.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cp_seats.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_newcomers_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_tools.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_score_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_emoji.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_theme_art.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_watch_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/live/presentation/live_permission_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_background_texts.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cp_entrance.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_games_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_guest_tiles.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_lucky_combo_button.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_boxes.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_states.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_side_cards.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_sticker_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_tap_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_watch_card.dart';
import 'package:kabso_live/features/medals/presentation/medal_showcase_row.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile/profile_bonds.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:kabso_live/features/safety/safety_actions.dart';
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
  const new({required this.roomId, super.key});

  /// CP-012: the live's points next to the viewer count.
  static const scoreKey = Key('room.score');

  /// D131: the host pill's taps line and the bar's gift button.
  static const tapsKey = Key('room.taps');
  static const giftKey = Key('room.gift');

  /// D154c: a moderator's Newcomers button.
  static const newcomersKey = Key('room.newcomers');

  /// D173: ≡, the room menu of everyone (viewer and moderator items).
  static const menuKey = Key('room.menu');

  /// D173: the video bar's games (joystick) and guest (∞) buttons, and the
  /// cherry chip beside the board chip.
  static const gamesKey = Key('room.games');
  static const guestKey = Key('room.guest');

  /// D174: ∞ while the request waits (cancel) and while seated (leave).
  static const guestCancelKey = Key('room.guest.cancel');
  static const guestLeaveKey = Key('room.guest.leave');
  static const scoreChipKey = Key('room.scoreChip');

  /// v1.20-live (D105): this person was kicked out of the live.
  static const kickedKey = Key('room.kicked');

  /// D109: who is watching (faces and count); opens the list.
  static const viewersKey = Key('room.viewers');

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

  @override
  void initState() {
    super.initState();
    _visits = ref.read(liveChatVisitsProvider);
  }

  @override
  void dispose() {
    endLiveChatVisit(_visits, widget.room.id);
    _chat.dispose();
    _chatFocus.dispose();
    super.dispose();
  }

  bool _started = false;
  String? _inviteShown;
  bool _mutedShown = false;

  Future<void> _setFollowing({required bool follow}) =>
      setHostFollowing(context, ref, _username, follow: follow);

  /// D131 (owner, ref 160): leaving asks to follow first when this viewer
  /// can follow the host and does not (signed in, not the host, a live
  /// room); otherwise it leaves at once.
  bool get _askBeforeLeaving {
    final room = _room;
    if (room.status != LiveRoomStatus.live) return false;
    final me = ref.read(currentUserProvider);
    if (me == null || me.id == room.host.id) return false;
    final profile = ref.read(publicProfileProvider(_username)).value;
    return profile != null && profile.canFollow && !profile.isFollowing;
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

  LiveRoomSession get _session =>
      ref.read(liveRoomSessionProvider(widget.room.id).notifier);

  void _start() {
    if (_started || widget.room.status != LiveRoomStatus.live) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final room = _room;
      unawaited(
        _session.start(
          room,
          background: liveBackgroundTexts(context.l10n),
          onLeave: () {
            if (mounted) closeLiveRoom(context);
          },
        ),
      );
      // CP-020: the room's gifts, on the same media session.
      ref
          .read(liveGiftEffectsProvider(room.id).notifier)
          .attach(_session.engine);
      // D138: the emojis people play on their seats.
      ref
          .read(liveSeatEmojisProvider(room.id).notifier)
          .attach(_session.engine);
      // D148: big lucky wins in other lives (the gold ticker).
      ref
          .read(liveLuckyTickersProvider(room.id).notifier)
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
        avatarSize: video ? 28.5 : LiveViewersStack.size,
        pitch: video ? 33.5 : LiveViewersStack.size - 7,
        countHeight: video ? 28 : LiveViewersStack.size,
        countMinWidth: video ? 34 : null,
        avatars: const [],
        count: KFormat.compact(count, l10n),
        label: l10n.liveViewers(count, KFormat.grouped(count)),
        onTap: open,
      );
    }
    final n = math.max(preview.items.length, room.viewerCount);
    final more = preview.next == null || n > preview.items.length ? '' : '+';
    return LiveViewersStack(
      key: LiveRoomScreen.viewersKey,
      // D131 (ref 158: 25.6 pt pictures 30.6 pt apart, a 25 pt count);
      // D141: about 12 % larger.
      avatarSize: video ? 28.5 : LiveViewersStack.size,
      pitch: video ? 33.5 : LiveViewersStack.size - 7,
      countHeight: video ? 28 : LiveViewersStack.size,
      countMinWidth: video ? 34 : null,
      avatars: [
        for (final v in preview.items)
          if (v.user case final u?)
            KAvatar(
              name: u.displayName,
              imageUrl: u.avatarUrl,
              size: video ? 28.5 : LiveViewersStack.size,
            ),
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

  Widget _roomChat(LiveRoomSessionState session, {Color? bubble}) =>
      LiveRoomChatLines(
        // D135: a bright theme darkens the rules line's fill a little.
        brightNotice: LiveRoomRulesNotice.isBrightTheme(_room.theme),
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
      // D174: a SOLO live's guests are on camera too.
      camera: _room.mode != LiveRoomMode.audio,
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
                // D148: the gold ticker opens the live of the win (like a
                // swipe to another live: this one is left).
                onOpenRoom: (id) =>
                    context.pushReplacement(AppRoutes.liveRoom(id)),
                // D145c: the strips centred at the reading start in audio
                // and video alike; beside a video live's wish column.
                stripsStart: LiveGiftEffectsLayer.videoStripsStart(
                  sideColumn:
                      room.mode != LiveRoomMode.audio &&
                      (room.wishGifts.isNotEmpty ||
                          LiveRoomPromoBox.shows(ref, room.id)),
                ),
              ),
            // D154i: the video the live watches together.
            if (room.status == LiveRoomStatus.live)
              LiveWatchLayer(
                roomId: room.id,
                host: false,
                // D160: a floating window in a video live.
                pip: room.mode != LiveRoomMode.audio,
              ),
            // D145: the lucky combo button after a lucky gift is sent.
            if (room.status == LiveRoomStatus.live)
              LuckyComboLayer(
                roomId: room.id,
                hostUsername: room.host.username,
                // Over the audio bar, or over the video live's quick
                // replies.
                bottom: room.mode == LiveRoomMode.audio
                    ? LuckyComboLayer.audioBottom
                    : LuckyComboLayer.videoBottom,
              ),
            // CP-021 (D112): the CP Entrance Effect.
            if (room.status == LiveRoomStatus.live)
              LiveCpEntranceLayer(roomId: room.id),
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
    final canFollow = profile?.canFollow ?? false;
    final following = profile?.isFollowing ?? false;
    final ended = room.status == LiveRoomStatus.ended;
    if (ended && canFollow && !following) _endedOfferedFollow = true;

    // CP-012: signed-in people tap to cheer (D95); D120 (owner): the host's
    // own taps count too.
    final me = ref.watch(currentUserProvider);
    final canTap = !ended && me != null;
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
    // D131 (owner): the host pill's second line takes turns between this
    // live's points (the cherry) and its taps (a heart), when known.
    final taps = session.scoreParts?.tapPoints ?? room.scoreParts?.tapPoints;
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
                  child: _video(session, engine),
                ),
                // D154h: the host's stickers (no touches here).
                LiveStickerLayer(roomId: room.id),
              ],
            ),
      stage: !ended && room.mode.hasSeats ? _stage(session, engine) : null,
      header: KHostPill(
        // D141 (owner): the host's @username beside the name (copy on tap).
        username: host.username,
        premiumTier: host.premiumTier,
        hostName: host.displayName,
        avatar: avatar,
        lines: ended
            ? const []
            : [
                Semantics(
                  label: l10n.liveHostPillPoints(KFormat.grouped(score)),
                  excludeSemantics: true,
                  child: KHostPillLine(
                    key: LiveRoomScreen.scoreKey,
                    icon: const KCherryIcon(size: 11),
                    text: KFormat.grouped(score),
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
        onFollow: canFollow
            ? () => unawaited(_setFollowing(follow: true))
            : null,
        onTap: profile == null ? null : () => _person(_username),
      ),
      // Presence does not exist yet: a count only when the API has one.
      viewers: ended ? null : _viewers(session, video: true),
      onClose: () => unawaited(_leave()),
      roomInfo: ended
          ? null
          : KRoomChipsRow(
              level: room.roomLevel,
              // D173: the cherry chip of the audio room (the live's points;
              // shown from the first point, as there).
              score: score > 0
                  ? LiveScoreChip(
                      key: LiveRoomScreen.scoreChipKey,
                      text: KFormat.compact(score, l10n),
                      label: l10n.liveScore(score, KFormat.grouped(score)),
                    )
                  : null,
            ),
      // D136: the host's wish list (a row opens the gift panel with that
      // gift and the host); D137: the promo box.
      sideStart: ended
          ? null
          : LiveWishCard(
              wishes: room.wishGifts,
              onWish: me == null
                  ? null
                  : (w) => unawaited(_openGifts(preselectGift: w.giftCode)),
            ),
      // D173 (owner: «يجب أن يظهر عند الجميع»): every viewer, signed in or
      // not (guests read the ROOM banners too, v1.39-live).
      sidePromo: ended ? null : LiveRoomPromoBox(roomId: room.id),
      // D145a: the lucky combo beside the chat, over the quick replies.
      // D174: a solo live's guests stacked at the end over the chat; D145a:
      // the lucky combo under them.
      chatEnd: ended ? null : _chatEnd(session, engine, room),
      chat: ended
          ? null
          : Align(
              alignment: AlignmentDirectional.bottomStart,
              child: LiveRoomChatLines(
                roomId: widget.room.id,
                role: _chatRole(session),
                bubble: KLiveColors.chatScrim,
                onProfile: _person,
                inline: true,
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
                // D131 (ref 158): quick replies over the bar, for someone
                // who may write.
                if (composer.canWrite && !_writing) ...[
                  KQuickReplies(
                    onSend: (text) => unawaited(
                      sendLiveChatText(
                        context,
                        ref,
                        roomId: widget.room.id,
                        text: text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                _chatComposer(composer) ??
                    KViewerBar(
                      pillKey: AudioRoomViewKeys.chat,
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
                        if (me != null && room.mode == LiveRoomMode.solo)
                          _soloGuestButton(session),
                        // D173: games (none yet: the sheet says so).
                        KViewerBarButton(
                          key: LiveRoomScreen.gamesKey,
                          asset: LiveGamesSheet.art,
                          art: true,
                          label: l10n.liveGames,
                          onTap: () => unawaited(showLiveGamesSheet(context)),
                        ),
                        KViewerBarButton(
                          key: LiveRoomScreen.giftKey,
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
    final room = _room;
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
    final cinema = LiveWatchScreen.shows(ref, room.id);
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
                wish: room.wishGifts.isEmpty
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
                  cover: KAvatar(
                    name: host.displayName,
                    imageUrl: host.avatarUrl,
                    size: 30,
                  ),
                  title: room.title,
                  level: room.roomLevel,
                  // D141 (owner): the host's @username (copy on tap), not
                  // the room number.
                  username: host.username,
                  premiumTier: host.premiumTier,
                  onTap: () => _person(_username),
                  action: canFollow
                      ? LiveRoundButton(
                          key: AudioRoomViewKeys.follow,
                          icon: Icons.person_add_alt_1_rounded,
                          label: l10n.liveFollow,
                          // Ref 147: the card's 26 pt action circle.
                          size: KAudioRoom.cardAction,
                          iconSize: 15,
                          color: const Color(0xFFFF4D7A),
                          onTap: () => unawaited(_setFollowing(follow: true)),
                        )
                      : null,
                  showMinimize: false,
                  minimizeTooltip: '',
                  onMinimize: null,
                  shareKey: AudioRoomViewKeys.share,
                  shareTooltip: l10n.goLiveShare,
                  onShare: () => unawaited(
                    _share(
                      room.title,
                      KHandle.plain(
                        host.username,
                        premiumTier: host.premiumTier,
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
                    ?_viewers(session),
                  ],
                ),
                stage: stage,
                chat: [_roomChat(session)],
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
                        showSeatRequests(
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
    final viewer = <GoLiveTool>[
      GoLiveTool(
        id: 'share',
        icon: Icons.share_rounded,
        label: l10n.goLiveShare,
        onTap: () => unawaited(
          _share(
            room.title,
            KHandle.plain(host.username, premiumTier: host.premiumTier),
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
      if (me != null && room.status == LiveRoomStatus.live)
        GoLiveTool(
          id: 'suggestVideo',
          icon: Icons.add_link_rounded,
          label: l10n.liveWatchSuggest,
          onTap: () =>
              unawaited(showLiveWatchSuggestSheet(context, roomId: room.id)),
        ),
      if (watch.watch?.video != null)
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
      if (me != null && me.id != host.id)
        GoLiveTool(
          id: 'report',
          icon: Icons.flag_outlined,
          label: l10n.liveToolReportHost,
          onTap: () => unawaited(reportUser(context, ref, userId: host.id)),
        ),
      // Not built for viewers yet: shown, greyed «قريباً».
      GoLiveTool.soon(
        id: 'minimize',
        icon: Icons.picture_in_picture_alt_rounded,
        label: l10n.goLiveMinimize,
      ),
      GoLiveTool.soon(
        id: 'giftSounds',
        icon: Icons.volume_off_rounded,
        label: l10n.liveToolGiftSounds,
      ),
      GoLiveTool.soon(
        id: 'giftEffects',
        icon: Icons.auto_awesome_rounded,
        label: l10n.liveToolGiftEffects,
      ),
      GoLiveTool.soon(
        id: 'clearScreen',
        icon: Icons.fullscreen_rounded,
        label: l10n.liveToolClearScreen,
      ),
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
    final guests = room.mode == LiveRoomMode.solo
        ? (session.seats?.seats ?? const <LiveSeat>[])
              .where((s) => s.state == LiveSeatState.taken)
              .toList()
        : const <LiveSeat>[];
    if (guests.isEmpty) return combo;
    final me = ref.read(currentUserProvider)?.id;
    final tiles = LiveGuestTiles(
      seats: guests,
      video: (u) => u.id == me ? engine.preview() : engine.remoteVideo(u.id),
      onTap: (u) => _person(u.username),
    );
    if (combo == null) return tiles;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [tiles, const SizedBox(height: 6), combo],
    );
  }

  /// D174: ∞ in a solo live — ask to join as a guest, the pending request
  /// (tap: cancel) or the seat (tap: leave). The 3 guest seats full: it
  /// says so instead of asking.
  Widget _soloGuestButton(LiveRoomSessionState session) {
    final l10n = context.l10n;
    final mine = session.mine;
    if (session.seated) {
      return KViewerBarButton(
        key: LiveRoomScreen.guestLeaveKey,
        icon: Icons.logout_rounded,
        label: l10n.liveSeatLeave,
        onTap: () => unawaited(runSeatAction(context, _session.leaveSeat)),
      );
    }
    if (mine?.request != null) {
      return KViewerBarButton(
        key: LiveRoomScreen.guestCancelKey,
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
    return KViewerBarButton(
      key: LiveRoomScreen.guestKey,
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

  /// SOLO: the host's video, "the host will be right back" while they are
  /// away, or the join failure. Seat rooms: the theme (seats are the stage).
  Widget _video(LiveRoomSessionState session, LiveMediaEngine engine) {
    final room = _room;
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
    final room = _room;
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
    // The room's stage scrolls; seats keep one size in every room (D123).
    return AudioSeatRing(
      count: count,
      // D173: the cinema rows under the YouTube screen (big rooms).
      // D173: no points pills on the cinema's seats.
      compact: LiveWatchScreen.shows(ref, room.id),
      seats: seats?.seats ?? const [],
      // D111: CP partners on adjacent seats are drawn joined.
      cpPairs: cpSeatPairs(seats, hostId: host.id),
      host: KAvatar(
        name: host.displayName,
        imageUrl: host.avatarUrl,
        size: AudioSeatRing.picture,
      ),
      hostName: host.displayName,
      hostPoints: KFormat.compact(score, context.l10n),
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
          ?seat.user,
      ],
      onSeatsStale: () {
        if (mounted) unawaited(_session.refreshSeats());
      },
      // D154: a moderator's free quips are the soundboard's.
      soundboard: (ref) =>
          ref.watch(liveRoomSessionProvider(widget.room.id)).canModerate,
    ),
  );
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
  /// 2026-10-26); null: the profile card they wear (`PublicProfile.
  /// profileCard`, CP-019), or the plain gold edge when none.
  final KabsoProfileHeader? header;

  static const inviteKey = Key('room.userCard.invite');

  /// The picture: opens the person's full profile (owner, 2026-10-26).
  static const profileKey = Key('room.userCard.profile');
  static const messageKey = Key('room.userCard.message');
  static const giftKey = Key('room.userCard.gift');

  /// D135: Mention (puts @username into the chat box) and Follow (for
  /// someone this viewer does not follow; Message once they do).
  static const mentionKey = Key('room.userCard.mention');
  static const boostKey = Key('room.userCard.boost');
  static const followKey = Key('room.userCard.follow');
  static const copyKey = Key('room.userCard.copy');
  static const medalsKey = Key('room.userCard.medals');
  static const cpFrameKey = Key('room.userCard.cpFrame');

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
    // CP-021 (D112): the couple's Special Frame around the picture.
    final framed = cpWearsSpecialFrame(profile?.cp);
    final frameWidth = CpSpecialFrameAvatar.widthForAvatar(_Card.avatar);
    final frameTop = CpSpecialFrameAvatar.pictureCentreY(frameWidth);
    final frameBelow = CpSpecialFrameAvatar.heightFor(frameWidth) - frameTop;
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
        child: ConstrainedBox(
          // D135: at least a 48 pt target; Expanded cells share the row.
          constraints: const BoxConstraints(minHeight: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // One 36 dp box for every icon: the gift art has a clear margin,
              // so its drawing comes out about 28 dp, like the Message
              // bubble (owner: same size, on one line).
              SizedBox.square(
                dimension: 36,
                child: glyph ?? Image.asset(asset!, width: 36, height: 36),
              ),
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
              // Room for the picture (or the frame's lower half).
              SizedBox(height: (framed ? frameBelow : _Card.avatar / 2) + 2),
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
                      ClipboardData(
                        text: KHandle.plain(
                          profile.username,
                          premiumTier: profile.premiumTier,
                        ),
                      ),
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
                      // D146: a premium username wears its special-ID badge.
                      if (profile.premiumTier case final tier?)
                        KSpecialUsername(
                          username: profile.username,
                          tier: tier,
                          height: 20,
                        )
                      else
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
                  padding: const EdgeInsets.only(top: 6),
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
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: text.body.copyWith(color: _Card.ink),
                  ),
                ),
              const SizedBox(height: 8),
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
                padding: const EdgeInsets.only(top: 10),
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
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFEDEEF2)),
              const SizedBox(height: 8),
              // D135 (owner): the bottom row — Gift, Mention, then Message
              // for someone I follow or Follow (which turns into Message)
              // for someone I do not; nothing for my own card. The host's
              // Invite to a seat stays after them.
              if (!profile.isSelf)
                Row(
                  children: [
                    // CP-020: the gift panel with this person chosen; the
                    // panel says when they cannot receive here (not on the
                    // mic).
                    if (scope?.onGift case final onGift?)
                      Expanded(
                        child: action(
                          key: giftKey,
                          asset: 'assets/live_bar/gift.png',
                          label: l10n.liveGifts,
                          onTap: () => close(
                            () => onGift((
                              username: profile.username,
                              name: profile.displayName,
                            )),
                          ),
                        ),
                      ),
                    // D154b: a traffic card for the host's live.
                    if (scope?.onBoost case final onBoost?)
                      Expanded(
                        child: action(
                          key: boostKey,
                          glyph: const _RoundGlyph(
                            colors: [Color(0xFFFFD36E), Color(0xFFF2A93B)],
                            child: Icon(
                              Icons.confirmation_number_rounded,
                              size: 18,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                          label: l10n.liveBoostGiftAction,
                          onTap: () => close(onBoost),
                        ),
                      ),
                    if (scope?.onMention case final onMention?)
                      Expanded(
                        child: action(
                          key: mentionKey,
                          glyph: const _RoundGlyph(
                            colors: [Color(0xFFFFB25B), Color(0xFFFF6A3D)],
                            child: Text(
                              '@',
                              style: TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontSize: 19,
                                height: 1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          label: l10n.liveUserMention,
                          onTap: () => close(() => onMention(profile.username)),
                        ),
                      ),
                    if (profile.isFollowing || !profile.canFollow)
                      Expanded(
                        child: action(
                          key: messageKey,
                          glyph: const _MessageGlyph(),
                          label: l10n.profileMessage,
                          onTap: () => close(
                            () => unawaited(
                              context.push(
                                AppRoutes.chat(profile.username),
                                extra: (
                                  displayName: profile.displayName,
                                  premiumTier: profile.premiumTier,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: action(
                          key: followKey,
                          glyph: const _RoundGlyph(
                            colors: [Color(0xFFFF5A7A), Color(0xFFE5245A)],
                            child: Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 20,
                              color: Color(0xFFFFFFFF),
                            ),
                          ),
                          label: l10n.liveFollow,
                          // Follows; the card then shows Message.
                          onTap: () => unawaited(
                            setHostFollowing(
                              context,
                              ref,
                              username,
                              follow: true,
                            ),
                          ),
                        ),
                      ),
                    if (onInvite != null)
                      Expanded(
                        child: action(
                          key: inviteKey,
                          asset: 'assets/live_bar/seat.png',
                          label: l10n.liveSeatInviteSend,
                          onTap: () => close(onInvite),
                        ),
                      ),
                  ],
                ),
            ],
          );

    // CP-019: an explicit header wins; otherwise the profile card the person
    // wears, once the profile is loaded (nothing is reserved before). A code
    // this app does not know shows the plain edge.
    final header =
        this.header ?? KabsoProfileHeader.byCode(profile?.profileCard?.code);
    return LayoutBuilder(
      builder: (context, box) {
        // The card's top edge: under the middle of the picture, or lower when
        // the header decoration rises higher than the picture.
        // The frame's upper half rises above the picture.
        final half = framed ? frameTop : _Card.avatar / 2;
        final edge = header == null
            ? half
            : math.max(half, header.overhang(box.maxWidth));
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                  middle: framed ? frameWidth : _Card.avatar + 16,
                ),
              ),
            // The picture in a gold ring, the charm level on a plate under it.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: edge - half),
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
                    child: framed
                        ? CpSpecialFrameAvatar(
                            key: cpFrameKey,
                            width: frameWidth,
                            name: profile?.displayName ?? username,
                            image: _networkImage(profile?.avatarUrl),
                          )
                        : Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: _Card.gold,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x55F2B84B),
                                  blurRadius: 14,
                                ),
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

/// D135: a round glossy 32 pt button art (Mention, Follow) sized like the
/// gift and Message art beside it.
class _RoundGlyph extends StatelessWidget {
  const new({required this.colors, required this.child});

  final List<Color> colors;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 36,
    child: Center(
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

/// The card's Message button art (owner, 2026-10-26: the flat bubble looked
/// poor): a glossy bubble in a blue-to-violet gradient with a soft shine and
/// three white dots, sized like the gift icon beside it.
class _MessageGlyph extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 36,
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
          child: const Icon(Icons.mode_comment_rounded, size: 33),
        ),
        // A soft shine on the upper part.
        Positioned(
          top: 7,
          left: 9,
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

  /// D173: games (the joystick).
  static const games = Key('audioRoom.games');

  /// D173: ≡, the room menu (viewer and moderator items).
  static const menu = Key('audioRoom.menu');
  static const mic = Key('audioRoom.mic');

  /// D138: an emoji on my own seat (seated only).
  static const seatEmoji = Key('audioRoom.seatEmoji');
}
