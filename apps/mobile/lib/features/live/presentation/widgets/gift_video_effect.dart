import 'dart:async';
import 'dart:ui' as ui;

import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

/// What a gift's full-screen effect plays (v1.46-live, D207, CONVENTIONS
/// §10.66): an SVGA (as before), an MP4 — a plain video played as is, or a
/// side-by-side alpha one composited by a shader — or only its MP3, or
/// nothing (the strip has shown the gift's picture).
enum GiftEffectKind { svga, mp4, mp4Alpha, soundOnly, none }

/// Decides [GiftEffectKind] from a gift's effect fields. A hosted
/// [animationUrl] wins over the bundled [hasBundledSvga] (D126); a format the
/// app does not know plays nothing (never an SVGA guess); an older API sends
/// no format: an SVGA. Without an effect, a hosted [audioUrl] plays alone.
GiftEffectKind giftEffectKind({
  required String? animationUrl,
  required GiftAnimationFormat? animationFormat,
  required GiftVideoAlpha? animationAlpha,
  required bool hasBundledSvga,
  required String? audioUrl,
}) {
  if (animationUrl != null) {
    return switch (animationFormat ?? GiftAnimationFormat.svga) {
      GiftAnimationFormat.svga => GiftEffectKind.svga,
      GiftAnimationFormat.mp4 =>
        animationAlpha == GiftVideoAlpha.sideBySide
            ? GiftEffectKind.mp4Alpha
            : GiftEffectKind.mp4,
      GiftAnimationFormat.unknown =>
        audioUrl != null ? GiftEffectKind.soundOnly : GiftEffectKind.none,
    };
  }
  if (hasBundledSvga) return GiftEffectKind.svga;
  return audioUrl != null ? GiftEffectKind.soundOnly : GiftEffectKind.none;
}

/// The side-by-side alpha shader (`shaders/gift_alpha_sbs.frag`), loaded
/// once. Null while it loads, when it fails, and where shader image filters
/// are not available (they need Impeller): the effect is then skipped and
/// the gift's picture (in the strip) is all that shows — never a black box.
abstract final class GiftAlphaShader {
  static ui.FragmentProgram? _program;
  static Future<ui.FragmentProgram?>? _loading;

  /// Whether this device can composite side-by-side alpha (tests replace
  /// it).
  @visibleForTesting
  static bool Function() supported = () =>
      ui.ImageFilter.isShaderFilterSupported;

  /// The program, or null when the device cannot use it.
  static Future<ui.FragmentProgram?> load() {
    if (!supported()) return Future.value();
    if (_program != null) return Future.value(_program);
    return _loading ??=
        ui.FragmentProgram.fromAsset('shaders/gift_alpha_sbs.frag')
            .then<ui.FragmentProgram?>(
              (p) => _program = p,
              onError: (Object e) {
                debugPrint('GiftAlphaShader: $e');
                _loading = null;
                return null;
              },
            );
  }
}

/// Makes the effect's video player from a file on the device (tests replace
/// it). Mixed with other audio (the live's audio and other apps keep
/// playing; on iOS the session's category is only upgraded, never changed).
VideoPlayerController Function(String path) giftVideoController = (path) =>
    VideoPlayerController.networkUrl(
      Uri.file(path),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

/// The video of an MP4 effect, drawn into its frame: a plain one as is; a
/// side-by-side one ([shader] set) laid out twice as wide as the frame and
/// composited by the shader (left colour, right alpha), the right half
/// clipped away. Never takes taps.
class GiftVideoView extends StatelessWidget {
  const new({required this.controller, super.key, this.shader});

  final VideoPlayerController controller;

  /// From [GiftAlphaShader]'s program, owned (and disposed) by the caller.
  final ui.FragmentShader? shader;

  @override
  Widget build(BuildContext context) {
    final video = VideoPlayer(controller);
    final p = shader;
    if (p == null) return IgnorePointer(child: video);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) => ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: box.maxWidth * 2,
            maxWidth: box.maxWidth * 2,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.shader(p),
              child: video,
            ),
          ),
        ),
      ),
    );
  }
}

/// The size an MP4 effect's frame shows: the video's own size, half as wide
/// when side by side (the right half is the alpha mask).
Size giftVideoViewBox(Size video, {required bool sideBySide}) =>
    sideBySide ? Size(video.width / 2, video.height) : video;
