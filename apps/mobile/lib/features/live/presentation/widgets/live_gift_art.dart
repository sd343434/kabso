import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svga/flutter_svga.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:material_ui/material_ui.dart';

/// Where the owner's gift files go (CP-020, assets/gifts/PROVENANCE.md):
/// the server's `assetKey` / `animationKey` name them. Keys outside the
/// contract's pattern (or climbing up with `..`) name nothing.
abstract final class KGiftAssets {
  static final _key = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_./-]{0,79}$');

  static bool _valid(String key) => _key.hasMatch(key) && !key.contains('..');

  /// The static image of `assetKey`, or null for a key the app refuses.
  static String? image(String assetKey) =>
      _valid(assetKey) ? 'assets/gifts/$assetKey.png' : null;

  /// The SVGA effect of `animationKey`, or null.
  static String? animation(String? animationKey) =>
      animationKey != null && _valid(animationKey)
      ? 'assets/gifts/anim/$animationKey.svga'
      : null;
}

/// A gift's static image at [size] (square). While the owner's art is not
/// in the app (or a key names no file) it shows Kabso's gift box, faded —
/// never an error. Decorative: the caller labels it.
class KGiftImage extends StatelessWidget {
  const new(this.assetKey, {super.key, this.size = 48});

  final String assetKey;
  final double size;

  /// The fallback, for tests.
  static const fallbackKey = Key('gift.image.fallback');

  @override
  Widget build(BuildContext context) {
    final fallback = Opacity(
      key: fallbackKey,
      opacity: 0.45,
      child: Image.asset(
        KabsoArt.giftBox.asset,
        width: size,
        height: size,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
      ),
    );
    final path = KGiftAssets.image(assetKey);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: path == null
            ? fallback
            : Image.asset(
                path,
                width: size,
                height: size,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// The large centred effect of a big gift: the owner's SVGA when the app
/// has it ([animationKey]), else the image growing in and fading out over
/// [duration]. With reduced motion the image just shows. Never takes taps.
///
/// The SVGA is read from the bundle and decoded directly (like
/// `KabsoBattleEmoji`); a missing or broken file keeps the image.
class KGiftEffect extends StatefulWidget {
  const new({
    required this.assetKey,
    required this.animationKey,
    required this.duration,
    super.key,
    this.size = 220,
  });

  final String assetKey;
  final String? animationKey;
  final Duration duration;
  final double size;

  /// Widget tests and goldens skip SVGA decoding (it runs outside fake
  /// time); set by `test/flutter_test_config.dart`.
  static bool animate = true;

  @override
  State<KGiftEffect> createState() => _KGiftEffectState();
}

class _KGiftEffectState extends State<KGiftEffect>
    with TickerProviderStateMixin {
  late final AnimationController _still = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  SVGAAnimationController? _svga;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _still.value = 0.5;
    } else {
      _still.forward();
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    final path = KGiftAssets.animation(widget.animationKey);
    if (!KGiftEffect.animate || path == null) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    try {
      final bytes = await rootBundle.load(path);
      final movie = await SVGAParser.shared.decodeFromBuffer(
        bytes.buffer.asUint8List(),
      );
      if (!mounted) return;
      final svga = SVGAAnimationController(vsync: this)
        ..muted = true
        ..videoItem = movie;
      setState(() => _svga = svga);
      await svga.forward();
    } on Object catch (e) {
      // No file yet, or a broken one: the image plays instead.
      debugPrint('KGiftEffect(${widget.animationKey}): $e');
    }
  }

  @override
  void dispose() {
    _still.dispose();
    _svga?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svga = _svga;
    return IgnorePointer(
      child: SizedBox.square(
        dimension: widget.size,
        child: svga != null
            ? SVGAImage(svga)
            : AnimatedBuilder(
                animation: _still,
                builder: (context, child) {
                  final t = _still.value;
                  // Grow in (first quarter), hold, fade out (last fifth).
                  final scale = t < 0.25
                      ? 0.5 + Curves.easeOutBack.transform(t / 0.25) * 0.5
                      : 1.0;
                  final opacity = t < 0.15
                      ? t / 0.15
                      : t > 0.8
                      ? (1 - t) / 0.2
                      : 1.0;
                  return Opacity(
                    opacity: opacity.clamp(0, 1),
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                child: KGiftImage(widget.assetKey, size: widget.size * 0.8),
              ),
      ),
    );
  }
}
