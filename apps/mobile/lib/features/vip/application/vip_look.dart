import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:material_ui/material_ui.dart';

/// D258 (§10.94): the perk codes the app does.
abstract final class VipPerks {
  static const badge = 'BADGE';
  static const avatarFrame = 'AVATAR_FRAME';
  static const nameColor = 'CHAT_NAME_COLOR';
  static const bubble = 'CHAT_BUBBLE';
  static const profileCard = 'PROFILE_CARD';
  static const entryBanner = 'ENTRY_BANNER';
  static const entryEffect = 'ENTRY_EFFECT';
  static const micWave = 'MIC_WAVE';
  static const dailyBullet = 'DAILY_BULLET';
  static const profileVisitors = 'PROFILE_VISITORS';
  static const dailyCoins = 'DAILY_COINS';
  static const levelSpeedup = 'LEVEL_SPEEDUP';
}

/// D258: the VIP catalogue kept for the whole session (every chat line, seat
/// and card reads it); a language change or another person reloads it.
/// Unreadable → null (members show only their tier's colour).
final FutureProvider<VipTierList?> vipCatalogProvider = FutureProvider((
  ref,
) async {
  ref
    ..watch(languageControllerProvider)
    ..watch(currentUserProvider.select((u) => u?.id));
  try {
    return await ref.watch(vipRepositoryProvider).tiers();
  } on Object {
    return null;
  }
});

/// D258: how a member looks — their tier, its colour and the perks they hold
/// (owner: «كل مستوى يحمل امتيازات ما قبله»: every enabled perk of the tiers
/// ordered up to theirs, the highest tier's perk winning for a code).
@immutable
class VipLook {
  const new({required this.vip, required this.perks, this.tier});

  final UserVip vip;

  /// The member's tier in the catalogue (null: not on sale any more, or the
  /// catalogue is unreadable — only the colour is known then).
  final VipTier? tier;

  /// The perks held, by code.
  final Map<String, VipPerk> perks;

  Color get color => Color(vip.color);

  /// The tier's level among those on sale (1 … n), or its rank.
  int get level => tier?.level ?? vip.rank;

  bool has(String code) => perks.containsKey(code);

  VipPerk? perk(String code) => perks[code];

  /// The badge art: the BADGE perk's own, else the tier's crest.
  ({String? animation, String? still}) get badgeArt {
    final p = perks[VipPerks.badge];
    if (p != null && (p.still != null || p.animation != null)) {
      return (animation: p.animation, still: p.still);
    }
    return (animation: tier?.badgeAnimation, still: tier?.badgeStill);
  }

  /// The name colour (CHAT_NAME_COLOR): a bright tint of the tier's colour,
  /// so it reads on the dark chat box and on the tier's own bubble; or null.
  Color? get nameColor => has(VipPerks.nameColor) ? vipNameTint(color) : null;

  /// The bubble's two stops (CHAT_BUBBLE without art): deep shades of the
  /// tier's colour, opaque, so a white text and [nameColor] stay ≥ 4.5:1.
  (Color, Color) get bubbleShades => vipBubbleShades(color);
}

/// WCAG contrast ratio of two opaque colours (1 … 21).
double vipContrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The lightest a VIP bubble or pill may be (relative luminance): white on it
/// is ≥ 7:1 and a name of luminance ≥ [_nameMinLuminance] ≥ 4.5:1 — also
/// under the owner's animated bubble, whose inside adds a light green veil
/// (20 %, [vipBubbleArtVeil]).
const _bubbleMaxLuminance = 0.05;
const _nameMinLuminance = 0.66;

/// The inside of the owner's VIP 1 bubble art (`svip_text_bubble_1`): its
/// light green at 20 % over the plain bubble (measured from the file).
const vipBubbleArtVeil = Color(0x3364B855);

/// [color] mixed toward white (at least 55 %) until it is light enough to read
/// on any VIP bubble and on the dark chat box.
Color vipNameTint(Color color) {
  var t = 0.55;
  var tint = Color.lerp(
    color.withValues(alpha: 1),
    const Color(0xFFFFFFFF),
    t,
  )!;
  while (tint.computeLuminance() < _nameMinLuminance && t < 1) {
    t += 0.05;
    tint = Color.lerp(color.withValues(alpha: 1), const Color(0xFFFFFFFF), t)!;
  }
  return tint;
}

/// [color] mixed toward black until dark enough for a VIP bubble or pill
/// (at least 25 %); the second stop a little deeper.
(Color, Color) vipBubbleShades(Color color) {
  Color shade(double t) =>
      Color.lerp(color.withValues(alpha: 1), const Color(0xFF000000), t)!;
  var t = 0.25;
  while (shade(t).computeLuminance() > _bubbleMaxLuminance && t < 1) {
    t += 0.05;
  }
  return (shade(t), shade((t + 0.2).clamp(0, 1)));
}

/// D258: the look of [vip] in [catalog] (null without a VIP).
VipLook? vipLookOf(UserVip? vip, VipTierList? catalog) {
  if (vip == null) return null;
  final tiers = [...?catalog?.tiers]
    ..sort((a, b) => a.level.compareTo(b.level));
  final own = tiers.where((t) => t.code == vip.tier).firstOrNull;
  if (own == null) {
    // Not on sale (or no catalogue): the badge in the tier's colour only.
    return VipLook(vip: vip, perks: const {});
  }
  final perks = <String, VipPerk>{};
  for (final t in tiers) {
    if (t.level > own.level) break;
    for (final p in t.perks) {
      if (p.available) perks[p.code] = p;
    }
  }
  return VipLook(vip: vip, tier: own, perks: perks);
}

/// D258: a member's look from the session's catalogue (null without a VIP).
final ProviderFamily<VipLook?, UserVip?> vipLookProvider =
    Provider.family<VipLook?, UserVip?>(
      (ref, vip) => vip == null
          ? null
          : vipLookOf(vip, ref.watch(vipCatalogProvider).value),
    );
