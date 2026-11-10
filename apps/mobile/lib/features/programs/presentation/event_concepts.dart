// KL-352 PROTOTYPE (design options for the owner, not wired into routing):
// three full-page layouts for a gift event, the rewards tab and the shared
// parts (hero, gifts strip, tabs, board switcher). Real widgets over the
// prototype data the capture test passes in; production would feed them
// from `EventDetail` / `EventLeaderboard` (see the report for the mapping).

import 'dart:math' as math;

import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/programs/presentation/event_hero_countdown.dart';
import 'package:kabso_live/features/programs/presentation/event_leaderboard_styles.dart';
import 'package:kabso_live/features/programs/presentation/event_page_theme.dart'
    show EventRulesRibbon;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

const kPageBg = Color(0xFF1A0306);

// ---- data --------------------------------------------------------------------

enum RewardKind { frame, entrance, badge, nameBar, gift, coins, cherries }

@immutable
class RewardPrize {
  const RewardPrize({
    required this.kind,
    required this.name,
    this.days,
    this.qty,
    this.art,
    this.rank = 1,
    this.featured = false,
  });

  final RewardKind kind;
  final String name;

  /// Null = permanent («دائم»); ignored for coins and cherries.
  final int? days;
  final int? qty;

  /// The item's art (asset path); frames use [rank]'s frame art.
  final String? art;
  final int rank;
  final bool featured;

  bool get previewable =>
      kind == RewardKind.entrance || kind == RewardKind.frame;
}

@immutable
class RewardTier {
  const RewardTier({
    required this.from,
    required this.to,
    required this.prizes,
  });

  final int from;
  final int to;
  final List<RewardPrize> prizes;
}

@immutable
class EventGiftLite {
  const EventGiftLite(this.name, this.art, this.price, this.points);

  final String name;
  final String art;
  final int price;
  final int points;
}

@immutable
class EventShowcase {
  const EventShowcase({
    required this.title,
    required this.dates,
    required this.startsAt,
    required this.endsAt,
    required this.gifts,
    required this.entries,
    required this.me,
    required this.toNext,
    required this.tiers,
    required this.background,
  });

  final String title;
  final String dates;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<EventGiftLite> gifts;
  final List<LbEntry> entries;
  final LbEntry me;
  final int toNext;
  final List<RewardTier> tiers;
  final ImageProvider background;
}

enum EventConcept { heroPodium, stage, deck }

// ---- shared parts ------------------------------------------------------------

/// Placeholder title art: the event title in gold with a dark outline.
/// The owner supplies real title art per event (an image replaces this).
class TitleArt extends StatelessWidget {
  const TitleArt(this.title, {this.size = 46, super.key});

  final String title;
  final double size;

  @override
  Widget build(BuildContext context) => GoldText(
    title,
    stroke: 7,
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFFF6D0),
        Color(0xFFFFD66B),
        Color(0xFFE09A2B),
        Color(0xFFFFE59A),
      ],
      stops: [0, .45, .7, 1],
    ),
    style: context.textStyles.display.copyWith(
      fontSize: size,
      fontWeight: FontWeight.w900,
      height: 1.15,
    ),
  );
}

class _GlassIcon extends StatelessWidget {
  const _GlassIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0x66000000),
      border: Border.all(color: const Color(0x33FFFFFF)),
    ),
    child: Icon(icon, color: Colors.white, size: 22),
  );
}

/// The full-bleed hero: background, top bar, title art, dates, countdown.
class EventHero extends StatelessWidget {
  const EventHero({
    required this.data,
    required this.countdown,
    required this.height,
    this.titleTop = 92,
    super.key,
  });

