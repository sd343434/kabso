import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_cover_repository.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';

/// Where a cover change is: idle, or [busy] with the upload's [progress]
/// (0–1; null once the bytes are sent and the server is processing).
@immutable
class LiveCoverState {
  const new({this.busy = false, this.progress});

  final bool busy;
  final double? progress;
}

/// Changes or removes the host's live cover (CP-015): upload the photo as a
/// `LIVE_COVER` asset, `PUT /me/live-cover`, then show it at once by updating
/// the session's user (`Me.liveCoverUrl`). Errors are rethrown as
/// `AppFailure` for the screen to explain (503 `MEDIA_UPLOADS_UNAVAILABLE`
/// while uploads are off); the cover then stays as it was.
class LiveCoverController extends Notifier<LiveCoverState> {
  @override
  LiveCoverState build() => const LiveCoverState();

  /// [bytes] of type [contentType] (already sniffed and size-checked).
  Future<void> change(Uint8List bytes, String contentType) async {
    if (state.busy) return;
    state = const LiveCoverState(busy: true, progress: 0);
    try {
      final asset = await ref
          .read(mediaRepositoryProvider)
          .uploadPhoto(
            bytes,
            contentType,
            forLiveCover: true,
            onProgress: (p) {
              if (state.busy) {
                state = LiveCoverState(busy: true, progress: p >= 1 ? null : p);
              }
            },
          );
      final url = await ref
          .read(liveCoverRepositoryProvider)
          .setCover(asset.id);
      _show(url);
    } finally {
      state = const LiveCoverState();
    }
  }

  /// Back to the avatar.
  Future<void> remove() async {
    if (state.busy) return;
    state = const LiveCoverState(busy: true);
    try {
      await ref.read(liveCoverRepositoryProvider).removeCover();
      _show(null);
    } finally {
      state = const LiveCoverState();
    }
  }

  void _show(String? url) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    ref
        .read(sessionControllerProvider.notifier)
        .updateUser(user.copyWith(liveCoverUrl: url));
  }
}

final NotifierProvider<LiveCoverController, LiveCoverState>
liveCoverControllerProvider =
    NotifierProvider.autoDispose<LiveCoverController, LiveCoverState>(
      LiveCoverController.new,
    );
