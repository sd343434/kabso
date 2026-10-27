import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D134 (owner): the host's currency, the Kab Cherry «الكرز» — everything a
/// host earns (a live's points, ranking and popularity points, the room
/// score, contributions to a host, the end-of-live points). What people
/// spend (the wallet, gift prices) keeps the coin.
///
/// The owner's art (`assets/currency/`, PROVENANCE.md), chosen by the
/// owner's size buckets: ≤ 26 the 48 px art, ≤ 34 the bold small art,
/// ≤ 48 the 128 px, ≤ 96 the 256 px, else the 512 px. [animated] plays
/// the owner's SVGA loop (sway, shine, sparkles) with the app's pinned
/// `flutter_svga`; it shows the still art while it loads, with reduce
/// motion, and in widget tests ([animate]).
class KCherryIcon extends StatelessWidget {
  const new({super.key, this.size = 20, this.animated = false});

  final double size;
  final bool animated;

  /// Off in widget tests and goldens (decoding runs outside fake time).
  static bool animate = true;

  static const _dir = 'assets/currency/';

  /// The art file for [size] (the owner's buckets).
  static String assetFor(double size) => switch (size) {
    <= 26 => '${_dir}kab_cherry_48.png',
    <= 34 => '${_dir}kab_cherry_small.png',
    <= 48 => '${_dir}kab_cherry_128.png',
    <= 96 => '${_dir}kab_cherry_256.png',
    _ => '${_dir}kab_cherry_512.png',
  };

  @override
  Widget build(BuildContext context) {
    final still = Image.asset(
      assetFor(size),
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
    if (!animated || !animate || MediaQuery.disableAnimationsOf(context)) {
      return still;
    }
    return SizedBox.square(
      dimension: size,
      child: _CherrySvga(still: still),
    );
  }
}

class _CherrySvga extends StatefulWidget {
  const new({required this.still});

  final Widget still;

  @override
  State<_CherrySvga> createState() => _CherrySvgaState();
}

class _CherrySvgaState extends State<_CherrySvga>
    with SingleTickerProviderStateMixin {
  static MovieEntity? _movie;
  SVGAAnimationController? _controller;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final movie = (_movie ??= await SVGAParser.shared.decodeFromBuffer(
        (await rootBundle.load('${KCherryIcon._dir}kab_cherry.svga')).buffer
            .asUint8List(),
      ))..autorelease = false;
      if (!mounted) return;
      final controller = SVGAAnimationController(vsync: this)
        ..videoItem = movie;
      setState(() => _controller = controller);
      controller.repeat();
    } on Object {
      // The still art stays.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => switch (_controller) {
    final c? => SVGAImage(c),
    null => widget.still,
  };
}

/// The cherry and an amount (host-earned points), the number formatted by
/// [KFormat] ([compact] or grouped) and isolated for mixed-direction text.
class KCherryAmount extends StatelessWidget {
  const new(
    this.amount, {
    super.key,
    this.size = 16,
    this.style,
    this.gap = KSpacing.xs,
    this.compact = false,
    this.formatted,
  });

  final int amount;
  final double size;
  final double gap;
  final TextStyle? style;

  /// Short form ("12.3K") instead of grouped digits.
  final bool compact;

  /// A ready string (e.g. a localized compact form); wins over [compact].
  final String? formatted;

  @override
  Widget build(BuildContext context) {
    final text =
        formatted ??
        (compact
            ? KFormat.compact(amount, context.l10n)
            : KFormat.grouped(amount));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KCherryIcon(size: size),
        SizedBox(width: gap),
        Flexible(
          child: Text(
            KFormat.bidiIsolate(text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
