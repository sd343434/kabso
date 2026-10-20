import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Input for one Home feed item. Production builds it from the posts API
/// (`feedPostOf`, v1.5-social) with a [postId], which turns the action row
/// into real buttons; tests use `test/fixtures/` and debug builds the
/// previews (no [postId]: display only).
@immutable
class FeedPostData {
  const new({
    required this.authorName,
    required this.postedAt,
    this.authorAvatar,
    this.authorUsername,
    this.isFollowingAuthor,
    this.location,
    this.text,
    this.media,
    this.mediaAspect,
    this.isVideo = false,
    this.likes,
    this.comments,
    this.shares,
    this.postId,
    this.liked = false,
    this.saved = false,
    this.isSelf = false,
    this.pendingModeration = false,
    this.repostedBy,
  });

  final String authorName;
  final ImageProvider? authorAvatar;

  /// The author's username, the key of the follow API.
  final String? authorUsername;

  /// Whether the viewer follows the author; `null` when unknown or for
  /// your own post. The "more" menu offers Follow/Unfollow only when known.
  final bool? isFollowingAuthor;

  final DateTime postedAt;

  /// Where the post was made, shown under the author's name.
  final String? location;
  final String? text;

  /// Photo or video cover; `null` for a text-only post.
  final ImageProvider? media;

  /// Width / height of [media]; `KMetrics.feedMediaAspect` when unknown.
  final double? mediaAspect;

  /// [media] is a video cover: it carries the video mark.
  final bool isVideo;

  /// Counts from the API. The counter row is drawn only when all three are
  /// known; it is display-only until the like/comment/share APIs exist.
  final int? likes;
  final int? comments;
  final int? shares;

  /// The API id: set for real posts only. With it, like and save are
  /// buttons and the "more" sheet offers hide, report or delete.
  final String? postId;
  final bool liked;
  final bool saved;

  /// The viewer wrote it (delete instead of hide/report).
  final bool isSelf;

  /// Waiting for moderation: visible to its author only (CP-006 Q2).
  final bool pendingModeration;

  /// The display name of who reposted it into the Following feed.
  final String? repostedBy;
}

/// Geometry of a post (D54, layout from the owner's reference; sizes on
/// the Kabso scale): flat and full width, no card.
abstract final class KPostCard {
  /// Side padding of the author row, actions, caption and time.
  static const double inset = KSpacing.md;

  /// Gap between two posts.
  static const double gap = KSpacing.lg;
  static const double avatar = 32;

  /// Collapsed caption before "see more".
  static const int collapsedLines = 2;

  /// The white disc of the video mark and its play glyph.
  static const double videoMark = 44;
  static const double videoGlyph = 28;

  /// The filled "Follow" box in the author row.
  static const double followHeight = KSpacing.xxl;

  /// The action icons and the gap after each count.
  static const double actionIcon = 26;
  static const double actionGap = KSpacing.lg;
}

/// One post, flat and full width (D54): the author row (avatar, name and,
/// when known, the location under it), the media edge to edge at its own
/// aspect ratio (a video cover carries a play mark), the like, comment and
/// share icons with their counts and the save icon at the end, the caption
/// led by the author's name, collapsed to two lines with an inline "see
/// more" that expands it in place, then the relative time.
///
/// When the source gives the follow state, a filled "Follow" box sits at
/// the end of the author row for authors the viewer does not follow
/// (typical on Trending), before the three dots, which open a sheet with
/// Follow or Unfollow, both through the existing follow API. Report and
/// hide join the sheet when their APIs exist.
///
/// The action row is display-only and drawn only when the API supplies the
/// counts: nothing in it is a button until the like/comment/share/save APIs
/// exist, and there is no comment field or "View all comments" link yet (no
/// inert controls).
class FeedPostTile extends StatelessWidget {
  const new({required this.post, super.key});

  final FeedPostData post;