  final EventShowcase data;
  final HeroCountdownStyle countdown;
  final double height;
  final double titleTop;

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: data.background,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x8C1A0306),
                  kPageBg,
                ],
                stops: [0, .22, .7, 1],
              ),
            ),
          ),
          Positioned(
            top: titleTop,
            left: KSpacing.lg,
            right: KSpacing.lg,
            child: Column(
              children: [
                TitleArt(data.title),
                const SizedBox(height: KSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x99140208),
                    borderRadius: BorderRadius.circular(KRadius.pill),
                    border: Border.all(color: kGold.withValues(alpha: .5)),
                  ),
                  child: Text(
                    data.dates,
                    style: ts.label.copyWith(
                      color: kGoldLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: KSpacing.lg,
            right: KSpacing.lg,
            bottom: KSpacing.lg,
            child: Center(
              // Narrow phones: the countdown scales down, never overflows.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: 361,
                  child: EventHeroCountdown(
                    startsAt: data.startsAt,
                    endsAt: data.endsAt,
                    style: countdown,
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

/// Back + share over the hero, and the rules ribbon on the END edge.
class HeroChrome extends StatelessWidget {
  const HeroChrome({this.ribbonTop = 104, super.key});

  final double ribbonTop;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Stack(
      children: [
        const PositionedDirectional(
          top: 52,
          start: KSpacing.lg,
          child: _GlassIcon(Icons.arrow_back_rounded),
        ),
        const PositionedDirectional(
          top: 52,
          end: KSpacing.lg,
          child: _GlassIcon(Icons.ios_share_rounded),
        ),
        PositionedDirectional(
          top: ribbonTop,
          end: 0,
          child: EventRulesRibbon(onTap: () {}, edgeIsLeft: rtl),
        ),
      ],
    );
  }
}

/// A small ornamented heading: diamond — gold text — diamond.
class OrnamentHeading extends StatelessWidget {
  const OrnamentHeading(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Widget line(bool flip) => Expanded(
      child: Container(
        height: 1.2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: flip
                ? [kGold.withValues(alpha: 0), kGold]
                : [kGold, kGold.withValues(alpha: 0)],
          ),
        ),
      ),
    );
    Widget diamond() => Transform.rotate(
      angle: math.pi / 4,
      child: Container(width: 7, height: 7, color: kGold),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: Row(
        children: [
          line(true),
          const SizedBox(width: 6),
          diamond(),
          const SizedBox(width: 10),
          Text(
            text,
            style: context.textStyles.title.copyWith(
              color: kGoldLight,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          diamond(),
          const SizedBox(width: 6),
          line(false),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Event gifts, compact and horizontally scrollable.
class GiftsStrip extends StatelessWidget {
  const GiftsStrip(this.gifts, {super.key});

  final List<EventGiftLite> gifts;

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
        itemCount: gifts.length,
        separatorBuilder: (_, _) => const SizedBox(width: KSpacing.sm),
        itemBuilder: (context, i) {
          final g = gifts[i];
          return Container(
            width: 80,
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.md),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4A0A12), Color(0xFF240409)],
              ),
              border: Border.all(color: kGold.withValues(alpha: .45)),
            ),
            child: Column(
              children: [
                Image.asset(
                  g.art,
                  width: 46,
                  height: 46,
                  excludeFromSemantics: true,
                ),
                const SizedBox(height: 4),
                Text(
                  g.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CoinIcon(size: 11),
                    const SizedBox(width: 2),
                    Text(
                      eventScore(g.price),
                      style: const TextStyle(
                        fontFamily: KFonts.latin,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kGoldLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// «الترتيب | الجوائز» as two gold tab buttons.
class GoldTabs extends StatelessWidget {
  const GoldTabs({required this.selected, this.compact = false, super.key});

  final int selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [l10n.eventsTabRanking, l10n.eventsTabRewards];
    final icons = [Icons.leaderboard_rounded, Icons.card_giftcard_rounded];
    return Container(
      height: compact ? 44 : 50,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        color: const Color(0xE6240409),
        border: Border.all(color: kGold.withValues(alpha: .7), width: 1.2),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 2; i++)
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: i == selected
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(KRadius.pill),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFFFF0B8), kGold, Color(0xFFC88E2C)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kGold.withValues(alpha: .4),
                            blurRadius: 8,
                          ),
                        ],
                      )
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[i],
                      size: 18,
                      color: i == selected ? kWine : kGoldLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      labels[i],
                      style: context.textStyles.bodyStrong.copyWith(
                        color: i == selected ? kWine : kGoldLight,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// داعمون / مضيفون / CP as gold pills.
class BoardPills extends StatelessWidget {
  const BoardPills({this.selected = 0, super.key});

  final int selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [
      l10n.eventsBoardSenders,
      l10n.eventsBoardReceivers,
      l10n.eventsBoardCp,
    ];
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(KRadius.pill),
                  gradient: i == selected ? kGoldGradient : null,
                  color: i == selected ? null : const Color(0xCC2A0508),
                  border: Border.all(
                    color: kGold.withValues(alpha: i == selected ? 1 : .45),
                  ),
                ),
                child: Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.label.copyWith(
                    color: i == selected ? kWine : kGoldLight,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- rewards -------------------------------------------------------------------

String rewardDuration(BuildContext context, RewardPrize p) => p.days == null
    ? context.l10n.eventsRewardPermanent
    : context.l10n.eventsRewardDays(p.days!);

/// The prize's picture: frame on a sample avatar, entrance, badge, name bar,
/// gift or coins.
class RewardArt extends StatelessWidget {
  const RewardArt(this.p, {required this.size, super.key});

  final RewardPrize p;
  final double size;

  @override
  Widget build(BuildContext context) => switch (p.kind) {
    RewardKind.frame => TopFrame(p.rank, null, size: size),
    RewardKind.nameBar => SizedBox(
      width: size,
      height: size,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: KSpecialUsername(
            username: 'Kabso',
            tier: p.rank == 1 ? PremiumTier.gold : PremiumTier.silver,
            height: size * .26,
            animate: false,
          ),
        ),
      ),
    ),
    RewardKind.coins => Image.asset(
      'assets/currency/kabso_coin.png',
      width: size * .72,
      height: size * .72,
      excludeFromSemantics: true,
    ),
    RewardKind.cherries => Image.asset(
      'assets/currency/kabso_cherry.webp',
      width: size * .72,
      height: size * .72,
      excludeFromSemantics: true,
    ),
    _ => Image.asset(
      p.art!,
      width: size * .9,
      height: size * .9,
      excludeFromSemantics: true,
    ),
  };
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge({this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: const Color(0xCC000000),
      border: Border.all(color: kGoldLight, width: 1.4),
    ),
    child: Icon(Icons.play_arrow_rounded, size: size * .72, color: kGoldLight),
  );
}

class _DurationChip extends StatelessWidget {
  const _DurationChip(this.text, {required this.permanent});

  final String text;
  final bool permanent;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(KRadius.pill),
      color: permanent ? null : const Color(0xFF3A0810),
      gradient: permanent ? kGoldGradient : null,
      border: permanent ? null : Border.all(color: kGold.withValues(alpha: .5)),
    ),
    child: Text(
      text,
      style: context.textStyles.caption.copyWith(
        color: permanent ? kWine : kGoldLight,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
    ),
  );
}

/// One prize tile: art (with ▶ / ×qty), name, duration.
class RewardTile extends StatelessWidget {
  const RewardTile(this.p, {required this.width, super.key});

  final RewardPrize p;
  final double width;

  @override
  Widget build(BuildContext context) {
    final money = p.kind == RewardKind.coins || p.kind == RewardKind.cherries;
    final qty = p.qty;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Container(
            width: width,
            height: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.md + 2),
              gradient: const RadialGradient(
                center: Alignment(0, -.2),
                radius: .85,
                colors: [Color(0xFF7A1420), Color(0xFF2E050C)],
              ),
              border: Border.all(color: kGold.withValues(alpha: .55)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                RewardArt(p, size: width - 14),
                if (p.previewable)
                  const PositionedDirectional(
                    end: 5,
                    bottom: 5,
                    child: _PlayBadge(),
                  ),
                if (qty != null)
                  PositionedDirectional(
                    end: 5,
                    bottom: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(KRadius.pill),
                        color: const Color(0xD9000000),
                      ),
                      child: Text(
                        '\u2066×${money ? eventScore(qty) : qty}\u2069',
                        style: const TextStyle(
                          fontFamily: KFonts.latin,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kGoldLight,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.textStyles.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 4),
          if (!money)
            _DurationChip(rewardDuration(context, p), permanent: p.days == null)
          else
            const SizedBox(height: 18),
        ],
      ),
    );
  }
}

/// The featured (grand) prize: bigger, with the preview action.
class FeaturedReward extends StatelessWidget {
  const FeaturedReward(this.p, {super.key});

  final RewardPrize p;

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    final l10n = context.l10n;
    return Container(
      height: 150,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.lg),
        gradient: kGoldGradient,
        boxShadow: [
          BoxShadow(color: kGold.withValues(alpha: .3), blurRadius: 16),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KRadius.lg - 1.5),
          gradient: const RadialGradient(
            radius: 1.1,
            colors: [Color(0xFF8A1A24), Color(0xFF2A050B)],
          ),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 14, 8),
        child: Row(
          children: [
            Stack(
              children: [
                RewardArt(p, size: 134),
                const PositionedDirectional(
                  end: 4,
                  bottom: 4,
                  child: _PlayBadge(size: 30),
                ),
              ],
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: KBrandColors.red500,
                      borderRadius: BorderRadius.circular(KRadius.xs),
                    ),
                    child: Text(
                      l10n.eventsRewardFeatured,
                      style: ts.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ts.title.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _DurationChip(
                    rewardDuration(context, p),
                    permanent: p.days == null,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(KRadius.pill),
                      border: Border.all(color: kGoldLight),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: kGoldLight,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.eventsRewardPreview,
                          style: ts.label.copyWith(
                            color: kGoldLight,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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

/// The tier heading: a red banner with gold rims, crown, «المركز 1».
class TierBanner extends StatelessWidget {
  const TierBanner(this.tier, {super.key});

  final RewardTier tier;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = tier.from == tier.to
        ? l10n.eventsRank('${tier.from}')
        : l10n.eventsRanks('${tier.from}', '${tier.to}');
    final metal = rankMetal(tier.from.clamp(1, 3));
    return SizedBox(
      height: 44,
      child: CustomPaint(
        painter: _TierBannerPainter(tier.from <= 3 ? metal : rankMetal(1)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (tier.from <= 3) ...[
              _MedalDot(tier.from),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: context.textStyles.title.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.2,
                shadows: const [
                  Shadow(color: Color(0x99000000), blurRadius: 3),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedalDot extends StatelessWidget {
  const _MedalDot(this.rank);

  final int rank;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: rankMetal(rank)),
      border: Border.all(color: Colors.white.withValues(alpha: .8)),
    ),
    child: Text(
      '$rank',
      style: const TextStyle(
        fontFamily: KFonts.latin,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: kWine,
      ),
    ),
  );
}

class _TierBannerPainter extends CustomPainter {
  _TierBannerPainter(this.metal);

  final List<Color> metal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;
    const half = 120.0;
    // Thin gold rules out to the edges.
    final rule = Paint()
      ..shader = LinearGradient(
        colors: [
          metal[1].withValues(alpha: 0),
          metal[1],
          metal[1],
          metal[1].withValues(alpha: 0),
        ],
        stops: const [0, .3, .7, 1],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), rule);
    final band = Path()
      ..moveTo(cx - half, 4)
      ..lineTo(cx + half, 4)
      ..lineTo(cx + half + 14, h / 2)
      ..lineTo(cx + half, h - 4)
      ..lineTo(cx - half, h - 4)
      ..lineTo(cx - half - 14, h / 2)
      ..close();
    canvas.drawPath(
      band,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [KBrandColors.red500, KBrandColors.red700],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = LinearGradient(colors: metal)
            .createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_TierBannerPainter old) => false;
}

/// A tier: banner + (featured prize) + a 3-column grid of tiles in a frame.
class RewardTierCard extends StatelessWidget {
  const RewardTierCard(this.tier, {super.key});

  final RewardTier tier;

  @override
  Widget build(BuildContext context) {
    final featured = tier.prizes.where((p) => p.featured).toList();
    final rest = tier.prizes.where((p) => !p.featured).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: Column(
        children: [
          TierBanner(tier),
          const SizedBox(height: KSpacing.sm),
          Container(
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.lg),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xE6400810), Color(0xE61E0307)],
              ),
              border: Border.all(color: kGold.withValues(alpha: .35)),
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth - KSpacing.md * 2) / 3;
                return Column(
                  children: [
                    for (final f in featured) ...[
                      FeaturedReward(f),
                      const SizedBox(height: KSpacing.md),
                    ],
                    Wrap(
                      spacing: KSpacing.md,
                      runSpacing: KSpacing.md,
                      children: [for (final p in rest) RewardTile(p, width: w)],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A tier as a horizontal carousel (concept 3).
class RewardTierCarousel extends StatelessWidget {
  const RewardTierCarousel(this.tier, {super.key});

  final RewardTier tier;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
        child: TierBanner(tier),
      ),
      const SizedBox(height: KSpacing.sm),
      SizedBox(
        height: 160,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          itemCount: tier.prizes.length,
          separatorBuilder: (_, _) => const SizedBox(width: KSpacing.md),
          itemBuilder: (_, i) => RewardTile(tier.prizes[i], width: 106),
        ),
      ),
    ],
  );
}

// ---- the three concepts --------------------------------------------------------

class EventConceptPage extends StatelessWidget {
  const EventConceptPage({
    required this.concept,
    required this.data,
    this.tab = 0,
    this.controller,
    super.key,
  });

  final EventConcept concept;
  final EventShowcase data;

  /// 0 = ranking, 1 = rewards.
  final int tab;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final bottom = Positioned(
      left: KSpacing.md,
      right: KSpacing.md,
      bottom: KSpacing.md,
      child: MyRankBar(me: data.me, toNext: data.toNext),
    );
    final body = switch (concept) {
      EventConcept.heroPodium => _heroPodium(context),
      EventConcept.stage => _stage(context),
      EventConcept.deck => _deck(context),
    };
    return ColoredBox(
      color: kPageBg,
      child: Stack(children: [body, bottom]),
    );
  }

  List<Widget> _rewards({bool carousel = false}) => [
    for (final t in data.tiers) ...[
      if (carousel) RewardTierCarousel(t) else RewardTierCard(t),
      const SizedBox(height: KSpacing.xl),
    ],
  ];

  // 1. Hero + podium ---------------------------------------------------------
  Widget _heroPodium(BuildContext context) {
    final l10n = context.l10n;
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              EventHero(
                data: data,
                countdown: HeroCountdownStyle.flip,
                height: 452,
                titleTop: 112,
              ),
              const Positioned.fill(child: HeroChrome(ribbonTop: 224)),
            ],
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _Pinned(
            height: 66,
            child: Container(
              color: kPageBg.withValues(alpha: .96),
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                8,
                KSpacing.lg,
                8,
              ),
              child: GoldTabs(selected: tab),
            ),
          ),
        ),
        if (tab == 0) ...[
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: KSpacing.sm),
                OrnamentHeading(l10n.eventsGifts),
                const SizedBox(height: KSpacing.md),
                GiftsStrip(data.gifts),
                const SizedBox(height: KSpacing.xl),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: KSpacing.lg),
                  child: BoardPills(),
                ),
                const SizedBox(height: KSpacing.md),
                LeaderboardStage(
                  style: LeaderboardStyle.throne,
                  entries: data.entries,
                  rowsLimit: 7,
                ),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ] else
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: KSpacing.md),
                ..._rewards(),
                const SizedBox(height: 80),
              ],
            ),
          ),
      ],
    );
  }

  // 2. Stage: the hero collapses into a compact header -------------------------
  Widget _stage(BuildContext context) {
    final l10n = context.l10n;
    final top = MediaQuery.paddingOf(context).top;
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _StageHeader(data: data, top: top, tab: tab),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _Pinned(
            height: tab == 0 ? 54 : 0.01,
            child: tab == 0
                ? Container(
                    color: kPageBg,
                    padding: const EdgeInsets.fromLTRB(
                      KSpacing.lg,
                      6,
                      KSpacing.lg,
                      12,
                    ),
                    child: const BoardPills(),
                  )
                : const SizedBox(),
          ),
        ),
        if (tab == 0)
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: KSpacing.sm),
                LeaderboardStage(
                  style: LeaderboardStyle.cardsRow,
                  entries: data.entries,
                  rowsLimit: 7,
                ),
                const SizedBox(height: KSpacing.lg),
                OrnamentHeading(l10n.eventsGifts),
                const SizedBox(height: KSpacing.md),
                GiftsStrip(data.gifts),
                const SizedBox(height: 96),
              ],
            ),
          )
        else
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: KSpacing.lg),
                ..._rewards(),
                const SizedBox(height: 80),
              ],
            ),
          ),
      ],
    );
  }

  // 3. Cards deck ----------------------------------------------------------------
  Widget _deck(BuildContext context) {
    final l10n = context.l10n;
    final boards = [
      l10n.eventsBoardSenders,
      l10n.eventsBoardReceivers,
      l10n.eventsBoardCp,
    ];
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              EventHero(
                data: data,
                countdown: HeroCountdownStyle.ribbon,
                height: 440,
                titleTop: 112,
              ),
              const Positioned.fill(child: HeroChrome(ribbonTop: 224)),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              OrnamentHeading(l10n.eventsGifts),
              const SizedBox(height: KSpacing.md),
              GiftsStrip(data.gifts),
              const SizedBox(height: KSpacing.lg),
            ],
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _Pinned(
            height: 60,
            child: Container(
              color: kPageBg.withValues(alpha: .96),
              padding: const EdgeInsets.fromLTRB(
                KSpacing.lg,
                6,
                KSpacing.lg,
                10,
              ),
              child: GoldTabs(selected: tab, compact: true),
            ),
          ),
        ),
        if (tab == 0)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 500,
              child: PageView.builder(
                controller: PageController(viewportFraction: .88),
                itemCount: 3,
                padEnds: true,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(5, KSpacing.md, 5, 0),
                  child: _BoardCard(title: boards[i], data: data, index: i),
                ),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: KSpacing.md),
                ..._rewards(carousel: true),
              ],
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}

