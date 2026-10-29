import 'dart:async';
import 'dart:typed_data';

import 'package:kabso_live/features/posts/application/compose_controller.dart';
import 'package:kabso_live/features/posts/data/media_library.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/video_source.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

/// An in-memory [MediaRepository] (tests only): every upload succeeds with
/// asset ids `a1`, `a2`, … unless [failWith] is set for the next call.
class FakeMediaRepository implements MediaRepository {
  final List<String> uploads = [];

  /// How many uploads were for stories.
  int storyUploads = 0;

  /// How many uploads were live covers (CP-015).
  int coverUploads = 0;
  Exception? failWith;

  /// Makes uploads wait until completed.
  Completer<void>? gate;

  @override
  Future<MediaAsset> uploadPhoto(
    Uint8List bytes,
    String contentType, {
    bool forStory = false,
    bool forLiveCover = false,
    void Function(double progress)? onProgress,
  }) async {
    if (gate case final g?) await g.future;
    if (failWith case final e?) {
      failWith = null;
      throw e;
    }
    uploads.add(contentType);
    if (forStory) storyUploads++;
    if (forLiveCover) coverUploads++;
    final id = 'a${uploads.length}';
    return MediaAsset(
      id: id,
      url: 'https://media.example.test/media/$id/1080.webp',
      thumbUrl: 'https://media.example.test/media/$id/320.webp',
      width: 1080,
      height: 1080,
    );
  }

  /// CP-018: how many family emblems were uploaded.
  int emblemUploads = 0;

  @override
  Future<MediaAsset> uploadFamilyEmblem(
    Uint8List bytes,
    String contentType,
  ) async {
    if (failWith case final e?) {
      failWith = null;
      throw e;
    }
    emblemUploads++;
    final id = 'e$emblemUploads';
    return MediaAsset(
      id: id,
      url: 'https://media.example.test/media/$id/640.webp',
      thumbUrl: 'https://media.example.test/media/$id/320.webp',
      width: 640,
      height: 640,
    );
  }

  /// CP-022: how many family covers were uploaded.
  int familyCoverUploads = 0;

  @override
  Future<MediaAsset> uploadFamilyCover(
    Uint8List bytes,
    String contentType,
  ) async {
    if (failWith case final e?) {
      failWith = null;
      throw e;
    }
    familyCoverUploads++;
    final id = 'c$familyCoverUploads';
    return MediaAsset(
      id: id,
      url: 'https://media.example.test/media/$id/1080.webp',
      thumbUrl: 'https://media.example.test/media/$id/320.webp',
      width: 1080,
      height: 608,
    );
  }

  /// D168: every profile photo upload, e.g. `image/png:1234`.
  final List<String> avatarUploads = [];

  @override
  Future<MediaAsset> uploadAvatar(
    Uint8List bytes,
    String contentType, {
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0);
    if (gate case final g?) await g.future;
    if (failWith case final e?) {
      failWith = null;
      throw e;
    }
    onProgress?.call(1);
    avatarUploads.add('$contentType:${bytes.length}');
    final id = 'av${avatarUploads.length}';
    return MediaAsset(
      id: id,
      url: 'https://media.example.test/media/$id/640.webp',
      thumbUrl: 'https://media.example.test/media/$id/320.webp',
      width: 640,
      height: 640,
    );
  }

  /// D155: every direct message upload, e.g. `voice:audio/mp4:1234`.
  final List<String> dmUploads = [];

  @override
  Future<String> uploadDmMedia(
    Uint8List bytes,
    String contentType, {
    required bool voice,
  }) async {
    if (failWith case final e?) {
      failWith = null;
      throw e;
    }
    dmUploads.add('${voice ? 'voice' : 'image'}:$contentType:${bytes.length}');
    return 'dm${dmUploads.length}';
  }

  /// D162: every video upload, e.g. `reel:video/mp4:1234:poster:image/jpeg`.
  final List<String> videoUploads = [];

  /// D162: the progress values reported to the last video upload.
  final List<double> videoProgress = [];

