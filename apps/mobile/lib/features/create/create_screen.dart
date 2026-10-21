import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/create/compose_widgets.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Create (the centre button of the bottom bar, D52/D86): a photo or text
/// post on the posts API (v1.5-social, CP-006 M1), laid out after the
/// owner's reference (KL-060):
///
/// - Header: Share (start), the sparkle, title and line, Close (end). Close
///   leaves Create, asking first when the draft is not empty.
/// - The photo strip scrolls sideways: the dashed "Add more" tile at the
///   start, then the photos in post order, each with its number, remove ×
///   and a drag handle that reorders them; dots under it follow the scroll.
/// - The caption box (≤ 2 200 characters; `#tags` and `@mentions` in the
///   brand colour, linked by the server) with emoji, mention and hashtag
///   buttons and a counter.
/// - Type chips: Photos (this screen) and Live (opens the live hub); short
///   clips and music have no API yet (M2) and say "soon".
/// - Option rows: place, who can see (the account's privacy), mention
///   people, hashtags of the caption, advanced (comments, like count).
/// - Share uploads the photos one by one (progress), then creates the post;
///   a failure keeps the draft with Retry and never makes two posts.
class CreateScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const textKey = Key('create.text');
  static const locationKey = Key('create.location');
  static const addPhotosKey = Key('create.addPhotos');
  static const shareKey = Key('create.share');
  static const closeKey = Key('create.close');
  static const progressKey = Key('create.progress');
  static const failureKey = Key('create.failure');
  static const retryKey = Key('create.retry');
  static const counterKey = Key('create.counter');
  static const emojiKey = Key('create.tool.emoji');
  static const mentionToolKey = Key('create.tool.mention');
  static const hashtagToolKey = Key('create.tool.hashtag');
  static const audienceKey = Key('create.audience');
  static const mentionRowKey = Key('create.mentionRow');
  static const hashtagsRowKey = Key('create.hashtagsRow');
  static const advancedKey = Key('create.advanced');
  static const liveChipKey = Key('create.type.live');
  static const stripKey = Key('create.strip');
  static Key photoKey(int localId) => Key('create.photo.$localId');
  static Key removePhotoKey(int localId) => Key('create.photo.$localId.remove');
  static Key handleKey(int localId) => Key('create.photo.$localId.handle');

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _text = CaptionController();
  final _focus = FocusNode();
  final _strip = ScrollController();
  String _place = '';
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
    _strip.addListener(_scrolled);
  }

  void _changed() => setState(() {});

  void _scrolled() {
    const step = KCompose.photoWidth + KCompose.stripGap;
    final page = (_strip.offset / step).round();
    if (page != _page) setState(() => _page = page);
  }

  @override
  void dispose() {
    _text
      ..removeListener(_changed)
      ..dispose();
    _focus.dispose();
    _strip
      ..removeListener(_scrolled)
      ..dispose();
    super.dispose();
  }

  bool get _hasDraft =>
      _text.text.trim().isNotEmpty ||
      _place.isNotEmpty ||
      ref.read(composeControllerProvider).photos.isNotEmpty;

  Future<void> _addPhotos() async {
    final l10n = context.l10n;
    final draft = ref.read(composeControllerProvider);
    final room = maxPostPhotos - draft.photos.length;
    if (room <= 0) {
      KSnack.info(context, l10n.createPhotoTooMany(maxPostPhotos));
      return;
    }
    try {
      final picked = await ref.read(photoPickerProvider).pickPhotos(room);
      if (!mounted || picked.isEmpty) return;
      final rejected = ref
          .read(composeControllerProvider.notifier)
          .addPhotos(picked);
      if (!mounted) return;
      if (rejected.contains(PhotoRejection.unsupportedType)) {
        KSnack.error(context, l10n.createPhotoUnsupported);
      } else if (rejected.contains(PhotoRejection.tooLarge)) {
        KSnack.error(context, l10n.createPhotoTooLarge);
      } else if (rejected.contains(PhotoRejection.tooMany)) {
        KSnack.info(context, l10n.createPhotoTooMany(maxPostPhotos));
      }
    } on PlatformException {
      if (mounted) KSnack.error(context, l10n.createPhotoAccessDenied);
    }
  }

  Future<void> _share() async {
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    final post = await ref
        .read(composeControllerProvider.notifier)
        .publish(text: _text.text, location: _place);
    if (!mounted || post == null) return;
    _text.clear();
    setState(() => _place = '');
    KSnack.success(
      context,
      post.pendingModeration ? l10n.createPostedInReview : l10n.createPosted,
    );
    context.go(AppRoutes.reels);
  }

  Future<void> _close() async {
    final l10n = context.l10n;
    if (_hasDraft) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l10n.createDiscardTitle),
          content: Text(l10n.createDiscardBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(l10n.createKeepEditing),
            ),
            TextButton(
              key: const Key('create.discard'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l10n.createDiscard),
            ),
          ],
        ),
      );
      if (!(discard ?? false) || !mounted) return;
      ref.invalidate(composeControllerProvider);
      _text.clear();
      setState(() => _place = '');
    }
    if (mounted) context.go(AppRoutes.reels);
  }

  Future<void> _insertEmoji() async {
    final emoji = await showCaptionEmojiSheet(context);
    if (emoji != null) _text.insertAtCursor(emoji);
  }

  Future<void> _mention() async {
    final user = await showMentionSheet(context);
    if (user != null) _text.insertAtCursor('@${user.username} ');
  }

  void _hashtag() {
    _text.insertAtCursor('#');
    _focus.requestFocus();
  }

  Future<void> _editPlace() async {
    final place = await showPlaceSheet(context, _place);
    if (place != null && mounted) setState(() => _place = place);
  }

  Future<void> _advanced() async {
    final next = await showAdvancedSheet(
      context,
      ref.read(composeControllerProvider).settings,
    );
    if (next != null) {
      ref.read(composeControllerProvider.notifier).setSettings(next);
    }
  }

  Future<void> _audience() async {
    final l10n = context.l10n;
    final private = ref.read(currentUserProvider)?.isPrivate ?? false;
    final open = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                private
                    ? l10n.createAudiencePrivate
                    : l10n.createAudiencePublic,
                style: sheet.textStyles.bodyStrong,
              ),
              const SizedBox(height: KSpacing.xs),
              Text(l10n.createAudienceExplain, style: sheet.textStyles.body),
              const SizedBox(height: KSpacing.md),
              KButton(
                label: l10n.createAudienceSettings,
                variant: KButtonVariant.secondary,
                onPressed: () => Navigator.of(sheet).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if ((open ?? false) && mounted) unawaited(context.push(AppRoutes.settings));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    _text.entityColor = p.primary;
    final draft = ref.watch(composeControllerProvider);
    final private = ref.watch(currentUserProvider)?.isPrivate ?? false;
    final count = _text.text.characters.length;
    final canShare =
        !draft.busy &&
        (_text.text.trim().isNotEmpty || draft.photos.isNotEmpty) &&
        count <= maxPostText;
    final tags = _text.hashtags;
    final hasMention = CaptionController.entityPattern
        .allMatches(_text.text)
        .any((m) => m.group(0)!.startsWith('@'));
    return Scaffold(
      backgroundColor: p.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              canShare: canShare,
              busy: draft.busy,
              onShare: _share,
              onClose: draft.busy ? null : _close,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: KSpacing.lg),
                children: [
                  if (draft.busy)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KCompose.inset,
                      ),
                      child: _Progress(draft: draft),
                    ),
                  if (draft.failure case final failure?)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: KCompose.inset,
                      ),
                      child: _FailureBanner(
                        failure: failure,
                        onRetry: canShare ? _share : null,
                      ),
                    ),
                  _PhotoStrip(
                    controller: _strip,
                    onAdd: draft.busy ? null : _addPhotos,
                  ),
                  _Dots(count: draft.photos.length + 1, active: _page),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KCompose.inset,
                    ),
                    child: _CaptionBox(
                      controller: _text,
                      focus: _focus,
                      enabled: !draft.busy,
                      count: count,
                      onEmoji: _insertEmoji,
                      onMention: _mention,
                      onHashtag: _hashtag,
                    ),
                  ),
                  const SizedBox(height: KSpacing.md),
                  // The four types share the width (they always fit).
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KCompose.inset,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: ComposeTypeChip(
                            icon: const Icon(Icons.image_outlined),
                            label: l10n.createTypePhotos,
                            selected: true,
                            onTap: null,
                          ),
                        ),
                        const SizedBox(width: KSpacing.sm),
                        Expanded(
                          child: ComposeTypeChip(
                            key: CreateScreen.liveChipKey,
                            icon: const AppIcon(AppIcons.liveTv),
                            label: l10n.createTypeLive,
                            selected: false,
                            onTap: () => context.go(AppRoutes.home),
                          ),
                        ),
                        const SizedBox(width: KSpacing.sm),
                        Expanded(
                          child: ComposeTypeChip(
                            icon: const Icon(Icons.smart_display_outlined),
                            label: l10n.createTypeClip,
                            selected: false,
                            onTap: null,
                            semanticsHint: l10n.createSoon,
                          ),
                        ),
                        const SizedBox(width: KSpacing.sm),
                        Expanded(
                          child: ComposeTypeChip(
                            icon: const AppIcon(AppIcons.musicNote),
                            label: l10n.createTypeMusic,
                            selected: false,
                            onTap: null,
                            semanticsHint: l10n.createSoon,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KSpacing.md),
                  for (final row in [
                    ComposeOptionRow(
                      key: CreateScreen.locationKey,
                      icon: const AppIcon(AppIcons.location),
                      title: _place.isEmpty ? l10n.createPlaceTitle : _place,
                      subtitle: l10n.createPlaceSubtitle,
                      trailing: _place.isEmpty
                          ? null
                          : IconButton(
                              key: const Key('create.place.clear'),
                              tooltip: l10n.createPlaceClear,
                              onPressed: draft.busy
                                  ? null
                                  : () => setState(() => _place = ''),
                              icon: Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: p.surfaceOverlay,
                                  shape: BoxShape.circle,
                                ),
                                child: AppIcon(
                                  AppIcons.close,
                                  size: 12,
                                  color: p.textSecondary,
                                ),
                              ),
                            ),
                      onTap: draft.busy ? null : _editPlace,
                    ),
                    ComposeOptionRow(
                      key: CreateScreen.audienceKey,
                      icon: const Icon(Icons.groups_rounded),
                      title: l10n.createAudienceTitle,
                      subtitle: private
                          ? l10n.createAudiencePrivate
                          : l10n.createAudiencePublic,
                      onTap: _audience,
                    ),
                    ComposeOptionRow(
                      key: CreateScreen.mentionRowKey,
                      icon: const Icon(Icons.alternate_email_rounded),
                      title: l10n.createMentionTitle,
                      subtitle: hasMention
                          ? l10n.createMentionSome
                          : l10n.createMentionSubtitle,
                      onTap: draft.busy ? null : _mention,
                    ),
                    ComposeOptionRow(
                      key: CreateScreen.hashtagsRowKey,
                      icon: Text(
                        '#',
                        style: t.title.copyWith(
                          color: p.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      title: l10n.createHashtagsTitle,
                      body: Wrap(
                        spacing: KSpacing.xs,
                        runSpacing: KSpacing.xs,
                        children: [
                          for (final tag in tags.take(6))
                            _TagPill(label: '#$tag'),
                          _TagPill(
                            key: const Key('create.hashtags.add'),
                            label: '+',
                            accent: true,
                            onTap: draft.busy ? null : _hashtag,
                          ),
                        ],
                      ),
                      onTap: draft.busy ? null : _hashtag,
                    ),
                    ComposeOptionRow(
                      key: CreateScreen.advancedKey,
                      icon: const AppIcon(AppIcons.settings),
                      title: l10n.createAdvancedTitle,
                      subtitle: l10n.createAdvancedSubtitle,
                      onTap: draft.busy ? null : _advanced,
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        KCompose.inset,
                        0,
                        KCompose.inset,
                        KCompose.rowGap,
                      ),
                      child: row,
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

class _Header extends StatelessWidget {
  const new({
    required this.canShare,
    required this.busy,
    required this.onShare,
    required this.onClose,
  });

  final bool canShare;
  final bool busy;
  final VoidCallback onShare;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        KCompose.inset,
        KSpacing.sm,
        KCompose.inset,
        KSpacing.sm,
      ),
      child: Row(
        children: [
          // Share: a filled pill with the send glyph.
          Semantics(
            button: true,
            enabled: canShare,
            label: l10n.createShare,
            onTap: canShare ? onShare : null,
            excludeSemantics: true,
            child: Material(
              key: CreateScreen.shareKey,
              color: canShare || busy
                  ? p.primary
                  : p.primary.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(KRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(KRadius.md),
                onTap: canShare ? onShare : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: KSizes.minTouchTarget - 8,
                    minWidth: 64,
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: KSpacing.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (busy)
                          SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: p.onPrimary,
                            ),
                          )
                        else
                          Transform.flip(
                            flipX:
                                Directionality.of(context) == TextDirection.rtl,
                            child: AppIcon(
                              AppIcons.send,
                              size: 18,
                              color: p.onPrimary,
                            ),
                          ),
                        const SizedBox(width: KSpacing.xs),
                        Text(
                          l10n.createShare,
                          style: t.label.copyWith(color: p.onPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          const ComposeIconDisc(
            size: KCompose.sparkle + 8,
            child: Icon(Icons.auto_awesome),
          ),
          const SizedBox(width: KSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.createTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.title.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  l10n.createSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: p.textTertiary),
                ),
              ],
            ),
          ),
          IconButton(
            key: CreateScreen.closeKey,
            tooltip: l10n.createClose,
            onPressed: onClose,
            constraints: const BoxConstraints.tightFor(
              width: KCompose.headerButton + 4,
              height: KCompose.headerButton + 4,
            ),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: p.surfaceOverlay,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KRadius.md),
              ),
            ),
            icon: AppIcon(
              AppIcons.close,
              size: KMetrics.iconMd,
              color: p.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The photo strip: scrolls sideways; "Add more" at the start, then the
/// photos (drag the handle to reorder).
class _PhotoStrip extends ConsumerWidget {
  const new({required this.controller, required this.onAdd});

  final ScrollController controller;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final draft = ref.watch(composeControllerProvider);
    final photos = draft.photos;
    return SizedBox(
      key: CreateScreen.stripKey,
      height: KCompose.stripHeight,
      child: ReorderableListView.builder(
        scrollController: controller,
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        // No `padding`: ReorderableListView hands it to the header and the
        // list as if the strip were LTR. The header and footer carry the
        // insets instead, so both directions match.
        footer: const SizedBox(width: KCompose.inset - KCompose.stripGap),
        onReorderItem: (from, to) =>
            ref.read(composeControllerProvider.notifier).movePhoto(from, to),
        header: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: KCompose.inset,
            end: KCompose.stripGap,
          ),
          child: Semantics(
            button: true,
            enabled: onAdd != null,
            label: l10n.createAddPhotos,
            onTap: onAdd,
            excludeSemantics: true,
            child: InkWell(
              key: CreateScreen.addPhotosKey,
              onTap: onAdd,
              borderRadius: BorderRadius.circular(KCompose.cardRadius),
              child: CustomPaint(
                painter: DashedBorderPainter(
                  color: p.primary.withValues(alpha: 0.4),
                  radius: KCompose.cardRadius,
                ),
                child: Container(
                  width: KCompose.addWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(KCompose.cardRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        p.primary.withValues(alpha: 0.05),
                        p.primary.withValues(alpha: 0.10),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(KSpacing.xs),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: p.primary, size: 28),
                      const SizedBox(height: KSpacing.xs),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.createAddMore,
                          maxLines: 1,
                          style: context.textStyles.label.copyWith(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        l10n.createUpTo(maxPostPhotos),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: context.textStyles.caption.copyWith(
                          color: p.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        itemCount: photos.length,
        itemBuilder: (context, i) {
          final photo = photos[i];
          return Padding(
            key: CreateScreen.photoKey(photo.localId),
            padding: const EdgeInsetsDirectional.only(end: KCompose.stripGap),
            child: Semantics(
              image: true,
              label: l10n.createPhotoLabel(i + 1, photos.length),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KCompose.cardRadius),
                child: SizedBox(
                  width: KCompose.photoWidth,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        photo.bytes,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: p.surfaceOverlay),
                      ),
                      PositionedDirectional(
                        top: KSpacing.xs,
                        start: KSpacing.xs,
                        child: _Badge(
                          child: Text(l10n.createPhotoNumber(i + 1)),
                        ),
                      ),
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: _RemoveButton(
                          key: CreateScreen.removePhotoKey(photo.localId),
                          onTap: draft.busy
                              ? null
                              : () => ref
                                    .read(composeControllerProvider.notifier)
                                    .removePhoto(photo.localId),
                        ),
                      ),
                      if (photos.length > 1)
                        PositionedDirectional(
                          bottom: 0,
                          start: 0,
                          end: 0,
                          child: ReorderableDragStartListener(
                            key: CreateScreen.handleKey(photo.localId),
                            index: i,
                            enabled: !draft.busy,
                            child: Semantics(
                              label: l10n.createReorder,
                              child: Container(
                                height: 28,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x00000000),
                                      Color(0x66000000),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.drag_handle_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: KCompose.badge,
    height: KCompose.badge,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: KStatusColors.onStatus.withValues(alpha: 0.72),
      shape: BoxShape.circle,
    ),
    child: DefaultTextStyle.merge(
      style: context.textStyles.caption.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
      child: child,
    ),
  );
}

/// × in a 20 dp disc inside a 40 dp target, in the photo's top corner.
class _RemoveButton extends StatelessWidget {
  const new({required this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: context.l10n.createRemovePhoto,
    child: Semantics(
      button: true,
      enabled: onTap != null,
      label: context.l10n.createRemovePhoto,
      onTap: onTap,
      excludeSemantics: true,
      child: InkResponse(
        radius: 20,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 40,
          child: Align(
            alignment: AlignmentDirectional.topEnd,
            child: Container(
              margin: const EdgeInsets.all(KSpacing.xs),
              width: KCompose.badge,
              height: KCompose.badge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KStatusColors.onStatus.withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
              child: const AppIcon(
                AppIcons.close,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Dots extends StatelessWidget {
  const new({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (count < 2) return const SizedBox(height: KSpacing.lg);
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: KCompose.dot,
                height: KCompose.dot,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == active.clamp(0, count - 1) ? p.primary : p.border,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CaptionBox extends StatelessWidget {
  const new({
    required this.controller,
    required this.focus,
    required this.enabled,
    required this.count,
    required this.onEmoji,
    required this.onMention,
    required this.onHashtag,
  });

  final CaptionController controller;
  final FocusNode focus;
  final bool enabled;
  final int count;
  final VoidCallback onEmoji;
  final VoidCallback onMention;
  final VoidCallback onHashtag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final over = count > maxPostText;
    Widget tool(Key key, String tooltip, Widget glyph, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(start: KSpacing.xs),
          child: IconButton(
            key: key,
            tooltip: tooltip,
            onPressed: enabled ? onTap : null,
            constraints: const BoxConstraints.tightFor(
              width: KCompose.tool + 6,
              height: KCompose.tool + 6,
            ),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: p.surfaceOverlay,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(KRadius.sm),
              ),
            ),
            icon: glyph,
          ),
        );
    return Container(
      constraints: const BoxConstraints(minHeight: KCompose.captionMinHeight),
      padding: const EdgeInsetsDirectional.fromSTEB(
        KSpacing.md,
        KSpacing.sm,
        KSpacing.sm,
        KSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KCompose.cardRadius),
        border: Border.all(
          color: over ? p.error : p.primary.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: CreateScreen.textKey,
                  controller: controller,
                  focusNode: focus,
                  enabled: enabled,
                  minLines: 3,
                  maxLines: 10,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: t.body.copyWith(color: p.textPrimary),
                  decoration: InputDecoration(
                    hintText: l10n.createTextHint,
                    hintStyle: t.body.copyWith(color: p.textTertiary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: KSpacing.sm,
                    ),
                  ),
                ),
              ),
              tool(
                CreateScreen.hashtagToolKey,
                l10n.createAddHashtag,
                Text(
                  '#',
                  style: t.title.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onHashtag,
              ),
              tool(
                CreateScreen.mentionToolKey,
                l10n.createMentionTitle,
                Icon(Icons.alternate_email_rounded, color: p.textPrimary),
                onMention,
              ),
              tool(
                CreateScreen.emojiKey,
                l10n.createEmoji,
                AppIcon(AppIcons.emoji, color: p.textPrimary),
                onEmoji,
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.bottomEnd,
            child: Text(
              '$count/$maxPostText',
              key: CreateScreen.counterKey,
              textDirection: TextDirection.ltr,
              style: t.caption.copyWith(color: over ? p.error : p.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const new({required this.label, this.accent = false, this.onTap, super.key});

  final String label;
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: accent ? p.primary.withValues(alpha: 0.09) : p.surfaceOverlay,
      borderRadius: BorderRadius.circular(KRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(KRadius.pill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.md,
            vertical: KSpacing.xs,
          ),
          child: Text(
            label,
            style: context.textStyles.label.copyWith(
              color: accent ? p.primary : p.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const new({required this.draft});

  final ComposeState draft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = draft.photos.length;
    final uploading = draft.phase == ComposePhase.uploading && total > 0;
    final current = draft.uploaded + 1 > total ? total : draft.uploaded + 1;
    return Padding(
      key: CreateScreen.progressKey,
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            uploading
                ? l10n.createUploading(current, total)
                : l10n.createPublishing,
            style: context.textStyles.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: KSpacing.xs),
          LinearProgressIndicator(
            value: uploading ? draft.uploaded / total : null,
            valueColor: AlwaysStoppedAnimation(context.palette.primary),
            backgroundColor: context.palette.surfaceOverlay,
          ),
        ],
      ),
    );
  }
}

class _FailureBanner extends StatelessWidget {
  const new({required this.failure, required this.onRetry});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final message = switch (failure) {
      ServerFailure(code: ErrorCode.mediaUploadsUnavailable) =>
        l10n.createUploadsUnavailable,
      ServerFailure(code: ErrorCode.mediaInvalid) => l10n.createPhotoInvalid,
      _ => failureMessage(l10n, failure),
    };
    return Container(
      key: CreateScreen.failureKey,
      margin: const EdgeInsets.only(bottom: KSpacing.md),
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.md),
        border: Border.all(color: p.error),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: context.textStyles.body.copyWith(color: p.textPrimary),
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              key: CreateScreen.retryKey,
              onPressed: onRetry,
              child: Text(l10n.actionRetry),
            ),
        ],
      ),
    );
  }
}
