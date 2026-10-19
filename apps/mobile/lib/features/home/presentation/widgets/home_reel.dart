import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Presentation-only input for one reel (a short vertical video). There is
/// no reels API yet (short video Phase 5), so nothing in production builds
/// these; tests and the debug previews supply fixtures.
///
/// Playback is not part of this slice: a reel shows its [cover] frame and
/// its text. There is no play control or progress until a player exists.
@immutable
class FeedReelData {
  const new({
    required this.authorName,
    required this.postedAt,
    this.authorAvatar,
    this.authorUsername,
    this.isFollowingAuthor,
    this.caption,
    this.cover,
    this.likes,
    this.comments,
    this.shares,
  });

  final String authorName;
  final ImageProvider? authorAvatar;

  /// The author's username, the key of the follow API
  /// (`PUT /users/{username}/follow`).
  final String? authorUsername;

  /// Whether the viewer follows the author; `null` when unknown (for
  /// yourself, or a source without it). Follow is offered only for `false`.
  final bool? isFollowingAuthor;

  final DateTime postedAt;
  final String? caption;

  /// The video's cover frame; `null` shows a dark surface.
  final ImageProvider? cover;

  /// Counts from the API, drawn on the rail when all three are known.
  /// Display-only until the like/comment/share APIs exist.
  final int? likes;
  final int? comments;
  final int? shares;
}

/// Reels geometry (D53, layout from the owner's reference): the author,
/// time and caption at the bottom start; the rail (author photo with the
/// follow badge, then the counts) at the bottom end.
abstract final class KHomeReels {
  static const double contentInset = 16;
  static const double contentBottom = 20;

  /// The rail's width; the caption stops [KSpacing.sm] before it.
  static const double railWidth = 56;
  static const double railAvatar = 48;
  static const double railGap = 20;
  static const double railIcon = 32;

  /// The red follow badge under the rail photo, centred in a 48 dp target.
  static const double followBadge = 20;
  static const double followIcon = 14;
}

/// Full-screen vertical pager of reels: swipe up for the next one. Its
/// page survives mode and feed switches (they are kept alive), and its
/// [PageStorageKey] (unique per feed) restores it if the subtree is
/// rebuilt.
class HomeReelsPager extends StatelessWidget {
  const new({required this.reels, required this.storageKey, super.key});

  final List<FeedReelData> reels;
  final String storageKey;

  @override
  Widget build(BuildContext context) => PageView.builder(
    key: PageStorageKey<String>(storageKey),
    scrollDirection: Axis.vertical,
    itemCount: reels.length,
    itemBuilder: (_, i) => HomeReelPage(reel: reels[i]),
  );
}

/// One reel, edge to edge: the cover frame under a bottom scrim, the
/// author, time and caption at the bottom start, and the rail at the bottom
/// end.
class HomeReelPage extends StatelessWidget {
  const new({required this.reel, super.key});

  final FeedReelData reel;

  static const railKey = Key('home.reel.rail');
  static const countsKey = Key('home.reel.counts');
  static const authorKey = Key('home.reel.author');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final white = KPalette.dark.textPrimary;
    final caption = reel.caption;
    return Semantics(
      container: true,
      label: l10n.homeReelBy(reel.authorName),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Cover(image: reel.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.25, 0.6, 1],
                colors: [
                  Color(0x66000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xA6000000),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            start: KHomeReels.contentInset,
            end: KHomeReels.contentInset + KHomeReels.railWidth + KSpacing.sm,
            bottom: KHomeReels.contentBottom,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reel.authorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.title.copyWith(color: white, shadows: _shadows),
                ),
                Text(
                  _when(context, reel.postedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: white, shadows: _shadows),
                ),
                if (caption != null && caption.isNotEmpty) ...[
                  const SizedBox(height: KSpacing.sm),
                  Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(color: white, shadows: _shadows),
                  ),
                ],
              ],
            ),
          ),
          PositionedDirectional(
            end: KHomeReels.contentInset - (KHomeReels.railWidth - 48) / 2,
            bottom: KHomeReels.contentBottom,
            width: KHomeReels.railWidth,
            child: _Rail(key: railKey, reel: reel),
          ),
        ],
      ),
    );
  }
}

const _shadows = [
  Shadow(color: Color(0x99000000), blurRadius: 8, offset: Offset(0, 2)),
];

/// The rail: the author photo (with the follow badge when the viewer does
/// not follow them yet), then like, comment and share with their counts.
/// The counts are display-only: they are not buttons until those APIs
/// exist, and they are drawn only when the source supplies them.
class _Rail extends StatelessWidget {
  const new({required this.reel, super.key});

