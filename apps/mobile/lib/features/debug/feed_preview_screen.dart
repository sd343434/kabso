import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/feed_glyphs.dart';
import 'package:kabso_live/features/debug/feed_share_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// KL-056 preview of a full-screen vertical Home feed (owner direction:
/// TikTok-style layout in Kabso's identity). `!kReleaseMode` only.
///
/// No posts API exists (D37/D39), so every post is a labelled test fixture
/// with generated art: no third-party media, names or photos. The layout
/// follows the owner's reference (kept outside the repo, D40); TikTok's
/// own marks (two-colour create button, LIVE TV glyph, sound disc) are not
/// reproduced.
class FeedPreviewScreen extends StatefulWidget {
  const new({super.key});

  static const testDataKey = Key('feedPreview.testData');
  static const pagerKey = Key('feedPreview.pager');
  static const railKey = Key('feedPreview.rail');
  static const captionKey = Key('feedPreview.caption');
  static const navKey = Key('feedPreview.nav');
  static const liveEntryKey = Key('feedPreview.live');
  static const searchKey = Key('feedPreview.search');

  @override
  State<FeedPreviewScreen> createState() => _FeedPreviewScreenState();
}

class _FeedPreviewScreenState extends State<FeedPreviewScreen> {
  /// Start → end; the selected tab sits at the end, as in the reference.
  static const List<FeedTab> _tabs = [
    FeedTab.latest,
    FeedTab.following,
    FeedTab.popular,
  ];

  FeedTab _tab = FeedTab.popular;

  @override
  Widget build(BuildContext context) {
    final ar = Directionality.of(context) == TextDirection.rtl;
    final posts = feedPreviewFixture(ar: ar);
    return Theme(
      data: buildAppTheme(
        brightness: Brightness.dark,
        locale: Localizations.localeOf(context),
      ),
      child: Scaffold(
        backgroundColor: KFeedPreview.chrome,
        body: Stack(
          children: [
            PageView.builder(
              key: FeedPreviewScreen.pagerKey,
              scrollDirection: Axis.vertical,
              itemCount: posts.length,
              itemBuilder: (_, i) => _FeedPage(post: posts[i]),
            ),
            SafeArea(
              bottom: false,
              child: _TopBar(
                tabs: _tabs,
                selected: _tab,
                onSelected: (t) => setState(() => _tab = t),
              ),
            ),
          ],
        ),
        bottomNavigationBar: const _FeedNavBar(),
      ),
    );
  }
}

/// Layout values estimated from the owner's reference (430×932 lp; no pixel
/// measurement was possible, so these are E-tagged estimates).
abstract final class KFeedPreview {
  // Measured from the owner's Figma reference (UI kit "Home page", 414x896,
  // node 1346:1891). Only geometry and type sizes are taken from it.
  static const Color chrome = Color(0xFF000000);
  static const double topBarHeight = 40;
  static const double tabFontSize = 18;
  static const double tabGap = 30;
  static const double tabIndicatorWidth = 29;
  static const double tabIndicatorHeight = 3;
  // The design's rail column is centred 35 from the edge; the wider column
  // keeps that centre and fits Arabic counts such as "10.1 ألف".
  static const double railEndInset = 3;
  static const double railWidth = 64;
  static const double railAvatar = 47;
  static const double railFollowBadge = 22;
  static const double railIcon = 34;
  static const double topBarIcon = 24;
  static const double railAvatarGap = 31;
  static const double railItemGap = 20;
  static const double railCountFontSize = 13;
  static const double captionInset = 13;
  static const double captionGap = 11;
  static const double contentBottom = 13;
  static const double navHeight = 52;
  static const double navIcon = 25;
  static const double navLabelSize = 10;
  static const double navLabelGap = 2;
  static const Color navDivider = Color(0xFF333333);
  static const Size createButton = Size(46, 31);

  /// Legibility for white text and glyphs over any art.
  static const List<Shadow> textShadow = [
    Shadow(color: Color(0x7D000000), blurRadius: 4.3, offset: Offset(0, 1)),
  ];
}

