import 'dart:async';
import 'dart:io' show File;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/features/live/data/live_media_extras.dart';
import 'package:kabso_live/features/live/tools/live_tools_repository.dart';
import 'package:kabso_live/features/posts/application/compose_controller.dart'
    show newIdempotencyKey;
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/data/video_source.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

/// D201 «التسجيل»: the longest clip (reels are ≤ 60 s, §11.14).
const Duration liveClipMax = Duration(seconds: 60);

enum LiveClipPhase { idle, starting, recording, stopping, ready, posting }

/// A finished clip on the phone.
@immutable
class LiveClip {
  const new({required this.path, required this.length, required this.poster});

  final String path;
  final Duration length;

  /// The camera's still when recording started (or null).
  final Uint8List? poster;
}

@immutable
class LiveClipState {
  const new({
    this.phase = LiveClipPhase.idle,
    this.startedAt,
    this.elapsed = Duration.zero,
    this.clip,
    this.progress,
  });

  final LiveClipPhase phase;
  final DateTime? startedAt;
  final Duration elapsed;
  final LiveClip? clip;

  /// 0–1 while a reel uploads.
  final double? progress;

  Duration get remaining {
    final left = liveClipMax - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  bool get recording =>
      phase == LiveClipPhase.recording || phase == LiveClipPhase.starting;
}

/// D201: the file side of clips — a fresh path, the bytes, the gallery,
/// deleting. A seam for tests.
abstract interface class LiveClipStore {
  Future<String> newPath();

  Future<int> length(String path);

  Future<List<int>> head(String path);

  Stream<List<int>> open(String path);

  /// Into the phone's gallery (Photos / MediaStore). Throws when refused.
  Future<void> saveToGallery(String path);

  Future<void> delete(String path);
}

class DeviceLiveClipStore implements LiveClipStore {
  @override
  Future<String> newPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/kabso_clip_${clock.now().millisecondsSinceEpoch}.mp4';
  }

  @override
  Future<int> length(String path) => File(path).length();

  @override
  Future<List<int>> head(String path) =>
      File(path).openRead(0, 16).fold<List<int>>([], (a, b) => a..addAll(b));

  @override
  Stream<List<int>> open(String path) => File(path).openRead();

  @override
  Future<void> saveToGallery(String path) async {
    final name = path.split('/').last;
    try {
      // Android 10+ adds to MediaStore without a permission.
      await PhotoManager.editor.saveVideo(File(path), title: name);
    } on Object {
      // Android 7–9 (storage) and iOS (add to Photos) ask first; the system
      // prompt explains it; refused → the caller says how to allow it.
      final access = await PhotoManager.requestPermissionExtend();
      if (!access.hasAccess) rethrow;
      await PhotoManager.editor.saveVideo(File(path), title: name);
    }
  }

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }
}

final liveClipStoreProvider = Provider<LiveClipStore>(
  (_) => DeviceLiveClipStore(),
);

/// Why the clip could not be used.
enum LiveClipProblem { startFailed, tooShort, unreadable }

class LiveClipException implements Exception {
  const new(this.problem);
  final LiveClipProblem problem;
}

/// D201: records the host's own published camera and microphone (on the
/// phone, [LiveClipCapture]) for at most [liveClipMax] — the room is told so
/// viewers see «يتم التسجيل» — then holds the clip for the preview: saved
/// to the gallery, posted as a reel (D162's upload), or discarded.
class LiveClipController extends Notifier<LiveClipState> {
  new(this.roomId);

  final String roomId;

  Timer? _ticker;
  LiveClipCapture? _capture;

  LiveToolsRepository get _repo => ref.read(liveToolsRepositoryProvider);
  LiveClipStore get _store => ref.read(liveClipStoreProvider);

  @override
  LiveClipState build() {
    final repo = _repo;
    ref.onDispose(() {
      _ticker?.cancel();
      // Still recording (the live screen closed): the recording stops.
      final capture = _capture;
      if (capture != null) {
        unawaited(capture.stopClip().catchError((Object _) {}));
        unawaited(
          repo.setRecording(roomId, active: false).catchError((Object _) {}),
        );
      }
    });
    return const LiveClipState();
  }

  /// Starts recording [capture]'s camera and microphone.
  Future<void> start(LiveClipCapture capture) async {
    if (state.phase != LiveClipPhase.idle) return;
    state = const LiveClipState(phase: LiveClipPhase.starting);
    final String path;
    final Uint8List? poster;
    try {
      path = await _store.newPath();
      poster = await capture.cameraStill();
      await capture.startClip(path);
    } on Object {
      state = const LiveClipState();
      throw const LiveClipException(LiveClipProblem.startFailed);
    }
    _capture = capture;
    final startedAt = clock.now();
    state = LiveClipState(phase: LiveClipPhase.recording, startedAt: startedAt);
    _pendingPath = path;
    _pendingPoster = poster;
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    // Transparency: the room shows «يتم التسجيل» (best effort — the clip
    // stays on the phone either way).
    unawaited(
      _repo.setRecording(roomId, active: true).catchError((Object _) {}),
    );
  }

