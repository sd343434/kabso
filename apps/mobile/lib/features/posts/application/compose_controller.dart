import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/posts/application/posts_feed_controller.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:material_ui/material_ui.dart';

/// At most 10 photos per post (`CreatePostRequest.mediaIds`).
const int maxPostPhotos = 10;

/// Text limits of a post (CONVENTIONS §11.2), checked again by the server.
const int maxPostText = 2200;
const int maxLocationText = 80;

/// Picks photos from the device library.
abstract interface class PhotoPicker {
  /// Up to [max] photos as bytes; empty when cancelled.
  Future<List<Uint8List>> pickPhotos(int max);
}

/// [PhotoPicker] on `image_picker`'s system picker. Asking for a bounded
/// size and a quality makes the platform re-encode, so iOS HEIC photos
/// arrive as JPEG (the API refuses HEIC, §11.1).
class ImagePickerPhotos implements PhotoPicker {
  new([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<Uint8List>> pickPhotos(int max) async {
    if (max <= 0) return const [];
    final files = await _picker.pickMultiImage(
      maxWidth: 2160,
      maxHeight: 2160,
      imageQuality: 90,
      limit: max > 1 ? max : null,
    );
    return [for (final f in files.take(max)) await f.readAsBytes()];
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => ImagePickerPhotos());

/// One photo of the draft; [assetId] once uploaded (kept across retries:
/// an asset stays attachable for 24 hours, §11.1).
@immutable
class ComposePhoto {
  const new({
    required this.localId,
    required this.bytes,
    required this.contentType,
    this.assetId,
  });

  final int localId;
  final Uint8List bytes;
  final String contentType;
  final String? assetId;

  ComposePhoto uploaded(String id) => ComposePhoto(
    localId: localId,
    bytes: bytes,
    contentType: contentType,
    assetId: id,
  );
}

/// Why picked photos were left out.
enum PhotoRejection { unsupportedType, tooLarge, tooMany }

enum ComposePhase { editing, uploading, publishing }

@immutable
class ComposeState {
  const new({
    this.photos = const [],
    this.phase = ComposePhase.editing,
    this.uploaded = 0,
    this.failure,
    this.rejections = const {},
  });

  final List<ComposePhoto> photos;
  final ComposePhase phase;

  /// Photos uploaded so far in this attempt (progress "n of m").
  final int uploaded;

  /// Why the last publish failed (shown with Retry).
  final AppFailure? failure;

  /// Why some of the last picked photos were left out.
  final Set<PhotoRejection> rejections;

  bool get busy => phase != ComposePhase.editing;

  ComposeState copyWith({
    List<ComposePhoto>? photos,
    ComposePhase? phase,
    int? uploaded,
    AppFailure? failure,
    bool clearFailure = false,
    Set<PhotoRejection>? rejections,
  }) => ComposeState(
    photos: photos ?? this.photos,
    phase: phase ?? this.phase,
    uploaded: uploaded ?? this.uploaded,
    failure: clearFailure ? null : (failure ?? this.failure),
    rejections: rejections ?? this.rejections,
  );
}

/// A random UUID v4 (the `Idempotency-Key` of a draft).
String newIdempotencyKey([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// The Create screen's draft (v1.5-social): photos are checked on the device
/// (type from the bytes, size, count), uploaded one by one when publishing,
/// then the post is created with an `Idempotency-Key`. A retry of the same
/// content reuses the key (so a lost response never makes two posts) and
/// skips photos already uploaded; changed content gets a new key.
class ComposeController extends Notifier<ComposeState> {
  int _nextId = 0;
  String? _key;
  String? _keyFor;

  @override
  ComposeState build() => const ComposeState();

  /// Adds picked photos that the API can take; returns what was left out.
  Set<PhotoRejection> addPhotos(List<Uint8List> picked) {
    final rejected = <PhotoRejection>{};
    final photos = [...state.photos];
    for (final bytes in picked) {
      final type = sniffImageType(bytes);
      if (type == null) {
        rejected.add(PhotoRejection.unsupportedType);
      } else if (bytes.length > maxPhotoBytes) {
        rejected.add(PhotoRejection.tooLarge);
      } else if (photos.length >= maxPostPhotos) {
        rejected.add(PhotoRejection.tooMany);
      } else {
        photos.add(
          ComposePhoto(localId: _nextId++, bytes: bytes, contentType: type),
        );
      }
    }
    state = state.copyWith(
      photos: List.unmodifiable(photos),
      rejections: rejected,
      clearFailure: true,
    );
    return rejected;
  }

  void removePhoto(int localId) {
    if (state.busy) return;
    state = state.copyWith(
      photos: List.unmodifiable([
        for (final p in state.photos)
          if (p.localId != localId) p,
      ]),
      clearFailure: true,
    );
  }

  /// Publishes the draft; the created post, or `null` on failure (then
  /// [ComposeState.failure] says why and the draft is kept).
  Future<Post?> publish({
    required String text,
    required String location,
  }) async {
    if (state.busy) return null;
    final caption = text.trim();
    final place = location.trim();
    if (caption.isEmpty && state.photos.isEmpty) return null;
    state = state.copyWith(
      phase: ComposePhase.uploading,
      uploaded: state.photos.where((p) => p.assetId != null).length,
      clearFailure: true,
    );
    try {
      final media = ref.read(mediaRepositoryProvider);
      for (final photo in state.photos) {
        if (photo.assetId != null) continue;
        final asset = await media.uploadPhoto(photo.bytes, photo.contentType);
        if (!ref.mounted) return null;
        state = state.copyWith(
          photos: List.unmodifiable(
            state.photos.map(
              (p) => p.localId == photo.localId ? p.uploaded(asset.id) : p,
            ),
          ),
          uploaded: state.uploaded + 1,
        );
      }
      state = state.copyWith(phase: ComposePhase.publishing);
      final mediaIds = [for (final p in state.photos) p.assetId!];
      final content = '$caption\u0000$place\u0000${mediaIds.join(',')}';
      if (_keyFor != content) {
        _key = newIdempotencyKey();
        _keyFor = content;
      }
      final post = await ref
          .read(postsRepositoryProvider)
          .createPost(
            idempotencyKey: _key!,
            text: caption,
            mediaIds: mediaIds,
            location: place,
          );
      if (!ref.mounted) return post;
      // A new draft starts clean; the feeds show the new post.
      _key = null;
      _keyFor = null;
      state = const ComposeState();
      for (final feed in HomeFeed.values) {
        ref.invalidate(postsFeedProvider(feed));
      }
      return post;
    } on Object catch (e) {
      if (!ref.mounted) return null;
      state = state.copyWith(
        phase: ComposePhase.editing,
        failure: toAppFailure(e),
      );
      return null;
    }
  }
}

final composeControllerProvider =
    NotifierProvider<ComposeController, ComposeState>(ComposeController.new);
