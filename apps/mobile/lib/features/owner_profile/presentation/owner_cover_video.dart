import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/media/inline_video.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/profile/profile_cover_header.dart'
    show KPublicProfile;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// How a cover video's poster is loaded (the layer and the owner's edit
/// page); tests swap in a [MemoryImage].
ImageProvider Function(String src) ownerPosterImageFor = NetworkImage.new;

/// v1.95-social (D301, §10.112.1; owner: «فيديو الغلاف» of mock-up 4
/// «المسرح»): the owner's cover as a short looping video — the language's
/// video ([OwnerCoverVideo.pick]: the app's Arabic → Arabic, else English;
/// one → that one), over its poster, with the cover's shades again on top
/// (the name block stays legible) and, under the top bar at the reading
/// end (above the name block), the «فيديو» pill (its length) and the mute
/// button.
///
/// Muted by default and looping; it plays only while at least half of it is
/// on screen and the app is in the foreground (paused off-screen, under
/// another page or in the background). With the system's reduce-motion
/// setting it never starts by itself: the poster stays and the pill plays
/// it. The app has no data-saver setting (none to respect).
class OwnerCoverVideoLayer extends ConsumerStatefulWidget {
  const new({required this.video, super.key});

  final CoverVideoVariant video;

  static const layerKey = Key('owner.coverVideo');
  static const posterKey = Key('owner.coverVideo.poster');
  static const surfaceKey = Key('owner.coverVideo.surface');
  static const pillKey = Key('owner.coverVideo.pill');
  static const muteKey = Key('owner.coverVideo.mute');

  @override
  ConsumerState<OwnerCoverVideoLayer> createState() =>
      _OwnerCoverVideoLayerState();
}

class _OwnerCoverVideoLayerState extends ConsumerState<OwnerCoverVideoLayer> {
  InlineVideoController? _video;
  AppLifecycleListener? _life;
  double _fraction = 0;
  bool _foreground = true;
  bool _muted = true;
  bool _loading = false;
  bool _failed = false;

  /// Reduce motion: started only by a tap on the pill.
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(
      onStateChange: (state) {
        _foreground = state == AppLifecycleState.resumed;
        unawaited(_sync());
      },
    );
  }

  @override
  void didUpdateWidget(OwnerCoverVideoLayer old) {
    super.didUpdateWidget(old);
    if (old.video.url != widget.video.url) {
      unawaited(_release());
      _failed = false;
      unawaited(_sync());
    }
  }

  @override
  void dispose() {
    _life?.dispose();
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

  bool get _still => MediaQuery.disableAnimationsOf(context);

  bool get _wanted =>
      _foreground && _fraction >= 0.5 && (!_still || _tapped) && !_failed;

  Future<void> _sync() async {
    if (!mounted) return;
    if (_wanted) {
      final video = await _open();
      if (video == null || !mounted) return;
      if (_wanted && !video.state.playing) await video.play();
    } else if (_video case final v? when v.state.playing) {
      await v.pause();
    }
  }

  Future<InlineVideoController?> _open() async {
    if (_video case final v?) return v;
    if (_loading || _failed) return null;
    setState(() => _loading = true);
    final video = ref.read(inlineVideoFactoryProvider)(widget.video.url);
    try {
      await video.initialize();
      await video.setVolume(_muted ? 0 : 1);
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

  void _toggleMute() {
    setState(() => _muted = !_muted);
    unawaited(_video?.setVolume(_muted ? 0 : 1));
  }

  void _togglePlay() {
    final playing = _video?.state.playing ?? false;
    _tapped = !playing;
    if (playing) {
      unawaited(_video?.pause());
      setState(() {});
    } else {
      unawaited(_sync());
    }
  }

  static String _length(int ms) {
    final s = (ms / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    final video = _video;
    final state = video?.state;
    final started =
        state != null &&
        state.initialized &&
        (state.playing || state.position > Duration.zero);
    final playing = state?.playing ?? false;
    const white = Color(0xFFFFFFFF);
    final size = state?.size ?? Size.zero;
    final aspect = size.width > 0 && size.height > 0
        ? size.width / size.height
        : (widget.video.width > 0 && widget.video.height > 0
              ? widget.video.width / widget.video.height
              : 9 / 16);
    return VisibilityDetector(
      key: ValueKey('owner.coverVideo.visibility.${widget.video.url}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        _fraction = info.visibleFraction;
        if (_fraction == 0) _tapped = false;
        unawaited(_sync());
      },
      child: Stack(
        key: OwnerCoverVideoLayer.layerKey,
        fit: StackFit.expand,
        children: [
          Image(
            key: OwnerCoverVideoLayer.posterKey,
            image: ownerPosterImageFor(widget.video.posterUrl),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          if (started && video != null)
            FittedBox(
              key: OwnerCoverVideoLayer.surfaceKey,
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: 1080,
                height: 1080 / aspect,
                child: video.buildView(),
              ),
            ),
          // The cover's own shades again, over the video (D299: the white
          // @username in the bar and the name block stay legible).
          const Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: KPublicProfile.topShadeShare,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [KPublicProfile.topShade, Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: KPublicProfile.scrimShare,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      KPublicProfile.scrimBottom,
                      KPublicProfile.scrimMiddle,
                      Color(0x00000000),
                    ],
                    stops: [0, 0.5, 1],
                  ),
                ),
              ),
            ),
          ),
          // Under the bar, at the reading end: «فيديو» and the sound.
          PositionedDirectional(
            // The page's top padding is the status bar and the bar
            // (`extendBodyBehindAppBar`): just under the bar, above the
            // name block.
            top: media.padding.top + KSpacing.xs,
            end: KSpacing.md,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  button: true,
                  label: playing
                      ? l10n.ownerCoverVideoPause
                      : l10n.ownerCoverVideoPlay,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: OwnerCoverVideoLayer.pillKey,
                    onTap: _togglePlay,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0x8C000000),
                        borderRadius: BorderRadius.circular(KRadius.pill),
                        border: Border.all(color: const Color(0x33FFFFFF)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KSpacing.sm,
                          vertical: KSpacing.xs,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_loading)
                              const SizedBox.square(
                                dimension: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: white,
                                ),
                              )
                            else
                              Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 16,
                                color: white,
                              ),
                            const SizedBox(width: KSpacing.xxs),
                            Text(
                              l10n.ownerCoverVideoPill,
                              style: context.textStyles.caption.copyWith(
                                color: white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: KSpacing.xs),
                            Text(
                              _length(widget.video.durationMs),
                              textDirection: TextDirection.ltr,
                              style: context.textStyles.caption.copyWith(
                                color: const Color(0xD9FFFFFF),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: KSpacing.xs),
                Semantics(
                  button: true,
                  label: _muted
                      ? l10n.ownerCoverVideoUnmute
                      : l10n.ownerCoverVideoMute,
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: OwnerCoverVideoLayer.muteKey,
                    onTap: _toggleMute,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0x8C000000),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x33FFFFFF)),
                      ),
                      child: Icon(
                        _muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        size: 18,
                        color: white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
