import 'dart:async';
import 'dart:typed_data';

import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

/// An in-memory [MediaRepository] (tests only): every upload succeeds with
/// asset ids `a1`, `a2`, … unless [failWith] is set for the next call.
class FakeMediaRepository implements MediaRepository {
  final List<String> uploads = [];
  Exception? failWith;

  /// Makes uploads wait until completed.
  Completer<void>? gate;

  @override
  Future<MediaAsset> uploadPhoto(
    Uint8List bytes,
    String contentType, {
    void Function(double progress)? onProgress,
  }) async {
    if (gate case final g?) await g.future;
    if (failWith case final e?) {
      failWith = null;
      throw e;
    }
    uploads.add(contentType);
    final id = 'a${uploads.length}';
    return MediaAsset(
      id: id,
      url: 'https://media.example.test/media/$id/1080.webp',
      thumbUrl: 'https://media.example.test/media/$id/320.webp',
      width: 1080,
      height: 1080,
    );
  }
}

/// A [PhotoPicker] that returns [next] (tests only).
class FakePhotoPicker implements PhotoPicker {
  new([this.next = const []]);

  List<Uint8List> next;
  int calls = 0;

  @override
  Future<List<Uint8List>> pickPhotos(int max) async {
    calls++;
    return next.take(max).toList();
  }
}

/// The smallest bytes that sniff as a JPEG (tests only).
final Uint8List jpegBytes = Uint8List.fromList([
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  0,
  0x10,
  0x4A,
  0x46,
  0x49,
  0x46,
  0,
  1,
]);

/// HEIC-like bytes (`ftypheic`), refused on the device.
final Uint8List heicBytes = Uint8List.fromList([
  0,
  0,
  0,
  0x18,
  0x66,
  0x74,
  0x79,
  0x70,
  0x68,
  0x65,
  0x69,
  0x63,
]);
