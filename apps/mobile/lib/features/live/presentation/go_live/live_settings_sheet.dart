import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D225 (owner, 2026-11-01): one settings page per live — the host's
/// «إعدادات البث» (the first tile of ≡ Room Tools, in every mode) and the
/// viewer's «إعدادات المشاهدة» (in the viewer's ≡). Grouped rows on the
/// white live sheet; each mode passes only the groups it needs. [groups] is
/// built again whenever what it watches changes (the mic, the chat, …), so
/// every switch shows the state the live is really in.
Future<void> showLiveSettingsSheet(
  BuildContext context, {
  required String title,
  required List<LiveSettingsGroup> Function(BuildContext, WidgetRef) groups,
  Key? key,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFFFFFFFF),
  barrierColor: const Color(0x00000000),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (sheet) => LiveSettingsSheet(key: key, title: title, groups: groups),
);

/// A titled group of rows («الصوت», «الكاميرا», …).
class LiveSettingsGroup {
  const new({required this.title, required this.items});

  final String title;
  final List<LiveSettingsItem> items;
}

/// One row of a [LiveSettingsSheet].
sealed class LiveSettingsItem {
  const new({required this.id, required this.label, this.icon, this.hint});

  /// The row's key is `LiveSettingsSheet.itemKey(id)`.
  final String id;
  final String label;
  final IconData? icon;

  /// A second line under the label.
  final String? hint;
}

