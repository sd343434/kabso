import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show AsyncNotifierProviderFamily;
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:material_ui/material_ui.dart';

/// A top-level comment and the replies loaded so far.
@immutable
class CommentThread {
  const new({
    required this.comment,
    this.replies = const [],
    this.repliesNext,
    this.repliesLoaded = false,
    this.expanded = false,
    this.loadingReplies = false,
  });

  final Comment comment;
  final List<Comment> replies;

  /// Cursor of the next replies page (`null` at the end).
  final String? repliesNext;
  final bool repliesLoaded;
  final bool expanded;
  final bool loadingReplies;

  /// Replies on the server not loaded yet.
  int get moreReplies => repliesLoaded && repliesNext == null
      ? 0
      : (comment.replyCount - replies.length).clamp(0, comment.replyCount);

  CommentThread copyWith({
    Comment? comment,
    List<Comment>? replies,
    String? repliesNext,
    bool clearNext = false,
    bool? repliesLoaded,
    bool? expanded,
    bool? loadingReplies,
  }) => CommentThread(
    comment: comment ?? this.comment,
    replies: replies ?? this.replies,
    repliesNext: clearNext ? null : (repliesNext ?? this.repliesNext),
    repliesLoaded: repliesLoaded ?? this.repliesLoaded,
    expanded: expanded ?? this.expanded,
    loadingReplies: loadingReplies ?? this.loadingReplies,
  );
}

/// The comments of one post as loaded so far.
@immutable
class CommentsState {
  const new({
    required this.threads,
    this.next,
    this.loadingMore = false,
    this.countDelta = 0,
    this.sort = CommentSort.relevant,
  });

  final List<CommentThread> threads;

  /// Cursor of the next page (`null` at the end).
  final String? next;
  final bool loadingMore;

  /// Comments added minus comments removed here (replies included), to
  /// keep the post's `commentCount` current without reloading it.
  final int countDelta;

  /// The order the list is in (D364); kept while the sheet is open.
  final CommentSort sort;

  CommentsState copyWith({
    List<CommentThread>? threads,
    String? next,
    bool clearNext = false,
    bool? loadingMore,
    int? countDelta,
  }) => CommentsState(
    threads: threads ?? this.threads,
    next: clearNext ? null : (next ?? this.next),
    loadingMore: loadingMore ?? this.loadingMore,
    countDelta: countDelta ?? this.countDelta,
    sort: sort,
  );
}

/// The comments sheet of a post on the comments API (CONVENTIONS §11.5):
/// pages of top-level comments (the pinned one first, then by likes, then
/// newest), replies loaded on demand (one level), and the caller's
/// comment, reply, like, pin and delete. Every action that fails throws
/// its `AppFailure` and leaves the list as the server has it.
class CommentsController extends AsyncNotifier<CommentsState> {
  new(this.postId);

  final String postId;

  PostsRepository get _repo => ref.read(postsRepositoryProvider);

  /// The chosen order (D364): the sheet's menu; a rebuild keeps it.
  CommentSort _sort = CommentSort.relevant;

  @override
  Future<CommentsState> build() async {
    ref
      ..watch(currentUserProvider.select((u) => u?.id))
      ..watch(postsRepositoryProvider);
    final sort = _sort;
    final page = await _repo.comments(postId, sort: sort);
    return CommentsState(
      threads: [for (final c in page.items) CommentThread(comment: c)],
      next: page.next,
      sort: sort,
    );
  }

  /// Lists the comments in [sort] from the first page (D364). The count
  /// kept for the post ([CommentsState.countDelta]) carries over. A later
  /// choice wins over an earlier answer still on its way.
  /// [reload] loads it again even when it is the current order (retry).
  Future<void> setSort(CommentSort sort, {bool reload = false}) async {
    if (sort == _sort && state.hasValue && !reload) return;
    _sort = sort;
    final delta = _current?.countDelta ?? 0;
    state = const AsyncLoading();
    try {
      final page = await _repo.comments(postId, sort: sort);
      if (_sort != sort) return;
      _set(
        CommentsState(
          threads: [for (final c in page.items) CommentThread(comment: c)],
          next: page.next,
          countDelta: delta,
          sort: sort,
        ),
      );
    } on Object catch (e, st) {
      if (_sort == sort && ref.mounted) state = AsyncError(e, st);
    }
  }

  CommentsState? get _current => state.value;

  void _set(CommentsState next) {
    if (ref.mounted) state = AsyncData(next);
  }

