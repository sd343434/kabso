import 'package:flutter/foundation.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/data/beauty/live_ar_effect.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
import 'package:kabso_live/features/live/data/beauty/live_color_filter.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_glass.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_style.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_theme_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Parts of the go-live screen (owner D94, after their two references):
/// the glass title card, `#` categories, the seat-count picker, the tools
/// bar, the glowing Go LIVE button and the mode bar.
abstract final class GoLiveKeys {
  static const title = Key('goLive.title');
  static const guestsChip = Key('goLive.guests');
  static const start = Key('goLive.start');
  static Key category(String? slug) => Key('goLive.category.${slug ?? ''}');
  static Key seatCount(int count) => Key('goLive.seats.$count');
  static Key tool(String id) => Key('goLive.tool.$id');
  static Key mode(LiveRoomMode mode) => Key('goLive.mode.${mode.name}');
  static Key theme(String slug) => Key('goLive.theme.$slug');
  static const beautySwitch = Key('goLive.beauty.switch');
  static const beautySmooth = Key('goLive.beauty.smooth');
  static const beautyBrighten = Key('goLive.beauty.brighten');
  static Key filter(LiveColorFilter f) => Key('goLive.filter.${f.name}');
  static const filterUnsupported = Key('goLive.filter.unsupported');
  static Key effect(LiveArEffect e) => Key('goLive.effect.${e.name}');
  static const effectsUnavailable = Key('goLive.effect.unavailable');

  /// D144a: why the picked effect is off now, or that it is starting.
  static const effectStatus = Key('goLive.effect.status');

  /// D157 fill light: one chip per level, and the line saying where the
  /// light goes (the published picture, or the screen only).
  static Key fillLightLevel(LiveFillLight l) =>
      Key('goLive.fillLight.${l.name}');
  static const fillLightNote = Key('goLive.fillLight.note');
}

const _white = Color(0xFFFFFFFF);

/// Magic without a status source (tests, previews): nothing to report.
final ValueListenable<LiveArStatus> _noEffectStatus = ValueNotifier(
  LiveArStatus.off,
);
const _shadow = [Shadow(color: KLiveColors.chatScrim, blurRadius: 6)];

