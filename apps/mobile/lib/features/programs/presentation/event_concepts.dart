// v1.115-social (D354, CONVENTIONS §10.150): the shared parts of a designed
// gift-event page — the hero, the gifts strip, the tabs, the board pills, the
// rewards tiers and the deck card — promoted from the KL-352 prototype and fed
// from `EventDetail` / `EventLeaderboard` (`event_designed_page.dart` builds
// the three layouts from them). Kabso art and tokens only.

import 'dart:math' as math;

import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/programs/data/event_page_design.dart';
import 'package:kabso_live/features/programs/data/programs_repository.dart';
import 'package:kabso_live/features/programs/presentation/event_hero_countdown.dart';
import 'package:kabso_live/features/programs/presentation/event_leaderboard_styles.dart';
import 'package:kabso_live/features/programs/presentation/event_page_theme.dart';
import 'package:kabso_live/features/programs/presentation/gift_event_sections.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

/// The designed page's ground (a red700 shade).
const kPageBg = Color(0xFF1A0306);

// ---- data ------------------------------------------------------------------

/// What a prize is, for its picture (derived from the prize item: never a
/// second copy of the prize table — §10.150.4).
enum RewardKind {
  frame,
  entrance,
  badge,
  nameBar,
  gift,
  coins,
  cherries,
  other,
}

/// One prize of a tier, from an `EventPrizeItem`.
@immutable
class RewardPrize {
  const new({
    required this.kind,
    required this.name,
    required this.item,
    this.days,
    this.qty,
    this.image,
    this.rank = 1,
    this.featured = false,
  });

  /// The tile of [item] (its name as the page states it, its picture and
  /// its duration).
  factory of(
    AppLocalizations l10n,
    EventPrizeItem item, {
    required int rank,
    bool featured = false,
  }) {
    final kind = switch (item.type) {
      'COINS' => RewardKind.coins,
      'CHERRIES' || 'CP_MONEY' => RewardKind.cherries,
      'BADGE' => RewardKind.badge,
      'GIFT_PIECES' => RewardKind.gift,
      'BAG_ITEM' => switch (item.category) {
        'AVATAR_FRAME' => RewardKind.frame,
        'ENTRY_EFFECT' || 'ENTRY_BANNER' => RewardKind.entrance,
        _ => RewardKind.other,
      },
      _ => RewardKind.other,
    };
    final url = item.displayUrl ?? item.stillUrl ?? item.imageUrl;
    final money = kind == RewardKind.coins || kind == RewardKind.cherries;
    return RewardPrize(
      kind: kind,
      item: item,
      name: money
          ? eventPrizeText(l10n, item)
          : item.name ?? eventPrizeText(l10n, item),
      days: item.days,
      qty: switch (item.type) {
        'COINS' || 'CHERRIES' => item.amount,
        'GIFT_PIECES' => item.amount,
        _ => null,
      },
      image: url == null ? null : GiftEventBackdrop.image(url),
      rank: rank,
      featured: featured,
    );
  }

  final RewardKind kind;
  final String name;
  final EventPrizeItem item;

  /// Null = permanent («دائم»); ignored for money.
  final int? days;
  final int? qty;

  /// The item's own picture (its display picture first), else drawn.
  final ImageProvider? image;
  final int rank;
  final bool featured;

  bool get isMoney => kind == RewardKind.coins || kind == RewardKind.cherries;

  /// The money and VIP have no duration chip.
  bool get hasDuration => !isMoney && item.type != 'VIP';

  bool get previewable =>
      item.animationUrl != null &&
      (kind == RewardKind.entrance || kind == RewardKind.frame);
}

/// A tier of the rewards tab: a rank range and its prizes.
@immutable
class RewardTier {
  const new({
    required this.from,
    required this.to,
    required this.prizes,
    this.label,
  });

  final int from;
  final int to;
  final List<RewardPrize> prizes;

  /// The team's heading, else «المركز N» / «المراكز N–M».
  final String? label;
}

