import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:kabso_live/features/emoji/emoji_names.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/status/status_names.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// «الحالة» (D376, contract v1.130-social, CONVENTIONS §10.167): the
/// animated emoji a person wears over their picture. An id is
/// `<pack>.<emoji>` (`kabi.crown`, `flags.jo`, `noto.fire`,
/// `premium.eagle`), stored by the server (`statusEmojiId`), which keeps the
/// same allow-list (`apps/api/src/modules/status-emoji/
/// status-emoji-catalogue.ts`; a server unit test reads this file and
/// `kabi_emoji.dart` to keep the two in step). Never rename an id.
///
/// The Kabso packs are [EmojiPack] (the chat emoji, D66 / D102 — no asset is
/// duplicated); «عام» and «المميزة» are Google Noto animated emoji
/// (CC BY 4.0, `assets/emojis/noto/`, PROVENANCE.md). The owner's own
/// premium designs go in `assets/emojis/premium/` and in [_premium] when
/// supplied.

/// The attribution CC BY 4.0 requires for the Noto animated emoji (shown in
/// Settings › Licenses and on the licences page).
const kNotoEmojiAttribution =
    'Animated emoji by Google (Noto Emoji), CC BY 4.0';

/// Adds the Noto animated emoji's licence to the app's licences page.
void registerStatusEmojiLicense() => LicenseRegistry.addLicense(
  () => Stream.value(
    const LicenseEntryWithLineBreaks(
      ['Noto Emoji (animated)'],
      '$kNotoEmojiAttribution\n\n'
      'The animated emoji of the «الحالة» packs «عام» and «المميزة» are '
      "Google's Noto Animated Emoji, licensed under the Creative Commons "
      'Attribution 4.0 International licence: '
      'https://creativecommons.org/licenses/by/4.0/',
    ),
  ),
);

/// Free (every account) or sold in «متجر الحالة» (the whole pack, for a
/// time).
enum StatusPackKind { free, store }

/// One status emoji.
@immutable
final class StatusEmoji {
  const new _({
    required this.id,
    required this.packId,
    required this.asset,
    this.faceSway = false,
    this.kabso,
  });

  /// `<pack>.<emoji>`, as stored by the server.
  final String id;
  final String packId;

  /// The Lottie asset.
  final String asset;

  /// Birds look left / right as they sway (they seem to fly).
  final bool faceSway;

  /// The chat emoji behind a Kabso pack's status (its name and asset).
  final KabsoEmoji? kabso;

  /// The name a screen reader says and the picker shows.
  String label(AppLocalizations l10n) =>
      kabso?.label(l10n) ?? statusEmojiName(l10n, id);

  @override
  bool operator ==(Object other) => other is StatusEmoji && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

/// A tab of the picker.
@immutable
final class StatusPack {
  const new _({required this.id, required this.kind, required this.emojis});

  final String id;
  final StatusPackKind kind;
  final List<StatusEmoji> emojis;

  StatusEmoji get icon => emojis.first;

  String label(AppLocalizations l10n) => switch (id) {
    'noto' => l10n.statusPackGeneral,
    'premium' => l10n.statusPackPremium,
    _ => emojiPackName(l10n, id),
  };
}

/// A Noto / premium emoji of this file: its id and Noto code point file
/// (`assets/emojis/noto/<code>.json`).
@immutable
final class StatusEmojiSpec {
  const new(this.id, this.code, {this.faceSway = false});

