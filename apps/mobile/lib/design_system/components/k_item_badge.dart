import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/models/item_badge.dart';
import 'package:kabso_live/design_system/components/k_badge_explainer.dart';
import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.79-live (D289, CONVENTIONS §10.102.1): a badge's fill, label colour and
/// (EXCLUSIVE) edge — one look in light and dark, since the pill sits on the
/// art, not on the page. The owner's four: offer red, new green, most wanted
/// gold, sound blue; the rest from the design tokens (violet and teal new).
@immutable
final class KItemBadgeStyle {
  const new(this.fill, this.ink, [this.edge]);

  factory of(ItemBadgeCode code) => switch (code) {
    ItemBadgeCode.limited => const KItemBadgeStyle(
      KBrandColors.red500,
      Color(0xFFFFFFFF),
    ),
    ItemBadgeCode.isNew => const KItemBadgeStyle(
      Color(0xFF137A43),
      Color(0xFFFFFFFF),
    ),
    ItemBadgeCode.seasonal => const KItemBadgeStyle(
      Color(0xFFF5A623),
      Color(0xFF0B0B0D),
    ),
    ItemBadgeCode.exclusive => const KItemBadgeStyle(
      Color(0xFF0B0B0D),
      KBrandColors.gold,
      KBrandColors.gold,
    ),
    ItemBadgeCode.mostWanted => const KItemBadgeStyle(
      KBrandColors.gold,
      Color(0xFF0B0B0D),
    ),
    ItemBadgeCode.featured => const KItemBadgeStyle(
      Color(0xFF7B4DFF),
      Color(0xFFFFFFFF),
    ),
    ItemBadgeCode.fullscreen => const KItemBadgeStyle(
      Color(0xFF00796B),
      Color(0xFFFFFFFF),
    ),
    ItemBadgeCode.sound => const KItemBadgeStyle(
      Color(0xFF1A64BF),
      Color(0xFFFFFFFF),
    ),
    ItemBadgeCode.noSound => const KItemBadgeStyle(
      Color(0xFF666671),
      Color(0xFFFFFFFF),
    ),
  };

  final Color fill;
  final Color ink;
  final Color? edge;
}

/// The badge's one icon (`assets/icons/badges/`, the same paths as the
/// panel's): hourglass, sparkle, calendar, crown, flame, diamond, expand,
/// speaker, muted speaker.
String itemBadgeIcon(ItemBadgeCode code) =>
    'assets/icons/badges/${switch (code) {
      ItemBadgeCode.limited => 'limited',
      ItemBadgeCode.isNew => 'new',
      ItemBadgeCode.seasonal => 'seasonal',
      ItemBadgeCode.exclusive => 'exclusive',
      ItemBadgeCode.mostWanted => 'most_wanted',
      ItemBadgeCode.featured => 'featured',
      ItemBadgeCode.fullscreen => 'fullscreen',
      ItemBadgeCode.sound => 'sound',
      ItemBadgeCode.noSound => 'no_sound',
    }}.svg';

/// The badge's name in the app's language.
String itemBadgeLabel(AppLocalizations l10n, ItemBadgeCode code) =>
    switch (code) {
      ItemBadgeCode.limited => l10n.itemBadgeLimited,
      ItemBadgeCode.isNew => l10n.itemBadgeNew,
      ItemBadgeCode.seasonal => l10n.itemBadgeSeasonal,
      ItemBadgeCode.exclusive => l10n.itemBadgeExclusive,
      ItemBadgeCode.mostWanted => l10n.itemBadgeMostWanted,
      ItemBadgeCode.featured => l10n.itemBadgeFeatured,
      ItemBadgeCode.fullscreen => l10n.itemBadgeFullscreen,
      ItemBadgeCode.sound => l10n.itemBadgeSound,
      ItemBadgeCode.noSound => l10n.itemBadgeNoSound,
    };

/// The sizes of a pill for one [height]: the icon, the label and the
/// paddings scale with it.
@immutable
final class _PillMetrics {
  const new(this.height);

  final double height;

  double get icon => height * 0.72;
  double get font => height * 0.6;
  double get padStart => height * 0.22;
  double get padEnd => height * 0.36;
  double get gap => height * 0.14;

  /// The label's text scale: the user's, but never taller than the pill.
  TextScaler scaler(BuildContext context) =>
      MediaQuery.textScalerOf(context)
          .clamp(maxScaleFactor: (height - 1) / (font * 1.2));
}

TextStyle _labelStyle(BuildContext context, _PillMetrics m, Color ink) =>
    context.textStyles.caption.copyWith(
      color: ink,
      fontSize: m.font,
      height: 1.2,
      letterSpacing: 0,
      fontWeight: FontWeight.w700,
    );

/// One badge: its icon and, unless [iconOnly], its name, on its colour.
/// The screen reader hears the name either way.
class KItemBadgePill extends StatelessWidget {
  const new(
    this.code, {
    super.key,
    this.height = 18,
    this.iconOnly = false,
    this.explain = true,
  });

  final ItemBadgeCode code;
  final double height;
  final bool iconOnly;

  /// D389: a tap shows what the badge is («شارة العنصر: جديد»).
  final bool explain;

  static Key keyOf(ItemBadgeCode code, {bool iconOnly = false}) =>
      Key('itemBadge.${code.wire}${iconOnly ? '.icon' : ''}');

