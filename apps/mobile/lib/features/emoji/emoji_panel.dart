import 'package:kabso_live/core/emoji/unicode_emoji.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// One tab of the [EmojiPanel] strip: one of the owner's packs (D102) or a
/// Unicode group (D131).
@immutable
sealed class EmojiPanelTab {
  const new();

  /// The owner's nine packs first, then (unless [packsOnly]) the Unicode
  /// groups (D138).
  static List<EmojiPanelTab> all({bool packsOnly = false}) => [
    for (final p in EmojiPack.values) EmojiPackTab(p),
    if (!packsOnly)
      for (final g in UnicodeEmojiGroup.values) UnicodeEmojiTab(g),
  ];

  /// Stable name (keys, scroll positions).
  String get name;

  /// What a screen reader says for the tab.
  String label(AppLocalizations l10n);
}

@immutable
final class EmojiPackTab extends EmojiPanelTab {
  const new(this.pack);

  final EmojiPack pack;

  @override
  String get name => 'pack.${pack.name}';

  @override
  String label(AppLocalizations l10n) => pack.label(l10n);

  @override
  bool operator ==(Object other) => other is EmojiPackTab && other.pack == pack;

  @override
  int get hashCode => pack.hashCode;
}

@immutable
final class UnicodeEmojiTab extends EmojiPanelTab {
  const new(this.group);

  final UnicodeEmojiGroup group;

  @override
  String get name => 'unicode.${group.name}';

  @override
  String label(AppLocalizations l10n) => switch (group) {
    UnicodeEmojiGroup.smileys => l10n.liveEmojiSmileys,
    UnicodeEmojiGroup.people => l10n.liveEmojiPeople,
    UnicodeEmojiGroup.love => l10n.liveEmojiLove,
    UnicodeEmojiGroup.animals => l10n.liveEmojiAnimals,
    UnicodeEmojiGroup.food => l10n.liveEmojiFood,
    UnicodeEmojiGroup.activities => l10n.liveEmojiActivities,
    UnicodeEmojiGroup.travel => l10n.liveEmojiTravel,
    UnicodeEmojiGroup.objects => l10n.liveEmojiObjects,
    UnicodeEmojiGroup.symbols => l10n.liveEmojiSymbols,
  };

  @override
  bool operator ==(Object other) =>
      other is UnicodeEmojiTab && other.group == group;

  @override
  int get hashCode => group.hashCode;
}

/// The panel's colours: the live chat box keeps ref 162's white panel
/// ([EmojiPanelColors.live]); private messages follow the app theme
/// ([EmojiPanelColors.of]).
@immutable
final class EmojiPanelColors {
  const new({required this.ink, required this.selected});

  /// The app theme (light and dark).
  factory of(BuildContext context) {
    final p = context.palette;
    return EmojiPanelColors(ink: p.textPrimary, selected: p.surfaceOverlay);
  }

  /// Ref 162 (D131): dark ink, the chosen tab on a `#F5F7F9` cell.
  static const live = EmojiPanelColors(
    ink: Color(0xFF1C1B2E),
    selected: Color(0xFFF5F7F9),
  );

  final Color ink;
  final Color selected;
}

/// D138 (owner): the one emoji panel of the live chat box (D131, ref 162)
/// and of private messages — the owner's nine packs first in the strip
/// (each tab shows one of its emojis, as in D102), then the Unicode groups;
/// the chosen tab's emojis in a 5-column grid (ref 162's pitch).
///
/// Pack emojis play (Lottie) in the grid; only the chosen tab is built and
/// only the cells on screen (the grid builds lazily, so an emoji scrolled
/// away stops and is let go); a composition loads once and stays in
/// Lottie's shared cache. With reduced motion each shows its first frame.
/// A tap gives [onEmoji] the text to insert: the pack token (`:<pack>_<id>:`,
/// CP-003) or the Unicode emoji. With [onPack] a pack emoji goes there
/// instead (the seat emoji sheet, where [packsOnly] hides the Unicode
/// groups).
class EmojiPanel extends StatefulWidget {
  const new({
    required this.onEmoji,
    super.key,
    this.onPack,
    this.colors = EmojiPanelColors.live,
    this.packsOnly = false,
    this.height = gridHeight,
    this.animate = true,
  });

  final ValueChanged<String> onEmoji;
  final ValueChanged<KabsoEmoji>? onPack;
  final EmojiPanelColors colors;
  final bool packsOnly;

  /// The grid's height.
  final double height;

  /// False keeps the pack emojis still (first frame).
  final bool animate;

  static Key tabKey(EmojiPanelTab tab) => Key('emojiPanel.tab.${tab.name}');
  static Key unicodeKey(String emoji) => Key('emojiPanel.unicode.$emoji');
  static Key packKey(KabsoEmoji emoji) => Key('emojiPanel.pack.${emoji.key}');
  static const gridKey = Key('emojiPanel.grid');

