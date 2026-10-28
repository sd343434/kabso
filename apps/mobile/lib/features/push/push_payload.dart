import 'package:kabso_live/app/router/routes.dart';

/// D152: a push as the app sees it — the FCM data the server sends
/// (CONVENTIONS §11.12): `kind` `notification` (channel `general`) or
/// `family_chat` (channel `messages`).
class PushPayload {
  const new(this.data);

  /// FCM data (string values).
  final Map<String, String> data;

  static const kindNotification = 'notification';
  static const kindFamilyChat = 'family_chat';

  String? get kind => data['kind'];

  /// The chat a `messages` push belongs to (the same id the open chat
  /// screen reports, [familyConversation]), or `null`.
  String? get conversation {
    final family = data['familyId'];
    return kind == kindFamilyChat && family != null && family.isNotEmpty
        ? familyConversation(family)
        : null;
  }

  bool get isMessage => kind == kindFamilyChat;

  /// Where a tap goes: the family chat, or the notification's target as the
  /// inbox would open it (`NotificationRow.routeTo`), else the inbox. `null`
  /// for a push this app does not know.
  String? route() {
    switch (kind) {
      case kindFamilyChat:
        final family = data['familyId'];
        return family == null || family.isEmpty
            ? null
            : AppRoutes.familyChat(family);
      case kindNotification:
        return _notificationRoute() ?? AppRoutes.notifications;
      default:
        return null;
    }
  }

  String? _notificationRoute() {
    final type = data['type'];
    final targetType = data['targetType'];
    final id = data['targetId'];
    if (type == 'CONTENT_REMOVED') return null;
    if (type == 'CP_REQUEST' || type == 'CP_ACCEPTED') return AppRoutes.cp;
    if (type == 'MEDAL_AWARDED') return AppRoutes.medals;
    if (id == null || id.isEmpty) return null;
    final postId = data['targetPostId'];
    final actor = data['actorUsername'];
    return switch (targetType) {
      'PREMIUM_USERNAME' => AppRoutes.premium,
      'POST' => AppRoutes.post(id),
      'COMMENT' when postId != null && postId.isNotEmpty => AppRoutes.post(
        postId,
        comments: true,
      ),
      'STORY' when actor != null && actor.isNotEmpty => AppRoutes.stories(
        actor,
      ),
      'USER' => AppRoutes.userProfile(id),
      'FAMILY' => AppRoutes.family(id),
      'MEDAL' => AppRoutes.medals,
      _ => null,
    };
  }
}

/// The conversation id of a family's chat (the server's Android tag).
String familyConversation(String familyId) => 'family:$familyId';
