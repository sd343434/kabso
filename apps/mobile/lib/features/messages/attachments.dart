import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

/// Where an attachment comes from (D67).
enum AttachmentSource { gallery, cameraPhoto, cameraVideo }

/// A photo or video the user picked on the device. Nothing is uploaded:
/// there is no media upload or messaging API yet (CP-004).
@immutable
class PickedMedia {
  const new({required this.path, required this.isVideo});

  /// Decides photo or video from the MIME type, else the file extension.
  factory fromFile(XFile file) {
    final mime = file.mimeType;
    final ext = file.name.split('.').last.toLowerCase();
    return PickedMedia(
      path: file.path,
      isVideo: mime != null
          ? mime.startsWith('video/')
          : _videoExtensions.contains(ext),
    );
  }

  /// A file path, or a blob URL on the web.
  final String path;
  final bool isVideo;

  static const _videoExtensions = {
    'mp4',
    'mov',
    'm4v',
    '3gp',
    'webm',
    'mkv',
    'avi',
  };
}

/// Opens the device's photo library or camera.
abstract interface class MediaAttachmentPicker {
  /// The chosen media, or null when the user cancelled. Throws
  /// [PlatformException] when access is refused.
  Future<PickedMedia?> pick(AttachmentSource source);
}

/// [MediaAttachmentPicker] on `image_picker`: the system photo picker for
/// the library (no storage permission on Android 13+), the camera app for
/// photos and videos (videos up to [maxVideo]).
class ImagePickerAttachments implements MediaAttachmentPicker {
  new([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  static const maxVideo = Duration(minutes: 1);

  final ImagePicker _picker;

  @override
  Future<PickedMedia?> pick(AttachmentSource source) async {
    final file = switch (source) {
      AttachmentSource.gallery => await _picker.pickMedia(),
      AttachmentSource.cameraPhoto => await _picker.pickImage(
        source: ImageSource.camera,
      ),
      AttachmentSource.cameraVideo => await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: maxVideo,
      ),
    };
    if (file == null) return null;
    final media = PickedMedia.fromFile(file);
    // The camera's video button always records a video.
    return source == AttachmentSource.cameraVideo
        ? PickedMedia(path: media.path, isVideo: true)
        : media;
  }
}

final mediaAttachmentPickerProvider = Provider<MediaAttachmentPicker>(
  (ref) => ImagePickerAttachments(),
);

/// Asks where the attachment comes from; null when dismissed.
Future<AttachmentSource?> showAttachmentSheet(BuildContext context) {
  final l10n = context.l10n;
  return showModalBottomSheet<AttachmentSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (source, icon, label) in [
            (
              AttachmentSource.gallery,
              Icons.photo_library_outlined,
              l10n.attachGallery,
            ),
            (
              AttachmentSource.cameraPhoto,
              Icons.photo_camera_outlined,
              l10n.attachTakePhoto,
            ),
            (
              AttachmentSource.cameraVideo,
              Icons.videocam_outlined,
              l10n.attachRecordVideo,
            ),
          ])
            ListTile(
              key: AttachmentButton.sourceKey(source),
              leading: Icon(icon),
              title: Text(label),
              onTap: () => Navigator.pop(context, source),
            ),
          const SizedBox(height: KSpacing.sm),
        ],
      ),
    ),
  );
}

/// The paper-clip of a composer (D67): choose the gallery or the camera,
/// then [onPicked] receives the photo or video. Disabled when [onPicked]
/// is null (no API to send it).
class AttachmentButton extends ConsumerWidget {
  const new({required this.onPicked, super.key, this.outlined = false});

  static Key sourceKey(AttachmentSource s) => Key('attach.${s.name}');

  final ValueChanged<PickedMedia>? onPicked;

  /// A round outlined "+" (the chat composer, D68) instead of the photo
  /// icon.
  final bool outlined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final onPicked = this.onPicked;
    final color = onPicked == null ? p.textTertiary : p.textSecondary;
    return IconButton(
      tooltip: l10n.attachButton,
      style: outlined
          ? IconButton.styleFrom(
              shape: CircleBorder(side: BorderSide(color: p.border)),
            )
          : null,
      onPressed: onPicked == null
          ? null
          : () async {
              final source = await showAttachmentSheet(context);
              if (source == null || !context.mounted) return;
              try {
                final media = await ref
                    .read(mediaAttachmentPickerProvider)
                    .pick(source);
                if (media != null) onPicked(media);
              } on PlatformException {
                if (context.mounted) KSnack.error(context, l10n.attachFailed);
              }
            },
      icon: Icon(
        outlined ? Icons.add_rounded : Icons.add_photo_alternate_outlined,
        size: KMetrics.iconMd,
        color: color,
      ),
    );
  }
}

/// A picked photo or video shown in a conversation, at [size] with
/// [borderRadius]. A video shows its first frame with a play button and
/// plays or pauses on tap.
class LocalMediaView extends StatelessWidget {
  const new({
    required this.media,
    required this.size,
    required this.borderRadius,
    super.key,
  });

  final PickedMedia media;
  final Size size;
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox.fromSize(
        size: size,
        child: media.isVideo
            ? _LocalVideo(path: media.path)
            : Semantics(
                container: true,
                image: true,
                label: l10n.attachPhotoLabel,
                child: kIsWeb
                    ? Image.network(
                        media.path,
                        fit: BoxFit.cover,
                        errorBuilder: _broken,
                      )
                    : Image.file(
                        File(media.path),
                        fit: BoxFit.cover,
                        errorBuilder: _broken,
                      ),
              ),
      ),
    );
  }

  static Widget _broken(BuildContext context, Object _, StackTrace? _) =>
      ColoredBox(
        color: context.palette.surfaceOverlay,
        child: Icon(
          Icons.broken_image_outlined,
          color: context.palette.textTertiary,
        ),
      );
}

class _LocalVideo extends StatefulWidget {
  const new({required this.path});

  final String path;

  @override
  State<_LocalVideo> createState() => _LocalVideoState();
}

class _LocalVideoState extends State<_LocalVideo> {
  VideoPlayerController? _controller;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    final controller = _controller =
        (kIsWeb
              ? VideoPlayerController.networkUrl(Uri.parse(widget.path))
              : VideoPlayerController.file(File(widget.path)))
          ..addListener(_changed);
    unawaited(
      controller.initialize().then(
        (_) {
          if (mounted) setState(() => _ready = true);
        },
        // No player (tests, an unsupported file): the tile stays a
        // placeholder with its play mark.
        onError: (Object _) {},
      ),
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_changed);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  void _toggle() {
    final c = _controller;
    if (c == null || !_ready) return;
    unawaited(c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = _controller;
    final playing = _ready && c != null && c.value.isPlaying;
    // Its own node: the time under it is announced separately.
    return Semantics(
      container: true,
      button: true,
      label: playing ? l10n.attachPause : l10n.attachPlayVideo,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _toggle,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: KPalette.dark.surfaceRaised),
            if (_ready && c != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox.fromSize(
                  size: c.value.size,
                  child: VideoPlayer(c),
                ),
              ),
            if (!playing)
              Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 44,
                  color: KPalette.dark.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
