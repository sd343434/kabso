import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cover_picture.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_glass.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D131: the go-live setup of a video live, measured on ref 164 (the
/// owner's own phone, 393 pt; outside git). "E" marks an estimate.
abstract final class KGoLiveSetup {
  /// The glass card: 13.4 pt from the sides, 109.9 pt tall (with one row
  /// of topics), ≈ 13 pt corners (E); the cover 51.1 pt.
  static const double cardInset = 13.4;
  static const double cardRadius = 13;
  static const double cover = 51.1;

  /// The topics: 20.4 pt chips, a 22.1 pt ▾ circle at the end.
  static const double chipHeight = 20.4;
  static const double expander = 22.1;

  /// The tools: 2 rows of 5, columns 56.6 pt apart, rows 64.3 pt; 20 pt
  /// white outline icons, no circle; 11 sp labels.
  static const double toolPitch = 56.6;
  static const double toolRow = 64.3;
  static const double toolIcon = 20;

  /// Go LIVE: 273.8 × 43 pt, `#02BFB1` → `#02B6A9`.
  static const double startWidth = 273.8;
  static const double startHeight = 43;
  static const startColors = [Color(0xFF02BFB1), Color(0xFF02B6A9)];

  /// The modes on a black band; the chosen one white and bold (≈ 15 sp)
  /// over a 4.5 pt dot, the others grey (≈ 12.5 sp).
  static const double modeBand = 98;
  static const double modeDot = 4.5;
}

const _white = Color(0xFFFFFFFF);
const _shadow = [Shadow(color: KLiveColors.chatScrim, blurRadius: 6)];

/// The glass card (ref 164): the live cover with Edit (CP-015), the title
/// and, under a thin line, the live's topics (the categories) with ▾ to see
/// them all. Who may watch moved to Settings (D131).
class GoLiveSetupCard extends StatelessWidget {
  const new({
    required this.hostName,
    required this.hostAvatarUrl,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.categories,
    required this.category,
    required this.onCategory,
    required this.accent,
    super.key,
  });

  final String hostName;
  final String? hostAvatarUrl;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final List<LiveCategory> categories;
  final String? category;
  final ValueChanged<String?> onCategory;
  final Color accent;

  static const expanderKey = Key('goLive.categories.all');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return LiveGlass(
      radius: KGoLiveSetup.cardRadius,
      padding: const EdgeInsets.fromLTRB(9.2, 9, 9.2, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LiveCoverPicture(
                hostName: hostName,
                hostAvatarUrl: hostAvatarUrl,
                enabled: enabled,
                size: KGoLiveSetup.cover,
                radius: 4.3,
              ),
              const SizedBox(width: 11.5),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: TextField(
                    key: GoLiveKeys.title,
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled,
                    maxLength: GoLiveTitleCard.titleMaxLength,
                    maxLines: 2,
                    minLines: 1,
                    textInputAction: TextInputAction.done,
                    style: text.bodyStrong.copyWith(
                      color: _white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                    cursorColor: accent,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      counterText: '',
                      hintText: l10n.goLiveTitleHint,
                      hintStyle: text.bodyStrong.copyWith(
                        color: _white.withValues(alpha: 0.72),
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (categories.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Divider(height: 1, color: _white.withValues(alpha: 0.22)),
            ),
            SizedBox(
              height: KSizes.minTouchTarget - 8,
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _TopicChip(
                            slug: null,
                            label: l10n.goLiveNoCategory,
                            selected: category == null,
                            onTap: enabled ? () => onCategory(null) : null,
                          ),
                          for (final c in categories)
                            _TopicChip(
                              slug: c.slug,
                              label: '# ${c.name}',
                              selected: category == c.slug,
                              onTap: enabled ? () => onCategory(c.slug) : null,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.goLiveCategoriesAll,
                    excludeSemantics: true,
                    child: GestureDetector(
                      key: expanderKey,
                      behavior: HitTestBehavior.opaque,
                      onTap: enabled
                          ? () => _showAll(context, l10n.goLiveCategoriesAll)
                          : null,
                      child: SizedBox(
                        width: 36,
                        height: 40,
                        child: Center(
                          child: Container(
                            width: KGoLiveSetup.expander,
                            height: KGoLiveSetup.expander,
                            decoration: BoxDecoration(
                              color: _white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: _white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showAll(BuildContext context, String title) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFFFFFFFF),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheet) {
          final l10n = sheet.l10n;
          Widget row(String? slug, String label) => ListTile(
            key: Key('goLive.categories.all.${slug ?? ''}'),
            title: Text(
              label,
              style: sheet.textStyles.body.copyWith(
                color: const Color(0xFF1C1B1F),
              ),
            ),
            trailing: category == slug
                ? Icon(Icons.check_rounded, color: accent)
                : null,
            onTap: () {
              Navigator.of(sheet).pop();
              onCategory(slug);
            },
          );
          return SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  LiveWhiteSheetHeader(title: title, centred: true),
                  row(null, l10n.goLiveNoCategory),
                  for (final c in categories) row(c.slug, '# ${c.name}'),
                ],
              ),
            ),
          );
        },
      );
}

class _TopicChip extends StatelessWidget {
  const new({
    required this.slug,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String? slug;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 9.4),
    child: Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        key: GoLiveKeys.category(slug),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: KGoLiveSetup.chipHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _white.withValues(alpha: selected ? 0.42 : 0.18),
              borderRadius: BorderRadius.circular(KRadius.pill),
              border: selected
                  ? Border.all(color: _white.withValues(alpha: 0.8))
                  : null,
            ),
            child: Text(
              label,
              maxLines: 1,
              style: context.textStyles.caption.copyWith(
                color: _white,
                fontSize: 11,
                height: 1.2,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The tools (ref 164): two rows of five, white outline icons with no
/// circle and a label under each; the last tool of the first row folds the
/// second (client-only). Tools without a backend say "Soon" (D99).
class GoLiveToolGrid extends StatelessWidget {
  const new({
    required this.first,
    required this.second,
    required this.expanded,
    required this.onExpanded,
    super.key,
  });

  /// Up to four tools; the fifth place is the fold button.
  final List<GoLiveTool> first;
  final List<GoLiveTool> second;
  final bool expanded;
  final ValueChanged<bool> onExpanded;

  static const foldKey = Key('goLive.tools.fold');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget row(List<Widget> cells) => SizedBox(
      height: KGoLiveSetup.toolRow,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final c in cells)
            SizedBox(width: KGoLiveSetup.toolPitch, child: c),
        ],
      ),
    );
    final fold = Semantics(
      button: true,
      label: expanded ? l10n.goLiveToolsLess : l10n.goLiveToolsMore,
      excludeSemantics: true,
      child: GestureDetector(
        key: foldKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => onExpanded(!expanded),
        child: _ToolFace(
          icon: Container(
            width: 19.5,
            height: 19.5,
            decoration: BoxDecoration(
              color: _white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: _white,
            ),
          ),
          label: expanded ? l10n.goLiveToolsLess : l10n.goLiveToolsMore,
        ),
      ),
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: KMetrics.overlayMaxTextScale,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row([for (final t in first) _Tool(tool: t), fold]),
            if (expanded) row([for (final t in second) _Tool(tool: t)]),
          ],
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const new({required this.tool});

  final GoLiveTool tool;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final enabled = tool.onTap != null;
    final label = switch (tool.toggled) {
      _ when tool.soon => '${tool.label}, ${l10n.liveSoon}',
      true => '${tool.label}, ${l10n.liveToolOn}',
      false => '${tool.label}, ${l10n.liveToolOff}',
      null => tool.label,
    };
    return Semantics(
      button: true,
      enabled: enabled,
      toggled: tool.toggled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: GoLiveKeys.tool(tool.id),
        behavior: HitTestBehavior.opaque,
        onTap: tool.onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: _ToolFace(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  tool.icon,
                  size: KGoLiveSetup.toolIcon,
                  color: _white,
                  shadows: _shadow,
                ),
                if (tool.badge)
                  const PositionedDirectional(
                    top: -2,
                    end: -4,
                    child: SizedBox.square(
                      dimension: 7,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF02BFB1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                if (tool.soon)
                  PositionedDirectional(
                    top: -7,
                    start: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: _white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(KRadius.pill),
                      ),
                      child: Text(
                        l10n.liveSoon,
                        style: context.textStyles.caption.copyWith(
                          color: const Color(0xFF3A3A44),
                          fontSize: 7,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: tool.label,
          ),
        ),
      ),
    );
  }
}

class _ToolFace extends StatelessWidget {
  const new({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(height: 24, child: Center(child: icon)),
      const SizedBox(height: 6),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: context.textStyles.caption.copyWith(
          color: _white,
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w500,
          shadows: _shadow,
        ),
      ),
    ],
  );
}

/// Go LIVE (ref 164): a 273.8 × 43 pt teal pill with a soft glow.
class GoLiveStartPill extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        key: GoLiveKeys.start,
        onTap: onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled || busy ? 1 : 0.5,
          child: Container(
            width: KGoLiveSetup.startWidth,
            height: KSizes.minTouchTarget,
            alignment: Alignment.center,
            child: Container(
              height: KGoLiveSetup.startHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: KGoLiveSetup.startColors,
                ),
                borderRadius: BorderRadius.circular(KRadius.pill),
                boxShadow: [
                  BoxShadow(
                    color: KGoLiveSetup.startColors.first.withValues(
                      alpha: 0.45,
                    ),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _white,
                      ),
                    ),
                    const SizedBox(width: KSpacing.sm),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: context.textStyles.bodyStrong.copyWith(
                          color: _white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The modes (ref 164) on a black band: Multi-guest · LIVE · Audio LIVE in
/// a row centred on the chosen one, which is white and bold over a dot.
class GoLiveModePager extends StatelessWidget {
  const new({required this.selected, required this.onSelect, super.key});

  final LiveRoomMode selected;
  final ValueChanged<LiveRoomMode>? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final modes = [
      (LiveRoomMode.multi, l10n.goLiveModeMulti),
      (LiveRoomMode.solo, l10n.goLiveModeSolo),
      (LiveRoomMode.audio, l10n.goLiveModeAudio),
    ];
    final i = modes.indexWhere((m) => m.$1 == selected);
    Widget mode(LiveRoomMode m, String label) {
      final on = m == selected;
      return Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          key: GoLiveKeys.mode(m),
          behavior: HitTestBehavior.opaque,
          onTap: on || onSelect == null ? null : () => onSelect!(m),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: KSizes.minTouchTarget,
              minWidth: KSizes.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    style: text.bodyStrong.copyWith(
                      color: on ? _white : _white.withValues(alpha: 0.55),
                      fontSize: on ? 15 : 12.5,
                      fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: on ? KGoLiveSetup.modeDot : 0,
                    height: KGoLiveSetup.modeDot,
                    decoration: const BoxDecoration(
                      color: _white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // The chosen mode sits in the middle: the row is shifted by the
    // difference of the labels on either side (E: equal widths assumed).
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final shift = (1 - i).toDouble() * (rtl ? -1 : 1);
    return ColoredBox(
      color: const Color(0xFF000000),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: KSizes.minTouchTarget + 14,
          child: Center(
            child: FractionalTranslation(
              translation: Offset(shift * 0.24, 0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [for (final (m, label) in modes) mode(m, label)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
