import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show newIdempotencyKey, photoPickerProvider;
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.95-social (D301 follow-up, §10.112.7; owner: «يتم نشرها بلغتين»): the
/// owner's official announcement — the Arabic and the English text (both
/// required) and, when publishing, up to 10 photos shared by both. Publishing
/// makes it everyone's first post and notifies everyone once; editing
/// ([post]) changes the texts only and notifies nobody. Returns the post.
Future<Post?> showAnnouncementComposer(
  BuildContext context, {
  required String username,
  Post? post,
}) => showModalBottomSheet<Post>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => AnnouncementComposer(username: username, post: post),
);

class AnnouncementComposer extends ConsumerStatefulWidget {
  const new({required this.username, super.key, this.post});

  final String username;

  /// Editing this announcement (its two texts).
  final Post? post;

  static const sheetKey = Key('owner.announcement.composer');
  static const arKey = Key('owner.announcement.ar');
  static const enKey = Key('owner.announcement.en');
  static const photosKey = Key('owner.announcement.photos');
  static const publishKey = Key('owner.announcement.publish');

  @override
  ConsumerState<AnnouncementComposer> createState() =>
      _AnnouncementComposerState();
}

class _AnnouncementComposerState extends ConsumerState<AnnouncementComposer> {
  late final _ar = TextEditingController(
    text: widget.post?.texts?.ar ?? widget.post?.text,
  );
  late final _en = TextEditingController(text: widget.post?.texts?.en);
  final List<Uint8List> _photos = [];

  /// One key for every retry of this announcement (CONVENTIONS §11.2).
  final String _key = newIdempotencyKey();
  bool _busy = false;

  bool get _editing => widget.post != null;

  bool get _ready =>
      !_busy && _ar.text.trim().isNotEmpty && _en.text.trim().isNotEmpty;

  @override
  void dispose() {
    _ar.dispose();
    _en.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final picked = await ref
        .read(photoPickerProvider)
        .pickPhotos(10 - _photos.length);
    if (picked.isEmpty || !mounted) return;
    setState(() {
      for (final p in picked) {
        if (sniffImageType(p) != null && p.length <= maxPhotoBytes) {
          _photos.add(p);
        }
      }
    });
  }

  Future<void> _submit() async {
    if (!_ready) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    final repo = ref.read(ownerProfileRepositoryProvider);
    try {
      final Post post;
      if (_editing) {
        post = await repo.updateAnnouncement(
          widget.post!.id,
          textAr: _ar.text.trim(),
          textEn: _en.text.trim(),
        );
      } else {
        final media = ref.read(mediaRepositoryProvider);
        final ids = <String>[];
        for (final p in _photos) {
          ids.add((await media.uploadPhoto(p, sniffImageType(p)!)).id);
        }
        post = await repo.createAnnouncement(
          idempotencyKey: _key,
          textAr: _ar.text.trim(),
          textEn: _en.text.trim(),
          mediaIds: ids,
        );
      }
      ref.invalidate(ownerOfficialPostsProvider(widget.username));
      if (!mounted) return;
      KSnack.success(
        context,
        _editing
            ? l10n.ownerAnnouncementSaved
            : l10n.ownerAnnouncementPublished,
      );
      Navigator.of(context).pop(post);
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    Widget field(
      Key key,
      TextEditingController c,
      String label, {
      required bool rtl,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.md),
      child: TextField(
        key: key,
        controller: c,
        minLines: 3,
        maxLines: 6,
        maxLength: 2200,
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
    return Padding(
      key: AnnouncementComposer.sheetKey,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          KSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_rounded, color: KBrandColors.red500),
                const SizedBox(width: KSpacing.xs),
                Expanded(
                  child: Text(
                    _editing
                        ? l10n.ownerAnnouncementEdit
                        : l10n.ownerAnnouncementNew,
                    style: t.title,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              _editing
                  ? l10n.ownerAnnouncementEditHint
                  : l10n.ownerAnnouncementHint,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: KSpacing.md),
            field(
              AnnouncementComposer.arKey,
              _ar,
              l10n.ownerAnnouncementTextAr,
              rtl: true,
            ),
            field(
              AnnouncementComposer.enKey,
              _en,
              l10n.ownerAnnouncementTextEn,
              rtl: false,
            ),
            if (!_editing) ...[
              Wrap(
                spacing: KSpacing.sm,
                runSpacing: KSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final (i, bytes) in _photos.indexed)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(KRadius.sm),
                          child: Image.memory(
                            bytes,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        PositionedDirectional(
                          top: 0,
                          end: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _photos.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 10,
                              backgroundColor: Color(0xB3000000),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_photos.length < 10)
                    OutlinedButton.icon(
                      key: AnnouncementComposer.photosKey,
                      onPressed: _busy ? null : () => unawaited(_addPhotos()),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(l10n.ownerAnnouncementPhotos),
                    ),
                ],
              ),
              const SizedBox(height: KSpacing.md),
            ],
            FilledButton.icon(
              key: AnnouncementComposer.publishKey,
              style: FilledButton.styleFrom(
                backgroundColor: KBrandColors.red500,
                foregroundColor: const Color(0xFFFFFFFF),
              ),
              onPressed: _ready ? () => unawaited(_submit()) : null,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_editing ? Icons.check_rounded : Icons.send_rounded),
              label: Text(
                _editing ? l10n.ownerSave : l10n.ownerAnnouncementPublish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
