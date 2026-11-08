import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/create/create_media_step.dart'
    show videoRejectionMessage;
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/owner_profile/presentation/owner_cover_video.dart'
    show ownerPosterImageFor;
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/video_source.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D307 follow-up: «فيديو الغلاف» on its own (the founder's Me tab) — the
/// same section as in «تعديل الملف».
Future<void> showOwnerCoverVideoEditor(
  BuildContext context, {
  required String username,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => SingleChildScrollView(
    key: OwnerCoverVideoEditor.sheetKey,
    padding: const EdgeInsets.only(bottom: KSpacing.lg),
    child: OwnerCoverVideoEditor(username: username),
  ),
);

/// v1.95-social (D301, §10.112.1): «فيديو الغلاف» in «تعديل الملف» — only
/// for the app owner. Two rows, Arabic and English: each shows its poster
/// and length, «اختيار فيديو» (≤ 60 s, ≤ 100 MiB, like a reel; uploaded as
/// `PROFILE_COVER_VIDEO` with its poster) and «إزالة». Arabic-language
/// viewers see the Arabic video, everyone else the English one; with one,
/// everyone sees it.
class OwnerCoverVideoEditor extends ConsumerStatefulWidget {
  const new({required this.username, super.key});

  final String username;

  static const sectionKey = Key('owner.coverVideo.editor');

  /// D307 follow-up: the sheet of [showOwnerCoverVideoEditor].
  static const sheetKey = Key('owner.coverVideo.editorSheet');
  static Key chooseKey(String lang) => Key('owner.coverVideo.choose.$lang');
  static Key removeKey(String lang) => Key('owner.coverVideo.remove.$lang');

  @override
  ConsumerState<OwnerCoverVideoEditor> createState() =>
      _OwnerCoverVideoEditorState();
}

class _OwnerCoverVideoEditorState extends ConsumerState<OwnerCoverVideoEditor> {
  /// The language being uploaded or removed, and the upload's progress.
  String? _busy;
  double _progress = 0;

  Future<void> _choose(String lang) async {
    final l10n = context.l10n;
    PickedVideo? video;
    try {
      video = await ref
          .read(videoPickerProvider)
          .pickVideo(maxDuration: maxReelVideoLength);
    } on PlatformException {
      if (mounted) KSnack.error(context, l10n.createPhotoAccessDenied);
      return;
    } on Object {
      if (mounted) KSnack.error(context, l10n.createVideoUnreadable);
      return;
    }
    if (!mounted || video == null) return;
    if (checkVideo(video, reel: true) case final rejection?) {
      KSnack.error(context, videoRejectionMessage(l10n, rejection));
      return;
    }
    setState(() {
      _busy = lang;
      _progress = 0;
    });
    try {
      final asset = await ref
          .read(mediaRepositoryProvider)
          .uploadVideo(
            video,
            reel: true,
            kind: 'PROFILE_COVER_VIDEO',
            onProgress: (v) {
              if (mounted) setState(() => _progress = v);
            },
          );
      await ref
          .read(ownerProfileRepositoryProvider)
          .setCoverVideo(lang, asset.id);
      ref.invalidate(profileStatsProvider(widget.username));
      if (mounted) KSnack.success(context, l10n.ownerCoverVideoSaved);
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _remove(String lang) async {
    final l10n = context.l10n;
    setState(() => _busy = lang);
    try {
      await ref.read(ownerProfileRepositoryProvider).removeCoverVideo(lang);
      ref.invalidate(profileStatsProvider(widget.username));
      if (mounted) KSnack.success(context, l10n.ownerCoverVideoRemoved);
    } on Object catch (e) {
      if (mounted) KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final videos = ref
        .watch(profileStatsProvider(widget.username))
        .value
        ?.coverVideo;
    Widget row(String lang, String label, CoverVideoVariant? v) {
      final busy = _busy == lang;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(KRadius.sm),
              child: SizedBox(
                width: 54,
                height: 72,
                child: v == null
                    ? ColoredBox(
                        color: p.surfaceRaised,
                        child: Icon(
                          Icons.videocam_off_outlined,
                          color: p.textTertiary,
                        ),
                      )
                    : Image(
                        image: ownerPosterImageFor(v.posterUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: p.surfaceRaised),
                      ),
              ),
            ),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: t.bodyStrong),
                  Text(
                    busy && _progress > 0
                        ? l10n.ownerCoverVideoUploading(
                            (_progress * 100).round(),
                          )
                        : v == null
                        ? l10n.ownerCoverVideoNone
                        : l10n.ownerCoverVideoSeconds(
                            (v.durationMs / 1000).round(),
                          ),
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else ...[
              if (v != null)
                IconButton(
                  key: OwnerCoverVideoEditor.removeKey(lang),
                  tooltip: l10n.ownerCoverVideoRemove,
                  onPressed: _busy == null
                      ? () => unawaited(_remove(lang))
                      : null,
                  icon: Icon(Icons.delete_outline_rounded, color: p.error),
                ),
              TextButton(
                key: OwnerCoverVideoEditor.chooseKey(lang),
                onPressed: _busy == null
                    ? () => unawaited(_choose(lang))
                    : null,
                child: Text(
                  v == null
                      ? l10n.ownerCoverVideoChoose
                      : l10n.ownerCoverVideoReplace,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Padding(
      key: OwnerCoverVideoEditor.sectionKey,
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.lg,
        KSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.movie_creation_rounded,
                size: 18,
                color: KBrandColors.red500,
              ),
              const SizedBox(width: KSpacing.xs),
              Text(l10n.ownerCoverVideoTitle, style: t.title),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            l10n.ownerCoverVideoHint,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.sm),
          row('ar', l10n.ownerCoverVideoArabic, videos?.ar),
          row('en', l10n.ownerCoverVideoEnglish, videos?.en),
        ],
      ),
    );
  }
}
