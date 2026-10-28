import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';

/// The unread messages count behind the Messages tab's badge (D130, D155):
/// unread direct messages in accepted conversations that are not muted
/// (`GET /dm/unread`, capped at 99; the bar shows "99+"). Message requests
/// are counted apart (`DmUnread.requests`) and never badge the tab. 0 when
/// signed out or with demo data (no server).
final Provider<int> unreadMessagesProvider = Provider<int>(
  (ref) => ref.watch(dmUnreadProvider.select((u) => u.messages)),
);
