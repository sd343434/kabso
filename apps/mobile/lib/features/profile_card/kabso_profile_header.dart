import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svga/flutter_svga.dart';
import 'package:material_ui/material_ui.dart';

/// The owner's profile-card header decorations (2026-10-26,
/// `assets/profile_card/`): an ornament that sits on the card's top edge
/// and loops (SVGA), with a still for tests and reduced motion.
enum KabsoProfileHeader {
  emeraldWings(
    'assets/profile_card/header_emerald_wings.svga',
    'assets/profile_card/header_emerald_wings_static.png',
    stillRatio: 247 / 750,
    stillBar: 201.5 / 247,
  );

  new(
    this.animation,
    this.still, {
    required this.stillRatio,
    required this.stillBar,
  });

  final String animation;
  final String still;

  /// The still's height ÷ width, and where its bar's line is (÷ height).
  final double stillRatio;
  final double stillBar;

  /// The SVGA canvas: 750 × 280. The bar's line is at 83.4 % of its height,
  /// measured on the rendered animation (2026-10-26); the 93.2 % in the
  /// owner's sample left the bar about 13 dp above the card's edge.
  static const double ratio = 280 / 750;
  static const bar = 0.834;

  /// How far the ornament rises above the card's top edge at [width].
  static double overhang(double width) => width * ratio * bar;
}

/// [header] drawn across [width], its bar's line [KabsoProfileHeader.
/// overhang] below the top: put it in a Stack so that line lies on the
/// card's top edge. It never takes taps.
class KabsoProfileHeaderArt extends StatefulWidget {
  const new(this.header, {required this.width, super.key});

  final KabsoProfileHeader header;
  final double width;

  /// Widget tests and goldens show the still (SVGA decoding runs outside
  /// fake time); set by `test/flutter_test_config.dart`.
  static bool animate = true;

  @override
  State<KabsoProfileHeaderArt> createState() => _KabsoProfileHeaderArtState();
}

class _KabsoProfileHeaderArtState extends State<KabsoProfileHeaderArt>
    with SingleTickerProviderStateMixin {
  static final Map<String, MovieEntity> _cache = {};

  late final SVGAAnimationController _controller = SVGAAnimationController(
    vsync: this,
  )..muted = true;
  bool _ready = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (KabsoProfileHeaderArt.animate &&
        !MediaQuery.disableAnimationsOf(context)) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final asset = widget.header.animation;
    try {
      var movie = _cache[asset];
      if (movie == null) {
        final bytes = await rootBundle.load(asset);
        movie = await SVGAParser.shared.decodeFromBuffer(
          bytes.buffer.asUint8List(),
        );
        _cache[asset] = movie..autorelease = false;
      }
      if (!mounted) return;
      _controller.videoItem = movie;
      _controller.repeat();
      setState(() => _ready = true);
    } on Object catch (e) {
      // A broken file keeps the still.
      debugPrint('KabsoProfileHeaderArt($asset): $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = w * KabsoProfileHeader.ratio;
    final line = KabsoProfileHeader.overhang(w);
    final header = widget.header;
    final stillHeight = w * header.stillRatio;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          width: w,
          height: h,
          child: _ready
              ? SVGAImage(
                  _controller,
                  fit: BoxFit.fill,
                  clearsAfterStop: false,
                  filterQuality: FilterQuality.medium,
                )
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: line - stillHeight * header.stillBar,
                      height: stillHeight,
                      child: Image.asset(header.still, fit: BoxFit.fill),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
