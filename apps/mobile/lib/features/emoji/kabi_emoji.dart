import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

/// The owner's animated Kabi emojis (D66): Lottie, 512×512, 60 fps, a
/// seamless 2 s loop, with a sticker outline added so Kabi reads on light
/// and dark backgrounds (`tool/kabi_emoji_outline.py`).
///
/// In text an emoji is the token `:kabi_<id>:` (proposal CP-003), so a
/// message or comment stays plain text that any client can show.
enum KabiEmojis {
  hi('hi'),
  love('love'),
  lol('lol'),
  wow('wow'),
  sad('sad'),
  angry('angry'),
  wink('wink'),
  live('live'),
  cool('cool'),
  dizzy('dizzy'),
  sleepy('sleepy'),
  silly('silly'),
  shy('shy'),
  think('think'),
  party('party'),
  dead('dead'),
  melt('melt'),
  kiss('kiss');

  new(this.id);

  final String id;

  String get asset => 'assets/emojis/kabi_$id.json';

  /// The text form of this emoji.
  String get token => ':kabi_$id:';

  static final Map<String, KabiEmojis> _byId = {
    for (final e in values) e.id: e,
  };

  /// `:kabi_<id>:` anywhere in a text. Unknown ids stay plain text.
  static final RegExp tokenPattern = RegExp(':kabi_([a-z]+):');

  static KabiEmojis? byId(String id) => _byId[id];

  /// The name a screen reader says, in the app language.
  String label(AppLocalizations l10n) => switch (this) {
    hi => l10n.kabiEmojiHi,
    love => l10n.kabiEmojiLove,
    lol => l10n.kabiEmojiLol,
    wow => l10n.kabiEmojiWow,
    sad => l10n.kabiEmojiSad,
    angry => l10n.kabiEmojiAngry,
    wink => l10n.kabiEmojiWink,
    live => l10n.kabiEmojiLive,
    cool => l10n.kabiEmojiCool,
    dizzy => l10n.kabiEmojiDizzy,
    sleepy => l10n.kabiEmojiSleepy,
    silly => l10n.kabiEmojiSilly,
    shy => l10n.kabiEmojiShy,
    think => l10n.kabiEmojiThink,
    party => l10n.kabiEmojiParty,
    dead => l10n.kabiEmojiDead,
    melt => l10n.kabiEmojiMelt,
    kiss => l10n.kabiEmojiKiss,
  };
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

  final KabiEmojis emoji;
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
  for (final m in KabiEmojis.tokenPattern.allMatches(text)) {
    final emoji = KabiEmojis.byId(m.group(1)!);
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

/// [text] as a screen reader says it: each token becomes the emoji's name.
String kabiSpokenText(String text, AppLocalizations l10n) => text
    .replaceAllMapped(KabiEmojis.tokenPattern, (m) {
      final emoji = KabiEmojis.byId(m.group(1)!);
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
  static List<KabiEmojis>? onlyEmojis(String text) {
    final rest = text.replaceAll(KabiEmojis.tokenPattern, '').trim();
    if (rest.isNotEmpty) return null;
    final found = [
      for (final m in KabiEmojis.tokenPattern.allMatches(text))
        ?KabiEmojis.byId(m.group(1)!),
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
    for (final m in KabiEmojis.tokenPattern.allMatches(text)) {
      final emoji = KabiEmojis.byId(m.group(1)!);
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
      child: Text.rich(
        TextSpan(children: spans),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

/// Opens the Kabi emoji picker; resolves to the chosen emoji, or null.
Future<KabiEmojis?> showKabiEmojiPicker(BuildContext context) =>
    showModalBottomSheet<KabiEmojis>(
      context: context,
      showDragHandle: true,
      builder: (_) => const KabiEmojiPicker(),
    );

/// A grid of all Kabi emojis. They stay still (less motion, less work)
/// and play while pressed; tapping one returns it.
class KabiEmojiPicker extends StatefulWidget {
  const new({super.key});

  static const gridKey = Key('kabiEmoji.picker');
  static Key itemKey(KabiEmojis e) => Key('kabiEmoji.${e.id}');

  @override
  State<KabiEmojiPicker> createState() => _KabiEmojiPickerState();
}

class _KabiEmojiPickerState extends State<KabiEmojiPicker> {
  KabiEmojis? _pressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.md,
          0,
          KSpacing.md,
          KSpacing.md,
        ),
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
            const SizedBox(height: KSpacing.md),
            Flexible(
              child: GridView.extent(
                key: KabiEmojiPicker.gridKey,
                shrinkWrap: true,
                maxCrossAxisExtent: KKabiEmoji.picker + KSpacing.md,
                children: [
                  for (final e in KabiEmojis.values)
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
            ),
          ],
        ),
      ),
    );
  }
}
