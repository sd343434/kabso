import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/shell_navigation.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/creator/data/creator_repository.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/live/application/home_banners_provider.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/home_banner_link.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_cover_picture.dart';
import 'package:kabso_live/features/live/presentation/hub/home_banner_carousel.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Creator Center geometry (D172). Measured on the owner's reference at
/// 430 × 932 lp (DPR 2.1465, an estimate; spec in the D172 notes); the
/// title row keeps D142's status-bar gap.
abstract final class KCreator {
  /// The title row (as every app bar) and the tabs row under it.
  static const double toolbarHeight = 44;
  static const double titleSize = 20;
  static const double tabsHeight = 50.5;
  static const double tabsStart = 23.8;
  static const double tabsGap = 23.3;
  static const double tabSize = 20;
  static const double tabTextTop = 13;
  static const double indicatorTop = 38.4;
  static const double indicatorWidth = 10;
  static const double indicatorHeight = 3.3;

  /// Cards: 14 lp from the sides; the stats card 17 lp under the tabs.
  static const double side = 14;
  static const double statsTop = 17.3;
  static const double cardRadius = KRadius.md;
  static const double statsPadding = 16.7;
  static const double avatar = 36.8;
  static const double headTitleGap = 11.7;
  static const double headTitleSize = 17;
  static const double linkSize = 15;
  static const double numbersTop = 8.6;
  static const double numberSize = 22;
  static const double labelGap = 2;
  static const double labelSize = 15;
  static const double statsBottom = 27;
  static const double dividerHeight = 24;

  /// The banner slot and the services card under it.
  static const double bannerTop = 15.4;
  static const double servicesTop = 13.5;
  static const double servicesTitleTop = 12.7;
  static const double servicesTitleSize = 17;
  static const double servicesTitleStart = 10.6;
  static const double tilesTop = 45.2;
  static const double tilesInset = 13.75;
  static const double tileGap = 4.8;
  static const double tileHeight = 78.7;
  static const double tileRadius = KRadius.sm;
  static const double tileCircle = 41;
  static const double tileCircleStart = 11.7;
  static const double tileTextGap = 10.2;
  static const double tileIcon = 27;
  static const double tileTextSize = 15.5;

  /// The floating Go Live pill: 319 × 55 lp, centred, 27.7 lp above the
  /// screen's bottom (6.3 lp into a 34-lp home-indicator inset).
  static const double goLiveWidth = 319;
  static const double goLiveHeight = 55.2;
  static const double goLiveBottom = 27.7;
  static const double goLiveTextSize = 22;
}

/// The services of the grid, in the reference's order.
enum CreatorService {
  preview,
  cover,
  events,
  hostLevel,
  violations,
  traffic,
  academy,
  support,
  identity,
  fans;

  Key get key => Key('creator.service.$name');
}

/// `/creator` «مركز صنّاع المحتوى» (D172, owner): in the layout of the
/// owner's reference (a third-party creator center, kept out of git per
/// D40) with Kabso's colours and icons.
///
/// - Tabs «البث» | «الوكالة»: Kabso has no host agencies, so Agency shows
///   an honest «قريباً» state.
/// - The stats card: this calendar month so far in the region's zone
///   (`GET /me/creator-stats?period=THIS_MONTH`, v1.49-social) — live
///   minutes, new followers and the host's share of gifts in the month's
///   lives (display only, D149). The card and «بيانات البث ›» open D164's
///   detailed statistics ([AppRoutes.creatorStats]).
/// - The promo slot shows the admin's live-hub banners (D124), nothing
///   when there is none.
/// - «خدمات البث»: every tile opens a real Kabso destination; the ones
///   not built are faded with «قريباً» and do nothing.
/// - «ابدأ البث» floats over the scrolling grid and opens the go-live
///   screen.
class CreatorCenterScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const liveTabKey = Key('creator.tab.live');
  static const agencyTabKey = Key('creator.tab.agency');
  static const agencySoonKey = Key('creator.agency.soon');
  static const statsCardKey = Key('creator.stats');
  static const liveDataKey = Key('creator.liveData');
  static const monthTitleKey = Key('creator.stats.title');
  static const minutesKey = Key('creator.stats.minutes');
  static const fansKey = Key('creator.stats.fans');
  static const earningsKey = Key('creator.stats.earnings');
  static const bannerKey = Key('creator.banner');
  static const goLiveKey = Key('creator.goLive');
  static const soonKey = Key('creator.soon');

  @override
  ConsumerState<CreatorCenterScreen> createState() =>
      _CreatorCenterScreenState();
}

