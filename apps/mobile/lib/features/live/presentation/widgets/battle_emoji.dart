import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svga/flutter_svga.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The owner's PK battle animations (D71): SVGA 2.0, 600×600, 30 fps,
/// 2.5 s, played once in the middle of the PK stage.
enum KabsoBattle {
  start('start'),
  win('win'),
  lose('lose'),
  draw('draw');

  new(this.id);

  final String id;

  String get asset => 'assets/battle/kabso_battle_$id.svga';

  /// What a screen reader announces when it plays.
  String label(AppLocalizations l10n) => switch (this) {
    start => l10n.pkBattleStart,
    win => l10n.pkWin,
    lose => l10n.pkLose,
    draw => l10n.pkDraw,
  };
}

/// Plays a [KabsoBattle] once, then calls [onDone]. Silent, and it never
/// takes taps. With reduced motion it shows one still frame for the same
/// time instead.
///
/// The file is read from the bundle and decoded directly: the player's
/// own asset loader would also copy it to a disk cache, which bundled
/// files do not need.
class KabsoBattleEmoji extends StatefulWidget {
  const new(this.battle, {super.key, this.size = 220, this.onDone});

  final KabsoBattle battle;
  final double size;
  final VoidCallback? onDone;

  /// The animations' length (75 frames at 30 fps).
  static const duration = Duration(milliseconds: 2500);

  /// Widget tests and goldens keep the space and the announcement but skip
  /// decoding (it runs outside fake time and would make goldens
  /// timing-dependent); set by `test/flutter_test_config.dart`.
  static bool enabled = true;

  @override
  State<KabsoBattleEmoji> createState() => _KabsoBattleEmojiState();
}

class _KabsoBattleEmojiState extends State<KabsoBattleEmoji>
    with SingleTickerProviderStateMixin {
  late final SVGAAnimationController _controller = SVGAAnimationController(
    vsync: this,
  )..muted = true;
  var _started = false;
  Timer? _hold;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_play());
  }

  @override
  void didUpdateWidget(KabsoBattleEmoji old) {
    super.didUpdateWidget(old);
    if (old.battle != widget.battle) unawaited(_play());
  }

  Future<void> _play() async {
    if (!KabsoBattleEmoji.enabled) return;
    final still = MediaQuery.disableAnimationsOf(context);
    try {
      final bytes = await rootBundle.load(widget.battle.asset);
      final movie = await SVGAParser.shared.decodeFromBuffer(
        bytes.buffer.asUint8List(),
      );
      if (!mounted) return;
      _controller.videoItem = movie;
      if (still) {
        // The peak of the animation, held for its length.
        _controller.value = 0.6;
        final held = Completer<void>();
        _hold = Timer(KabsoBattleEmoji.duration, held.complete);
        await held.future;
      } else {
        _controller.reset();
        await _controller.forward();
      }
    } on Object catch (e) {
      // A missing or broken file must not break the room: skip it.
      debugPrint('KabsoBattleEmoji(${widget.battle.id}): $e');
    }
    if (mounted) widget.onDone?.call();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: widget.battle.label(context.l10n),
    excludeSemantics: true,
    child: IgnorePointer(
      child: SizedBox.square(
        dimension: widget.size,
        child: SVGAImage(_controller, clearsAfterStop: false),
      ),
    ),
  );
}
