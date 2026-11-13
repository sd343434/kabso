import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// One comment of the preview sheet (labelled test data, D46).
class CommentPreview {
  const new({
    required this.name,
    required this.body,
    required this.hoursAgo,
    this.likes = 0,
    this.replies = const [],
    this.verified = false,
    this.creator = false,
  });

  final String name;
  final String body;
  final int hoursAgo;
  final int likes;
  final List<CommentPreview> replies;
  final bool verified;
  final bool creator;
}

List<CommentPreview> commentsPreviewFixture({required bool ar}) => [
  CommentPreview(
    name: ar ? 'نور (تجربة)' : 'Nour (test)',
    body: ar
        ? 'شكرًا لكل من شاهد! هذا تعليق تجريبي من صاحبة المنشور.'
        : 'Thanks for watching! This is a test comment from the creator.',
    hoursAgo: 5,
    likes: 1240,
    verified: true,
    creator: true,
    replies: [
      CommentPreview(
        name: ar ? 'سامي (تجربة)' : 'Sami (test)',
        body: ar ? 'رد تجريبي' : 'A test reply',
        hoursAgo: 4,
        likes: 12,
      ),
    ],
  ),
  CommentPreview(
    name: ar ? 'هند (تجربة)' : 'Hind (test)',
    body: ar
        ? 'تعليق تجريبي أطول قليلًا ليظهر كيف يلتف النص على سطرين داخل '
              'اللوحة دون أن يصل إلى زر الإعجاب.'
        : 'A slightly longer test comment to show how the text wraps over '
              'two lines without reaching the like button.',
    hoursAgo: 3,
    likes: 86,
  ),
  CommentPreview(
    name: ar ? 'عمر (تجربة)' : 'Omar (test)',
    body: ar ? 'بيانات اختبار' : 'Test data',
    hoursAgo: 2,
  ),
];

/// Bottom sheet opened by the feed preview's comment button. Likes, replies
/// and new comments change only this sheet's local state (preview only).
class FeedCommentsSheet extends StatefulWidget {
  const new({super.key});

  static const sheetKey = Key('feed-comments-sheet');
  static const listKey = Key('feed-comments-list');
  static const inputKey = Key('feed-comments-input');
  static const postKey = Key('feed-comments-post');
  static const emojiKey = Key('feed-comments-emoji');
  static const closeKey = Key('feed-comments-close');

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: KCommentsSheet.barrier,
    backgroundColor: const Color(0x00000000),
    builder: (_) => const FeedCommentsSheet(),
  );

  @override
  State<FeedCommentsSheet> createState() => _FeedCommentsSheetState();
}

class _FeedCommentsSheetState extends State<FeedCommentsSheet> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<CommentPreview>? _comments;
  final _liked = <CommentPreview>{};
  final _disliked = <CommentPreview>{};
  final _expanded = <CommentPreview>{};
  CommentSort _sort = CommentSort.relevant;

  /// D364: «الأحدث» lists the fixture newest first (no pin in the preview).
  List<CommentPreview> get _sorted => switch (_sort) {
    CommentSort.relevant => _comments!,
    CommentSort.newest => [
      ..._comments!,
    ]..sort((a, b) => a.hoursAgo.compareTo(b.hoursAgo)),
  };

  /// A like and a dislike exclude each other (D364).
  void _like(CommentPreview c) => setState(() {
    if (!_liked.remove(c)) {
      _liked.add(c);
      _disliked.remove(c);
    }
  });

  void _dislike(CommentPreview c) => setState(() {
    if (!_disliked.remove(c)) {
      _disliked.add(c);
      _liked.remove(c);
    }
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _comments ??= commentsPreviewFixture(
      ar: Directionality.of(context) == TextDirection.rtl,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _post([String? emoji]) {
    final text = emoji ?? _controller.text.trim();
    if (text.isEmpty) return;
    final you = context.l10n.commentsYou;
    setState(() {
      _comments = [
        CommentPreview(name: you, body: text, hoursAgo: 0),
        ..._comments!,
      ];
      if (emoji == null) _controller.clear();
    });
  }

  void _reply(CommentPreview c) {
    _controller.text = '@${c.name} ';
    _focus.requestFocus();
  }

  int get _total => _comments!.fold(0, (n, c) => n + 1 + c.replies.length);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final comments = _sorted;
    return CommentsSheetFrame(
      sheetKey: FeedCommentsSheet.sheetKey,
      closeKey: FeedCommentsSheet.closeKey,
      title: l10n.commentsSheetTitle(_total),
      sort: _sort,
      onSort: (sort) => setState(() => _sort = sort),
      body: ListView.separated(
        key: FeedCommentsSheet.listKey,
        padding: const EdgeInsetsDirectional.fromSTEB(
          KCommentsSheet.listInset,
          KCommentsSheet.listTop,
          KCommentsSheet.listInset,
          KCommentsSheet.listTop,
        ),
        itemCount: comments.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: KCommentsSheet.commentGap),
        itemBuilder: (context, i) {
          final c = comments[i];
          final expanded = _expanded.contains(c);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CommentTile(
                comment: c,
                liked: _liked.contains(c),
                disliked: _disliked.contains(c),
                onLike: () => _like(c),
                onDislike: () => _dislike(c),
                onReply: () => _reply(c),
              ),
              if (expanded)
                for (final r in c.replies)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: KCommentsSheet.avatar + KCommentsSheet.avatarGap,
                      top: KSpacing.xs,
                    ),
                    child: _CommentTile(
                      comment: r,
                      liked: _liked.contains(r),
                      disliked: _disliked.contains(r),
                      onLike: () => _like(r),
                      onDislike: () => _dislike(r),
                      onReply: () => _reply(r),
                    ),
                  ),
              if (c.replies.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: KCommentsSheet.avatar + KCommentsSheet.avatarGap,
                  ),
                  child: _RepliesToggle(
                    count: c.replies.length,
                    expanded: expanded,
                    onTap: () => setState(
                      () => expanded ? _expanded.remove(c) : _expanded.add(c),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      composer: CommentComposer(
        controller: _controller,
        focusNode: _focus,
        inputKey: FeedCommentsSheet.inputKey,
        postKey: FeedCommentsSheet.postKey,
        emojiKey: FeedCommentsSheet.emojiKey,
        onPost: _post,
        // D66: a Kabi emoji posts at once, as its own comment.
        onEmoji: (e) => _post(e.token),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const new({
    required this.comment,
    required this.liked,
    required this.disliked,
    required this.onLike,
    required this.onDislike,
    required this.onReply,
  });

  final CommentPreview comment;
  final bool liked;
  final bool disliked;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final c = comment;
    return CommentRow(
      name: c.name,
      text: c.body,
      when: c.hoursAgo == 0
          ? l10n.feedPostJustNow
          : l10n.relativeHoursAgo(c.hoursAgo),
      likeCount: c.likes + (liked ? 1 : 0),
      liked: liked,
      seal: c.verified
          ? Semantics(
              label: l10n.commentsVerified,
              child: AppIcon(
                AppIcons.checkCircle,
                size: KCommentsSheet.verifiedIcon,
                color: p.info,
              ),
            )
          : null,
      creator: c.creator,
      onLike: onLike,
      disliked: disliked,
      onDislike: onDislike,
      onReply: onReply,
    );
  }
}

class _RepliesToggle extends StatelessWidget {
  const new({required this.count, required this.expanded, required this.onTap});

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              expanded
                  ? l10n.commentsHideReplies
                  : l10n.commentsViewReplies(count),
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
    );
  }
}
