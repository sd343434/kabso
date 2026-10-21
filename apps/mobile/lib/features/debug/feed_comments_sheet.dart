import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/feed_glyphs.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
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
  final _expanded = <CommentPreview>{};

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
    final p = context.palette;
    final l10n = context.l10n;
    final height =
        MediaQuery.sizeOf(context).height * KCommentsSheet.heightFactor;
    final comments = _comments!;
    return Padding(
      // Keeps the composer above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        key: FeedCommentsSheet.sheetKey,
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
              height: KCommentsSheet.headerHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    l10n.commentsSheetTitle(_total),
                    style: context.textStyles.caption.copyWith(
                      fontSize: KCommentsSheet.titleSize,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                  PositionedDirectional(
                    end: KCommentsSheet.closeInset - KSpacing.sm,
                    child: IconButton(
                      key: FeedCommentsSheet.closeKey,
                      tooltip: l10n.liveClose,
                      visualDensity: VisualDensity.compact,
                      onPressed: Navigator.of(context).maybePop,
                      icon: FeedGlyphIcon(
                        FeedGlyph.close,
                        size: KCommentsSheet.closeIcon,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
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
                        onLike: () => setState(
                          () => _liked.contains(c)
                              ? _liked.remove(c)
                              : _liked.add(c),
                        ),
                        onReply: () => _reply(c),
                      ),
                      if (c.replies.isNotEmpty)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(
                            start:
                                KCommentsSheet.avatar +
                                KCommentsSheet.avatarGap,
                            top: KSpacing.sm,
                          ),
                          child: _RepliesToggle(
                            count: c.replies.length,
                            expanded: expanded,
                            onTap: () => setState(
                              () => expanded
                                  ? _expanded.remove(c)
                                  : _expanded.add(c),
                            ),
                          ),
                        ),
                      if (expanded)
                        for (final r in c.replies)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start:
                                  KCommentsSheet.avatar +
                                  KCommentsSheet.avatarGap,
                              top: KSpacing.md,
                            ),
                            child: _CommentTile(
                              comment: r,
                              liked: _liked.contains(r),
                              onLike: () => setState(
                                () => _liked.contains(r)
                                    ? _liked.remove(r)
                                    : _liked.add(r),
                              ),
                              onReply: () => _reply(r),
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
            _CommentBar(
              controller: _controller,
              focusNode: _focus,
              onPost: _post,
              // D66: a Kabi emoji posts at once, as its own comment.
              onEmoji: (e) => _post(e.token),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const new({
    required this.comment,
    required this.liked,
    required this.onLike,
    required this.onReply,
  });

  final CommentPreview comment;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    final c = comment;
    final likes = c.likes + (liked ? 1 : 0);
    final meta = t.caption.copyWith(
      fontSize: KCommentsSheet.metaSize,
      color: p.textTertiary,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KAvatar(name: c.name, size: KCommentsSheet.avatar),
        const SizedBox(width: KCommentsSheet.avatarGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 3,
                children: [
                  Text(
                    c.name,
                    style: meta.copyWith(
                      fontSize: KCommentsSheet.nameSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (c.verified)
                    Semantics(
                      label: l10n.commentsVerified,
                      child: AppIcon(
                        AppIcons.checkCircle,
                        size: KCommentsSheet.verifiedIcon,
                        color: p.info,
                      ),
                    ),
                  if (c.creator) ...[
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
                c.body,
                style: t.body.copyWith(
                  fontSize: KCommentsSheet.bodySize,
                  height: KCommentsSheet.bodyHeight,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(height: KSpacing.xxs),
              Wrap(
                spacing: KCommentsSheet.metaGap,
                children: [
                  Text(
                    c.hoursAgo == 0
                        ? l10n.feedPostJustNow
                        : l10n.relativeHoursAgo(c.hoursAgo),
                    style: meta,
                  ),
                  InkWell(
                    onTap: onReply,
                    child: Text(
                      l10n.commentsReply,
                      style: meta.copyWith(fontWeight: FontWeight.w600),
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
          selected: liked,
          label: l10n.commentsLike(KFormat.compact(likes, l10n)),
          excludeSemantics: true,
          child: InkWell(
            onTap: onLike,
            customBorder: const CircleBorder(),
            // At least the measured column; wider for counts such as 1,240.
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: KCommentsSheet.likeColumn,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(
                    liked ? AppIcons.heartFilled : AppIcons.heart,
                    size: KCommentsSheet.likeIcon,
                    color: liked ? p.primary : p.textTertiary,
                  ),
                  Text(
                    KFormat.compact(likes, l10n),
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

class _CommentBar extends StatelessWidget {
  const new({
    required this.controller,
    required this.focusNode,
    required this.onPost,
    required this.onEmoji,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onPost;
  final ValueChanged<KabiEmojis> onEmoji;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final ar = Directionality.of(context) == TextDirection.rtl;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        border: Border(top: BorderSide(color: p.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KCommentsSheet.barInset,
            vertical: KSpacing.sm,
          ),
          child: Row(
            children: [
              KAvatar(name: l10n.commentsYou, size: KCommentsSheet.barAvatar),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: TextField(
                  key: FeedCommentsSheet.inputKey,
                  controller: controller,
                  focusNode: focusNode,
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
                      key: FeedCommentsSheet.emojiKey,
                      tooltip: l10n.kabiEmojiButton,
                      onPressed: () async {
                        final emoji = await showKabiEmojiPicker(context);
                        if (emoji != null) onEmoji(emoji);
                      },
                      icon: AppIcon(
                        AppIcons.emoji,
                        size: KCommentsSheet.inputIcon,
                        color: p.textSecondary,
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints(),
                    // No outline at rest (the theme's enabled border
                    // would add one); its focus border shows while typing.
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        KCommentsSheet.inputRadius,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        KCommentsSheet.inputRadius,
                      ),
                      borderSide: BorderSide.none,
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        KCommentsSheet.inputRadius,
                      ),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: FeedCommentsSheet.postKey,
                tooltip: l10n.commentsPost,
                onPressed: onPost,
                // The paper plane points along the reading direction.
                icon: Transform.flip(
                  flipX: ar,
                  child: AppIcon(
                    AppIcons.send,
                    size: KCommentsSheet.postIcon,
                    color: p.primary,
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
