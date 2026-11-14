import 'dart:async';
import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

/// Server limits of videos (v1.41-social, D162, CONVENTIONS §11.14), checked
/// again on the device so a too-long or too-large video never starts an
/// upload: a post video ≤ 200 MiB and 90 s (D168, owner; 3 minutes before),
/// a reel ≤ 100 MiB and 60 s, both at least 1 s, MP4 or QuickTime.
const int maxPostVideoBytes = 200 * 1024 * 1024;
const int maxReelVideoBytes = 100 * 1024 * 1024;
const Duration maxPostVideoLength = Duration(seconds: 90);
const Duration maxReelVideoLength = Duration(seconds: 60);
const Duration minVideoLength = Duration(seconds: 1);

/// The server accepts up to 500 ms of encoder padding past the maximum.
const Duration _lengthTolerance = Duration(milliseconds: 500);

/// The video type of a file from its first bytes (the bytes decide, like
/// photos, §11.1): `video/quicktime` (major brand `qt  `), `video/mp4` (any
/// other `ftyp` brand), or `null` (not an MPEG-4 / QuickTime file).
String? sniffVideoType(List<int> head) {
  if (head.length < 12) return null;
  final ftyp = String.fromCharCodes(head.sublist(4, 8));
  if (ftyp != 'ftyp') return null;
  final brand = String.fromCharCodes(head.sublist(8, 12));
  // HEIC / AVIF photos share the box format: not videos.
  const stills = {'heic', 'heix', 'mif1', 'msf1', 'avif', 'avis'};
  if (stills.contains(brand)) return null;
  return brand == 'qt  ' ? 'video/quicktime' : 'video/mp4';
}

/// A video picked on the device, ready to upload: its bytes are read from
/// [open] as a stream (never loaded whole), [poster] is its first frame
/// (JPEG or PNG, made on the phone — the server makes none).
@immutable
class PickedVideo {
  const new({
    required this.byteSize,
    required this.contentType,
    required this.duration,
    required this.width,
    required this.height,
    required this.poster,
    required this.posterType,
    required this.open,
    this.sourceId,
    this.path,
  });

  final int byteSize;

  /// `video/mp4` or `video/quicktime`.
  final String contentType;
  final Duration duration;

  /// The size shown on screen (rotation applied); 0 when unknown.
  final int width;
  final int height;
  final Uint8List poster;
  final String posterType;

  /// Opens the file's bytes (a new stream each time: a retry reads again).
  final Stream<List<int>> Function() open;

  /// The device-library video it came from (`null` for the system picker).
  final String? sourceId;

  /// The file on the device (previews play it), when there is one.
  final String? path;

  double get aspect => width <= 0 || height <= 0 ? 9 / 16 : width / height;
}

/// Whether a video of [length] is longer than a post's (or, with [reel], a
/// reel's) limit, with the server's 500 ms of padding (D168: library tiles
/// mark such videos before they are tapped).
bool isVideoTooLong(Duration length, {required bool reel}) =>
    length >
    (reel ? maxReelVideoLength : maxPostVideoLength) + _lengthTolerance;

/// Why a picked video cannot be used ([mixed]: a post holds photos or one
/// video, never both, §11.14).
enum VideoRejection { unsupportedType, tooLarge, tooLong, tooShort, mixed }

/// The reason [video] does not fit a post (or, with [reel], a reel), or
/// `null` when it does.
VideoRejection? checkVideo(PickedVideo video, {required bool reel}) {
  if (video.contentType != 'video/mp4' &&
      video.contentType != 'video/quicktime') {
    return VideoRejection.unsupportedType;
  }
  if (video.byteSize > (reel ? maxReelVideoBytes : maxPostVideoBytes)) {
    return VideoRejection.tooLarge;
  }
  if (isVideoTooLong(video.duration, reel: reel)) return VideoRejection.tooLong;
  if (video.duration < minVideoLength) return VideoRejection.tooShort;
  return null;
}

/// Picks one video with the system picker (no library on this platform, or
/// no access to it).
abstract interface class VideoPicker {
  /// The video, `null` when cancelled; throws when it can't be read.
  Future<PickedVideo?> pickVideo({required Duration maxDuration});
}

/// [VideoPicker] on `image_picker`'s system picker. The length and size come
/// from the platform player (`video_player`, which opens the file without
/// playing it). The system picker gives no frame, so the poster is a plain
/// dark picture of the video's shape (honestly blank, never someone else's
/// image); the device library path (`MediaLibrary.video`) has the real first
/// frame.
class ImagePickerVideos implements VideoPicker {
  new([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedVideo?> pickVideo({required Duration maxDuration}) async {
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: maxDuration,
    );
    if (file == null) return null;
    final head = await file
        .openRead(0, 16)
        .fold<List<int>>([], (a, b) => a..addAll(b));
    final type = sniffVideoType(head);
    final probe = kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(file.path))
        : VideoPlayerController.file(File(file.path));
    try {
      await probe.initialize();
      final value = probe.value;
      final width = value.size.width.round();
      final height = value.size.height.round();
      return PickedVideo(
        byteSize: await file.length(),
        contentType: type ?? 'application/octet-stream',
        duration: value.duration,
        width: width,
        height: height,
        poster: await plainPoster(width, height),
        posterType: 'image/png',
        open: file.openRead,
        path: kIsWeb ? null : file.path,
      );
    } finally {
      unawaited(probe.dispose());
    }
  }
}

/// A plain dark PNG of the video's shape (at most 720 px on the long side),
/// the poster when the platform gives no frame.
Future<Uint8List> plainPoster(int width, int height) async {
  final aspect = width <= 0 || height <= 0 ? 9 / 16 : width / height;
  final w = aspect >= 1 ? 720 : (720 * aspect).round().clamp(16, 720);
  final h = aspect >= 1 ? (720 / aspect).round().clamp(16, 720) : 720;
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF15171C),
  );
  final image = await recorder.endRecording().toImage(w, h);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

final videoPickerProvider = Provider<VideoPicker>((ref) => ImagePickerVideos());

/// A video's length as `m:ss` (Latin digits, read left to right).
String videoLengthLabel(Duration length) {
  final seconds = (length.inMilliseconds / 1000).round();
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
