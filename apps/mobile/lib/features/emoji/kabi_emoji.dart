import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/emoji_names.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

/// The owner's animated emojis (D66; more packs D102): Lottie, 512×512,
/// 60 fps, a seamless 2 s loop. Each pack is one character with its own
/// style; the picker shows one tab per pack. Kabi has a sticker outline so
/// it reads on light and dark backgrounds (`tool/kabi_emoji_outline.py`).
///
/// In text an emoji is the token `:<pack>_<id>:` (proposal CP-003, e.g.
/// `:kabi_love:`, `:kiki_clap:`), so a message or comment stays plain text
/// that any client can show; an unknown token stays text.
enum EmojiPack {
  kabi('hi', [
    'hi',
    'love',
    'lol',
    'wow',
    'sad',
    'angry',
    'wink',
    'live',
    'cool',
    'dizzy',
    'sleepy',
    'silly',
    'shy',
    'think',
    'party',
    'dead',
    'melt',
    'kiss',
    'gift',
    'fire',
    'crown',
    'money',
    'sing',
    'star',
  ]),
  kiki('love', [
    'hi',
    'love',
    'lol',
    'wow',
    'sad',
    'angry',
    'cool',
    'sleepy',
    'wink',
    'kiss',
    'sing',
    'shy',
    'think',
    'party',
    'clap',
    'fire',
    'ok',
    'dizzy',
  ]),
  boo('boo', [
    'boo',
    'scared',
    'fade',
    'peek',
    'spin',
    'laugh',
    'love',
    'cry',
    'sneaky',
    'sleep',
    'shock',
    'party',
  ]),
  pipo('hi', [
    'hi',
    'chirp',
    'hungry',
    'cold',
    'fly',
    'love',
    'cry',
    'angry',
    'sleepy',
    'yay',
    'shy',
    'wow',
  ]),
  dubi('hug', [
    'hug',
    'thanks',
    'strong',
    'honey',
    'sleep',
    'grr',
    'lol',
    'love',
    'cool',
    'ok',
    'sad',
    'clap',
  ]),
  gogo('roar', [
    'hi',
    'roar',
    'stomp',
    'hatch',
    'munch',
    'dance',
    'sneeze',
    'cool',
    'love',
    'lol',
    'cry',
    'wow',
  ]),
  lulu('sun', [
    'hi',
    'sun',
    'rain',
    'thunder',
    'rainbow',
    'snow',
    'wind',
    'sleep',
    'love',
    'wow',
    'lol',
    'shy',
  ]),
  neno('hi', [
    'hi',
    'love',
    'lol',
    'wow',
    'cry',
    'angry',
    'cool',
    'think',
    'wink',
    'sleepy',
    'money',
    'ok',
    'clap',
    'party',
    'kiss',
    'blush',
    'rose',
    'heartbeat',
    'flirt',
    'melt',
    'iloveu',
    'serenade',
  ]),
  flags('jo', [
    'jo',
    'ps',
    'sa',
    'eg',
    'iq',
    'sy',
    'ye',
    'ae',
    'kw',
    'qa',
    'bh',
    'om',
    'lb',
    'ma',
    'dz',
    'tn',
    'ly',
    'sd',
  ]);

  new(this.iconId, this.ids);

  /// The emoji that stands for the pack on its tab.
  final String iconId;
  final List<String> ids;

  List<KabsoEmoji> get emojis => [for (final id in ids) KabsoEmoji._(this, id)];

  KabsoEmoji get icon => KabsoEmoji._(this, iconId);

  /// The tab name, in the app language.
  String label(AppLocalizations l10n) => emojiPackName(l10n, name);
}

/// One animated emoji of a pack.
@immutable
final class KabsoEmoji {
  const new _(this.pack, this.id);

  final EmojiPack pack;
  final String id;

  /// Every emoji, pack by pack.
  static final List<KabsoEmoji> values = [
    for (final p in EmojiPack.values) ...p.emojis,
  ];

  static final Map<String, KabsoEmoji> _byKey = {
    for (final e in values) e.key: e,
  };

  /// A Kabi emoji by id (`love`, `live` …); throws for an unknown id.
  static KabsoEmoji kabi(String id) => _byKey['kabi_$id']!;

  /// `<pack>_<id>`, as in the token and the asset file.
  String get key => '${pack.name}_$id';

  String get asset => 'assets/emojis/${pack.name}/$key.json';

  /// The text form of this emoji.
  String get token => ':$key:';

  /// `:<pack>_<id>:` anywhere in a text. Unknown ids stay plain text.
  static final RegExp tokenPattern = RegExp(
    ':((?:${EmojiPack.values.map((p) => p.name).join('|')})_[a-z]+):',
  );