/// The rewards tab of [board]: the design's tiers on it (the covering prize
/// line's items; the featured ones shown large), else one tier per prize
/// line (its first item featured on the first place).
List<RewardTier> rewardTiersOf(
  AppLocalizations l10n,
  String languageCode,
  EventBoardInfo board,
  List<EventRewardTierSpec>? specs,
) {
  final lines = board.prizes;
  final mine = specs?.where((t) => t.board == board.kind.wire).toList();
  // No tiers designed for this board: one tier per prize line.
  if (mine == null || mine.isEmpty) {
    return [
      for (final l in lines)
        RewardTier(
          from: l.rankFrom,
          to: l.rankTo,
          prizes: [
            for (final (i, item) in l.items.indexed)
              RewardPrize.of(
                l10n,
                item,
                rank: l.rankFrom,
                featured: i == 0 && l.rankFrom == 1,
              ),
          ],
        ),
    ];
  }
  final out = <RewardTier>[];
  for (final t in mine) {
    final line = lines
        .where((l) => t.from >= l.rankFrom && t.to <= l.rankTo)
        .firstOrNull;
    // A tier whose line is gone (an older stored design) is left out.
    if (line == null) continue;
    out.add(
      RewardTier(
        from: t.from,
        to: t.to,
        label: t.label(languageCode),
        prizes: [
          for (final (i, item) in line.items.indexed)
            RewardPrize.of(
              l10n,
              item,
              rank: t.from,
              featured: t.featured.contains(i),
            ),
        ],
      ),
    );
  }
  return out;
}

// ---- shared parts ----------------------------------------------------------

/// Placeholder title art: the event title in gold with a dark outline.
/// The owner supplies real title art per event (an image replaces this).
class TitleArt extends StatelessWidget {
  const new(this.title, {this.size = 46, super.key});

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
  const new(this.icon, {required this.label, this.onTap, super.key});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: KSizes.minTouchTarget,
        height: KSizes.minTouchTarget,
        child: Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x66000000),
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    ),
  );
}

/// The title: the event's title art (a picture, an animated WebP or a
/// Lottie) when uploaded, else the title in gold.
class EventTitleArt extends StatelessWidget {
  const new({
    required this.title,
    this.url,
    this.size = 46,
    this.height = 140,
    super.key,
  });

  final String title;
  final String? url;
  final double size;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url == null) {
      return Semantics(
        header: true,
        label: title,
        excludeSemantics: true,
        child: TitleArt(title, size: size),
      );
    }
    final fallback = TitleArt(title, size: size);
    return Semantics(
      header: true,
      label: title,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: url.endsWith('.json')
            ? Lottie.network(
                url,
                fit: BoxFit.contain,
                animate: !MediaQuery.disableAnimationsOf(context),
                errorBuilder: (_, _, _) => fallback,
              )
            : Image(
                image: GiftEventBackdrop.image(url),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// The countdown of the hero: today's pill ([EventCountdownKind.classic])
/// or one of the five large ones; none for an event without an end.
class EventDesignCountdown extends StatelessWidget {
  const new({required this.event, required this.kind, this.now, super.key});

  final EventSummary event;
  final EventCountdownKind kind;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final end = event.endsAt;
    if (kind == EventCountdownKind.classic || end == null) {
      return EventCountdown(event: event, now: now);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: 361,
        child: EventHeroCountdown(
          startsAt: event.startsAt,
          endsAt: end,
          style: switch (kind) {
            EventCountdownKind.flip => HeroCountdownStyle.flip,
            EventCountdownKind.ring => HeroCountdownStyle.ring,
            EventCountdownKind.coins => HeroCountdownStyle.coins,
            EventCountdownKind.neon => HeroCountdownStyle.neon,
            _ => HeroCountdownStyle.ribbon,
          },
        ),
      ),
    );
  }
}