  late String _pendingPath;
  Uint8List? _pendingPoster;

  void _tick() {
    final startedAt = state.startedAt;
    if (state.phase != LiveClipPhase.recording || startedAt == null) return;
    final elapsed = clock.now().difference(startedAt);
    if (elapsed >= liveClipMax) {
      state = LiveClipState(
        phase: LiveClipPhase.recording,
        startedAt: startedAt,
        elapsed: liveClipMax,
      );
      unawaited(stop());
      return;
    }
    state = LiveClipState(
      phase: LiveClipPhase.recording,
      startedAt: startedAt,
      elapsed: elapsed,
    );
  }

  /// Stops (the 60 s limit, or the host); the clip goes to the preview.
  Future<void> stop() async {
    if (state.phase != LiveClipPhase.recording) return;
    _ticker?.cancel();
    _ticker = null;
    final startedAt = state.startedAt!;
    final elapsed = clock.now().difference(startedAt);
    final length = elapsed > liveClipMax ? liveClipMax : elapsed;
    state = LiveClipState(
      phase: LiveClipPhase.stopping,
      startedAt: startedAt,
      elapsed: length,
    );
    final capture = _capture;
    _capture = null;
    try {
      await capture?.stopClip();
    } on Object {
      // The file is checked below.
    }
    unawaited(
      _repo.setRecording(roomId, active: false).catchError((Object _) {}),
    );
    final path = _pendingPath;
    if (length < minVideoLength) {
      await _store.delete(path).catchError((Object _) {});
      state = const LiveClipState();
      throw const LiveClipException(LiveClipProblem.tooShort);
    }
    state = LiveClipState(
      phase: LiveClipPhase.ready,
      elapsed: length,
      clip: LiveClip(path: path, length: length, poster: _pendingPoster),
    );
  }

  /// «حفظ في الجهاز». The clip stays for another action.
  Future<void> save() async {
    final clip = state.clip;
    if (clip == null) return;
    await _store.saveToGallery(clip.path);
  }

  /// «نشر كريلز»: D162's reel upload (`REEL_VIDEO` ≤ 60 s) with [caption].
  /// Returns whether the reel waits for review.
  Future<bool> postReel(String caption) async {
    final clip = state.clip;
    if (clip == null || state.phase != LiveClipPhase.ready) return false;
    state = LiveClipState(
      phase: LiveClipPhase.posting,
      elapsed: state.elapsed,
      clip: clip,
      progress: 0,
    );
    try {
      final head = await _store.head(clip.path);
      final type = sniffVideoType(head);
      if (type == null) {
        throw const LiveClipException(LiveClipProblem.unreadable);
      }
      final video = PickedVideo(
        byteSize: await _store.length(clip.path),
        contentType: type,
        duration: clip.length,
        width: 0,
        height: 0,
        poster: clip.poster ?? await plainPoster(720, 1280),
        posterType: clip.poster == null ? 'image/png' : 'image/jpeg',
        open: () => _store.open(clip.path),
        path: clip.path,
      );
      final asset = await ref
          .read(mediaRepositoryProvider)
          .uploadVideo(
            video,
            reel: true,
            onProgress: (p) => state = LiveClipState(
              phase: LiveClipPhase.posting,
              elapsed: clip.length,
              clip: clip,
              progress: p,
            ),
          );
      final post = await ref
          .read(postsRepositoryProvider)
          .createPost(
            idempotencyKey: newIdempotencyKey(),
            text: caption.trim(),
            mediaIds: [asset.id],
            reel: true,
          );
      await _store.delete(clip.path).catchError((Object _) {});
      state = const LiveClipState();
      return post.pendingModeration;
    } on Object {
      state = LiveClipState(
        phase: LiveClipPhase.ready,
        elapsed: clip.length,
        clip: clip,
      );
      rethrow;
    }
  }

  /// «تجاهل»: the file is deleted.
  Future<void> discard() async {
    final clip = state.clip;
    state = const LiveClipState();
    if (clip != null) await _store.delete(clip.path).catchError((Object _) {});
  }
}

final NotifierProviderFamily<LiveClipController, LiveClipState, String>
liveClipProvider = NotifierProvider.autoDispose
    .family<LiveClipController, LiveClipState, String>(LiveClipController.new);
