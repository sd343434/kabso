import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';

/// The unread messages count behind the Messages tab's badge (D130, D155):
/// unread direct messages in accepted conversations that are not muted
/// (`GET /dm/unread`, capped at 99; the bar shows "99+"). Message requests
/// are counted apart (`DmUnread.requests`) and never badge the tab. 0 when
/// signed out or with demo data (no server). v1.104-social (D339): unread
/// group messages count too (`DmUnread.groups`); archived chats do not.
/// v1.137-social (D385, owner 2026-11-12): so do the unread «دعم كابسو»
/// replies (`DmUnread.support`), cleared by reading the thread.
final Provider<int> unreadMessagesProvider = Provider<int>(
  (ref) => ref.watch(dmUnreadProvider.select((u) => u.badge)),
);
