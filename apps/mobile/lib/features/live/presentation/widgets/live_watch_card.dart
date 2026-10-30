import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/logging/app_logger.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_watch.dart';
import 'package:kabso_live/features/live/data/youtube_player.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_watch_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D154i («يوتيوب», CONVENTIONS §10.39): the video the live watches
/// together, as a 16:9 card under the room's header (a Stack child). The
/// host's player has YouTube's controls and its play / pause / seek become
/// the room's state; viewers' players have none and follow it (a seek when
/// they drift more than 2 s). A viewer may hide it on their phone or
/// suggest a video; the host sees the waiting suggestions and stops the
/// show. Anyone may hide it on their own phone (the room keeps watching).
/// Nothing while no video is on. D173: in an audio room the card is the
/// cinema screen inside the room's layout ([LiveWatchScreen]); this layer
/// then only shows the «show» pill while it is hidden on this phone.
/// D160: in a video live ([pip]) the same
/// player floats in a small window over the host's picture
/// ([LiveWatchPip]).
class LiveWatchLayer extends ConsumerWidget {
  const new({
    required this.roomId,
    required this.host,
    this.pip = false,
    super.key,
  });

  final String roomId;
  final bool host;

  /// D160: a video live — the floating window instead of the card.
  final bool pip;

  /// Under the header rows and the program card.
  static const double top = 148;

  static const cardKey = Key('watch.card');
  static const showKey = Key('watch.show');
  static const hideKey = Key('watch.hide');
  static const suggestKey = Key('watch.suggest');
  static const manageKey = Key('watch.manage');
  static const pipKey = Key('watch.pip');
  static const pipBarKey = Key('watch.pipBar');
  static const closeKey = Key('watch.close');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(liveWatchProvider(roomId));
    final video = view.watch?.video;
    final topInset = MediaQuery.paddingOf(context).top + top;
    if (video == null) {
      return const Positioned(top: 0, left: 0, child: SizedBox.shrink());
    }
    if (pip) {
      return Positioned.fill(
        child: LiveWatchPip(roomId: roomId, host: host),
      );
    }
    final l10n = context.l10n;
    if (view.hidden) {
      return PositionedDirectional(
        top: topInset,
        end: KSpacing.sm,
        child: _Pill(
          key: showKey,
          icon: Icons.smart_display_rounded,
          label: l10n.liveWatchShow,
          onTap: () =>
              ref.read(liveWatchProvider(roomId).notifier).toggleHidden(),
        ),
      );
    }
    // D173: in an audio room the card is the cinema screen inside the
    // room's layout ([LiveWatchScreen]); this layer keeps only the pill.
    return const Positioned(top: 0, left: 0, child: SizedBox.shrink());
  }
}

/// D173 (owner: «عند فتح يوتيوب في الغرفة الصوتية تنتقل الكراسي إلى
/// أسفل»): the audio room's cinema screen — the player (16:9) and its bar
/// (title, suggest / manage, hide on this phone), placed by
/// `LiveAudioRoomLayout.screen` at the top of the room with the seats under
/// it. [shows] tells the room whether to switch to that layout.
class LiveWatchScreen extends ConsumerWidget {
  const new({
    required this.roomId,
    required this.host,
    super.key,
    this.part = LiveWatchPart.card,
  });

  final String roomId;
  final bool host;

  /// D173: the whole card, or (the cinema) the player on the drawn screen
  /// and its bar on the stage under it.
  final LiveWatchPart part;

