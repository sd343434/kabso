import 'dart:ui' show ImageFilter;

import 'package:clock/clock.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/feed_comments_sheet.dart';
import 'package:kabso_live/features/debug/feed_share_sheet.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the KL-056 reels and posts preview, measured from the owner's
/// Figma reference ("Shorts - Reels App UI", Home node 26802:1788, 390x844).
/// Only geometry and type sizes are taken from it: Kabso red replaces the
/// kit's yellow, media is generated art, icons are the owner's set.
abstract final class KReels {
  static const double edge = 16;
  static const double appBarRow = 32;
  static const double appBarPad = 16;
  static const double tabSize = 20;
  static const double tabGap = 8;
  static const double friendAvatar = 15;
  static const double friendOverlap = 7;
  static const double coinSize = 28;
  static const double coinText = 14;
  static const Color glass = Color(0x33FFFFFF);
  static const double railIcon = 24;
  static const double railGap = 24;
  static const double railLabel = 10;
  static const double railLabelGap = 4;
  static const double infoAvatar = 32;
  static const double nameSize = 20;
  static const double verified = 16;
  static const double metaSize = 10;
  static const double metaIcon = 10;
  static const double captionSize = 12;
  static const double captionHeight = 16 / 12;
  static const double locationIcon = 16;
  static const double infoGap = 8;
  static const double infoMaxWidth = 294;
  static const double contentBottom = 20;
  static const double progress = 4;
  static const double navIcon = 24;
  static const double navLabel = 12;
  static const double navGap = 4;
  static const double navPad = 8;

  /// Posts mode (owner direction: Instagram-like scroll of photo and text
  /// posts). No measured reference: Kabso spacing tokens.
  static const double postAvatar = 36;
  static const double postAction = 26;

  static const List<Shadow> textShadow = [
    Shadow(blurRadius: 8, offset: Offset(0, 2)),
  ];
}

/// A reel or a post of the preview (labelled test data, D46).
class ReelPreview {
  const new({
    required this.seed,
    required this.author,
    required this.caption,
    required this.at,
    required this.likes,
    required this.comments,
    required this.shares,
    this.location,
    this.verified = false,
    this.progress = 0.25,
    this.hasMedia = true,
    this.avatarSeed = 0,
  });

  final int seed;
  final String author;
  final String caption;
  final DateTime at;
  final int likes;
  final int comments;
  final int shares;
  final String? location;
  final bool verified;

  /// Fixed playback position: there is no video in the preview.
  final double progress;

  /// Posts only: false for a text-only post.
  final bool hasMedia;

  /// Which preview headshot the author gets (matches the test name).
  final int avatarSeed;
}

List<ReelPreview> reelsPreviewFixture({
  required bool ar,
  required DateTime now,
}) => [
  ReelPreview(
    seed: 31,
    author: ar ? 'نور (تجربة)' : 'Nour (test)',
    avatarSeed: 2,
    caption: ar
        ? 'مساء هادئ في الحديقة، نص تجريبي يلتف على سطرين #بيانات_اختبار'
        : 'A quiet evening in the park, a test caption that wraps onto '
              'two lines #test_data',
    at: now.subtract(const Duration(days: 2)),
    likes: 432000,
    comments: 123000,
    shares: 98000,
    location: ar ? 'موقع تجريبي' : 'Test location',
    verified: true,
    progress: 0.23,
  ),
  ReelPreview(
    seed: 32,
    author: ar ? 'سامي (تجربة)' : 'Sami (test)',
    avatarSeed: 1,
    caption: ar ? 'جولة سريعة #بيانات_اختبار' : 'A quick tour #test_data',
    at: now.subtract(const Duration(hours: 5)),
    likes: 8400,
    comments: 312,
    shares: 45,
    progress: 0.6,
  ),
];