class _TopBar extends StatelessWidget {
  const new({
    required this.tabs,
    required this.selected,
    required this.onSelected,
  });

  final List<FeedTab> tabs;
  final FeedTab selected;
  final ValueChanged<FeedTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = KPalette.dark.textPrimary;
    String label(FeedTab t) => switch (t) {
      FeedTab.following => l10n.feedTabFollowing,
      FeedTab.popular => l10n.feedTabPopular,
      FeedTab.latest => l10n.feedTabNew,
    };
    return SizedBox(
      height: KFeedPreview.topBarHeight,
      child: Row(
        children: [
          IconButton(
            key: FeedPreviewScreen.liveEntryKey,
            tooltip: l10n.feedOpenLive,
            onPressed: () => context.go(AppRoutes.live),
            icon: FeedGlyphIcon(
              FeedGlyph.live,
              size: KFeedPreview.topBarIcon,
              color: white,
              shadow: true,
            ),
          ),
          Expanded(
            // Large text or narrow screens shrink the row instead of
            // overflowing or hiding a tab.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final t in tabs) ...[
                    if (t != tabs.first)
                      const SizedBox(width: KFeedPreview.tabGap),
                    _Tab(
                      label: label(t),
                      selected: t == selected,
                      onTap: () => onSelected(t),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            key: FeedPreviewScreen.searchKey,
            tooltip: l10n.feedSearch,
            onPressed: () {},
            icon: FeedGlyphIcon(
              FeedGlyph.search,
              size: KFeedPreview.topBarIcon,
              color: white,
              shadow: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const new({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final white = KPalette.dark.textPrimary;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: KSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.textStyles.bodyStrong.copyWith(
                  fontSize: KFeedPreview.tabFontSize,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? white : white.withValues(alpha: 0.65),
                  shadows: KFeedPreview.textShadow,
                ),
              ),
              const SizedBox(height: KSpacing.xxs),
              Container(
                width: KFeedPreview.tabIndicatorWidth,
                height: KFeedPreview.tabIndicatorHeight,
                color: selected ? white : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedPage extends StatelessWidget {
  const new({required this.post});

  final FeedPreviewPost post;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          image: true,
          label: post.artLabel,
          child: CustomPaint(painter: FeedPreviewArt(post.seed)),
        ),
        // Bottom scrim so the caption and counts stay readable.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.676, 1],
              colors: [Color(0x00000000), Color(0xC3000000)],
            ),
          ),
        ),
        PositionedDirectional(
          top: MediaQuery.paddingOf(context).top + KFeedPreview.topBarHeight,
          start: KFeedPreview.captionInset,
          child: const _TestDataLabel(),
        ),
        PositionedDirectional(
          end: KFeedPreview.railEndInset,
          bottom: KFeedPreview.contentBottom,
          width: KFeedPreview.railWidth,
          child: _ActionRail(post: post),
        ),
        PositionedDirectional(
          start: KFeedPreview.captionInset,
          end: KFeedPreview.railEndInset + KFeedPreview.railWidth + KSpacing.sm,
          bottom: KFeedPreview.contentBottom,
          child: _Caption(post: post),
        ),
      ],
    );
  }
}

class _TestDataLabel extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: FeedPreviewScreen.testDataKey,
    decoration: BoxDecoration(
      color: KLiveColors.chatScrim,
      borderRadius: BorderRadius.circular(KRadius.xs),
    ),
    child: Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: KSpacing.xs,
        vertical: KSpacing.xxs,
      ),
      child: Text(
        context.l10n.feedPreviewTestData,
        style: context.textStyles.caption.copyWith(
          color: KPalette.dark.textPrimary,
        ),
      ),
    ),
  );
}

class _ActionRail extends StatelessWidget {
  const new({required this.post});

  final FeedPreviewPost post;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final white = KPalette.dark.textPrimary;

