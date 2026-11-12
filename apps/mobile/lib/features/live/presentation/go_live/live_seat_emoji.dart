import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/emoji_panel.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/application/live_seat_emojis.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_vip_perks.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

/// D138: an emoji playing once on a seat — centred over the picture, about
/// 85 % of it (the character fills ~77 % of the Lottie canvas), above the
/// picture and its frame, under the name. One cycle, then a short fade and
/// [onDone]; with reduced motion the first frame shows for [stillTime]. A
/// new emoji on the same tile is a new widget (keyed by its id), so it
/// replaces this one and starts over.
class SeatEmojiBurst extends StatefulWidget {
  const new({
    required this.emoji,
    required this.onDone,
    required this.picture,
    super.key,
  });

  final KabsoEmoji emoji;
  final VoidCallback onDone;

  /// The picture's diameter on the tile.
  final double picture;

  /// The Lottie canvas over a [picture]-wide picture.
  static double canvasFor(double picture) => picture * 0.85 / 0.77;

  /// Reduced motion: the first frame stays this long.
  static const stillTime = Duration(milliseconds: 1500);

  /// The fade at the end.
  static const fadeTime = Duration(milliseconds: 220);

  static Key keyFor(int seat) => Key('seatEmoji.$seat');

  @override
  State<SeatEmojiBurst> createState() => _SeatEmojiBurstState();
}

class _SeatEmojiBurstState extends State<SeatEmojiBurst>
    with TickerProviderStateMixin {
  late final _play = AnimationController(vsync: this);
  late final _fade = AnimationController(
    vsync: this,
    duration: SeatEmojiBurst.fadeTime,
    value: 1,
  );
  Timer? _still;
  var _started = false;
  var _finished = false;

  @override
  void dispose() {
    _still?.cancel();
    _play.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _loaded(LottieComposition composition) {
    if (_started || !mounted) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _still = Timer(SeatEmojiBurst.stillTime, _end);
      return;
    }
    _play.duration = composition.duration;
    unawaited(_play.forward().whenComplete(_end));
  }

  void _end() {
    if (!mounted || _finished) return;
    _finished = true;
    unawaited(
      _fade.reverse().whenComplete(() {
        if (mounted) widget.onDone();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = SeatEmojiBurst.canvasFor(widget.picture);
    // Decorative: the seat says who sits there; an emoji per tap would
    // flood a screen reader.
    return IgnorePointer(
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: _fade,
          child: OverflowBox(
            maxWidth: size,
            maxHeight: size,
            child: Lottie.asset(
              widget.emoji.asset,
              controller: _play,
              width: size,
              height: size,
              fit: BoxFit.contain,
              frameRate: FrameRate.max,
              onLoaded: _loaded,
              errorBuilder: (_, _, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _end());
                return SizedBox.square(dimension: size);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// D138: the seat emojis of room [roomId] as the overlay of tile `i` (0 is
/// the host), for `AudioSeatRing.overlay`.
Widget? Function(int) seatEmojiOverlay(
  WidgetRef ref,
  String roomId, {
  required double picture,
}) {
  final playing = ref.watch(liveSeatEmojisProvider(roomId));
  return (i) {
    final show = playing[i];
    if (show == null) return null;
    final emoji = show.emoji;
    if (emoji == null) {
      // v1.132-social (D379): a VIP pack file.
      return VipSeatEmojiBurst(
        key: ValueKey('seatEmoji.$i.${show.id}'),
        art: show.vipArt!,
        picture: picture,
        onDone: () =>
            ref.read(liveSeatEmojisProvider(roomId).notifier).done(i, show.id),
      );
    }
    return SeatEmojiBurst(
      key: ValueKey('seatEmoji.$i.${show.id}'),
      emoji: emoji,
      picture: picture,
      onDone: () =>
          ref.read(liveSeatEmojisProvider(roomId).notifier).done(i, show.id),
    );
  };
}

/// D138: the sheet of the owner's packs (the shared [EmojiPanel], packs
/// only, ref 162's white panel); a tap closes it and plays the emoji on the
/// caller's tile [seat] for the room (shown at once; a refusal says why).
Future<void> showSeatEmojiSheet(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required int seat,
}) async {
  final picked = await showModalBottomSheet<Object>(
    context: context,
    backgroundColor: const Color(0xFFFFFFFF),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
    ),
    builder: (sheet) => SeatEmojiSheet(
      onPick: (e) => Navigator.pop(sheet, e),
      onVip: (n, art) => Navigator.pop(sheet, (n: n, art: art)),
    ),
  );
  if (picked == null || !context.mounted) return;
  final seatEmojis = ref.read(liveSeatEmojisProvider(roomId).notifier);
  final failure = switch (picked) {
    final KabsoEmoji e => await seatEmojis.send(seat: seat, emoji: e),
    (n: final int n, art: final String art) => await seatEmojis.sendVip(
      seat: seat,
      n: n,
      art: art,
    ),
    _ => null,
  };
  if (failure != null && context.mounted) {
    KSnack.error(context, failureMessage(context.l10n, failure));
  }
}

/// The content of [showSeatEmojiSheet].
class SeatEmojiSheet extends StatelessWidget {
  const new({required this.onPick, super.key, this.onVip});

  final ValueChanged<KabsoEmoji> onPick;

  /// v1.132-social (D379, §10.169.1): a holder's VIP pack file n (1 …).
  final void Function(int n, String art)? onVip;

  static const panelKey = Key('seatEmoji.panel');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              l10n.liveSeatEmoji,
              style: t.title.copyWith(color: EmojiPanelColors.live.ink),
            ),
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: Text(
              l10n.liveSeatEmojiHint,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: const Color(0xFF8A8D93)),
            ),
          ),
          if (onVip case final vip?) ...[
            const SizedBox(height: KSpacing.sm),
            LiveVipSeatEmojiRow(onPick: vip),
          ],
          EmojiPanel(
            key: panelKey,
            packsOnly: true,
            onEmoji: (_) {},
            onPack: onPick,
          ),
        ],
      ),
    );
  }
}

/// v1.132-social (D379, §10.169.1): a VIP pack file playing once on a seat
/// — the SVGA (or the picture) over the picture for [SeatEmojiBurst.stillTime]
/// and a fade, then [onDone].
class VipSeatEmojiBurst extends StatefulWidget {
  const new({
    required this.art,
    required this.picture,
    required this.onDone,
    super.key,
  });

  final String art;
  final double picture;
  final VoidCallback onDone;

  /// How long it shows (the owner's emoji cycle, about 2 s).
  static const showTime = Duration(seconds: 2);

  @override
  State<VipSeatEmojiBurst> createState() => _VipSeatEmojiBurstState();
}

class _VipSeatEmojiBurstState extends State<VipSeatEmojiBurst> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(VipSeatEmojiBurst.showTime, widget.onDone);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = SeatEmojiBurst.canvasFor(widget.picture);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: OverflowBox(
          maxWidth: size,
          maxHeight: size,
          child: SizedBox.square(
            dimension: size,
            child: VipSeatEmojiArt(art: widget.art),
          ),
        ),
      ),
    );
  }
}
