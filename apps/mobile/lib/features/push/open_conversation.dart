import 'package:flutter_riverpod/flutter_riverpod.dart';

/// D152: the chat on screen (`family:<id>`), or `null`. A push for it plays
/// no sound and shows nothing — the open chat shows the message itself.
class OpenConversation extends Notifier<String?> {
  @override
  String? build() => null;

  void opened(String conversation) {
    if (state != conversation) state = conversation;
  }

  /// Only the chat that is still the open one clears it (a newer chat may
  /// already have taken its place).
  void closed(String conversation) {
    if (state == conversation) state = null;
  }
}

final openConversationProvider = NotifierProvider<OpenConversation, String?>(
  OpenConversation.new,
);