    Widget action(
      FeedGlyph glyph,
      int count,
      String label, {
      VoidCallback? onTap,
    }) => Semantics(
      button: true,
      label: '$label, ${KFormat.compact(count, l10n)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap ?? () {},
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FeedGlyphIcon(
              glyph,
              size: KFeedPreview.railIcon,
              color: white,
              shadow: true,
            ),
            const SizedBox(height: KSpacing.xxs),
            Text(
              KFormat.compact(count, l10n),
              maxLines: 1,
              style: context.textStyles.caption.copyWith(
                fontSize: KFeedPreview.railCountFontSize,
                fontWeight: FontWeight.w700,
                color: white,
                shadows: KFeedPreview.textShadow,
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      key: FeedPreviewScreen.railKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: '${l10n.liveFollow} ${post.displayName}',
          excludeSemantics: true,
          child: SizedBox(
            height: KFeedPreview.railAvatar + KFeedPreview.railFollowBadge / 2,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: white, width: 1.5),
                  ),
                  child: KAvatar(
                    name: post.displayName,
                    size: KFeedPreview.railAvatar,
                  ),
                ),
                PositionedDirectional(
                  bottom: 0,
                  child: Container(
                    width: KFeedPreview.railFollowBadge,
                    height: KFeedPreview.railFollowBadge,
                    decoration: BoxDecoration(
                      color: p.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: AppIcon(
                      AppIcons.plus,
                      size: KFeedPreview.railFollowBadge - 6,
                      color: p.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: KFeedPreview.railAvatarGap),
        action(FeedGlyph.heart, post.likes, l10n.feedActionLike),
        const SizedBox(height: KFeedPreview.railItemGap),
        action(FeedGlyph.comment, post.comments, l10n.feedActionComment),
        const SizedBox(height: KFeedPreview.railItemGap),
        action(FeedGlyph.bookmark, post.saves, l10n.feedActionSave),
        const SizedBox(height: KFeedPreview.railItemGap),
        // The share glyph is not mirrored: it points the same way in both
        // directions, as in the reference.
        action(
          FeedGlyph.share,
          post.shares,
          l10n.liveShare,
          onTap: () => FeedShareSheet.show(context),
        ),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const new({required this.post});

  final FeedPreviewPost post;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final white = KPalette.dark.textPrimary;
    return Column(
      key: FeedPreviewScreen.captionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          post.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.bodyStrong.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: white,
            shadows: KFeedPreview.textShadow,
          ),
        ),
        const SizedBox(height: KFeedPreview.captionGap),
        Text(
          post.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: t.body.copyWith(
            fontSize: 16,
            height: 1.15,
            color: white.withValues(alpha: 0.9),
            shadows: KFeedPreview.textShadow,
          ),
        ),
      ],
    );
  }
}