List<ReelPreview> postsPreviewFixture({
  required bool ar,
  required DateTime now,
}) => [
  ReelPreview(
    seed: 41,
    author: ar ? 'ليلى (تجربة)' : 'Layla (test)',
    caption: ar
        ? 'صورة تجريبية من رحلة اليوم #بيانات_اختبار'
        : "A test photo from today's trip #test_data",
    at: now.subtract(const Duration(hours: 3)),
    likes: 1240,
    comments: 86,
    shares: 12,
    location: ar ? 'موقع تجريبي' : 'Test location',
    verified: true,
  ),
  ReelPreview(
    seed: 42,
    author: ar ? 'عمر (تجربة)' : 'Omar (test)',
    avatarSeed: 1,
    caption: ar
        ? 'منشور نصي تجريبي بدون صورة، ليظهر كيف يبدو النص وحده.'
        : 'A text-only test post, to show how text looks on its own.',
    at: now.subtract(const Duration(days: 1)),
    likes: 57,
    comments: 4,
    shares: 0,
    hasMedia: false,
  ),
  ReelPreview(
    seed: 43,
    author: ar ? 'هند (تجربة)' : 'Hind (test)',
    avatarSeed: 2,
    caption: ar ? 'لقطة أخرى #كبسو' : 'Another shot #kabso',
    at: now.subtract(const Duration(days: 4)),
    likes: 15800,
    comments: 230,
    shares: 41,
  ),
];

enum ReelsMode { reels, posts }

enum ReelsTab { forYou, friends }

/// `/debug/reels-preview` — KL-056 reels and posts (owner direction): a
/// Reels/Posts switch and For you · Friends tabs at the top, the coin
/// balance, and the app's bottom bar (D48: Home · Discover · Create · Reels ·
/// Profile). Likes and saves change local state only. The real Reels tab
/// (For you · Posts · Reels) is `features/home/feed_screen.dart`.
class ReelsPreviewScreen extends StatefulWidget {
  const new({super.key, this.initialMode = ReelsMode.reels});

  final ReelsMode initialMode;

  static const testDataKey = Key('reels-preview-test-data');
  static const modeKey = Key('reels-preview-mode');
  static const coinsKey = Key('reels-preview-coins');
  static const pagerKey = Key('reels-preview-pager');
  static const postsKey = Key('reels-preview-posts');
  static const railKey = Key('reels-preview-rail');
  static const infoKey = Key('reels-preview-info');
  static const progressKey = Key('reels-preview-progress');
  static const navKey = Key('reels-preview-nav');

  /// Test balance shown in the coin badge.
  static const int testCoins = 2133;

  @override
  State<ReelsPreviewScreen> createState() => _ReelsPreviewScreenState();
}

class _ReelsPreviewScreenState extends State<ReelsPreviewScreen> {
  late ReelsMode _mode = widget.initialMode;
  ReelsTab _tab = ReelsTab.forYou;
  final _liked = <int>{};
  final _saved = <int>{};

  void _toggle(Set<int> set, int seed) =>
      setState(() => set.contains(seed) ? set.remove(seed) : set.add(seed));

