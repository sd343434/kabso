import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D134 (owner): the host's currency, the Kab Cherry «الكرز» — everything a
/// host earns (a live's points, ranking and popularity points, the room
/// score, contributions to a host, the end-of-live points). What people
/// spend (the wallet, gift prices) keeps the coin.
///
/// D182 (owner: «use the new cherry and coin icons I sent»): one art file at
/// every size, the owner's new cherry ([KabsoArt.cherry], 256 px,
/// `assets/currency/PROVENANCE.md`) — the same set as the Kabi coin. The
/// D134 art and its SVGA loop (the old cherry) are retired.
class KCherryIcon extends StatelessWidget {
  const new({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    KabsoArt.cherry.asset,
    width: size,
    height: size,
    excludeFromSemantics: true,
    // A missing file must not break the screen.
    errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
  );
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
