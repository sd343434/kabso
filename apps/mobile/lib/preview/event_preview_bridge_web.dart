import 'dart:js_interop';

import 'package:kabso_live/preview/event_preview_protocol.dart';
import 'package:web/web.dart' as web;

/// Listens to the panel (the parent window, an allowed origin only) and
/// answers it.
final class EventPreviewBridge {
  new({required this.onMessage});

  final void Function(PreviewParse message) onMessage;

  /// Development only: other origins of the panel (`vite` on its own port),
  /// comma-separated, given at build time.
  static const _extraOrigins = String.fromEnvironment('PREVIEW_PARENT_ORIGINS');

  late final Set<String> _allowed = previewAllowedOrigins(
    web.window.location.origin,
    _extraOrigins,
  );

  /// Where replies go: the origin the panel's messages came from (its own
  /// origin until then).
  String? _parentOrigin;

  void start() {
    web.window.addEventListener(
      'message',
      ((web.MessageEvent e) {
        // Only the window that embeds us.
        if (!e.source.strictEquals(web.window.parent).toDart) return;
        final data = e.data;
        final parsed = parsePreviewMessage(
          data.isA<JSString>() ? (data! as JSString).toDart : null,
          origin: e.origin,
          allowedOrigins: _allowed,
          now: DateTime.now(),
        );
        if (parsed is! PreviewIgnored) _parentOrigin = e.origin;
        onMessage(parsed);
      }).toJS,
    );
    send(previewReply(kPreviewReady));
  }

  void send(String message) {
    final parent = web.window.parent;
    if (parent == null || parent.strictEquals(web.window).toDart) return;
    final origin = _parentOrigin ?? web.window.location.origin;
    // Never '*': only an allowed origin hears us.
    if (!_allowed.contains(origin)) return;
    parent.postMessage(message.toJS, origin.toJS);
  }
}
