// v1.136-social (D384, CONVENTIONS §10.173.2–3): saving and removing the VIP
// animated picture — the strip goes through the media pipeline like every
// upload (slot, presigned PUT, complete: kind ANIMATED_AVATAR, image/png),
// then `PUT /me/animated-avatar`; `DELETE /me/animated-avatar` removes it.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/vip/domain/animated_avatar.dart';

/// Every method throws an `AppFailure` (409 `VIP_UNAVAILABLE` without the
/// perk, 422 `MEDIA_INVALID` for a strip the server refuses).
abstract interface class AnimatedAvatarRepository {
  /// Uploads the PNG [strip] and makes it the caller's animated picture;
  /// [onProgress] gets 0–1 of the upload.
  Future<AnimatedAvatar> save(
    Uint8List strip, {
    void Function(double progress)? onProgress,
  });

  /// `DELETE /me/animated-avatar` (idempotent).
  Future<void> remove();
}

class AnimatedAvatarRepositoryImpl implements AnimatedAvatarRepository {
  new(this._api, this._storage);

  final Dio _api;

  /// The bare storage client: no base URL, no bearer token (the URL is
  /// presigned).
  final Dio _storage;

  @override
  Future<AnimatedAvatar> save(
    Uint8List strip, {
    void Function(double progress)? onProgress,
  }) => guardApiCall(() async {
    final slot = (await _api.post<Map<String, dynamic>>(
      '/media/uploads',
      data: {
        'kind': 'ANIMATED_AVATAR',
        'contentType': 'image/png',
        'byteSize': strip.length,
      },
    )).data!;
    final uploadId = slot['uploadId']! as String;
    final headers = {
      for (final e in (slot['headers']! as Map<String, dynamic>).entries)
        e.key: e.value as String,
    };
    await _storage.put<void>(
      slot['uploadUrl']! as String,
      data: Stream.fromIterable([strip]),
      options: Options(headers: headers, contentType: headers['Content-Type']),
      onSendProgress: onProgress == null
          ? null
          : (sent, total) => onProgress(total <= 0 ? 0 : sent / total),
    );
    final asset = (await _api.post<Map<String, dynamic>>(
      '/media/uploads/${pathSegment(uploadId)}/complete',
    )).data!;
    final res = await _api.put<Map<String, dynamic>>(
      '/me/animated-avatar',
      data: {'mediaId': asset['id']},
    );
    return AnimatedAvatar.tryParse(res.data) ??
        (throw const FormatException('AnimatedAvatar'));
  });

  @override
  Future<void> remove() =>
      guardApiCall(() => _api.delete<void>('/me/animated-avatar'));
}

final animatedAvatarRepositoryProvider = Provider<AnimatedAvatarRepository>(
  (ref) => AnimatedAvatarRepositoryImpl(
    ref.watch(apiDioProvider),
    ref.watch(storageDioProvider),
  ),
);