class _CreatorCenterScreenState extends ConsumerState<CreatorCenterScreen> {
  bool _agency = false;

  static const CreatorStatsPeriod _period = CreatorStatsPeriod.thisMonth;

  void _push(String location) => unawaited(context.push<void>(location));

  void _openBanner(HomeBanner banner) {
    switch (HomeBannerTarget.parse(banner.link)) {
      case HomeBannerRoute(:final location):
        _push(location);
      case HomeBannerLiveTab(tab: final target):
        openLiveHub(context, ref, target);
      case null:
        break;
    }
  }

  VoidCallback? _serviceTap(CreatorService s) => switch (s) {
    CreatorService.preview => () => _push(AppRoutes.goLive),
    CreatorService.cover => () => unawaited(
      LiveCoverPicture.openOptions(
        context,
        ref,
        hasCover: ref.read(currentUserProvider)?.liveCoverUrl != null,
      ),
    ),
    CreatorService.events => () => _push(AppRoutes.eventCenter),
    CreatorService.hostLevel => () => _push(
      AppRoutes.level(LevelCategory.attractiveness.slug),
    ),
    CreatorService.traffic => () => KSnack.info(
      context,
      context.l10n.creatorTrafficHint,
    ),
    CreatorService.fans => () => _push(AppRoutes.creatorStats),
    // Not built: no self-view of moderation, no academy, no support
    // contact, no identity check (owner decisions pending).
    CreatorService.violations ||
    CreatorService.academy ||
    CreatorService.support ||
    CreatorService.identity => null,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final media = MediaQuery.of(context);
    final provider = creatorStatsProvider(_period);

    Future<void> refresh() async {
      ref
        ..invalidate(provider)
        ..invalidate(homeBannersProvider);
      try {
        await ref.read(provider.future);
      } on Object {
        // The card shows dashes; pulling again retries.
      }
    }

    final goLiveBottom = math.max(
      KSpacing.lg,
      media.padding.bottom - (34 - KCreator.goLiveBottom),
    );

    final live = ListView(
      key: const PageStorageKey('creator.live'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: goLiveBottom + KCreator.goLiveHeight + KSpacing.lg,
      ),
      children: [
        _StatsBand(
          child: _StatsCard(
            period: _period,
            onOpen: () => _push(AppRoutes.creatorStats),
          ),
        ),
        _BannerSlot(onOpen: _openBanner),
        _Services(onTap: _serviceTap),
      ],
    );

    final agency = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        KEmptyState(
          key: CreatorCenterScreen.agencySoonKey,
          icon: Icons.groups_2_outlined,
          title: l10n.creatorAgencySoonTitle,
          message: l10n.creatorAgencySoonBody,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: p.surface,
      appBar: KAppBar(
        backgroundColor: p.background,
        scrolledUnderElevation: 0,
        toolbarHeight: KCreator.toolbarHeight,
        centerTitle: true,
        title: Text(
          l10n.meHubCreatorCenter,
          style: context.textStyles.title.copyWith(
            fontSize: KCreator.titleSize,
            fontWeight: FontWeight.w500,
            color: p.textPrimary,
          ),
        ),
        bottom: _Tabs(
          agency: _agency,
          onSelect: (agency) => setState(() => _agency = agency),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: _agency ? agency : live,
            ),
          ),
          if (!_agency)
            Positioned(
              left: 0,
              right: 0,
              bottom: goLiveBottom,
              child: Center(
                child: _GoLiveButton(onPressed: () => _push(AppRoutes.goLive)),
              ),
            ),
        ],
      ),
    );
  }
}

