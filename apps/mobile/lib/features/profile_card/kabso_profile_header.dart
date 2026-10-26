import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svga/flutter_svga.dart';
import 'package:material_ui/material_ui.dart';

/// The owner's profile-card header decorations (2026-10-26,
/// `assets/profile_card/`): an ornament that sits on the card's top edge
/// and loops (SVGA, canvas 750 × 280). [code] is the bag item's code
/// (PROFILE_CARD, CP-019). Royal Bunny is every new account's free one.
enum KabsoProfileHeader {
  bunnyRoyal('bunny_royal', 'assets/profile_card/header_bunny_royal.svga'),
  kabiRoyal('kabi_royal', 'assets/profile_card/header_kabi_royal.svga'),
  goldenStags('golden_stags', 'assets/profile_card/header_golden_stags.svga'),
  emeraldWings(
    'emerald_wings',
    'assets/profile_card/header_emerald_wings.svga',
    // Measured on the rendered animation (2026-10-26).
    bar: 0.834,
    still: (
      asset: 'assets/profile_card/header_emerald_wings_static.png',
      ratio: 247 / 750,
      bar: 201.5 / 247,
    ),
  );

  new(this.code, this.animation, {this.bar = 230 / 280, this.still});

  final String code;
  final String animation;

  /// Where the gold bar's line is, as a fraction of the canvas height (the
  /// owner: y = 230 of 280 for every header).
  final double bar;

  /// A still for tests and reduced motion: its height ÷ width and its bar's
  /// line (÷ height). Without one, reduced motion shows the first frame.
  final ({String asset, double ratio, double bar})? still;

  /// The SVGA canvas: height ÷ width.
  static const double ratio = 280 / 750;

  /// The header with the bag item [code], if the app knows it.
  static KabsoProfileHeader? byCode(String? code) =>
      values.where((h) => h.code == code).firstOrNull;

  /// How far the ornament rises above the card's top edge at [width].
  double overhang(double width) => width * ratio * bar;
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
    if (!KabsoProfileHeaderArt.animate) return;
    final still = MediaQuery.disableAnimationsOf(context);
    // Reduced motion: the still, or the first frame when there is none.
    if (!still || widget.header.still == null) {
      unawaited(_load(play: !still));
    }
  }

  Future<void> _load({required bool play}) async {
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
      if (play) _controller.repeat();
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
    final header = widget.header;
    final still = header.still;
    final Widget child;
    if (_ready) {
      child = SVGAImage(
        _controller,
        fit: BoxFit.fill,
        clearsAfterStop: false,
        filterQuality: FilterQuality.medium,
      );
    } else if (still != null) {
      final stillHeight = w * still.ratio;
      child = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: header.overhang(w) - stillHeight * still.bar,
            height: stillHeight,
            child: Image.asset(still.asset, fit: BoxFit.fill),
          ),
        ],
      );
    } else {
      child = const SizedBox.shrink();
    }
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          width: w,
          height: w * KabsoProfileHeader.ratio,
          child: child,
        ),
      ),
    );
  }
}