  /// A video plays and this phone has not hidden it.
  static bool shows(WidgetRef ref, String roomId) {
    final view = ref.watch(liveWatchProvider(roomId));
    return view.watch?.video != null && !view.hidden;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(liveWatchProvider(roomId));
    final video = view.watch?.video;
    if (video == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    const cardKey = LiveWatchLayer.cardKey;
    const manageKey = LiveWatchLayer.manageKey;
    const suggestKey = LiveWatchLayer.suggestKey;
    const hideKey = LiveWatchLayer.hideKey;
    final player = _Player(
      key: ValueKey('watch.player.$host'),
      roomId: roomId,
      host: host,
    );
    final bar = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
      child: Row(
        children: [
          const Icon(
            Icons.smart_display_rounded,
            size: 16,
            color: Color(0xFFFF4D4D),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              KFormat.bidiIsolate(video.title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(
                color: const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (host)
            _IconAction(
              key: manageKey,
              icon: Icons.playlist_add_rounded,
              tooltip: l10n.liveWatchTitle,
              badge: view.suggestions.length,
              onTap: () =>
                  unawaited(showLiveWatchSheet(context, roomId: roomId)),
            )
          else
            _IconAction(
              key: suggestKey,
              icon: Icons.add_link_rounded,
              tooltip: l10n.liveWatchSuggest,
              onTap: () =>
                  unawaited(showLiveWatchSuggestSheet(context, roomId: roomId)),
            ),
          // Hidden on this phone only (the seats of an audio
          // room show again); the room keeps watching.
          _IconAction(
            key: hideKey,
            icon: Icons.close_fullscreen_rounded,
            tooltip: l10n.liveWatchHide,
            onTap: () =>
                ref.read(liveWatchProvider(roomId).notifier).toggleHidden(),
          ),
        ],
      ),
    );
    switch (part) {
      case LiveWatchPart.player:
        return ColoredBox(
          key: cardKey,
          color: const Color(0xFF000000),
          child: player,
        );
      case LiveWatchPart.bar:
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xB3141318),
            borderRadius: BorderRadius.circular(12),
          ),
          child: bar,
        );
      case LiveWatchPart.card:
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              key: cardKey,
              decoration: BoxDecoration(
                color: const Color(0xE6141318),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x33FFFFFF)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(aspectRatio: 16 / 9, child: player),
                  bar,
                ],
              ),
            ),
          ),
        );
    }
  }
}

/// D173: which part of the watch card [LiveWatchScreen] draws.
enum LiveWatchPart {
  /// The player and its bar in one card.
  card,

  /// The player alone (the cinema's drawn screen).
  player,

  /// The bar alone (title, suggest / manage, hide), under the screen.
  bar,
}

class _Player extends ConsumerStatefulWidget {
  const new({required this.roomId, required this.host, super.key});

  final String roomId;
  final bool host;

  @override
  ConsumerState<_Player> createState() => _PlayerState();
}

class _PlayerState extends ConsumerState<_Player> {
  late final YoutubePlayer _player;
  StreamSubscription<YoutubePlayerEvent>? _events;
  Timer? _tick;
  String? _loaded;
  bool _failed = false;
  bool _playing = false;

  /// Viewers check their drift this often; the host reports this often
  /// while playing.
  static const viewerCheck = Duration(seconds: 5);
  static const hostReport = Duration(seconds: 15);

  /// A viewer more than this far from the host seeks.
  static const maxDriftMs = 2000;

  LiveWatchController get _controller =>
      ref.read(liveWatchProvider(widget.roomId).notifier);

