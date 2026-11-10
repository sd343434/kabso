import 'package:kabso_live/preview/event_preview_protocol.dart';

/// No parent window outside the browser.
final class EventPreviewBridge {
  new({required this.onMessage});

  final void Function(PreviewParse message) onMessage;

  void start() {}

  void send(String message) {}
}