  @override
  Widget build(BuildContext context) {
    final ar = Directionality.of(context) == TextDirection.rtl;
    final now = clock.now();
    final reels = _mode == ReelsMode.reels;
    final top = SafeArea(
      bottom: false,
      child: _TopBar(
        mode: _mode,
        tab: _tab,
        onMode: (m) => setState(() => _mode = m),
        onTab: (t) => setState(() => _tab = t),
      ),
    );
    return Theme(
      data: buildAppTheme(
        brightness: Brightness.dark,
        locale: Localizations.localeOf(context),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: reels
            ? Stack(
                children: [
                  PageView(
                    key: ReelsPreviewScreen.pagerKey,
                    scrollDirection: Axis.vertical,
                    children: [
                      for (final r in reelsPreviewFixture(ar: ar, now: now))
                        _ReelPage(
                          reel: r,
                          liked: _liked.contains(r.seed),
                          saved: _saved.contains(r.seed),
                          onLike: () => _toggle(_liked, r.seed),
                          onSave: () => _toggle(_saved, r.seed),
                        ),
                    ],
                  ),
                  top,
                ],
              )
            : Column(
                children: [
                  top,
                  Expanded(
                    child: ListView(
                      key: ReelsPreviewScreen.postsKey,
                      children: [
                        for (final p in postsPreviewFixture(ar: ar, now: now))
                          _PostCard(
                            post: p,
                            liked: _liked.contains(p.seed),
                            saved: _saved.contains(p.seed),
                            onLike: () => _toggle(_liked, p.seed),
                            onSave: () => _toggle(_saved, p.seed),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: const _ReelsNavBar(),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const new({
    required this.mode,
    required this.tab,
    required this.onMode,
    required this.onTab,
  });

  final ReelsMode mode;
  final ReelsTab tab;
  final ValueChanged<ReelsMode> onMode;
  final ValueChanged<ReelsTab> onTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = KPalette.dark.textPrimary;
    Widget tabText(ReelsTab t, String label) => Semantics(
      button: true,
      selected: t == tab,
      child: InkWell(
        onTap: () => onTab(t),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyles.bodyStrong.copyWith(
            fontSize: KReels.tabSize,
            fontWeight: FontWeight.w700,
            color: white.withValues(alpha: t == tab ? 1 : 0.5),
            shadows: KReels.textShadow,
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KReels.edge,
        vertical: KSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Scales down only when a large text size leaves no room.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: _ModeSwitch(mode: mode, onChanged: onMode),
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              const _CoinBadge(),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          SizedBox(
            height: KReels.appBarRow,
            child: Row(
              children: [
                Flexible(child: tabText(ReelsTab.forYou, l10n.reelsTabForYou)),
                const SizedBox(width: KReels.tabGap * 2),
                Flexible(
                  child: tabText(ReelsTab.friends, l10n.reelsTabFriends),
                ),
                const SizedBox(width: 2),
                // Friend faces next to the tab (initials, test names).
                ExcludeSemantics(
                  child: Opacity(
                    opacity: tab == ReelsTab.friends ? 1 : 0.5,
                    child: SizedBox(
                      width: KReels.friendAvatar + 2 * KReels.friendOverlap + 2,
                      height: KReels.friendAvatar,
                      child: Stack(
                        children: [
                          for (final (i, c) in [
                            context.palette.primary,
                            KBrandColors.gold,
                            context.palette.info,
                          ].indexed)
                            PositionedDirectional(
                              start: i * KReels.friendOverlap,
                              child: Container(
                                width: KReels.friendAvatar,
                                height: KReels.friendAvatar,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Flexible(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DecoratedBox(
                      key: ReelsPreviewScreen.testDataKey,
                      decoration: BoxDecoration(
                        color: KLiveColors.chatScrim,
                        borderRadius: BorderRadius.circular(KRadius.xs),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: KSpacing.xs,
                          vertical: KSpacing.xxs,
                        ),
                        child: Text(
                          l10n.feedPreviewTestData,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.caption.copyWith(
                            color: white,
                          ),
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
    );
  }
}

/// Reels | Posts switch (owner direction).
class _ModeSwitch extends StatelessWidget {
  const new({required this.mode, required this.onChanged});

  final ReelsMode mode;
  final ValueChanged<ReelsMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final white = KPalette.dark.textPrimary;
    Widget segment(ReelsMode m, String label) {
      final selected = m == mode;
      return Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: () => onChanged(m),
          borderRadius: BorderRadius.circular(KRadius.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: selected ? p.primary : const Color(0x00000000),
              borderRadius: BorderRadius.circular(KRadius.pill),
            ),
            child: Text(
              label,
              style: context.textStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? p.onPrimary : white,
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: l10n.reelsModeLabel,
      child: Container(
        key: ReelsPreviewScreen.modeKey,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: KReels.glass,
          borderRadius: BorderRadius.circular(KRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            segment(ReelsMode.reels, l10n.reelsModeReels),
            segment(ReelsMode.posts, l10n.reelsModePosts),
          ],
        ),
      ),
    );
  }
}

/// Coin balance (test value): the coin disc overlaps the pill's start.
class _CoinBadge extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final count = KFormat.grouped(ReelsPreviewScreen.testCoins);
    return Semantics(
      label: l10n.reelsCoins(count),
      excludeSemantics: true,
      child: Container(
        key: ReelsPreviewScreen.coinsKey,
        height: KReels.coinSize,
        padding: const EdgeInsetsDirectional.only(start: 2, end: 8),
        decoration: BoxDecoration(
          color: KReels.glass,
          borderRadius: BorderRadius.circular(KRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppIcon(
              AppIcons.coinGold,
              size: KReels.coinSize - 4,
              tint: false,
            ),
            const SizedBox(width: KSpacing.xxs),
            Text(
              count,
              style: context.textStyles.caption.copyWith(
                fontSize: KReels.coinText,
                fontWeight: FontWeight.w600,
                color: KPalette.dark.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelPage extends StatelessWidget {
  const new({
    required this.reel,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onSave,
  });

  final ReelPreview reel;
  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Stack(
      fit: StackFit.expand,
      children: [
        PreviewPhoto(reel.seed),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.2, 0.6, 1],
              colors: [
                Color(0x66000000),
                Color(0x00000000),
                Color(0x00000000),
                Color(0x99000000),
              ],
            ),
          ),
        ),
        PositionedDirectional(
          end: KReels.edge,
          bottom: KReels.contentBottom,
          child: _Rail(
            reel: reel,
            liked: liked,
            saved: saved,
            onLike: onLike,
            onSave: onSave,
          ),
        ),
        PositionedDirectional(
          start: KReels.edge,
          end: KReels.edge + KReels.railIcon + KSpacing.xl,
          bottom: KReels.contentBottom,
          child: Align(
            alignment: AlignmentDirectional.bottomStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: KReels.infoMaxWidth),
              child: _Info(reel: reel),
            ),
          ),
        ),
        // Playback position along the bottom edge of the video.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Semantics(
            label: context.l10n.reelsProgress,
            value: '${(reel.progress * 100).round()}%',
            child: SizedBox(
              key: ReelsPreviewScreen.progressKey,
              height: KReels.progress,
              child: LinearProgressIndicator(
                value: reel.progress,
                color: p.primary,
                backgroundColor: KReels.glass,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A white icon legible on any video frame: a soft shadow of the glyph's own
/// shape sits under it (a box shadow would draw a dark disc).
class _ShadowedIcon extends StatelessWidget {
  const new(this.asset, {required this.size, required this.color});

  final String asset;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Transform.translate(
        offset: const Offset(0, 1),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: AppIcon(asset, size: size, color: const Color(0x73000000)),
        ),
      ),
      AppIcon(asset, size: size, color: color),
    ],
  );
}

class _Info extends StatelessWidget {
  const new({required this.reel});

  final ReelPreview reel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final white = KPalette.dark.textPrimary;
    final t = context.textStyles;
    final time =
        KFormat.relative(
          reel.at,
          clock.now(),
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
        ) ??
        l10n.feedPostJustNow;
    final meta = t.caption.copyWith(
      fontSize: KReels.captionSize,
      height: KReels.captionHeight,
      color: white,
      shadows: KReels.textShadow,
    );
    return Column(
      key: ReelsPreviewScreen.infoKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            KAvatar(
              name: reel.author,
              image: PreviewPhotos.avatar(reel.avatarSeed),
              size: KReels.infoAvatar,
            ),
            const SizedBox(width: KReels.infoGap),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          reel.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(
                            fontSize: KReels.nameSize,
                            fontWeight: FontWeight.w700,
                            color: white,
                            shadows: KReels.textShadow,
                          ),
                        ),
                      ),
                      if (reel.verified) ...[
                        const SizedBox(width: KSpacing.xxs * 2),
                        Semantics(
                          container: true,
                          label: l10n.commentsVerified,
                          child: AppIcon(
                            AppIcons.checkCircle,
                            size: KReels.verified,
                            color: p.info,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ShadowedIcon(
                        AppIcons.clock,
                        size: KReels.metaIcon,
                        color: white,
                      ),
                      const SizedBox(width: KSpacing.xxs * 2),
                      Text(
                        time,
                        style: meta.copyWith(fontSize: KReels.metaSize),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: KReels.infoGap),
        Text(
          reel.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: meta,
        ),
        if (reel.location != null) ...[
          const SizedBox(height: KReels.infoGap),
          Row(
            children: [
              _ShadowedIcon(
                AppIcons.location,
                size: KReels.locationIcon,
                color: white,
              ),
              const SizedBox(width: KSpacing.xxs * 2),
              Flexible(
                child: Text(
                  reel.location!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: meta,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const new({
    required this.reel,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onSave,
  });

  final ReelPreview reel;
  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final white = KPalette.dark.textPrimary;
    Widget item(
      String asset,
      String label,
      String semantics,
      VoidCallback onTap, {
      Color? color,
      bool selected = false,
    }) => Semantics(
      button: true,
      selected: selected,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ShadowedIcon(asset, size: KReels.railIcon, color: color ?? white),
            const SizedBox(height: KReels.railLabelGap),
            Text(
              label,
              maxLines: 1,
              style: context.textStyles.caption.copyWith(
                fontSize: KReels.railLabel,
                color: white,
                shadows: KReels.textShadow,
              ),
            ),
          ],
        ),
      ),
    );
    final likes = KFormat.compact(reel.likes + (liked ? 1 : 0), l10n);
    final comments = KFormat.compact(reel.comments, l10n);
    final shares = KFormat.compact(reel.shares, l10n);
    return Column(
      key: ReelsPreviewScreen.railKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        item(
          AppIcons.heartFilled,
          likes,
          '${l10n.feedActionLike}, $likes',
          onLike,
          color: liked ? p.primary : null,
          selected: liked,
        ),
        const SizedBox(height: KReels.railGap),
        item(
          AppIcons.commentFilled,
          comments,
          '${l10n.feedActionComment}, $comments',
          () => FeedCommentsSheet.show(context),
        ),
        const SizedBox(height: KReels.railGap),
        item(
          AppIcons.shareFilled,
          shares,
          '${l10n.liveShare}, $shares',
          () => FeedShareSheet.show(context),
        ),
        const SizedBox(height: KReels.railGap),
        item(
          AppIcons.bookmarkFilled,
          saved ? l10n.reelsSaved : l10n.reelsSave,
          saved ? l10n.reelsSaved : l10n.reelsSave,
          onSave,
          color: saved ? KBrandColors.gold : null,
          selected: saved,
        ),
        const SizedBox(height: KReels.railGap),
        item(
          AppIcons.moreHoriz,
          l10n.livePreviewMore,
          l10n.livePreviewMore,
          () => _MoreSheet.show(context),
        ),
      ],
    );
  }
}

/// "More" actions; each closes the sheet (preview only).
class _MoreSheet extends StatelessWidget {
  const new();

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    builder: (_) => const _MoreSheet(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final close = Navigator.of(context).maybePop;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: AppIcon(
              AppIcons.eyeOff,
              color: context.palette.textPrimary,
            ),
            title: Text(l10n.reelsNotInterested),
            onTap: close,
          ),
          ListTile(
            leading: AppIcon(AppIcons.flag, color: context.palette.textPrimary),
            title: Text(l10n.shareReport),
            onTap: close,
          ),
        ],
      ),
    );
  }
}

/// Instagram-like post card (owner direction): header, square media (or
/// text only), actions, likes, caption and the comments link.
class _PostCard extends StatelessWidget {
  const new({
    required this.post,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onSave,
  });

  final ReelPreview post;
  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    final time =
        KFormat.relative(
          post.at,
          clock.now(),
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
        ) ??
        l10n.feedPostJustNow;
    final likes = KFormat.compact(post.likes + (liked ? 1 : 0), l10n);
    Widget action(
      String asset,
      String label,
      VoidCallback onTap, {
      Color? color,
      bool selected = false,
    }) => Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        onPressed: onTap,
        icon: AppIcon(
          asset,
          size: KReels.postAction,
          color: color ?? p.textPrimary,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KReels.edge,
              KSpacing.sm,
              KSpacing.xs,
              KSpacing.sm,
            ),
            child: Row(
              children: [
                KAvatar(
                  name: post.author,
                  image: PreviewPhotos.avatar(post.avatarSeed),
                  size: KReels.postAvatar,
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodyStrong.copyWith(
                                color: p.textPrimary,
                              ),
                            ),
                          ),
                          if (post.verified) ...[
                            const SizedBox(width: KSpacing.xxs * 2),
                            Semantics(
                              container: true,
                              label: l10n.commentsVerified,
                              child: AppIcon(
                                AppIcons.checkCircle,
                                size: 14,
                                color: p.info,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        post.location == null
                            ? time
                            : '$time · ${post.location}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.livePreviewMore,
                  onPressed: () => _MoreSheet.show(context),
                  icon: AppIcon(
                    AppIcons.moreHoriz,
                    size: 22,
                    color: p.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (post.hasMedia)
            AspectRatio(
              aspectRatio: 1,
              child: PreviewPhoto(post.seed, kind: PreviewPhotoKind.landscape),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KReels.edge),
              child: Text(
                post.caption,
                style: t.body.copyWith(
                  fontSize: 17,
                  height: 1.4,
                  color: p.textPrimary,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
            child: Row(
              children: [
                action(
                  liked ? AppIcons.heartFilled : AppIcons.heart,
                  '${l10n.feedActionLike}, $likes',
                  onLike,
                  color: liked ? p.primary : null,
                  selected: liked,
                ),
                action(
                  AppIcons.comment,
                  l10n.feedActionComment,
                  () => FeedCommentsSheet.show(context),
                ),
                action(
                  AppIcons.share,
                  l10n.liveShare,
                  () => FeedShareSheet.show(context),
                ),
                const Spacer(),
                action(
                  saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
                  saved ? l10n.reelsSaved : l10n.reelsSave,
                  onSave,
                  selected: saved,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KReels.edge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.postsLikes(likes),
                  style: t.bodyStrong.copyWith(color: p.textPrimary),
                ),
                if (post.hasMedia) ...[
                  const SizedBox(height: KSpacing.xxs),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: KFormat.bidiIsolate(post.author),
                          style: t.bodyStrong.copyWith(color: p.textPrimary),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(text: post.caption),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: p.textPrimary),
                  ),
                ],
                if (post.comments > 0) ...[
                  const SizedBox(height: KSpacing.xxs),
                  InkWell(
                    onTap: () => FeedCommentsSheet.show(context),
                    child: Text(
                      l10n.postsViewComments(
                        KFormat.compact(post.comments, l10n),
                      ),
                      style: t.body.copyWith(color: p.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The app's bottom bar (D48): Home (the live hub) · Discover · Create ·
/// Reels · Profile, with Reels selected; the others open the matching
/// preview or app route.
class _ReelsNavBar extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final white = KPalette.dark.textPrimary;
    Widget item(
      String icon,
      String label,
      VoidCallback onTap, {
      bool selected = false,
    }) => Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(KReels.navPad),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  icon,
                  size: KReels.navIcon,
                  color: selected ? p.primary : white,
                ),
                const SizedBox(height: KReels.navGap),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.caption.copyWith(
                    fontSize: KReels.navLabel,
                    fontWeight: FontWeight.w500,
                    color: selected ? p.primary : white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return DecoratedBox(
      key: ReelsPreviewScreen.navKey,
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border(top: BorderSide(color: Color(0x0D0C0C0D))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: KSpacing.xxs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              item(
                AppIcons.home,
                l10n.navHome,
                () => context.push(AppRoutes.debugLivePreview),
              ),
              item(
                AppIcons.search,
                l10n.navDiscover,
                () => context.push(AppRoutes.debugDiscoverPreview),
              ),
              item(
                AppIcons.plus,
                l10n.navCreate,
                () => context.go(AppRoutes.create),
              ),
              item(AppIcons.reels, l10n.navReels, () {}, selected: true),
              item(
                AppIcons.profile,
                l10n.navProfile,
                () => context.go(AppRoutes.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