  final String id;
  final String code;
  final bool faceSway;
}

/// «عام» — 24 Google Noto animated emoji (CC BY 4.0).
const List<StatusEmojiSpec> _noto = [
  StatusEmojiSpec('noto.happy', '1f600'),
  StatusEmojiSpec('noto.laugh', '1f602'),
  StatusEmojiSpec('noto.love', '1f970'),
  StatusEmojiSpec('noto.heart_eyes', '1f60d'),
  StatusEmojiSpec('noto.cool', '1f60e'),
  StatusEmojiSpec('noto.star_struck', '1f929'),
  StatusEmojiSpec('noto.party', '1f973'),
  StatusEmojiSpec('noto.innocent', '1f607'),
  StatusEmojiSpec('noto.wink_tongue', '1f61c'),
  StatusEmojiSpec('noto.hug', '1f917'),
  StatusEmojiSpec('noto.kiss', '1f618'),
  StatusEmojiSpec('noto.thinking', '1f914'),
  StatusEmojiSpec('noto.sleepy', '1f634'),
  StatusEmojiSpec('noto.eye_roll', '1f644'),
  StatusEmojiSpec('noto.sad', '1f622'),
  StatusEmojiSpec('noto.crying', '1f62d'),
  StatusEmojiSpec('noto.angry', '1f621'),
  StatusEmojiSpec('noto.shocked', '1f631'),
  StatusEmojiSpec('noto.heart', '2764_fe0f'),
  StatusEmojiSpec('noto.fire', '1f525'),
  StatusEmojiSpec('noto.hundred', '1f4af'),
  StatusEmojiSpec('noto.thumbs_up', '1f44d'),
  StatusEmojiSpec('noto.congrats', '1f389'),
  StatusEmojiSpec('noto.thanks', '1f64f'),
];

/// «المميزة» — sold in «متجر الحالة» (owner: 100 000 coins / 30 days, the
/// server's price): 9 birds (they face the way they sway) and 18 luxury
/// symbols, all Google Noto animated emoji (CC BY 4.0). The owner's list
/// had 29: the parrot (1F99C) and the money bag (1F4B0) are not in Noto's
/// animated set and are left out.
const List<StatusEmojiSpec> _premium = [
  StatusEmojiSpec('premium.bird', '1f426', faceSway: true),
  StatusEmojiSpec('premium.dove', '1f54a_fe0f', faceSway: true),
  StatusEmojiSpec('premium.eagle', '1f985', faceSway: true),
  StatusEmojiSpec('premium.owl', '1f989', faceSway: true),
  StatusEmojiSpec('premium.flamingo', '1f9a9', faceSway: true),
  StatusEmojiSpec('premium.peacock', '1f99a', faceSway: true),
  StatusEmojiSpec('premium.penguin', '1f427', faceSway: true),
  StatusEmojiSpec('premium.chick', '1f424', faceSway: true),
  StatusEmojiSpec('premium.hatching', '1f423', faceSway: true),
  StatusEmojiSpec('premium.crown', '1f451'),
  StatusEmojiSpec('premium.diamond', '1f48e'),
  StatusEmojiSpec('premium.rocket', '1f680'),
  StatusEmojiSpec('premium.lion', '1f981'),
  StatusEmojiSpec('premium.rich', '1f911'),
  StatusEmojiSpec('premium.trophy', '1f3c6'),
  StatusEmojiSpec('premium.glow_star', '1f31f'),
  StatusEmojiSpec('premium.sparkles', '2728'),
  StatusEmojiSpec('premium.unicorn', '1f984'),
  StatusEmojiSpec('premium.dragon', '1f409'),
  StatusEmojiSpec('premium.rose', '1f339'),
  StatusEmojiSpec('premium.gift', '1f381'),
  StatusEmojiSpec('premium.fireworks', '1f386'),
  StatusEmojiSpec('premium.rainbow', '1f308'),
  StatusEmojiSpec('premium.sparkling_heart', '1f496'),
  StatusEmojiSpec('premium.champagne', '1f37e'),
  StatusEmojiSpec('premium.cheers', '1f942'),
  StatusEmojiSpec('premium.devil', '1f608'),
  // D374 hook: the VIP perk catalogue (another branch) or the owner's own
  // designs add emojis here — Lottie in `assets/emojis/premium/` (declare the
  // folder in pubspec.yaml), the same id in the server's allow-list: e.g. the
  // id `premium.falcon` with the code `premium/falcon` and faceSway true.
];

List<StatusEmoji> _fromSpecs(String pack, List<StatusEmojiSpec> specs) => [
  for (final s in specs)
    StatusEmoji._(
      id: s.id,
      packId: pack,
      asset: s.code.contains('/')
          ? 'assets/emojis/${s.code}.json'
          : 'assets/emojis/noto/${s.code}.json',
      faceSway: s.faceSway,
    ),
];

/// Every status pack, in the picker's tab order: Kabso's own, «عام», then the
/// store's.
abstract final class StatusCatalogue {
  /// The Kabso order of the picker: Kabi first, the flags last.
  static const List<EmojiPack> _kabsoOrder = [
    EmojiPack.kabi,
    EmojiPack.neno,
    EmojiPack.kiki,
    EmojiPack.boo,
    EmojiPack.pipo,
    EmojiPack.dubi,
    EmojiPack.gogo,
    EmojiPack.lulu,
    EmojiPack.flags,
  ];

  static final List<StatusPack> packs = [
    for (final pack in _kabsoOrder)
      StatusPack._(
        id: pack.name,
        kind: StatusPackKind.free,
        emojis: [
          for (final e in pack.emojis)
            StatusEmoji._(
              id: '${pack.name}.${e.id}',
              packId: pack.name,
              asset: e.asset,
              kabso: e,
            ),
        ],
      ),
    StatusPack._(
      id: 'noto',
      kind: StatusPackKind.free,
      emojis: _fromSpecs('noto', _noto),
    ),
    StatusPack._(
      id: 'premium',
      kind: StatusPackKind.store,
      emojis: _fromSpecs('premium', _premium),
    ),
  ];

  static final Map<String, StatusEmoji> _byId = {
    for (final p in packs)
      for (final e in p.emojis) e.id: e,
  };

  static final Map<String, StatusPack> _packs = {
    for (final p in packs) p.id: p,
  };

  /// The emoji of [id]; null for none or an id this app does not know (a
  /// newer server's emoji shows nothing rather than a wrong one).
  static StatusEmoji? byId(String? id) => id == null ? null : _byId[id];

  static StatusPack? pack(String id) => _packs[id];

  /// The pack of [emoji].
  static StatusPack packOf(StatusEmoji emoji) => _packs[emoji.packId]!;

  /// The packs sold in «متجر الحالة».
  static Iterable<StatusPack> get storePacks =>
      packs.where((p) => p.kind == StatusPackKind.store);
}
