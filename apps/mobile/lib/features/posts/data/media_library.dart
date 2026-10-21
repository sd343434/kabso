import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// One photo of the device library.
@immutable
class LibraryItem {
  const new({required this.id});

  final String id;

  @override
  bool operator ==(Object other) => other is LibraryItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The device photo library, newest first. Photos only: posts take no video
/// before M2.
abstract interface class MediaLibrary {
  /// Asks for access when it has not been decided yet.
  Future<LibraryAccess> requestAccess();

  /// Page [page] (0-based) of [size] photos.
  Future<List<LibraryItem>> page(int page, {int size = 60});

  /// A small JPEG for the grid, or `null` when it can't be read.
  Future<Uint8List?> thumbnail(String id);

  /// The photo to upload: JPEG, at most 2160 px on its longer side (so iOS
  /// HEIC arrives as JPEG, which the API takes, §11.1), or `null`.
  Future<Uint8List?> photoBytes(String id);

  /// Opens the system settings (access was denied) or, with limited access,
  /// the system sheet that changes which photos the app sees.
  Future<void> manageAccess(LibraryAccess access);
}

/// [MediaLibrary] on `photo_manager`.
class DeviceMediaLibrary implements MediaLibrary {
  AssetPathEntity? _all;
  final Map<String, AssetEntity> _assets = {};

  static const _option = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.image,
      mediaLocation: false,
    ),
  );

  @override
  Future<LibraryAccess> requestAccess() async {
    final state = await PhotoManager.requestPermissionExtend(
      requestOption: _option,
    );
    return switch (state) {
      PermissionState.authorized => LibraryAccess.granted,
      PermissionState.limited => LibraryAccess.limited,
      _ => LibraryAccess.denied,
    };
  }

  @override
  Future<List<LibraryItem>> page(int page, {int size = 60}) async {
    _all ??= (await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
    )).firstOrNull;
    final all = _all;
    if (all == null) return const [];
    final assets = await all.getAssetListPaged(page: page, size: size);
    return [for (final a in assets) LibraryItem(id: (_assets[a.id] = a).id)];
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
  Future<void> manageAccess(LibraryAccess access) =>
      access == LibraryAccess.limited
      ? PhotoManager.presentLimited(type: RequestType.image)
      : PhotoManager.openSetting();
}

/// No device library (web): the Create screen offers the system picker.
class UnsupportedMediaLibrary implements MediaLibrary {
  const new();

  @override
  Future<LibraryAccess> requestAccess() async => LibraryAccess.unsupported;

  @override
  Future<List<LibraryItem>> page(int page, {int size = 60}) async => const [];

  @override
  Future<Uint8List?> thumbnail(String id) async => null;

  @override
  Future<Uint8List?> photoBytes(String id) async => null;

  @override
  Future<void> manageAccess(LibraryAccess access) async {}
}

final mediaLibraryProvider = Provider<MediaLibrary>(
  (ref) => kIsWeb ? const UnsupportedMediaLibrary() : DeviceMediaLibrary(),
);
