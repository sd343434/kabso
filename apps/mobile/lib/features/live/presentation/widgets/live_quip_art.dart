import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D154: the emoji of a quip by its `assetKey` (`quips/<sound>` for the
/// free sounds, `quips/<kind>` for the lines: D154's Egyptian ghazal / funny
/// / tease, D349's gulf / jordan) — Unicode emoji, the owner's sounds have no
/// picture of their own. An unknown key (a newer server's) shows 🎙️.
String quipEmoji(String assetKey) => switch (assetKey) {
  'quips/clap' => '👏',
  'quips/laugh' => '😂',
  'quips/welcome' => '👋',
  'quips/wow' => '😮',
  'quips/tada' => '🥁',
  'quips/ya_salam' => '❤️',
  'quips/bell' => '🔔',
  'quips/sad' => '😢',
  'quips/ghazal' => '😍',
  'quips/funny' => '🤣',
  'quips/tease' => '😏',
  'quips/gulf' => '😎',
  'quips/jordan' => '🔥',
  _ => '🎙️',
};

/// The quip art key of a sound when the catalogue is not loaded yet:
/// `room/clap` → `quips/clap`, `kabi/ghazal_01` → `quips/ghazal`,
/// `gulf/gulf_01` → `quips/gulf` (D349; the server's `quipAssetKey`).
String quipAssetOf(String soundKey) {
  final name = soundKey.split('/').last;
  return soundKey.startsWith('room/')
      ? 'quips/$name'
      : 'quips/${name.split('_').first}';
}

/// D216: Kabso's own art for a quip by its `assetKey` — the owner's Kabi
/// (and Kiki's clap) Lottie emojis, crisp at any size; [quipEmoji] stays the
/// text form (screen readers, chat).
KabsoEmoji quipArt(String assetKey) => switch (assetKey) {
  'quips/clap' => KabsoEmoji.byKey('kiki_clap')!,
  'quips/laugh' => KabsoEmoji.kabi('lol'),
  'quips/welcome' => KabsoEmoji.kabi('hi'),
  'quips/wow' => KabsoEmoji.kabi('wow'),
  'quips/tada' => KabsoEmoji.kabi('party'),
  'quips/ya_salam' => KabsoEmoji.kabi('love'),
  'quips/bell' => KabsoEmoji.kabi('star'),
  'quips/sad' => KabsoEmoji.kabi('sad'),
  'quips/ghazal' => KabsoEmoji.kabi('kiss'),
  'quips/funny' => KabsoEmoji.kabi('silly'),
  'quips/tease' => KabsoEmoji.kabi('wink'),
  // D349: the Gulf and Jordanian lines (Kabso's own Kabi art).
  'quips/gulf' => KabsoEmoji.kabi('cool'),
  'quips/jordan' => KabsoEmoji.kabi('fire'),
  _ => KabsoEmoji.kabi('sing'),
};

/// A quip's art (D216: its Kabi emoji) in a soft round badge with a warm
/// glow. [play] loops the art (off: its first frame).
class LiveQuipBadge extends StatelessWidget {
  const new({
    required this.assetKey,
    super.key,
    this.size = 40,
    this.play = false,
  });

  final String assetKey;
  final double size;
  final bool play;

  /// Off in widget tests (the Lottie loops forever;
  /// `test/flutter_test_config.dart`).
  static bool animate = true;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [Color(0x40FF3B47), Color(0x14FFFFFF)]),
      border: Border.fromBorderSide(BorderSide(color: Color(0x1FFFFFFF))),
    ),
    // The Lottie canvas has a wide margin around the character.
    child: OverflowBox(
      maxWidth: size * 1.3,
      maxHeight: size * 1.3,
      child: KabiEmoji(
        quipArt(assetKey),
        size: size * 1.3,
        animate: play && animate,
      ),
    ),
  );
}

/// D224: the art key of [quip] — its catalogue gift's ([gift]), else the
/// one its sound names.
String quipAssetKeyOf(LiveQuip quip, Gift? gift) =>
    gift?.assetKey ?? quipAssetOf(quip.soundKey);

/// D224: what [quip] says on its strip and chat line — its words, else its
/// catalogue gift's name ([gift]), else its art's name.
String quipWordsOf(AppLocalizations l10n, LiveQuip quip, Gift? gift) =>
    quip.text ?? gift?.name ?? quipArt(quipAssetKeyOf(quip, gift)).label(l10n);

/// D224: a quip's Kabi art at [size] in a strip or a chat line (no badge:
/// the Lottie canvas's margin is let out round it, like [LiveQuipBadge]).
class LiveQuipArt extends StatelessWidget {
  const new({required this.assetKey, required this.size, super.key});

  final String assetKey;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: OverflowBox(
      maxWidth: size * 1.3,
      maxHeight: size * 1.3,
      child: KabiEmoji(
        quipArt(assetKey),
        size: size * 1.3,
        animate: LiveQuipBadge.animate,
      ),
    ),
  );
}
