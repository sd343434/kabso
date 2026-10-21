import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/create/compose_widgets.dart';
import 'package:kabso_live/features/create/create_media_step.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/application/media_library_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Create (the centre button of the bottom bar, D52/D86): a photo or text
/// post on the posts API (v1.5-social, CP-006 M1) in two steps, laid out
/// after the owner's references (KL-060). Full screen: the shell hides the
/// bottom bar here.
///
/// 1. Media ([CreateMediaStep]): pick up to 10 photos from the device
///    library (or the system picker), then Next. Close leaves Create,
///    asking first when the draft is not empty.
/// 2. Details: Share (start), title, Back (end) to the media step; the
///    step indicator; the photos in post order (long-press and drag to
///    reorder, × removes, "Add more" goes back to the media step); the
///    caption box (≤ 2 200 characters, `#tags` and `@mentions` in the brand
///    colour, linked by the server) with AI ("soon", no API), hashtag,
///    mention and emoji tools and a counter; then the rows: place (with the
///    places this account used last on this device), mention people,
///    hashtags, who can see (the account's privacy), when to publish (now,
///    or scheduled 5 minutes to 30 days ahead), more options (comments,
///    like count).
///
/// Share (or Schedule) uploads the photos one by one (progress), then
/// creates the post; a failure keeps the draft with Retry and never makes
/// two posts. Close offers to save the post as a draft
/// (`status: DRAFT`), found later under Drafts on the profile.
class CreateScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const textKey = Key('create.text');
  static const locationKey = Key('create.location');
  static const addPhotosKey = Key('create.addPhotos');
  static const shareKey = Key('create.share');
  static const closeKey = Key('create.close');
  static const backKey = Key('create.back');
  static const progressKey = Key('create.progress');
  static const failureKey = Key('create.failure');
  static const retryKey = Key('create.retry');
  static const counterKey = Key('create.counter');
  static const emojiKey = Key('create.tool.emoji');
  static const mentionToolKey = Key('create.tool.mention');
  static const hashtagToolKey = Key('create.tool.hashtag');
  static const aiToolKey = Key('create.tool.ai');
  static const audienceKey = Key('create.audience');
  static const mentionRowKey = Key('create.mentionRow');
  static const hashtagsRowKey = Key('create.hashtagsRow');
  static const advancedKey = Key('create.advanced');
  static const scheduleKey = Key('create.schedule');
  static const clearScheduleKey = Key('create.schedule.clear');
  static const saveDraftKey = Key('create.saveDraft');
  static const stripKey = Key('create.strip');
  static const mediaStepKey = Key('create.step.media');
  static const detailsStepKey = Key('create.step.details');
  static Key photoKey(int localId) => Key('create.photo.$localId');
  static Key removePhotoKey(int localId) => Key('create.photo.$localId.remove');
  static Key handleKey(int localId) => Key('create.photo.$localId.handle');
  static Key placeChipKey(String place) => Key('create.place.chip.$place');

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _text = CaptionController();
  final _focus = FocusNode();
  final _strip = ScrollController();
  String _place = '';
  int _page = 0;
  bool _details = false;

  /// When to publish; `null`: now.
  DateTime? _publishAt;

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

  void _toDetails() => setState(() => _details = true);

  void _toMedia() {
    FocusScope.of(context).unfocus();
    setState(() => _details = false);
  }

  /// The system picker (no library on this platform, or no access to it).
  Future<void> _pickFromDevice() async {
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
    final place = _place;
    final at = _publishAt;
    if (at != null && !isSchedulable(at, clock.now())) {
      KSnack.error(context, l10n.createScheduleWindow);
      return;
    }
    final post = await ref
        .read(composeControllerProvider.notifier)
        .publish(
          text: _text.text,
          location: place,
          status: at == null ? 'PUBLISHED' : 'SCHEDULED',
          publishAt: at,
        );
    if (!mounted || post == null) return;
    unawaited(ref.read(recentPlacesProvider.notifier).remember(place));
    _reset();
    KSnack.success(
      context,
      at != null
          ? l10n.createScheduled(scheduleLabel(context, at))
          : post.pendingModeration
          ? l10n.createPostedInReview
          : l10n.createPosted,
    );
    context.go(AppRoutes.reels);
  }

  void _reset() {
    _text.clear();
    setState(() {
      _place = '';
      _publishAt = null;
      _details = false;
    });
  }

  /// Saves the post as a draft (`status: DRAFT`) and leaves Create.
  Future<void> _saveDraft() async {
    final l10n = context.l10n;
    final controller = ref.read(composeControllerProvider.notifier);
    final post = await controller.publish(
      text: _text.text,
      location: _place,
      status: 'DRAFT',
    );
    if (!mounted) return;
    if (post == null) {
      final failure = ref.read(composeControllerProvider).failure;
      if (failure != null) {
        KSnack.error(context, failureMessage(l10n, failure));
      }
      return;
    }
    _reset();
    KSnack.success(context, l10n.createDraftSaved);
    context.go(AppRoutes.reels);
  }

  Future<void> _schedule() async {
    final at = await pickScheduleTime(context, _publishAt);
    if (at != null && mounted) setState(() => _publishAt = at);
  }

  Future<void> _close() async {
    final l10n = context.l10n;
    if (_hasDraft) {
      // A draft needs text or a photo (§11.2).
      final canDraft =
          _text.text.trim().isNotEmpty ||
          ref.read(composeControllerProvider).photos.isNotEmpty;
      final choice = await showDialog<_CloseChoice>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l10n.createDiscardTitle),
          content: Text(
            canDraft ? l10n.createDiscardOrDraftBody : l10n.createDiscardBody,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(_CloseChoice.keep),
              child: Text(l10n.createKeepEditing),
            ),
            TextButton(
              key: const Key('create.discard'),
              onPressed: () => Navigator.of(dialog).pop(_CloseChoice.discard),
              child: Text(l10n.createDiscard),
            ),
            if (canDraft)
              TextButton(
                key: CreateScreen.saveDraftKey,
                onPressed: () => Navigator.of(dialog).pop(_CloseChoice.draft),
                child: Text(l10n.createSaveDraft),
              ),
          ],
        ),
      );
      if (!mounted) return;
      switch (choice) {
        case _CloseChoice.draft:
          await _saveDraft();
          return;
        case _CloseChoice.discard:
          ref.invalidate(composeControllerProvider);
          _reset();
        case _CloseChoice.keep || null:
          return;
      }
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
    final p = context.palette;
    return PopScope(
      // System back on the details step returns to the media step.
      canPop: !_details,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _details) _toMedia();
      },
      child: Scaffold(
        backgroundColor: p.surface,
        body: SafeArea(
          child: _details
              ? KeyedSubtree(
                  key: CreateScreen.detailsStepKey,
                  child: _buildDetails(context),
                )
              : CreateMediaStep(
                  key: CreateScreen.mediaStepKey,
                  onNext: _toDetails,
                  onClose: _close,
                  onPickFromDevice: _pickFromDevice,
                ),
        ),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    _text.entityColor = p.primary;
    final draft = ref.watch(composeControllerProvider);
    final private = ref.watch(currentUserProvider)?.isPrivate ?? false;
    final recent = ref.watch(recentPlacesProvider);
    final count = _text.text.characters.length;
    final canShare =
        !draft.busy &&
        (_text.text.trim().isNotEmpty || draft.photos.isNotEmpty) &&
        count <= maxPostText;
    final tags = _text.hashtags;
    final hasMention = CaptionController.entityPattern
        .allMatches(_text.text)
        .any((m) => m.group(0)!.startsWith('@'));
    final places = [
      if (_place.isNotEmpty) _place,
      ...recent.where((r) => r != _place),
    ];
    return Column(
      children: [
        ComposeHeader(
          action: ComposeActionPill(
            key: CreateScreen.shareKey,
            label: _publishAt == null
                ? l10n.createShare
                : l10n.createScheduleAction,
            glyph: Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: const AppIcon(AppIcons.send),
            ),
            enabled: canShare,
            busy: draft.busy,
            onTap: _share,
          ),
          subtitle: l10n.createSubtitle,
          endButton: ComposeRoundButton(
            key: CreateScreen.backKey,
            tooltip: l10n.createBack,
            raised: true,
            onPressed: draft.busy ? null : _toMedia,
            // Points to the end edge, where the button sits (mirrors).
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ),
        _Stepper(onMedia: draft.busy ? null : _toMedia),
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
                onAdd: draft.busy ? null : _toMedia,
              ),
              _StripFooter(photos: draft.photos.length, active: _page),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: KCompose.inset),
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
              for (final row in [
                ComposeOptionRow(
                  key: CreateScreen.locationKey,
                  icon: const AppIcon(AppIcons.location),
                  title: l10n.createPlaceTitle,
                  subtitle: _place.isEmpty ? l10n.createPlaceSubtitle : _place,
                  body: places.isEmpty
                      ? null
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final place in places)
                                Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: KSpacing.sm,
                                  ),
                                  child: _PlaceChip(
                                    key: CreateScreen.placeChipKey(place),
                                    label: place,
                                    selected: place == _place,
                                    onTap: draft.busy
                                        ? null
                                        : () => setState(
                                            () => _place = place == _place
                                                ? ''
                                                : place,
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                  onTap: draft.busy ? null : _editPlace,
                ),
                ComposeOptionRow(
                  key: CreateScreen.mentionRowKey,
                  icon: const Icon(Icons.person_rounded),
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
                  subtitle: tags.isEmpty ? l10n.createHashtagsExample : null,
                  body: tags.isEmpty
                      ? null
                      : Wrap(
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
                  key: CreateScreen.audienceKey,
                  icon: const Icon(Icons.lock_rounded),
                  title: l10n.createAudienceTitle,
                  subtitle: private
                      ? l10n.createAudiencePrivate
                      : l10n.createAudiencePublic,
                  onTap: _audience,
                ),
                ComposeOptionRow(
                  key: CreateScreen.scheduleKey,
                  icon: const Icon(Icons.schedule_rounded),
                  title: l10n.createScheduleTitle,
                  subtitle: switch (_publishAt) {
                    final at? => scheduleLabel(context, at),
                    null => l10n.createScheduleNow,
                  },
                  trailing: _publishAt == null
                      ? null
                      : IconButton(
                          key: CreateScreen.clearScheduleKey,
                          tooltip: l10n.createScheduleClear,
                          onPressed: draft.busy
                              ? null
                              : () => setState(() => _publishAt = null),
                          icon: AppIcon(
                            AppIcons.close,
                            size: KMetrics.iconSm,
                            color: p.textSecondary,
                          ),
                        ),
                  onTap: draft.busy ? null : _schedule,
                ),
                ComposeOptionRow(
                  key: CreateScreen.advancedKey,
                  icon: const AppIcon(AppIcons.settings),
                  neutralIcon: true,
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
                    KCompose.rowGap + 2,
                  ),
                  child: row,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _CloseChoice { keep, discard, draft }

/// 1 Media — 2 Details; the details step is current. Tapping Media goes
/// back to it.
class _Stepper extends StatelessWidget {
  const new({required this.onMedia});

  final VoidCallback? onMedia;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    Widget step(int n, String label, {required bool current}) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: KCompose.step,
          height: KCompose.step,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: current ? p.primary : p.primary.withValues(alpha: 0.1),
          ),
          child: Text(
            l10n.createPhotoNumber(n),
            style: t.caption.copyWith(
              color: current ? p.onPrimary : p.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: KSpacing.xs),
        Text(
          label,
          style: t.caption.copyWith(
            color: current ? p.primary : p.textTertiary,
            fontWeight: current ? FontWeight.w700 : null,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: l10n.createStepOf(1, 2, l10n.createStepMedia),
            onTap: onMedia,
            excludeSemantics: true,
            child: InkWell(
              onTap: onMedia,
              borderRadius: BorderRadius.circular(KRadius.md),
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.xs),
                child: step(1, l10n.createStepMedia, current: false),
              ),
            ),
          ),
          Container(
            width: 104,
            height: 2,
            margin: const EdgeInsets.only(top: KSpacing.xs + KCompose.step / 2),
            color: p.primary.withValues(alpha: 0.3),
          ),
          Semantics(
            selected: true,
            label: l10n.createStepOf(2, 2, l10n.createStepDetails),
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.xs),
              child: step(2, l10n.createStepDetails, current: true),
            ),
          ),
        ],
      ),
    );
  }
}

