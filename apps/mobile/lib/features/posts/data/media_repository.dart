import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

/// The largest photo the server accepts (`CreateMediaUploadRequest.byteSize`).
const int maxPhotoBytes = 15 * 1024 * 1024;

/// The image type of [bytes] from its signature (CONVENTIONS §11.1: the
/// bytes decide, never the picker's MIME type): `image/jpeg`, `image/png`,
/// `image/webp`, or `null` for anything else (HEIC, GIF, …).
String? sniffImageType(Uint8List bytes) {
  bool at(int offset, List<int> sig) {
    if (bytes.length < offset + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[offset + i] != sig[i]) return false;
    }
    return true;
  }

  if (at(0, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'image/webp';
  return null;
}

/// Photo uploads (v1.5-social, CONVENTIONS §11.1): reserve a slot
/// (`POST /media/uploads`), send the bytes to its presigned URL with exactly
/// the headers it names, then `POST /media/uploads/{id}/complete`, which
/// verifies and processes the photo.
///
/// Every method throws an `AppFailure`.
abstract interface class MediaRepository {
  /// Uploads one photo of type [contentType] for a post, or with
  /// [forStory] for a story (`STORY_IMAGE`, kept at 1 920 px, CP-008), or
  /// with [forLiveCover] as the host's live cover (`LIVE_COVER`, a 640 px
  /// square, CP-015); [onProgress] gets 0–1.
  Future<MediaAsset> uploadPhoto(
    Uint8List bytes,
    String contentType, {
    bool forStory = false,
    bool forLiveCover = false,
    void Function(double progress)? onProgress,
  });
}

class MediaRepositoryImpl implements MediaRepository {
  new(this._api, this._storage);

  final Dio _api;

  /// A bare client for the storage URL: no API base URL and, above all, no
  /// bearer token (the URL is presigned; the token must not leak to it).
  final Dio _storage;

  @override
  Future<MediaAsset> uploadPhoto(
    Uint8List bytes,
    String contentType, {
    bool forStory = false,
    bool forLiveCover = false,
    void Function(double progress)? onProgress,
  }) => guardApiCall(() async {
    final slot = (await _api.post<Map<String, dynamic>>(
      '/media/uploads',
      data: {
        'kind': forLiveCover
            ? 'LIVE_COVER'
            : forStory
            ? 'STORY_IMAGE'
            : 'POST_IMAGE',
        'contentType': contentType,
        'byteSize': bytes.length,
      },
    )).data!;
    final uploadId = slot['uploadId']! as String;
    final headers = {
      for (final e in (slot['headers']! as Map<String, dynamic>).entries)
        e.key: e.value as String,
    };
    await _storage.put<void>(
      slot['uploadUrl']! as String,
      data: Stream.fromIterable([bytes]),
      options: Options(headers: headers, contentType: headers['Content-Type']),
      onSendProgress: onProgress == null
          ? null
          : (sent, total) => onProgress(total <= 0 ? 0 : sent / total),
    );
    final asset = await _api.post<Map<String, dynamic>>(
      '/media/uploads/${pathSegment(uploadId)}/complete',
    );
    return MediaAsset.fromJson(asset.data!);
  });
}

/// The storage client (tests swap the adapter like the API's).
final storageDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final dio = Dio(
    BaseOptions(
      connectTimeout: config.connectTimeout,
      sendTimeout: const Duration(minutes: 2),
      receiveTimeout: config.receiveTimeout,
    ),
  );
  if (ref.watch(httpClientAdapterProvider) case final adapter?) {
    dio.httpClientAdapter = adapter;
  }
  ref.onDispose(dio.close);
  return dio;
});

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepositoryImpl(
    ref.watch(apiDioProvider),
    ref.watch(storageDioProvider),
  ),
);
