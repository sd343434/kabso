import 'dart:async';

import 'package:kabso_live/features/live/domain/live_models.dart';

/// CP-012 (D95): taps on a live are sent in batches, at most one request a
/// second and 50 taps a batch; the server counts at most 10 a second and
/// 10 000 a live (CONVENTIONS §10.10) and answers with the room's score.
///
/// Shared by the viewer's room session and, D120 (owner), the host's own
/// screen: the host's taps count like a viewer's.
class LiveTapBatcher {
  new({required this.send, required this.onScore, this.onError});

  /// Sends one batch of `count` taps.
  final Future<LiveTapsResult> Function(int count) send;

  /// The room's score after a batch.
  final void Function(int total) onScore;

  /// A batch failed (best effort: a lost batch only loses points).
  final void Function(Object error)? onError;

  static const maxBatch = 50;
  static const interval = Duration(seconds: 1);

  Timer? _flush;
  int _pending = 0;
  bool _closed = false;

  /// One tap.
  void tap() {
    if (_closed) return;
    _pending++;
    _flush ??= Timer(interval, _send);
  }

  Future<void> _send() async {
    _flush = null;
    final count = _pending < maxBatch ? _pending : maxBatch;
    if (count == 0 || _closed) return;
    _pending -= count;
    try {
      final result = await send(count);
      if (!_closed) onScore(result.score.total);
    } on Object catch (e) {
      if (!_closed) onError?.call(e);
    }
    if (!_closed && _pending > 0) _flush ??= Timer(interval, _send);
  }

  /// Drops the taps not sent yet and sends no more.
  void close() {
    _closed = true;
    _flush?.cancel();
    _flush = null;
    _pending = 0;
  }
}
