import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Shared parts of the wallet page (D177): the two currency tabs, the warm
/// balance card, the white section card and the big gradient pill.

/// The wallet's two tabs, each centred in half of the width (the
/// reference's layout); the selected one is bold with a short Kabso-red
/// dash under it.
class WalletTabs extends StatelessWidget {
  const new({
    required this.labels,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  static Key tabKey(int i) => Key('wallet.tab.$i');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Row(
      children: [
        for (final (i, label) in labels.indexed)
          Expanded(
            child: Semantics(
              key: tabKey(i),
              button: true,
              selected: i == selected,
              label: label,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => onSelected(i),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.xs,
                      vertical: KSpacing.sm,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: t.title.copyWith(
                            fontSize: 17,
                            color: i == selected
                                ? p.textPrimary
                                : p.textTertiary,
                            fontWeight: i == selected
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: KSpacing.xs),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 8,
                          height: 3,
                          decoration: BoxDecoration(
                            color: i == selected
                                ? p.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(KRadius.pill),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The warm balance card: [icon] and a big [amount] on the first line,
/// [label] under it, an optional [action] at the top end and optional
/// [footer] lines. [tint] is the accent blended into the card (gold for
/// coins, Kabso red for cherries) over the raised surface.
class WalletBalanceCard extends StatelessWidget {
  const new({
    required this.icon,
    required this.amount,
    required this.label,
    required this.semanticsLabel,
    required this.tint,
    super.key,
    this.action,
    this.footer,
    this.tintStrength = 0.12,
  });

  final Widget icon;

  /// How much of [tint] warms the card's bottom-end colour.
  final double tintStrength;

  /// The number, a skeleton while loading, or "–" after a failure.
  final Widget amount;
  final String label;
  final String semanticsLabel;
  final Color tint;
  final Widget? action;
  final Widget? footer;

  /// The warm label colour: AA on both ends of the card.
  static Color labelColor(BuildContext context) => context.palette.warning;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Container(
      constraints: const BoxConstraints(minHeight: 91),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            Color.alphaBlend(
              KBrandColors.gold.withValues(alpha: 0.22),
              p.surfaceRaised,
            ),
            // Peach: the Kabso gold, warmed by the tint (Kabso red for
            // both currencies; stronger on the cherry card).
            Color.alphaBlend(
              tint.withValues(alpha: tintStrength),
              Color.alphaBlend(
                KBrandColors.gold.withValues(alpha: 0.35),
                p.surfaceRaised,
              ),
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(KRadius.lg),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KSpacing.lg,
              KSpacing.lg,
              56,
              KSpacing.lg,
            ),
            child: Semantics(
              container: true,
              label: semanticsLabel,
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      icon,
                      const SizedBox(width: KSpacing.sm),
                      Flexible(child: amount),
                    ],
                  ),
                  const SizedBox(height: KSpacing.xs),
                  Text(
                    label,
                    style: t.bodyStrong.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      color: labelColor(context),
                    ),
                  ),
                  if (footer case final f?) ...[
                    const SizedBox(height: KSpacing.sm),
                    f,
                  ],
                ],
              ),
            ),
          ),
          if (action case final a?)
            PositionedDirectional(top: KSpacing.sm, end: KSpacing.sm, child: a),
        ],
      ),
    );
  }
}

/// The big number of a balance card (FittedBox: never clips at 360 dp or
/// a large text size).
class WalletBigNumber extends StatelessWidget {
  const new(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      text,
      maxLines: 1,
      textDirection: TextDirection.ltr,
      style: context.textStyles.title.copyWith(
        color: context.palette.textPrimary,
        fontSize: 34,
        height: 1.1,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

/// The round history button at the top end of a balance card.
class WalletCardButton extends StatelessWidget {
  const new({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onPressed,
          radius: 24,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.surfaceRaised.withValues(alpha: 0.6),
                ),
                child: SizedBox.square(
                  dimension: 34,
                  child: Icon(
                    icon,
                    size: 20,
                    color: WalletBalanceCard.labelColor(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A white (raised) rounded section with an optional [title] and a hairline
/// under it.
class WalletSection extends StatelessWidget {
  const new({required this.children, super.key, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title case final title?) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                KSpacing.lg,
                KSpacing.lg,
                KSpacing.md,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: t.title.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: p.border),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg - 5,
              KSpacing.md,
              KSpacing.lg - 5,
              KSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// The big Kabso-red gradient pill (the recharge and the withdraw buttons).
/// [available] false: dimmed, announced as disabled with [reason], the
/// reason shown under it, and a tap only repeats the reason — nothing is
/// bought or paid (B5, D149).
class WalletPill extends StatelessWidget {
  const new({
    required this.title,
    required this.semanticsLabel,
    required this.available,
    required this.reason,
    super.key,
    this.subtitle,
    this.onPressed,
  });

  final Widget title;
  final String? subtitle;
  final String semanticsLabel;
  final bool available;
  final String reason;
  final VoidCallback? onPressed;

  static const reasonKey = Key('wallet.pill.reason');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    void explain() {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(reason)));
    }

    final sub = subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          button: true,
          enabled: available,
          label: available
              ? semanticsLabel
              : context.l10n.meHubSoonItem(semanticsLabel),
          hint: available ? null : reason,
          excludeSemantics: true,
          child: Opacity(
            opacity: available ? 1 : 0.55,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: AlignmentDirectional.centerStart,
                  end: AlignmentDirectional.centerEnd,
                  colors: [KBrandColors.red400, KBrandColors.red500],
                ),
                borderRadius: BorderRadius.circular(KRadius.pill),
              ),
              child: Material(
                type: MaterialType.transparency,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: available ? onPressed : explain,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.lg,
                        vertical: KSpacing.xs + 1,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DefaultTextStyle.merge(
                            style: t.title.copyWith(
                              color: Colors.white,
                              fontSize: 18,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                            ),
                            child: title,
                          ),
                          if (sub != null)
                            Text(
                              sub,
                              textAlign: TextAlign.center,
                              style: t.label.copyWith(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 14,
                                height: 1.2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!available) ...[
          const SizedBox(height: KSpacing.xs),
          ExcludeSemantics(
            child: Text(
              reason,
              key: reasonKey,
              textAlign: TextAlign.center,
              style: t.caption.copyWith(color: p.textTertiary),
            ),
          ),
        ],
      ],
    );
  }
}

/// One piece of a [WalletSection] built as separate list children (a paged
/// list: its rows must stay lazy, so they cannot sit in one Column). [title]
/// makes it the section's top with a hairline; [bottom] rounds its lower
/// corners.
class WalletSectionPiece extends StatelessWidget {
  const new({super.key, this.title, this.child, this.bottom = false});

  final String? title;
  final Widget? child;
  final bool bottom;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    const r = Radius.circular(KRadius.lg);
    final title = this.title;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.only(
          topLeft: title != null ? r : Radius.zero,
          topRight: title != null ? r : Radius.zero,
          bottomLeft: bottom ? r : Radius.zero,
          bottomRight: bottom ? r : Radius.zero,
        ),
      ),
      child: title != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KSpacing.lg,
                    KSpacing.lg,
                    KSpacing.lg,
                    KSpacing.md,
                  ),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: t.title.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ),
                Divider(height: 1, thickness: 1, color: p.border),
              ],
            )
          : Padding(
              padding: EdgeInsets.fromLTRB(
                KSpacing.lg,
                0,
                KSpacing.lg,
                bottom ? KSpacing.md : 0,
              ),
              child: child,
            ),
    );
  }
}