  static const seeMoreKey = Key('feed.post.seeMore');
  static const videoMarkKey = Key('feed.post.video');
  static const countsKey = Key('feed.post.counts');
  static const moreKey = Key('feed.post.more');
  static const followKey = Key('feed.post.follow');
  static const authorKey = Key('feed.post.author');
  static const followActionKey = Key('feed.post.more.follow');
  static const likeKey = Key('feed.post.like');
  static const saveKey = Key('feed.post.save');
  static const hideActionKey = Key('feed.post.more.hide');
  static const reportActionKey = Key('feed.post.more.report');
  static const deleteActionKey = Key('feed.post.more.delete');
  static const pendingKey = Key('feed.post.pending');
  static const deleteConfirmKey = Key('feed.post.delete.confirm');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final when =
        KFormat.relative(
          post.postedAt,
          clock.now(),
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
        ) ??
        l10n.feedPostJustNow;
    final text = post.text;
    final media = post.media;
    final (likes, comments, shares) = (post.likes, post.comments, post.shares);
    const inset = EdgeInsetsDirectional.symmetric(horizontal: KPostCard.inset);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (post.repostedBy case final by?)
          Padding(
            padding: inset.add(const EdgeInsets.only(top: KSpacing.xs)),
            child: Text(
              l10n.feedPostRepostedBy(by),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ),
        _AuthorRow(post: post),
        if (post.pendingModeration)
          Padding(
            key: FeedPostTile.pendingKey,
            padding: inset.add(const EdgeInsets.only(bottom: KSpacing.xs)),
            child: Text(
              l10n.feedPostPending,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ),
        if (media != null)
          AspectRatio(
            aspectRatio: post.mediaAspect ?? KMetrics.feedMediaAspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: p.surfaceRaised,
                  child: Image(
                    image: media,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
                    errorBuilder: (_, _, _) => const SizedBox.expand(),
                  ),
                ),
                if (post.isVideo)
                  const Center(
                    child: _VideoMark(key: FeedPostTile.videoMarkKey),
                  ),
              ],
            ),
          ),
        if (post.postId case final id?)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KPostCard.inset,
              KSpacing.xs,
              KSpacing.xs,
              0,
            ),
            child: _Actions(postId: id, post: post),
          )
        else if (likes != null && comments != null && shares != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KPostCard.inset,
              KSpacing.sm,
              KPostCard.inset,
              0,
            ),
            child: _Counts(likes: likes, comments: comments, shares: shares),
          ),
        if (text != null && text.isNotEmpty)
          Padding(
            padding: inset.add(const EdgeInsets.only(top: KSpacing.sm)),
            child: _ExpandableText(text, lead: post.authorName, style: t.body),
          ),
        Padding(
          padding: inset.add(const EdgeInsets.only(top: KSpacing.xs)),
          child: Text(
            when,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.caption.copyWith(color: p.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// The author row: avatar, name and, when known, the location under it.
/// When the source says the viewer does not follow the author (typical on
/// Trending), a filled "Follow" box sits before the three dots at the end; the
/// dots (48 dp) open a sheet with Follow or Unfollow. Both use the follow
/// API (`PUT`/`DELETE /users/{username}/follow`): the choice applies at
/// once and comes back with a message on failure. Without a follow state
/// (your own post, or a source without it) neither is shown.
enum _MoreAction { follow, hide, report, delete }

/// The label of a report reason.
String reportReasonLabel(AppLocalizations l10n, ReportReason reason) =>
    switch (reason) {
      ReportReason.spam => l10n.reportReasonSpam,
      ReportReason.nudity => l10n.reportReasonNudity,
      ReportReason.violence => l10n.reportReasonViolence,
      ReportReason.hate => l10n.reportReasonHate,
      ReportReason.harassment => l10n.reportReasonHarassment,
      ReportReason.illegal => l10n.reportReasonIllegal,
      ReportReason.other => l10n.reportReasonOther,
    };

class _AuthorRow extends ConsumerStatefulWidget {
  const new({required this.post});

  final FeedPostData post;

  @override
  ConsumerState<_AuthorRow> createState() => _AuthorRowState();
}

class _AuthorRowState extends ConsumerState<_AuthorRow> {
  late bool? _following = widget.post.isFollowingAuthor;
  bool _busy = false;

  Future<void> _set({required bool follow}) async {
    final username = widget.post.authorUsername;
    if (_busy || username == null || _following == follow) return;
    final before = _following;
    setState(() {
      _following = follow;
      _busy = true;
    });
    try {
      final repo = ref.read(profileRepositoryProvider);
      await (follow ? repo.follow(username) : repo.unfollow(username));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _following = before);
      KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openMore() async {
    final l10n = context.l10n;
    final post = widget.post;
    final following = _following;
    final id = post.postId;
    final name = post.authorName;
    final choice = await showModalBottomSheet<_MoreAction>(
      context: context,
      builder: (sheet) {
        Widget item(Key key, String icon, String label, _MoreAction action) =>
            ListTile(
              key: key,
              leading: AppIcon(icon, color: sheet.palette.textPrimary),
              title: Text(label),
              onTap: () => Navigator.of(sheet).pop(action),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (post.authorUsername != null && following != null)
                item(
                  FeedPostTile.followActionKey,
                  following ? AppIcons.followFilled : AppIcons.follow,
                  following
                      ? l10n.homeUnfollowAuthor(name)
                      : l10n.homeFollowAuthor(name),
                  _MoreAction.follow,
                ),
              if (id != null && !post.isSelf) ...[
                item(
                  FeedPostTile.hideActionKey,
                  AppIcons.moreHoriz,
                  l10n.feedPostHide,
                  _MoreAction.hide,
                ),
                item(
                  FeedPostTile.reportActionKey,
                  AppIcons.moreHoriz,
                  l10n.feedPostReport,
                  _MoreAction.report,
                ),
              ],
              if (id != null && post.isSelf)
                item(
                  FeedPostTile.deleteActionKey,
                  AppIcons.moreHoriz,
                  l10n.feedPostDelete,
                  _MoreAction.delete,
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case _MoreAction.follow:
        await _set(follow: !(following ?? false));
      case _MoreAction.hide:
        await _run(
          (repo, id) => repo.setHidden(id, hidden: true),
          l10n.feedPostHidden,
        );
      case _MoreAction.report:
        final reason = await _pickReason();
        if (reason == null) return;
        await _run(
          (repo, id) => repo.reportPost(id, reason),
          l10n.feedPostReported,
        );
      case _MoreAction.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(l10n.feedPostDeleteConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: Text(l10n.actionCancel),
              ),
              TextButton(
                key: FeedPostTile.deleteConfirmKey,
                onPressed: () => Navigator.of(dialog).pop(true),
                child: Text(l10n.feedPostDelete),
              ),
            ],
          ),
        );
        if (ok ?? false) {
          await _run((repo, id) => repo.deletePost(id), l10n.feedPostDeleted);
        }
    }
  }

  /// Hide, report or delete: on success the post leaves the feeds.
  Future<void> _run(
    Future<void> Function(PostsRepository repo, String id) action,
    String done,
  ) async {
    final id = widget.post.postId;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      await action(ref.read(postsRepositoryProvider), id);
      if (!mounted) return;
      removePostFromFeeds(ref, id);
      KSnack.success(context, done);
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<ReportReason?> _pickReason() {
    final l10n = context.l10n;
    return showModalBottomSheet<ReportReason>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(l10n.feedPostReportTitle)),
            for (final reason in ReportReason.values)
              ListTile(
                key: ValueKey('feed.post.report.${reason.name}'),
                title: Text(reportReasonLabel(l10n, reason)),
                onTap: () => Navigator.of(sheet).pop(reason),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    final post = widget.post;
    final location = post.location;
    final username = post.authorUsername;
    final known = username != null && _following != null;
    return Padding(
      // The end inset is smaller: the dots' 48 dp target is mostly air.
      padding: const EdgeInsetsDirectional.fromSTEB(
        KPostCard.inset,
        KSpacing.xs,
        KSpacing.xs,
        KSpacing.xs,
      ),
      child: Row(
        children: [
          // D60: the photo and name open the author's profile.
          Expanded(
            child: Semantics(
              button: username != null,
              child: InkWell(
                key: FeedPostTile.authorKey,
                borderRadius: BorderRadius.circular(KRadius.sm),
                onTap: username == null
                    ? null
                    : () => context.push(AppRoutes.userProfile(username)),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: KAvatar(
                        name: post.authorName,
                        image: post.authorAvatar,
                        size: KPostCard.avatar,
                      ),
                    ),
                    const SizedBox(width: KSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyStrong.copyWith(color: p.textPrimary),
                          ),
                          if (location != null && location.isNotEmpty)
                            Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.caption.copyWith(color: p.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (known && _following == false)
            Semantics(
              container: true,
              button: true,
              label: l10n.homeFollowAuthor(post.authorName),
              excludeSemantics: true,
              child: InkWell(
                key: FeedPostTile.followKey,
                onTap: _busy ? null : () => _set(follow: true),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: KSizes.minTouchTarget,
                    minHeight: KSizes.minTouchTarget,
                  ),
                  // A filled box inside the 48 dp target.
                  child: Center(
                    widthFactor: 1,
                    child: Container(
                      height: KPostCard.followHeight,
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: KSpacing.md,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.primary,
                        borderRadius: BorderRadius.circular(KRadius.sm),
                      ),
                      child: Text(
                        l10n.liveFollow,
                        maxLines: 1,
                        textScaler: MediaQuery.textScalerOf(context)
                            .clamp(maxScaleFactor: KMetrics.topBarMaxTextScale),
                        style: t.label.copyWith(color: p.onPrimary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (known || post.postId != null)
            IconButton(
              key: FeedPostTile.moreKey,
              tooltip: l10n.feedPostMore,
              constraints: const BoxConstraints.tightFor(
                width: KSizes.minTouchTarget,
                height: KSizes.minTouchTarget,
              ),
              onPressed: _busy ? null : _openMore,
              icon: AppIcon(
                AppIcons.moreHoriz,
                size: KMetrics.iconMd,
                color: p.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}

/// A post's caption: the author's name in bold, then the text, collapsed
/// to [KPostCard.collapsedLines] lines. When it does not fit, the last line
/// ends in "… see more" (tertiary colour); tapping it expands the caption
/// in place. A short caption is shown as is.
class _ExpandableText extends StatefulWidget {
  const new(this.text, {required this.lead, required this.style});

  final String text;
  final String lead;
  final TextStyle style;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  static const _ellipsis = '… ';

  @override
  Widget build(BuildContext context) {
    // Measure with exactly what [Text] will render: the ambient style merged
    // with ours, the locale's font fallback and the text scale.
    final style = DefaultTextStyle.of(context).style
        .merge(widget.style.copyWith(color: context.palette.textPrimary));
    final lead = TextSpan(
      text: '${widget.lead} ',
      style: style.copyWith(fontWeight: FontWeight.w600),
    );
    InlineSpan caption(String s, {InlineSpan? tail}) => TextSpan(
      style: style,
      children: [
        lead,
        TextSpan(text: s),
        ?tail,
      ],
    );
    if (_expanded) return Text.rich(caption(widget.text));
    final seeMore = context.l10n.feedSeeMore;
    final tail = TextSpan(
      text: _ellipsis,
      children: [
        TextSpan(
          text: seeMore,
          style: style.copyWith(color: context.palette.textTertiary),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final direction = Directionality.of(context);
        final scaler = MediaQuery.textScalerOf(context);
        final locale = Localizations.maybeLocaleOf(context);
        bool fits(String s, {InlineSpan? tail}) {
          final painter = TextPainter(
            text: caption(s, tail: tail),
            textDirection: direction,
            textScaler: scaler,
            locale: locale,
            maxLines: KPostCard.collapsedLines,
          )..layout(maxWidth: constraints.maxWidth);
          final ok = !painter.didExceedMaxLines;
          painter.dispose();
          return ok;
        }

        if (fits(widget.text)) return Text.rich(caption(widget.text));
        // The longest prefix that still fits with "… see more" after it.
        var lo = 0;
        var hi = widget.text.length;
        while (lo < hi) {
          final mid = (lo + hi + 1) ~/ 2;
          if (fits(widget.text.substring(0, mid).trimRight(), tail: tail)) {
            lo = mid;
          } else {
            hi = mid - 1;
          }
        }
        // Cut at the last word boundary when there is one.
        var shown = widget.text.substring(0, lo);
        final space = shown.lastIndexOf(RegExp(r'\s'));
        if (space > 0 && lo < widget.text.length) {
          shown = shown.substring(0, space);
        }
        shown = shown.trimRight();
        return Semantics(
          container: true,
          button: true,
          label: '${widget.lead} ${widget.text}. $seeMore',
          excludeSemantics: true,
          child: GestureDetector(
            key: FeedPostTile.seeMoreKey,
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = true),
            child: Text.rich(
              caption(shown, tail: tail),
              maxLines: KPostCard.collapsedLines,
              overflow: TextOverflow.clip,
            ),
          ),
        );
      },
    );
  }
}

/// Marks a video cover: a white disc with a play glyph. Playback arrives
/// with the player, so this is a mark, not a button.
class _VideoMark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: context.l10n.feedPostVideo,
    child: Container(
      width: KPostCard.videoMark,
      height: KPostCard.videoMark,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: KPalette.light.surfaceRaised,
        shape: BoxShape.circle,
      ),
      child: const Padding(
        // The triangle always points right; its optical centre sits left
        // of its box.
        padding: EdgeInsets.only(left: KSpacing.xxs),
        child: AppIcon(
          AppIcons.play,
          size: KPostCard.videoGlyph * 0.75,
          color: KStatusColors.onStatus,
        ),
      ),
    ),
  );
}

/// The action row: like, comment and share icons with their compact
/// counts, and save at the end. Display-only (one semantics label).
class _Counts extends StatelessWidget {
  const new({
    required this.likes,
    required this.comments,
    required this.shares,
  });

  final int likes;
  final int comments;
  final int shares;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final style = context.textStyles.bodyStrong.copyWith(color: p.textPrimary);
    Widget icon(String asset) =>
        AppIcon(asset, size: KPostCard.actionIcon, color: p.textPrimary);
    Widget counter(String asset, int value) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon(asset),
        const SizedBox(width: KSpacing.xs),
        Text(KFormat.compact(value, l10n), style: style),
        const SizedBox(width: KPostCard.actionGap),
      ],
    );
    return Semantics(
      key: FeedPostTile.countsKey,
      container: true,
      label: l10n.feedPostCounts(
        KFormat.compact(likes, l10n),
        KFormat.compact(comments, l10n),
        KFormat.compact(shares, l10n),
      ),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wraps instead of clipping when large text no longer fits.
          Expanded(
            child: Wrap(
              runSpacing: KSpacing.xs,
              children: [
                counter(AppIcons.heart, likes),
                counter(AppIcons.comment, comments),
                counter(AppIcons.send, shares),
              ],
            ),
          ),
          icon(AppIcons.bookmark),
        ],
      ),
    );
  }
}

/// The action row of a real post: like (a button with its count; no count
/// when the author hides it), the comment and share counts (shown, not yet
/// buttons: comments and outside sharing arrive next), and save at the end.
/// Like and save apply at once and are undone with a message when the API
/// refuses; the counts then come from the server's answer.
class _Actions extends ConsumerStatefulWidget {
  const new({required this.postId, required this.post});

  final String postId;
  final FeedPostData post;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  late bool _liked = widget.post.liked;
  late int? _likes = widget.post.likes;
  late bool _saved = widget.post.saved;
  bool _liking = false;
  bool _saving = false;

  Future<void> _toggleLike() async {
    if (_liking) return;
    final (before, beforeCount) = (_liked, _likes);
    final next = !_liked;
    setState(() {
      _liking = true;
      _liked = next;
      if (_likes case final n?) {
        _likes = (n + (next ? 1 : -1)).clamp(0, 1 << 31);
      }
    });
    try {
      final state = await ref
          .read(postsRepositoryProvider)
          .setLiked(widget.postId, liked: next);
      if (mounted) {
        setState(() {
          _liked = state.liked;
          _likes = state.likeCount;
        });
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = before;
        _likes = beforeCount;
      });
      KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _toggleSave() async {
    if (_saving) return;
    final next = !_saved;
    setState(() {
      _saving = true;
      _saved = next;
    });
    try {
      final saved = await ref
          .read(postsRepositoryProvider)
          .setSaved(widget.postId, saved: next);
      if (mounted) setState(() => _saved = saved);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saved = !next);
      KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final style = context.textStyles.bodyStrong.copyWith(color: p.textPrimary);
    final likes = _likes;
    Widget count(int value) => Text(KFormat.compact(value, l10n), style: style);
    Widget shown(String asset, int value, String label) => Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KSizes.minTouchTarget),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(asset, size: KPostCard.actionIcon, color: p.textPrimary),
            const SizedBox(width: KSpacing.xs),
            count(value),
            const SizedBox(width: KPostCard.actionGap),
          ],
        ),
      ),
    );
    return Row(
      children: [
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                button: true,
                toggled: _liked,
                label: _liked ? l10n.feedPostUnlike : l10n.feedPostLike,
                value: likes == null ? null : KFormat.compact(likes, l10n),
                excludeSemantics: true,
                child: InkWell(
                  key: FeedPostTile.likeKey,
                  borderRadius: BorderRadius.circular(KRadius.sm),
                  onTap: _toggleLike,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: KSizes.minTouchTarget,
                      minWidth: KSizes.minTouchTarget,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          _liked ? AppIcons.heartFilled : AppIcons.heart,
                          size: KPostCard.actionIcon,
                          color: _liked ? p.primary : p.textPrimary,
                        ),
                        if (likes != null) ...[
                          const SizedBox(width: KSpacing.xs),
                          count(likes),
                        ],
                        const SizedBox(width: KPostCard.actionGap),
                      ],
                    ),
                  ),
                ),
              ),
              shown(
                AppIcons.comment,
                widget.post.comments ?? 0,
                l10n.feedPostCommentCount(
                  KFormat.compact(widget.post.comments ?? 0, l10n),
                ),
              ),
              shown(
                AppIcons.send,
                widget.post.shares ?? 0,
                l10n.feedPostShareCount(
                  KFormat.compact(widget.post.shares ?? 0, l10n),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: FeedPostTile.saveKey,
          tooltip: _saved ? l10n.feedPostUnsave : l10n.feedPostSave,
          isSelected: _saved,
          onPressed: _toggleSave,
          icon: AppIcon(
            _saved ? AppIcons.bookmarkFilled : AppIcons.bookmark,
            size: KPostCard.actionIcon,
            color: p.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Loading placeholder with the post's anatomy.
class FeedPostSkeleton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.all(KPostCard.inset),
        child: Row(
          children: [
            KSkeleton(height: KPostCard.avatar, circle: true),
            SizedBox(width: KSpacing.sm),
            KSkeleton(width: KSizes.avatarLg, height: KSpacing.md),
          ],
        ),
      ),
      AspectRatio(
        aspectRatio: 1,
        child: KSkeleton(width: double.infinity, height: double.infinity),
      ),
      Padding(
        padding: EdgeInsets.all(KPostCard.inset),
        child: KSkeleton(width: double.infinity, height: KSpacing.md),
      ),
    ],
  );
}
