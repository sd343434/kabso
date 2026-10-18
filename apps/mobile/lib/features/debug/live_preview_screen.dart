import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/feed_glyphs.dart';
import 'package:kabso_live/features/debug/feed_preview_screen.dart'
    show FeedPreviewArt;
import 'package:kabso_live/features/debug/feed_share_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// KL-056 preview of a full-screen live room in the owner's reference
/// layout (kept outside the repo, D40), in Kabso's identity.
/// `!kReleaseMode` only.
///
/// No live video or chat API exists yet (D37), so the host, viewers, chat
/// and counts are labelled test fixtures over generated art. TikTok's own
/// marks (pink follow, LIVE leagues, coin promo, promote button) are not
/// reproduced: Kabso red, a test weekly-rank chip, a balance button and a
/// More button take their places.
class LivePreviewScreen extends StatelessWidget {
  const new({super.key});

  static const testDataKey = Key('livePreview.testData');
  static const hostPillKey = Key('livePreview.host');
  static const followKey = Key('livePreview.follow');
  static const rankKey = Key('livePreview.rank');
  static const viewersKey = Key('livePreview.viewers');
  static const closeKey = Key('livePreview.close');
  static const chatKey = Key('livePreview.chat');
  static const bottomBarKey = Key('livePreview.bottomBar');
  static const inputKey = Key('livePreview.input');

  @override
  Widget build(BuildContext context) {
    final ar = Directionality.of(context) == TextDirection.rtl;
    final room = livePreviewFixture(ar: ar);
    return Theme(
      data: buildAppTheme(
        brightness: Brightness.dark,
        locale: Localizations.localeOf(context),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              image: true,
              label: context.l10n.liveVideoPlaceholder,
              child: const CustomPaint(painter: FeedPreviewArt(4)),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.18, 0.55, 1],
                  colors: [
                    Color(0x59000000),
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0x8C000000),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: KLivePreview.edge,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        // On narrow screens or large text the host pill
                        // gives way (its name truncates); the viewer cluster
                        // and Close keep their size.
                        Expanded(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: _HostPill(room: room),
                          ),
                        ),
                        const SizedBox(width: KSpacing.sm),
                        _ViewerCluster(room: room),
                      ],
                    ),
                    const SizedBox(height: KLivePreview.pillToChip),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _RankChip(rank: room.weeklyRank),
                    ),
                    const SizedBox(height: KSpacing.xs),
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _TestDataLabel(),
                    ),
                    const Spacer(),
                    _Chat(room: room),
                    const SizedBox(height: KLivePreview.chatToBar),
                    _BottomBar(room: room),
                    const SizedBox(height: KSpacing.xs),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Layout values measured on the owner's reference (923×2000 px at
/// 2.1465 px/lp → 430×932 lp) with measure.py and colour masks (M), or read
/// from zoomed crops (E).
abstract final class KLivePreview {
  static const double edge = 11; // M: 23–24 px side margins
  static const double hostPillHeight = 35; // M: 75 px
  static const double hostAvatar = 35; // M
  static const double followWidth = 74; // M: 159 px
  static const double followHeight = 27; // M: 58 px
  static const double pillToChip = 6.5; // M: 14 px
  static const double chipHeight = 24; // M: 51 px
  static const double viewerAvatar = 22; // E: ~48 px
  static const double viewerOverlap = 3; // E
  static const double collapseIcon = 20; // E: ~38 px circle
  static const double closeIcon = 18; // E
  static const double chatAvatar = 28; // M: 61 px
  static const double chatGap = 6.5; // M: 14 px avatar → text
  static const double chatRowGap = 14; // E
  static const double chatMaxWidthFraction = 0.66; // E
  static const double chatToBar = 20; // M: 42 px
  static const double barHeight = 36; // M: 77 px circles
  static const double barGap = 6.5; // M: 13–15 px
  static const double barIcon = 22; // E

  /// Translucent fill of the pill, chips and round buttons over video.
  static const Color glass = Color(0x47000000);
  static const Color inputGlass = Color(0x24FFFFFF);
  static const Color coin = Color(0xFFF5C518);

  static const List<Shadow> textShadow = [
    Shadow(color: Color(0x80000000), blurRadius: 3, offset: Offset(0, 1)),
  ];
}

class _HostPill extends StatelessWidget {
  const new({required this.room});

