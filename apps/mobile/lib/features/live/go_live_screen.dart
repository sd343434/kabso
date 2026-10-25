import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart'
    show showHostSheet;
import 'package:kabso_live/features/live/presentation/go_live/go_live_audio_setup.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_glass.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_info_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_style.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_tools.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_score_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_theme_art.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/live/new` — go live (CP-010, CP-011), designed after the owner's two
/// references (D94) in Kabso's own look: Multi-guest · LIVE · Audio LIVE.
///
/// - **LIVE:** the camera fills the screen.
/// - **Multi-guest:** the room theme behind a grid of 4, 6, 9 or 12 tiles,
///   the host's camera in the first.
/// - **Audio:** the room theme behind the host's crowned circle and rows of
///   seats (6, 9, 15, 20 or 25 with the host, D100).
///
/// Above: the glass title card (picture, title, guests, `#` categories,
/// Kabi). Below: the seat count, the tools (flip, beauty, microphone,
/// theme), the glowing Go LIVE button and the modes. Only working tools
/// are shown; audio has no filters (owner).
///
/// Gates, in order: `GET /live/config` `hostingEnabled`, then the account's
/// hosting permission (`Me.canHost`); the camera and microphone start only
/// when both pass. Then capture problems, starting, on air (elapsed time,
/// seats, guests switch, end with confirmation) and ended.
class GoLiveScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const closeKey = Key('goLive.close');
  static const Key titleKey = GoLiveKeys.title;
  static const countdownKey = Key('goLive.countdown');
  static const Key startKey = GoLiveKeys.start;
  static final Key flipKey = GoLiveKeys.tool('flip');
  static final Key micKey = GoLiveKeys.tool('mic');
  static final Key beautyKey = GoLiveKeys.tool('beauty');
  static final Key themeKey = GoLiveKeys.tool('theme');
  static final Key liveGuestsKey = GoLiveKeys.tool('guests');
  static const Key guestsChipKey = GoLiveKeys.guestsChip;
  static const minimizeKey = Key('goLive.minimize');
  static const viewersKey = Key('goLive.viewers');
  static const shareKey = Key('goLive.share');
  static const videoChatKey = Key('goLive.videoChat');
  static const audioChatKey = Key('goLive.audio.chat');
  static const audioMoreKey = Key('goLive.audio.more');
  static const audioPkKey = Key('goLive.audio.pk');
  static const endConfirmKey = Key('goLive.endConfirm');
  static const doneKey = Key('goLive.done');
  static const retryKey = Key('goLive.retry');
  static const elapsedKey = Key('goLive.elapsed');
  static const notAllowedKey = Key('goLive.notAllowed');
  static const unavailableKey = Key('goLive.unavailable');
  static const captureFailedKey = Key('goLive.captureFailed');
  static const endedKey = Key('goLive.ended');
  static Key categoryKey(String? slug) => GoLiveKeys.category(slug);

  /// The title limit (CONVENTIONS §10.3: 1–80 grapheme clusters).
  static const int titleMaxLength = GoLiveTitleCard.titleMaxLength;

  @override
  ConsumerState<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends ConsumerState<GoLiveScreen> {
  final _title = TextEditingController();
  final _titleFocus = FocusNode();
  final _chat = TextEditingController();
  final _chatFocus = FocusNode();
  bool _writing = false;
  String? _chatRoom;
  String? _category;
  bool _previewRequested = false;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    _title.dispose();
    _titleFocus.dispose();
    _chat.dispose();
    _chatFocus.dispose();
    super.dispose();
  }

  LiveHostController get _host => ref.read(liveHostControllerProvider.notifier);

  void _close() {
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.home);
    }
  }

  void _requestPreview() {
    if (_previewRequested) return;
    _previewRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Back from the floating window: the live goes on, full screen.
      ref.read(liveMinimizedProvider.notifier).restore();
      if (ref.read(liveHostControllerProvider).phase == GoLivePhase.preparing) {
        unawaited(_host.startPreview());
      }
    });
  }

  /// Minimizes the live into the floating window (owner D94); it goes on.
  void _minimize() {
    ref.read(liveMinimizedProvider.notifier).minimize();
    _close();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
    }
  }

  Future<void> _start() async {
    final l10n = context.l10n;
    final title = _title.text.trim();
    if (title.isEmpty) {
      _titleFocus.requestFocus();
      KSnack.info(context, l10n.goLiveTitleRequired);
      return;
    }
    _titleFocus.unfocus();
    // Audio: 3, 2, 1 before the room opens (the owner's recording).
    if (ref.read(liveHostControllerProvider).mode == LiveRoomMode.audio) {
      for (var n = 3; n >= 1; n--) {
        if (!mounted) return;
        setState(() => _countdown = n);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (!mounted) return;
      setState(() => _countdown = null);
    }
    await _guard(() => _host.goLive(title: title, categorySlug: _category));
  }

  /// 3, 2, 1 while an audio live is about to start; null otherwise.
  int? _countdown;

  Future<void> _confirmEnd() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.goLiveEndConfirmTitle),
        content: Text(l10n.goLiveEndConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.goLiveKeepGoing),
          ),
          TextButton(
            key: GoLiveScreen.endConfirmKey,
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.goLiveEndConfirm),
          ),
        ],
      ),
    );
    if (ok ?? false) await _host.end();
  }

  /// Share: copies the live's invite (there is no public link to a live
  /// yet, nor a system share sheet in the app).
  Future<void> _shareLive(String title, String username) async {
    final l10n = context.l10n;
    await Clipboard.setData(
      ClipboardData(text: l10n.goLiveShareText(title, username)),
    );
    if (mounted) KSnack.success(context, l10n.goLiveShareCopied);
  }

  /// The audio room's ≡: the tools that are not on the bar.
  Future<void> _toggleGuests(GoLiveState state) async {
    final l10n = context.l10n;
    final allow = !state.allowGuests;
    await _guard(() async {
      await _host.setAllowGuests(allow: allow);
      if (mounted && state.phase == GoLivePhase.live) {
        KSnack.info(
          context,
          allow ? l10n.goLiveGuestsOn : l10n.goLiveGuestsOff,
        );
      }
    });
  }

  /// CP-013: the host turns the room chat off or on.
  Future<void> _toggleChat(String roomId, {required bool enabled}) async {
    final l10n = context.l10n;
    await _guard(() async {
      await ref
          .read(liveChatProvider(roomId).notifier)
          .setEnabled(enabled: !enabled);
      if (mounted) {
        KSnack.info(
          context,
          enabled ? l10n.liveChatTurnedOff : l10n.liveChatTurnedOn,
        );
      }
    });
  }

  /// CP-013: starts the room chat once the room is on air.
  void _attachChat(LiveRoom? room, LiveMediaEngine engine, bool onAir) {
    if (room == null || !onAir || _chatRoom == room.id) return;
    _chatRoom = room.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(liveChatProvider(room.id).notifier)
            .attach(engine, enabled: room.chatEnabled, muted: false),
      );
    });
  }

  void _syncTicker(GoLiveState state) {
    final live = state.phase == GoLivePhase.live;
    if (live && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!live && _tick != null) {
      _tick!.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final config = ref.watch(liveConfigProvider);
    final user = ref.watch(currentUserProvider);
    final canHost = user?.canHost ?? false;
    final state = ref.watch(liveHostControllerProvider);
    _syncTicker(state);

    Widget? gate;
    switch (config) {
      case AsyncData(:final value) when !value.hostingEnabled:
        gate = _Notice(
          key: GoLiveScreen.unavailableKey,
          icon: Icons.sensors_off_outlined,
          title: l10n.goLiveUnavailableTitle,
          body: l10n.errorLiveHostingUnavailable,
        );
      case AsyncData() when !canHost:
        gate = _Notice(
          key: GoLiveScreen.notAllowedKey,
          icon: Icons.verified_user_outlined,
          title: l10n.goLiveNotAllowedTitle,
          body: l10n.goLiveNotAllowedBody,
        );
      case AsyncData():
        _requestPreview();
      case AsyncError(:final error):
        gate = _Notice(
          icon: Icons.error_outline_rounded,
          title: l10n.liveRoomErrorTitle,
          body: failureMessage(l10n, toAppFailure(error)),
          onRetry: () => ref.invalidate(liveConfigProvider),
        );
      default:
        gate = const _Spinner();
    }

    final cfg = config.value;
    final art = LiveThemeArt.of(
      state.mode.hasSeats ? state.theme : LiveThemes.classic,
    );
    final onAir =
        state.phase == GoLivePhase.live || state.phase == GoLivePhase.ending;
    final ended = state.phase == GoLivePhase.ended;
    final busy =
        state.phase == GoLivePhase.starting ||
        state.phase == GoLivePhase.ending;
    final previewing = gate == null && state.phase == GoLivePhase.preview;
    final setup = gate == null && !onAir && !ended;
    final captureFailed = state.phase == GoLivePhase.captureFailed;
    final audioSetup =
        setup && !captureFailed && state.mode == LiveRoomMode.audio;
    final seats = state.mode.hasSeats;
    final room = state.room;
    final liveSeats = onAir && seats && room != null
        ? ref.watch(liveSeatsProvider(room.id)).value
        : null;
    final seatCount =
        liveSeats?.seatCount ?? room?.seatCount ?? state.seatCount;
    final engine = _host.engine;
    _watchSeatsVersion(room);
    _attachChat(room, engine, onAir);
    final chat = onAir && room != null
        ? ref.watch(liveChatProvider(room.id))
        : null;
    void openChat() {
      setState(() => _writing = true);
      _chatFocus.requestFocus();
    }

    void send() {
      if (room == null) return;
      unawaited(sendLiveChatFrom(context, ref, roomId: room.id, field: _chat));
    }

    final roomChat = room == null || chat == null
        ? null
        : LiveRoomChatLines(
            roomId: room.id,
            role: LiveChatViewerRole.host,
            onProfile: (username) =>
                unawaited(showHostSheet(context, username)),
          );
    final chatComposer = _writing
        ? TapRegion(
            onTapOutside: (_) => setState(() {
              _writing = false;
              _chatFocus.unfocus();
            }),
            child: LiveChatComposer(
              controller: _chat,
              focusNode: _chatFocus,
              hint: l10n.goLiveChatHint,
              sendLabel: l10n.goLiveChatSend,
              onSend: send,
              onEmoji: (emoji) {
                if (room == null) return;
                unawaited(
                  sendLiveChatText(
                    context,
                    ref,
                    roomId: room.id,
                    text: emoji.token,
                  ),
                );
              },
            ),
          )
        : null;
    // Seat index → user id, for who is speaking (the host is 0).
    final speaking = <int>{
      if (user != null && engine.speaking.contains(user.id)) 0,
      for (final seat in liveSeats?.seats ?? const <LiveSeat>[])
        if (seat.user != null && engine.speaking.contains(seat.user!.id))
          seat.index,
    };
    ValueChanged<int>? onSeat;
    if (liveSeats != null && room != null) {
      onSeat = (index) => unawaited(_seatActions(room.id, liveSeats, index));
    }

    final audioOnAir =
        gate == null && onAir && state.mode == LiveRoomMode.audio;
    final Widget background;
    if (gate != null || ended) {
      background = ColoredBox(color: KPalette.dark.background);
    } else if (!seats) {
      background = _camera(state);
    } else {
      background = audioOnAir && state.theme == LiveThemes.classic
          ? const LiveAudioRoomBackground()
          : LiveThemeBackground(
              theme: state.theme,
              waves: state.mode == LiveRoomMode.audio,
            );
    }

    final hostName = user?.displayName ?? '';
    final hostPicture = KAvatar(
      name: hostName,
      imageUrl: user?.avatarUrl,
      size: 96,
    );

    Widget? middle;
    if (gate != null) {
      middle = gate;
    } else if (ended) {
      middle = _Ended(state: state, onDone: _close);
    } else if (captureFailed) {
      middle = _captureNotice(state);
    } else if (state.mode == LiveRoomMode.multi) {
      middle = Align(
        alignment: Alignment.topCenter,
        child: VideoSeatGrid(
          count: seatCount!,
          accent: art.accent,
          seats: liveSeats?.seats ?? const [],
          host: _camera(state, fallback: Center(child: hostPicture)),
          guestVideo: (seat) => engine.remoteVideo(seat.user!.id),
          onSeat: onSeat,
        ),
      );
    }

    final canAct = previewing || state.phase == GoLivePhase.live;
    final video = state.mode != LiveRoomMode.audio;
    final tools = <GoLiveTool>[
      if (video) ...[
        GoLiveTool(
          id: 'flip',
          icon: Icons.flip_camera_ios_rounded,
          label: l10n.goLiveFlip,
          onTap: canAct && engine.videoEnabled
              ? () => unawaited(_host.flipCamera())
              : null,
        ),
        GoLiveTool(
          id: 'beauty',
          icon: Icons.face_retouching_natural_rounded,
          label: l10n.goLiveBeauty,
          badge: state.beauty.enabled,
          onTap: canAct
              ? () => unawaited(
                  showLiveBeautySheet(
                    context,
                    beauty: state.beauty,
                    supported: engine.beautySupported,
                    accent: art.accent,
                    onChanged: (b) => unawaited(_host.setBeauty(b)),
                  ),
                )
              : null,
        ),
      ],
      GoLiveTool(
        id: 'mic',
        icon: state.micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
        label: state.micEnabled ? l10n.goLiveMic : l10n.goLiveMicOff,
        toggled: state.micEnabled,
        onTap: canAct ? () => unawaited(_host.toggleMic()) : null,
      ),
      if (seats)
        GoLiveTool(
          id: 'theme',
          icon: Icons.palette_rounded,
          label: l10n.goLiveTheme,
          onTap: canAct
              ? () => unawaited(
                  showLiveThemeSheet(
                    context,
                    themes: cfg?.themes ?? const [LiveThemes.classic],
                    selected: state.theme,
                    onSelect: (t) => unawaited(_guard(() => _host.setTheme(t))),
                  ),
                )
              : null,
        ),
      if (onAir && seats && room != null) ...[
        GoLiveTool(
          id: 'requests',
          icon: Icons.front_hand_rounded,
          label: l10n.liveSeatRequests,
          badge: (liveSeats?.pendingRequests ?? 0) > 0,
          onTap: state.phase == GoLivePhase.live
              ? () => unawaited(_openRequests(room.id))
              : null,
        ),
        GoLiveTool(
          id: 'seats',
          icon: Icons.weekend_rounded,
          label: l10n.liveSeats,
          onTap: state.phase == GoLivePhase.live
              ? () => unawaited(
                  showSeatCountSheet(
                    context,
                    counts: state.mode == LiveRoomMode.audio
                        ? (cfg?.seatCounts.audio ?? const [6, 9, 15, 20, 25])
                        : (cfg?.seatCounts.multi ?? const [4, 6, 9, 12]),
                    selected: seatCount!,
                    accent: art.accent,
                    onSelect: (c) async {
                      await _host.setSeatCount(c);
                      ref.invalidate(liveSeatsProvider(room.id));
                    },
                  ),
                )
              : null,
        ),
      ],
      if (onAir)
        GoLiveTool(
          id: 'guests',
          icon: state.allowGuests
              ? Icons.groups_rounded
              : Icons.no_accounts_rounded,
          label: l10n.goLiveGuests,
          toggled: state.allowGuests,
          onTap: state.phase == GoLivePhase.live
              ? () => unawaited(_toggleGuests(state))
              : null,
        ),
      // In the audio room's tools sheet only: the video tools bar shows
      // five tools and the chat switch must stay among them.
      if (onAir && state.mode == LiveRoomMode.audio)
        GoLiveTool(
          id: 'voice',
          icon: Icons.tune_rounded,
          label: l10n.liveToolsVoice,
          onTap: state.phase == GoLivePhase.live
              ? () => unawaited(
                  showLiveVoiceSheet(
                    context,
                    noiseReduction: state.noiseReduction,
                    enhance: state.voiceEnhance,
                    onChanged: _host.setVoice,
                  ),
                )
              : null,
        ),
      if (onAir && seats && room != null)
        GoLiveTool(
          id: 'viewers',
          icon: Icons.people_alt_outlined,
          label: l10n.liveToolsViewers,
          onTap: state.phase == GoLivePhase.live
              ? () => unawaited(_openViewers(room.id, liveSeats))
              : null,
        ),
      if (onAir && room != null)
        GoLiveTool(
          id: 'chat',
          icon: chat?.enabled ?? true
              ? Icons.chat_rounded
              : Icons.speaker_notes_off_rounded,
          // Short in the tools bar; on/off shows on the button.
          label: l10n.liveChatTool,
          toggled: chat?.enabled ?? true,
          onTap: state.phase == GoLivePhase.live
              ? () => unawaited(
                  _toggleChat(room.id, enabled: chat?.enabled ?? true),
                )
              : null,
        ),
    ];

    const pad = KSpacing.lg;
    final Widget body;
    if (audioSetup) {
      body = GoLiveAudioSetup(
        controller: _title,
        focusNode: _titleFocus,
        enabled: previewing,
        theme: state.theme,
        onTheme: previewing
            ? () => unawaited(
                showLiveThemeSheet(
                  context,
                  themes: cfg?.themes ?? const [LiveThemes.classic],
                  selected: state.theme,
                  onSelect: (t) => unawaited(_guard(() => _host.setTheme(t))),
                ),
              )
            : null,
        categories: ref.watch(liveCategoriesProvider).value ?? const [],
        category: _category,
        onCategory: (slug) => setState(() => _category = slug),
        allowGuests: state.allowGuests,
        onAllowGuests: previewing
            ? (allow) => unawaited(_host.setAllowGuests(allow: allow))
            : null,
        micEnabled: state.micEnabled,
        onMic: previewing ? () => unawaited(_host.toggleMic()) : null,
        noiseReduction: state.noiseReduction,
        enhance: state.voiceEnhance,
        onVoice: previewing
            ? ({noiseReduction, enhance}) => unawaited(
                _host.setVoice(
                  noiseReduction: noiseReduction,
                  enhance: enhance,
                ),
              )
            : null,
        seatCounts: cfg?.seatCounts.audio ?? const [6, 9, 15, 20, 25],
        seatCount: state.seatCount!,
        onSeatCount: previewing
            ? (c) => unawaited(_guard(() => _host.setSeatCount(c)))
            : null,
        busy: busy,
        onStart: previewing && _countdown == null
            ? () => unawaited(_start())
            : null,
        onClose: busy || _countdown != null ? null : _close,
        onMode: busy || _countdown != null
            ? null
            : (mode) => unawaited(_host.setMode(mode)),
        hostName: hostName,
        hostAvatarUrl: user?.avatarUrl,
        onShare: user == null
            ? null
            : () => unawaited(_shareLive(_title.text.trim(), user.username)),
      );
    } else if (audioOnAir) {
      // CP-012: the score from the media room's metadata, else the room's.
      final score = engine.score ?? room?.score ?? 0;
      final viewers = room == null
          ? null
          : ref.watch(liveViewersPreviewProvider(room.id)).value;
      final live = state.phase == GoLivePhase.live;
      final byId = {for (final t in tools) t.id: t};
      // Owner ref 73: the room bar (and ref 84's Topic) opens the room's info.
      final openRoomInfo = room == null || !live
          ? null
          : () => unawaited(
              showLiveRoomInfo(
                context,
                hostName: hostName,
                hostAvatarUrl: user?.avatarUrl,
                onSettings: () => unawaited(
                  showLiveSetupSettings(
                    context,
                    allowGuests: state.allowGuests,
                    onAllowGuests: (_) => unawaited(_toggleGuests(state)),
                    onShare: user == null
                        ? null
                        : () =>
                              unawaited(_shareLive(room.title, user.username)),
                  ),
                ),
              ),
            );
      // The chat box opens from 💬 and 🙂 (CP-013).
      body = LiveAudioRoomLayout(
        header: LiveAudioRoomHeader(
          // CP-015: the live's cover, else the host's picture.
          cover: switch (room?.coverUrl ?? user?.liveCoverUrl) {
            final url? => Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  KAvatar(name: hostName, imageUrl: user?.avatarUrl, size: 26),
            ),
            null => KAvatar(
              name: hostName,
              imageUrl: user?.avatarUrl,
              size: 26,
            ),
          },
          title: room?.title ?? _title.text.trim(),
          // CP-016 G (ref 83): the room number, else the username.
          subtitle: switch (room?.roomNumber) {
            final n? => l10n.liveRoomNumber('$n'),
            null => user == null ? null : '@${user.username}',
          },
          minimizeKey: GoLiveScreen.minimizeKey,
          minimizeTooltip: l10n.goLiveMinimize,
          onMinimize: live ? _minimize : null,
          // Owner ref 73: the room bar opens the room's info.
          onTap: openRoomInfo,
          shareKey: GoLiveScreen.shareKey,
          shareTooltip: l10n.goLiveShare,
          onShare: user == null || room == null
              ? null
              : () => unawaited(_shareLive(room.title, user.username)),
          endKey: GoLiveScreen.closeKey,
          endTooltip: l10n.goLiveEndConfirm,
          onEnd: live ? () => unawaited(_confirmEnd()) : null,
        ),
        // Ref 83/84: the room rank, then the live's points.
        chips: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Flexible(child: LiveRankChip()),
                  if (score > 0) ...[
                    const SizedBox(width: 8),
                    LiveScoreChip(
                      text: KFormat.compact(score, l10n),
                      label: l10n.liveScore(score, KFormat.grouped(score)),
                      onTap: room == null
                          ? null
                          : () =>
                                unawaited(showLiveScoreSheet(context, room.id)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (viewers != null && room != null)
              LiveViewersStack(
                key: GoLiveScreen.viewersKey,
                avatars: [
                  for (final v in viewers.items)
                    if (v.user case final u?)
                      KAvatar(
                        name: u.displayName,
                        imageUrl: u.avatarUrl,
                        size: LiveViewersStack.size,
                      ),
                ],
                count: viewers.next == null
                    ? KFormat.compact(viewers.items.length, l10n)
                    : '${KFormat.compact(viewers.items.length, l10n)}+',
                label: l10n.liveViewers(
                  viewers.items.length,
                  KFormat.compact(viewers.items.length, l10n),
                ),
                onTap: () => unawaited(_openViewers(room.id, liveSeats)),
              ),
          ],
        ),
        stage: AudioSeatRing(
          count: seatCount!,
          seats: liveSeats?.seats ?? const [],
          host: KAvatar(
            name: hostName,
            imageUrl: user?.avatarUrl,
            size: AudioSeatRing.hostSize,
          ),
          hostName: hostName,
          hostMicOn: state.micEnabled,
          hostPoints: KFormat.compact(score, l10n),
          speaking: speaking,
          onSeat: onSeat,
        ),
        chat: [?roomChat],
        composer: chatComposer,
        // Ref 83: chat, emoji and the tools menu on one side; seats, PK and
        // the mic on the other.
        barStart: [
          LiveRoundButton(
            key: GoLiveScreen.audioChatKey,
            icon: Icons.chat_bubble_outline_rounded,
            label: l10n.goLiveChatPill,
            onTap: openChat,
          ),
          LiveRoundButton(
            icon: Icons.emoji_emotions_rounded,
            asset: 'assets/live_room_icons/emoji.png',
            tintAsset: true,
            label: l10n.livePreviewEmoji,
            onTap: openChat,
          ),
          LiveRoundButton(
            key: GoLiveScreen.audioMoreKey,
            icon: Icons.menu_rounded,
            label: l10n.livePreviewMore,
            onTap: () => unawaited(
              showLiveRoomTools(
                context,
                // Ref 84's tools in its order: ours where they exist (the
                // voice in the mixer's place, viewers as users, chat as
                // comments), the rest greyed with "Soon" (owner D99).
                room: [
                  ?byId['voice'],
                  GoLiveTool.soon(
                    id: 'music',
                    icon: Icons.music_note_rounded,
                    label: l10n.liveToolMusic,
                  ),
                  GoLiveTool.soon(
                    id: 'sounds',
                    icon: Icons.graphic_eq_rounded,
                    label: l10n.liveToolSounds,
                  ),
                  GoLiveTool.soon(
                    id: 'fluent',
                    icon: Icons.speed_rounded,
                    label: l10n.liveToolFluent,
                  ),
                  GoLiveTool.soon(
                    id: 'program',
                    icon: Icons.movie_creation_outlined,
                    label: l10n.liveToolProgramList,
                  ),
                  GoLiveTool.soon(
                    id: 'screen',
                    icon: Icons.screen_share_outlined,
                    label: l10n.liveToolShareScreen,
                  ),
                  GoLiveTool.soon(
                    id: 'youtube',
                    icon: Icons.smart_display_outlined,
                    label: l10n.liveToolYoutube,
                  ),
                  GoLiveTool.soon(
                    id: 'singing',
                    icon: Icons.mic_external_on_outlined,
                    label: l10n.liveToolSinging,
                  ),
                  GoLiveTool(
                    id: 'topic',
                    icon: Icons.forum_outlined,
                    label: l10n.liveToolTopic,
                    onTap: openRoomInfo,
                  ),
                  byId['seats']!,
                  byId['theme']!,
                ],
                other: [
                  ?byId['viewers'],
                  ?byId['chat'],
                  GoLiveTool.soon(
                    id: 'management',
                    icon: Icons.manage_accounts_outlined,
                    label: l10n.liveToolManagement,
                  ),
                  GoLiveTool.soon(
                    id: 'assistance',
                    icon: Icons.support_agent_rounded,
                    label: l10n.liveToolAssistance,
                  ),
                  GoLiveTool.soon(
                    id: 'recorder',
                    icon: Icons.videocam_outlined,
                    label: l10n.liveToolRecorder,
                  ),
                  GoLiveTool.soon(
                    id: 'newcomers',
                    icon: Icons.fiber_new_outlined,
                    label: l10n.liveToolNewcomers,
                  ),
                  GoLiveTool.soon(
                    id: 'data',
                    icon: Icons.insights_outlined,
                    label: l10n.liveToolDataCenter,
                  ),
                  GoLiveTool.soon(
                    id: 'time',
                    icon: Icons.alarm_rounded,
                    label: l10n.liveToolLiveTime,
                  ),
                  byId['guests']!,
                ],
              ),
            ),
          ),
        ],
        barEnd: [
          LiveRoundButton(
            key: GoLiveKeys.tool('requests'),
            icon: Icons.weekend_rounded,
            asset: 'assets/live_room_icons/seat.png',
            tintAsset: true,
            label: byId['requests']!.label,
            onTap: byId['requests']!.onTap,
            badge: liveSeats?.pendingRequests ?? 0,
          ),
          // PK is not in the contract yet: the button says so.
          LiveRoundButton(
            key: GoLiveScreen.audioPkKey,
            icon: Icons.sports_mma_rounded,
            asset: 'assets/live_room_icons/versus.png',
            tintAsset: true,
            label: l10n.goLivePk,
            onTap: () => KSnack.info(context, l10n.goLivePkSoon),
          ),
          LiveRoundButton(
            key: GoLiveScreen.micKey,
            icon: byId['mic']!.icon,
            asset: state.micEnabled
                ? 'assets/live_room_icons/mic.png'
                : 'assets/live_room_icons/mic_off.png',
            tintAsset: true,
            label: state.micEnabled ? l10n.goLiveMuteMic : l10n.goLiveUnmuteMic,
            onTap: byId['mic']!.onTap,
          ),
        ],
      );
    } else {
      body = SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.sm,
                KSpacing.xs,
                KSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  if (onAir)
                    Expanded(
                      child: _LiveClock(
                        since: state.liveSince,
                        title: room?.title ?? _title.text.trim(),
                      ),
                    )
                  else
                    const Spacer(),
                  if (onAir)
                    IconButton(
                      key: GoLiveScreen.minimizeKey,
                      tooltip: l10n.goLiveMinimize,
                      onPressed: state.phase == GoLivePhase.live
                          ? _minimize
                          : null,
                      icon: const Icon(
                        Icons.picture_in_picture_alt_rounded,
                        color: Color(0xFFFFFFFF),
                        size: 26,
                        shadows: [
                          Shadow(color: KLiveColors.chatScrim, blurRadius: 6),
                        ],
                      ),
                    ),
                  if (!ended)
                    IconButton(
                      key: GoLiveScreen.closeKey,
                      tooltip: onAir ? l10n.goLiveEndConfirm : l10n.liveClose,
                      onPressed: onAir
                          ? (state.phase == GoLivePhase.live
                                ? () => unawaited(_confirmEnd())
                                : null)
                          : (busy ? null : _close),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFFFFFFF),
                        size: 30,
                        shadows: [
                          Shadow(color: KLiveColors.chatScrim, blurRadius: 6),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (setup && !captureFailed)
              Padding(
                padding: const EdgeInsets.fromLTRB(pad, KSpacing.xs, pad, 0),
                child: GoLiveTitleCard(
                  hostName: hostName,
                  hostAvatarUrl: user?.avatarUrl,
                  controller: _title,
                  focusNode: _titleFocus,
                  enabled: previewing,
                  allowGuests: state.allowGuests,
                  onGuests: previewing
                      ? () => unawaited(_toggleGuests(state))
                      : null,
                  categories:
                      ref.watch(liveCategoriesProvider).value ?? const [],
                  category: _category,
                  onCategory: (slug) => setState(() => _category = slug),
                  accent: art.accent,
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  pad,
                  KSpacing.xl,
                  pad,
                  KSpacing.md,
                ),
                child: onAir && roomChat != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ?middle,
                          Align(
                            alignment: AlignmentDirectional.bottomStart,
                            child: LiveRoomChatLines(
                              roomId: room!.id,
                              role: LiveChatViewerRole.host,
                              bubble: KLiveColors.chatScrim,
                              onProfile: (username) =>
                                  unawaited(showHostSheet(context, username)),
                            ),
                          ),
                        ],
                      )
                    : middle ?? const SizedBox.expand(),
              ),
            ),
            if (gate == null && !ended && !captureFailed) ...[
              if (setup && seats)
                Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.md),
                  child: GoLiveSeatCountPicker(
                    counts: state.mode == LiveRoomMode.audio
                        ? (cfg?.seatCounts.audio ?? const [6, 9, 15, 20, 25])
                        : (cfg?.seatCounts.multi ?? const [4, 6, 9, 12]),
                    selected: state.seatCount!,
                    accent: art.accent,
                    onSelect: previewing
                        ? (c) => unawaited(_guard(() => _host.setSeatCount(c)))
                        : null,
                  ),
                ),
              if (onAir && room != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    pad - 4,
                    0,
                    pad - 4,
                    KSpacing.sm,
                  ),
                  child:
                      chatComposer ??
                      LiveChatPill(
                        key: GoLiveScreen.videoChatKey,
                        hint: l10n.goLiveChatPill,
                        onTap: openChat,
                      ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: pad),
                child: GoLiveToolsBar(tools: tools, accent: art.accent),
              ),
              const SizedBox(height: KSpacing.lg),
              // On air the live ends from ✕ at the top (owner D94).
              if (!onAir)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.xxxl - KSpacing.sm,
                  ),
                  child: LiveGlowButton(
                    label: busy ? l10n.goLiveStarting : l10n.goLiveStart,
                    busy: busy,
                    icon: state.mode == LiveRoomMode.audio
                        ? Icons.mic_rounded
                        : Icons.videocam_rounded,
                    onPressed: previewing ? () => unawaited(_start()) : null,
                  ),
                ),
              const SizedBox(height: KSpacing.sm),
            ],
            if (!onAir && !ended)
              IgnorePointer(
                ignoring: busy,
                child: GoLiveModeBar(
                  selected: state.mode,
                  accent: art.accent,
                  onSelect: gate == null
                      ? (m) => unawaited(_host.setMode(m))
                      : null,
                ),
              ),
          ],
        ),
      );
    }

    return PopScope(
      // Back while live minimizes; the live goes on (owner D94).
      canPop: !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && state.phase == GoLivePhase.live) {
          ref.read(liveMinimizedProvider.notifier).minimize();
        }
      },
      child: KLiveSurface(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: KPalette.dark.background,
            resizeToAvoidBottomInset: false,
            body: Stack(
              fit: StackFit.expand,
              children: [
                background,
                body,
                if (_countdown case final n?)
                  // The countdown (sized from the owner's recording).
                  IgnorePointer(
                    child: Align(
                      alignment: const Alignment(0, 0.5),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          '$n',
                          key: GoLiveScreen.countdownKey,
                          textDirection: TextDirection.ltr,
                          style: context.textStyles.headline.copyWith(
                            color: const Color(0xFFFFFFFF),
                            fontSize: 214,
                            height: 1,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _seatsVersionSeen = -1;
  String? _watchedRoom;

  /// Refetches the seats when the media room's `seatsVersion` moves.
  void _watchSeatsVersion(LiveRoom? room) {
    if (room == null || _watchedRoom == room.id) return;
    _watchedRoom = room.id;
    final engine = _host.engine;
    void onChange() {
      final v = engine.seatsVersion;
      if (v != null && v > _seatsVersionSeen && mounted) {
        _seatsVersionSeen = v;
        ref.invalidate(liveSeatsProvider(room.id));
      }
      if (mounted) setState(() {});
    }

    engine.changes.addListener(onChange);
  }

  Future<void> _afterSeatChange(String roomId) async =>
      ref.invalidate(liveSeatsProvider(roomId));

  Future<void> _seatActions(String roomId, LiveSeats seats, int index) {
    final repo = ref.read(liveRepositoryProvider);
    final seat = seats.seats.firstWhere(
      (s) => s.index == index,
      orElse: () =>
          LiveSeat(index: index, state: LiveSeatState.empty, user: null),
    );
    return showSeatActions(
      context,
      seat: seat,
      isHost: true,
      moderators: seats.moderators,
      onMute: ({required muted}) async {
        await repo.muteSeat(roomId, index, muted: muted);
        await _afterSeatChange(roomId);
      },
      onRemove: () async {
        await repo.removeFromSeat(roomId, index);
        await _afterSeatChange(roomId);
      },
      onLock: ({required locked}) async {
        await repo.lockSeat(roomId, index, locked: locked);
        await _afterSeatChange(roomId);
      },
      onModerator: (username, {required moderator}) async {
        if (moderator) {
          await repo.addModerator(roomId, username);
        } else {
          await repo.removeModerator(roomId, username);
        }
        await _afterSeatChange(roomId);
      },
      onInvite: () => showInviteViewers(
        context,
        roomId: roomId,
        moderators: seats.moderators,
        seated: seats.seats,
        onInvite: (username) async {
          await repo.inviteToSeat(roomId, username, seatIndex: index);
          await _afterSeatChange(roomId);
        },
        onModerator: (username, {required moderator}) async {
          if (moderator) {
            await repo.addModerator(roomId, username);
          } else {
            await repo.removeModerator(roomId, username);
          }
          await _afterSeatChange(roomId);
        },
      ),
    );
  }

  /// Who is watching: invite to a seat, make or remove moderators.
  Future<void> _openViewers(String roomId, LiveSeats? seats) =>
      showInviteViewers(
        context,
        roomId: roomId,
        moderators: seats?.moderators ?? const [],
        seated: seats?.seats ?? const [],
        onInvite: (username) async {
          await ref.read(liveRepositoryProvider).inviteToSeat(roomId, username);
          await _afterSeatChange(roomId);
        },
        onModerator: (username, {required moderator}) async {
          final repo = ref.read(liveRepositoryProvider);
          if (moderator) {
            await repo.addModerator(roomId, username);
          } else {
            await repo.removeModerator(roomId, username);
          }
          await _afterSeatChange(roomId);
        },
      );

  Future<void> _openRequests(String roomId) {
    final repo = ref.read(liveRepositoryProvider);
    return showSeatRequests(
      context,
      roomId: roomId,
      onAccept: (r) async {
        await repo.acceptSeatRequest(roomId, r.id);
        await _afterSeatChange(roomId);
      },
      onDecline: (r) async {
        await repo.declineSeatRequest(roomId, r.id);
        await _afterSeatChange(roomId);
      },
    );
  }

  Widget _captureNotice(GoLiveState state) {
    final l10n = context.l10n;
    final denied = state.capture == LiveCaptureProblem.denied;
    return LiveGlass(
      child: _Notice(
        key: GoLiveScreen.captureFailedKey,
        icon: denied
            ? Icons.no_photography_outlined
            : Icons.videocam_off_outlined,
        title: denied
            ? l10n.goLiveCameraDeniedTitle
            : l10n.goLiveCameraUnavailableTitle,
        body: denied
            ? l10n.goLiveCameraDeniedBody
            : l10n.goLiveCameraUnavailableBody,
        onRetry: () => unawaited(_host.startPreview()),
      ),
    );
  }

  /// The camera picture (full screen for LIVE, the host tile for
  /// multi-guest), with [fallback] until it runs.
  Widget _camera(GoLiveState state, {Widget? fallback}) {
    final picture = state.phase == GoLivePhase.ended
        ? null
        : _host.engine.preview();
    if (picture == null) {
      return fallback ??
          (state.phase == GoLivePhase.preparing
              ? const _Spinner()
              : ColoredBox(color: KPalette.dark.surface));
    }
    return SizedBox.expand(key: ValueKey(state.frontCamera), child: picture);
  }
}

class _Spinner extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => Center(
    child: CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation(KPalette.dark.textPrimary),
    ),
  );
}

/// A centred explanation over the empty stage (gates, camera problems).
class _Notice extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.textStyles;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.xxl,
          vertical: KSpacing.xxxl * 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: KSpacing.xxxl, color: p.textSecondary),
            const SizedBox(height: KSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: text.title,
              ),
            ),
            const SizedBox(height: KSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: text.body.copyWith(color: p.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: KSpacing.xl),
              KButton(
                key: GoLiveScreen.retryKey,
                label: context.l10n.actionRetry,
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// LIVE · elapsed time and the title while on air.
class _LiveClock extends StatelessWidget {
  const new({required this.since, required this.title});

  final DateTime? since;
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = context.textStyles;
    final elapsed = formatLiveDuration(
      since == null ? Duration.zero : clock.now().difference(since!),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          key: GoLiveScreen.elapsedKey,
          label: context.l10n.goLiveElapsed(elapsed),
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const KBadge.live(),
              const SizedBox(width: KSpacing.sm),
              Text(
                elapsed,
                textDirection: TextDirection.ltr,
                style: text.label.copyWith(
                  color: p.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        if (title.isNotEmpty) ...[
          const SizedBox(height: KSpacing.xs),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.caption.copyWith(color: p.textPrimary),
          ),
        ],
      ],
    );
  }
}

/// Over: the duration and Done.
class _Ended extends StatelessWidget {
  const new({required this.state, required this.onDone});

  final GoLiveState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final since = state.liveSince;
    final until = state.endedAt ?? clock.now();
    final duration = formatLiveDuration(
      since == null ? Duration.zero : until.difference(since),
    );
    return ColoredBox(
      key: GoLiveScreen.endedKey,
      color: p.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sensors_off_outlined,
                size: KSpacing.xxxl,
                color: p.textSecondary,
              ),
              const SizedBox(height: KSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  l10n.goLiveEndedTitle,
                  textAlign: TextAlign.center,
                  style: text.title,
                ),
              ),
              const SizedBox(height: KSpacing.sm),
              Text(
                l10n.goLiveEndedDuration(duration),
                style: text.body.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: KSpacing.xl),
              KButton(
                key: GoLiveScreen.doneKey,
                label: l10n.goLiveDone,
                onPressed: onDone,
                expand: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