  CommentsState _mapThread(
    CommentsState s,
    String id,
    CommentThread Function(CommentThread) f,
  ) => s.copyWith(
    threads: [
      for (final t in s.threads)
        if (t.comment.id == id) f(t) else t,
    ],
  );

  /// The next page of top-level comments, when one exists.
  Future<void> loadMore() async {
    final s = _current;
    if (s == null || s.next == null || s.loadingMore) return;
    _set(s.copyWith(loadingMore: true));
    try {
      final page = await _repo.comments(postId, cursor: s.next, sort: s.sort);
      final now = _current!;
      final known = {for (final t in now.threads) t.comment.id};
      _set(
        now.copyWith(
          threads: [
            ...now.threads,
            for (final c in page.items)
              if (!known.contains(c.id)) CommentThread(comment: c),
          ],
          next: page.next,
          clearNext: page.next == null,
          loadingMore: false,
        ),
      );
    } on Object {
      final now = _current;
      if (now != null) _set(now.copyWith(loadingMore: false));
      rethrow;
    }
  }

  /// Shows or hides the replies of [commentId], loading the first page the
  /// first time.
  Future<void> toggleReplies(String commentId) async {
    final s = _current;
    if (s == null) return;
    final thread = s.threads.firstWhere((t) => t.comment.id == commentId);
    if (thread.expanded) {
      _set(_mapThread(s, commentId, (t) => t.copyWith(expanded: false)));
      return;
    }
    if (thread.repliesLoaded) {
      _set(_mapThread(s, commentId, (t) => t.copyWith(expanded: true)));
      return;
    }
    await moreReplies(commentId);
  }

  /// The next page of replies of [commentId].
  Future<void> moreReplies(String commentId) async {
    final s = _current;
    if (s == null) return;
    final thread = s.threads.firstWhere((t) => t.comment.id == commentId);
    if (thread.loadingReplies) return;
    _set(_mapThread(s, commentId, (t) => t.copyWith(loadingReplies: true)));
    try {
      final page = await _repo.replies(
        commentId,
        cursor: thread.repliesLoaded ? thread.repliesNext : null,
      );
      _set(
        _mapThread(_current!, commentId, (t) {
          final known = {for (final r in t.replies) r.id};
          return t.copyWith(
            replies: [
              ...t.replies,
              for (final r in page.items)
                if (!known.contains(r.id)) r,
            ],
            repliesNext: page.next,
            clearNext: page.next == null,
            repliesLoaded: true,
            expanded: true,
            loadingReplies: false,
          );
        }),
      );
    } on Object {
      final now = _current;
      if (now != null) {
        _set(
          _mapThread(now, commentId, (t) => t.copyWith(loadingReplies: false)),
        );
      }
      rethrow;
    }
  }

  /// Posts [text] as a comment, or as a reply to [replyTo] (a reply to a
  /// reply joins its top-level comment).
  Future<Comment> add(String text, {Comment? replyTo}) async {
    final parentId = replyTo == null ? null : (replyTo.parentId ?? replyTo.id);
    final created = await _repo.createComment(
      postId,
      text.trim(),
      parentId: parentId,
    );
    final s = _current;
    if (s == null) return created;
    if (created.parentId case final parent?) {
      _set(
        _mapThread(
          s.copyWith(countDelta: s.countDelta + 1),
          parent,
          (t) => t.copyWith(
            comment: t.comment.copyWith(replyCount: t.comment.replyCount + 1),
            replies: [...t.replies.where((r) => r.id != created.id), created],
            expanded: true,
          ),
        ),
      );
    } else {
      // Below the pinned comment, above the rest (the newest of the caller).
      final pinned = s.threads.takeWhile((t) => t.comment.pinned).length;
      _set(
        s.copyWith(
          threads: [
            ...s.threads.take(pinned),
            CommentThread(comment: created, repliesLoaded: true),
            ...s.threads.skip(pinned),
          ],
          countDelta: s.countDelta + 1,
        ),
      );
    }
    return created;
  }

  /// D372: a gift line the caller just sent on the post (`sendContentGift`
  /// answered it): shown below the pinned comment, above the rest, and
  /// counted. A line already listed is not added twice.
  void addGiftLine(Comment line) {
    final s = _current;
    if (s == null || s.threads.any((t) => t.comment.id == line.id)) return;
    final pinned = s.threads.takeWhile((t) => t.comment.pinned).length;
    _set(
      s.copyWith(
        threads: [
          ...s.threads.take(pinned),
          CommentThread(comment: line, repliesLoaded: true),
          ...s.threads.skip(pinned),
        ],
        countDelta: s.countDelta + 1,
      ),
    );
  }