/// The photo strip: scrolls sideways; "Add more" at the start (back to the
/// media step), then the photos in post order. Long-press a photo and drag
/// to reorder.
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
                  color: p.primary.withValues(alpha: 0.35),
                  radius: KCompose.cardRadius,
                ),
                child: Container(
                  width: KCompose.addWidth,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(KCompose.cardRadius),
                    color: p.primary.withValues(alpha: 0.03),
                  ),
                  padding: const EdgeInsets.all(KSpacing.xs),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ComposeIconDisc(
                        size: 32,
                        child: Icon(Icons.add_rounded, color: p.primary),
                      ),
                      const SizedBox(height: KSpacing.sm),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.createAddMore,
                          maxLines: 1,
                          style: context.textStyles.caption.copyWith(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.createUpTo(maxPostPhotos),
                          maxLines: 1,
                          style: context.textStyles.caption.copyWith(
                            color: p.textTertiary,
                          ),
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
            child: ReorderableDelayedDragStartListener(
              key: CreateScreen.handleKey(photo.localId),
              index: i,
              enabled: !draft.busy && photos.length > 1,
              child: Semantics(
                image: true,
                label: l10n.createPhotoLabel(i + 1, photos.length),
                hint: photos.length > 1 ? l10n.createLongPressReorder : null,
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
                          bottom: KSpacing.xs + 2,
                          end: KSpacing.xs + 2,
                          child: _Badge(
                            child: Text(l10n.createPhotoNumber(i + 1)),
                          ),
                        ),
                        PositionedDirectional(
                          top: 0,
                          start: 0,
                          child: _RemoveButton(
                            key: CreateScreen.removePhotoKey(photo.localId),
                            onTap: draft.busy
                                ? null
                                : () => ref
                                      .read(composeControllerProvider.notifier)
                                      .removePhoto(photo.localId),
                          ),
                        ),
                      ],
                    ),
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
    width: KCompose.numberBadge,
    height: KCompose.numberBadge,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: KStatusColors.onStatus.withValues(alpha: 0.72),
      shape: BoxShape.circle,
    ),
    child: DefaultTextStyle.merge(
      style: context.textStyles.caption.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 11,
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
            alignment: AlignmentDirectional.topStart,
            child: Container(
              margin: const EdgeInsets.all(KSpacing.xs + 2),
              width: KCompose.badge,
              height: KCompose.badge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: KStatusColors.onStatus.withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
              child: const AppIcon(
                AppIcons.close,
                size: 11,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Under the strip: the reorder hint (two photos or more) at the start,
/// then the page dots (centred when there is no hint).
class _StripFooter extends StatelessWidget {
  const new({required this.photos, required this.active});

  final int photos;
  final int active;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final count = photos + 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KCompose.inset,
        KSpacing.sm,
        KCompose.inset,
        KSpacing.md,
      ),
      child: ExcludeSemantics(
        child: Row(
          children: [
            if (photos > 1)
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        context.l10n.createLongPressReorder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.caption.copyWith(
                          color: p.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: KSpacing.xs),
                    Icon(
                      Icons.drag_handle_rounded,
                      size: 18,
                      color: p.textTertiary,
                    ),
                    const SizedBox(width: KSpacing.md),
                  ],
                ),
              )
            else
              const Spacer(),
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
            if (photos <= 1) const Spacer(),
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
    Widget tool(
      Key key,
      String tooltip,
      Widget glyph,
      VoidCallback? onTap, {
      bool accent = false,
    }) => Padding(
      // The 32 dp square sits in a 48 dp tap target.
      padding: const EdgeInsetsDirectional.only(start: KSpacing.xs),
      child: IconButton(
        key: key,
        tooltip: tooltip,
        onPressed: enabled ? onTap : null,
        constraints: const BoxConstraints.tightFor(
          width: KCompose.tool,
          height: KCompose.tool,
        ),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: accent
              ? p.primary.withValues(alpha: 0.08)
              : p.surfaceOverlay,
          disabledBackgroundColor: accent
              ? p.primary.withValues(alpha: 0.06)
              : p.surfaceOverlay,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KRadius.sm + 2),
          ),
        ),
        icon: glyph,
      ),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: KCompose.captionMinHeight),
      padding: const EdgeInsetsDirectional.fromSTEB(
        KSpacing.lg,
        KSpacing.sm,
        KSpacing.md,
        KSpacing.md,
      ),
      decoration: composeCard(p, border: over ? p.error : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: CreateScreen.textKey,
            // Like dir="auto": a caption that starts with @handle or Latin
            // text reads left to right.
            textDirection: KFormat.firstStrongDirection(controller.text),
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
              contentPadding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
            ),
          ),
          const SizedBox(height: KSpacing.xs),
          Row(
            children: [
              Text(
                '$count/$maxPostText',
                key: CreateScreen.counterKey,
                maxLines: 1,
                textDirection: TextDirection.ltr,
                style: t.caption.copyWith(
                  color: over ? p.error : p.textTertiary,
                ),
              ),
              const Spacer(),
              // No caption-suggestion API yet: shown, but says "soon".
              Semantics(
                hint: l10n.createSoon,
                child: tool(
                  CreateScreen.aiToolKey,
                  '${l10n.createAiCaption} · ${l10n.createSoon}',
                  Icon(
                    Icons.auto_awesome,
                    color: p.primary.withValues(alpha: 0.5),
                    size: 20,
                  ),
                  null,
                  accent: true,
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
        ],
      ),
    );
  }
}

/// A place this account used before (or the current one, selected).
class _PlaceChip extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? p.primary : p.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.primary.withValues(alpha: 0.09) : p.surfaceOverlay,
        borderRadius: BorderRadius.circular(KRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(KRadius.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.xs + 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(AppIcons.location, size: 16, color: fg),
                const SizedBox(width: KSpacing.xs),
                Text(
                  label,
                  maxLines: 1,
                  style: context.textStyles.label.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
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