  final FeedReelData reel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = KPalette.dark.textPrimary;
    final username = reel.authorUsername;
    final (likes, comments, shares) = (reel.likes, reel.comments, reel.shares);
    Widget count(String icon, int value) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(icon, size: KHomeReels.railIcon, color: white),
        const SizedBox(height: KSpacing.xxs),
        Text(
          KFormat.compact(value, l10n),
          maxLines: 1,
          style: context.textStyles.caption.copyWith(
            color: white,
            fontWeight: FontWeight.w600,
            shadows: _shadows,
          ),
        ),
      ],
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: KMetrics.overlayMaxTextScale,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: KHomeReels.railWidth,
            height: KHomeReels.railAvatar + KSizes.minTouchTarget / 2,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // D60: the photo opens the author's profile.
                GestureDetector(
                  key: HomeReelPage.authorKey,
                  onTap: username == null
                      ? null
                      : () => context.push(AppRoutes.userProfile(username)),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: white, width: KMetrics.stroke),
                    ),
                    child: ExcludeSemantics(
                      child: KAvatar(
                        name: reel.authorName,
                        image: reel.authorAvatar,
                        size: KHomeReels.railAvatar - 2 * KMetrics.stroke,
                      ),
                    ),
                  ),
                ),
                if (username != null && reel.isFollowingAuthor == false)
                  Positioned(
                    bottom: 0,
                    child: ReelFollowBadge(
                      username: username,
                      authorName: reel.authorName,
                    ),
                  ),
              ],
            ),
          ),
          if (likes != null && comments != null && shares != null)
            Semantics(
              key: HomeReelPage.countsKey,
              container: true,
              label: l10n.feedPostCounts(
                KFormat.compact(likes, l10n),
                KFormat.compact(comments, l10n),
                KFormat.compact(shares, l10n),
              ),
              excludeSemantics: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: KHomeReels.railGap / 2),
                  count(AppIcons.heartFilled, likes),
                  const SizedBox(height: KHomeReels.railGap),
                  count(AppIcons.commentFilled, comments),
                  const SizedBox(height: KHomeReels.railGap),
                  count(AppIcons.shareFilled, shares),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Follow on the rail photo: a red "+" badge (48 dp target) that follows
/// the author through the follow API (`PUT /users/{username}/follow`,
/// CONVENTIONS §10.6). It turns into a check at once and stays so on
/// success; on failure it comes back and a snack bar says why.
class ReelFollowBadge extends ConsumerStatefulWidget {
  const new({required this.username, required this.authorName, super.key});

  final String username;
  final String authorName;

  static const badgeKey = Key('home.reel.follow');

  @override
  ConsumerState<ReelFollowBadge> createState() => _ReelFollowBadgeState();
}

class _ReelFollowBadgeState extends ConsumerState<ReelFollowBadge> {
  bool _followed = false;

  Future<void> _follow() async {
    if (_followed) return;
    setState(() => _followed = true);
    try {
      await ref.read(profileRepositoryProvider).follow(widget.username);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _followed = false);
      KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const p = KPalette.dark;
    return Semantics(
      container: true,
      button: !_followed,
      label: _followed
          ? l10n.homeFollowingAuthor(widget.authorName)
          : l10n.homeFollowAuthor(widget.authorName),
      excludeSemantics: true,
      child: GestureDetector(
        key: ReelFollowBadge.badgeKey,
        behavior: HitTestBehavior.opaque,
        onTap: _followed ? null : _follow,
        child: SizedBox.square(
          dimension: KSizes.minTouchTarget,
          child: Center(
            child: AnimatedContainer(
              duration: KMotion.of(context, KMotion.fast),
              width: KHomeReels.followBadge,
              height: KHomeReels.followBadge,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _followed ? p.textPrimary : p.primary,
              ),
              child: Icon(
                _followed ? Icons.check_rounded : Icons.add_rounded,
                size: KHomeReels.followIcon,
                color: _followed ? p.primary : p.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const new({required this.image});

  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final cover = image;
    return ColoredBox(
      color: KPalette.dark.surfaceRaised,
      child: cover == null
          ? null
          : Image(
              image: cover,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
    );
  }
}

String _when(BuildContext context, DateTime at) {
  final l10n = context.l10n;
  return KFormat.relative(
        at,
        clock.now(),
        l10n,
        Localizations.localeOf(context).toLanguageTag(),
      ) ??
      l10n.feedPostJustNow;
}