  /// Deletes [comment] (and, for a top-level one, its replies).
  Future<void> delete(Comment comment) async {
    await _repo.deleteComment(comment.id);
    final s = _current;
    if (s == null) return;
    if (comment.parentId case final parent?) {
      _set(
        _mapThread(
          s.copyWith(countDelta: s.countDelta - 1),
          parent,
          (t) => t.copyWith(
            comment: t.comment.copyWith(
              replyCount: (t.comment.replyCount - 1).clamp(0, 1 << 31),
            ),
            replies: [
              for (final r in t.replies)
                if (r.id != comment.id) r,
            ],
          ),
        ),
      );
    } else {
      final removed = s.threads
          .where((t) => t.comment.id == comment.id)
          .fold(0, (n, t) => n + 1 + t.comment.replyCount);
      _set(
        s.copyWith(
          threads: [
            for (final t in s.threads)
              if (t.comment.id != comment.id) t,
          ],
          countDelta: s.countDelta - removed,
        ),
      );
    }
  }

  void _replace(Comment c) {
    final s = _current;
    if (s == null) return;
    _set(
      s.copyWith(
        threads: [
          for (final t in s.threads)
            if (t.comment.id == c.id)
              t.copyWith(comment: c)
            else if (t.comment.id == c.parentId)
              t.copyWith(
                replies: [
                  for (final r in t.replies)
                    if (r.id == c.id) c else r,
                ],
              )
            else
              t,
        ],
      ),
    );
  }

  /// Likes or unlikes [comment] at once; back as it was when it fails. A
  /// like removes the caller's dislike (D364).
  Future<void> toggleLike(Comment comment) async {
    final next = !comment.viewerHasLiked;
    _replace(
      comment.copyWith(
        viewerHasLiked: next,
        viewerHasDisliked: next ? false : null,
        likeCount: (comment.likeCount + (next ? 1 : -1)).clamp(0, 1 << 31),
      ),
    );
    try {
      final like = await _repo.setCommentLiked(comment.id, liked: next);
      _replace(
        comment.copyWith(
          viewerHasLiked: like.liked,
          viewerHasDisliked: like.liked ? false : null,
          likeCount: like.likeCount ?? comment.likeCount,
        ),
      );
    } on Object {
      _replace(comment);
      rethrow;
    }
  }

  /// Dislikes or takes back the dislike of [comment] at once (D364); a
  /// dislike removes the caller's like. Back as it was when it fails.
  Future<void> toggleDislike(Comment comment) async {
    final next = !comment.viewerHasDisliked;
    final dropsLike = next && comment.viewerHasLiked;
    _replace(
      comment.copyWith(
        viewerHasDisliked: next,
        viewerHasLiked: next ? false : null,
        likeCount: dropsLike
            ? (comment.likeCount - 1).clamp(0, 1 << 31)
            : comment.likeCount,
      ),
    );
    try {
      final r = await _repo.setCommentDisliked(comment.id, disliked: next);
      _replace(
        comment.copyWith(
          viewerHasDisliked: r.disliked,
          viewerHasLiked: r.liked,
          likeCount: r.likeCount,
        ),
      );
    } on Object {
      _replace(comment);
      rethrow;
    }
  }

  /// Pins [comment] (it moves to the top and replaces the previous pin) or
  /// unpins it (post author, top level only).
  Future<void> setPinned(Comment comment, {required bool pinned}) async {
    final updated = await _repo.setCommentPinned(comment.id, pinned: pinned);
    final s = _current;
    if (s == null) return;
    final threads = [
      for (final t in s.threads)
        if (t.comment.id == updated.id)
          t.copyWith(comment: updated)
        else if (pinned && t.comment.pinned)
          t.copyWith(comment: t.comment.copyWith(pinned: false))
        else
          t,
    ];
    if (pinned) {
      final i = threads.indexWhere((t) => t.comment.id == updated.id);
      if (i > 0) threads.insert(0, threads.removeAt(i));
    }
    _set(s.copyWith(threads: threads));
  }
}

final AsyncNotifierProviderFamily<CommentsController, CommentsState, String>
commentsProvider = AsyncNotifierProvider.autoDispose.family(
  CommentsController.new,
);
