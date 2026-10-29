import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// What an [InlineVideoController] shows.
@immutable
class InlineVideoState {
  const new({
    this.initialized = false,
    this.playing = false,
    this.buffering = false,
    this.failed = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.size = Size.zero,
  });

  final bool initialized;
  final bool playing;
  final bool buffering;
  final bool failed;
  final Duration position;
  final Duration duration;

  /// The picture's size once known.
  final Size size;
}

/// A network video in a post or a reel (v1.41-social, D162): the file the
/// server stores as uploaded (`MediaAsset.url`, progressive download).
/// Production uses [VideoPlayerInlineVideo]; widget tests use a fake (the
/// plugin has no implementation there).
abstract class InlineVideoController implements Listenable {
  InlineVideoState get state;

  /// Opens the video (looping). Throws when it cannot be played.
  Future<void> initialize();
  Future<void> play();
  Future<void> pause();

  /// 0 (muted) or 1.
  Future<void> setVolume(double volume);

  /// The picture at its own size.
  Widget buildView();
  Future<void> dispose();
}

/// [InlineVideoController] on the official `video_player` plugin
/// (ExoPlayer on Android, AVPlayer on iOS). It mixes with the person's own
/// audio while muted.
class VideoPlayerInlineVideo implements InlineVideoController {
  new(String url)
    : _controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

  final VideoPlayerController _controller;

  @override
  InlineVideoState get state {
    final v = _controller.value;
    return InlineVideoState(
      initialized: v.isInitialized,
      playing: v.isPlaying,
      buffering: v.isBuffering,
      failed: v.hasError,
      position: v.position,
      duration: v.duration,
      size: v.size,
    );
  }

  @override
  Future<void> initialize() async {
    await _controller.initialize();
    await _controller.setLooping(true);
  }

  @override
  Future<void> play() => _controller.play();

  @override
  Future<void> pause() => _controller.pause();

  @override
  Future<void> setVolume(double volume) => _controller.setVolume(volume);

  @override
  Widget buildView() => VideoPlayer(_controller);

  @override
  Future<void> dispose() => _controller.dispose();

  @override
  void addListener(VoidCallback listener) => _controller.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);
}

/// Makes the player of a video URL (tests override it).
final Provider<InlineVideoController Function(String url)>
inlineVideoFactoryProvider =
    Provider<InlineVideoController Function(String url)>(
      (ref) => VideoPlayerInlineVideo.new,
    );

/// Whether videos play muted (every video starts muted; the speaker button
/// turns sound on for this one and the next ones, until turned off).
class VideoMuted extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final videoMutedProvider = NotifierProvider<VideoMuted, bool>(VideoMuted.new);

/// A video over its poster: until it plays, the poster ([poster]) with the
/// play mark; a tap plays or pauses; the speaker button (end corner) mutes
/// or unmutes. It loops, starts muted, plays only while at least half of it
/// is on screen and, with [autoplay], starts by itself when it is (the
/// reels pager passes the current page). Loading shows a spinner; a video
/// that can't play says so over the poster (no fake frames).
class InlineVideo extends ConsumerStatefulWidget {
  const new({
    required this.url,
    required this.poster,
    this.autoplay = false,
    this.fit = BoxFit.cover,
    this.onDoubleTap,
    this.muteOnTop = false,
    super.key,
  });

  /// The speaker button in the top end corner (a reel: the rail holds the
  /// bottom end); otherwise the bottom end corner.
  final bool muteOnTop;

  final String url;
  final ImageProvider? poster;
  final bool autoplay;
  final BoxFit fit;
  final VoidCallback? onDoubleTap;

  static const playKey = Key('video.play');
  static const muteKey = Key('video.mute');
  static const errorKey = Key('video.error');
  static const loadingKey = Key('video.loading');
  static const surfaceKey = Key('video.surface');

  @override
  ConsumerState<InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends ConsumerState<InlineVideo> {
  InlineVideoController? _video;

  /// How much of the video is on screen (0–1).
  double _fraction = 0;
  bool _wantPlay = false;

  /// Started by a tap: plays while any of it is on screen (autoplay needs
  /// at least half).
  bool _tapped = false;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _wantPlay = widget.autoplay;
  }