/// A board as one card of the deck: mini top three + rows 4–6.
class _BoardCard extends StatelessWidget {
  const _BoardCard({
    required this.title,
    required this.data,
    required this.index,
  });

  final String title;
  final EventShowcase data;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    final e = data.entries;
    return Container(
      padding: const EdgeInsets.all(1.6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.xl),
        gradient: kGoldGradient,
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 16)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KRadius.xl - 1.6),
        child: Stack(
          children: [
            Positioned.fill(
              child: StageBackground(
                style: LeaderboardStyle.podium,
                t: 0,
                motion: false,
              ),
            ),
            Column(
              children: [
                const SizedBox(height: KSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: kGold,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      title,
                      style: ts.title.copyWith(
                        color: kGoldLight,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.md),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final r in [2, 1, 3])
                        SizedBox(
                          width: 102,
                          child: Column(
                            children: [
                              PodiumFrame(
                                r,
                                e[r - 1].photo,
                                width: r == 1 ? 110 : 88,
                              ),
                              Directionality(
                                textDirection: Directionality.of(context),
                                child: NameFlag(
                                  e[r - 1],
                                  style: ts.caption.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              ScorePlate(e[r - 1].score, metal: rankMetal(r)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: KSpacing.md),
                for (final row in e.skip(3).take(4))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, KSpacing.sm),
                    child: RankRow(row),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pinned extends SliverPersistentHeaderDelegate {
  _Pinned({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(_Pinned old) => old.child != child || old.height != height;
}

/// Concept 2's header: the full hero that collapses into a bar with the
/// title, a mini countdown and the tabs.
class _StageHeader extends SliverPersistentHeaderDelegate {
  _StageHeader({required this.data, required this.top, required this.tab});

  final EventShowcase data;
  final double top;
  final int tab;

  static const double tabsH = 58;

  @override
  double get maxExtent => 470;
  @override
  double get minExtent => top + 56 + 52 + tabsH;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(
          opacity: 1 - t,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: maxExtent,
            child: Stack(
              children: [
                EventHero(
                  data: data,
                  countdown: HeroCountdownStyle.ring,
                  height: maxExtent - tabsH,
                  titleTop: 104,
                ),
                const Positioned.fill(child: HeroChrome(ribbonTop: 218)),
              ],
            ),
          ),
        ),
        // The compact bar.
        if (t > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: minExtent - tabsH,
            child: Opacity(
              opacity: t,
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: data.background,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -.6),
                    colorFilter: const ColorFilter.mode(
                      Color(0xB3140206),
                      BlendMode.srcOver,
                    ),
                  ),
                  border: Border(
                    bottom: BorderSide(color: kGold.withValues(alpha: .5)),
                  ),
                ),
                padding: EdgeInsets.only(
                  top: top + 46,
                  left: KSpacing.lg,
                  right: KSpacing.lg,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    const SizedBox(width: KSpacing.md),
                    Expanded(child: TitleArt(data.title, size: 24)),
                    _MiniCountdown(data: data),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: tabsH,
          child: Container(
            color: kPageBg,
            padding: const EdgeInsets.fromLTRB(KSpacing.lg, 6, KSpacing.lg, 6),
            child: GoldTabs(selected: tab, compact: true),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_StageHeader old) => old.tab != tab || old.top != top;
}

class _MiniCountdown extends StatelessWidget {
  const _MiniCountdown({required this.data});

  final EventShowcase data;

  @override
  Widget build(BuildContext context) {
    final now = (EventHeroCountdown.debugClock ?? DateTime.now)();
    final left = data.endsAt.difference(now);
    String two(int v) => v.toString().padLeft(2, '0');
    final text = left.isNegative
        ? context.l10n.eventsCountdownEnded
        : '${left.inDays} ${context.l10n.eventsUnitDays} \u2066'
              '${two(left.inHours % 24)}:${two(left.inMinutes % 60)}'
              ':${two(left.inSeconds % 60)}\u2069';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        color: const Color(0xCC2A0508),
        border: Border.all(color: kGold),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 15, color: kGold),
          const SizedBox(width: 4),
          Text(
            text,
            style: context.textStyles.label.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: kGoldLight,
              height: 1.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