/// An on/off row; [onChanged] null: shown, not changeable (e.g. not live).
final class LiveSettingsSwitch extends LiveSettingsItem {
  const new({
    required super.id,
    required super.label,
    required this.value,
    required this.onChanged,
    super.icon,
    super.hint,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
}

/// A row that opens something (another sheet, a picker) or does one thing
/// ([closes]: the settings page closes first, e.g. minimize). [onTap] null:
/// an honest «قريباً» (greyed, does nothing).
final class LiveSettingsLink extends LiveSettingsItem {
  const new({
    required super.id,
    required super.label,
    required this.onTap,
    super.icon,
    super.hint,
    this.trailing,
    this.closes = false,
    this.danger = false,
  });

  final VoidCallback? onTap;

  /// A value before the chevron (a count, the current choice).
  final String? trailing;
  final bool closes;

  /// Drawn in the live red (a destructive or strong action).
  final bool danger;
}

/// A 0–100 % slider.
final class LiveSettingsSlider extends LiveSettingsItem {
  const new({
    required super.id,
    required super.label,
    required this.value,
    required this.onChanged,
    super.icon,
    super.hint,
  });

  /// 0–1.
  final double value;
  final ValueChanged<double>? onChanged;
}

/// One of a few choices (e.g. the chat's text size), as chips.
final class LiveSettingsChoice extends LiveSettingsItem {
  const new({
    required super.id,
    required super.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    super.icon,
    super.hint,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int>? onSelected;
}

class LiveSettingsSheet extends ConsumerWidget {
  const new({required this.title, required this.groups, super.key});

  final String title;
  final List<LiveSettingsGroup> Function(BuildContext, WidgetRef) groups;

  static const sheetKey = Key('liveSettingsSheet');
  static Key itemKey(String id) => Key('liveSettingsSheet.$id');
  static Key optionKey(String id, int index) =>
      Key('liveSettingsSheet.$id.$index');

  static const ink = Color(0xFF000000);
  static const hintInk = Color(0xFF7A7B8C);
  static const groupInk = Color(0xFF6C6E78);
  static const band = Color(0xFFF3F3F3);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = groups(context, ref).where((g) => g.items.isNotEmpty);
    final height = MediaQuery.sizeOf(context).height;
    return SafeArea(
      key: sheetKey,
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height * 0.86),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LiveWhiteSheetHeader(title: title, centred: true, titleTop: 15.6),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (final (i, g) in list.indexed) ...[
                    if (i > 0)
                      const ColoredBox(
                        color: band,
                        child: SizedBox(height: 8, width: double.infinity),
                      ),
                    _GroupTitle(g.title),
                    for (final item in g.items) _Row(item: item),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const new(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(17.5, 12, 16, 2),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: context.textStyles.caption.copyWith(
          color: LiveSettingsSheet.groupInk,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const new({required this.item});

  final LiveSettingsItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final item = this.item;
    final enabled = switch (item) {
      LiveSettingsSwitch(:final onChanged) => onChanged != null,
      LiveSettingsLink(:final onTap) => onTap != null,
      LiveSettingsSlider(:final onChanged) => onChanged != null,
      LiveSettingsChoice(:final onSelected) => onSelected != null,
    };
    final danger = item is LiveSettingsLink && item.danger;
    final labelStyle = text.title.copyWith(
      color: !enabled
          ? const Color(0xFFB4B6BB)
          : danger
          ? const Color(0xFFD7263D)
          : LiveSettingsSheet.ink,
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.w500,
    );
    final hintStyle = text.caption.copyWith(
      color: LiveSettingsSheet.hintInk,
      fontSize: 12.5,
    );
    Widget labels({String? trailingSoon}) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        ),
        if (item.hint case final hint?)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              hint,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: hintStyle,
            ),
          ),
      ],
    );
    Widget? leading;
    if (item.icon case final icon?) {
      leading = Padding(
        padding: const EdgeInsetsDirectional.only(end: 12),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? const Color(0xFF2D2F33) : const Color(0xFFB4B6BB),
        ),
      );
    }
    Widget line(Widget middle, {Widget? end}) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(17.5, 6, 12, 6),
        child: Row(
          children: [
            ?leading,
            Expanded(child: middle),
            if (end != null) ...[const SizedBox(width: 8), end],
          ],
        ),
      ),
    );
    switch (item) {
      case LiveSettingsSwitch(:final value, :final onChanged):
        return Semantics(
          key: LiveSettingsSheet.itemKey(item.id),
          container: true,
          toggled: value,
          enabled: onChanged != null,
          label: [item.label, ?item.hint].join(', '),
          onTap: onChanged == null ? null : () => onChanged(!value),
          excludeSemantics: true,
          child: InkWell(
            onTap: onChanged == null ? null : () => onChanged(!value),
            child: line(
              labels(),
              end: Switch(value: value, onChanged: onChanged),
            ),
          ),
        );
      case LiveSettingsLink(:final onTap, :final trailing, :final closes):
        final soon = onTap == null;
        void tap() {
          if (closes) Navigator.of(context).pop();
          onTap!();
        }

        return Semantics(
          key: LiveSettingsSheet.itemKey(item.id),
          container: true,
          button: !soon,
          enabled: !soon,
          label: [item.label, ?trailing, if (soon) l10n.liveSoon].join(', '),
          onTap: soon ? null : tap,
          excludeSemantics: true,
          child: InkWell(
            onTap: soon ? null : tap,
            child: line(
              labels(),
              end: soon
                  ? Text(
                      l10n.liveSoon,
                      style: text.caption.copyWith(
                        color: const Color(0xFFB4B6BB),
                        fontSize: 13,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (trailing case final t?)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 96),
                            child: Text(
                              t,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.body.copyWith(
                                color: const Color(0xFFA4A9AC),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.chevron_left_rounded
                              : Icons.chevron_right_rounded,
                          color: const Color(0xFF888A8F),
                          size: 24,
                        ),
                      ],
                    ),
            ),
          ),
        );
      case LiveSettingsSlider(:final value, :final onChanged):
        return Semantics(
          key: LiveSettingsSheet.itemKey(item.id),
          container: true,
          child: line(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                labels(),
                Slider(
                  value: value.clamp(0, 1),
                  divisions: 10,
                  label: '${(value * 100).round()}%',
                  semanticFormatterCallback: (v) => '${(v * 100).round()}%',
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        );
      case LiveSettingsChoice(
        :final options,
        :final selected,
        :final onSelected,
      ):
        return Semantics(
          key: LiveSettingsSheet.itemKey(item.id),
          container: true,
          child: line(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labels(),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final (i, label) in options.indexed)
                      ChoiceChip(
                        key: LiveSettingsSheet.optionKey(item.id, i),
                        label: Text(label),
                        selected: i == selected,
                        onSelected: onSelected == null
                            ? null
                            : (_) => onSelected(i),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
    }
  }
}

/// D225: a short list to pick one value from (the question time, …),
/// on the white live sheet; returns the index picked, or null.
Future<int?> showLiveSettingsPicker(
  BuildContext context, {
  required String title,
  required List<String> options,
  required int selected,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFFFFFFFF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (sheet) => SafeArea(
    top: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LiveWhiteSheetHeader(title: title, centred: true, titleTop: 15.6),
        for (final (i, label) in options.indexed)
          ListTile(
            key: LiveSettingsSheet.optionKey('picker', i),
            title: Text(label),
            trailing: i == selected ? const Icon(Icons.check_rounded) : null,
            onTap: () => Navigator.of(sheet).pop(i),
          ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);
