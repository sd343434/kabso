import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/posts/application/comments_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the comments sheet (KL-056), measured from the owner's Figma
/// reference (UI kit "Comment page", node 1347:5310, 414x896: sheet 414x653).
/// Only geometry and type sizes are taken from it; colours are Kabso's and
/// avatars are the users' own or initials, never the kit's photos.
abstract final class KCommentsSheet {
  /// Sheet height as a share of the screen (653 / 896).
  static const double heightFactor = 0.73;
  static const double radius = 8;
  static const Color barrier = Color(0x33000000);
  static const double headerHeight = 36;
  static const double titleSize = 13;
  static const double closeIcon = 17;
  static const double closeInset = 16;
  static const double listInset = 14;
  static const double listTop = 12;
  static const double commentGap = 22;
  static const double avatar = 33;
  static const double avatarGap = 12;
  static const double nameSize = 13;
  static const double verifiedIcon = 12;
  static const double bodySize = 15;
  static const double bodyHeight = 1.365;
  static const double metaSize = 13;
  static const double metaGap = 8;
  static const double repliesSize = 12;
  static const double repliesIcon = 18;
  static const double likeIcon = 20;
  static const double likeSize = 13.5;
  static const double likeColumn = 24;
  static const double barAvatar = 32;
  static const double barInset = 12;

  /// Height of the meta row and the replies toggle (text buttons).
  static const double metaTarget = 40;
  static const double inputHeight = 38;
  static const double inputRadius = 8;
  static const double inputIcon = 24;
  static const double postIcon = 28;
}

/// [text] with every `@username` wrapped in a left-to-right isolate, so a
/// Latin handle keeps its `@` in front inside Arabic text (display only;
/// what is sent stays as typed).
String isolateHandles(String text) =>
    text.replaceAllMapped(_handle, (m) => '\u2066${m.group(0)}\u2069');

final RegExp _handle = RegExp(r'(?<![\p{L}\p{N}_])@[a-z0-9._]+', unicode: true);

/// The post a comments sheet belongs to.
@immutable
class CommentsTarget {
  const new({
    required this.postId,
    required this.commentCount,
    required this.authorId,
    required this.isSelf,
    required this.commentsOpen,
  });

  final String postId;
  final int commentCount;

  /// The post's author: their comments carry the "creator" label.
  final String? authorId;

  /// The viewer wrote the post (may pin comments).
  final bool isSelf;

  /// `false` when comments are off or nobody may comment (the author
  /// always may, §11.5). "Followers only" is decided by the server.
  final bool commentsOpen;
}

/// Opens the comments of [target]; [onCount] hears the post's comment count
/// whenever it changes here.
Future<void> showCommentsSheet(
  BuildContext context,
  CommentsTarget target, {
  ValueChanged<int>? onCount,
}) => showModalBottomSheet<void>(
  context: context,
  // Above the bottom bar, like every full sheet.
  useRootNavigator: true,
  isScrollControlled: true,
  barrierColor: KCommentsSheet.barrier,
  backgroundColor: const Color(0x00000000),
  builder: (_) => CommentsSheet(target: target, onCount: onCount),
);

/// The comments of a post on the comments API (CONVENTIONS §11.5): the
/// pinned comment, then by likes, then newest, paged as the list scrolls;
/// replies (one level) open under their comment. Like, reply, and through
/// "⋯": pin (the post's author), delete (the comment's or the post's
/// author) and report (others). The bar posts a comment or, after Reply,
/// a reply; a Kabi emoji posts at once as its own comment (D66). With
/// comments closed the bar says so.
class CommentsSheet extends ConsumerStatefulWidget {
  const new({required this.target, this.onCount, super.key});

  final CommentsTarget target;
  final ValueChanged<int>? onCount;

  static const sheetKey = Key('comments.sheet');
  static const listKey = Key('comments.list');
  static const inputKey = Key('comments.input');
  static const postKey = Key('comments.post');
  static const emojiKey = Key('comments.emoji');
  static const closeKey = Key('comments.close');
  static const retryKey = Key('comments.retry');
  static const closedKey = Key('comments.closed');
  static const cancelReplyKey = Key('comments.reply.cancel');
  static const deleteConfirmKey = Key('comments.delete.confirm');
  static Key commentKey(String id) => Key('comments.item.$id');
  static Key likeKey(String id) => Key('comments.item.$id.like');
  static Key replyKey(String id) => Key('comments.item.$id.reply');
  static Key moreKey(String id) => Key('comments.item.$id.more');
  static Key repliesKey(String id) => Key('comments.item.$id.replies');
  static Key moreRepliesKey(String id) => Key('comments.item.$id.moreReplies');

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

enum _Action { pin, unpin, delete, report }

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Comment? _replyTo;
  bool _sending = false;
  int _lastDelta = 0;