  /// The emoji of a token's `<pack>_<id>` ([tokenPattern] group 1).
  static KabsoEmoji? byKey(String key) => _byKey[key];

  /// The name a screen reader says, in the app language.
  String label(AppLocalizations l10n) => emojiName(l10n, key);

  @override
  bool operator ==(Object other) =>
      other is KabsoEmoji && other.pack == pack && other.id == id;

  @override
  int get hashCode => Object.hash(pack, id);

  @override
  String toString() => token;
}

/// Sizes of the Kabi emojis (D66).
abstract final class KKabiEmoji {
  /// Inline in text: this many times the font size (the Lottie canvas has
  /// a wide margin around Kabi).
  static const double inlineScale = 2.2;

  /// A message or comment that is only emojis (up to [bigMaxCount]).
  static const double big = 96;
  static const int bigMaxCount = 3;

  static const double picker = 52;
}

/// One animated emoji. It loops unless [animate] is false or the user
/// asked for reduced motion (then it shows its first frame).
class KabiEmoji extends StatelessWidget {
  const new(
    this.emoji, {
    super.key,
    this.size = 48,
    this.animate = true,
    this.repeat = true,
    this.semanticLabel,
  });

  final KabsoEmoji emoji;
  final double size;
  final bool animate;

  /// Plays once and holds the last frame when false.
  final bool repeat;

  /// Announced by screen readers; without it the emoji is decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final moving = animate && !MediaQuery.disableAnimationsOf(context);
    final lottie = Lottie.asset(
      emoji.asset,
      width: size,
      height: size,
      animate: moving,
      repeat: repeat,
      frameRate: FrameRate.max,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
    );
    final label = semanticLabel;
    return label == null
        ? ExcludeSemantics(child: lottie)
        : Semantics(
            label: label,
            image: true,
            child: ExcludeSemantics(child: lottie),
          );
  }
}

/// [text] with each `:kabi_<id>:` token as an inline animated emoji of
/// [size] (unknown ids stay text). The spans take the enclosing style.
List<InlineSpan> kabiInlineSpans(String text, {required double size}) {
  final spans = <InlineSpan>[];
  var start = 0;
  for (final m in KabsoEmoji.tokenPattern.allMatches(text)) {
    final emoji = KabsoEmoji.byKey(m.group(1)!);
    if (emoji == null) continue;
    if (m.start > start) {
      spans.add(TextSpan(text: text.substring(start, m.start)));
    }
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: KabiEmoji(emoji, size: size),
      ),
    );
    start = m.end;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return spans;
}

/// D141: [kabiInlineSpans] for a message inside a line of another
/// direction (the chat rows: badges and a name first). A message with
/// letters of its own is isolated (FSI … PDI) so it keeps its order; a
/// message of emojis and punctuation only is not — an empty FSI would read
/// it left to right even in an Arabic line, so it follows the line instead.
List<InlineSpan> kabiIsolatedSpans(String text, {required double size}) {
  final spans = kabiInlineSpans(text, size: size);
  final letters = text.replaceAll(KabsoEmoji.tokenPattern, '');
  if (!_strong.hasMatch(letters)) return spans;
  return [
    const TextSpan(text: '\u2068'),
    ...spans,
    const TextSpan(text: '\u2069'),
  ];
}

/// A letter with a direction (Latin, Arabic, Hebrew and the like).
final _strong = RegExp(
  r'[A-Za-z\u00C0-\u024F\u0370-\u03FF\u0400-\u04FF\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
);

/// [text] as a screen reader says it: each token becomes the emoji's name.
String kabiSpokenText(String text, AppLocalizations l10n) => text
    .replaceAllMapped(KabsoEmoji.tokenPattern, (m) {
      final emoji = KabsoEmoji.byKey(m.group(1)!);
      return emoji == null ? m.group(0)! : ' ${emoji.label(l10n)} ';
    })
    .replaceAll(RegExp(' {2,}'), ' ')
    .trim();

