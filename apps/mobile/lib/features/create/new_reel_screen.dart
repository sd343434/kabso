import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/media/inline_video.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/create/create_media_step.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/application/media_library_controller.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/media_library.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/data/video_source.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/reel/new` (owner, D162; v1.41-social, CONVENTIONS §11.14): one
/// vertical video (≤ 60 s, ≤ 100 MiB) from the device library — or the
/// system picker without one — with a caption (the post text rules), shared
/// as a reel for Moments. The video is checked on the device, its first
/// frame goes up as the poster, the file is streamed (with progress) as a
/// `REEL_VIDEO`, then the reel is created with an `Idempotency-Key` kept
/// for retries of the same content; a failure keeps everything with Retry.
class NewReelScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const pickKey = Key('newReel.pick');
  static const changeKey = Key('newReel.change');
  static const textKey = Key('newReel.text');
  static const shareKey = Key('newReel.share');
  static const closeKey = Key('newReel.close');
  static const previewKey = Key('newReel.preview');
  static const progressKey = Key('newReel.progress');
  static const failureKey = Key('newReel.failure');
  static const retryKey = Key('newReel.retry');
  static const sheetKey = Key('newReel.library');
  static Key libraryItemKey(String id) => Key('newReel.library.$id');

  @override
  ConsumerState<NewReelScreen> createState() => _NewReelScreenState();
}

class _NewReelScreenState extends ConsumerState<NewReelScreen> {
  final _text = TextEditingController();
  PickedVideo? _video;

  /// The uploaded video, kept for a retry while the video is unchanged.
  String? _assetId;
  late String _key;
  String? _keyFor;
  bool _busy = false;

  /// Reading the chosen video (the button shows progress).
  bool _picking = false;

  /// A choice is open (the sheet or the system picker).
  bool _choosing = false;
  double? _progress;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy || _picking || _choosing) return;
    final l10n = context.l10n;
    _choosing = true;
    try {
      final library = ref.read(mediaLibraryProvider);
      final access = await library.requestAccess();
      if (!mounted) return;
      PickedVideo? video;
      if (access.canBrowse) {
        final id = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          useSafeArea: true,
          builder: (_) => const _ReelLibrarySheet(),
        );
        if (id == null || !mounted) return;
        setState(() => _picking = true);
        video = await library.video(id);
        if (!mounted) return;
        if (video == null) {
          KSnack.error(context, l10n.createVideoUnreadable);
          return;
        }
      } else {
        video = await ref
            .read(videoPickerProvider)
            .pickVideo(maxDuration: maxReelVideoLength);
        if (!mounted || video == null) return;
      }
      if (checkVideo(video, reel: true) case final rejection?) {
        KSnack.error(
          context,
          videoRejectionMessage(l10n, rejection, reel: true),
        );
        return;
      }
      setState(() {
        _video = video;
        _assetId = null;
        _failure = null;
      });
    } on PlatformException {
      if (mounted) KSnack.error(context, l10n.createPhotoAccessDenied);
    } on Object {
      if (mounted) KSnack.error(context, l10n.createVideoUnreadable);
    } finally {
      _choosing = false;
      if (mounted && _picking) setState(() => _picking = false);
    }
  }

  bool get _valid => _text.text.trim().characters.length <= maxPostText;

  Future<void> _share() async {
    final video = _video;
    if (_busy || video == null || !_valid) return;
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _failure = null;
      _progress = _assetId == null ? 0 : null;
    });
    try {
      final assetId =
          _assetId ??
          (await ref
                  .read(mediaRepositoryProvider)
                  .uploadVideo(
                    video,
                    reel: true,
                    onProgress: (p) {
                      if (mounted) setState(() => _progress = p);
                    },
                  ))
              .id;
      _assetId = assetId;
      if (mounted) setState(() => _progress = null);
      final text = _text.text.trim();
      final content = '$assetId\u0000$text';
      if (_keyFor != content) {
        _key = newIdempotencyKey();
        _keyFor = content;
      }
      final post = await ref
          .read(postsRepositoryProvider)
          .createPost(
            idempotencyKey: _key,
            text: text,
            mediaIds: [assetId],
            reel: true,
          );
      if (!mounted) return;
      for (final feed in HomeFeed.values) {
        ref.invalidate(reelsFeedProvider(feed));
      }
      KSnack.success(
        context,
        post.pendingModeration ? l10n.reelSharedInReview : l10n.reelShared,
      );
      _close();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _failure = toAppFailure(e);
      });
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.reels);
    }
  }

  String _failureText(AppLocalizations l10n, AppFailure failure) =>
      switch (failure) {
        ServerFailure(code: ErrorCode.mediaUploadsUnavailable) =>
          l10n.createVideoUploadsUnavailable,
        ServerFailure(code: ErrorCode.mediaInvalid) => l10n.createVideoInvalid,
        _ => failureMessage(l10n, failure),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    const white = Color(0xFFFFFFFF);
    final video = _video;
    final count = _text.text.trim().characters.length;
    final progress = _progress;
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      resizeToAvoidBottomInset: true,
      body: KTopSafeArea(
        bottom: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video != null)
              Center(
                child: AspectRatio(
                  aspectRatio: video.aspect,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        video.poster,
                        key: NewReelScreen.previewKey,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        semanticLabel: l10n.reelPreview,
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: Color(0xFF15171C)),
                      ),
                      const IgnorePointer(
                        child: Center(child: VideoPlayMark()),
                      ),
                    ],
                  ),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(KSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.movie_creation_outlined,
                        size: 56,
                        color: white,
                      ),
                      const SizedBox(height: KSpacing.md),
                      Text(
                        l10n.reelNewTitle,
                        textAlign: TextAlign.center,
                        style: t.title.copyWith(color: white),
                      ),
                      const SizedBox(height: KSpacing.xs),
                      Text(
                        l10n.reelNewBody,
                        textAlign: TextAlign.center,
                        style: t.body.copyWith(color: const Color(0xCCFFFFFF)),
                      ),
                      const SizedBox(height: KSpacing.lg),
                      KButton(
                        key: NewReelScreen.pickKey,
                        label: l10n.reelPickVideo,
                        loading: _picking,
                        onPressed: _picking ? null : _pick,
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: KSpacing.xs,
              left: KSpacing.xs,
              right: KSpacing.xs,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: NewReelScreen.closeKey,
                        tooltip: l10n.createClose,
                        onPressed: _busy ? null : _close,
                        icon: const Icon(Icons.close_rounded, color: white),
                      ),
                      Expanded(
                        child: Text(
                          l10n.reelNewTitle,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(color: white),
                        ),
                      ),
                      if (video != null) ...[
                        IconButton(
                          key: NewReelScreen.changeKey,
                          tooltip: l10n.reelChangeVideo,
                          onPressed: _busy || _picking ? null : _pick,
                          icon: const Icon(
                            Icons.video_library_outlined,
                            color: white,
                          ),
                        ),
                        const SizedBox(width: KSpacing.xs),
                        FilledButton.icon(
                          key: NewReelScreen.shareKey,
                          onPressed: _busy || !_valid ? null : _share,
                          style: FilledButton.styleFrom(
                            backgroundColor: p.primary,
                            foregroundColor: p.onPrimary,
                          ),
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded, size: 18),
                          label: Text(l10n.reelShare),
                        ),
                      ] else
                        const SizedBox(width: KSizes.minTouchTarget),
                    ],
                  ),
                  if (_busy)
                    Padding(
                      key: NewReelScreen.progressKey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.sm,
                        vertical: KSpacing.xs,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              progress != null
                                  ? l10n.createUploadingVideo(
                                      (progress * 100).floor(),
                                    )
                                  : l10n.createPublishing,
                              style: t.caption.copyWith(color: white),
                            ),
                          ),
                          const SizedBox(height: KSpacing.xs),
                          LinearProgressIndicator(
                            value: progress,
                            valueColor: AlwaysStoppedAnimation(p.primary),
                            backgroundColor: const Color(0x33FFFFFF),
                          ),
                        ],
                      ),
                    ),
                  if (_failure case final failure?)
                    Container(
                      key: NewReelScreen.failureKey,
                      margin: const EdgeInsets.all(KSpacing.sm),
                      padding: const EdgeInsets.all(KSpacing.sm),
                      decoration: BoxDecoration(
                        color: const Color(0xCC000000),
                        borderRadius: BorderRadius.circular(KRadius.md),
                        border: Border.all(color: p.error),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                _failureText(l10n, failure),
                                style: t.body.copyWith(color: white),
                              ),
                            ),
                          ),
                          TextButton(
                            key: NewReelScreen.retryKey,
                            onPressed: _valid ? _share : null,
                            child: Text(l10n.actionRetry),
                          ),
                        ],
                      ),
                    ),
                  if (video != null && video.aspect > 1)
                    Padding(
                      padding: const EdgeInsets.all(KSpacing.sm),
                      child: Text(
                        l10n.reelVertical,
                        textAlign: TextAlign.center,
                        style: t.caption.copyWith(
                          color: const Color(0xCCFFFFFF),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (video != null)
              Positioned(
                left: KSpacing.md,
                right: KSpacing.md,
                bottom: KSpacing.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: KSpacing.sm),
                      padding: const EdgeInsets.symmetric(
                        horizontal: KSpacing.sm,
                        vertical: KSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        borderRadius: BorderRadius.circular(KRadius.pill),
                      ),
                      child: Text(
                        videoLengthLabel(video.duration),
                        textDirection: TextDirection.ltr,
                        style: t.caption.copyWith(color: white),
                      ),
                    ),
                    TextField(
                      key: NewReelScreen.textKey,
                      controller: _text,
                      enabled: !_busy,
                      minLines: 1,
                      maxLines: 4,
                      textDirection: KFormat.inputDirection(_text.text),
                      style: t.body.copyWith(color: white),
                      cursorColor: white,
                      decoration: InputDecoration(
                        hintText: l10n.reelCaptionHint,
                        hintStyle: t.body.copyWith(
                          color: const Color(0xB3FFFFFF),
                        ),
                        filled: true,
                        fillColor: const Color(0x99000000),
                        counterText: count > maxPostText - 200
                            ? '$count/$maxPostText'
                            : null,
                        counterStyle: t.caption.copyWith(
                          color: _valid ? white : p.error,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KRadius.md),
                          borderSide: BorderSide.none,
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

/// The device library's videos (newest first) to choose the reel's from;
/// pops the chosen id.
class _ReelLibrarySheet extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final library = ref.watch(
      mediaLibraryControllerProvider(LibraryFilter.videos),
    );
    return SizedBox(
      key: NewReelScreen.sheetKey,
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: switch (library) {
        AsyncData(:final value) when value.items.isEmpty => Center(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Text(
              l10n.createLibraryNoVideos,
              textAlign: TextAlign.center,
              style: context.textStyles.body.copyWith(color: p.textSecondary),
            ),
          ),
        ),
        AsyncData(:final value) => NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < 400) {
              unawaited(
                ref
                    .read(
                      mediaLibraryControllerProvider(LibraryFilter.videos)
                          .notifier,
                    )
                    .loadMore(),
              );
            }
            return false;
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(KSpacing.sm),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: KSpacing.xs,
              crossAxisSpacing: KSpacing.xs,
              childAspectRatio: 9 / 16,
            ),
            itemCount: value.items.length,
            itemBuilder: (context, i) {
              final item = value.items[i];
              final thumb = ref.watch(libraryThumbnailProvider(item.id)).value;
              final length = videoLengthLabel(item.duration ?? Duration.zero);
              return Semantics(
                button: true,
                label: l10n.createVideoLabel(length),
                excludeSemantics: true,
                child: GestureDetector(
                  key: NewReelScreen.libraryItemKey(item.id),
                  onTap: () => Navigator.of(context).pop(item.id),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(KRadius.sm),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (thumb != null)
                          Image.memory(thumb, fit: BoxFit.cover)
                        else
                          ColoredBox(color: p.surfaceOverlay),
                        PositionedDirectional(
                          bottom: KSpacing.xs,
                          end: KSpacing.xs,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: KSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: KStatusColors.onStatus.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(KRadius.sm),
                            ),
                            child: Text(
                              length,
                              textDirection: TextDirection.ltr,
                              style: context.textStyles.caption.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        AsyncError() => Center(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.createLibraryFailed,
                  textAlign: TextAlign.center,
                  style: context.textStyles.body.copyWith(
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(height: KSpacing.md),
                KButton(
                  label: l10n.actionRetry,
                  variant: KButtonVariant.secondary,
                  onPressed: () => ref.invalidate(
                    mediaLibraryControllerProvider(LibraryFilter.videos),
                  ),
                ),
              ],
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
