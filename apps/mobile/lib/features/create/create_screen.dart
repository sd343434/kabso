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
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Create (the centre button of the bottom bar, D52/D86): a photo or text
/// post on the posts API (v1.5-social, CP-006 M1). Short videos arrive with
/// M2.
///
/// - The caption (≤ 2 200 characters; `#tags` and `@mentions` are linked by
///   the server), up to 10 photos from the library (checked on the device:
///   JPEG, PNG or WebP by their bytes, ≤ 15 MB) and an optional place.
/// - "Share" uploads the photos one by one (progress "n of m"), then creates
///   the post. A failure keeps the draft and says why, with Retry; a retry
///   does not upload the same photos again and never makes two posts.
/// - On success the draft clears and Posts opens; a post with photos waits
///   for review and the message says so (CP-006 Q2).
class CreateScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const textKey = Key('create.text');
  static const locationKey = Key('create.location');
  static const addPhotosKey = Key('create.addPhotos');
  static const shareKey = Key('create.share');
  static const progressKey = Key('create.progress');
  static const failureKey = Key('create.failure');
  static const retryKey = Key('create.retry');
  static Key photoKey(int localId) => Key('create.photo.$localId');
  static Key removePhotoKey(int localId) => Key('create.photo.$localId.remove');

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  final _text = TextEditingController();
  final _location = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _text
      ..removeListener(_changed)
      ..dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final l10n = context.l10n;
    final draft = ref.read(composeControllerProvider);
    final room = maxPostPhotos - draft.photos.length;
    if (room <= 0) return;
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
        .publish(text: _text.text, location: _location.text);
    if (!mounted || post == null) return;
    _text.clear();
    _location.clear();
    KSnack.success(
      context,
      post.pendingModeration ? l10n.createPostedInReview : l10n.createPosted,
    );
    context.go(AppRoutes.reels);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final draft = ref.watch(composeControllerProvider);
    final user = ref.watch(currentUserProvider);
    final canShare =
        !draft.busy &&
        (_text.text.trim().isNotEmpty || draft.photos.isNotEmpty) &&
        _text.text.characters.length <= maxPostText;
    final count = _text.text.characters.length;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: KMetrics.topBarHeight,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: KSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          l10n.createTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.title.copyWith(color: p.textPrimary),
                        ),
                      ),
                    ),
                    KButton(
                      key: CreateScreen.shareKey,
                      label: l10n.createShare,
                      expand: false,
                      loading: draft.busy,
                      onPressed: canShare ? _share : null,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(KSpacing.md),
                children: [
                  if (draft.busy) _Progress(draft: draft),
                  if (draft.failure case final failure?)
                    _FailureBanner(
                      failure: failure,
                      onRetry: canShare ? _share : null,
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: KAvatar(
                          name: user?.displayName ?? '',
                          imageUrl: user?.avatarUrl,
                          size: KSizes.avatarSm,
                        ),
                      ),
                      const SizedBox(width: KSpacing.sm),
                      Expanded(
                        child: TextField(
                          key: CreateScreen.textKey,
                          controller: _text,
                          enabled: !draft.busy,
                          minLines: 4,
                          maxLines: 12,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          style: t.body.copyWith(color: p.textPrimary),
                          decoration: InputDecoration(
                            hintText: l10n.createTextHint,
                            border: InputBorder.none,
                            counterText: count > maxPostText - 200
                                ? '$count/$maxPostText'
                                : '',
                            counterStyle: t.caption.copyWith(
                              color: count > maxPostText
                                  ? p.error
                                  : p.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.md),
                  _Photos(onAdd: draft.busy ? null : _addPhotos),
                  const SizedBox(height: KSpacing.md),
                  TextField(
                    key: CreateScreen.locationKey,
                    controller: _location,
                    enabled: !draft.busy,
                    maxLength: maxLocationText,
                    style: t.body.copyWith(color: p.textPrimary),
                    decoration: InputDecoration(
                      hintText: l10n.createLocationHint,
                      counterText: '',
                      prefixIcon: AppIcon(
                        AppIcons.location,
                        size: KMetrics.iconMd,
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: KSpacing.md),
                  Text(
                    l10n.createPhotosReviewNote,
                    style: t.caption.copyWith(color: p.textTertiary),
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

class _Progress extends StatelessWidget {
  const new({required this.draft});

  final ComposeState draft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = draft.photos.length;
    final uploading = draft.phase == ComposePhase.uploading && total > 0;
    return Padding(
      key: CreateScreen.progressKey,
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            uploading
                ? l10n.createUploading(
                    draft.uploaded + 1 > total ? total : draft.uploaded + 1,
                    total,
                  )
                : l10n.createPublishing,
            style: context.textStyles.caption.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: KSpacing.xs),
          LinearProgressIndicator(
            value: uploading ? draft.uploaded / total : null,
            valueColor: AlwaysStoppedAnimation(context.palette.primary),
            backgroundColor: context.palette.surfaceRaised,
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

/// The draft's photos (96 dp squares, each with a remove button) and, while
/// there is room, the "Add photos" tile.
class _Photos extends ConsumerWidget {
  const new({required this.onAdd});

  final VoidCallback? onAdd;

  static const double _cell = 96;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final draft = ref.watch(composeControllerProvider);
    final photos = draft.photos;
    return SizedBox(
      height: _cell,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final (i, photo) in photos.indexed)
            Padding(
              key: CreateScreen.photoKey(photo.localId),
              padding: const EdgeInsetsDirectional.only(end: KSpacing.sm),
              child: Semantics(
                image: true,
                label: l10n.createPhotoLabel(i + 1, photos.length),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(KRadius.md),
                  child: SizedBox.square(
                    dimension: _cell,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          photo.bytes,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) =>
                              ColoredBox(color: p.surfaceRaised),
                        ),
                        // A 24 dp disc in the corner; the 48 dp target
                        // reaches past it into the photo.
                        PositionedDirectional(
                          top: 0,
                          end: 0,
                          child: Tooltip(
                            message: l10n.createRemovePhoto,
                            child: Semantics(
                              button: true,
                              enabled: !draft.busy,
                              label: l10n.createRemovePhoto,
                              excludeSemantics: true,
                              child: InkResponse(
                                key: CreateScreen.removePhotoKey(photo.localId),
                                radius: KSizes.minTouchTarget / 2,
                                onTap: draft.busy
                                    ? null
                                    : () => ref
                                          .read(
                                            composeControllerProvider.notifier,
                                          )
                                          .removePhoto(photo.localId),
                                child: SizedBox.square(
                                  dimension: KSizes.minTouchTarget,
                                  child: Align(
                                    alignment: AlignmentDirectional.topEnd,
                                    child: Container(
                                      margin: const EdgeInsets.all(KSpacing.xs),
                                      width: KSpacing.xl,
                                      height: KSpacing.xl,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: KStatusColors.onStatus
                                            .withValues(alpha: 0.65),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const AppIcon(
                                        AppIcons.close,
                                        size: KSpacing.md,
                                        color: Colors.white,
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
                ),
              ),
            ),
          if (photos.length < maxPostPhotos)
            Semantics(
              button: true,
              enabled: onAdd != null,
              label: l10n.createAddPhotos,
              onTap: onAdd,
              excludeSemantics: true,
              child: InkWell(
                key: CreateScreen.addPhotosKey,
                onTap: onAdd,
                borderRadius: BorderRadius.circular(KRadius.md),
                child: Container(
                  width: _cell,
                  height: _cell,
                  decoration: BoxDecoration(
                    color: p.surfaceRaised,
                    borderRadius: BorderRadius.circular(KRadius.md),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: onAdd == null ? p.textTertiary : p.textPrimary,
                      ),
                      const SizedBox(height: KSpacing.xs),
                      Text(
                        l10n.createAddPhotos,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.caption.copyWith(
                          color: p.textSecondary,
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
