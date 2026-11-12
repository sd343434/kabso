import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D252c (owner, with a new reference: «اجعل شاشة vip في تطبيقنا مثل التصميم
/// ١٠٠٪ دون اي اختلاف بالمقاسات فقط غير لون الخلفية واجعله في وضع نهاري ابيض
/// والوضع الليلي اسود»): the «شراء VIP» page's parts in the reference's
/// geometry (measured at 393 pt wide) — the tier tabs with the selected one a
/// pill in its colour, «الخاص بي VIP» at the end edge, the tier's badge over a
/// bordered showcase card of the tier's art in tiles, the «الامتياز الحصري»
/// card with round icons three a row, and the pay card at the bottom. The
/// page is white in light mode and black in dark mode; the rest follows the
/// reference. Every art is the owner's (admin panel); nothing third-party.
@immutable
class VipPalette {
  const new({
    required this.background,
    required this.card,
    required this.tile,
    required this.text,
    required this.muted,
    required this.iconFill,
    required this.icon,
    required this.sheet,
    required this.payCard,
  });

  factory of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static const light = VipPalette(
    background: Color(0xFFFFFFFF),
    card: Color(0xFFF3F1F6),
    tile: Color(0xFFE8E5EE),
    text: Color(0xFF1C1A22),
    muted: Color(0xFF8A8494),
    iconFill: Color(0xFFEFE7DA),
    icon: Color(0xFF8C6A3D),
    sheet: Color(0xFFF6F4F8),
    payCard: Color(0xFFE9E3F5),
  );

  static const dark = VipPalette(
    background: Color(0xFF000000),
    card: Color(0xFF17151C),
    tile: Color(0xFF24212B),
    text: Color(0xFFFFFFFF),
    muted: Color(0xFF9C97A6),
    iconFill: Color(0xFF2E2A35),
    icon: Color(0xFFE8D3B0),
    sheet: Color(0xFF0F0E12),
    payCard: Color(0xFF2A2338),
  );

  final Color background;
  final Color card;
  final Color tile;
  final Color text;
  final Color muted;
  final Color iconFill;
  final Color icon;
  final Color sheet;
  final Color payCard;

  /// The price's gold (ref).
  static const Color gold = Color(0xFFF5B83D);
}

/// The reference's measures (pt at 393 wide).
abstract final class KVip {
  static const double side = 15.5;

  static const double pillHeight = 22;
  static const double myChipHeight = 22;
  static const double badge = 115;

  /// The badge hangs this far over the showcase card's top.
  static const double badgeOverlap = 53;
  static const double cardHeight = 225.5;
  static const double cardRadius = 13;
  static const double tileRadius = 5;
  static const double icon = 44;
  static const double perkRow = 122;
  static const double payHeight = 84;
}

/// «الخاص بي VIP ›»: the member's own VIP, a tab attached to the screen's end
/// edge (rounded on its inner side).
class VipMyChip extends StatelessWidget {
  const new({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = VipPalette.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: KVip.myChipHeight,
          padding: const EdgeInsetsDirectional.only(start: 10, end: 8),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: const BorderRadiusDirectional.horizontal(
              start: Radius.circular(KVip.myChipHeight / 2),
            ).resolve(Directionality.of(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.textStyles.caption.copyWith(
                  fontSize: 10.5,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
              const SizedBox(width: 2),
              // Pointing to the edge it is attached to (ref «VIP الخاص بي ‹»).
              // Mirrors in RTL (ref «‹» toward the left edge).
              Icon(Icons.chevron_right_rounded, size: 14, color: p.text),
            ],
          ),
        ),
      ),
    );
  }
}

/// The showcase card: a rounded card bordered in the tier's colour holding the
/// tier's art perks in the reference's tiles — a tall tile at the start, two
/// wide tiles beside it, then two small tiles and a wide one (up to six; the
/// art perks in their order). The badge hangs over its top ([KVip.badgeOverlap]
/// of space is kept free there).
class VipShowcaseCard extends StatelessWidget {
  const new({required this.tier, required this.perks, super.key});

  final VipTier tier;

  /// The tier's perks that have art.
  final List<VipPerk> perks;

  static const cardKey = Key('vip.showcase');
  static Key tileKey(String code) => Key('vip.showcase.$code');

  /// D258 (owner: «ضع القطع»): which piece goes in which tile, by its shape
  /// — the tall tile the person card, the two wide ones the entry banner and
  /// the chat bubble, the small ones the frame and the mic wave, the long
  /// bottom one the entry car; any other art fills the tiles left, in order.
  static const preferred = [
    'PROFILE_CARD',
    'ENTRY_BANNER',
    'CHAT_BUBBLE',
    'AVATAR_FRAME',
    'MIC_WAVE',
    'ENTRY_EFFECT',
  ];

