import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
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
import 'package:kabso_live/features/live/application/live_assistant.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/application/live_lucky_ticker.dart';
import 'package:kabso_live/features/live/application/live_program.dart';
import 'package:kabso_live/features/live/application/live_quips.dart';
import 'package:kabso_live/features/live/application/live_seat_emojis.dart';
import 'package:kabso_live/features/live/application/live_stickers.dart';
import 'package:kabso_live/features/live/application/live_tap_batcher.dart';
import 'package:kabso_live/features/live/application/live_watch.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_color_filter.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart'
    show showHostSheet;
import 'package:kabso_live/features/live/presentation/go_live/go_live_audio_setup.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_setup_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_assistant_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_boost_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cp_seats.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_data_center_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_end_summary.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_fill_light.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_glass.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_host_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_newcomers_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_program_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_quality_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_info_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_tools.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_schedule_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_score_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_emoji.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_soundboard_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_sticker_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_theme_art.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_watch_sheet.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/live/presentation/live_fx_diagnostics.dart';
import 'package:kabso_live/features/live/presentation/live_permission_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_background_texts.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_cp_entrance.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_games_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_effects_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_lucky_combo_button.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_person_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_side_cards.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_sticker_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_tap_layer.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_viewer_parts.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_watch_card.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/live/new` — go live (CP-010, CP-011), designed after the owner's two
/// references (D94) in Kabso's own look: Multi-guest · LIVE · Audio LIVE.
///
/// - **LIVE:** the camera fills the screen.
/// - **Multi-guest:** the room theme behind a grid of 4, 6, 9 or 12 tiles,
///   the host's camera in the first.
/// - **Audio:** the room theme behind the host's crowned circle and rows of
///   seats (5, 10, 15 or 20 with the host, D103, D123).
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

  /// D135: the host's quick replies over the host bar.
  static const hostQuickRepliesKey = Key('goLive.quickReplies');

  static const minimizeKey = Key('goLive.minimize');
  static const viewersKey = Key('goLive.viewers');

  /// D154g: the «السلاسة» suggestion on a weak connection.
  static const smoothSuggestKey = Key('goLive.smoothSuggest');
  static const shareKey = Key('goLive.share');
  static const videoChatKey = Key('goLive.videoChat');
  static const audioChatKey = Key('goLive.audio.chat');
  static const audioMoreKey = Key('goLive.audio.more');
  static const audioPkKey = Key('goLive.audio.pk');

  /// D141: the games button (in place of the toolbox, which repeated ≡).
  static const audioGamesKey = Key('goLive.audio.games');
  static const audioGiftKey = Key('goLive.audio.gift');
  static const endConfirmKey = Key('goLive.endConfirm');
  static const doneKey = Key('goLive.done');
  static const retryKey = Key('goLive.retry');

  /// D144a: «فتح الإعدادات» on the capture notice (access refused for good).
  static const settingsKey = Key('goLive.openSettings');
  static const elapsedKey = Key('goLive.elapsed');
  static const notAllowedKey = Key('goLive.notAllowed');
  static const unavailableKey = Key('goLive.unavailable');
  static const captureFailedKey = Key('goLive.captureFailed');
  static const endedKey = Key('goLive.ended');

  /// D131: the host pill's lines (this live's points, its taps, mic off).
  static const scoreKey = Key('goLive.score');
  static const tapsKey = Key('goLive.taps');
  static const micOffKey = Key('goLive.micOff');
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
  bool _emojiMode = false;
  String? _chatRoom;
  String? _category;
  bool _previewRequested = false;
  Timer? _tick;

  /// D120 (owner): the host taps their own live and it counts like a
  /// viewer's tap (CONVENTIONS §10.10); the batches of the room on air.
  LiveTapBatcher? _taps;
  String? _tapsRoom;
  int? _tapScore;

  /// D131: the parts of [_tapScore] (its taps feed the host pill).
  LiveScore? _tapParts;

  /// D144a: back from the system settings, the capture starts if access is
  /// now allowed.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(_host.recheckPermission()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _tick?.cancel();
    _taps?.close();
    _title.dispose();
    _titleFocus.dispose();
    _chat.dispose();
    _chatFocus.dispose();
    super.dispose();
  }

  LiveHostController get _host => ref.read(liveHostControllerProvider.notifier);

  /// One tap of the host on their own live (D120): batched and sent like a
  /// viewer's; the answer moves the score until the media room's catches up.
  void _tapLive(String roomId) {
    if (_tapsRoom != roomId) {
      _taps?.close();
      _tapsRoom = roomId;
      _tapScore = null;
      _tapParts = null;
      final repo = ref.read(liveRepositoryProvider);
      _taps = LiveTapBatcher(
        send: (count) => repo.tap(roomId, count),
        onScore: (score) {
          if (mounted) {
            setState(() {
              _tapScore = score.total;
              _tapParts = score;
            });
          }
        },
      );
    }
    _taps!.tap();
  }

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
        unawaited(_host.startPreview(explain: _explainPermission));
      }
    });
  }

  /// D144a: the rationale before the system's camera/microphone prompt.
  Future<bool> _explainPermission({required bool camera}) async {
    if (!mounted) return false;
    return await showLivePermissionSheet(context, camera: camera);
  }

  /// Minimizes the live into the floating window (owner D94); it goes on.
  /// D123: back to where the person was — never to Create, which opened
  /// the go-live screen: the tab they came from (the Live hub by default).
  void _minimize() {
    ref.read(liveMinimizedProvider.notifier).minimize();
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.of(context).maybePop();
    } else {
      leaveToShell(router, ref);
    }
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
    final background = liveBackgroundTexts(l10n);
    await _guard(
      () => _host.goLive(
        title: title,
        categorySlug: _category,
        background: background,
      ),
    );
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
    // D158: the host's own handle (a premium username has no «@»).
    final handle = KHandle.plain(
      username,
      premiumTier: ref.read(currentUserProvider)?.premiumTier,
    );
    await Clipboard.setData(
      ClipboardData(text: l10n.goLiveShareText(title, handle)),
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
      // CP-020: the room's gifts, on the same media session.
      ref.read(liveGiftEffectsProvider(room.id).notifier).attach(engine);
      // D138: the emojis people play on their seats.
      ref.read(liveSeatEmojisProvider(room.id).notifier).attach(engine);
      // D148: big lucky wins in other lives (the gold ticker).
      ref.read(liveLuckyTickersProvider(room.id).notifier).attach(engine);
      // D154: the room's quips (one at a time, after their delay).
      ref.read(liveQuipsProvider(room.id).notifier).attach(engine);
      // D154e: the live's program.
      ref.read(liveProgramProvider(room.id).notifier).attach(engine);
      // D154h: the live's stickers.
      ref.read(liveStickersProvider(room.id).notifier).attach(engine);
      // D154i: watch-together (the host's suggestions too).
      ref.read(liveWatchProvider(room.id).notifier)
        ..onSuggestion = (s) {
          if (mounted) {
            KSnack.info(
              context,
              context.l10n.liveWatchNewSuggestion(s.video.title),
            );
          }
        }
        ..attach(engine, host: true);
      // D154f: the host's assistant (hints on this phone only).
      ref
          .read(liveAssistantProvider(room.id).notifier)
          .attach(
            engine,
            startedAt: room.startedAt,
            selfId: ref.read(currentUserProvider)?.id,
          );
      unawaited(
        ref
            .read(liveChatProvider(room.id).notifier)
            .attach(engine, enabled: room.chatEnabled, muted: false),
      );
    });
  }

  /// D154g: a weak connection for a while with the normal picture suggests
  /// «السلاسة» (at most every 5 min).
  final _poorWatch = PoorConnectionWatch();

  /// D160: 1080p falls back to 720p after a weak connection for 10 s.
  final _hdFallback = HdFallbackWatch();

  void _checkConnection() {
    final engine = _host.engine;
    if (!engine.videoEnabled) return;
    if (_hdFallback.feed(
      engine.connectionQuality,
      engine.videoQuality,
      clock.now(),
    )) {
      unawaited(_fallBackFromHd());
      return;
    }
    if (!_poorWatch.feed(
      engine.connectionQuality,
      engine.videoQuality,
      clock.now(),
    )) {
      return;
    }
    final l10n = context.l10n;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: GoLiveScreen.smoothSuggestKey,
          content: Text(l10n.liveQualitySuggest),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: l10n.liveQualitySuggestAction,
            onPressed: () => unawaited(_goSmooth()),
          ),
        ),
      );
  }

  Future<void> _fallBackFromHd() async {
    final l10n = context.l10n;
    try {
      await _host.engine.setVideoQuality(LiveVideoQuality.normal);
      if (mounted) KSnack.info(context, l10n.liveQualityHighFallback);
    } on Object {
      // The camera keeps 1080p; the next weak spell tries again.
    }
  }

  Future<void> _goSmooth() async {
    final l10n = context.l10n;
    try {
      await _host.engine.setVideoQuality(LiveVideoQuality.smooth);
      if (mounted) KSnack.success(context, l10n.liveQualitySmoothOn);
    } on LiveCaptureException {
      if (mounted) KSnack.error(context, l10n.liveQualityFailed);
    }
  }

  void _syncTicker(GoLiveState state) {
    final live = state.phase == GoLivePhase.live;
    if (live && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        _checkConnection();
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
    // Before going live, the count previewed is the one that will be sent
    // (a count the server no longer allows shows as the next allowed one).
    final setupSeats = switch (state.seatCount) {
      final c? => fitSeatCount(
        c,
        state.mode == LiveRoomMode.audio
            ? (cfg?.seatCounts.audio ?? const [5, 10, 15, 20])
            : (cfg?.seatCounts.multi ?? const [4, 6, 9, 12]),
      ),
      null => null,
    };
    final seatCount = liveSeats?.seatCount ?? room?.seatCount ?? setupSeats;
    final engine = _host.engine;
    _watchSeatsVersion(room);
    _attachChat(room, engine, onAir);
    final chat = onAir && room != null
        ? ref.watch(liveChatProvider(room.id))
        : null;
    void openChat({bool emoji = false}) {
      setState(() {
        _writing = true;
        _emojiMode = emoji;
      });
      // D131 (ref 162): from 😊 the emoji panel, the keyboard hidden.
      if (!emoji) _chatFocus.requestFocus();
    }

    void send() {
      if (room == null) return;
      unawaited(sendLiveChatFrom(context, ref, roomId: room.id, field: _chat));
    }

    final roomChat = room == null || chat == null
        ? null
        : LiveRoomChatLines(
            // D135: a bright theme darkens the rules line's fill a little.
            brightNotice: LiveRoomRulesNotice.isBrightTheme(state.theme),
            roomId: room.id,
            role: LiveChatViewerRole.host,
            onProfile: (username) => _person(room.id, username),
          );
    final chatComposer = _writing
        ? TapRegion(
            onTapOutside: (_) => setState(() {
              _writing = false;
              _chatFocus.unfocus();
            }),
            child: LiveRoomComposer(
              roomId: room?.id ?? '',
              emoji: _emojiMode,
              // CP-017: the host's mic pauses while a voice clip records.
              liveMic: engine,
              controller: _chat,
              focusNode: _chatFocus,
              onSend: send,
              // CP-017: private messages; the live goes on minimized.
              onMessages: () {
                final router = GoRouter.maybeOf(context);
                if (router == null) return;
                ref.read(liveMinimizedProvider.notifier).minimize();
                router.go(AppRoutes.messages);
              },
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
    // Owner (2026-10-26, "the host cannot tap"): a seat answers the host's
    // tap as soon as the room exists — while the seats are still being read
    // (or the last read failed) the tap reads them first, and says why when
    // it cannot.
    ValueChanged<int>? onSeat;
    if (room != null && seats) {
      onSeat = (index) => unawaited(_tapSeat(room.id, liveSeats, index));
    }

    final audioOnAir =
        gate == null && onAir && state.mode == LiveRoomMode.audio;
    // D131: the host's video live in the viewer's frame (host pill, chips,
    // inline chat, the host bar).
    final videoOnAir =
        gate == null &&
        onAir &&
        !captureFailed &&
        room != null &&
        state.mode != LiveRoomMode.audio;
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
        // D143 Magic: colour filters on the published picture (greyed with
        // why where the device has no camera pipeline; D144: Android has
        // one), and D144's Effects (beta) where DeepAR runs.
        GoLiveTool(
          id: 'magic',
          icon: Icons.auto_awesome_rounded,
          label: l10n.liveToolMagic,
          badge:
              !state.beauty.filter.isNatural ||
              state.beauty.effect != LiveArEffect.none,
          onTap: canAct
              ? () => unawaited(
                  showLiveFilterSheet(
                    context,
                    selected: state.beauty.filter,
                    supported: engine.filtersSupported,
                    accent: art.accent,
                    onChanged: (f) => unawaited(_host.setColorFilter(f)),
                    effects: engine.arEffects,
                    effect: state.beauty.effect,
                    onEffect: (e) => unawaited(_host.setArEffect(e)),
                    effectStatus: engine.arStatus,
                  ),
                )
              : null,
        ),
        // D143 fill light: the front camera's soft light with its level
        // (D157: a sheet — off/low/medium/high) or the torch (back camera,
        // a toggle); one tool for both (it replaces "Flash").
        GoLiveTool(
          id: 'fillLight',
          icon: state.frontCamera
              ? Icons.light_mode_rounded
              : Icons.flashlight_on_rounded,
          label: l10n.liveToolFillLight,
          toggled: state.fillLight,
          onTap: canAct && engine.videoEnabled
              ? () => unawaited(_toggleFillLight(state, art.accent))
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
                        ? (cfg?.seatCounts.audio ?? const [5, 10, 15, 20])
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
      // In the room tools sheet (audio and, D131, video).
      if (onAir)
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
    if (ended && gate == null) {
      // D140 (owner): the end-of-live summary takes the whole screen.
      body = _Ended(
        state: state,
        hostName: user?.displayName ?? '',
        hostUsername: user?.username,
        hostAvatarUrl: user?.avatarUrl,
        onDone: _close,
      );
    } else if (audioSetup) {
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
        seatCounts: cfg?.seatCounts.audio ?? const [5, 10, 15, 20],
        seatCount: setupSeats!,
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
            : (mode) =>
                  unawaited(_host.setMode(mode, explain: _explainPermission)),
        hostName: hostName,
        hostAvatarUrl: user?.avatarUrl,
        onShare: user == null
            ? null
            : () => unawaited(_shareLive(_title.text.trim(), user.username)),
      );
    } else if (audioOnAir) {
      // CP-012: the score from the media room's metadata, else the host's
      // last tap batch (D120), else the room's.
      final score =
          engine.score ??
          (_tapsRoom == room?.id ? _tapScore : null) ??
          room?.score ??
          0;
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
                    onWishList: () => unawaited(_openWishSheet()),
                    wishCount: _wishCount(state),
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
      // ≡ and the toolbox open the room tools (owner, 2026-10-26).
      void openTools() => unawaited(
        showLiveRoomTools(
          context,
          // Ref 84's tools in its order: ours where they exist (the
          // voice in the mixer's place, viewers as users, chat as
          // comments), the rest greyed with "Soon" (owner D99).
          room: [
            // D138: the host plays an emoji on their own tile (0).
            GoLiveTool(
              id: 'seatEmoji',
              icon: Icons.add_reaction_rounded,
              label: l10n.liveSeatEmoji,
              onTap: room == null || !live
                  ? null
                  : () => unawaited(
                      showSeatEmojiSheet(
                        context,
                        ref,
                        roomId: room.id,
                        seat: 0,
                      ),
                    ),
            ),
            ?byId['voice'],
            GoLiveTool.soon(
              id: 'music',
              icon: Icons.music_note_rounded,
              label: l10n.liveToolMusic,
            ),
            // D154: the host's free soundboard (quips' free sounds).
            GoLiveTool(
              id: 'sounds',
              icon: Icons.graphic_eq_rounded,
              label: l10n.liveToolSounds,
              onTap: room == null || !live
                  ? null
                  : () =>
                        unawaited(showLiveSoundboard(context, roomId: room.id)),
            ),
            // D154e: the live's program (everyone sees its card).
            GoLiveTool(
              id: 'program',
              icon: Icons.movie_creation_outlined,
              label: l10n.liveToolProgramList,
              onTap: room == null || !live
                  ? null
                  : () => unawaited(
                      showLiveProgramEditor(
                        context,
                        roomId: room.id,
                        startedAt: room.startedAt,
                      ),
                    ),
            ),
            GoLiveTool.soon(
              id: 'screen',
              icon: Icons.screen_share_outlined,
              label: l10n.liveToolShareScreen,
            ),
            // D154i: YouTube watch-together (the official player).
            GoLiveTool(
              id: 'youtube',
              icon: Icons.smart_display_outlined,
              label: l10n.liveToolYoutube,
              onTap: room == null || !live
                  ? null
                  : () =>
                        unawaited(showLiveWatchSheet(context, roomId: room.id)),
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
            // D143: the same User management as video rooms (moderators
            // included: the audio room has seats).
            _managementTool(state, live ? room : null, liveSeats),
            // D154f: the host's rule-based assistant (its settings).
            GoLiveTool(
              id: 'assistance',
              icon: Icons.support_agent_rounded,
              label: l10n.liveToolAssistance,
              onTap: () => unawaited(showLiveAssistantSettings(context)),
            ),
            GoLiveTool.soon(
              id: 'recorder',
              icon: Icons.videocam_outlined,
              label: l10n.liveToolRecorder,
            ),
            // D154c: the newcomers in this room, with «رحّب».
            GoLiveTool(
              id: 'newcomers',
              icon: Icons.fiber_new_outlined,
              label: l10n.liveToolNewcomers,
              onTap: room == null || !live
                  ? null
                  : () =>
                        unawaited(showLiveNewcomers(context, roomId: room.id)),
            ),
            // D154d: the host's data center.
            GoLiveTool(
              id: 'data',
              icon: Icons.insights_outlined,
              label: l10n.liveToolDataCenter,
              onTap: () => unawaited(showLiveDataCenter(context)),
            ),
            // D141 (owner): the host's live schedule (D99 C), from the
            // live itself.
            GoLiveTool(
              id: 'time',
              icon: Icons.alarm_rounded,
              label: l10n.liveToolLiveTime,
              onTap: () => unawaited(showLiveSchedule(context)),
            ),
            // D154b: the traffic card (a paid «مميز» slot for this room).
            GoLiveTool(
              id: 'traffic',
              icon: Icons.confirmation_number_outlined,
              label: l10n.liveToolTrafficCard,
              onTap: room == null || !live
                  ? null
                  : () =>
                        unawaited(showLiveBoostSheet(context, roomId: room.id)),
            ),
            byId['guests']!,
          ],
        ),
      );
      // The chat box opens from 💬 and 🙂 (CP-013).
      // D166: YouTube together turns the room into the owner's cinema.
      final cinema =
          live && room != null && LiveWatchScreen.shows(ref, room.id);
      final ring = AudioSeatRing(
        count: seatCount!,
        // D166: no points pills on the cinema's seats.
        compact: cinema,
        seats: liveSeats?.seats ?? const [],
        // D111: CP partners on adjacent seats are drawn joined.
        cpPairs: room == null
            ? const []
            : cpSeatPairs(liveSeats, hostId: room.host.id),
        host: KAvatar(
          name: hostName,
          imageUrl: user?.avatarUrl,
          size: AudioSeatRing.picture,
        ),
        hostName: hostName,
        hostMicOn: state.micEnabled,
        // Owner (2026-10-26): a tap on the host's own picture opens their
        // card (not a mute); they turn the mic on or off from there.
        // Before the live starts there is no card: the tap tries the mic.
        onHost: room == null
            ? byId['mic']!.onTap
            : () => unawaited(
                _person(
                  room.id,
                  room.host.username,
                  selfMic: (
                    enabled: state.micEnabled,
                    set: ({required enabled}) async {
                      final host = ref.read(liveHostControllerProvider);
                      if (host.micEnabled != enabled) {
                        await ref
                            .read(liveHostControllerProvider.notifier)
                            .toggleMic();
                      }
                    },
                  ),
                ),
              ),
        hostTapLabel: room != null
            ? l10n.liveUserViewProfile
            : state.micEnabled
            ? l10n.goLiveMuteMic
            : l10n.goLiveUnmuteMic,
        hostPoints: KFormat.compact(score, l10n),
        speaking: speaking,
        onSeat: onSeat,
        // D138: the emojis played on the seats.
        overlay: room == null
            ? null
            : seatEmojiOverlay(ref, room.id, picture: AudioSeatRing.picture),
      );
      body = LiveAudioRoomLayout(
        // D145c: the gift strips keep above the chat text.
        onChatTop: room == null
            ? null
            : (top) => ref.read(liveChatTopProvider(room.id).notifier).set(top),
        // D145a: the combo in the promo box's place.
        combo: room != null && LuckyComboCluster.shows(ref, room.id)
            ? LuckyComboCluster(roomId: room.id)
            : null,
        // D141a (owner): the promo box over the gift button.
        promo: live && room != null && LiveRoomPromoBox.shows(ref, room.id)
            ? LiveRoomPromoBox(
                roomId: room.id,
                boxWidth: LiveRoomPromoBox.audioWidth,
              )
            : null,
        // D166: YouTube together turns the room into a cinema — the
        // player on top, the seats under it.
        screen: cinema
            ? LiveWatchScreen(
                roomId: room.id,
                host: true,
                part: LiveWatchPart.player,
              )
            : null,
        screenBar: cinema
            ? LiveWatchScreen(
                roomId: room.id,
                host: true,
                part: LiveWatchPart.bar,
              )
            : null,
        // D166: the wish list (D136) in the audio room too, over the promo
        // box; a tap changes it.
        wish: live && room != null && room.wishGifts.isNotEmpty
            ? LiveWishCard(
                wishes: room.wishGifts,
                onEdit: () => unawaited(_openWishSheet()),
              )
            : null,
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
          level: room?.roomLevel,
          // D141 (owner): the host's @username (copy on tap), not the
          // room number.
          username: user?.username,
          premiumTier: user?.premiumTier,
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
        stage: ring,
        // D166: the cinema's seats on the drawn seats.
        cinemaSeat: cinema ? ring.cinemaTile : null,
        cinemaSeats: seatCount,
        chat: [?roomChat],
        composer: chatComposer,
        // Ref 83: chat, emoji and the tools menu on one side; seats, PK and
        // the mic on the other.
        barStart: [
          LiveRoundButton(
            key: GoLiveScreen.audioChatKey,
            icon: Icons.chat_bubble_outline_rounded,
            asset: 'assets/live_bar/chat.png',
            bare: true,
            label: l10n.goLiveChatPill,
            onTap: openChat,
          ),
          LiveRoundButton(
            icon: Icons.emoji_emotions_rounded,
            asset: 'assets/live_bar/emoji.png',
            bare: true,
            label: l10n.livePreviewEmoji,
            onTap: () => openChat(emoji: true),
          ),
          LiveRoundButton(
            key: GoLiveScreen.audioMoreKey,
            icon: Icons.menu_rounded,
            asset: 'assets/live_bar/menu.png',
            bare: true,
            label: l10n.livePreviewMore,
            onTap: openTools,
          ),
        ],
        barEnd: [
          LiveRoundButton(
            key: GoLiveKeys.tool('requests'),
            // D141 (owner): the video bar's ∞ (guests) icon.
            icon: Icons.all_inclusive_rounded,
            bare: true,
            label: byId['requests']!.label,
            // Owner (2026-10-26): the seat button opens the room's people on
            // the Guests tab — the requests, then who is on a seat.
            onTap: switch ((room, byId['requests']!.onTap)) {
              (final r?, _?) => () => unawaited(
                _openViewers(r.id, liveSeats, guests: true),
              ),
              _ => null,
            },
            badge: liveSeats?.pendingRequests ?? 0,
          ),
          // PK is not in the contract yet: the button says so.
          LiveRoundButton(
            key: GoLiveScreen.audioPkKey,
            icon: Icons.sports_mma_rounded,
            // D135/D141: the owner's colourful PK art, as on the video bar.
            asset: 'assets/live_bar/bar_pk.png',
            art: true,
            bare: true,
            label: l10n.goLivePk,
            onTap: () => KSnack.info(context, l10n.goLivePkSoon),
          ),
          // D141 (owner): games, with the owner's controller art, where
          // the toolbox was (it repeated ≡). There are no games yet: the
          // button says so (no list is shown).
          LiveRoundButton(
            key: GoLiveScreen.audioGamesKey,
            icon: Icons.sports_esports_rounded,
            asset: 'assets/live_bar/bar_games.png',
            art: true,
            bare: true,
            label: l10n.liveGames,
            // D166: the same games sheet as the viewers' bars.
            onTap: () => unawaited(showLiveGamesSheet(context)),
          ),
          LiveRoundButton(
            key: GoLiveScreen.audioGiftKey,
            icon: Icons.card_giftcard_rounded,
            // D135/D141: the owner's colourful gift box.
            asset: 'assets/live_bar/bar_gift.png',
            art: true,
            bare: true,
            label: l10n.liveGifts,
            onTap: room == null ? null : () => unawaited(_openGifts(room)),
          ),
        ],
      );
    } else if (videoOnAir) {
      body = _videoOnAir(
        state: state,
        room: room,
        background: background,
        stage: middle,
        tools: tools,
        chat: chat,
        liveSeats: liveSeats,
        seatCount: seatCount,
        roomChat: LiveRoomChatLines(
          roomId: room.id,
          role: LiveChatViewerRole.host,
          bubble: KLiveColors.chatScrim,
          onProfile: (username) => _person(room.id, username),
          inline: true,
        ),
        composer: chatComposer,
        openChat: openChat,
      );
    } else {
      body = KTopSafeArea(
        bottom: true,
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
                        level: room?.roomLevel,
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
                // D131 (ref 164): the glass card 13.4 pt from the sides.
                padding: const EdgeInsets.fromLTRB(
                  KGoLiveSetup.cardInset,
                  KSpacing.sm,
                  KGoLiveSetup.cardInset,
                  0,
                ),
                child: GoLiveSetupCard(
                  hostName: hostName,
                  hostAvatarUrl: user?.avatarUrl,
                  controller: _title,
                  focusNode: _titleFocus,
                  enabled: previewing,
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
                                  _person(room.id, username),
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
                        ? (cfg?.seatCounts.audio ?? const [5, 10, 15, 20])
                        : (cfg?.seatCounts.multi ?? const [4, 6, 9, 12]),
                    selected: setupSeats!,
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
              // D131 (ref 164): two rows of tools, the second foldable.
              _setupTools(state, tools, canAct: previewing),
              const SizedBox(height: KSpacing.lg),
              GoLiveStartPill(
                label: busy ? l10n.goLiveStarting : l10n.goLiveStart,
                busy: busy,
                onPressed: previewing ? () => unawaited(_start()) : null,
              ),
              const SizedBox(height: KSpacing.md),
            ],
            if (!onAir && !ended)
              IgnorePointer(
                ignoring: busy,
                child: GoLiveModePager(
                  selected: state.mode,
                  onSelect: gate == null
                      ? (m) => unawaited(
                          _host.setMode(m, explain: _explainPermission),
                        )
                      : null,
                ),
              ),
          ],
        ),
      );
    }

    return PopScope(
      // Back while live minimizes; the live goes on (owner D94), and the
      // person returns where they came from, not to Create (D123).
      canPop: !busy && state.phase != GoLivePhase.live,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && state.phase == GoLivePhase.live) _minimize();
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
                if (!videoOnAir) background,
                // D120 (owner): the host cheers their own live like a viewer:
                // a tap on an empty part of the stage counts and pops a
                // character; seats, the bar, the chat and the cards keep
                // their taps.
                if (room != null && state.phase == GoLivePhase.live)
                  LiveTapLayer(
                    onTap: () => _tapLive(room.id),
                    // The lane starts just above the audio bar, or above
                    // the chat pill and tools of a video live.
                    // D131: a video live's lane starts 59 pt up, over
                    // the gift button (as the viewer's).
                    laneBottomInset: audioOnAir ? 56 : 59,
                    child: body,
                  )
                else
                  body,
                // CP-020: gift banners and effects over the live.
                if (onAir && room != null)
                  LiveGiftEffectsLayer(
                    roomId: room.id,
                    onSender: (u) => unawaited(_person(room.id, u.username)),
                    // D145c: the strips centred at the reading start in
                    // audio and video alike; beside a video live's wish
                    // column.
                    stripsStart: LiveGiftEffectsLayer.videoStripsStart(
                      sideColumn:
                          !audioOnAir &&
                          (room.wishGifts.isNotEmpty ||
                              LiveRoomPromoBox.shows(ref, room.id)),
                    ),
                  ),
                // D145: the lucky combo button after a lucky gift is sent.
                if (onAir && room != null)
                  LuckyComboLayer(
                    roomId: room.id,
                    hostUsername: room.host.username,
                    // Over the audio bar, or over the video live's quick
                    // replies.
                    bottom: audioOnAir
                        ? LuckyComboLayer.audioBottom
                        : LuckyComboLayer.videoBottom,
                  ),
                // D154i: the video the live watches together.
                if (room != null && state.phase == GoLivePhase.live)
                  LiveWatchLayer(
                    roomId: room.id,
                    host: true,
                    // D160: a floating window in a video live.
                    pip: state.mode != LiveRoomMode.audio,
                  ),
                // D154f: the assistant's hint, for the host only.
                if (room != null && state.phase == GoLivePhase.live)
                  LiveAssistantHintLayer(roomId: room.id),
                // CP-021 (D112): the CP Entrance Effect.
                if (onAir && room != null) LiveCpEntranceLayer(roomId: room.id),
                // D144a: DeepAR's diagnostics for the owner's screenshots —
                // debug/profile builds with the camera processor only.
                if (LiveFxDiagnostics.enabled &&
                    engine.arEffects != LiveArSupport.unsupported &&
                    state.mode != LiveRoomMode.audio &&
                    engine.videoEnabled)
                  PositionedDirectional(
                    top: MediaQuery.paddingOf(context).top + 120,
                    start: KSpacing.sm,
                    child: LiveFxDiagnostics(
                      load: engine.arDiagnostics,
                      status: engine.arStatus,
                    ),
                  ),
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

  bool _toolsExpanded = true;

  /// D131 (ref 164): the setup's tools — Flip, Beauty, Magic (D143 colour
  /// filters), the microphone and the fold; then Fill light (D143), the
  /// voice, the theme
  /// (seat rooms), Share and Settings (who may watch).
  Widget _setupTools(
    GoLiveState state,
    List<GoLiveTool> tools, {
    required bool canAct,
  }) {
    final l10n = context.l10n;
    final user = ref.read(currentUserProvider);
    final byId = {for (final t in tools) t.id: t};
    return GoLiveToolGrid(
      expanded: _toolsExpanded,
      onExpanded: (v) => setState(() => _toolsExpanded = v),
      first: [?byId['flip'], ?byId['beauty'], ?byId['magic'], ?byId['mic']],
      second: [
        ?byId['fillLight'],
        GoLiveTool(
          id: 'voice',
          icon: Icons.tune_rounded,
          label: l10n.liveToolsVoice,
          onTap: canAct
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
        ?byId['theme'],
        GoLiveTool(
          id: 'share',
          icon: Icons.share_outlined,
          label: l10n.goLiveShare,
          onTap: user == null
              ? null
              : () => unawaited(_shareLive(_title.text.trim(), user.username)),
        ),
        GoLiveTool(
          id: 'settings',
          icon: Icons.settings_outlined,
          label: l10n.settingsTitle,
          onTap: canAct
              ? () => unawaited(
                  showLiveSetupSettings(
                    context,
                    onWishList: () => unawaited(_openWishSheet()),
                    wishCount: _wishCount(state),
                    allowGuests: state.allowGuests,
                    guestsKey: GoLiveScreen.guestsChipKey,
                    onAllowGuests: (allow) => unawaited(
                      _guard(() => _host.setAllowGuests(allow: allow)),
                    ),
                    onShare: user == null
                        ? null
                        : () => unawaited(
                            _shareLive(_title.text.trim(), user.username),
                          ),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  /// D131 (owner's recording, §11c): the host's video live in the viewer's
  /// frame — the host pill (this live's cherries, then its taps; no follow),
  /// the viewers, minimize and ✕ (end, confirmed); LIVE · time with the
  /// room chips; the stage (multi-guest seats); the inline chat; and the
  /// host bar: 💬 ✨ ≡ … ∞ PK 🎁. Flip and the microphone moved into ≡,
  /// which keeps every tool (owner D99: the missing ones say "Soon").
  Widget _videoOnAir({
    required GoLiveState state,
    required LiveRoom room,
    required Widget background,
    required Widget? stage,
    required List<GoLiveTool> tools,
    required LiveChatState? chat,
    required LiveSeats? liveSeats,
    required int? seatCount,
    required Widget roomChat,
    required Widget? composer,
    required VoidCallback openChat,
  }) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    final engine = _host.engine;
    final live = state.phase == GoLivePhase.live;
    final byId = {for (final t in tools) t.id: t};
    final score =
        engine.score ?? (_tapsRoom == room.id ? _tapScore : null) ?? room.score;
    final taps =
        (_tapsRoom == room.id ? _tapParts?.tapPoints : null) ??
        room.scoreParts?.tapPoints;
    final hostName = user?.displayName ?? room.host.displayName;
    final avatarUrl = user?.avatarUrl ?? room.host.avatarUrl;
    final viewers = ref.watch(liveViewersPreviewProvider(room.id)).value;
    void openSelf() => unawaited(
      _person(
        room.id,
        room.host.username,
        selfMic: (
          enabled: state.micEnabled,
          set: ({required enabled}) async {
            final host = ref.read(liveHostControllerProvider);
            if (host.micEnabled != enabled) {
              await ref.read(liveHostControllerProvider.notifier).toggleMic();
            }
          },
        ),
      ),
    );
    final openRoomInfo = !live
        ? null
        : () => unawaited(
            showLiveRoomInfo(
              context,
              hostName: hostName,
              hostAvatarUrl: avatarUrl,
              onSettings: () => unawaited(
                showLiveSetupSettings(
                  context,
                  onWishList: () => unawaited(_openWishSheet()),
                  wishCount: _wishCount(state),
                  allowGuests: state.allowGuests,
                  onAllowGuests: (_) => unawaited(_toggleGuests(state)),
                  onShare: user == null
                      ? null
                      : () => unawaited(_shareLive(room.title, user.username)),
                ),
              ),
            ),
          );
    final management = _managementTool(state, live ? room : null, liveSeats);
    GoLiveTool soon(String id, IconData icon, String label) =>
        GoLiveTool.soon(id: id, icon: icon, label: label);
    void openTools() => unawaited(
      showLiveRoomTools(
        context,
        // The recording's Room Tools in its order: ours where they exist,
        // the rest "Soon" (D99); our other tools stay in the same sheet.
        room: [
          // D135 (owner: "minimize is in ≡ at the bottom, not at the top").
          GoLiveTool(
            id: 'minimize',
            icon: Icons.picture_in_picture_alt_rounded,
            label: l10n.goLiveMinimize,
            onTap: live ? _minimize : null,
          ),
          // D136: the wish list.
          GoLiveTool(
            id: 'wish',
            icon: Icons.card_giftcard_rounded,
            label: l10n.liveToolWish,
            onTap: !live ? null : () => unawaited(_openWishSheet()),
          ),
          GoLiveTool(
            id: 'share',
            icon: Icons.share_rounded,
            label: l10n.goLiveShare,
            onTap: user == null
                ? null
                : () => unawaited(_shareLive(room.title, user.username)),
          ),
          ?byId['fillLight'],
          ?byId['flip'],
          soon('dual', Icons.switch_video_rounded, l10n.liveToolDual),
          // D154g: «الجودة» (HD and «السلاسة» in one tool).
          GoLiveTool(
            id: 'quality',
            icon: liveConnectionIcon(engine.connectionQuality),
            label: l10n.liveToolQuality,
            onTap: engine.videoEnabled
                ? () => unawaited(showLiveQualitySheet(context, engine: engine))
                : null,
          ),
          // D154h: Kabi and text stickers on the live (≤ 3).
          GoLiveTool(
            id: 'sticker',
            icon: Icons.emoji_emotions_outlined,
            label: l10n.liveToolSticker,
            onTap: !live
                ? null
                : () =>
                      unawaited(showLiveStickerSheet(context, roomId: room.id)),
          ),
          ?byId['mic'],
          soon('music', Icons.music_note_rounded, l10n.liveToolMusic),
          // D154: the host's free soundboard (quips' free sounds).
          GoLiveTool(
            id: 'sounds',
            icon: Icons.graphic_eq_rounded,
            label: l10n.liveToolSounds,
            onTap: !live
                ? null
                : () => unawaited(showLiveSoundboard(context, roomId: room.id)),
          ),
          // D160: YouTube watch-together in a video live too (a floating
          // window over the picture).
          GoLiveTool(
            id: 'youtube',
            icon: Icons.smart_display_outlined,
            label: l10n.liveToolYoutube,
            onTap: !live
                ? null
                : () => unawaited(showLiveWatchSheet(context, roomId: room.id)),
          ),
          ?byId['beauty'],
          ?byId['voice'],
          ?byId['theme'],
          ?byId['seats'],
          ?byId['requests'],
        ],
        other: [
          GoLiveTool(
            id: 'topic',
            icon: Icons.info_outline_rounded,
            label: l10n.liveToolInfo,
            onTap: openRoomInfo,
          ),
          GoLiveTool(
            id: 'viewers',
            icon: Icons.people_alt_outlined,
            label: l10n.liveToolsViewers,
            onTap: !live
                ? null
                : () => unawaited(_openAudience(room, liveSeats)),
          ),
          ?byId['chat'],
          management,
          // D154f: the host's rule-based assistant (its settings).
          GoLiveTool(
            id: 'assistance',
            icon: Icons.support_agent_rounded,
            label: l10n.liveToolAssistance,
            onTap: () => unawaited(showLiveAssistantSettings(context)),
          ),
          // D154e: the live's program (everyone sees its card).
          GoLiveTool(
            id: 'program',
            icon: Icons.movie_creation_outlined,
            label: l10n.liveToolProgramList,
            onTap: !live
                ? null
                : () => unawaited(
                    showLiveProgramEditor(
                      context,
                      roomId: room.id,
                      startedAt: room.startedAt,
                    ),
                  ),
          ),
          soon('recorder', Icons.videocam_outlined, l10n.liveToolRecorder),
          // D154c: the newcomers in this live, with «رحّب».
          GoLiveTool(
            id: 'newcomers',
            icon: Icons.fiber_new_outlined,
            label: l10n.liveToolNewcomers,
            onTap: !live
                ? null
                : () => unawaited(showLiveNewcomers(context, roomId: room.id)),
          ),
          // D154d: the host's data center.
          GoLiveTool(
            id: 'data',
            icon: Icons.insights_outlined,
            label: l10n.liveToolDataCenter,
            onTap: () => unawaited(showLiveDataCenter(context)),
          ),
          // D141 (owner): the host's live schedule (D99 C), from the live.
          GoLiveTool(
            id: 'time',
            icon: Icons.alarm_rounded,
            label: l10n.liveToolLiveTime,
            onTap: () => unawaited(showLiveSchedule(context)),
          ),
          // D154b: the traffic card (a paid «مميز» slot for this live).
          GoLiveTool(
            id: 'traffic',
            icon: Icons.confirmation_number_outlined,
            label: l10n.liveToolTrafficCard,
            onTap: !live
                ? null
                : () => unawaited(showLiveBoostSheet(context, roomId: room.id)),
          ),
          ?byId['guests'],
        ],
      ),
    );
    void openBeauty() => unawaited(
      showLiveToolGrid(
        context,
        title: l10n.liveBeautyToolsTitle,
        tools: [
          ?byId['beauty'],
          ?byId['magic'],
          ?byId['fillLight'],
          GoLiveTool(
            id: 'mixer',
            icon: Icons.tune_rounded,
            label: l10n.liveToolMixer,
            onTap: !live
                ? null
                : () => unawaited(
                    showLiveVoiceSheet(
                      context,
                      noiseReduction: state.noiseReduction,
                      enhance: state.voiceEnhance,
                      onChanged: _host.setVoice,
                    ),
                  ),
          ),
        ],
      ),
    );
    final micOff = !state.micEnabled;
    // D135: the host's own charm level and points (`GET /levels/me`).
    final charm = ref
        .watch(myLevelsProvider)
        .value
        ?.where(
          (l) => l.category == LevelCategory.attractiveness && l.available,
        )
        .firstOrNull;
    return KLiveRoomScaffold(
      // D145c: the gift strips keep above the chat text.
      onChatTop: (top) =>
          ref.read(liveChatTopProvider(room.id).notifier).set(top),
      // D154h: the stickers over the picture; the host moves them.
      video: Stack(
        fit: StackFit.expand,
        children: [
          background,
          LiveStickerLayer(roomId: room.id, editable: live),
        ],
      ),
      header: KHostPill(
        // D141 (owner): the host's @username beside the name (copy on tap).
        username: user?.username,
        premiumTier: user?.premiumTier,
        hostName: hostName,
        avatar: avatarUrl == null ? null : NetworkImage(avatarUrl),
        lines: [
          if (micOff)
            KHostPillLine(
              key: GoLiveScreen.micOffKey,
              icon: const Icon(
                Icons.mic_off_rounded,
                size: 11,
                color: Color(0xFFFFFFFF),
              ),
              text: l10n.goLiveMicOff,
              color: const Color(0xFFFFFFFF),
            ),
          Semantics(
            label: l10n.liveHostPillPoints(KFormat.grouped(score)),
            excludeSemantics: true,
            child: KHostPillLine(
              key: GoLiveScreen.scoreKey,
              icon: const KCherryIcon(size: 11),
              text: KFormat.grouped(score),
            ),
          ),
          if (taps != null)
            Semantics(
              label: l10n.liveHostPillTaps(KFormat.grouped(taps)),
              excludeSemantics: true,
              child: KHostPillLine(
                key: GoLiveScreen.tapsKey,
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
        onTap: live ? openSelf : null,
      ),
      viewers: viewers == null || viewers.items.isEmpty
          ? null
          : LiveViewersStack(
              key: GoLiveScreen.viewersKey,
              avatarSize: 28.5,
              pitch: 33.5,
              countHeight: 28,
              countMinWidth: 34,
              avatars: [
                for (final v in viewers.items)
                  if (v.user case final u?)
                    KAvatar(
                      name: u.displayName,
                      imageUrl: u.avatarUrl,
                      size: 28.5,
                    ),
              ],
              count: viewers.next == null
                  ? KFormat.compact(viewers.items.length, l10n)
                  : '${KFormat.compact(viewers.items.length, l10n)}+',
              label: l10n.liveViewers(
                viewers.items.length,
                KFormat.compact(viewers.items.length, l10n),
              ),
              onTap: () => unawaited(_openAudience(room, liveSeats)),
            ),
      // D136: the wish list (a tap changes it); D137: the promo box.
      sideStart: LiveWishCard(
        wishes: room.wishGifts,
        onEdit: live ? () => unawaited(_openWishSheet()) : null,
      ),
      sidePromo: live ? LiveRoomPromoBox(roomId: room.id) : null,
      // D145a: the lucky combo beside the chat, over the quick replies.
      chatEnd: LuckyComboCluster.shows(ref, room.id)
          ? LuckyComboCluster(roomId: room.id)
          : null,
      closeButtonKey: GoLiveScreen.closeKey,
      closeLabel: l10n.goLiveEndConfirm,
      onClose: live ? () => unawaited(_confirmEnd()) : null,
      // D135 (owner: "the charm level is in the wrong place"): the board
      // chip and the charm level chip with the host's points against the
      // next level at the start; the LIVE timer and the room ID at the end.
      roomInfo: KRoomChipsRow(
        level: charm?.level?.levelNumber ?? room.roomLevel,
        points: charm?.points.toInt(),
        target: charm?.nextLevel?.requiredPoints.toInt(),
        elapsed: _HostElapsed(since: state.liveSince),
      ),
      stage: stage,
      chat: Align(alignment: AlignmentDirectional.bottomStart, child: roomChat),
      actionBar:
          composer ??
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // D135 (ref 158 §4.7): the host's quick replies over the bar
              // while the chat is on (each one an ordinary chat message).
              if (chat != null && chat.enabled) ...[
                KQuickReplies(
                  key: GoLiveScreen.hostQuickRepliesKey,
                  host: true,
                  onSend: (text) => unawaited(
                    sendLiveChatText(context, ref, roomId: room.id, text: text),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              KHostBar(
                chatKey: GoLiveScreen.videoChatKey,
                onChat: openChat,
                onBeauty: openBeauty,
                onTools: openTools,
                beautyOn: state.beauty.enabled,
                requests: liveSeats?.pendingRequests ?? 0,
                // In a multi-guest live: requests and seats; a solo live has no
                // seats to join (switching mid-live has no backend yet).
                onGuests: state.mode.hasSeats
                    ? () => unawaited(
                        _openViewers(room.id, liveSeats, guests: true),
                      )
                    : () => KSnack.info(context, l10n.liveHostGuestsSoon),
                onPk: () => KSnack.info(context, l10n.goLivePkSoon),
                onGift: () => unawaited(_openGifts(room)),
              ),
            ],
          ),
    );
  }

  /// Who is watching: in a seat room the invite sheet; in a solo live the
  /// viewers list (there is no seat to invite to).
  Future<void> _openAudience(LiveRoom room, LiveSeats? seats) {
    if (room.mode.hasSeats) return _openViewers(room.id, seats);
    return showLiveViewers(
      context,
      roomId: room.id,
      onPerson: (u) => unawaited(_person(room.id, u.username)),
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

  /// [username]'s card, seen by the host (owner, 2026-10-26): points, kick,
  /// chat mute, make or remove moderator, report and block; Invite to a
  /// seat when [onInvite] is given.
  Future<void> _person(
    String roomId,
    String username, {
    bool? moderator,
    VoidCallback? onInvite,
    ValueChanged<bool>? onModeratorChanged,
    ({bool enabled, Future<void> Function({required bool enabled}) set})?
    selfMic,
  }) {
    // Seat rooms know their moderators; a SOLO live reads no seats.
    final seats = liveSeatsProvider(roomId);
    final current = ref.exists(seats) ? ref.read(seats).value : null;
    final moderators = current?.moderators ?? const <UserSummary>[];
    final seat = current?.seats
        .where((s) => s.user?.username == username)
        .firstOrNull;
    final isModerator =
        moderator ?? moderators.any((m) => m.username == username);
    final repo = ref.read(liveRepositoryProvider);
    return showHostSheet(
      context,
      username,
      onInvite: onInvite,
      scope: LivePersonScope(
        roomId: roomId,
        viewer: LivePersonRole.host,
        target: isModerator ? LivePersonRole.moderator : LivePersonRole.viewer,
        onModerator: (username, {required moderator}) async {
          if (moderator) {
            await repo.addModerator(roomId, username);
          } else {
            await repo.removeModerator(roomId, username);
          }
          onModeratorChanged?.call(moderator);
          await _afterSeatChange(roomId);
        },
        onKicked: () => unawaited(_afterSeatChange(roomId)),
        seat: seat,
        onSeatMute: (index, {required muted}) async {
          await repo.muteSeat(roomId, index, muted: muted);
          await _afterSeatChange(roomId);
        },
        selfMic: selfMic,
        onGift: switch (ref.read(liveHostControllerProvider).room) {
          final room? when room.id == roomId => (person) => unawaited(
            _openGifts(room, preselect: person),
          ),
          _ => null,
        },
        // D135: Mention — "@username" in the host's chat box, opened.
        onMention: (username) {
          if (!mounted) return;
          insertMention(_chat, username);
          setState(() {
            _writing = true;
            _emojiMode = false;
          });
          _chatFocus.requestFocus();
        },
      ),
    );
  }

  /// D136: the wish list — the live room's, else the one picked before
  /// going live.
  List<String> _wishCodes(GoLiveState state) =>
      state.room?.wishGifts.map((w) => w.giftCode).toList() ??
      state.wishGifts ??
      const [];

  int? _wishCount(GoLiveState state) =>
      state.room != null || state.wishGifts != null
      ? _wishCodes(state).length
      : null;

  /// D136: the host picks the wish list (setup settings, Room Tools, a tap
  /// on the card).
  Future<void> _openWishSheet() => showLiveWishSheet(
    context,
    initial: _wishCodes(ref.read(liveHostControllerProvider)),
    onSave: _host.setWishGifts,
  );

  /// CP-020: the host's gift panel: to the people on a seat now, and to
  /// the host themself (D128).
  Future<void> _openGifts(LiveRoom room, {LiveGiftPreselect? preselect}) =>
      KLiveGiftSheet.show(
        context,
        preselect: preselect,
        room: LiveGiftRoom(
          roomId: room.id,
          host: room.host,
          seated: (ref) => [
            for (final seat
                in ref.watch(liveSeatsProvider(room.id)).value?.seats ??
                    const <LiveSeat>[])
              ?seat.user,
          ],
          onSeatsStale: () {
            if (mounted) unawaited(_afterSeatChange(room.id));
          },
          // D154: the host's free quips are the soundboard's.
          soundboard: (_) => true,
        ),
      );

  /// A tap on seat [index]: its actions, from [seats] or, when they are not
  /// read yet, from a fresh read (a failure is explained).
  Future<void> _tapSeat(String roomId, LiveSeats? seats, int index) async {
    final LiveSeats current;
    if (seats != null) {
      current = seats;
    } else {
      try {
        current = await ref.refresh(liveSeatsProvider(roomId).future);
      } on Object catch (e) {
        if (mounted) {
          KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
        }
        return;
      }
      if (!mounted) return;
    }
    await _seatActions(roomId, current, index);
  }

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
  Future<void> _openViewers(
    String roomId,
    LiveSeats? seats, {
    bool guests = false,
  }) {
    final repo = ref.read(liveRepositoryProvider);
    return showInviteViewers(
      context,
      roomId: roomId,
      moderators: seats?.moderators ?? const [],
      seated: seats?.seats ?? const [],
      initialTab: guests ? 1 : 0,
      onPerson: (u, {required moderator, onInvite, onModeratorChanged}) =>
          _person(
            roomId,
            u.username,
            moderator: moderator,
            onInvite: onInvite,
            onModeratorChanged: onModeratorChanged,
          ),
      onAccept: (r) async {
        await repo.acceptSeatRequest(roomId, r.id);
        await _afterSeatChange(roomId);
      },
      onDecline: (r) async {
        await repo.declineSeatRequest(roomId, r.id);
        await _afterSeatChange(roomId);
      },
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
  }

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
    final problem = state.capture;
    final refused =
        problem == LiveCaptureProblem.denied ||
        problem == LiveCaptureProblem.blocked;
    // D144a: an audio room asks for the microphone only, and says so.
    final audio = state.mode == LiveRoomMode.audio;
    final blocked = problem == LiveCaptureProblem.blocked;
    return LiveGlass(
      child: _Notice(
        key: GoLiveScreen.captureFailedKey,
        icon: !refused
            ? Icons.videocam_off_outlined
            : (audio ? Icons.mic_off_rounded : Icons.no_photography_outlined),
        title: !refused
            ? l10n.goLiveCameraUnavailableTitle
            : (audio
                  ? l10n.goLiveMicDeniedTitle
                  : l10n.goLiveCameraDeniedTitle),
        body: blocked
            ? (audio
                  ? l10n.livePermissionBlockedAudio
                  : l10n.livePermissionBlockedVideo)
            : refused
            ? (audio ? l10n.goLiveMicDeniedBody : l10n.goLiveCameraDeniedBody)
            : l10n.goLiveCameraUnavailableBody,
        // Refused for good: the system will not ask again; the settings
        // can (the capture starts on return, [recheckPermission]).
        onSettings: blocked
            ? () => unawaited(_host.openPermissionSettings())
            : null,
        onRetry: () =>
            unawaited(_host.startPreview(explain: _explainPermission)),
      ),
    );
  }

  /// The host's User management (D131; D143 audio rooms too): muted,
  /// removed, the moderators (assign from the viewers, remove here) and
  /// signed-in viewers only. Greyed until [room] is on air.
  GoLiveTool _managementTool(
    GoLiveState state,
    LiveRoom? room,
    LiveSeats? liveSeats,
  ) {
    final seats = state.mode.hasSeats;
    return GoLiveTool(
      id: 'management',
      icon: Icons.manage_accounts_outlined,
      label: context.l10n.liveToolManagement,
      onTap: room == null
          ? null
          : () => unawaited(
              showLiveUserManagement(
                context,
                roomId: room.id,
                hasSeats: seats,
                allowGuests: state.allowGuests,
                onAllowGuests: ({required allow}) =>
                    _host.setAllowGuests(allow: allow),
                onChanged: seats
                    ? () => unawaited(_afterSeatChange(room.id))
                    : null,
                onAddModerator: seats
                    ? () => unawaited(_openViewers(room.id, liveSeats))
                    : null,
              ),
            ),
    );
  }

  /// D143 fill light. The front camera (D157): the level sheet. The back
  /// camera: the torch on or off; says so when it has none.
  Future<void> _toggleFillLight(GoLiveState state, Color accent) async {
    if (state.frontCamera) {
      await showLiveFillLightSheet(
        context,
        level: state.fillLight ? state.fillLightLevel : LiveFillLight.off,
        onPicture: _host.engine.filtersSupported,
        accent: accent,
        onChanged: (level) =>
            unawaited(_host.setFillLight(on: !level.isOff, level: level)),
      );
      return;
    }
    final on = !state.fillLight;
    final done = await _host.setFillLight(on: on);
    if (!mounted || done) return;
    KSnack.info(context, context.l10n.liveFillLightNoTorch);
  }

  /// The camera picture (full screen for LIVE, the host tile for
  /// multi-guest), with [fallback] until it runs. D157: with the fill light
  /// on and the front camera the picture itself is lifted (camera
  /// pipeline); only a device without one shows the thin edge glow.
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
    return SizedBox.expand(
      key: ValueKey(state.frontCamera),
      child: Stack(
        fit: StackFit.expand,
        children: [
          picture,
          LiveFillLightFrame(
            on:
                state.fillLight &&
                state.frontCamera &&
                !_host.engine.filtersSupported,
            level: state.fillLightLevel,
          ),
        ],
      ),
    );
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
    this.onSettings,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onRetry;

  /// D144a: «فتح الإعدادات», first, when set.
  final VoidCallback? onSettings;

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
            if (onSettings != null) ...[
              const SizedBox(height: KSpacing.xl),
              KButton(
                key: GoLiveScreen.settingsKey,
                label: context.l10n.livePermissionOpenSettings,
                icon: Icons.settings_rounded,
                onPressed: onSettings,
                expand: false,
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: onSettings != null ? KSpacing.sm : KSpacing.xl),
              KButton(
                key: GoLiveScreen.retryKey,
                label: context.l10n.actionRetry,
                variant: onSettings != null
                    ? KButtonVariant.secondary
                    : KButtonVariant.primary,
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
  const new({required this.since, required this.title, this.level});

  final DateTime? since;
  final String title;

  /// CP-016 D (D101): the room level after the title.
  final int? level;

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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.caption.copyWith(color: p.textPrimary),
                ),
              ),
              if (level case final level?) ...[
                const SizedBox(width: KSpacing.xs),
                CharmLevelBadge(level: level),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// Over (D131, D140): the full-screen end-of-live summary, from the live's
/// statistics (`GET /live/rooms/{roomId}/stats`) and the host's charm level.
class _Ended extends ConsumerWidget {
  const new({
    required this.state,
    required this.hostName,
    required this.hostUsername,
    required this.hostAvatarUrl,
    required this.onDone,
  });

  final GoLiveState state;
  final String hostName;

  /// Reads the host's profile for the CP Special Frame (D112).
  final String? hostUsername;
  final String? hostAvatarUrl;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final since = state.liveSince;
    final until = state.endedAt ?? clock.now();
    final local = since == null ? Duration.zero : until.difference(since);
    final room = state.room;
    final stats = room == null
        ? null
        : ref.watch(liveRoomStatsProvider(room.id));
    final charm = ref
        .watch(myLevelsProvider)
        .value
        ?.where((l) => l.category == LevelCategory.attractiveness)
        .firstOrNull;
    final value = stats?.value;
    final username = hostUsername;
    // D140b: the host's own avatar frame (the CP Special Frame) in the hero.
    final framed =
        username != null &&
        cpWearsSpecialFrame(
          ref.watch(profileStatsProvider(username)).value?.cp,
        );
    return Semantics(
      key: GoLiveScreen.endedKey,
      container: true,
      label: l10n.goLiveEndedDuration(
        formatLiveDuration(value?.duration ?? local),
      ),
      child: GoLiveSummary(
        localDuration: local,
        stats: value,
        loading: stats != null && stats.isLoading && !stats.hasValue,
        failed: stats == null || (stats.hasError && !stats.hasValue),
        onRetry: room == null
            ? null
            : () => ref.invalidate(liveRoomStatsProvider(room.id)),
        hostName: hostName,
        hostAvatarUrl: hostAvatarUrl,
        hostCpFrame: framed,
        charm: charm,
        onDone: onDone,
        doneKey: GoLiveScreen.doneKey,
      ),
    );
  }
}

/// D131: LIVE · elapsed time, as a chip in the host's second row.
class _HostElapsed extends StatelessWidget {
  const new({required this.since});

  final DateTime? since;

  @override
  Widget build(BuildContext context) =>
      KLiveElapsedPill(key: GoLiveScreen.elapsedKey, since: since);
}