/// A text in which `:kabi_<id>:` tokens show as animated emojis (D66).
/// A text made only of emojis (up to [KKabiEmoji.bigMaxCount]) shows them
/// big, like a sticker. Screen readers hear the emoji names.
class KabiEmojiText extends StatelessWidget {
  const new(this.text, {required this.style, super.key, this.textAlign});

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  /// The emojis of [text] when it holds nothing else, else null.
  static List<KabsoEmoji>? onlyEmojis(String text) {
    final rest = text.replaceAll(KabsoEmoji.tokenPattern, '').trim();
    if (rest.isNotEmpty) return null;
    final found = [
      for (final m in KabsoEmoji.tokenPattern.allMatches(text))
        ?KabsoEmoji.byKey(m.group(1)!),
    ];
    if (found.isEmpty || found.length > KKabiEmoji.bigMaxCount) return null;
    return found;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final big = onlyEmojis(text);
    if (big != null) {
      return Semantics(
        label: big.map((e) => e.label(l10n)).join(' '),
        image: true,
        excludeSemantics: true,
        child: Wrap(
          children: [for (final e in big) KabiEmoji(e, size: KKabiEmoji.big)],
        ),
      );
    }
    final size = (style.fontSize ?? 14) * KKabiEmoji.inlineScale;
    final spans = <InlineSpan>[];
    final spoken = StringBuffer();
    var start = 0;
    for (final m in KabsoEmoji.tokenPattern.allMatches(text)) {
      final emoji = KabsoEmoji.byKey(m.group(1)!);
      if (emoji == null) continue;
      if (m.start > start) {
        final part = text.substring(start, m.start);
        spans.add(TextSpan(text: part));
        spoken.write(part);
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: KabiEmoji(emoji, size: size),
        ),
      );
      spoken.write(' ${emoji.label(l10n)} ');
      start = m.end;
    }
    if (spans.isEmpty) {
      return Text(text, style: style, textAlign: textAlign);
    }
    if (start < text.length) {
      final part = text.substring(start);
      spans.add(TextSpan(text: part));
      spoken.write(part);
    }
    return Semantics(
      label: spoken.toString().trim(),
      excludeSemantics: true,
      // D141: pack emoji in reading order in right-to-left text too.
      child: KBidiRichText(
        TextSpan(style: style, children: spans),
        textAlign: textAlign,
      ),
    );
  }
}

/// Opens the emoji picker; resolves to the chosen emoji, or null.
Future<KabsoEmoji?> showKabiEmojiPicker(BuildContext context) =>
    showModalBottomSheet<KabsoEmoji>(
      context: context,
      showDragHandle: true,
      builder: (_) => const KabiEmojiPicker(),
    );

/// The emojis in one tab per pack (D102): each tab shows the pack's
/// character and name. The emojis stay still (less motion, less work) and
/// play while pressed; tapping one returns it.
class KabiEmojiPicker extends StatefulWidget {
  const new({super.key});

  static const gridKey = Key('kabiEmoji.picker');
  static Key itemKey(KabsoEmoji e) => Key('kabiEmoji.${e.key}');
  static Key tabKey(EmojiPack p) => Key('kabiEmoji.tab.${p.name}');

  /// The grid area under the tabs (less when the sheet is shorter).
  static const double gridHeight = 300;

  @override
  State<KabiEmojiPicker> createState() => _KabiEmojiPickerState();
}

class _KabiEmojiPickerState extends State<KabiEmojiPicker> {
  KabsoEmoji? _pressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    return SafeArea(
      child: DefaultTabController(
        length: EmojiPack.values.length,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.kabiEmojiPickerTitle,
                textAlign: TextAlign.center,
                style: t.title,
              ),
            ),
            const SizedBox(height: KSpacing.xs),
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: p.textPrimary,
              unselectedLabelColor: p.textSecondary,
              labelStyle: t.caption.copyWith(fontWeight: FontWeight.w600),
              unselectedLabelStyle: t.caption,
              tabs: [
                for (final pack in EmojiPack.values)
                  Tab(
                    key: KabiEmojiPicker.tabKey(pack),
                    height: 58,
                    iconMargin: const EdgeInsets.only(bottom: 2),
                    icon: KabiEmoji(pack.icon, size: 30, animate: false),
                    text: pack.label(l10n),
                  ),
              ],
            ),
            // At most this tall; less on a short screen (the sheet's limit).
            Flexible(
              child: SizedBox(
                height: KabiEmojiPicker.gridHeight,
                child: TabBarView(
                  children: [
                    for (final pack in EmojiPack.values)
                      GridView.extent(
                        key: pack == EmojiPack.kabi
                            ? KabiEmojiPicker.gridKey
                            : null,
                        padding: const EdgeInsets.all(KSpacing.md),
                        maxCrossAxisExtent: KKabiEmoji.picker + KSpacing.md,
                        children: [
                          for (final e in pack.emojis)
                            Semantics(
                              button: true,
                              label: e.label(l10n),
                              excludeSemantics: true,
                              child: InkResponse(
                                key: KabiEmojiPicker.itemKey(e),
                                radius: KKabiEmoji.picker / 2 + KSpacing.xs,
                                onHighlightChanged: (down) =>
                                    setState(() => _pressed = down ? e : null),
                                onTap: () => Navigator.pop(context, e),
                                child: Center(
                                  child: AnimatedScale(
                                    scale: _pressed == e ? 1.25 : 1,
                                    duration: const Duration(milliseconds: 160),
                                    curve: Curves.easeOutBack,
                                    child: KabiEmoji(
                                      e,
                                      size: KKabiEmoji.picker,
                                      animate: _pressed == e,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