  @override
  void initState() {
    super.initState();
    _player = ref.read(youtubePlayerFactoryProvider)(controls: widget.host);
    _events = _player.events.listen(_onEvent);
    _tick = Timer.periodic(
      widget.host ? hostReport : viewerCheck,
      (_) => unawaited(widget.host ? _heartbeat() : _sync()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_follow()));
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_events?.cancel());
    _player.dispose();
    super.dispose();
  }

  void _onEvent(YoutubePlayerEvent event) {
    switch (event) {
      case YoutubePlayerReady():
        if (!widget.host) unawaited(_sync());
      case YoutubePlayerStateChanged(:final playing, :final positionMs):
        _playing = playing;
        // The host's player is the room's: play, pause, seek and the end.
        if (widget.host) {
          unawaited(
            _controller.report(playing: playing, positionMs: positionMs),
          );
        }
      case YoutubePlayerFailed(:final code, :final failure):
        // The same honest overlay for all; the log says whose fault (D154k).
        AppLogger.warning(
          'YouTube player error $code (${failure.name}) for $_loaded'
          '${failure.isConfiguration ? ': the embed identity was refused, '
                    'check the player origin' : ''}',
        );
        if (mounted) setState(() => _failed = true);
    }
  }

  /// Loads the room's video when it changes.
  Future<void> _follow() async {
    if (!mounted) return;
    final watch = ref.read(liveWatchProvider(widget.roomId)).watch;
    final id = watch?.video?.videoId;
    if (id == null || id == _loaded) return;
    _loaded = id;
    setState(() => _failed = false);
    await _player.load(
      id,
      startMs: _controller.expectedPositionMs(),
      play: watch!.playing,
    );
  }

  /// A viewer follows the host: play or pause, and seek when far off.
  Future<void> _sync() async {
    if (!mounted) return;
    final watch = ref.read(liveWatchProvider(widget.roomId)).watch;
    if (watch?.video == null) return;
    final expected = _controller.expectedPositionMs();
    final at = await _player.positionMs();
    if (at != null && (at - expected).abs() > maxDriftMs) {
      await _player.seekTo(expected);
    }
    if (watch!.playing && !_playing) {
      await _player.play();
    } else if (!watch.playing && _playing) {
      await _player.pause();
    }
  }

  /// The host's position now and then while playing (late joiners and
  /// drift).
  Future<void> _heartbeat() async {
    if (!_playing) return;
    final at = await _player.positionMs();
    if (at != null) {
      await _controller.report(playing: true, positionMs: at);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveWatchProvider(widget.roomId), (before, now) {
      if (now.watch?.video?.videoId != _loaded) {
        unawaited(_follow());
      } else if (!widget.host) {
        unawaited(_sync());
      }
    });
    return Stack(
      fit: StackFit.expand,
      children: [
        _player.view(),
        if (_failed)
          ColoredBox(
            color: const Color(0xE6000000),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Text(
                  context.l10n.liveWatchPlayerError,
                  textAlign: TextAlign.center,
                  style: context.textStyles.caption.copyWith(
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const new({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badge = 0,
    this.size = 44,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;
  final double size;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    constraints: BoxConstraints.tightFor(width: size, height: size),
    icon: Badge(
      isLabelVisible: badge > 0,
      label: Text(KFormat.compact(badge, context.l10n)),
      child: Icon(icon, size: 20, color: const Color(0xFFFFFFFF)),
    ),
  );
}

class _Pill extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xCC141318),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFFFF4D4D)),
            const SizedBox(width: 6),
            Text(
              label,
              style: context.textStyles.caption.copyWith(
                color: const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// D160: a corner of the watch window in a video live, by reading
/// direction (start is the right in Arabic).
enum LiveWatchCorner { topStart, topEnd, bottomStart, bottomEnd }

/// D160: where the watch window of a video live may sit — under the header
/// rows ([LiveWatchLayer.top]) and above the chat, the MAX X button and the
/// bottom bar (the quick replies and the bar, then the chat's 30 % cap) —
/// and its corners. Pure, for the window and its tests.
abstract final class LiveWatchPipGeometry {
  /// From the screen's sides and the band's edges.
  static const double margin = 8;

  /// The window's bar (drag, actions): 40 pt targets.
  static const double barHeight = 40;

  /// A video live's bar and quick replies over the bottom safe edge (as
  /// `LuckyComboLayer.videoBottom`).
  static const double bottomChrome = 100;

  /// The window's width: half the screen, 168–240 pt.
  static double width(double screenWidth) =>
      (screenWidth * 0.5).clamp(168.0, 240.0);

  /// The window's height for [width]: a 16:9 player and its bar.
  static double height(double width) => width * 9 / 16 + barHeight;

  /// The band the window keeps to on a [size] screen with [padding] and a
  /// [keyboard] up (the room's column ends on it).
  static ({double top, double bottom}) band(
    Size size,
    EdgeInsets padding, {
    double keyboard = 0,
  }) {
    final top = padding.top + LiveWatchLayer.top;
    final floor = keyboard > padding.bottom ? keyboard : padding.bottom;
    final bottom =
        size.height -
        floor -
        bottomChrome -
        size.height * KMetrics.chatMaxHeightFactor -
        margin;
    return (top: top, bottom: bottom);
  }

  /// The window's top-left at [corner]. Where the band is too short for
  /// the window, the bottom corners take the top row (the chat, MAX X and
  /// the bar stay free first).
  static Offset offsetOf(
    LiveWatchCorner corner, {
    required Size size,
    required EdgeInsets padding,
    required TextDirection direction,
    double keyboard = 0,
  }) {
    final w = width(size.width);
    final h = height(w);
    final b = band(size, padding, keyboard: keyboard);
    final start =
        corner == LiveWatchCorner.topStart ||
        corner == LiveWatchCorner.bottomStart;
    final left = (start == (direction == TextDirection.ltr))
        ? margin
        : size.width - margin - w;
    final bottomRow =
        corner == LiveWatchCorner.bottomStart ||
        corner == LiveWatchCorner.bottomEnd;
    final bottomTop = b.bottom - h;
    final top = bottomRow && bottomTop >= b.top ? bottomTop : b.top;
    return Offset(left, top);
  }

  /// The corner nearest a window whose top-left is [at].
  static LiveWatchCorner nearest(
    Offset at, {
    required Size size,
    required EdgeInsets padding,
    required TextDirection direction,
    double keyboard = 0,
  }) {
    final w = width(size.width);
    final h = height(w);
    final b = band(size, padding, keyboard: keyboard);
    final left = at.dx + w / 2 < size.width / 2;
    final start = left == (direction == TextDirection.ltr);
    final top = at.dy + h / 2 < (b.top + b.bottom) / 2;
    return switch ((top, start)) {
      (true, true) => LiveWatchCorner.topStart,
      (true, false) => LiveWatchCorner.topEnd,
      (false, true) => LiveWatchCorner.bottomStart,
      (false, false) => LiveWatchCorner.bottomEnd,
    };
  }
}

/// D160 («يوتيوب» in a video live): the video the live watches together in
/// a small floating window over the host's picture — the same synced player
/// as the audio room's card. Dragged by its bar, it settles in the nearest
/// corner of [LiveWatchPipGeometry.band] (never over the chat, MAX X or
/// the bottom bar); it collapses to a pill on this phone (anyone); the
/// host also manages the show (suggestions) and closes it for everyone;
/// a viewer suggests a video from it.
class LiveWatchPip extends ConsumerStatefulWidget {
  const new({required this.roomId, required this.host, super.key});

  final String roomId;
  final bool host;

  @override
  ConsumerState<LiveWatchPip> createState() => _LiveWatchPipState();
}

class _LiveWatchPipState extends ConsumerState<LiveWatchPip> {
  LiveWatchCorner _corner = LiveWatchCorner.topEnd;

  /// The window's top-left while it is dragged.
  Offset? _drag;

  Future<void> _close() async {
    final l10n = context.l10n;
    final failure = await ref
        .read(liveWatchProvider(widget.roomId).notifier)
        .stop();
    if (failure != null && mounted) {
      KSnack.error(context, failureMessage(l10n, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(liveWatchProvider(widget.roomId));
    final video = view.watch?.video;
    if (video == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final controller = ref.read(liveWatchProvider(widget.roomId).notifier);
    final mq = MediaQuery.of(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final keyboard = mq.viewInsets.bottom;
        Offset corner(LiveWatchCorner c) => LiveWatchPipGeometry.offsetOf(
          c,
          size: size,
          padding: mq.padding,
          direction: direction,
          keyboard: keyboard,
        );
        final w = LiveWatchPipGeometry.width(size.width);
        final h = LiveWatchPipGeometry.height(w);
        final at = _drag ?? corner(_corner);
        if (view.hidden) {
          // Collapsed on this phone: a pill in the same corner.
          final start =
              _corner == LiveWatchCorner.topStart ||
              _corner == LiveWatchCorner.bottomStart;
          return Stack(
            children: [
              PositionedDirectional(
                top: at.dy,
                start: start ? LiveWatchPipGeometry.margin : null,
                end: start ? null : LiveWatchPipGeometry.margin,
                child: _Pill(
                  key: LiveWatchLayer.showKey,
                  icon: Icons.smart_display_rounded,
                  label: l10n.liveWatchShow,
                  onTap: controller.toggleHidden,
                ),
              ),
            ],
          );
        }
        final b = LiveWatchPipGeometry.band(
          size,
          mq.padding,
          keyboard: keyboard,
        );
        final maxTop = b.bottom - h < b.top ? b.top : b.bottom - h;
        return Stack(
          children: [
            AnimatedPositioned(
              key: LiveWatchLayer.pipKey,
              duration: _drag == null
                  ? const Duration(milliseconds: 200)
                  : Duration.zero,
              curve: Curves.easeOutCubic,
              left: at.dx,
              top: at.dy,
              width: w,
              height: h,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xF0141318),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66000000), blurRadius: 12),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _Player(
                        key: ValueKey('watch.player.${widget.host}'),
                        roomId: widget.roomId,
                        host: widget.host,
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        key: LiveWatchLayer.pipBarKey,
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) => setState(() => _drag = at),
                        onPanUpdate: (d) => setState(() {
                          final p = (_drag ?? at) + d.delta;
                          _drag = Offset(
                            p.dx.clamp(
                              LiveWatchPipGeometry.margin,
                              size.width - LiveWatchPipGeometry.margin - w,
                            ),
                            p.dy.clamp(b.top, maxTop),
                          );
                        }),
                        onPanEnd: (_) => setState(() {
                          _corner = LiveWatchPipGeometry.nearest(
                            _drag ?? at,
                            size: size,
                            padding: mq.padding,
                            direction: direction,
                            keyboard: keyboard,
                          );
                          _drag = null;
                        }),
                        onPanCancel: () => setState(() => _drag = null),
                        child: Row(
                          children: [
                            const SizedBox(width: 4),
                            Semantics(
                              label: l10n.liveWatchDrag,
                              child: const Icon(
                                Icons.drag_indicator_rounded,
                                size: 16,
                                color: Color(0x99FFFFFF),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                KFormat.bidiIsolate(video.title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textStyles.caption.copyWith(
                                  color: const Color(0xFFFFFFFF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (widget.host)
                              _IconAction(
                                key: LiveWatchLayer.manageKey,
                                icon: Icons.playlist_add_rounded,
                                tooltip: l10n.liveWatchTitle,
                                badge: view.suggestions.length,
                                size: 40,
                                onTap: () => unawaited(
                                  showLiveWatchSheet(
                                    context,
                                    roomId: widget.roomId,
                                  ),
                                ),
                              )
                            else
                              _IconAction(
                                key: LiveWatchLayer.suggestKey,
                                icon: Icons.add_link_rounded,
                                tooltip: l10n.liveWatchSuggest,
                                size: 40,
                                onTap: () => unawaited(
                                  showLiveWatchSuggestSheet(
                                    context,
                                    roomId: widget.roomId,
                                  ),
                                ),
                              ),
                            // Collapsed on this phone only; the room keeps
                            // watching.
                            _IconAction(
                              key: LiveWatchLayer.hideKey,
                              icon: Icons.close_fullscreen_rounded,
                              tooltip: l10n.liveWatchHide,
                              size: 40,
                              onTap: controller.toggleHidden,
                            ),
                            if (widget.host)
                              _IconAction(
                                key: LiveWatchLayer.closeKey,
                                icon: Icons.close_rounded,
                                tooltip: l10n.liveWatchStop,
                                size: 40,
                                onTap: () => unawaited(_close()),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