  @override
  void didUpdateWidget(InlineVideo old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      unawaited(_release());
      _failed = false;
    }
    if (old.autoplay != widget.autoplay) {
      _wantPlay = widget.autoplay;
      unawaited(_sync());
    }
  }

  @override
  void dispose() {
    unawaited(_release());
    super.dispose();
  }

  Future<void> _release() async {
    final video = _video;
    _video = null;
    if (video == null) return;
    video.removeListener(_changed);
    await video.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (_video?.state.failed ?? false) _failed = true;
    setState(() {});
  }

  Future<InlineVideoController?> _open() async {
    if (_video case final v?) return v;
    if (_loading || _failed) return null;
    setState(() => _loading = true);
    final video = ref.read(inlineVideoFactoryProvider)(widget.url);
    try {
      await video.initialize();
      await video.setVolume(ref.read(videoMutedProvider) ? 0 : 1);
    } on Object {
      unawaited(video.dispose());
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
      return null;
    }
    if (!mounted) {
      unawaited(video.dispose());
      return null;
    }
    video.addListener(_changed);
    setState(() {
      _video = video;
      _loading = false;
    });
    return video;
  }

  bool get _canPlay => _tapped ? _fraction > 0 : _fraction >= 0.5;

  /// Plays when wanted and on screen; pauses otherwise.
  Future<void> _sync() async {
    if (_wantPlay && _canPlay) {
      final video = await _open();
      if (video == null || !mounted) return;
      if (_wantPlay && _canPlay && !video.state.playing) await video.play();
    } else if (_video case final v? when v.state.playing) {
      await v.pause();
    }
  }

  void _toggle() {
    if (_failed) return;
    _wantPlay = !(_video?.state.playing ?? false);
    _tapped = true;
    unawaited(_sync());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final muted = ref.watch(videoMutedProvider);
    ref.listen(videoMutedProvider, (_, next) {
      unawaited(_video?.setVolume(next ? 0 : 1));
    });
    final video = _video;
    final state = video?.state;
    final started =
        state != null &&
        state.initialized &&
        (state.playing || state.position > Duration.zero);
    final white = KPalette.dark.textPrimary;
    return VisibilityDetector(
      key: ValueKey('video.visibility.${widget.url}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        _fraction = info.visibleFraction;
        if (_fraction == 0) {
          // Off screen: a tapped video waits for another tap; a reel
          // follows its page.
          _tapped = false;
          _wantPlay = widget.autoplay;
        }
        unawaited(_sync());
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: KPalette.dark.surfaceRaised,
            child: switch (widget.poster) {
              final poster? => Image(
                image: poster,
                fit: widget.fit,
                gaplessPlayback: true,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.expand(),
              ),
              null => null,
            },
          ),
          if (started && video != null)
            FittedBox(
              key: InlineVideo.surfaceKey,
              fit: widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: 1080,
                height: 1080 / _aspect(video),
                child: video.buildView(),
              ),
            ),
          Semantics(
            button: true,
            label: _failed
                ? l10n.videoCannotPlay
                : (state?.playing ?? false)
                ? l10n.videoPause
                : l10n.videoPlay,
            onTap: _toggle,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              onDoubleTap: widget.onDoubleTap,
            ),
          ),
          if (_loading || (state?.buffering ?? false))
            Center(
              key: InlineVideo.loadingKey,
              child: SizedBox.square(
                dimension: 36,
                child: CircularProgressIndicator(strokeWidth: 3, color: white),
              ),
            )
          else if (_failed)
            IgnorePointer(
              child: Center(
                key: InlineVideo.errorKey,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.md,
                    vertical: KSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: KStatusColors.onStatus.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(KRadius.pill),
                  ),
                  child: Text(
                    l10n.videoCannotPlay,
                    style: context.textStyles.caption.copyWith(color: white),
                  ),
                ),
              ),
            )
          else if (!(state?.playing ?? false))
            const IgnorePointer(
              child: Center(child: VideoPlayMark(key: InlineVideo.playKey)),
            ),
          if (!_failed)
            PositionedDirectional(
              end: KSpacing.xs,
              top: widget.muteOnTop ? KSpacing.sm : null,
              bottom: widget.muteOnTop ? null : KSpacing.xs,
              child: IconButton(
                key: InlineVideo.muteKey,
                tooltip: muted ? l10n.videoUnmute : l10n.videoMute,
                onPressed: () => ref.read(videoMutedProvider.notifier).toggle(),
                style: IconButton.styleFrom(
                  backgroundColor: KStatusColors.onStatus.withValues(
                    alpha: 0.45,
                  ),
                ),
                icon: Icon(
                  muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _aspect(InlineVideoController video) {
    final size = video.state.size;
    // A vertical shape stands in until the player knows the size.
    return size.width <= 0 || size.height <= 0
        ? 9 / 16
        : size.width / size.height;
  }
}

/// The white disc with a play glyph over a video that is not playing.
class VideoPlayMark extends StatelessWidget {
  const new({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: KPalette.light.surfaceRaised.withValues(alpha: 0.92),
      shape: BoxShape.circle,
    ),
    child: Padding(
      // The triangle's optical centre sits left of its box.
      padding: const EdgeInsets.only(left: KSpacing.xxs),
      child: AppIcon(
        AppIcons.play,
        size: size * 0.45,
        color: KStatusColors.onStatus,
      ),
    ),
  );
}
