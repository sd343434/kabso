import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/data/beauty/live_beauty.dart';
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
}

const _white = Color(0xFFFFFFFF);
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
        const PositionedDirectional(
          top: -KSpacing.lg,
          end: -KSpacing.xs,
          child: KabiEmoji(KabiEmojis.live, size: 64, repeat: false),
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
  });

  final String id;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool? toggled;

  /// A small dot (e.g. beauty on).
  final bool badge;
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

/// The room theme picker: the server's themes as tall thumbnails.
Future<void> showLiveThemeSheet(
  BuildContext context, {
  required List<String> themes,
  required String selected,
  required ValueChanged<String> onSelect,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(0x00000000),
  builder: (sheet) => LiveSheetFrame(
    title: sheet.l10n.goLiveThemeTitle,
    child: SizedBox(
      height: 210,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
        children: [
          for (final slug in themes)
            _ThemeThumb(
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
  ),
);

class _ThemeThumb extends StatelessWidget {
  const new({required this.slug, required this.selected, required this.onTap});

  final String slug;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final art = LiveThemeArt.of(slug);
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: KSpacing.md),
      child: Semantics(
        button: true,
        selected: selected,
        label: art.name(context.l10n),
        excludeSemantics: true,
        child: GestureDetector(
          key: GoLiveKeys.theme(slug),
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: 100,
                height: 170,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(KRadius.lg),
                  border: Border.all(
                    color: selected
                        ? art.accent
                        : _white.withValues(alpha: 0.15),
                    width: selected ? 2.5 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: art.accent.withValues(alpha: 0.6),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(KRadius.lg - 1),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      LiveThemeBackground(theme: slug),
                      if (selected)
                        Align(
                          alignment: AlignmentDirectional.topEnd,
                          child: Padding(
                            padding: const EdgeInsets.all(KSpacing.xs + 2),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: art.accent,
                              size: 22,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: KSpacing.xs + 2),
              Text(
                art.name(context.l10n),
                style: context.textStyles.caption.copyWith(
                  color: _white,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
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