  @override
  Widget build(BuildContext context) {
    final style = KItemBadgeStyle.of(code);
    final m = _PillMetrics(height);
    final name = itemBadgeLabel(context.l10n, code);
    return KBadgeExplainer(
      message: context.l10n.badgeExplainItem(name),
      enabled: explain,
      child: Semantics(
        label: name,
        container: true,
        child: ExcludeSemantics(
          child: Container(
            key: keyOf(code, iconOnly: iconOnly),
            height: height,
            constraints: BoxConstraints(minWidth: height),
            padding: iconOnly
                ? EdgeInsets.zero
                : EdgeInsetsDirectional.only(start: m.padStart, end: m.padEnd),
            decoration: BoxDecoration(
              color: style.fill,
              borderRadius: BorderRadius.circular(height / 2),
              border: style.edge == null
                  ? null
                  : Border.all(color: style.edge!, width: height / 16),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(itemBadgeIcon(code), size: m.icon, color: style.ink),
                if (!iconOnly) ...[
                  SizedBox(width: m.gap),
                  Text(
                    name,
                    maxLines: 1,
                    softWrap: false,
                    textScaler: m.scaler(context),
                    style: _labelStyle(context, m, style.ink),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How the badges of a row are drawn in a width: names while they fit,
/// else the first with its name and the others as icons, else icons only,
/// else fewer icons. Exported for tests.
List<({ItemBadgeCode code, bool iconOnly})> fitItemBadges({
  required List<ItemBadgeCode> codes,
  required double maxWidth,
  required double height,
  required double Function(ItemBadgeCode code) labelWidth,
  double spacing = 2,
}) {
  final m = _PillMetrics(height);
  double pill(ItemBadgeCode c, {required bool icon}) =>
      icon ? height : m.padStart + m.icon + m.gap + labelWidth(c) + m.padEnd;
  double total(List<bool> icons) {
    var w = 0.0;
    for (var i = 0; i < codes.length; i++) {
      w += pill(codes[i], icon: icons[i]);
    }
    return w + spacing * (codes.length - 1);
  }

  if (codes.isEmpty) return const [];
  final n = codes.length;
  final options = [
    List.filled(n, false),
    [false, ...List.filled(n - 1, true)],
    List.filled(n, true),
  ];
  for (final icons in options) {
    if (total(icons) <= maxWidth) {
      return [for (var i = 0; i < n; i++) (code: codes[i], iconOnly: icons[i])];
    }
  }
  // Icons only, as many as fit (at least none).
  final fit = ((maxWidth + spacing) / (height + spacing)).floor().clamp(0, n);
  return [for (var i = 0; i < fit; i++) (code: codes[i], iconOnly: true)];
}

/// A row of at most [max] running badges for a tile's corner, in priority
/// order, fitted to the width it is given (see [fitItemBadges]).
class KItemBadgeRow extends StatelessWidget {
  const new({
    required this.badges,
    super.key,
    this.max = 2,
    this.height = 14,
    this.spacing = 2,
    this.now,
  });

  final List<ItemBadge> badges;
  final int max;
  final double height;
  final double spacing;

  /// The time the ends are compared with (tests); null: now.
  final DateTime? now;

  static const rowKey = Key('itemBadge.row');

  @override
  Widget build(BuildContext context) {
    final codes = [
      for (final b in runningBadges(badges, now ?? DateTime.now())) b.code,
    ].take(max).toList();
    if (codes.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final m = _PillMetrics(height);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = m.scaler(context);
        double labelWidth(ItemBadgeCode c) {
          final painter = TextPainter(
            text: TextSpan(
              text: itemBadgeLabel(l10n, c),
              style: _labelStyle(context, m, const Color(0xFF000000)),
            ),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final w = painter.width;
          painter.dispose();
          return w.ceilToDouble() + 1;
        }

        final fitted = fitItemBadges(
          codes: codes,
          maxWidth: constraints.maxWidth,
          height: height,
          labelWidth: labelWidth,
          spacing: spacing,
        );
        return Row(
          key: rowKey,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < fitted.length; i++) ...[
              if (i > 0) SizedBox(width: spacing),
              KItemBadgePill(
                fitted[i].code,
                height: height,
                iconOnly: fitted[i].iconOnly,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Every running badge with its icon and name, and the days left of a timed
/// one — the gift's and the store item's details.
class KItemBadgeList extends StatelessWidget {
  const new({required this.badges, super.key, this.now, this.mutedColor});

  final List<ItemBadge> badges;
  final DateTime? now;
  final Color? mutedColor;

  static const listKey = Key('itemBadge.list');
  static Key daysKey(ItemBadgeCode code) => Key('itemBadge.days.${code.wire}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final at = now ?? DateTime.now();
    final running = runningBadges(badges, at);
    if (running.isEmpty) return const SizedBox.shrink();
    return Wrap(
      key: listKey,
      spacing: KSpacing.sm,
      runSpacing: KSpacing.sm,
      children: [
        for (final b in running)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              KItemBadgePill(b.code, height: 24),
              if (b.daysLeft(at) case final days?) ...[
                const SizedBox(width: KSpacing.xs),
                Text(
                  days == 0
                      ? l10n.itemBadgeEndsToday
                      : l10n.itemBadgeDaysLeft(days),
                  key: daysKey(b.code),
                  style: t.caption.copyWith(
                    color: mutedColor ?? p.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