  final LivePreviewRoom room;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final white = KPalette.dark.textPrimary;
    return Container(
      key: LivePreviewScreen.hostPillKey,
      // The measured height; large text may grow it instead of clipping.
      constraints: const BoxConstraints(minHeight: KLivePreview.hostPillHeight),
      decoration: BoxDecoration(
        color: KLivePreview.glass,
        borderRadius: BorderRadius.circular(KLivePreview.hostPillHeight / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KAvatar(name: room.hostName, size: KLivePreview.hostAvatar),
          const SizedBox(width: KSpacing.xs),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 84),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.hostName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(
                      fontSize: 14,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: white,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          KFormat.compact(room.hostLikes, l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            fontSize: 12,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      const SizedBox(width: KSpacing.xxs),
                      FeedGlyphIcon(
                        FeedGlyph.heart,
                        size: 11,
                        color: white.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          Semantics(
            button: true,
            label: l10n.liveFollow,
            excludeSemantics: true,
            child: InkWell(
              key: LivePreviewScreen.followKey,
              onTap: () {},
              borderRadius: BorderRadius.circular(
                KLivePreview.followHeight / 2,
              ),
              child: Container(
                width: KLivePreview.followWidth,
                height: KLivePreview.followHeight,
                decoration: BoxDecoration(
                  color: p.primary,
                  borderRadius: BorderRadius.circular(
                    KLivePreview.followHeight / 2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(AppIcons.plus, size: 16, color: p.onPrimary),
                    Flexible(
                      child: Text(
                        l10n.liveFollow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyStrong.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: p.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: KSpacing.xxs),
        ],
      ),
    );
  }
}

class _ViewerCluster extends StatelessWidget {
  const new({required this.room});

  final LivePreviewRoom room;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = KPalette.dark.textPrimary;
    const avatar = KLivePreview.viewerAvatar;
    return Row(
      key: LivePreviewScreen.viewersKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: l10n.liveViewers(
            room.viewers,
            KFormat.compact(room.viewers, l10n),
          ),
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: avatar * 2 - KLivePreview.viewerOverlap,
                height: avatar,
                child: Stack(
                  children: [
                    for (var i = 0; i < room.topViewers.length; i++)
                      PositionedDirectional(
                        start: i * (avatar - KLivePreview.viewerOverlap),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: white.withValues(alpha: 0.7),
                              width: 1.2,
                            ),
                          ),
                          child: KAvatar(
                            name: room.topViewers[i],
                            size: avatar,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: KSpacing.xs),
              Text(
                KFormat.compact(room.viewers, l10n),
                style: context.textStyles.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: white,
                  shadows: KLivePreview.textShadow,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.livePreviewMinimize,
          onPressed: () {},
          visualDensity: VisualDensity.compact,
          icon: FeedGlyphIcon(
            FeedGlyph.collapse,
            size: KLivePreview.collapseIcon,
            color: white,
            shadow: true,
          ),
        ),
        IconButton(
          key: LivePreviewScreen.closeKey,
          tooltip: l10n.liveClose,
          onPressed: () => Navigator.maybePop(context),
          visualDensity: VisualDensity.compact,
          icon: FeedGlyphIcon(
            FeedGlyph.close,
            size: KLivePreview.closeIcon,
            color: white,
            shadow: true,
          ),
        ),
      ],
    );
  }
}

class _RankChip extends StatelessWidget {
  const new({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final white = KPalette.dark.textPrimary;
    return Container(
      key: LivePreviewScreen.rankKey,
      height: KLivePreview.chipHeight,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: KSpacing.sm),
      decoration: BoxDecoration(
        color: KLivePreview.glass,
        borderRadius: BorderRadius.circular(KLivePreview.chipHeight / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              context.l10n.livePreviewRank(rank),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: white,
              ),
            ),
          ),
          const SizedBox(width: KSpacing.xxs),
          const FeedGlyphIcon(
            FeedGlyph.rank,
            size: 14,
            color: KLivePreview.coin,
          ),
        ],
      ),
    );
  }
}

class _TestDataLabel extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: LivePreviewScreen.testDataKey,
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

class _Chat extends StatelessWidget {
  const new({required this.room});

  final LivePreviewRoom room;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final white = KPalette.dark.textPrimary;
    final maxWidth =
        MediaQuery.sizeOf(context).width * KLivePreview.chatMaxWidthFraction;

    Widget avatarFor(LivePreviewMessage m) => switch (m.joined) {
      true => Container(
        width: KLivePreview.chatAvatar,
        height: KLivePreview.chatAvatar,
        decoration: const BoxDecoration(
          color: KLivePreview.inputGlass,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: FeedGlyphIcon(FeedGlyph.wave, size: 16, color: white),
      ),
      false => KAvatar(name: m.name, size: KLivePreview.chatAvatar),
    };

    Widget row(LivePreviewMessage m) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        avatarFor(m),
        const SizedBox(width: KLivePreview.chatGap),
        Flexible(
          child: m.joined
              ? Padding(
                  padding: const EdgeInsetsDirectional.only(top: 4),
                  child: Text(
                    l10n.livePreviewJoined(m.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: white.withValues(alpha: 0.85),
                      shadows: KLivePreview.textShadow,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LevelBadge(level: m.level),
                        const SizedBox(width: KSpacing.xxs),
                        Flexible(
                          child: Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: white.withValues(alpha: 0.7),
                              shadows: KLivePreview.textShadow,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyStrong.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: white,
                        shadows: KLivePreview.textShadow,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          key: LivePreviewScreen.chatKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < room.chat.length; i++) ...[
              if (i > 0) const SizedBox(height: KLivePreview.chatRowGap),
              row(room.chat[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const new({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) => Container(
    height: 16,
    padding: const EdgeInsetsDirectional.symmetric(horizontal: 5),
    decoration: BoxDecoration(
      color: KBrandColors.red600.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(KRadius.xs),
    ),
    alignment: Alignment.center,
    child: Text(
      KFormat.grouped(level),
      textDirection: TextDirection.ltr,
      style: context.textStyles.caption.copyWith(
        fontSize: 11,
        height: 1,
        fontWeight: FontWeight.w700,
        color: KPalette.dark.textPrimary,
      ),
    ),
  );
}

class _BottomBar extends StatelessWidget {
  const new({required this.room});

  final LivePreviewRoom room;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final white = KPalette.dark.textPrimary;

    Widget round(
      String label,
      Widget glyph, {
      String? caption,
      VoidCallback? onTap,
    }) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap ?? () {},
        customBorder: const CircleBorder(),
        child: Container(
          width: KLivePreview.barHeight,
          height: KLivePreview.barHeight,
          decoration: const BoxDecoration(
            color: KLivePreview.glass,
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              glyph,
              if (caption != null)
                PositionedDirectional(
                  bottom: 1,
                  child: Text(
                    caption,
                    textDirection: TextDirection.ltr,
                    style: context.textStyles.caption.copyWith(
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: white,
                      shadows: KLivePreview.textShadow,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return SizedBox(
      key: LivePreviewScreen.bottomBarKey,
      height: KLivePreview.barHeight,
      child: Row(
        children: [
          round(
            l10n.liveShare,
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 6),
              child: FeedGlyphIcon(
                FeedGlyph.share,
                size: KLivePreview.barIcon,
                color: white.withValues(alpha: 0.9),
              ),
            ),
            caption: KFormat.compact(room.shares, l10n),
            onTap: () => FeedShareSheet.show(context),
          ),
          const SizedBox(width: KLivePreview.barGap),
          round(
            l10n.liveGifts,
            FeedGlyphIcon(
              FeedGlyph.gift,
              size: KLivePreview.barIcon,
              color: p.primary,
            ),
          ),
          const SizedBox(width: KLivePreview.barGap),
          round(
            l10n.livePreviewBalance,
            const FeedGlyphIcon(
              FeedGlyph.coin,
              size: KLivePreview.barIcon,
              color: KLivePreview.coin,
            ),
          ),
          const SizedBox(width: KLivePreview.barGap),
          Expanded(
            child: Container(
              key: LivePreviewScreen.inputKey,
              height: KLivePreview.barHeight,
              padding: const EdgeInsetsDirectional.only(
                start: KSpacing.md,
                end: KSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: KLivePreview.inputGlass,
                borderRadius: BorderRadius.circular(KLivePreview.barHeight / 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.liveCommentHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.body.copyWith(
                        fontSize: 15,
                        color: white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.livePreviewEmoji,
                    excludeSemantics: true,
                    child: FeedGlyphIcon(
                      FeedGlyph.smiley,
                      size: 24,
                      color: white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: KLivePreview.barGap),
          round(
            l10n.livePreviewMore,
            FeedGlyphIcon(
              FeedGlyph.more,
              size: KLivePreview.barIcon,
              color: white,
            ),
          ),
        ],
      ),
    );
  }
}

/// One labelled test chat line ([joined] marks a join notice).
@immutable
class LivePreviewMessage {
  const new({
    required this.name,
    this.text = '',
    this.level = 0,
    this.joined = false,
  });

  final String name;
  final String text;
  final int level;
  final bool joined;
}

/// A labelled test live room (never shown in production).
@immutable
class LivePreviewRoom {
  const new({
    required this.hostName,
    required this.hostLikes,
    required this.viewers,
    required this.topViewers,
    required this.weeklyRank,
    required this.shares,
    required this.chat,
  });

  final String hostName;
  final int hostLikes;
  final int viewers;
  final List<String> topViewers;
  final int weeklyRank;
  final int shares;
  final List<LivePreviewMessage> chat;
}

/// Labelled test room: names say they are test accounts (D35/D46).
LivePreviewRoom livePreviewFixture({required bool ar}) => LivePreviewRoom(
  hostName: ar ? 'سارة (تجربة)' : 'Sara (test)',
  hostLikes: 36500,
  viewers: 284,
  topViewers: ar ? const ['ع', 'م'] : const ['A', 'M'],
  weeklyRank: 7,
  shares: 426,
  chat: [
    LivePreviewMessage(
      name: ar ? 'عمر (تجربة)' : 'Omar (test)',
      text: ar ? 'رسالة اختبار للدردشة' : 'A test chat message',
      level: 19,
    ),
    LivePreviewMessage(
      name: ar ? 'هند (تجربة)' : 'Hind (test)',
      text: ar
          ? 'أهلًا بالجميع، هذه بيانات اختبار'
          : 'Hi all, this is test data',
      level: 3,
    ),
    LivePreviewMessage(
      name: ar ? 'خالد (تجربة)' : 'Khalid (test)',
      joined: true,
    ),
    LivePreviewMessage(name: ar ? 'نور (تجربة)' : 'Nour (test)', joined: true),
  ],
);