/// The host's card: their picture, the title, the guests chip, a waving
/// Kabi, and the categories.
class GoLiveTitleCard extends StatelessWidget {
  const new({
    required this.hostName,
    required this.hostAvatarUrl,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.allowGuests,
    required this.onGuests,
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
  final bool allowGuests;
  final VoidCallback? onGuests;
  final List<LiveCategory> categories;
  final String? category;
  final ValueChanged<String?> onCategory;
  final Color accent;

  /// CONVENTIONS §10.3: 1–80 grapheme clusters.
  static const titleMaxLength = 80;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        LiveGlass(
          radius: KRadius.xl - 2,
          padding: const EdgeInsets.fromLTRB(
            KSpacing.md,
            KSpacing.md,
            KSpacing.md,
            KSpacing.sm + 2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _HostPicture(
                    name: hostName,
                    url: hostAvatarUrl,
                    accent: accent,
                  ),
                  const SizedBox(width: KSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            end: KSpacing.xxxl,
                          ),
                          child: TextField(
                            key: GoLiveKeys.title,
                            controller: controller,
                            focusNode: focusNode,
                            enabled: enabled,
                            maxLength: titleMaxLength,
                            textInputAction: TextInputAction.done,
                            style: text.title.copyWith(
                              color: _white,
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
                              hintStyle: text.title.copyWith(
                                color: _white.withValues(alpha: 0.62),
                                fontWeight: FontWeight.w800,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: KSpacing.xs,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: KSpacing.sm),
                        _Pill(
                          key: GoLiveKeys.guestsChip,
                          icon: allowGuests
                              ? Icons.groups_rounded
                              : Icons.no_accounts_rounded,
                          label: allowGuests
                              ? l10n.goLiveGuestsAllowedChip
                              : l10n.goLiveGuestsOffChip,
                          hint: allowGuests
                              ? l10n.goLiveGuestsOnHint
                              : l10n.goLiveGuestsOffHint,
                          toggled: allowGuests,
                          accent: accent,
                          onTap: onGuests,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (categories.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
                  child: Divider(
                    height: 1,
                    color: _white.withValues(alpha: 0.14),
                  ),
                ),
                SizedBox(
                  height: KSpacing.xxl + KSpacing.xxs,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _CategoryChip(
                        slug: null,
                        label: l10n.goLiveNoCategory,
                        selected: category == null,
                        accent: accent,
                        onTap: enabled ? () => onCategory(null) : null,
                      ),
                      for (final c in categories)
                        _CategoryChip(
                          slug: c.slug,
                          label: '# ${c.name}',
                          selected: category == c.slug,
                          accent: accent,
                          onTap: enabled ? () => onCategory(c.slug) : null,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        // Kabi waves from the card's corner (the owner's mascot; the
        // reference's own mascot is not used).
        PositionedDirectional(
          top: -KSpacing.lg,
          end: -KSpacing.xs,
          child: KabiEmoji(KabsoEmoji.kabi('live'), size: 64, repeat: false),
        ),
      ],
    );
  }
}

class _HostPicture extends StatelessWidget {
  const new({required this.name, required this.url, required this.accent});

  final String name;
  final String? url;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    width: 68,
    height: 68,
    padding: const EdgeInsets.all(2.5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(KRadius.lg + 2),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, KBrandColors.gold],
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(KRadius.lg),
      child: ColoredBox(
        color: KPalette.dark.surfaceRaised,
        child: Center(
          child: KAvatar(name: name, imageUrl: url, size: 60),
        ),
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.accent,
    super.key,
    this.onTap,
    this.toggled,
    this.hint,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;
  final bool? toggled;
  final String? hint;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    toggled: toggled,
    hint: hint,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.md,
          vertical: KSpacing.xs + 1,
        ),
        decoration: BoxDecoration(
          color: (toggled ?? false)
              ? accent.withValues(alpha: 0.28)
              : _white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(KRadius.pill),
          border: Border.all(
            color: (toggled ?? false)
                ? accent.withValues(alpha: 0.8)
                : _white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _white),
            const SizedBox(width: KSpacing.xs + 2),
            Text(
              label,
              style: context.textStyles.caption.copyWith(
                color: _white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CategoryChip extends StatelessWidget {
  const new({
    required this.slug,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String? slug;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: KSpacing.sm),
    child: Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        key: GoLiveKeys.category(slug),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.md + 2),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: [accent, KBrandColors.red600])
                : null,
            color: selected ? null : _white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(KRadius.pill),
            border: Border.all(
              color: _white.withValues(alpha: selected ? 0.5 : 0.16),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.5),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            style: context.textStyles.label.copyWith(
              color: _white,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    ),
  );
}

/// 4 · 6 · 9 · 12 (multi-guest) or 5 · 9 · 13 (audio), with a seat icon.
class GoLiveSeatCountPicker extends StatelessWidget {
  const new({
    required this.counts,
    required this.selected,
    required this.onSelect,
    required this.accent,
    super.key,
  });

  final List<int> counts;
  final int selected;
  final ValueChanged<int>? onSelect;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Large text and narrow cards shrink the row rather than overflow it.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in counts)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
              child: Semantics(
                button: true,
                selected: c == selected,
                label: l10n.goLiveSeatCount(c),
                onTap: onSelect == null ? null : () => onSelect!(c),
                excludeSemantics: true,
                child: GestureDetector(
                  key: GoLiveKeys.seatCount(c),
                  onTap: onSelect == null ? null : () => onSelect!(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.md,
                      vertical: KSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: c == selected
                          ? accent.withValues(alpha: 0.3)
                          : _white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(KRadius.pill),
                      border: Border.all(
                        color: c == selected
                            ? accent
                            : _white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.weekend_rounded,
                          size: 18,
                          color: _white,
                        ),
                        const SizedBox(width: KSpacing.xs + 2),
                        Text(
                          '$c',
                          style: context.textStyles.label.copyWith(
                            color: _white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One tool of [GoLiveToolsBar].
class GoLiveTool {
  const new({
    required this.id,
    required this.icon,
    required this.label,
    required this.onTap,
    this.toggled,
    this.badge = false,
    this.soon = false,
  });

  /// A tool with no server yet (owner D99, ref 84): greyed with "Soon" and
  /// does nothing.
  const new soon({required this.id, required this.icon, required this.label})
    : onTap = null,
      toggled = null,
      badge = false,
      soon = true;

  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool? toggled;

  /// A small dot (e.g. beauty on).
  final bool badge;

  /// See [GoLiveTool.soon].
  final bool soon;
}

/// The frosted tools bar above the button.
class GoLiveToolsBar extends StatelessWidget {
  const new({required this.tools, required this.accent, super.key});

  final List<GoLiveTool> tools;
  final Color accent;

  /// More than this many tools scroll sideways at a fixed width.
  static const maxFitting = 5;

  @override
  Widget build(BuildContext context) {
    final scroll = tools.length > maxFitting;
    Widget item(GoLiveTool t) => scroll
        ? SizedBox(width: 72, child: _tool(context, t))
        : Expanded(child: _tool(context, t));
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      mainAxisSize: scroll ? MainAxisSize.min : MainAxisSize.max,
      children: [for (final t in tools) item(t)],
    );
    return LiveGlass(
      radius: KRadius.xl - 2,
      padding: const EdgeInsets.symmetric(vertical: KSpacing.sm + 2),
      child: scroll
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
          : row,
    );
  }

  Widget _tool(BuildContext context, GoLiveTool t) => Semantics(
    button: true,
    toggled: t.toggled,
    enabled: t.onTap != null,
    label: t.label,
    excludeSemantics: true,
    child: InkWell(
      key: GoLiveKeys.tool(t.id),
      borderRadius: BorderRadius.circular(KRadius.md),
      onTap: t.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  t.icon,
                  size: 28,
                  color: t.onTap == null
                      ? _white.withValues(alpha: 0.4)
                      : _white,
                  shadows: _shadow,
                ),
                if (t.badge)
                  PositionedDirectional(
                    top: -2,
                    end: -4,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                        border: Border.all(color: _white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              t.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(
                color: _white,
                fontWeight: FontWeight.w600,
                shadows: _shadow,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Multi-guest · LIVE · Audio LIVE.
class GoLiveModeBar extends StatelessWidget {
  const new({
    required this.selected,
    required this.onSelect,
    required this.accent,
    super.key,
  });

  final LiveRoomMode selected;
  final ValueChanged<LiveRoomMode>? onSelect;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    Widget mode(LiveRoomMode m, String label) {
      final on = m == selected;
      return Semantics(
        button: true,
        selected: on,
        child: InkWell(
          key: GoLiveKeys.mode(m),
          borderRadius: BorderRadius.circular(KRadius.sm),
          onTap: on || onSelect == null ? null : () => onSelect!(m),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KSizes.minTouchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    style: text.bodyStrong.copyWith(
                      color: on ? _white : _white.withValues(alpha: 0.6),
                      fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                      shadows: _shadow,
                    ),
                  ),
                  const SizedBox(height: KSpacing.xs),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: on ? KSpacing.lg + KSpacing.xs : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(KRadius.pill),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.8),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          mode(LiveRoomMode.multi, l10n.goLiveModeMulti),
          mode(LiveRoomMode.solo, l10n.goLiveModeSolo),
          mode(LiveRoomMode.audio, l10n.goLiveModeAudio),
        ],
      ),
    );
  }
}

/// The header of the white sheets (owner refs 66, 68, 70): the title
/// (centred or at the start) and ✕, measured from the sheet's top.
class LiveWhiteSheetHeader extends StatelessWidget {
  const new({
    required this.title,
    super.key,
    this.centred = false,
    this.titleTop = 14.4,
    this.closeTop = 2.5,
    this.closeEnd = 6,
  });

  final String title;
  final bool centred;
  final double titleTop;
  final double closeTop;
  final double closeEnd;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: Stack(
      children: [
        Positioned.fill(
          top: titleTop,
          child: Align(
            alignment: centred
                ? Alignment.topCenter
                : AlignmentDirectional.topStart,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: centred ? 0 : 21.4),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: context.textStyles.title.copyWith(
                    color: const Color(0xFF1C1B1F),
                    fontSize: 17.5,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          top: closeTop,
          end: closeEnd,
          child: IconButton(
            tooltip: context.l10n.liveClose,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF1C1B1F),
              size: 25,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The room theme picker (owner ref 68): a white half-height sheet, the
/// Theme tab, and the server's themes as cards two by two, the chosen one
/// framed in teal.
Future<void> showLiveThemeSheet(
  BuildContext context, {
  required List<String> themes,
  required String selected,
  required ValueChanged<String> onSelect,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFFFFFFFF),
  // The reference leaves the room undimmed behind the sheet.
  barrierColor: const Color(0x00000000),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (sheet) {
    final text = sheet.textStyles;
    return SizedBox(
      height: MediaQuery.sizeOf(sheet).height * 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The handle (36 x 5 pt, 6 pt down).
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCCCCCC),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          LiveWhiteSheetHeader(
            title: sheet.l10n.goLiveThemeTitle,
            titleTop: 21,
            closeTop: 10.6,
            closeEnd: 1.3,
          ),
          // The Theme tab (the reference's other tabs have no feature here).
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 14, top: 8),
            child: Container(
              height: 21.4,
              padding: const EdgeInsets.fromLTRB(12.6, 3.5, 12.6, 0),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F5F8),
                borderRadius: BorderRadius.circular(10.7),
              ),
              child: Text(
                sheet.l10n.goLiveTheme,
                style: text.bodyStrong.copyWith(
                  color: const Color(0xFF2D2F33),
                  fontSize: 12.5,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.fromLTRB(20, 18.6, 20, 16),
              crossAxisSpacing: 15.4,
              childAspectRatio: 187.3 / 152.8,
              children: [
                for (final slug in themes)
                  _ThemeCard(
                    slug: slug,
                    selected: slug == selected,
                    onTap: () {
                      onSelect(slug);
                      Navigator.of(sheet).pop();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  },
);

/// A theme (ref 68): its look with an empty seat, a wave and the host's
/// circle, 187.3 x 118.3 pt, the name under it.
class _ThemeCard extends StatelessWidget {
  const new({required this.slug, required this.selected, required this.onTap});

  final String slug;
  final bool selected;
  final VoidCallback onTap;

  static const teal = Color(0xFF34CAC0);

  @override
  Widget build(BuildContext context) {
    final art = LiveThemeArt.of(slug);
    final name = art.name(context.l10n);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: GoLiveKeys.theme(slug),
        onTap: onTap,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 187.3 / 118.3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9.3),
                  boxShadow: selected
                      ? const [BoxShadow(color: teal, spreadRadius: 2.3)]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9.3),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      LiveThemeBackground(theme: slug),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 45,
                            height: 45,
                            decoration: const BoxDecoration(
                              color: Color(0x38FFFFFF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Color(0xCCFFFFFF),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Icon(
                            Icons.graphic_eq_rounded,
                            color: Color(0xCCFFFFFF),
                            size: 18,
                          ),
                          const SizedBox(width: 7),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFE6FFFA),
                              border: Border.all(color: art.accent, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: art.accent.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: Color(0xFF2EC4B6),
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.body.copyWith(
                color: const Color(0xFF1C1B1F),
                fontSize: 15,
                height: 1.2,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Beauty: on/off, smoothing and brightening (D94), applied live.
Future<void> showLiveBeautySheet(
  BuildContext context, {
  required LiveBeauty beauty,
  required bool supported,
  required ValueChanged<LiveBeauty> onChanged,
  required Color accent,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(0x00000000),
  // The picture stays visible above the sheet while adjusting.
  barrierColor: const Color(0x22000000),
  builder: (sheet) {
    var value = beauty;
    return StatefulBuilder(
      builder: (context, setState) {
        final l10n = context.l10n;
        final text = context.textStyles;
        void set(LiveBeauty next) {
          setState(() => value = next);
          onChanged(next);
        }

        Widget slider(
          Key key,
          String label,
          double v,
          ValueChanged<double> f,
        ) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          child: Row(
            children: [
              SizedBox(
                width: 104,
                child: Text(label, style: text.label.copyWith(color: _white)),
              ),
              Expanded(
                child: Slider(
                  key: key,
                  value: v,
                  activeColor: accent,
                  inactiveColor: _white.withValues(alpha: 0.2),
                  onChanged: supported && value.enabled ? f : null,
                ),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${(v * 100).round()}',
                  textAlign: TextAlign.end,
                  style: text.caption.copyWith(color: _white),
                ),
              ),
            ],
          ),
        );

        return LiveSheetFrame(
          title: l10n.goLiveBeautyTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile.adaptive(
                key: GoLiveKeys.beautySwitch,
                value: value.enabled,
                activeTrackColor: accent,
                onChanged: supported
                    ? (on) => set(value.copyWith(enabled: on))
                    : null,
                title: Text(
                  l10n.goLiveBeautySwitch,
                  style: text.bodyStrong.copyWith(color: _white),
                ),
                subtitle: supported
                    ? null
                    : Text(
                        l10n.goLiveBeautyUnsupported,
                        style: text.caption.copyWith(
                          color: _white.withValues(alpha: 0.7),
                        ),
                      ),
              ),
              slider(
                GoLiveKeys.beautySmooth,
                l10n.goLiveBeautySmooth,
                value.smooth,
                (v) => set(value.copyWith(smooth: v)),
              ),
              slider(
                GoLiveKeys.beautyBrighten,
                l10n.goLiveBeautyBrighten,
                value.brighten,
                (v) => set(value.copyWith(brighten: v)),
              ),
            ],
          ),
        );
      },
    );
  },
);

class LiveSheetFrame extends StatelessWidget {
  const new({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(KSpacing.sm),
    child: SafeArea(
      top: false,
      child: LiveGlass(
        tint: KLiveStyle.card,
        padding: const EdgeInsets.only(top: KSpacing.sm, bottom: KSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: KMetrics.sheetHandleWidth,
              height: KMetrics.sheetHandleHeight,
              decoration: BoxDecoration(
                color: _white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(KRadius.pill),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            Semantics(
              header: true,
              child: Text(
                title,
                style: context.textStyles.title.copyWith(color: _white),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            child,
          ],
        ),
      ),
    ),
  );
}

/// D143 Magic: the colour filters, applied live to the published camera
/// picture. Where this device has no camera pipeline ([supported] false)
/// the filters are shown greyed with why.
///
/// D144: under them, **Effects (beta)** — DeepAR on the published picture —
/// where the platform has the processor ([effects] not `unsupported`);
/// greyed with why when this build has no DeepAR licence.
///
/// D144a: [effectStatus] (DeepAR on the device) — an effect DeepAR had to
/// switch off shows None selected and an honest «المؤثر غير متاح الآن: …».
Future<void> showLiveFilterSheet(
  BuildContext context, {
  required LiveColorFilter selected,
  required bool supported,
  required ValueChanged<LiveColorFilter> onChanged,
  required Color accent,
  LiveArSupport effects = LiveArSupport.unsupported,
  LiveArEffect effect = LiveArEffect.none,
  ValueChanged<LiveArEffect>? onEffect,
  ValueListenable<LiveArStatus>? effectStatus,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(0x00000000),
  // The picture stays visible above the sheet while choosing.
  barrierColor: const Color(0x22000000),
  builder: (sheet) {
    var value = selected;
    var effectValue = effect;
    return StatefulBuilder(
      builder: (context, setState) {
        final l10n = context.l10n;
        final text = context.textStyles;
        return LiveSheetFrame(
          title: l10n.liveFilterTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!supported)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KSpacing.lg,
                    0,
                    KSpacing.lg,
                    KSpacing.md,
                  ),
                  child: Text(
                    l10n.liveFilterUnsupported,
                    key: GoLiveKeys.filterUnsupported,
                    textAlign: TextAlign.center,
                    style: text.caption.copyWith(
                      color: _white.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              SizedBox(
                height: KLiveStyle.filterSwatch + 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
                  children: [
                    for (final f in LiveColorFilter.values)
                      _FilterSwatch(
                        key: GoLiveKeys.filter(f),
                        filter: f,
                        label: liveFilterLabel(l10n, f),
                        selected: f == value,
                        accent: accent,
                        onTap: supported
                            ? () {
                                setState(() => value = f);
                                onChanged(f);
                              }
                            : null,
                      ),
                  ],
                ),
              ),
              if (effects != LiveArSupport.unsupported)
                ValueListenableBuilder<LiveArStatus>(
                  valueListenable: effectStatus ?? _noEffectStatus,
                  builder: (context, status, _) => _EffectsSection(
                    selected: status.state == LiveArState.unavailable
                        ? LiveArEffect.none
                        : effectValue,
                    status:
                        effectValue == LiveArEffect.none &&
                            status.state != LiveArState.unavailable
                        ? LiveArStatus.off
                        : status,
                    ready: effects == LiveArSupport.ready && onEffect != null,
                    accent: accent,
                    onChanged: (e) {
                      setState(() => effectValue = e);
                      onEffect?.call(e);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  },
);

/// D157 fill light (front camera): its level — Off, Low, Medium, High.
/// [onPicture]: the device lifts the published picture (viewers see it);
/// else only a thin glow on the screen lights the face, and the sheet says
/// so. The picture stays visible above the sheet while choosing.
Future<void> showLiveFillLightSheet(
  BuildContext context, {
  required LiveFillLight level,
  required bool onPicture,
  required Color accent,
  required ValueChanged<LiveFillLight> onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(0x00000000),
  barrierColor: const Color(0x22000000),
  builder: (sheet) {
    var value = level;
    return StatefulBuilder(
      builder: (context, setState) {
        final l10n = context.l10n;
        final text = context.textStyles;
        return LiveSheetFrame(
          title: l10n.liveFillLightTitle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              0,
              KSpacing.lg,
              KSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  onPicture
                      ? l10n.liveFillLightOnPicture
                      : l10n.liveFillLightScreenOnly,
                  key: GoLiveKeys.fillLightNote,
                  textAlign: TextAlign.center,
                  style: text.caption.copyWith(
                    color: _white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: KSpacing.md),
                // One row, Off first (start side: right in Arabic).
                Row(
                  spacing: KSpacing.xs,
                  children: [
                    for (final l in LiveFillLight.values)
                      Expanded(
                        child: _EffectChip(
                          key: GoLiveKeys.fillLightLevel(l),
                          dense: true,
                          label: liveFillLightLabel(l10n, l),
                          selected: l == value,
                          accent: accent,
                          onTap: () {
                            setState(() => value = l);
                            onChanged(l);
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  },
);

/// The name of fill-light [level] in the person's language.
String liveFillLightLabel(AppLocalizations l10n, LiveFillLight level) =>
    switch (level) {
      LiveFillLight.off => l10n.liveFillLightOff,
      LiveFillLight.low => l10n.liveFillLightLow,
      LiveFillLight.medium => l10n.liveFillLightMedium,
      LiveFillLight.high => l10n.liveFillLightHigh,
    };

/// The name of [effect] in the person's language.
String liveEffectLabel(AppLocalizations l10n, LiveArEffect effect) =>
    switch (effect) {
      LiveArEffect.none => l10n.liveEffectNone,
      LiveArEffect.backgroundBlur => l10n.liveEffectBackgroundBlur,
    };

/// D144a: Magic's honest line for [status] (null: nothing to say).
String? liveEffectStatusText(AppLocalizations l10n, LiveArStatus status) =>
    switch (status.state) {
      LiveArState.off || LiveArState.running => null,
      LiveArState.starting => l10n.liveEffectStarting,
      LiveArState.unavailable => switch (status.problem) {
        LiveArProblem.licence => l10n.liveEffectUnavailableLicence,
        LiveArProblem.stopped => l10n.liveEffectUnavailableStopped,
        LiveArProblem.blackPicture => l10n.liveEffectUnavailableBlack,
        LiveArProblem.failed || null => l10n.liveEffectUnavailableFailed,
      },
    };

/// D144 Magic → Effects (beta): one chip per [LiveArEffect].
class _EffectsSection extends StatelessWidget {
  const new({
    required this.selected,
    required this.ready,
    required this.accent,
    required this.onChanged,
    this.status = LiveArStatus.off,
  });

  final LiveArEffect selected;
  final LiveArStatus status;
  final bool ready;
  final Color accent;
  final ValueChanged<LiveArEffect> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.md,
        KSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.liveEffectsTitle,
              style: text.label.copyWith(
                color: _white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!ready) ...[
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.liveEffectsUnavailable,
              key: GoLiveKeys.effectsUnavailable,
              style: text.caption.copyWith(
                color: _white.withValues(alpha: 0.75),
              ),
            ),
          ] else if (liveEffectStatusText(l10n, status) case final line?) ...[
            const SizedBox(height: KSpacing.xs),
            Semantics(
              liveRegion: true,
              child: Text(
                line,
                key: GoLiveKeys.effectStatus,
                style: text.caption.copyWith(
                  color: status.state == LiveArState.unavailable
                      ? const Color(0xFFFFC2C2)
                      : _white.withValues(alpha: 0.75),
                ),
              ),
            ),
          ],
          const SizedBox(height: KSpacing.sm),
          Wrap(
            spacing: KSpacing.sm,
            runSpacing: KSpacing.sm,
            children: [
              for (final e in LiveArEffect.values)
                _EffectChip(
                  key: GoLiveKeys.effect(e),
                  icon: switch (e) {
                    LiveArEffect.none => Icons.block_rounded,
                    LiveArEffect.backgroundBlur => Icons.blur_on_rounded,
                  },
                  label: liveEffectLabel(l10n, e),
                  selected: e == selected,
                  accent: accent,
                  onTap: ready ? () => onChanged(e) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EffectChip extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    super.key,
    this.icon,
    this.dense = false,
  });

  final IconData? icon;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  /// D157: tighter padding, content centred (four in one row, words only).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KRadius.pill),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: EdgeInsets.symmetric(
              horizontal: dense ? KSpacing.sm : KSpacing.md,
              vertical: KSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: _white.withValues(alpha: selected ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(KRadius.pill),
              border: Border.all(
                color: selected ? accent : _white.withValues(alpha: 0.2),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon case final icon?) ...[
                  Icon(icon, size: 18, color: _white),
                  const SizedBox(width: KSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.caption.copyWith(
                      color: _white,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The name of [filter] in the person's language.
String liveFilterLabel(AppLocalizations l10n, LiveColorFilter filter) =>
    switch (filter) {
      LiveColorFilter.natural => l10n.liveFilterNatural,
      LiveColorFilter.warm => l10n.liveFilterWarm,
      LiveColorFilter.cool => l10n.liveFilterCool,
      LiveColorFilter.mono => l10n.liveFilterMono,
      LiveColorFilter.cinematic => l10n.liveFilterCinematic,
      LiveColorFilter.vivid => l10n.liveFilterVivid,
      LiveColorFilter.soft => l10n.liveFilterSoft,
    };

class _FilterSwatch extends StatelessWidget {
  const new({
    required this.filter,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final LiveColorFilter filter;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const size = KLiveStyle.filterSwatch;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
            child: Column(
              children: [
                Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(KRadius.md),
                    border: Border.all(
                      color: selected ? accent : const Color(0x00000000),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(KRadius.md - 2),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(filter.flutterMatrix),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: KLiveStyle.filterSample,
                          ),
                        ),
                        child: SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: KSpacing.xs + 2),
                SizedBox(
                  width: size + 8,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.textStyles.caption.copyWith(
                      color: _white,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
