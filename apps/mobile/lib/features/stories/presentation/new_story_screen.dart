import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/story/new` (CP-008): one photo, full screen, with an optional short
/// text (≤ 200 characters), shared as a story for 24 hours. The photo is
/// checked on the device (type from the bytes, size), uploaded as a
/// `STORY_IMAGE` (kept at 1 920 px), then the story is created with an
/// `Idempotency-Key` kept for retries of the same content.
class NewStoryScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const pickKey = Key('newStory.pick');
  static const changeKey = Key('newStory.change');
  static const textKey = Key('newStory.text');
  static const shareKey = Key('newStory.share');
  static const closeKey = Key('newStory.close');
  static const previewKey = Key('newStory.preview');

  @override
  ConsumerState<NewStoryScreen> createState() => _NewStoryScreenState();
}

class _NewStoryScreenState extends ConsumerState<NewStoryScreen> {
  final _text = TextEditingController();
  Uint8List? _bytes;
  String? _type;

  /// The uploaded photo, kept for a retry while the photo is unchanged.
  String? _mediaId;
  late String _key;
  String? _keyFor;
  bool _busy = false;

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
    final l10n = context.l10n;
    try {
      final picked = await ref.read(photoPickerProvider).pickPhotos(1);
      if (!mounted || picked.isEmpty) return;
      final bytes = picked.first;
      final type = sniffImageType(bytes);
      if (type == null) {
        KSnack.error(context, l10n.createPhotoUnsupported);
        return;
      }
      if (bytes.length > maxPhotoBytes) {
        KSnack.error(context, l10n.createPhotoTooLarge);
        return;
      }
      setState(() {
        _bytes = bytes;
        _type = type;
        _mediaId = null;
      });
    } on PlatformException {
      if (mounted) KSnack.error(context, l10n.createPhotoAccessDenied);
    }
  }

  bool get _valid => _text.text.trim().characters.length <= maxStoryText;

  Future<void> _share() async {
    final bytes = _bytes;
    final type = _type;
    if (_busy || bytes == null || type == null || !_valid) return;
    FocusScope.of(context).unfocus();
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final mediaId =
          _mediaId ??
          (await ref
                  .read(mediaRepositoryProvider)
                  .uploadPhoto(bytes, type, forStory: true))
              .id;
      _mediaId = mediaId;
      final text = _text.text.trim();
      final content = '$mediaId\u0000$text';
      if (_keyFor != content) {
        _key = newIdempotencyKey();
        _keyFor = content;
      }
      await ref
          .read(storiesRepositoryProvider)
          .createStory(idempotencyKey: _key, mediaId: mediaId, text: text);
      if (!mounted) return;
      ref
        ..invalidate(storyTrayProvider)
        ..invalidate(storyArchiveProvider);
      KSnack.success(context, l10n.storyShared);
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.reels);
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }

  void _closeScreen() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.reels);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    const white = Color(0xFFFFFFFF);
    final bytes = _bytes;
    final count = _text.text.trim().characters.length;
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (bytes != null)
              Center(
                child: Image.memory(
                  bytes,
                  key: NewStoryScreen.previewKey,
                  fit: BoxFit.contain,
                  semanticLabel: l10n.storyPreview,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: Color(0x99FFFFFF),
                    size: 48,
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
                        Icons.add_photo_alternate_outlined,
                        size: 56,
                        color: white,
                      ),
                      const SizedBox(height: KSpacing.md),
                      Text(
                        l10n.storyNewTitle,
                        textAlign: TextAlign.center,
                        style: t.title.copyWith(color: white),
                      ),
                      const SizedBox(height: KSpacing.xs),
                      Text(
                        l10n.storyNewBody,
                        textAlign: TextAlign.center,
                        style: t.body.copyWith(color: const Color(0xCCFFFFFF)),
                      ),
                      const SizedBox(height: KSpacing.lg),
                      KButton(
                        key: NewStoryScreen.pickKey,
                        label: l10n.storyPickPhoto,
                        onPressed: _pick,
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: KSpacing.xs,
              left: KSpacing.xs,
              right: KSpacing.xs,
              child: Row(
                children: [
                  IconButton(
                    key: NewStoryScreen.closeKey,
                    tooltip: l10n.storyClose,
                    onPressed: _busy ? null : _closeScreen,
                    icon: const Icon(Icons.close_rounded, color: white),
                  ),
                  const Spacer(),
                  if (bytes != null) ...[
                    IconButton(
                      key: NewStoryScreen.changeKey,
                      tooltip: l10n.storyChangePhoto,
                      onPressed: _busy ? null : _pick,
                      icon: const Icon(
                        Icons.photo_library_outlined,
                        color: white,
                      ),
                    ),
                    const SizedBox(width: KSpacing.xs),
                    FilledButton.icon(
                      key: NewStoryScreen.shareKey,
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
                      label: Text(l10n.storyShare),
                    ),
                  ],
                ],
              ),
            ),
            if (bytes != null)
              Positioned(
                left: KSpacing.md,
                right: KSpacing.md,
                bottom: KSpacing.md,
                child: TextField(
                  key: NewStoryScreen.textKey,
                  controller: _text,
                  enabled: !_busy,
                  minLines: 1,
                  maxLines: 4,
                  textDirection: KFormat.inputDirection(_text.text),
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(color: white),
                  cursorColor: white,
                  decoration: InputDecoration(
                    hintText: l10n.storyTextHint,
                    hintStyle: t.body.copyWith(color: const Color(0xB3FFFFFF)),
                    filled: true,
                    fillColor: const Color(0x99000000),
                    counterText: count > maxStoryText - 40
                        ? '$count/$maxStoryText'
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
              ),
          ],
        ),
      ),
    );
  }
}
