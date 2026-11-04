import 'dart:async';
import 'dart:ui' as ui;

import 'package:kabso_live/core/models/store_art.dart';
import 'package:kabso_live/features/live/data/gift_art_cache.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_video_effect.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

/// D270 (owner: store art may be an MP4 as well as an SVGA): plays a hosted
/// MP4 animation in its box — the gifts' D207 path: the file comes from the
/// gift art cache on the device, the gift video controller plays it muted
/// (looping, or [once] then [onDone]), a side-by-side one is composited by
/// the gift alpha shader ([GiftVideoView]) and skipped (the [still] stays)
/// where shader filters do not run. The [still] shows until the first frame,
/// when it cannot play, and with reduced motion (also for [once]: [onDone]
/// then follows at once). Never takes taps.
class ArtVideoPlayer extends StatefulWidget {
  const new({
    required this.url,
    required this.video,
    super.key,
    this.still,
    this.fit = BoxFit.contain,
    this.once = false,
    this.onDone,
  });

  final String url;
  final ArtVideo video;
  final Widget? still;
  final BoxFit fit;
  final bool once;
  final VoidCallback? onDone;

  @override
  State<ArtVideoPlayer> createState() => _ArtVideoPlayerState();
}

class _ArtVideoPlayerState extends State<ArtVideoPlayer> {
  VideoPlayerController? _video;
  ui.FragmentShader? _shader;
  bool _started = false;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _finishSoon();
      return;
    }
    unawaited(_load());
  }

  @override
  void didUpdateWidget(ArtVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.video != widget.video) {
      unawaited(_release());
      _done = false;
      unawaited(_load());
    }
  }

  void _finishSoon() {
    if (_done || !widget.once) return;
    _done = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone?.call();
    });
  }

  Future<void> _load() async {
    final url = widget.url;
    VideoPlayerController? video;
    ui.FragmentShader? shader;
    try {
      if (widget.video == ArtVideo.sideBySide) {
        final program = await GiftAlphaShader.load();
        // No compositing here: never a video with its mask beside it.
        if (program == null) return _finishSoon();
        shader = program.fragmentShader();
      }
      final path = await GiftArtCache.instance.path(url);
      if (!mounted || widget.url != url) {
        shader?.dispose();
        return;
      }
      video = giftVideoController(path);
      await video.initialize();
      await video.setVolume(0);
      await video.setLooping(!widget.once);
      if (!mounted || widget.url != url) {
        shader?.dispose();
        await video.dispose();
        return;
      }
      final controller = video;
      controller.addListener(() {
        final v = controller.value;
        if (v.hasError) {
          _finishSoon();
        } else if (widget.once &&
            v.isInitialized &&
            !v.isPlaying &&
            v.duration > Duration.zero &&
            v.position >= v.duration) {
          _finishSoon();
        }
      });
      setState(() {
        _video = controller;
        _shader = shader;
      });
      await controller.play();
    } on Object catch (e) {
      debugPrint('ArtVideoPlayer($url): $e');
      shader?.dispose();
      await video?.dispose();
      _finishSoon();
    }
  }

  Future<void> _release() async {
    final video = _video;
    final shader = _shader;
    _video = null;
    _shader = null;
    shader?.dispose();
    await video?.dispose();
  }

  @override
  void dispose() {
    unawaited(_release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _video;
    final still = widget.still ?? const SizedBox.shrink();
    if (video == null || !video.value.isInitialized) return still;
    final box = giftVideoViewBox(
      video.value.size,
      sideBySide: widget.video == ArtVideo.sideBySide,
    );
    return IgnorePointer(
      child: FittedBox(
        fit: widget.fit,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: box.width,
          height: box.height,
          child: GiftVideoView(controller: video, shader: _shader),
        ),
      ),
    );
  }
}
