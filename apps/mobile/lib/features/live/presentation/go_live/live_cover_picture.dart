import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_cover_controller.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The room card's picture on the go-live screen (owner ref 65): the host's
/// live cover (`Me.liveCoverUrl`, CP-015), else their avatar, else their
/// initial, with **Edit** on it. Tapping it opens the cover options: choose a
/// photo (uploaded as a `LIVE_COVER`, cropped square by the server) or go
/// back to the avatar. While uploads are off the server answers 503 and the
/// screen says so; nothing changes.
class LiveCoverPicture extends ConsumerWidget {
  const new({
    required this.hostName,
    required this.hostAvatarUrl,
    required this.enabled,
    this.size = 55.9,
    this.radius = 5,
    this.label,
    this.labelSize = 10.2,
    this.labelBottom = 2.2,
    super.key,
  });

  static const pictureKey = Key('goLive.cover');
  static const chooseKey = Key('goLive.cover.choose');
  static const removeKey = Key('goLive.cover.remove');

  final String hostName;
  final String? hostAvatarUrl;
  final bool enabled;
  final double size;
  final double radius;

  /// The word on the picture: "Edit" (ref 65) by default; "Change" in the
  /// room's info sheet (ref 73).
  final String? label;
  final double labelSize;
  final double labelBottom;

  static const _white = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final cover = ref.watch(currentUserProvider.select((u) => u?.liveCoverUrl));
    final state = ref.watch(liveCoverControllerProvider);
    final url = cover ?? hostAvatarUrl;
    final initial = Text(
      hostName.characters.firstOrNull ?? '',
      style: text.title.copyWith(color: _white, fontSize: 24),
    );
    return Semantics(
      button: true,
      enabled: enabled && !state.busy,
      label: state.busy ? l10n.liveCoverUploading : l10n.liveCoverEditLabel,
      excludeSemantics: true,
      child: GestureDetector(
        key: pictureKey,
        behavior: HitTestBehavior.opaque,
        onTap: enabled && !state.busy
            ? () => openOptions(context, ref, hasCover: cover != null)
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: const Color(0xFF000000),
                  child: url != null
                      ? Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Center(child: initial),
                        )
                      : Center(child: initial),
                ),
                // Keeps "Edit" legible on a bright photo; invisible on the
                // empty black picture of the reference.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.5, 1],
                      colors: [Color(0x00000000), Color(0x8C000000)],
                    ),
                  ),
                ),
                if (state.busy)
                  ColoredBox(
                    color: const Color(0x8C000000),
                    child: Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          value: state.progress,
                          strokeWidth: 2.4,
                          color: _white,
                        ),
                      ),
                    ),
                  )
                else
                  // Measured on ref 65: #CCCCCC, ≈ 10 pt semibold, baseline
                  // 3.7 pt above the bottom edge.
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    bottom: labelBottom,
                    child: Text(
                      label ?? l10n.liveCoverEdit,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: text.caption.copyWith(
                        color: label == null ? const Color(0xFFCCCCCC) : _white,
                        fontSize: labelSize,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The cover options (choose a photo, back to the avatar); also opened
  /// by the Creator Center's «تعديل الغلاف» (D172).
  static Future<void> openOptions(
    BuildContext context,
    WidgetRef ref, {
    required bool hasCover,
  }) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<_CoverAction>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 4),
              child: Text(
                l10n.liveCoverSheetTitle,
                style: sheet.textStyles.title,
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 8),
              child: Text(
                l10n.liveCoverSheetBody,
                style: sheet.textStyles.body.copyWith(
                  color: sheet.palette.textSecondary,
                ),
              ),
            ),
            ListTile(
              key: chooseKey,
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.liveCoverChoose),
              onTap: () => Navigator.of(sheet).pop(_CoverAction.choose),
            ),
            if (hasCover)
              ListTile(
                key: removeKey,
                leading: Icon(Icons.delete_outline, color: sheet.palette.error),
                title: Text(l10n.liveCoverRemove),
                onTap: () => Navigator.of(sheet).pop(_CoverAction.remove),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final controller = ref.read(liveCoverControllerProvider.notifier);
    try {
      switch (action) {
        case _CoverAction.choose:
          final picked = await ref.read(photoPickerProvider).pickPhotos(1);
          if (!context.mounted || picked.isEmpty) return;
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
          await controller.change(bytes, type);
          if (context.mounted) KSnack.success(context, l10n.liveCoverUpdated);
        case _CoverAction.remove:
          await controller.remove();
          if (context.mounted) KSnack.success(context, l10n.liveCoverRemoved);
      }
    } on PlatformException {
      if (context.mounted) KSnack.error(context, l10n.createPhotoAccessDenied);
    } on Object catch (e) {
      if (context.mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }
}

enum _CoverAction { choose, remove }