  /// [perks] laid out in the six tiles (null: an empty tile).
  static List<VipPerk?> layout(List<VipPerk> perks) {
    final tiles = List<VipPerk?>.filled(slots.length, null);
    final rest = [...perks];
    for (final (i, code) in preferred.indexed) {
      final hit = rest.where((p) => p.code == code).firstOrNull;
      if (hit != null) {
        tiles[i] = hit;
        rest.remove(hit);
      }
    }
    for (var i = 0; i < tiles.length && rest.isNotEmpty; i++) {
      tiles[i] ??= rest.removeAt(0);
    }
    return tiles;
  }

  /// D258 (owner: «لون البوكس … مناسب للـ vip»): the card's and the tiles'
  /// fill in the tier's colour — a light tint in light mode, a deeper
  /// translucent shade in dark mode.
  static (Color card, Color tile) fills(
    Color accent,
    VipPalette p, {
    required bool dark,
  }) {
    final card = Color.alphaBlend(
      accent.withValues(alpha: dark ? 0.16 : 0.08),
      p.card,
    );
    final tile = dark
        ? Color.alphaBlend(
            Color.lerp(
              accent,
              const Color(0xFF000000),
              0.45,
            )!.withValues(alpha: 0.55),
            p.tile,
          )
        : Color.alphaBlend(accent.withValues(alpha: 0.16), p.background);
    return (card, tile);
  }

  /// Each slot's rectangle inside the card's 362 × 225.5 pt (from the END
  /// side, top, width, height), measured on the Arabic reference from its
  /// left edge — the tall tile sits at the end; English mirrors it.
  static const List<(double, double, double, double)> slots = [
    (9.5, 46.5, 114.5, 117),
    (137, 46.5, 184, 53),
    (137, 108.5, 184, 55),
    (9.5, 172.5, 53.5, 36),
    (71.5, 172.5, 52.5, 36),
    (137, 172.5, 184, 36),
  ];