/// «البث» | «الوكالة»: start-aligned labels, a short red bar under the
/// selected one.
class _Tabs extends StatelessWidget implements PreferredSizeWidget {
  const new({required this.agency, required this.onSelect});

  final bool agency;
  final ValueChanged<bool> onSelect;

  @override
  Size get preferredSize => const Size.fromHeight(KCreator.tabsHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget tab(
      Key key,
      String label, {
      required bool selected,
      required bool value,
    }) => _Tab(
      key: key,
      label: label,
      selected: selected,
      onTap: () => onSelect(value),
    );
    return SizedBox(
      height: KCreator.tabsHeight,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: KCreator.tabsStart),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tab(
              CreatorCenterScreen.liveTabKey,
              l10n.creatorTabLive,
              selected: !agency,
              value: false,
            ),
            const SizedBox(width: KCreator.tabsGap),
            tab(
              CreatorCenterScreen.agencyTabKey,
              l10n.creatorTabAgency,
              selected: agency,
              value: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: KCreator.tabsHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: KCreator.tabTextTop),
                child: Text(
                  label,
                  maxLines: 1,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: KMetrics.topBarMaxTextScale),
                  style: context.textStyles.title.copyWith(
                    fontSize: KCreator.tabSize,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: selected ? p.textPrimary : p.textTertiary,
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  left: 0,
                  right: 0,
                  top: KCreator.indicatorTop,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: KCreator.indicatorWidth,
                      height: KCreator.indicatorHeight,
                      decoration: BoxDecoration(
                        color: p.primary,
                        borderRadius: BorderRadius.circular(KRadius.pill),
                      ),
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

/// The soft brand tint behind the stats card, with faint shapes drawn in
/// code at the end side (Kabso's own, not the reference's art).
class _StatsBand extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(p.background, p.primary, 0.10)!,
            Color.lerp(p.background, p.primary, 0.04)!,
            p.surface,
          ],
          stops: const [0, 0.6, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(painter: _BandShapes(p.primary)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KCreator.side,
              KCreator.statsTop,
              KCreator.side,
              0,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _BandShapes extends CustomPainter {
  const new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.10);
    final fill = Paint()..color = color.withValues(alpha: 0.06);
    // Placed by the visual side: shapes are decoration only.
    final c = Offset(size.width * 0.82, size.height * 0.30);
    canvas
      ..drawCircle(c, size.height * 0.62, ring)
      ..drawCircle(Offset(size.width * 0.56, 0), size.height * 0.40, ring);
    // A soft rounded "play" mark (Kabso's live), not the reference's art.
    final r = size.height * 0.26;
    final play = Path()
      ..moveTo(c.dx - r * 0.55, c.dy - r * 0.8)
      ..lineTo(c.dx + r * 0.85, c.dy)
      ..lineTo(c.dx - r * 0.55, c.dy + r * 0.8)
      ..close();
    canvas
      ..drawCircle(c, r * 1.25, fill)
      ..drawPath(
        play,
        fill
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.28
          ..strokeJoin = StrokeJoin.round,
      );
  }

  @override
  bool shouldRepaint(_BandShapes old) => old.color != color;
}

/// This month's card: the photo, «بيانات أكتوبر», «بيانات البث ›» and three
/// numbers with thin dividers.
class _StatsCard extends ConsumerWidget {
  const new({required this.period, required this.onOpen});

  final CreatorStatsPeriod period;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final user = ref.watch(currentUserProvider);
    final stats = ref.watch(creatorStatsProvider(period)).value;
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final month = stats?.month ?? DateTime.now();
    final title = l10n.creatorMonthData(
      DateFormat.MMMM(localeTag).format(month),
    );
    String n(int? v) => v == null ? '—' : KFormat.grouped(v);

    Widget column(Key key, int? value, String label) => Expanded(
      child: Semantics(
        key: key,
        label: '$label: ${n(value)}',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(
              n(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.title.copyWith(
                fontSize: KCreator.numberSize,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: KCreator.labelGap),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: t.body.copyWith(
                fontSize: KCreator.labelSize,
                height: 1.2,
                color: p.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
    final divider = Container(
      width: 1,
      height: KCreator.dividerHeight,
      color: p.border.withValues(alpha: 0.6),
    );

    return Material(
      key: CreatorCenterScreen.statsCardKey,
      color: p.background.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(KCreator.cardRadius),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(KCreator.cardRadius),
        child: Padding(
          padding: const EdgeInsets.only(
            top: KCreator.statsPadding,
            bottom: KCreator.statsBottom,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KCreator.statsPadding,
                ),
                child: Row(
                  children: [
                    KAvatar(
                      name: user?.displayName ?? '',
                      imageUrl: user?.avatarUrl,
                      size: KCreator.avatar,
                    ),
                    const SizedBox(width: KCreator.headTitleGap),
                    Expanded(
                      child: Padding(
                        // The title's caps sit 2 lp above the photo's centre.
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Semantics(
                          header: true,
                          child: Text(
                            title,
                            key: CreatorCenterScreen.monthTitleKey,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.title.copyWith(
                              fontSize: KCreator.headTitleSize,
                              fontWeight: FontWeight.w700,
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: l10n.creatorLiveData,
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: CreatorCenterScreen.liveDataKey,
                        behavior: HitTestBehavior.opaque,
                        onTap: onOpen,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.creatorLiveData,
                              maxLines: 1,
                              style: t.body.copyWith(
                                fontSize: KCreator.linkSize,
                                color: p.textSecondary,
                              ),
                            ),
                            Icon(
                              Directionality.of(context) == TextDirection.rtl
                                  ? Icons.chevron_left_rounded
                                  : Icons.chevron_right_rounded,
                              size: 20,
                              color: p.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KCreator.numbersTop),
              Row(
                children: [
                  column(
                    CreatorCenterScreen.minutesKey,
                    stats == null ? null : stats.live.liveSeconds ~/ 60,
                    l10n.creatorLiveMinutes,
                  ),
                  divider,
                  column(
                    CreatorCenterScreen.fansKey,
                    stats == null ? null : (stats.followersNew ?? 0),
                    l10n.creatorNewFans,
                  ),
                  divider,
                  column(
                    CreatorCenterScreen.earningsKey,
                    stats?.live.earningsCoins,
                    l10n.creatorNewEarnings,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The admin's promo banners (the live hub's, D124) — nothing when there
/// is none or they fail to load.
class _BannerSlot extends ConsumerWidget {
  const new({required this.onOpen});

  final ValueChanged<HomeBanner> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(homeBannersProvider).value ?? const [];
    if (banners.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: CreatorCenterScreen.bannerKey,
      padding: const EdgeInsets.fromLTRB(
        KCreator.side,
        KCreator.bannerTop,
        KCreator.side,
        0,
      ),
      child: KHomeBannerCarousel(
        banners: banners,
        onOpen: onOpen,
        canOpen: (b) => HomeBannerTarget.parse(b.link) != null,
      ),
    );
  }
}

/// «خدمات البث»: a white card with a two-column grid of tiles.
class _Services extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback? Function(CreatorService service) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final labels = {
      CreatorService.preview: l10n.creatorSvcPreview,
      CreatorService.cover: l10n.creatorSvcCover,
      CreatorService.events: l10n.creatorSvcEvents,
      CreatorService.hostLevel: l10n.creatorSvcHostLevel,
      CreatorService.violations: l10n.creatorSvcViolations,
      CreatorService.traffic: l10n.liveToolTrafficCard,
      CreatorService.academy: l10n.creatorSvcAcademy,
      CreatorService.support: l10n.creatorSvcSupport,
      CreatorService.identity: l10n.creatorSvcIdentity,
      CreatorService.fans: l10n.creatorSvcFans,
    };
    const icons = {
      CreatorService.preview: Icons.play_circle_outline_rounded,
      CreatorService.cover: Icons.photo_outlined,
      CreatorService.events: Icons.campaign_outlined,
      CreatorService.hostLevel: Icons.workspace_premium_outlined,
      CreatorService.violations: Icons.warning_amber_rounded,
      CreatorService.traffic: Icons.trending_up_rounded,
      CreatorService.academy: Icons.school_outlined,
      CreatorService.support: Icons.headset_mic_outlined,
      CreatorService.identity: Icons.badge_outlined,
      CreatorService.fans: Icons.favorite_border_rounded,
    };
    const services = CreatorService.values;
    final rows = <Widget>[];
    for (var i = 0; i < services.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: KCreator.tileGap));
      Widget tile(CreatorService s) => Expanded(
        child: _ServiceTile(
          service: s,
          icon: icons[s]!,
          label: labels[s]!,
          onTap: onTap(s),
        ),
      );
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile(services[i]),
              const SizedBox(width: KCreator.tileGap),
              tile(services[i + 1]),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KCreator.side,
        KCreator.servicesTop,
        KCreator.side,
        0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: BorderRadius.circular(KCreator.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: KCreator.tilesTop,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: KCreator.servicesTitleStart,
                  top: KCreator.servicesTitleTop,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.creatorServices,
                    maxLines: 1,
                    style: t.title.copyWith(
                      fontSize: KCreator.servicesTitleSize,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KCreator.tilesInset,
                0,
                KCreator.tilesInset,
                KCreator.tilesInset,
              ),
              child: Column(children: rows),
            ),
          ],
        ),
      ),
    );
  }
}

/// One service: a tinted circle with the icon, the label beside it; faded
/// with «قريباً» when not built ([onTap] null).
class _ServiceTile extends StatelessWidget {
  const new({
    required this.service,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final CreatorService service;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final soon = onTap == null;
    final face = Row(
      children: [
        const SizedBox(width: KCreator.tileCircleStart),
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(p.background, p.primary, 0.08),
          ),
          child: SizedBox.square(
            dimension: KCreator.tileCircle,
            child: Icon(icon, size: KCreator.tileIcon, color: p.primary),
          ),
        ),
        const SizedBox(width: KCreator.tileTextGap),
        Expanded(
          child: Text(
            label,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.body.copyWith(
              fontSize: KCreator.tileTextSize,
              height: 1.1,
              fontWeight: FontWeight.w500,
              color: p.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: KSpacing.sm),
      ],
    );
    final radius = BorderRadius.circular(KCreator.tileRadius);
    return Semantics(
      key: service.key,
      button: true,
      enabled: !soon,
      label: soon ? context.l10n.meHubSoonItem(label) : label,
      excludeSemantics: true,
      child: Material(
        color: p.background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: p.border.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KCreator.tileHeight),
            child: Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [
                if (soon)
                  // Room under the «قريباً» tag when large text makes the
                  // tile taller (no change at 1.0: 41 + 36 < 78.7 lp).
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Opacity(opacity: KMeHub.soonOpacity, child: face),
                  )
                else
                  face,
                if (soon)
                  const PositionedDirectional(
                    top: KSpacing.xs,
                    end: KSpacing.xs,
                    child: MeHubSoonTag(key: CreatorCenterScreen.soonKey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «ابدأ البث»: a Kabso red gradient pill.
class _GoLiveButton extends StatelessWidget {
  const new({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.creatorGoLive;
    final radius = BorderRadius.circular(KRadius.pill);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: SizedBox(
        width: KCreator.goLiveWidth,
        height: KCreator.goLiveHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              colors: [KBrandColors.red400, KBrandColors.red500],
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: CreatorCenterScreen.goLiveKey,
              onTap: onPressed,
              borderRadius: radius,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: KMetrics.topBarMaxTextScale),
                  style: context.textStyles.title.copyWith(
                    fontSize: KCreator.goLiveTextSize,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