  @override
  Future<MediaAsset> uploadVideo(
    PickedVideo video, {
    required bool reel,
    void Function(double progress)? onProgress,
  }) async {
    for (final p in const [0.0, 0.5, 1.0]) {
      videoProgress.add(p);
      onProgress?.call(p);
    }
    if (gate case final g?) await g.future;
    if (failWith case final e?) {
      failWith = null;
      throw e;
    }
    videoUploads.add(
      '${reel ? 'reel' : 'post'}:${video.contentType}:${video.byteSize}'
      ':poster:${video.posterType}',
    );
    final id = 'v${videoUploads.length}';
    return MediaAsset(
      id: id,
      url: 'https://media.example.test/media/$id/video.mp4',
      thumbUrl: 'https://media.example.test/media/p$id/320.webp',
      posterUrl: 'https://media.example.test/media/p$id/1080.webp',
      width: video.width,
      height: video.height,
      type: MediaType.video,
      durationMs: video.duration.inMilliseconds,
    );
  }

  /// CP-017: every live chat upload, e.g. `voice:audio/mp4:1234`.
  final List<String> liveChatUploads = [];

  @override
  Future<MediaAsset> uploadLiveChatMedia(
    Uint8List bytes,
    String contentType, {
    required bool voice,
  }) async {
    if (gate case final g?) await g.future;
    if (failWith case final e?) {
      failWith = null;
      throw e;
    }
    liveChatUploads.add(
      '${voice ? 'voice' : 'image'}:$contentType:${bytes.length}',
    );
    final id = 'c${liveChatUploads.length}';
    return MediaAsset(
      id: id,
      url: 'https://media.example.test/media/$id/x',
      thumbUrl: 'https://media.example.test/media/$id/x',
      width: voice ? 0 : 1080,
      height: voice ? 0 : 1080,
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

/// A device library (tests only): [access] as given, [ids] as the photos
/// (newest first), each read as [bytes] (`null` = unreadable), and
/// (D162) [videos] by id (a `null` value: unreadable).
class FakeMediaLibrary implements MediaLibrary {
  new({
    this.access = LibraryAccess.unsupported,
    this.ids = const [],
    Uint8List? bytes,
    this.videos = const {},
  }) : bytes = bytes ?? jpegBytes;

  LibraryAccess access;
  List<String> ids;
  Uint8List? bytes;
  Map<String, PickedVideo?> videos;
  final List<String> calls = [];

  @override
  Future<LibraryAccess> requestAccess() async {
    calls.add('access');
    return access;
  }

  @override
  Future<List<LibraryItem>> page(
    int page, {
    int size = 60,
    LibraryFilter filter = LibraryFilter.all,
  }) async {
    calls.add(
      filter == LibraryFilter.all ? 'page:$page' : 'page:$page:${filter.name}',
    );
    final all = [
      if (filter != LibraryFilter.videos)
        for (final id in ids) LibraryItem(id: id),
      if (filter != LibraryFilter.photos)
        for (final e in videos.entries)
          LibraryItem(
            id: e.key,
            video: true,
            duration: e.value?.duration ?? const Duration(seconds: 5),
          ),
    ];
    return all.skip(page * size).take(size).toList();
  }

  @override
  Future<PickedVideo?> video(String id) async {
    calls.add('video:$id');
    return videos[id];
  }

  @override
  Future<Uint8List?> thumbnail(String id) async => null;

  @override
  Future<Uint8List?> photoBytes(String id) async {
    calls.add('bytes:$id');
    return bytes;
  }

  @override
  Future<void> manageAccess(LibraryAccess access) async {
    calls.add('manage:${access.name}');
  }
}

/// A picked video (tests only): [seconds] long, [bytes] large, MP4, with a
/// JPEG poster; streams [bytes] zero bytes.
PickedVideo testVideo({
  String? sourceId,
  int seconds = 8,
  int bytes = 4096,
  int width = 1080,
  int height = 1920,
  String contentType = 'video/mp4',
}) => PickedVideo(
  byteSize: bytes,
  contentType: contentType,
  duration: Duration(seconds: seconds),
  width: width,
  height: height,
  poster: jpegBytes,
  posterType: 'image/jpeg',
  open: () => Stream.value(List<int>.filled(bytes, 0)),
  sourceId: sourceId,
);

/// A [VideoPicker] that returns [next] (tests only).
class FakeVideoPicker implements VideoPicker {
  new([this.next]);

  PickedVideo? next;
  final List<Duration> calls = [];

  @override
  Future<PickedVideo?> pickVideo({required Duration maxDuration}) async {
    calls.add(maxDuration);
    return next;
  }
}
