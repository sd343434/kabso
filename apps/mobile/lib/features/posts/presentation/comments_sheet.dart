import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/posts/application/comments_controller.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/features/profile/profile_verification_badge.dart';
import 'package:kabso_live/features/status/status_emoji_layer.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the comments sheet. The layout follows the owner's
/// reel-comments reference: the reel stays visible above a rounded sheet
/// with a tab handle, a centred count, a sort line, rows whose footer ends
/// with the like, and a floating pill composer. Only geometry comes from
/// it; colours, icons and type are Kabso's, and avatars are the users' own
/// or initials.
abstract final class KCommentsSheet {
  /// Sheet height as a share of the screen: the reel's upper part stays
  /// visible above it.
  static const double heightFactor = 0.6;
  static const double radius = 28;

  /// A light barrier, so the reel behind stays clearly visible.
  static const Color barrier = Color(0x1F000000);

  /// The tab-shaped handle centred on the top edge: it rises [tabRise]
  /// above the sheet and holds the grab bar.
  static const double tabRise = 8;
  static const Size tab = Size(64, 22);
  static const double tabRadius = 11;
  static const Size grabBar = Size(28, 4);

  /// Tap area of the handle (closes the sheet; swiping down does too).
  static const Size handleTarget = Size(96, KSizes.minTouchTarget);
  static const double headerTop = 14;
  static const double titleSize = 15;
  static const double sortSize = 13;
  static const double sortIcon = 16;
  static const double sortHeight = 32;
  static const double listInset = 16;
  static const double listTop = 4;
  static const double commentGap = 14;
  static const double avatar = 44;
  static const double avatarGap = 12;
  static const double nameSize = 13.5;
  static const double verifiedIcon = 12;
  static const double bodySize = 14.5;
  static const double bodyHeight = 1.4;
  static const double metaSize = 12.5;
  static const double metaGap = 8;
  static const double repliesSize = 12;
  static const double repliesIcon = 18;
  static const double likeIcon = 18;
  static const double likeSize = 12.5;

  /// Height of the footer row and the replies toggle (text buttons).
  static const double metaTarget = 40;

  /// The floating pill composer, inset from the sheet's edges.
  static const double composerRadius = 28;
  static const double composerInset = 12;
  static const double composerBottom = 8;
  static const double composerPadding = 6;
  static const double composerButton = 38;
  static const double composerIcon = 20;
  static const List<BoxShadow> composerShadow = [
    BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const double inputHeight = 38;

  /// D372: the gift box button sits this far after «+»; its art is a little
  /// larger than the line icons (a picture, not a glyph).
  static const double composerGap = 4;
  static const double composerGiftArt = 26;

  /// D372: the gift line's picture.
  static const double giftArt = 28;
}

/// The frame of a comments sheet: the tab handle (tap to close, or swipe
/// the sheet down), the centred [title], the order menu, then [body] and
/// [composer]. Shared by [CommentsSheet] and the feed preview's sheet.
class CommentsSheetFrame extends StatelessWidget {
  const new({
    required this.sheetKey,
    required this.closeKey,
    required this.title,
    required this.body,
    required this.composer,
    required this.sort,
    required this.onSort,
    super.key,
  });

  final Key sheetKey;
  final Key closeKey;
  final String title;
  final Widget body;
  final Widget composer;

  /// The list's order and the menu that changes it (D364).
  final CommentSort sort;
  final ValueChanged<CommentSort> onSort;

