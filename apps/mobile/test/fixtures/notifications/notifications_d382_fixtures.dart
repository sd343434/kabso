// D382 (owner: «اجعل الإشعارات بنفس هذه الطريقة … بنفس الحجم والطريقة»):
// an inbox with every section (today, this week, earlier) and the common
// kinds — a family join accepted, a comment with its text, a follow, likes
// by several people, a reply, a live reminder and removed content —
// shaped like docs/contracts/openapi.yaml `Notification`. Synthetic people
// only; test data (G-26).

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';

/// The fixed "now" of the D382 tests and goldens (local time).
final DateTime d382Now = DateTime(2026, 11, 12, 15);

UserSummary _person(String username, String name) => UserSummary(
  id: 'u-$username',
  username: username,
  displayName: name,
  avatarUrl: null,
);

/// The inbox, newest first; the two of today are unread.
List<AppNotification> d382Notifications({required bool ar}) {
  AppNotification note(
    String id,
    NotificationType type,
    Duration ago, {
    List<UserSummary> actors = const [],
    int? actorCount,
    NotificationTarget? target,
    bool read = true,
  }) => AppNotification(
    id: id,
    type: type,
    actors: actors,
    actorCount: actorCount ?? actors.length,
    target: target,
    createdAt: d382Now.subtract(ago),
    read: read,
  );

  return [
    note(
      'family',
      NotificationType.familyJoinAccepted,
      const Duration(hours: 4),
      target: NotificationTarget(
        type: NotificationTargetType.family,
        id: 'f1',
        text: ar ? 'سهرات الطرب' : 'Tarab Nights',
      ),
      read: false,
    ),
    note(
      'comment',
      NotificationType.comment,
      const Duration(hours: 7),
      actors: [_person('sara.m', ar ? 'سارة محمد' : 'Sara Mohammed')],
      target: NotificationTarget(
        type: NotificationTargetType.comment,
        id: 'c1',
        postId: 'p1',
        text: ar
            ? 'كان البث رائعاً الليلة، تعلّمت الكثير عن الإضاءة والصوت من '
                  'المضيفين أنفسهم، وأنتظر الحلقة القادمة بفارغ الصبر حتى '
                  'نكمل الحديث'
            : 'The live was incredible tonight, I learned so much about '
                  'lighting and sound from the hosts themselves, and I '
                  'cannot wait for the next episode to keep talking',
      ),
      read: false,
    ),
    note(
      'follow',
      NotificationType.follow,
      const Duration(days: 4),
      actors: [_person('lucas.t', ar ? 'لؤي طارق' : 'Lucas Terry')],
      target: const NotificationTarget(
        type: NotificationTargetType.user,
        id: 'lucas.t',
      ),
    ),
    note(
      'likes',
      NotificationType.likePost,
      const Duration(days: 5),
      actors: [
        _person('chanel.g', ar ? 'شيماء غسان' : 'Chanel Green'),
        _person('omar', ar ? 'عمر' : 'Omar'),
      ],
      actorCount: 13,
      target: const NotificationTarget(
        type: NotificationTargetType.post,
        id: 'p2',
      ),
    ),
    note(
      'reply',
      NotificationType.reply,
      const Duration(days: 12),
      actors: [_person('jyoti', ar ? 'جود' : 'Jyoti')],
      target: NotificationTarget(
        type: NotificationTargetType.comment,
        id: 'c2',
        postId: 'p3',
        text: ar ? 'ساعتان من الموسيقى والضحك' : '2 hours of music',
      ),
    ),
    note(
      'live',
      NotificationType.liveScheduledSoon,
      const Duration(days: 20),
      actors: [_person('layla', ar ? 'ليلى' : 'Layla')],
      target: NotificationTarget(
        type: NotificationTargetType.user,
        id: 'layla',
        text: ar ? 'أغاني المساء' : 'Evening songs',
        startsAt: d382Now.subtract(const Duration(days: 20, hours: -1)),
      ),
    ),
    note(
      'removed',
      NotificationType.contentRemoved,
      const Duration(days: 26),
      target: const NotificationTarget(
        type: NotificationTargetType.post,
        id: 'p9',
      ),
    ),
  ];
}
