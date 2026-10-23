import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/notifications/data/notifications_repository.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:material_ui/material_ui.dart';

/// How often the badge refreshes while the app is open (CP-009 §3: there is
/// no realtime channel yet).
const Duration unreadPollInterval = Duration(seconds: 60);

/// The unread count for the bell (0–99; the badge shows "99+" at 99). It
/// loads when first watched, then every [unreadPollInterval] and whenever
/// the app comes back to the foreground. A failed refresh keeps the last
/// count: the badge is a hint, never an error.
class UnreadNotifications extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    final repo = ref.watch(notificationsRepositoryProvider);
    final signedIn =
        ref.watch(currentUserProvider.select((u) => u?.id)) != null;
    if (!signedIn) return 0;
    _timer = Timer.periodic(unreadPollInterval, (_) => unawaited(refresh()));
    final lifecycle = AppLifecycleListener(
      onResume: () => unawaited(refresh()),
    );
    ref.onDispose(() {
      _timer?.cancel();
      lifecycle.dispose();
    });
    unawaited(_load(repo));
    return 0;
  }

  Future<void> _load(NotificationsRepository repo) async {
    try {
      final count = await repo.unreadCount();
      if (ref.mounted) state = count;
    } on Object {
      // Keep the last count.
    }
  }

  /// Asks the server again.
  Future<void> refresh() => _load(ref.read(notificationsRepositoryProvider));

  /// Everything was just marked read here.
  void clear() => state = 0;
}

final NotifierProvider<UnreadNotifications, int> unreadNotificationsProvider =
    NotifierProvider.autoDispose(UnreadNotifications.new);

/// The inbox (`GET /notifications`), newest activity first, paged. The
/// first load marks everything read on the server (the rows keep their
/// unread look for this visit) and clears the badge.
class NotificationsInbox extends AsyncNotifier<FeedItems<AppNotification>> {
  String? _next;

  @override
  Future<FeedItems<AppNotification>> build() async {
    final repo = ref.watch(notificationsRepositoryProvider);
    ref.watch(currentUserProvider.select((u) => u?.id));
    final page = await repo.list();
    _next = page.next;
    final items = [
      for (final n in page.items)
        if (n.type != NotificationType.unknown) n,
    ];
    if (page.items.any((n) => !n.read)) unawaited(_markAllRead(repo));
    return FeedItems(items, hasMore: _next != null);
  }

  Future<void> _markAllRead(NotificationsRepository repo) async {
    try {
      await repo.markRead();
      if (ref.mounted) ref.read(unreadNotificationsProvider.notifier).clear();
    } on Object {
      // The next visit tries again; the badge keeps the server's count.
    }
  }

  /// The next page, when one exists and none is loading.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(FeedItems(s.items, hasMore: true, loadingMore: true));
    try {
      final page = await ref
          .read(notificationsRepositoryProvider)
          .list(cursor: _next);
      if (!ref.mounted) return;
      _next = page.next;
      final known = {for (final n in s.items) n.id};
      state = AsyncData(
        FeedItems([
          ...s.items,
          for (final n in page.items)
            if (!known.contains(n.id) && n.type != NotificationType.unknown) n,
        ], hasMore: _next != null),
      );
    } on Object catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(FeedItems(s.items, hasMore: true, loadMoreError: e));
    }
  }
}

final AsyncNotifierProvider<NotificationsInbox, FeedItems<AppNotification>>
notificationsInboxProvider = AsyncNotifierProvider.autoDispose(
  NotificationsInbox.new,
);

/// `/me/notification-settings`; a switch changes at once and goes back if
/// the server refuses.
class NotificationSettingsController
    extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() {
    ref.watch(currentUserProvider.select((u) => u?.id));
    return ref.watch(notificationsRepositoryProvider).settings();
  }

  /// Sends the change; on failure restores the old value and rethrows its
  /// `AppFailure`.
  Future<void> change(NotificationSetting setting, {required bool on}) async {
    final before = state.value;
    if (before == null || setting.of(before) == on) return;
    state = AsyncData(setting.set(before, on: on));
    try {
      final saved = await ref
          .read(notificationsRepositoryProvider)
          .updateSetting(setting, on: on);
      if (ref.mounted) state = AsyncData(saved);
    } on Object {
      if (ref.mounted) state = AsyncData(before);
      rethrow;
    }
  }
}

final AsyncNotifierProvider<
  NotificationSettingsController,
  NotificationSettings
>
notificationSettingsProvider = AsyncNotifierProvider.autoDispose(
  NotificationSettingsController.new,
);