  /// Ref 162: 5 columns 75.8 pt apart, rows 73.3 pt; the strip's tabs 43 pt
  /// apart, the chosen one on a 41.7 × 27.7 pt cell.
  static const gridColumns = 5;
  static const gridRow = 73.3;
  static const gridHeight = 250.0;
  static const glyph = 34.0;
  static const tabPitch = 43.0;

  /// A pack emoji's Lottie canvas in the grid (the character fills about
  /// 77 % of it, so it reads as large as the 34 pt glyphs' neighbours).
  static const packCell = 52.0;

  /// A pack's tab icon (its canvas).
  static const packTab = 30.0;

  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<EmojiPanel> {
  late final List<EmojiPanelTab> _tabs = EmojiPanelTab.all(
    packsOnly: widget.packsOnly,
  );
  late EmojiPanelTab _tab = _tabs.first;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = widget.colors;
    final glyph = context.textStyles.body.copyWith(
      fontSize: EmojiPanel.glyph,
      height: 1.15,
      color: colors.ink,
    );
    final tab = _tab;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            itemExtent: EmojiPanel.tabPitch,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 9),
            children: [
              for (final t in _tabs)
                Semantics(
                  button: true,
                  selected: t == tab,
                  label: t.label(l10n),
                  excludeSemantics: true,
                  child: GestureDetector(
                    key: EmojiPanel.tabKey(t),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _tab = t),
                    child: Center(
                      child: Container(
                        width: 41.7,
                        height: 27.7,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: t == tab ? colors.selected : null,
                          borderRadius: BorderRadius.circular(13.9),
                        ),
                        child: switch (t) {
                          // D102: the pack's character stands for it (still).
                          EmojiPackTab(:final pack) => OverflowBox(
                            maxWidth: EmojiPanel.packTab,
                            maxHeight: EmojiPanel.packTab,
                            child: KabiEmoji(
                              pack.icon,
                              size: EmojiPanel.packTab,
                              animate: false,
                            ),
                          ),
                          UnicodeEmojiTab(:final group) => Text(
                            group.icon,
                            textScaler: TextScaler.noScaling,
                            style: glyph.copyWith(fontSize: 19, height: 1.1),
                          ),
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: widget.height,
          child: switch (tab) {
            EmojiPackTab(:final pack) => _grid(
              tab,
              pack.ids.length,
              (i) => _packCell(pack.emojis[i], l10n),
            ),
            UnicodeEmojiTab(:final group) => _grid(
              tab,
              group.emojis.length,
              (i) => _unicodeCell(group.emojis[i], glyph),
            ),
          },
        ),
      ],
    );
  }

  Widget _grid(EmojiPanelTab tab, int count, Widget Function(int) cell) =>
      GridView.builder(
        key: PageStorageKey('emojiPanel.grid.${tab.name}'),
        padding: const EdgeInsets.fromLTRB(8.3, 6, 8.3, 4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: EmojiPanel.gridColumns,
          mainAxisExtent: EmojiPanel.gridRow,
        ),
        itemCount: count,
        itemBuilder: (context, i) => cell(i),
      );

  Widget _packCell(KabsoEmoji e, AppLocalizations l10n) {
    void tap() {
      final onPack = widget.onPack;
      if (onPack != null) {
        onPack(e);
      } else {
        widget.onEmoji(e.token);
      }
    }

    return Semantics(
      button: true,
      label: e.label(l10n),
      onTap: tap,
      excludeSemantics: true,
      child: GestureDetector(
        key: EmojiPanel.packKey(e),
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: Center(
          child: RepaintBoundary(
            child: KabiEmoji(
              e,
              size: EmojiPanel.packCell,
              animate: widget.animate,
            ),
          ),
        ),
      ),
    );
  }

  Widget _unicodeCell(String e, TextStyle glyph) => Semantics(
    button: true,
    label: e,
    child: GestureDetector(
      key: EmojiPanel.unicodeKey(e),
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onEmoji(e),
      child: Center(
        child: Text(e, style: glyph, textScaler: TextScaler.noScaling),
      ),
    ),
  );
}

/// Puts [text] (an emoji or a pack token) at [controller]'s cursor, or at
/// the end when there is none; nothing when the result would be longer
/// than [maxLength] characters.
void insertEmojiText(
  TextEditingController controller,
  String text, {
  int? maxLength,
}) {
  final value = controller.value;
  final sel = value.selection;
  final current = value.text;
  final start = sel.isValid ? sel.start : current.length;
  final end = sel.isValid ? sel.end : current.length;
  final next = current.replaceRange(start, end, text);
  if (maxLength != null && next.characters.length > maxLength) return;
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: start + text.length),
  );
}
