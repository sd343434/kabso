import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/posts/data/video_source.dart';
import 'package:photo_manager/photo_manager.dart';

/// What the app may read from the device photo library.
enum LibraryAccess {
  /// Every photo.
  granted,

  /// Only the photos the user chose (iOS 14+, Android 14+).
  limited,

  /// Refused; the system picker still works.
  denied,

  /// No library on this platform (web).
  unsupported;

  bool get canBrowse => this == granted || this == limited;
}

/// What the media step's grid lists (D162: the «فيديو» segment).
enum LibraryFilter { all, photos, videos }

/// One photo or (D162) video of the device library.
@immutable
class LibraryItem {
  const new({required this.id, this.video = false, this.duration});

  final String id;

  /// A video (with its [duration]); otherwise a photo.
  final bool video;
  final Duration? duration;

  @override
  bool operator ==(Object other) => other is LibraryItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The device photo and video library, newest first.
abstract interface class MediaLibrary {
  /// Asks for access when it has not been decided yet.
  Future<LibraryAccess> requestAccess();

  /// Page [page] (0-based) of [size] items of [filter].
  Future<List<LibraryItem>> page(
    int page, {
    int size = 60,
    LibraryFilter filter = LibraryFilter.all,
  });

  /// A small JPEG for the grid, or `null` when it can't be read.
  Future<Uint8List?> thumbnail(String id);

  /// The photo to upload: JPEG, at most 2160 px on its longer side (so iOS
  /// HEIC arrives as JPEG, which the API takes, §11.1), or `null`.
  Future<Uint8List?> photoBytes(String id);

  /// D162: the video [id] to upload — its file, length, size and first
  /// frame as the poster — or `null` when it can't be read.
  Future<PickedVideo?> video(String id);

  /// Opens the system settings (access was denied) or, with limited access,
  /// the system sheet that changes which photos the app sees.
  Future<void> manageAccess(LibraryAccess access);
}

/// [MediaLibrary] on `photo_manager`.
class DeviceMediaLibrary implements MediaLibrary {
  final Map<LibraryFilter, AssetPathEntity?> _paths = {};
  final Map<String, AssetEntity> _assets = {};

  /// D168 (owner: the newest photo or video showed at the bottom): an
  /// explicit order, newest first, for every grid. Without one the platform
  /// default applies — on iOS the Photos order (oldest first), on Android
  /// the media id. `createDate` is `creationDate` on iOS and `DATE_ADDED`
  /// on Android. Paging (`getAssetListPaged`) keeps this order, so page 0
  /// holds the newest items and later pages go back in time. No date
  /// window: `FilterOptionGroup`'s default one ends at the moment it is
  /// built, which would hide photos taken after it.
  static FilterOptionGroup get newestFirst => FilterOptionGroup(
    orders: const [OrderOption()],
    createTimeCond: DateTimeCond.def().copyWith(ignore: true),
  );

  static RequestType _type(LibraryFilter filter) => switch (filter) {
    LibraryFilter.all => RequestType.common,
    LibraryFilter.photos => RequestType.image,
    LibraryFilter.videos => RequestType.video,
  };

  @override
  Future<LibraryAccess> requestAccess() async {
    // D162: photos and videos — the default request (`RequestType.common`;
    // Android 13+ asks for both media permissions), no location.
    final state = await PhotoManager.requestPermissionExtend();
    return switch (state) {
      PermissionState.authorized => LibraryAccess.granted,
      PermissionState.limited => LibraryAccess.limited,
      _ => LibraryAccess.denied,
    };
  }

