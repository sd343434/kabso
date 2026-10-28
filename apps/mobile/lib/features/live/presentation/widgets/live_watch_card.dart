import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
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
/// Nothing while no video is on.
class LiveWatchLayer extends ConsumerWidget {
  const new({required this.roomId, required this.host, super.key});

  final String roomId;
  final bool host;

  /// Under the header rows and the program card.
  static const double top = 148;

  static const cardKey = Key('watch.card');
  static const showKey = Key('watch.show');
  static const hideKey = Key('watch.hide');
  static const suggestKey = Key('watch.suggest');
  static const manageKey = Key('watch.manage');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(liveWatchProvider(roomId));
    final video = view.watch?.video;
    final topInset = MediaQuery.paddingOf(context).top + top;
    if (video == null) {
      return const Positioned(top: 0, left: 0, child: SizedBox.shrink());
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
    return Positioned(
      top: topInset,
      left: KSpacing.md,
      right: KSpacing.md,
      child: Center(
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
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _Player(
                    key: ValueKey('watch.player.$host'),
                    roomId: roomId,
                    host: host,
                  ),
                ),
                Padding(
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
                          onTap: () => unawaited(
                            showLiveWatchSheet(context, roomId: roomId),
                          ),
                        )
                      else
                        _IconAction(
                          key: suggestKey,
                          icon: Icons.add_link_rounded,
                          tooltip: l10n.liveWatchSuggest,
                          onTap: () => unawaited(
                            showLiveWatchSuggestSheet(context, roomId: roomId),
                          ),
                        ),
                      // Hidden on this phone only (the seats of an audio
                      // room show again); the room keeps watching.
                      _IconAction(
                        key: hideKey,
                        icon: Icons.close_fullscreen_rounded,
                        tooltip: l10n.liveWatchHide,
                        onTap: () => ref
                            .read(liveWatchProvider(roomId).notifier)
                            .toggleHidden(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
      case YoutubePlayerFailed():
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
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onTap,
    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
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