  String get _postId => widget.target.postId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _controller
      ..removeListener(_changed)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  CommentsController get _comments =>
      ref.read(commentsProvider(_postId).notifier);

  void _fail(Object e) {
    if (!mounted) return;
    final failure = toAppFailure(e);
    final l10n = context.l10n;
    KSnack.error(
      context,
      failure is ServerFailure && failure.code == ErrorCode.authForbidden
          ? l10n.commentsNotAllowed
          : failureMessage(l10n, failure),
    );
  }

  Future<void> _send([String? emoji]) async {
    final text = (emoji ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _comments.add(text, replyTo: _replyTo);
      if (!mounted) return;
      setState(() {
        if (emoji == null) _controller.clear();
        _replyTo = null;
      });
    } on Object catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _reply(Comment c) {
    setState(() => _replyTo = c);
    final mention = '@${c.author.username} ';
    if (!_controller.text.startsWith(mention)) {
      _controller.value = TextEditingValue(
        text: mention,
        selection: TextSelection.collapsed(offset: mention.length),
      );
    }
    _focus.requestFocus();
  }

  Future<void> _guard(Future<void> Function() action, [String? done]) async {
    try {
      await action();
      if (done != null && mounted) KSnack.success(context, done);
    } on Object catch (e) {
      _fail(e);
    }
  }

  Future<void> _more(Comment c) async {
    final l10n = context.l10n;
    final me = ref.read(currentUserProvider)?.id;
    final top = c.parentId == null;
    final action = await showModalBottomSheet<_Action>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.target.isSelf && top)
              ListTile(
                key: const Key('comments.action.pin'),
                leading: const Icon(Icons.push_pin_outlined),
                title: Text(c.pinned ? l10n.commentsUnpin : l10n.commentsPin),
                onTap: () =>
                    Navigator.of(sheet)
                        .pop(c.pinned ? _Action.unpin : _Action.pin),
              ),
            if (c.canDelete)
              ListTile(
                key: const Key('comments.action.delete'),
                leading: Icon(Icons.delete_outline, color: sheet.palette.error),
                title: Text(l10n.commentsDelete),
                onTap: () => Navigator.of(sheet).pop(_Action.delete),
              ),
            if (c.author.id != me)
              ListTile(
                key: const Key('comments.action.report'),
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.commentsReport),
                onTap: () => Navigator.of(sheet).pop(_Action.report),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _Action.pin || _Action.unpin:
        await _guard(
          () => _comments.setPinned(c, pinned: action == _Action.pin),
        );
      case _Action.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(l10n.commentsDeleteTitle),
            content: top && c.replyCount > 0
                ? Text(l10n.commentsDeleteWithReplies)
                : null,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: Text(l10n.actionCancel),
              ),
              TextButton(
                key: CommentsSheet.deleteConfirmKey,
                onPressed: () => Navigator.of(dialog).pop(true),
                child: Text(l10n.commentsDelete),
              ),
            ],
          ),
        );
        if ((ok ?? false) && mounted) {
          if (_replyTo?.id == c.id) setState(() => _replyTo = null);
          await _guard(() => _comments.delete(c), l10n.commentsDeleted);
        }
      case _Action.report:
        final reason = await pickReportReason(
          context,
          l10n.commentsReportTitle,
        );
        if (reason == null || !mounted) return;
        await _guard(
          () => ref.read(postsRepositoryProvider).reportComment(c.id, reason),
          l10n.feedPostReported,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final comments = ref.watch(commentsProvider(_postId));
    final delta = comments.value?.countDelta ?? _lastDelta;
    if (delta != _lastDelta) {
      _lastDelta = delta;
      final count = (widget.target.commentCount + delta).clamp(0, 1 << 31);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onCount?.call(count),
      );
    }
    final total = (widget.target.commentCount + delta).clamp(0, 1 << 31);
    final height =
        MediaQuery.sizeOf(context).height * KCommentsSheet.heightFactor;
    return Padding(
      // Keeps the composer above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        key: CommentsSheet.sheetKey,
        height: height,
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(KCommentsSheet.radius),
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: KCommentsSheet.headerHeight + KSpacing.sm,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.commentsSheetTitle(total),
                      style: context.textStyles.caption.copyWith(
                        fontSize: KCommentsSheet.titleSize,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    end: KCommentsSheet.closeInset - KSpacing.md,
                    child: IconButton(
                      key: CommentsSheet.closeKey,
                      tooltip: l10n.liveClose,
                      onPressed: Navigator.of(context).maybePop,
                      icon: AppIcon(
                        AppIcons.close,
                        size: KCommentsSheet.closeIcon,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (comments) {
                AsyncData(:final value) => _List(
                  state: value,
                  target: widget.target,
                  onLike: (c) => _guard(() => _comments.toggleLike(c)),
                  onReply: widget.target.commentsOpen ? _reply : null,
                  onMore: _more,
                  onReplies: (c) => _guard(() => _comments.toggleReplies(c.id)),
                  onMoreReplies: (c) =>
                      _guard(() => _comments.moreReplies(c.id)),
                  onLoadMore: () => _guard(_comments.loadMore),
                ),
                AsyncError() => _Message(
                  title: l10n.commentsFailed,
                  action: TextButton(
                    key: CommentsSheet.retryKey,
                    onPressed: () => ref.invalidate(commentsProvider(_postId)),
                    child: Text(l10n.actionRetry),
                  ),
                ),
                _ => Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(p.primary),
                  ),
                ),
              },
            ),
            if (widget.target.commentsOpen)
              _CommentBar(
                controller: _controller,
                focusNode: _focus,
                sending: _sending,
                replyTo: _replyTo,
                onCancelReply: () => setState(() => _replyTo = null),
                onPost: _send,
                // D66: a Kabi emoji posts at once, as its own comment.
                onEmoji: (e) => _send(e.token),
              )
            else
              _ClosedBar(message: l10n.commentsClosed),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const new({required this.title, this.body, this.action});

  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyStrong.copyWith(
                color: p.textPrimary,
              ),
            ),
            if (body case final b?) ...[
              const SizedBox(height: KSpacing.xs),
              Text(
                b,
                textAlign: TextAlign.center,
                style: context.textStyles.body.copyWith(color: p.textSecondary),
              ),
            ],
            if (action case final a?) ...[
              const SizedBox(height: KSpacing.sm),
              a,
            ],
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const new({
    required this.state,
    required this.target,
    required this.onLike,
    required this.onReply,
    required this.onMore,
    required this.onReplies,
    required this.onMoreReplies,
    required this.onLoadMore,
  });

  final CommentsState state;
  final CommentsTarget target;
  final ValueChanged<Comment> onLike;
  final ValueChanged<Comment>? onReply;
  final ValueChanged<Comment> onMore;
  final ValueChanged<Comment> onReplies;
  final ValueChanged<Comment> onMoreReplies;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final threads = state.threads;
    if (threads.isEmpty) {
      return _Message(title: l10n.commentsEmpty, body: l10n.commentsEmptyHint);
    }
    Widget tile(Comment c) => _CommentTile(
      key: CommentsSheet.commentKey(c.id),
      comment: c,
      creator: c.author.id == target.authorId,
      onLike: () => onLike(c),
      onReply: onReply == null ? null : () => onReply!(c),
      onMore: () => onMore(c),
    );
    const indent = EdgeInsetsDirectional.only(
      start: KCommentsSheet.avatar + KCommentsSheet.avatarGap,
    );
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 300 && state.next != null) onLoadMore();
        return false;
      },
      child: ListView.separated(
        key: CommentsSheet.listKey,
        padding: const EdgeInsetsDirectional.fromSTEB(
          KCommentsSheet.listInset,
          KCommentsSheet.listTop,
          KCommentsSheet.listInset,
          KCommentsSheet.listTop,
        ),
        itemCount: threads.length + (state.loadingMore ? 1 : 0),
        separatorBuilder: (_, _) =>
            const SizedBox(height: KCommentsSheet.commentGap),
        itemBuilder: (context, i) {
          if (i == threads.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final t = threads[i];
          final c = t.comment;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tile(c),
              if (t.expanded)
                for (final r in t.replies)
                  Padding(
                    padding: indent.add(
                      const EdgeInsets.only(top: KSpacing.md),
                    ),
                    child: tile(r),
                  ),
              if (c.replyCount > 0 || t.replies.isNotEmpty)
                Padding(
                  padding: indent,
                  child: Wrap(
                    spacing: KSpacing.md,
                    children: [
                      if (t.expanded && t.moreReplies > 0)
                        _RepliesToggle(
                          key: CommentsSheet.moreRepliesKey(c.id),
                          label: l10n.commentsMoreReplies(t.moreReplies),
                          expanded: false,
                          busy: t.loadingReplies,
                          onTap: () => onMoreReplies(c),
                        ),
                      _RepliesToggle(
                        key: CommentsSheet.repliesKey(c.id),
                        label: t.expanded
                            ? l10n.commentsHideReplies
                            : l10n.commentsViewReplies(c.replyCount),
                        expanded: t.expanded,
                        busy: !t.expanded && t.loadingReplies,
                        onTap: () => onReplies(c),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const new({
    required this.comment,
    required this.creator,
    required this.onLike,
    required this.onReply,
    required this.onMore,
    super.key,
  });

  final Comment comment;
  final bool creator;
  final VoidCallback onLike;
  final VoidCallback? onReply;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    final c = comment;
    final name = c.author.displayName.isEmpty
        ? c.author.username
        : c.author.displayName;
    final meta = t.caption.copyWith(
      fontSize: KCommentsSheet.metaSize,
      color: p.textTertiary,
    );
    final when =
        KFormat.relative(
          c.createdAt,
          clock.now(),
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
        ) ??
        l10n.feedPostJustNow;
    return GestureDetector(
      onLongPress: onMore,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: KAvatar(
              name: name,
              imageUrl: c.author.avatarUrl,
              size: KCommentsSheet.avatar,
            ),
          ),
          const SizedBox(width: KCommentsSheet.avatarGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c.pinned)
                  Padding(
                    padding: const EdgeInsets.only(bottom: KSpacing.xxs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.push_pin_rounded,
                          size: 13,
                          color: p.textTertiary,
                        ),
                        const SizedBox(width: KSpacing.xxs),
                        Text(l10n.commentsPinned, style: meta),
                      ],
                    ),
                  ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 3,
                  children: [
                    Text(
                      name,
                      style: meta.copyWith(
                        fontSize: KCommentsSheet.nameSize,
                        fontWeight: FontWeight.w600,
                        color: p.textSecondary,
                      ),
                    ),
                    if (creator) ...[
                      // Separator dot (drawn, not a text literal).
                      Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          color: p.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        l10n.commentsCreator,
                        style: meta.copyWith(
                          fontWeight: FontWeight.w600,
                          color: p.primaryText,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: KSpacing.xxs),
                KabiEmojiText(
                  isolateHandles(c.text),
                  style: t.body.copyWith(
                    fontSize: KCommentsSheet.bodySize,
                    height: KCommentsSheet.bodyHeight,
                    color: p.textPrimary,
                  ),
                ),
                // Wraps on narrow widths and large text.
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(when, style: meta),
                    if (onReply != null)
                      TextButton(
                        key: CommentsSheet.replyKey(c.id),
                        onPressed: onReply,
                        style: TextButton.styleFrom(
                          foregroundColor: p.textTertiary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: KCommentsSheet.metaGap,
                          ),
                          minimumSize: const Size(0, KCommentsSheet.metaTarget),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.commentsReply,
                          style: meta.copyWith(fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      const SizedBox(
                        width: KCommentsSheet.metaGap,
                        height: KCommentsSheet.metaTarget,
                      ),
                    IconButton(
                      key: CommentsSheet.moreKey(c.id),
                      tooltip: l10n.commentsMore,
                      onPressed: onMore,
                      constraints: const BoxConstraints.tightFor(
                        width: KCommentsSheet.metaTarget,
                        height: KCommentsSheet.metaTarget,
                      ),
                      padding: EdgeInsets.zero,
                      icon: AppIcon(
                        AppIcons.moreHoriz,
                        size: 18,
                        color: p.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          Semantics(
            container: true,
            button: true,
            selected: c.viewerHasLiked,
            label: l10n.commentsLike(KFormat.compact(c.likeCount, l10n)),
            onTap: onLike,
            excludeSemantics: true,
            child: InkWell(
              key: CommentsSheet.likeKey(c.id),
              onTap: onLike,
              customBorder: const CircleBorder(),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: KSizes.minTouchTarget,
                  minHeight: KSizes.minTouchTarget,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppIcon(
                      c.viewerHasLiked ? AppIcons.heartFilled : AppIcons.heart,
                      size: KCommentsSheet.likeIcon,
                      color: c.viewerHasLiked ? p.primary : p.textTertiary,
                    ),
                    Text(
                      KFormat.compact(c.likeCount, l10n),
                      maxLines: 1,
                      style: t.caption.copyWith(
                        fontSize: KCommentsSheet.likeSize,
                        color: p.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RepliesToggle extends StatelessWidget {
  const new({
    required this.label,
    required this.expanded,
    required this.busy,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool expanded;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      container: true,
      button: true,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: KCommentsSheet.metaTarget,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.caption.copyWith(
                    fontSize: KCommentsSheet.repliesSize,
                    fontWeight: FontWeight.w600,
                    color: p.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              if (busy)
                const SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                RotatedBox(
                  quarterTurns: expanded ? 2 : 0,
                  child: AppIcon(
                    AppIcons.chevronDown,
                    size: KCommentsSheet.repliesIcon,
                    color: p.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosedBar extends StatelessWidget {
  const new({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        border: Border(top: BorderSide(color: p.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          key: CommentsSheet.closedKey,
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: p.textTertiary),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: context.textStyles.caption.copyWith(
                    color: p.textSecondary,
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

class _CommentBar extends ConsumerWidget {
  const new({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.replyTo,
    required this.onCancelReply,
    required this.onPost,
    required this.onEmoji,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final Comment? replyTo;
  final VoidCallback onCancelReply;
  final VoidCallback onPost;
  final ValueChanged<KabsoEmoji> onEmoji;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final l10n = context.l10n;
    final ar = Directionality.of(context) == TextDirection.rtl;
    final me = ref.watch(currentUserProvider);
    final canPost = !sending && controller.text.trim().isNotEmpty;
    final noBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(KCommentsSheet.inputRadius),
      borderSide: BorderSide.none,
    );
    final reply = replyTo;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        border: Border(top: BorderSide(color: p.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reply != null)
              Container(
                color: p.surfaceOverlay.withValues(alpha: 0.5),
                padding: const EdgeInsetsDirectional.only(
                  start: KCommentsSheet.barInset,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.commentsReplyingTo(
                          reply.author.displayName.isEmpty
                              ? reply.author.username
                              : reply.author.displayName,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.caption.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ),
                    IconButton(
                      key: CommentsSheet.cancelReplyKey,
                      tooltip: l10n.commentsCancelReply,
                      onPressed: onCancelReply,
                      icon: AppIcon(
                        AppIcons.close,
                        size: 14,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KCommentsSheet.barInset,
                vertical: KSpacing.sm,
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: KAvatar(
                      name: me?.displayName ?? l10n.commentsYou,
                      size: KCommentsSheet.barAvatar,
                    ),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  Expanded(
                    // Direction follows the first letter outside tags: a
                    // reply's lone @handle reads left to right.
                    child: ValueListenableBuilder(
                      valueListenable: controller,
                      builder: (context, value, _) => TextField(
                        key: CommentsSheet.inputKey,
                        textDirection: KFormat.inputDirection(value.text),
                        controller: controller,
                        focusNode: focusNode,
                        enabled: !sending,
                        minLines: 1,
                        maxLines: 4,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(maxCommentText),
                        ],
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onPost(),
                        decoration: InputDecoration(
                          hintText: l10n.commentsHint,
                          filled: true,
                          fillColor: p.surfaceOverlay,
                          isDense: true,
                          constraints: const BoxConstraints(
                            minHeight: KCommentsSheet.inputHeight,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: KSpacing.sm,
                            vertical: KSpacing.sm + 2,
                          ),
                          suffixIcon: IconButton(
                            key: CommentsSheet.emojiKey,
                            tooltip: l10n.kabiEmojiButton,
                            onPressed: sending
                                ? null
                                : () async {
                                    final emoji = await showKabiEmojiPicker(
                                      context,
                                    );
                                    if (emoji != null) onEmoji(emoji);
                                  },
                            icon: AppIcon(
                              AppIcons.emoji,
                              size: KCommentsSheet.inputIcon,
                              color: p.textSecondary,
                            ),
                          ),
                          suffixIconConstraints: const BoxConstraints(),
                          // No outline at rest; the theme's focus border
                          // shows while typing.
                          border: noBorder,
                          enabledBorder: noBorder,
                          disabledBorder: noBorder,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: CommentsSheet.postKey,
                    tooltip: l10n.commentsPost,
                    onPressed: canPost ? onPost : null,
                    icon: sending
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        // The paper plane points along the reading direction.
                        : Transform.flip(
                            flipX: ar,
                            child: AppIcon(
                              AppIcons.send,
                              size: KCommentsSheet.postIcon,
                              color: canPost
                                  ? p.primary
                                  : p.primary.withValues(alpha: 0.35),
                            ),
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