  @override
  Future<List<LibraryItem>> page(
    int page, {
    int size = 60,
    LibraryFilter filter = LibraryFilter.all,
  }) async {
    if (!_paths.containsKey(filter)) {
      _paths[filter] = (await PhotoManager.getAssetPathList(
        onlyAll: true,
        type: _type(filter),
        filterOption: newestFirst,
      )).firstOrNull;
    }
    final all = _paths[filter];
    if (all == null) return const [];
    final assets = await all.getAssetListPaged(page: page, size: size);
    return [
      for (final a in assets)
        LibraryItem(
          id: (_assets[a.id] = a).id,
          video: a.type == AssetType.video,
          duration: a.type == AssetType.video ? a.videoDuration : null,
        ),
    ];
  }

  Future<AssetEntity?> _asset(String id) async {
    final known = _assets[id];
    if (known != null) return known;
    final asset = await AssetEntity.fromId(id);
    if (asset != null) _assets[id] = asset;
    return asset;
  }

  @override
  Future<Uint8List?> thumbnail(String id) async {
    final asset = await _asset(id);
    return await asset?.thumbnailDataWithSize(
      const ThumbnailSize.square(300),
      quality: 80,
    );
  }

  @override
  Future<Uint8List?> photoBytes(String id) async {
    final asset = await _asset(id);
    if (asset == null) return null;
    final w = asset.orientatedWidth;
    final h = asset.orientatedHeight;
    const max = 2160;
    final scale = w <= 0 || h <= 0 || (w <= max && h <= max)
        ? 1.0
        : max / (w > h ? w : h);
    return await asset.thumbnailDataWithSize(
      ThumbnailSize(
        w <= 0 ? max : (w * scale).round(),
        h <= 0 ? max : (h * scale).round(),
      ),
      quality: 90,
    );
  }

  @override
  Future<PickedVideo?> video(String id) async {
    final asset = await _asset(id);
    if (asset == null || asset.type != AssetType.video) return null;
    // The original file (not a transcoded copy); null when it is only in
    // the cloud and can't be fetched.
    final file = await asset.originFile ?? await asset.file;
    if (file == null) return null;
    final head = await file
        .openRead(0, 16)
        .fold<List<int>>([], (a, b) => a..addAll(b));
    final w = asset.orientatedWidth;
    final h = asset.orientatedHeight;
    const max = 1080;
    final scale = w <= 0 || h <= 0 || (w <= max && h <= max)
        ? 1.0
        : max / (w > h ? w : h);
    // The platform's video thumbnail: the first frame, as a JPEG.
    final poster = await asset.thumbnailDataWithSize(
      ThumbnailSize(
        w <= 0 ? max : (w * scale).round(),
        h <= 0 ? max : (h * scale).round(),
      ),
      quality: 85,
    );
    return PickedVideo(
      byteSize: await file.length(),
      contentType: sniffVideoType(head) ?? 'application/octet-stream',
      duration: asset.videoDuration,
      width: w,
      height: h,
      poster: poster ?? await plainPoster(w, h),
      posterType: poster == null ? 'image/png' : 'image/jpeg',
      open: file.openRead,
      sourceId: id,
      path: file.path,
    );
  }

  @override
  Future<void> manageAccess(LibraryAccess access) =>
      access == LibraryAccess.limited
      ? PhotoManager.presentLimited(type: RequestType.common)
      : PhotoManager.openSetting();
}

/// No device library (web): the Create screen offers the system picker.
class UnsupportedMediaLibrary implements MediaLibrary {
  const new();

  @override
  Future<LibraryAccess> requestAccess() async => LibraryAccess.unsupported;

  @override
  Future<List<LibraryItem>> page(
    int page, {
    int size = 60,
    LibraryFilter filter = LibraryFilter.all,
  }) async => const [];

  @override
  Future<Uint8List?> thumbnail(String id) async => null;

  @override
  Future<Uint8List?> photoBytes(String id) async => null;

  @override
  Future<PickedVideo?> video(String id) async => null;

  @override
  Future<void> manageAccess(LibraryAccess access) async {}
}

final mediaLibraryProvider = Provider<MediaLibrary>(
  (ref) => kIsWeb ? const UnsupportedMediaLibrary() : DeviceMediaLibrary(),
);