  @override
  Widget build(BuildContext context) {
    final p = VipPalette.of(context);
    final accent = Color(tier.color);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (cardFill, tileFill) = fills(accent, p, dark: dark);
    final tiles = layout(perks);
    return LayoutBuilder(
      builder: (context, c) {
        // The slots are measured on 362 − 2 × 9.5 inner pt; a narrower phone
        // scales them across.
        final scale = c.maxWidth / 362;
        return Container(
          key: cardKey,
          height: KVip.cardHeight,
          decoration: BoxDecoration(
            color: cardFill,
            borderRadius: BorderRadius.circular(KVip.cardRadius),
            border: Border.all(color: accent, width: 1.3),
            boxShadow: [
              BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 6),
            ],
          ),
          child: Stack(
            children: [
              for (final (i, slot) in slots.indexed)
                PositionedDirectional(
                  end: slot.$1 * scale,
                  top: slot.$2,
                  width: slot.$3 * scale,
                  height: slot.$4,
                  child: Container(
                    key: tiles[i] == null ? null : tileKey(tiles[i]!.code),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: tileFill,
                      borderRadius: BorderRadius.circular(KVip.tileRadius),
                    ),
                    child: tiles[i] == null
                        ? null
                        : Semantics(
                            image: true,
                            label: tiles[i]!.title,
                            child: VipAnimatedArt(
                              animation: tiles[i]!.animation,
                              still: tiles[i]!.still,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// «الامتياز الحصري VIPn x/y» and the tier's perks three a row, each a round
/// icon over its title (and its one-line description, small).
class VipPrivilegeCard extends StatelessWidget {
  const new({
    required this.tier,
    required this.total,
    required this.active,
    super.key,
  });

  final VipTier tier;

  /// The most perks a tier has (the reference's «/10»).
  final int total;

  /// The caller holds this tier or a higher one now.
  final bool active;

  static const cardKey = Key('vip.privileges');

  static IconData iconOf(String code) => switch (code) {
    'BADGE' || 'IDENTITY' => Icons.workspace_premium_rounded,
    'FRAME' || 'HEADWEAR' || 'AVATAR_FRAME' => Icons.face_retouching_natural,
    'ENTRY_BANNER' || 'ENTRANCE' || 'ENTRY_EFFECT' => Icons.login_rounded,
    'CHAT_BUBBLE' || 'BUBBLE' => Icons.chat_bubble_rounded,
    'ROOM_CARD' || 'CARD' => Icons.style_rounded,
    'MIC_WAVE' || 'MIC_EFFECT' => Icons.graphic_eq_rounded,
    'NAME_COLOR' || 'NAME_PLATE' => Icons.format_color_text_rounded,
    'DAILY_BULLET' => Icons.campaign_rounded,
    'VIEWER_LIST_PRIORITY' => Icons.trending_up_rounded,
    'MONTHLY_GIFT' => Icons.card_giftcard_rounded,
    'VISITORS' || 'PROFILE_VISITORS' => Icons.visibility_rounded,
    'PROFILE_CARD' => Icons.badge_rounded,
    'CHAT_NAME_COLOR' => Icons.format_color_text_rounded,
    'LEVEL_SPEEDUP' => Icons.rocket_launch_rounded,
    // D374: the catalogue's perks not built yet («قريباً»).
    'ANIMATED_COVER' => Icons.wallpaper_rounded,
    'PREMIUM_USERNAME' || 'GOLDEN_ID' => Icons.alternate_email_rounded,
    'SEAT_EMOJI' => Icons.emoji_emotions_rounded,
    'PINNED_MESSAGE' => Icons.push_pin_rounded,
    'EXCLUSIVE_GIFTS' ||
    'SCHEDULED_GIFT' ||
    'ANONYMOUS_GIFT' => Icons.card_giftcard_rounded,
    'HIDDEN_VISIT' ||
    'RANKING_ANONYMOUS' ||
    'KICK_MUTE_SHIELD' => Icons.shield_rounded,
    'DM_BUBBLE' => Icons.forum_rounded,
    'POST_BADGE' => Icons.verified_rounded,
    'STORY_RING' => Icons.radio_button_checked_rounded,
    'FREE_CP_REQUEST' => Icons.favorite_rounded,
    'SEAT_REQUEST_PRIORITY' => Icons.event_seat_rounded,
    'PRIORITY_SUPPORT' => Icons.support_agent_rounded,
    'MONTHLY_ROCKETS' => Icons.rocket_rounded,
    'GLOWING_NAME' || 'ANIMATED_SIGNATURE' => Icons.auto_awesome_rounded,
    'HOST_GREETING' => Icons.waving_hand_rounded,
    'SEAT_CROWN' => Icons.emoji_events_rounded,
    'BIG_GIFT_RAIN' => Icons.celebration_rounded,
    'TICKER_HOLD' => Icons.timer_rounded,
    'VIP_ROOM' => Icons.meeting_room_rounded,
    'SEAT_RESERVE' => Icons.chair_rounded,
    'HIGHER_GIFT_QUANTITY' => Icons.add_box_rounded,
    'LONGER_VOICE' => Icons.mic_rounded,
    _ => Icons.auto_awesome_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final p = VipPalette.of(context);
    final l10n = context.l10n;
    final t = context.textStyles;
    final perks = tier.perks;
    return Container(
      key: cardKey,
      padding: const EdgeInsets.only(top: 14, bottom: 18),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(KVip.cardRadius),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sort_rounded, size: 14, color: p.muted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.vipPrivilegeTitle(
                    'VIP${tier.level}',
                    KFormat.grouped(perks.length),
                    KFormat.grouped(total),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.label.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Transform.flip(
                flipX: true,
                child: Icon(Icons.sort_rounded, size: 14, color: p.muted),
              ),
            ],
          ),
          const SizedBox(height: 21),
          if (perks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(KSpacing.lg),
              child: Text(
                l10n.vipPerksEmpty,
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: p.muted),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth / 3;
                return Wrap(
                  runSpacing: 8,
                  children: [
                    for (final perk in perks)
                      SizedBox(
                        width: w,
                        child: _Perk(perk: perk, palette: p),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const new({required this.perk, required this.palette});

  final VipPerk perk;
  final VipPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final t = context.textStyles;
    final description = perk.description;
    return Semantics(
      key: Key('vip.perk.${perk.code}'),
      label: [perk.title, ?description].join('، '),
      excludeSemantics: true,
      child: Opacity(
        opacity: perk.available ? 1 : 0.55,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KVip.perkRow - 8),
          child: Column(
            children: [
              Container(
                width: KVip.icon,
                height: KVip.icon,
                decoration: BoxDecoration(
                  color: p.iconFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  VipPrivilegeCard.iconOf(perk.code),
                  size: 22,
                  color: p.icon,
                ),
              ),
              const SizedBox(height: 9),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  perk.title,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(
                    fontSize: 10.5,
                    height: 1.3,
                    color: p.text.withValues(alpha: 0.85),
                  ),
                ),
              ),
              if (description != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(
                      fontSize: 7.5,
                      height: 1.4,
                      color: p.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