  /// The order menu's button and its items.
  static const sortKey = Key('comments.sort');
  static Key sortOptionKey(CommentSort sort) =>
      Key('comments.sort.${sort.name}');

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    final height =
        MediaQuery.sizeOf(context).height * KCommentsSheet.heightFactor;
    return Padding(
      // Keeps the composer above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height + KCommentsSheet.tabRise,
        child: Stack(
          children: [
            PositionedDirectional(
              top: KCommentsSheet.tabRise,
              start: 0,
              end: 0,
              bottom: 0,
              child: Container(
                key: sheetKey,
                decoration: BoxDecoration(
                  color: p.surfaceRaised,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(KCommentsSheet.radius),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: KCommentsSheet.headerTop),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: t.bodyStrong.copyWith(
                          fontSize: KCommentsSheet.titleSize,
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: KCommentsSheet.listInset - KSpacing.sm,
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _SortMenu(sort: sort, onSort: onSort),
                      ),
                    ),
                    Expanded(child: body),
                    composer,
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Semantics(
                button: true,
                label: l10n.liveClose,
                child: GestureDetector(
                  key: closeKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: Navigator.of(context).maybePop,
                  child: SizedBox.fromSize(
                    size: KCommentsSheet.handleTarget,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: KCommentsSheet.tab.width,
                        height: KCommentsSheet.tab.height,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.surfaceRaised,
                          borderRadius: BorderRadius.circular(
                            KCommentsSheet.tabRadius,
                          ),
                        ),
                        child: Container(
                          width: KCommentsSheet.grabBar.width,
                          height: KCommentsSheet.grabBar.height,
                          decoration: BoxDecoration(
                            color: p.borderStrong,
                            borderRadius: BorderRadius.circular(KRadius.pill),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «الأكثر صلة ⌄»: the current order; a tap opens the menu of both (D364).
class _SortMenu extends StatelessWidget {
  const new({required this.sort, required this.onSort});

  final CommentSort sort;
  final ValueChanged<CommentSort> onSort;

  static String label(AppLocalizations l10n, CommentSort sort) =>
      switch (sort) {
        CommentSort.relevant => l10n.commentsSortRelevant,
        CommentSort.newest => l10n.commentsSortNewest,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    return PopupMenuButton<CommentSort>(
      key: CommentsSheetFrame.sortKey,
      tooltip: l10n.commentsSortMenu,
      initialValue: sort,
      onSelected: onSort,
      position: PopupMenuPosition.under,
      color: p.surfaceOverlay,
      // Flat with a hairline: the raised overlay colour already lifts it off
      // the sheet.
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.lg),
        side: BorderSide(color: p.border),
      ),
      itemBuilder: (_) => [
        for (final s in CommentSort.values)
          PopupMenuItem(
            key: CommentsSheetFrame.sortOptionKey(s),
            value: s,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label(l10n, s),
                    style: t.body.copyWith(
                      color: p.textPrimary,
                      fontWeight: s == sort ? FontWeight.w600 : null,
                    ),
                  ),
                ),
                const SizedBox(width: KSpacing.md),
                if (s == sort)
                  Icon(Icons.check_rounded, size: 18, color: p.primaryText)
                else
                  const SizedBox(width: 18),
              ],
            ),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KCommentsSheet.sortHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label(l10n, sort),
                style: t.label.copyWith(
                  fontSize: KCommentsSheet.sortSize,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(width: KSpacing.xxs),
              AppIcon(
                AppIcons.chevronDown,
                size: KCommentsSheet.sortIcon,
                color: p.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One comment row: round avatar at the start; the name, seal, creator tag
/// and time on one line; the text; then a footer with Reply and "⋯" at the
/// start and the like (icon and count) at the end. A long press opens the
/// same actions as "⋯".
class CommentRow extends StatelessWidget {
  const new({
    required this.name,
    required this.text,
    required this.when,
    required this.likeCount,
    required this.liked,
    required this.onLike,
    this.avatarUrl,
    this.statusEmojiId,
    this.seal,
    this.creator = false,
    this.pinned = false,
    this.onReply,
    this.onMore,
    this.disliked = false,
    this.onDislike,
    this.likeKey,
    this.dislikeKey,
    this.replyKey,
    this.moreKey,
    this.gift,
    super.key,
  });

  final String name;

  /// Shown as is (callers isolate `@handles` first).
  final String text;

  /// D372: a gift line's body ([CommentGiftLine]) in place of [text].
  final Widget? gift;
  final String when;
  final int likeCount;
  final bool liked;
  final VoidCallback onLike;
  final String? avatarUrl;

  /// D376 «الحالة»: the author's status, a small still emoji on the
  /// avatar's corner (no motion in a long list).
  final String? statusEmojiId;

  /// The verification seal after the name, if any.
  final Widget? seal;
  final bool creator;
  final bool pinned;
  final VoidCallback? onReply;
  final VoidCallback? onMore;

  /// D364: the caller's private dislike, after the like (no count).
  final bool disliked;
  final VoidCallback? onDislike;
  final Key? likeKey;
  final Key? dislikeKey;
  final Key? replyKey;
  final Key? moreKey;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final t = context.textStyles;
    final meta = t.caption.copyWith(
      fontSize: KCommentsSheet.metaSize,
      color: p.textTertiary,
    );
    // Separator dot (drawn, not a text literal).
    Widget dot() => Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(color: p.textTertiary, shape: BoxShape.circle),
    );
    return GestureDetector(
      onLongPress: onMore,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: StatusAvatar(
              radius: KCommentsSheet.avatar / 2,
              statusEmojiId: statusEmojiId,
              motion: StatusEmojiMotion.badge,
              semantics: false,
              child: KAvatar(
                name: name,
                imageUrl: avatarUrl,
                size: KCommentsSheet.avatar,
              ),
            ),
          ),
          const SizedBox(width: KCommentsSheet.avatarGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pinned)
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
                  spacing: KSpacing.xs,
                  runSpacing: KSpacing.xxs,
                  children: [
                    Text(
                      name,
                      style: t.label.copyWith(
                        fontSize: KCommentsSheet.nameSize,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    ?seal,
                    if (creator)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: p.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(KRadius.xs),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: KSpacing.xs,
                          ),
                          child: Text(
                            l10n.commentsCreator,
                            style: meta.copyWith(
                              fontSize: KCommentsSheet.metaSize - 1,
                              fontWeight: FontWeight.w600,
                              color: p.primaryText,
                            ),
                          ),
                        ),
                      ),
                    dot(),
                    Text(when, style: meta),
                  ],
                ),
                const SizedBox(height: KSpacing.xxs),
                ?gift,
                if (gift == null)
                  KabiEmojiText(
                    text,
                    style: t.body.copyWith(
                      fontSize: KCommentsSheet.bodySize,
                      height: KCommentsSheet.bodyHeight,
                      color: p.textSecondary,
                    ),
                  ),
                Row(
                  children: [
                    if (onReply != null)
                      TextButton(
                        key: replyKey,
                        onPressed: onReply,
                        style: TextButton.styleFrom(
                          foregroundColor: p.textTertiary,
                          padding: const EdgeInsetsDirectional.only(
                            end: KCommentsSheet.metaGap,
                          ),
                          minimumSize: const Size(0, KCommentsSheet.metaTarget),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.commentsReply,
                          style: meta.copyWith(
                            fontWeight: FontWeight.w600,
                            color: p.textSecondary,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: KCommentsSheet.metaTarget),
                    if (onMore != null)
                      IconButton(
                        key: moreKey,
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
                    const Spacer(),
                    Semantics(
                      container: true,
                      button: true,
                      selected: liked,
                      label: l10n.commentsLike(
                        KFormat.compact(likeCount, l10n),
                      ),
                      onTap: onLike,
                      excludeSemantics: true,
                      child: InkWell(
                        key: likeKey,
                        onTap: onLike,
                        borderRadius: BorderRadius.circular(KRadius.pill),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: KSizes.minTouchTarget,
                            minHeight: KCommentsSheet.metaTarget,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: KSpacing.xs,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AppIcon(
                                  liked ? AppIcons.heartFilled : AppIcons.heart,
                                  size: KCommentsSheet.likeIcon,
                                  color: liked ? p.primary : p.textTertiary,
                                ),
                                const SizedBox(width: KSpacing.xs),
                                Text(
                                  KFormat.compact(likeCount, l10n),
                                  maxLines: 1,
                                  style: meta.copyWith(
                                    fontSize: KCommentsSheet.likeSize,
                                    color: p.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (onDislike case final dislike?)
                      Semantics(
                        container: true,
                        button: true,
                        selected: disliked,
                        label: l10n.commentsDislike,
                        onTap: dislike,
                        excludeSemantics: true,
                        child: InkWell(
                          key: dislikeKey,
                          onTap: dislike,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: KCommentsSheet.metaTarget,
                            height: KCommentsSheet.metaTarget,
                            child: Center(
                              child: AppIcon(
                                disliked
                                    ? AppIcons.thumbDownFilled
                                    : AppIcons.thumbDown,
                                size: KCommentsSheet.likeIcon,
                                color: disliked
                                    ? p.textPrimary
                                    : p.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating pill composer: a round "+" at the start (the Kabi emoji
/// picker), the field, and a round brand-red send button at the end. A
/// reply chip sits above it while replying.
class CommentComposer extends StatelessWidget {
  const new({
    required this.controller,
    required this.focusNode,
    required this.onPost,
    required this.onEmoji,
    required this.inputKey,
    required this.postKey,
    required this.emojiKey,
    this.canPost = true,
    this.sending = false,
    this.replyingTo,
    this.onCancelReply,
    this.cancelReplyKey,
    this.maxLength,
    this.onGift,
    this.giftKey,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onPost;
  final ValueChanged<KabsoEmoji> onEmoji;
  final Key inputKey;
  final Key postKey;
  final Key emojiKey;
  final bool canPost;
  final bool sending;

  /// The name of the comment being replied to (shows the reply chip).
  final String? replyingTo;
  final VoidCallback? onCancelReply;
  final Key? cancelReplyKey;
  final int? maxLength;

  /// D372 «هدية الدعم»: opens the gift panel (a gift box beside «+»); null
  /// hides the button (the author is not a host or a content creator, or
  /// it is the viewer's own post).
  final VoidCallback? onGift;
  final Key? giftKey;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l10n = context.l10n;
    final ar = Directionality.of(context) == TextDirection.rtl;
    final gift = onGift;
    const noBorder = OutlineInputBorder(borderSide: BorderSide.none);
    final reply = replyingTo;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: KCommentsSheet.composerBottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KCommentsSheet.composerInset,
          KSpacing.xs,
          KCommentsSheet.composerInset,
          0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (reply != null)
              Padding(
                padding: const EdgeInsets.only(bottom: KSpacing.xs),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.surfaceOverlay,
                    borderRadius: BorderRadius.circular(KRadius.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: KSpacing.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.commentsReplyingTo(reply),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyles.caption.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ),
                        IconButton(
                          key: cancelReplyKey,
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
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: p.surfaceOverlay,
                borderRadius: BorderRadius.circular(
                  KCommentsSheet.composerRadius,
                ),
                boxShadow: KCommentsSheet.composerShadow,
              ),
              child: Padding(
                padding: const EdgeInsets.all(KCommentsSheet.composerPadding),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      key: emojiKey,
                      tooltip: l10n.kabiEmojiButton,
                      onPressed: sending
                          ? null
                          : () async {
                              final emoji = await showKabiEmojiPicker(context);
                              if (emoji != null) onEmoji(emoji);
                            },
                      style: IconButton.styleFrom(
                        backgroundColor: p.surfaceRaised,
                        fixedSize: const Size.square(
                          KCommentsSheet.composerButton,
                        ),
                        minimumSize: const Size.square(
                          KCommentsSheet.composerButton,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      icon: AppIcon(
                        AppIcons.plus,
                        size: KCommentsSheet.composerIcon,
                        color: p.textPrimary,
                      ),
                    ),
                    if (gift != null) ...[
                      const SizedBox(width: KCommentsSheet.composerGap),
                      IconButton(
                        key: giftKey,
                        tooltip: l10n.contentGiftButton,
                        onPressed: sending ? null : gift,
                        style: IconButton.styleFrom(
                          backgroundColor: p.surfaceRaised,
                          fixedSize: const Size.square(
                            KCommentsSheet.composerButton,
                          ),
                          minimumSize: const Size.square(
                            KCommentsSheet.composerButton,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const KabsoArtIcon(
                          KabsoArt.giftBox,
                          size: KCommentsSheet.composerGiftArt,
                        ),
                      ),
                    ],
                    Expanded(
                      // Direction follows the first letter outside tags: a
                      // reply's lone @handle reads left to right.
                      child: ValueListenableBuilder(
                        valueListenable: controller,
                        builder: (context, value, _) => TextField(
                          key: inputKey,
                          textDirection: KFormat.inputDirection(value.text),
                          controller: controller,
                          focusNode: focusNode,
                          enabled: !sending,
                          minLines: 1,
                          maxLines: 4,
                          inputFormatters: [
                            if (maxLength case final max?)
                              LengthLimitingTextInputFormatter(max),
                          ],
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onPost(),
                          style: context.textStyles.body.copyWith(
                            color: p.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: l10n.commentsHint,
                            hintStyle: context.textStyles.body.copyWith(
                              color: p.textTertiary,
                            ),
                            filled: false,
                            isDense: true,
                            constraints: const BoxConstraints(
                              minHeight: KCommentsSheet.inputHeight,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: KSpacing.md,
                              vertical: KSpacing.sm + 1,
                            ),
                            // The pill is the field; no outline, even
                            // while typing.
                            border: noBorder,
                            enabledBorder: noBorder,
                            disabledBorder: noBorder,
                            focusedBorder: noBorder,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      key: postKey,
                      tooltip: l10n.commentsPost,
                      onPressed: canPost && !sending ? onPost : null,
                      style: IconButton.styleFrom(
                        backgroundColor: p.primary,
                        disabledBackgroundColor: p.primary.withValues(
                          alpha: 0.35,
                        ),
                        fixedSize: const Size.square(
                          KCommentsSheet.composerButton,
                        ),
                        minimumSize: const Size.square(
                          KCommentsSheet.composerButton,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      icon: sending
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(p.onPrimary),
                              ),
                            )
                          // The paper plane points along the reading
                          // direction.
                          : Transform.flip(
                              flipX: ar,
                              child: AppIcon(
                                AppIcons.send,
                                size: KCommentsSheet.composerIcon,
                                color: p.onPrimary,
                              ),
                            ),
                    ),
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

/// [text] with every `@username` wrapped in a left-to-right isolate, so a
/// Latin handle keeps its `@` in front inside Arabic text (display only;
/// what is sent stays as typed). D158: a handle of one of the [mentions]
/// that is a premium username shows without «@».
String isolateHandles(String text, {List<UserSummary> mentions = const []}) {
  final premium = {
    for (final m in mentions)
      if (m.premiumTier != null) m.username.toLowerCase(),
  };
  return text.replaceAllMapped(_handle, (m) {
    final handle = m.group(0)!;
    // A username ends before a trailing dot (end of a sentence).
    final name = handle.substring(1).replaceFirst(_trailingDots, '');
    if (!premium.contains(name.toLowerCase())) return '\u2066$handle\u2069';
    return '\u2066$name\u2069${handle.substring(1 + name.length)}';
  });
}

final RegExp _trailingDots = RegExp(r'\.+$');

final RegExp _handle = RegExp(r'(?<![\p{L}\p{N}_])@[a-z0-9._]+', unicode: true);

/// D372 «هدية الدعم»: a gift line's body — «فلان أرسل الهدية ×N» in
/// gold with the gift's picture, on a soft gold pill. Readable in light and
/// dark (a deeper gold on light surfaces).
class CommentGiftLine extends StatelessWidget {
  const new({required this.sender, required this.gift, super.key});

  /// The sender's name as the row shows it.
  final String sender;
  final CommentGift gift;

  static const lineKey = Key('comments.giftLine');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // #F5C451 on dark; a deeper gold (≥ 4.5:1 on white) on light.
    final ink = dark ? KBrandColors.gold : const Color(0xFF8A5A00);
    final text = l10n.commentsGiftSent(
      KFormat.bidiIsolate(sender),
      KFormat.bidiIsolate(gift.name),
      // «×10» stays in that order inside Arabic text.
      KFormat.bidiIsolate('×${KFormat.grouped(gift.quantity)}'),
    );
    return Semantics(
      key: lineKey,
      container: true,
      label: text,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              KBrandColors.gold.withValues(alpha: dark ? 0.22 : 0.20),
              KBrandColors.gold.withValues(alpha: dark ? 0.08 : 0.06),
            ],
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
          ),
          borderRadius: BorderRadius.circular(KRadius.pill),
          border: Border.all(
            color: KBrandColors.gold.withValues(alpha: dark ? 0.55 : 0.7),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            KSpacing.md,
            KSpacing.xxs,
            KSpacing.xs,
            KSpacing.xxs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.body.copyWith(
                    fontSize: KCommentsSheet.bodySize,
                    height: KCommentsSheet.bodyHeight,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
              ),
              const SizedBox(width: KSpacing.xs),
              KGiftImage(
                gift.assetKey,
                imageUrl: gift.imageUrl,
                size: KCommentsSheet.giftArt,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The post a comments sheet belongs to.
@immutable
class CommentsTarget {
  const new({
    required this.postId,
    required this.commentCount,
    required this.authorId,
    required this.isSelf,
    required this.commentsOpen,
    this.giftTo,
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

  /// D372: the author to send a gift to «هدية الدعم» (`Post.giftable`);
  /// null hides the composer's gift button.
  final UserSummary? giftTo;
}

/// Opens the comments of [target]; [onCount] hears the post's comment count
/// whenever it changes here, [onGiftCherries] the post's gift cherries after
/// a gift sent here (D372).
Future<void> showCommentsSheet(
  BuildContext context,
  CommentsTarget target, {
  ValueChanged<int>? onCount,
  ValueChanged<int>? onGiftCherries,
}) => showModalBottomSheet<void>(
  context: context,
  // Above the bottom bar, like every full sheet.
  useRootNavigator: true,
  isScrollControlled: true,
  barrierColor: KCommentsSheet.barrier,
  backgroundColor: const Color(0x00000000),
  builder: (_) => CommentsSheet(
    target: target,
    onCount: onCount,
    onGiftCherries: onGiftCherries,
  ),
);

/// The comments of a post on the comments API (CONVENTIONS §11.5): the
/// pinned comment, then by likes, then newest, paged as the list scrolls;
/// replies (one level) open under their comment. Like, reply, and through
/// "⋯": pin (the post's author), delete (the comment's or the post's
/// author) and report (others). The bar posts a comment or, after Reply,
/// a reply; a Kabi emoji posts at once as its own comment (D66). With
/// comments closed the bar says so.
class CommentsSheet extends ConsumerStatefulWidget {
  const new({
    required this.target,
    this.onCount,
    this.onGiftCherries,
    super.key,
  });

  final CommentsTarget target;
  final ValueChanged<int>? onCount;

  /// D372: the post's gift cherries after a gift sent from this sheet.
  final ValueChanged<int>? onGiftCherries;

  static const sheetKey = Key('comments.sheet');
  static const listKey = Key('comments.list');
  static const inputKey = Key('comments.input');
  static const postKey = Key('comments.post');
  static const emojiKey = Key('comments.emoji');

  /// D372: the composer's gift box button.
  static const giftKey = Key('comments.gift');
  static const closeKey = Key('comments.close');
  static const retryKey = Key('comments.retry');
  static const closedKey = Key('comments.closed');
  static const cancelReplyKey = Key('comments.reply.cancel');
  static const deleteConfirmKey = Key('comments.delete.confirm');
  static Key commentKey(String id) => Key('comments.item.$id');
  static Key likeKey(String id) => Key('comments.item.$id.like');
  static Key dislikeKey(String id) => Key('comments.item.$id.dislike');
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

  /// The order chosen in this sheet (D364); the list reloads on a change.
  CommentSort _sort = CommentSort.relevant;
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

  /// D372 «هدية الدعم»: the live gift panel in its content mode; a send
  /// adds the gold line to the list and tells the post its gift cherries.
  Future<void> _openGift(UserSummary author) async {
    final repo = ref.read(postsRepositoryProvider);
    final comments = _comments;
    await KLiveGiftSheet.show(
      context,
      room: LiveGiftRoom.content(
        author: author,
        send:
            ({
              required giftCode,
              required quantity,
              required source,
              required clientId,
            }) async {
              final result = await repo.sendContentGift(
                _postId,
                giftCode: giftCode,
                quantity: quantity,
                source: source == LiveGiftSource.bag ? 'BAG' : 'COINS',
                clientId: clientId,
              );
              comments.addGiftLine(result.comment);
              widget.onGiftCherries?.call(result.giftCherries);
              return (
                coins: result.coins,
                bagQuantity: result.bagQuantity,
                lucky: null,
              );
            },
      ),
    );
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
    final reply = _replyTo;
    return CommentsSheetFrame(
      sheetKey: CommentsSheet.sheetKey,
      closeKey: CommentsSheet.closeKey,
      title: l10n.commentsSheetTitle(total),
      sort: _sort,
      onSort: (sort) {
        setState(() => _sort = sort);
        unawaited(_comments.setSort(sort));
      },
      body: switch (comments) {
        AsyncData(:final value) => _List(
          state: value,
          target: widget.target,
          onLike: (c) => _guard(() => _comments.toggleLike(c)),
          onDislike: (c) => _guard(() => _comments.toggleDislike(c)),
          onReply: widget.target.commentsOpen ? _reply : null,
          onMore: _more,
          onReplies: (c) => _guard(() => _comments.toggleReplies(c.id)),
          onMoreReplies: (c) => _guard(() => _comments.moreReplies(c.id)),
          onLoadMore: () => _guard(_comments.loadMore),
        ),
        AsyncError() => _Message(
          title: l10n.commentsFailed,
          action: TextButton(
            key: CommentsSheet.retryKey,
            onPressed: () => unawaited(_comments.setSort(_sort, reload: true)),
            child: Text(l10n.actionRetry),
          ),
        ),
        _ => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(p.primary),
          ),
        ),
      },
      composer: widget.target.commentsOpen
          ? CommentComposer(
              controller: _controller,
              focusNode: _focus,
              inputKey: CommentsSheet.inputKey,
              postKey: CommentsSheet.postKey,
              emojiKey: CommentsSheet.emojiKey,
              cancelReplyKey: CommentsSheet.cancelReplyKey,
              maxLength: maxCommentText,
              sending: _sending,
              canPost: _controller.text.trim().isNotEmpty,
              replyingTo: reply == null
                  ? null
                  : reply.author.displayName.isEmpty
                  ? reply.author.username
                  : reply.author.displayName,
              onCancelReply: () => setState(() => _replyTo = null),
              onPost: _send,
              // D66: a Kabi emoji posts at once, as its own comment.
              onEmoji: (e) => _send(e.token),
              giftKey: CommentsSheet.giftKey,
              onGift: switch (widget.target.giftTo) {
                final author? => () => unawaited(_openGift(author)),
                null => null,
              },
            )
          : _ClosedBar(message: l10n.commentsClosed),
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
    required this.onDislike,
    required this.onReply,
    required this.onMore,
    required this.onReplies,
    required this.onMoreReplies,
    required this.onLoadMore,
  });

  final CommentsState state;
  final CommentsTarget target;
  final ValueChanged<Comment> onLike;
  final ValueChanged<Comment> onDislike;
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
      onDislike: () => onDislike(c),
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
    required this.onDislike,
    required this.onReply,
    required this.onMore,
    super.key,
  });

  final Comment comment;
  final bool creator;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback? onReply;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = comment;
    final name = c.author.displayName.isEmpty
        ? c.author.username
        : c.author.displayName;
    final when =
        KFormat.relative(
          c.createdAt,
          clock.now(),
          l10n,
          Localizations.localeOf(context).toLanguageTag(),
        ) ??
        l10n.feedPostJustNow;
    final gift = c.gift;
    return CommentRow(
      name: name,
      avatarUrl: c.author.avatarUrl,
      statusEmojiId: c.author.statusEmojiId,
      text: isolateHandles(c.text, mentions: c.mentions),
      // D372: a gift line «فلان أرسل … ×N».
      gift: gift == null ? null : CommentGiftLine(sender: name, gift: gift),
      when: when,
      likeCount: c.likeCount,
      liked: c.viewerHasLiked,
      // D293: the author's verification seal after the name.
      seal: shownVerification(c.author.verification) == null
          ? null
          : VerificationSeal(
              c.author.verification,
              fontSize: KCommentsSheet.nameSize,
              gap: 0,
            ),
      creator: creator,
      pinned: c.pinned,
      onLike: onLike,
      disliked: c.viewerHasDisliked,
      onDislike: onDislike,
      onReply: onReply,
      onMore: onMore,
      likeKey: CommentsSheet.likeKey(c.id),
      dislikeKey: CommentsSheet.dislikeKey(c.id),
      replyKey: CommentsSheet.replyKey(c.id),
      moreKey: CommentsSheet.moreKey(c.id),
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
    // The composer's pill, holding the reason instead of a field.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: KCommentsSheet.composerBottom),
      child: Container(
        key: CommentsSheet.closedKey,
        margin: const EdgeInsets.fromLTRB(
          KCommentsSheet.composerInset,
          KSpacing.xs,
          KCommentsSheet.composerInset,
          0,
        ),
        decoration: BoxDecoration(
          color: p.surfaceOverlay,
          borderRadius: BorderRadius.circular(KCommentsSheet.composerRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.lg,
            vertical: KSpacing.md,
          ),
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
