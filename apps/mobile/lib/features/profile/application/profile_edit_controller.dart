import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/data/profile_edit_repository.dart';

/// Where a photo change is: idle, or [busy] with the upload's [progress]
/// (0–1; null once the bytes are sent and the server is processing).
@immutable
class ProfilePhotoState {
  const new({this.busy = false, this.progress});

  final bool busy;
  final double? progress;
}

/// Edits the own profile (D168, CONVENTIONS §10.42) and shows each change
/// at once: the session's user is replaced with the server's answer and
/// the cached `GET /me` and own profile counts are read again, so the Me
/// hub and the profile page show the new name, bio or photo.
///
/// Errors are rethrown as `AppFailure` for the screen to explain (503
/// `MEDIA_UPLOADS_UNAVAILABLE` while uploads are off); nothing changes then.
class ProfilePhotoController extends Notifier<ProfilePhotoState> {
  @override
  ProfilePhotoState build() => const ProfilePhotoState();

  /// Uploads [bytes] of [contentType] (already cropped square) as an
  /// `AVATAR`, then makes it the profile photo.
  Future<void> change(Uint8List bytes, String contentType) async {
    if (state.busy) return;
    state = const ProfilePhotoState(busy: true, progress: 0);
    try {
      final asset = await ref
          .read(mediaRepositoryProvider)
          .uploadAvatar(
            bytes,
            contentType,
            onProgress: (p) {
              if (state.busy) {
                state = ProfilePhotoState(
                  busy: true,
                  progress: p >= 1 ? null : p,
                );
              }
            },
          );
      final url = await ref
          .read(profileEditRepositoryProvider)
          .setAvatar(asset.id);
      _showPhoto(url);
    } finally {
      if (ref.mounted) state = const ProfilePhotoState();
    }
  }

  /// Back to the initial (no photo).
  Future<void> remove() async {
    if (state.busy) return;
    state = const ProfilePhotoState(busy: true);
    try {
      await ref.read(profileEditRepositoryProvider).removeAvatar();
      _showPhoto(null);
    } finally {
      if (ref.mounted) state = const ProfilePhotoState();
    }
  }

  void _showPhoto(String? url) {
    final user = ref.read(currentUserProvider);
    if (user != null) showUpdatedProfile(ref, user.copyWith(avatarUrl: url));
  }
}

final NotifierProvider<ProfilePhotoController, ProfilePhotoState>
profilePhotoControllerProvider =
    NotifierProvider.autoDispose<ProfilePhotoController, ProfilePhotoState>(
      ProfilePhotoController.new,
    );

/// Puts [user] in the session and reads `GET /me` and the own profile again.
void showUpdatedProfile(Ref ref, User user) {
  ref.read(sessionControllerProvider.notifier).updateUser(user);
  ref
    ..invalidate(meProvider)
    ..invalidate(profileStatsProvider(user.username));
}

/// `PATCH /me {displayName}` / `{bio}`; the updated user is shown at once.
final saveDisplayNameProvider = Provider<Future<User> Function(String)>(
  (ref) => (name) async {
    final user = await ref
        .read(profileEditRepositoryProvider)
        .updateDisplayName(name);
    showUpdatedProfile(ref, user);
    return user;
  },
);

final saveBioProvider = Provider<Future<User> Function(String?)>(
  (ref) => (bio) async {
    final user = await ref.read(profileEditRepositoryProvider).updateBio(bio);
    showUpdatedProfile(ref, user);
    return user;
  },
);