/// The full-bleed hero: background, title art, dates, countdown (and what
/// goes under it — the gold rules pill).
class EventHero extends StatelessWidget {
  const new({
    required this.event,
    required this.dates,
    required this.countdown,
    required this.height,
    this.titleTop = 92,
    this.belowCountdown,
    this.now,
    super.key,
  });

  final EventDetail event;
  final String dates;
  final EventCountdownKind countdown;
  final double height;
  final double titleTop;
  final Widget? belowCountdown;
  final DateTime Function()? now;

  static const heroKey = Key('event.design.hero');

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    final still = event.art.stillUrl;
    return SizedBox(
      key: heroKey,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (still != null)
            Image(
              image: GiftEventBackdrop.image(still),
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const ColoredBox(color: kPageBg),
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -.5),
                  radius: 1.1,
                  colors: [Color(0xFF6E0A14), kPageBg],
                ),
              ),
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
                EventTitleArt(title: event.title, url: event.art.titleUrl),
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
                    dates,
                    textAlign: TextAlign.center,
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: EventDesignCountdown(
                    event: event,
                    kind: countdown,
                    now: now,
                  ),
                ),
                if (belowCountdown != null) ...[
                  const SizedBox(height: KSpacing.sm),
                  Center(child: belowCountdown),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The back button over the hero (and, at the end, the app-bar rules link).
class HeroChrome extends StatelessWidget {
  const new({this.trailing, super.key});

  final Widget? trailing;

  static const backKey = Key('event.design.back');

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Stack(
      children: [
        PositionedDirectional(
          top: top + KSpacing.xs,
          start: KSpacing.sm,
          child: _GlassIcon(
            rtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
            key: backKey,
            label: MaterialLocalizations.of(context).backButtonTooltip,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        if (trailing != null)
          PositionedDirectional(
            top: top + KSpacing.xs,
            end: KSpacing.sm,
            child: SizedBox(
              height: KSizes.minTouchTarget,
              child: Center(child: trailing),
            ),
          ),
      ],
    );
  }
}

/// A small ornamented heading: diamond — gold text — diamond.
class OrnamentHeading extends StatelessWidget {
  const new(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Widget line({required bool flip}) => Expanded(
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
          line(flip: true),
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
          line(flip: false),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Event gifts, compact and horizontally scrollable; a tap explains how to
/// send one (from a live's gift panel).
class GiftsStrip extends StatelessWidget {
  const new(this.gifts, {required this.onTap, super.key});

  final List<EventGiftInfo> gifts;
  final void Function(EventGiftInfo gift) onTap;

  static const stripKey = Key('event.design.gifts');

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    final l10n = context.l10n;
    final theme = EventPageTheme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return SizedBox(
      key: stripKey,
      height: 112 + 30 * (scale - 1),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
        itemCount: gifts.length,
        separatorBuilder: (_, _) => const SizedBox(width: KSpacing.sm),
        itemBuilder: (context, i) {
          final g = gifts[i];
          return Semantics(
            key: EventGiftsSection.giftKey(g.code),
            button: true,
            label: [
              g.name,
              l10n.meHubCoins(KFormat.grouped(g.priceCoins)),
              l10n.eventsGiftPoints(KFormat.grouped(g.pointsEach)),
            ].join('، '),
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onTap(g),
              child: Container(
                width: 80 * scale,
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(KRadius.md),
                  color: theme?.tileFill,
                  gradient: theme != null
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF4A0A12), Color(0xFF240409)],
                        ),
                  border: Border.all(
                    color: theme?.tileBorder ?? kGold.withValues(alpha: .45),
                  ),
                ),
                child: Column(
                  children: [
                    KGiftImage(g.assetKey, imageUrl: g.imageUrl, size: 46),
                    const SizedBox(height: 4),
                    Text(
                      g.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ts.caption.copyWith(
                        color: theme?.text ?? Colors.white,
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
                        Flexible(
                          child: Text(
                            eventScore(g.priceCoins),
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: KFonts.latin,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kGoldLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// «الترتيب | الجوائز» as two gold tab buttons (the preset's tab colours
/// when one is chosen).
class GoldTabs extends StatelessWidget {
  const new({
    required this.selected,
    required this.onSelected,
    this.rewardsFirst = false,
    this.compact = false,
    super.key,
  });

  /// 0 = ranking, 1 = rewards.
  final int selected;
  final ValueChanged<int> onSelected;

  /// The rewards tab comes first (REWARDS before BOARDS in the design).
  final bool rewardsFirst;
  final bool compact;

  static Key tabKey(int tab) => Key('event.design.tab.$tab');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = EventPageTheme.of(context);
    final order = rewardsFirst ? const [1, 0] : const [0, 1];
    final labels = [l10n.eventsTabRanking, l10n.eventsTabRewards];
    final icons = [Icons.leaderboard_rounded, Icons.card_giftcard_rounded];
    final selectedText = theme?.tabSelectedText ?? kWine;
    final text = theme?.tabText ?? kGoldLight;
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 44 : 50),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        color: theme == null ? const Color(0xE6240409) : null,
        gradient: theme?.tabFill,
        border: Border.all(color: kGold.withValues(alpha: .7), width: 1.2),
      ),
      child: Row(
        children: [
          for (final i in order)
            Expanded(
              child: Semantics(
                selected: i == selected,
                button: true,
                child: GestureDetector(
                  key: tabKey(i),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(i),
                  child: Container(
                    constraints: BoxConstraints(minHeight: compact ? 38 : 44),
                    alignment: Alignment.center,
                    decoration: i == selected
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(KRadius.pill),
                            gradient:
                                theme?.tabSelectedFill ??
                                const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFFFF0B8),
                                    kGold,
                                    Color(0xFFC88E2C),
                                  ],
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
                          color: i == selected ? selectedText : text,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyles.bodyStrong.copyWith(
                              color: i == selected ? selectedText : text,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
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

/// The event's boards (داعمون / مضيفون / CP …) as gold pills.
class BoardPills extends StatelessWidget {
  const new({
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.keys,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final List<Key>? keys;

  @override
  Widget build(BuildContext context) {
    Widget pill(int i) => Semantics(
      selected: i == selected,
      button: true,
      child: GestureDetector(
        key: keys?[i],
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(i),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 36,
            minWidth: KSizes.minTouchTarget,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
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
    );
    if (labels.length <= 3) {
      return Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: KSpacing.sm),
            Expanded(child: pill(i)),
          ],
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: KSpacing.sm),
            pill(i),
          ],
        ],
      ),
    );
  }
}

// ---- rewards ---------------------------------------------------------------

String rewardDuration(BuildContext context, RewardPrize p) => p.days == null
    ? context.l10n.eventsRewardPermanent
    : context.l10n.eventsRewardDays(p.days!);

/// The prize's picture: its own art when uploaded, else drawn — a frame on
/// the default photo, coins, cherries, the event gift, a medal.
class RewardArt extends StatelessWidget {
  const new(this.p, {required this.size, super.key});

  final RewardPrize p;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = p.image;
    Widget drawn() => switch (p.kind) {
      RewardKind.frame => TopFrame(p.rank.clamp(1, 3), null, size: size),
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
      RewardKind.gift => KGiftImage(
        p.item.code ?? '',
        imageUrl: p.item.imageUrl,
        size: size * .8,
      ),
      _ => Icon(
        p.item.type == 'VIP'
            ? Icons.workspace_premium_rounded
            : p.kind == RewardKind.badge
            ? Icons.military_tech_rounded
            : Icons.card_giftcard_rounded,
        size: size * .6,
        color: kGoldLight,
      ),
    };
    if (image == null) return drawn();
    return Image(
      image: image,
      width: size * .9,
      height: size * .9,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => drawn(),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const new({this.size = 26});

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
  const new(this.text, {required this.permanent});

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

/// One prize tile: art (with ▶ / ×qty), name, duration; a tap opens it.
class RewardTile extends StatelessWidget {
  const new(this.p, {required this.width, super.key});

  final RewardPrize p;
  final double width;

  @override
  Widget build(BuildContext context) {
    final qty = p.qty;
    final theme = EventPageTheme.of(context);
    return Semantics(
      button: true,
      label: [
        eventPrizeText(context.l10n, p.item),
        if (p.hasDuration) rewardDuration(context, p),
      ].join('، '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => showEventPrizeSheet(context, p.item),
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              Container(
                width: width,
                height: width,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(KRadius.md + 2),
                  color: theme?.tileFill,
                  gradient: theme != null
                      ? null
                      : const RadialGradient(
                          center: Alignment(0, -.2),
                          radius: .85,
                          colors: [Color(0xFF7A1420), Color(0xFF2E050C)],
                        ),
                  border: Border.all(
                    color: theme?.tileBorder ?? kGold.withValues(alpha: .55),
                  ),
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
                      )
                    else if (qty != null)
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
                            '\u2066×${p.isMoney ? eventScore(qty) : qty}\u2069',
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.textStyles.caption.copyWith(
                  color: theme?.text ?? Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              if (p.hasDuration)
                _DurationChip(
                  rewardDuration(context, p),
                  permanent: p.days == null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The featured (grand) prize: bigger, with «معاينة» that opens it.
class FeaturedReward extends StatelessWidget {
  const new(this.p, {super.key});

  final RewardPrize p;

  static const featuredKey = Key('event.design.featured');

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    final l10n = context.l10n;
    return Semantics(
      button: true,
      label: [
        l10n.eventsRewardFeatured,
        eventPrizeText(l10n, p.item),
        if (p.hasDuration) rewardDuration(context, p),
      ].join('، '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => showEventPrizeSheet(context, p.item),
        child: Container(
          key: featuredKey,
          constraints: const BoxConstraints(minHeight: 150),
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
                    RewardArt(p, size: 120),
                    if (p.previewable)
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
                      if (p.hasDuration) ...[
                        const SizedBox(height: 6),
                        _DurationChip(
                          rewardDuration(context, p),
                          permanent: p.days == null,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(minHeight: 32),
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
                            Flexible(
                              child: Text(
                                l10n.eventsRewardPreview,
                                style: ts.label.copyWith(
                                  color: kGoldLight,
                                  fontWeight: FontWeight.w800,
                                ),
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
        ),
      ),
    );
  }
}

/// The tier heading: a red banner with gold rims, a medal, «المركز 1».
class TierBanner extends StatelessWidget {
  const new(this.tier, {super.key});

  final RewardTier tier;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label =
        tier.label ??
        (tier.from == tier.to
            ? l10n.eventsRank('${tier.from}')
            : l10n.eventsRanks('${tier.from}', '${tier.to}'));
    final metal = rankMetal(tier.from.clamp(1, 3));
    return Semantics(
      header: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: CustomPaint(
          painter: _TierBannerPainter(tier.from <= 3 ? metal : rankMetal(1)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (tier.from <= 3) ...[
                  _MedalDot(tier.from),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.title.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      shadows: const [
                        Shadow(color: Color(0x99000000), blurRadius: 3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedalDot extends StatelessWidget {
  const new(this.rank);

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
  new(this.metal);

  final List<Color> metal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
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
    canvas
      ..drawPath(
        band,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [KBrandColors.red500, KBrandColors.red700],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
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

/// A tier: banner + (featured prizes) + a 3-column grid of tiles in a frame.
class RewardTierCard extends StatelessWidget {
  const new(this.tier, {super.key});

  final RewardTier tier;

  static Key tierKey(int from) => Key('event.design.tier.$from');

  @override
  Widget build(BuildContext context) {
    final featured = tier.prizes.where((p) => p.featured).toList();
    final rest = tier.prizes.where((p) => !p.featured).toList();
    final theme = EventPageTheme.of(context);
    return Padding(
      key: tierKey(tier.from),
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
      child: Column(
        children: [
          TierBanner(tier),
          const SizedBox(height: KSpacing.sm),
          EventFrame(
            radius: theme?.radius ?? KRadius.lg,
            fill:
                theme?.cardFill ??
                const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xE6400810), Color(0xE61E0307)],
                ),
            border:
                theme?.cardBorder ??
                LinearGradient(
                  colors: [
                    kGold.withValues(alpha: .35),
                    kGold.withValues(alpha: .35),
                  ],
                ),
            borderWidth: theme?.cardBorderWidth ?? 1,
            blur: theme?.blur ?? 0,
            glow: theme?.glow ?? const [],
            padding: const EdgeInsets.all(KSpacing.md),
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

/// A tier as a horizontal carousel (the deck layout).
class RewardTierCarousel extends StatelessWidget {
  const new(this.tier, {super.key});

  final RewardTier tier;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return Column(
      key: RewardTierCard.tierKey(tier.from),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          child: TierBanner(tier),
        ),
        const SizedBox(height: KSpacing.sm),
        SizedBox(
          height: 180 + 40 * (scale - 1),
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
}

// ---- the deck's board card and the pinned bars -----------------------------

/// A board as one card of the deck: the top three on podium frames, then the
/// next rows.
class BoardDeckCard extends StatelessWidget {
  const new({
    required this.title,
    required this.entries,
    this.rows = 4,
    this.loading = false,
    this.background,
    super.key,
  });

  final String title;
  final List<LbEntry> entries;
  final int rows;
  final bool loading;
  final ImageProvider? background;

  @override
  Widget build(BuildContext context) {
    final ts = context.textStyles;
    LbEntry? at(int rank) => entries.where((e) => e.rank == rank).firstOrNull;
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
                image: background,
              ),
            ),
            SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
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
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts.title.copyWith(
                            color: kGoldLight,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.md),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.all(KSpacing.xl),
                      child: CircularProgressIndicator(color: kGold),
                    )
                  else ...[
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final r in [2, 1, 3])
                            Flexible(
                              child: SizedBox(
                                width: 102,
                                child: Directionality(
                                  textDirection: Directionality.of(context),
                                  child: Column(
                                    children: [
                                      PodiumFrame(
                                        r,
                                        at(r)?.photo,
                                        width: r == 1 ? 110 : 88,
                                      ),
                                      if (at(r) case final e?) ...[
                                        NameFlag(
                                          e,
                                          style: ts.caption.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        ScorePlate(
                                          e.score,
                                          metal: rankMetal(r),
                                        ),
                                      ] else
                                        Text(
                                          context.l10n.eventsSeatOpen,
                                          style: ts.caption.copyWith(
                                            color: kGoldLight,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: KSpacing.md),
                    for (final row
                        in entries.where((e) => e.rank > 3).take(rows))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          10,
                          0,
                          10,
                          KSpacing.sm,
                        ),
                        child: RankRow(row),
                      ),
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

/// A fixed-height pinned header.
class PinnedBar extends SliverPersistentHeaderDelegate {
  new({required this.height, required this.child});

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
  bool shouldRebuild(PinnedBar old) =>
      old.child != child || old.height != height;
}

/// The stage layout's small countdown in the collapsed bar.
class MiniCountdown extends StatelessWidget {
  const new({required this.event, this.now, super.key});

  final EventSummary event;
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final at = (now ?? EventHeroCountdown.debugClock ?? DateTime.now)();
    final starts = at.isBefore(event.startsAt);
    final end = event.endsAt;
    final left = starts ? event.startsAt.difference(at) : end?.difference(at);
    String two(int v) => v.toString().padLeft(2, '0');
    final text = left == null
        ? l10n.eventsNoEnd
        : left.isNegative
        ? l10n.eventsCountdownEnded
        : '${l10n.eventsDaysShort(left.inDays)} \u2066'
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
