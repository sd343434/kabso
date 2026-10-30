import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/auth/data/dtos.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';

/// Editing the own profile (contract v1.45-social, D168, CONVENTIONS
/// §10.42): the name and bio (`PATCH /me`) and the profile photo
/// (`PUT` / `DELETE /me/avatar`; the photo itself is uploaded first as an
/// `AVATAR` asset, `MediaRepository.uploadAvatar`).
///
/// Every method throws an `AppFailure`.
abstract interface class ProfileEditRepository {
  /// `PATCH /me {displayName}`; the updated `Me`.
  Future<User> updateDisplayName(String displayName);

  /// `PATCH /me {bio}`; null (or empty) clears it. The updated `Me`.
  Future<User> updateBio(String? bio);

  /// `PUT /me/avatar {mediaId}`; the photo's URL.
  Future<String> setAvatar(String mediaId);

  /// `DELETE /me/avatar` (idempotent; works while uploads are off).
  Future<void> removeAvatar();
}

class ProfileEditRepositoryImpl implements ProfileEditRepository {
  new(this._api);

  final Dio _api;

  Future<User> _patch(Map<String, Object?> body) => guardApiCall(() async {
    final res = await _api.patch<Map<String, dynamic>>('/me', data: body);
    return MeDto.fromJson(res.data!).toEntity();
  });

  @override
  Future<User> updateDisplayName(String displayName) =>
      _patch({'displayName': displayName});

  @override
  Future<User> updateBio(String? bio) => _patch({'bio': bio});

  @override
  Future<String> setAvatar(String mediaId) => guardApiCall(() async {
    final res = await _api.put<Map<String, dynamic>>(
      '/me/avatar',
      data: {'mediaId': mediaId},
    );
    return res.data!['avatarUrl']! as String;
  });

  @override
  Future<void> removeAvatar() =>
      guardApiCall(() => _api.delete<void>('/me/avatar'));
}

final profileEditRepositoryProvider = Provider<ProfileEditRepository>(
  (ref) => ProfileEditRepositoryImpl(ref.watch(apiDioProvider)),
);

/// Where a new profile photo comes from.
enum AvatarSource { library, camera }

/// Takes one photo for the profile: from the system photo picker or the
/// camera. Asking for a bounded size and a quality makes the platform
/// re-encode, so iOS HEIC arrives as JPEG (the API refuses HEIC, §11.1).
abstract interface class AvatarPhotoPicker {
  /// The photo's bytes, or null when cancelled.
  Future<Uint8List?> pick(AvatarSource source);
}

class ImagePickerAvatarPhotos implements AvatarPhotoPicker {
  new([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Uint8List?> pick(AvatarSource source) async {
    final file = await _picker.pickImage(
      source: source == AvatarSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 2160,
      maxHeight: 2160,
      imageQuality: 90,
    );
    return file == null ? null : await file.readAsBytes();
  }
}

final avatarPhotoPickerProvider = Provider<AvatarPhotoPicker>(
  (ref) => ImagePickerAvatarPhotos(),
);
