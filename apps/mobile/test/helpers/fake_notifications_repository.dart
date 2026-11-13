import 'dart:async';

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/notifications/data/notifications_repository.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

/// An in-memory [NotificationsRepository] (tests only). By default the inbox
/// is empty and nothing is unread. [items] is served newest first in pages
/// of [pageSize]; [unread] answers the count; [failWith] makes the next call
/// throw; every call is recorded in [calls].
class FakeNotificationsRepository implements NotificationsRepository {
  new({this.pageSize = 20});

  final int pageSize;
  final List<String> calls = [];
  Exception? failWith;

  List<AppNotification> items = [];
  int unread = 0;
  NotificationSettings current = const NotificationSettings();

  Future<void> _step(String call) async {
    calls.add(call);
    if (failWith case final e?) {
      failWith = null;
      throw e;
    }
  }

  @override
  Future<PageOf<AppNotification>> list({String? cursor}) async {
    await _step('list:${cursor ?? ''}');
    final start = cursor == null ? 0 : int.parse(cursor);
    final end = (start + pageSize).clamp(0, items.length);
    final more = end < items.length;
    return PageOf(
      items.sublist(start, end),
      PageInfo(nextCursor: more ? '$end' : null, hasMore: more),
    );
  }

  @override
  Future<int> unreadCount() async {
    await _step('unread');
    return unread;
  }

  @override
  Future<void> markRead({List<String>? ids}) async {
    await _step(ids == null ? 'read:all' : 'read:${ids.join(',')}');
    items = [
      for (final n in items)
        if (ids == null || ids.contains(n.id)) n.asRead() else n,
    ];
    unread = items.where((n) => !n.read).length;
  }

  @override
  Future<NotificationSettings> settings() async {
    await _step('settings');
    return current;
  }

  @override
  Future<NotificationSettings> updateSetting(
    NotificationSetting setting, {
    required bool on,
  }) async {
    await _step('setting:${setting.name}:$on');
    return current = setting.set(current, on: on);
  }
}
