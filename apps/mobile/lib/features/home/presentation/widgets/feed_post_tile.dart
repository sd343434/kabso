import 'package:clock/clock.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/safety/safety_actions.dart';
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
    this.authorId,
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
    this.reposted = false,
    this.reposts = 0,
    this.pinned = false,
    this.edited = false,
    this.isSelf = false,
    this.pendingModeration = false,
    this.repostedBy,
    this.commentsOpen = true,
    this.hashtags = const {},
    this.mentions = const {},
  });

  final String authorName;
  final ImageProvider? authorAvatar;

  /// The author's username, the key of the follow API.
  final String? authorUsername;

  /// The author's id: their comments carry the "creator" label.
  final String? authorId;

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

  /// The viewer reposted it, and how many did (`repostCount`).
  final bool reposted;
  final int reposts;

  /// Pinned on the author's profile.
  final bool pinned;

  /// The caption was edited after publishing (`editedAt`).
  final bool edited;

  /// The viewer wrote it: pin, edit and delete instead of hide/report.
  final bool isSelf;

  /// Waiting for moderation: visible to its author only (CP-006 Q2).
  final bool pendingModeration;

  /// The display name of who reposted it into the Following feed.
  final String? repostedBy;

  /// The viewer may try to comment: comments are on and not "nobody" (the
  /// author always may; "followers only" is decided by the server).
  final bool commentsOpen;

  /// The caption's linked hashtags (lower case, no `#`) and mentions
  /// (usernames): only these are links (§11.6).
  final Set<String> hashtags;
  final Set<String> mentions;
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
/// For a real post (with a [FeedPostData.postId]) like, comment (the
/// comments sheet), repost (others' posts) and save are buttons, and the
/// like count opens who liked it; share stays a count (outside sharing
/// needs post links, CP-006 Q7). Previews without a post id are display
/// only.
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
  static const commentKey = Key('feed.post.comment');
  static const saveKey = Key('feed.post.save');
  static const repostKey = Key('feed.post.repost');
  static const likersKey = Key('feed.post.likers');
  static const hideActionKey = Key('feed.post.more.hide');
  static const reportActionKey = Key('feed.post.more.report');
  static const deleteActionKey = Key('feed.post.more.delete');
  static const pinActionKey = Key('feed.post.more.pin');
  static const editActionKey = Key('feed.post.more.edit');
  static const editedKey = Key('feed.post.edited');
  static const muteActionKey = Key('feed.post.more.mute');
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
            child: _ExpandableText(
              text,
              lead: post.authorName,
              style: t.body,
              hashtags: post.hashtags,
              mentions: post.mentions,
            ),
          ),
        Padding(
          padding: inset.add(const EdgeInsets.only(top: KSpacing.xs)),
          child: Text(
            post.edited ? l10n.feedPostTimeEdited(when) : when,
            key: post.edited ? FeedPostTile.editedKey : null,
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
enum _MoreAction { follow, hide, mute, report, pin, edit, delete }

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
        final color = sheet.palette.textPrimary;
        Widget item(
          Key key,
          Widget leading,
          String label,
          _MoreAction action,
        ) => ListTile(
          key: key,
          leading: leading,
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
                  AppIcon(
                    following ? AppIcons.followFilled : AppIcons.follow,
                    color: color,
                  ),
                  following
                      ? l10n.homeUnfollowAuthor(name)
                      : l10n.homeFollowAuthor(name),
                  _MoreAction.follow,
                ),
              if (id != null && !post.isSelf) ...[
                item(
                  FeedPostTile.hideActionKey,
                  AppIcon(AppIcons.eyeOff, color: color),
                  l10n.feedPostHide,
                  _MoreAction.hide,
                ),
                if (post.authorUsername != null)
                  item(
                    FeedPostTile.muteActionKey,
                    Icon(Icons.volume_off_outlined, color: color),
                    l10n.safetyMuteUser(name),
                    _MoreAction.mute,
                  ),
                item(
                  FeedPostTile.reportActionKey,
                  AppIcon(AppIcons.flag, color: color),
                  l10n.feedPostReport,
                  _MoreAction.report,
                ),
              ],
              if (id != null && post.isSelf) ...[
                item(
                  FeedPostTile.pinActionKey,
                  Icon(
                    post.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: color,
                  ),
                  post.pinned ? l10n.feedPostUnpin : l10n.feedPostPin,
                  _MoreAction.pin,
                ),
                item(
                  FeedPostTile.editActionKey,
                  Icon(Icons.edit_outlined, color: color),
                  l10n.feedPostEdit,
                  _MoreAction.edit,
                ),
              ],
              if (id != null && post.isSelf)
                item(
                  FeedPostTile.deleteActionKey,
                  Icon(Icons.delete_outline, color: sheet.palette.error),
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
      case _MoreAction.mute:
        // Their posts leave the feeds as they reload; Undo is on the message.
        await muteUser(
          context,
          ref,
          username: post.authorUsername!,
          name: name,
        );
      case _MoreAction.report:
        final reason = await pickReportReason(
          context,
          l10n.feedPostReportTitle,
        );
        if (reason == null) return;
        await _run(
          (repo, id) => repo.reportPost(id, reason),
          l10n.feedPostReported,
        );
      case _MoreAction.pin:
        await _pin(pinned: !post.pinned);
      case _MoreAction.edit:
        if (id != null) await context.push(AppRoutes.editPost(id));
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

  /// Pins or unpins your post on your profile (at most 3: 409 says so);
  /// feeds, the post screen and the grids take the server's answer.
  Future<void> _pin({required bool pinned}) async {
    final id = widget.post.postId;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      final post = await ref
          .read(postsRepositoryProvider)
          .setPinned(id, pinned: pinned);
      if (!mounted) return;
      ref.read(postEditsProvider.notifier).put(post);
      KSnack.success(
        context,
        post.pinned
            ? context.l10n.feedPostPinned
            : context.l10n.feedPostUnpinned,
      );
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
/// in place. A short caption is shown as is. Linked `#tags` and
/// `@mentions` are in the brand colour; once the whole caption shows, a
/// tap opens the hashtag page or the profile.
class _ExpandableText extends StatefulWidget {
  const new(
    this.text, {
    required this.lead,
    required this.style,
    this.hashtags = const {},
    this.mentions = const {},
  });

  final String text;
  final String lead;
  final TextStyle style;
  final Set<String> hashtags;
  final Set<String> mentions;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;
  final List<TapGestureRecognizer> _taps = [];

  static const _ellipsis = '… ';

  static final RegExp _entity = RegExp(
    r'(?<![\p{L}\p{N}_])([#@])([\p{L}\p{M}\p{N}_.]+)',
    unicode: true,
  );

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  /// [s] with linked entities coloured and, when [links], tappable.
  List<InlineSpan> _entities(String s, TextStyle style, {required bool links}) {
    final out = <InlineSpan>[];
    var last = 0;
    final accent = style.copyWith(
      color: context.palette.primaryText,
      fontWeight: FontWeight.w600,
    );
    for (final m in _entity.allMatches(s)) {
      final hash = m.group(1) == '#';
      // A username ends before a trailing dot (end of a sentence).
      final name = hash
          ? m.group(2)!
          : m.group(2)!.replaceFirst(RegExp(r'\.+$'), '');
      final linked = hash
          ? widget.hashtags.contains(name.toLowerCase())
          : widget.mentions.contains(name.toLowerCase());
      if (!linked) continue;
      if (m.start > last) out.add(TextSpan(text: s.substring(last, m.start)));
      TapGestureRecognizer? tap;
      if (links) {
        tap = TapGestureRecognizer()
          ..onTap = () => context.push(
            hash ? AppRoutes.hashtag(name) : AppRoutes.userProfile(name),
          );
        _taps.add(tap);
      }
      // A Latin handle keeps its `@` in front inside Arabic text.
      out.add(
        TextSpan(
          text: hash ? '#$name' : '\u2066@$name\u2069',
          style: accent,
          recognizer: tap,
        ),
      );
      last = m.start + 1 + name.length;
    }
    if (last < s.length) out.add(TextSpan(text: s.substring(last)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    // Measure with exactly what [Text] will render: the ambient style merged
    // with ours, the locale's font fallback and the text scale.
    final style = DefaultTextStyle.of(context).style
        .merge(widget.style.copyWith(color: context.palette.textPrimary));
    final lead = TextSpan(
      text: '${widget.lead} ',
      style: style.copyWith(fontWeight: FontWeight.w600),
    );
    InlineSpan caption(String s, {InlineSpan? tail, bool links = false}) =>
        TextSpan(
          style: style,
          children: [
            lead,
            ..._entities(s, style, links: links),
            ?tail,
          ],
        );
    if (_expanded) return Text.rich(caption(widget.text, links: true));
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

        if (fits(widget.text)) {
          return Text.rich(caption(widget.text, links: true));
        }
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

/// The action row of a real post: like (the heart toggles, its count opens
/// who liked it; no count when the author hides it), comments (the
/// sheet), repost (not on your own post; a private author's post is
/// refused by the server), the share count, and save at the end. Like,
/// repost and save apply at once and are undone with a message when the
/// API refuses; the counts then come from the server's answer.
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
  late int _comments = widget.post.comments ?? 0;
  late bool _reposted = widget.post.reposted;
  late int _reposts = widget.post.reposts;
  bool _liking = false;
  bool _saving = false;
  bool _reposting = false;

  Future<void> _toggleRepost() async {
    if (_reposting) return;
    final (before, beforeCount) = (_reposted, _reposts);
    final next = !_reposted;
    setState(() {
      _reposting = true;
      _reposted = next;
      _reposts = (_reposts + (next ? 1 : -1)).clamp(0, 1 << 31);
    });
    try {
      final state = await ref
          .read(postsRepositoryProvider)
          .setReposted(widget.postId, reposted: next);
      if (!mounted) return;
      setState(() {
        _reposted = state.reposted;
        _reposts = state.repostCount;
      });
      final l10n = context.l10n;
      KSnack.success(
        context,
        state.reposted ? l10n.feedPostReposted : l10n.feedPostUnreposted,
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _reposted = before;
        _reposts = beforeCount;
      });
      final failure = toAppFailure(e);
      KSnack.error(
        context,
        failure is ServerFailure && failure.code == ErrorCode.validationFailed
            ? context.l10n.feedPostRepostRefused
            : failureMessage(context.l10n, failure),
      );
    } finally {
      if (mounted) setState(() => _reposting = false);
    }
  }

  void _openLikers() => context.push(AppRoutes.postLikes(widget.postId));

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

  Future<void> _openComments() => showCommentsSheet(
    context,
    CommentsTarget(
      postId: widget.postId,
      commentCount: _comments,
      authorId: widget.post.authorId,
      isSelf: widget.post.isSelf,
      commentsOpen: widget.post.commentsOpen,
    ),
    onCount: (n) {
      if (mounted) setState(() => _comments = n);
    },
  );

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
                onTap: _toggleLike,
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
                        if (likes == null)
                          const SizedBox(width: KPostCard.actionGap),
                      ],
                    ),
                  ),
                ),
              ),
              // The count opens who liked it (CONVENTIONS §11.4).
              if (likes != null)
                Semantics(
                  button: true,
                  label: l10n.likersOpen,
                  value: KFormat.compact(likes, l10n),
                  onTap: _openLikers,
                  excludeSemantics: true,
                  child: InkWell(
                    key: FeedPostTile.likersKey,
                    borderRadius: BorderRadius.circular(KRadius.sm),
                    onTap: _openLikers,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: KSizes.minTouchTarget,
                      ),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: KPostCard.actionGap,
                        ),
                        child: Center(widthFactor: 1, child: count(likes)),
                      ),
                    ),
                  ),
                ),
              // Opens the comments (CONVENTIONS §11.5); the count follows
              // what the sheet adds or removes.
              Semantics(
                button: true,
                label: l10n.commentsOpen,
                value: l10n.feedPostCommentCount(
                  KFormat.compact(_comments, l10n),
                ),
                onTap: _openComments,
                excludeSemantics: true,
                child: InkWell(
                  key: FeedPostTile.commentKey,
                  borderRadius: BorderRadius.circular(KRadius.sm),
                  onTap: _openComments,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: KSizes.minTouchTarget,
                      minWidth: KSizes.minTouchTarget,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          AppIcons.comment,
                          size: KPostCard.actionIcon,
                          color: p.textPrimary,
                        ),
                        const SizedBox(width: KSpacing.xs),
                        count(_comments),
                        const SizedBox(width: KPostCard.actionGap),
                      ],
                    ),
                  ),
                ),
              ),
              if (!widget.post.isSelf)
                Semantics(
                  button: true,
                  toggled: _reposted,
                  label: _reposted
                      ? l10n.feedPostUnrepost
                      : l10n.feedPostRepost,
                  value: KFormat.compact(_reposts, l10n),
                  onTap: _toggleRepost,
                  excludeSemantics: true,
                  child: InkWell(
                    key: FeedPostTile.repostKey,
                    borderRadius: BorderRadius.circular(KRadius.sm),
                    onTap: _toggleRepost,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: KSizes.minTouchTarget,
                        minWidth: KSizes.minTouchTarget,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(
                            AppIcons.repost,
                            size: KPostCard.actionIcon,
                            color: _reposted ? p.primary : p.textPrimary,
                          ),
                          const SizedBox(width: KSpacing.xs),
                          Text(
                            KFormat.compact(_reposts, l10n),
                            style: _reposted
                                ? style.copyWith(color: p.primary)
                                : style,
                          ),
                          const SizedBox(width: KPostCard.actionGap),
                        ],
                      ),
                    ),
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
