import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:material_ui/material_ui.dart';

/// Records post views for `POST /views` (CONVENTIONS §11.4), best effort:
/// a post counts as watched while at least half of it is on screen; when
/// it leaves (or the app goes to the background) the time is kept if it
/// reached [minWatch]. Views are sent in batches of at most [maxBatch],
/// [flushDelay] after the first one waits; each post is sent once per
/// session (the server counts once per 24 hours anyway). A failed batch is
/// dropped: views never retry or block anything.
class ViewRecorder {
  new(this._repo);

  final PostsRepository _repo;

  static const Duration minWatch = Duration(seconds: 1);
  static const Duration flushDelay = Duration(seconds: 10);
  static const int maxBatch = 50;

  final Map<String, DateTime> _since = {};
  final Set<String> _sent = {};
  final List<PostView> _queue = [];
  Timer? _timer;
  bool _sending = false;
  bool _disposed = false;

  /// [postId] is now on screen.
  void visible(String postId) {
    if (_disposed || _sent.contains(postId)) return;
    _since.putIfAbsent(postId, clock.now);
  }

  /// [postId] left the screen.
  void hidden(String postId) {
    final since = _since.remove(postId);
    if (_disposed || since == null || _sent.contains(postId)) return;
    final watched = clock.now().difference(since);
    if (watched < minWatch) return;
    _sent.add(postId);
    _queue.add((postId: postId, watchedMs: watched.inMilliseconds));
    if (_queue.length >= maxBatch) {
      unawaited(flush());
    } else {
      _timer ??= Timer(flushDelay, () => unawaited(flush()));
    }
  }

  /// Ends every watch in progress and sends what is queued.
  Future<void> flush() async {
    [..._since.keys].forEach(hidden);
    _timer?.cancel();
    _timer = null;
    if (_sending || _queue.isEmpty) return;
    _sending = true;
    try {
      while (_queue.isNotEmpty) {
        final n = _queue.length < maxBatch ? _queue.length : maxBatch;
        final batch = _queue.sublist(0, n);
        _queue.removeRange(0, n);
        try {
          await _repo.recordViews(batch);
        } on Object {
          // Best effort (§11.4): a lost batch is not retried.
        }
      }
    } finally {
      _sending = false;
    }
  }

  /// Stops recording (the session ended): later calls are ignored.
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
  }
}

/// The session's [ViewRecorder]; flushes when the app goes to the
/// background and when the repository (the session) changes.
final viewRecorderProvider = Provider<ViewRecorder>((ref) {
  final recorder = ViewRecorder(ref.watch(postsRepositoryProvider));
  final lifecycle = AppLifecycleListener(
    onHide: () => unawaited(recorder.flush()),
  );
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(recorder.flush());
    recorder.dispose();
  });
  return recorder;
});