class _FeedNavBar extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final white = KPalette.dark.textPrimary;
    final dim = white.withValues(alpha: 0.65);

    Widget item(
      FeedGlyph glyph,
      String label,
      String route, {
      bool selected = false,
    }) => Expanded(
      child: Semantics(
        selected: selected,
        child: InkWell(
          onTap: () => context.go(route),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FeedGlyphIcon(
                glyph,
                size: KFeedPreview.navIcon,
                color: selected ? white : dim,
              ),
              const SizedBox(height: KFeedPreview.navLabelGap),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.caption.copyWith(
                  fontSize: KFeedPreview.navLabelSize,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? white : dim,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return DecoratedBox(
      key: FeedPreviewScreen.navKey,
      decoration: const BoxDecoration(
        color: KFeedPreview.chrome,
        border: Border(
          top: BorderSide(color: KFeedPreview.navDivider, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: KFeedPreview.navHeight,
          child: Row(
            children: [
              item(
                FeedGlyph.homeFilled,
                l10n.navHome,
                AppRoutes.home,
                selected: true,
              ),
              item(FeedGlyph.discover, l10n.navDiscover, AppRoutes.discover),
              Expanded(
                child: Center(
                  child: Semantics(
                    button: true,
                    label: l10n.navCreate,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => context.go(AppRoutes.create),
                      borderRadius: BorderRadius.circular(KRadius.sm),
                      // One solid Kabso red: no two-colour offset edges.
                      child: Container(
                        width: KFeedPreview.createButton.width,
                        height: KFeedPreview.createButton.height,
                        decoration: BoxDecoration(
                          color: p.primary,
                          borderRadius: BorderRadius.circular(KRadius.sm),
                        ),
                        alignment: Alignment.center,
                        child: AppIcon(AppIcons.plus, color: p.onPrimary),
                      ),
                    ),
                  ),
                ),
              ),
              item(FeedGlyph.live, l10n.navLive, AppRoutes.live),
              item(FeedGlyph.profile, l10n.navProfile, AppRoutes.profile),
            ],
          ),
        ),
      ),
    );
  }
}

/// One labelled test post (never shown in production).
@immutable
class FeedPreviewPost {
  const new({
    required this.seed,
    required this.displayName,
    required this.caption,
    required this.artLabel,
    required this.likes,
    required this.comments,
    required this.saves,
    required this.shares,
  });

  final int seed;
  final String displayName;
  final String caption;
  final String artLabel;
  final int likes;
  final int comments;
  final int saves;
  final int shares;
}

/// Labelled test posts with generated art (D35/D46: no invented data in
/// production; names say they are test accounts).
List<FeedPreviewPost> feedPreviewFixture({required bool ar}) => [
  FeedPreviewPost(
    seed: 1,
    displayName: ar ? 'نور (تجربة)' : 'Nour (test)',
    caption: ar
        ? 'مساء هادئ في الحديقة #بيانات_اختبار #كبسو'
        : 'A quiet evening in the park #test_data #kabso',
    artLabel: ar ? 'صورة مولّدة للاختبار' : 'Generated test art',
    likes: 10100,
    comments: 1945,
    saves: 1312,
    shares: 3662,
  ),
  FeedPreviewPost(
    seed: 2,
    displayName: ar ? 'سامي (تجربة)' : 'Sami (test)',
    caption: ar
        ? 'جولة سريعة في المدينة #بيانات_اختبار'
        : 'A quick tour of the city #test_data',
    artLabel: ar ? 'صورة مولّدة للاختبار' : 'Generated test art',
    likes: 482000,
    comments: 12400,
    saves: 30100,
    shares: 9050,
  ),
  FeedPreviewPost(
    seed: 3,
    displayName: ar ? 'ليلى (تجربة)' : 'Layla (test)',
    caption: ar
        ? 'وصفة اليوم خطوة بخطوة، وتجربة نص أطول يلتف على سطرين '
              'ثم يُختصر #بيانات_اختبار'
        : "Today's recipe step by step, and a longer caption that wraps "
              'onto two lines and then ends #test_data',
    artLabel: ar ? 'صورة مولّدة للاختبار' : 'Generated test art',
    likes: 87,
    comments: 4,
    saves: 0,
    shares: 2,
  ),
];

/// Deterministic generated art standing in for post media: a vertical
/// gradient sky, soft shapes and a ground band, varied by [seed].
class FeedPreviewArt extends CustomPainter {
  const new(this.seed);

  final int seed;

  static const _palettes = [
    [Color(0xFF6E8B74), Color(0xFFB7C7B0), Color(0xFF3E5A44)],
    [Color(0xFF283D63), Color(0xFF8A6BA8), Color(0xFF1B2238)],
    [Color(0xFF7A3B2E), Color(0xFFE0A15E), Color(0xFF3A1F1A)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final colors = _palettes[seed % _palettes.length];
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors[1], colors[0], colors[2]],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );
    final rnd = math.Random(seed);
    for (var i = 0; i < 7; i++) {
      final c = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height * 0.7,
      );
      canvas.drawCircle(
        c,
        size.shortestSide * (0.08 + rnd.nextDouble() * 0.18),
        Paint()..color = colors[i.isEven ? 1 : 0].withValues(alpha: 0.35),
      );
    }
    final ground = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * (0.70 + rnd.nextDouble() * 0.06),
        size.width,
        size.height * 0.80,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(ground, Paint()..color = colors[2].withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(FeedPreviewArt oldDelegate) => oldDelegate.seed != seed;
}
