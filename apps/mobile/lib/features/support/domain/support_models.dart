import 'package:kabso_live/features/live/domain/live_chat.dart'
    show LiveChatMedia;
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart'
    show WaDepartment;
import 'package:material_ui/material_ui.dart' show immutable;

/// v1.137-social (D385, CONVENTIONS §10.174): «دعم كابسو» — the person's
/// in-app support thread with the Kabso Team, and the chats pinned at the
/// top of «الرسائل». The shapes of `/support/thread*` (tag `support`) and
/// `/dm/pins` (tag `messages`).

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// `SupportThread.status`: none yet, a ticket open, or closed by the team.
enum SupportThreadStatus {
  none('NONE'),
  open('OPEN'),
  closed('CLOSED');

  new(this.wire);

  final String wire;

  static SupportThreadStatus fromWire(Object? v) => values.firstWhere(
    (s) => s.wire == v,
    orElse: () => SupportThreadStatus.none,
  );
}

/// `SupportThread` (§10.174.1).
@immutable
class SupportThread {
  const new({
    required this.status,
    this.id,
    this.department,
    this.unreadCount = 0,
    this.lastMessageAt,
    this.lastPreview,
  });

  factory fromJson(Map<String, dynamic> j) => SupportThread(
    id: j['id'] as String?,
    status: SupportThreadStatus.fromWire(j['status']),
    department: j['department'] == null
        ? null
        : WaDepartment.fromWire(j['department']),
    unreadCount: (j['unreadCount'] as num?)?.toInt() ?? 0,
    lastMessageAt: _date(j['lastMessageAt']),
    lastPreview: j['lastPreview'] as String?,
  );

  /// Before the first message (and while the server cannot be read).
  static const empty = SupportThread(status: SupportThreadStatus.none);

  final String? id;
  final SupportThreadStatus status;
  final WaDepartment? department;

  /// The team's replies the person has not read (≤ 99).
  final int unreadCount;
  final DateTime? lastMessageAt;
  final String? lastPreview;

  /// The next message opens a ticket: the person picks its topic first.
  bool get needsTopic => status != SupportThreadStatus.open;
}

/// `SupportMessage.receipt`: the person's own message is with the team
/// («تم الاستلام»), then read by them.
enum SupportReceipt { received, read }

/// `SupportMessage` (§10.174.2).
@immutable
class SupportMessage {
  const new({
    required this.id,
    required this.mine,
    required this.kind,
    required this.createdAt,
    this.text,
    this.media,
    this.staffFirstName,
    this.receipt,
  });

  factory fromJson(Map<String, dynamic> j) {
    final media = j['media'] as Map<String, dynamic>?;
    final staff = j['staff'] as Map<String, dynamic>?;
    return SupportMessage(
      id: j['id']! as String,
      mine: j['mine'] as bool? ?? false,
      kind: switch (j['kind']) {
        'IMAGE' => DmMessageKind.image,
        'VOICE' => DmMessageKind.voice,
        'TEXT' => DmMessageKind.text,
        _ => DmMessageKind.unknown,
      },
      text: j['text'] as String?,
      media: media == null ? null : LiveChatMedia.fromJson(media),
      staffFirstName: staff?['firstName'] as String?,
      receipt: switch (j['receipt']) {
        'READ' => SupportReceipt.read,
        'RECEIVED' => SupportReceipt.received,
        _ => null,
      },
      createdAt: _date(j['createdAt']) ?? DateTime.now(),
    );
  }

  final String id;
  final bool mine;
  final DmMessageKind kind;
  final String? text;
  final LiveChatMedia? media;

  /// The team's replies: the staff member's first name only (may be null:
  /// the «فريق كابسو» badge alone). Never their account.
  final String? staffFirstName;
  final SupportReceipt? receipt;
  final DateTime createdAt;

  /// The DM bubbles draw it (D385 reuses the conversation's components).
  DmMessage toDm(String threadId) => DmMessage(
    id: id,
    conversationId: threadId,
    senderId: mine ? 'me' : 'team',
    mine: mine,
    kind: kind,
    text: text,
    media: media,
    read: receipt == SupportReceipt.read,
    createdAt: createdAt,
    // Support messages do not expire after 24 hours (§10.174.7).
    expiresAt: createdAt.add(const Duration(days: 180)),
  );
}

/// A page of the thread, newest first.
@immutable
class SupportMessagePage {
  const new({required this.data, required this.thread, this.nextCursor});

  factory fromJson(Map<String, dynamic> j) => SupportMessagePage(
    data: [
      for (final m in j['data']! as List<dynamic>)
        SupportMessage.fromJson(m as Map<String, dynamic>),
    ],
    nextCursor: (j['page'] as Map<String, dynamic>?)?['nextCursor'] as String?,
    thread: SupportThread.fromJson(j['thread']! as Map<String, dynamic>),
  );

  final List<SupportMessage> data;
  final String? nextCursor;
  final SupportThread thread;
}

/// `SupportSendResult`.
@immutable
class SupportSendResult {
  const new({required this.message, required this.thread});

  factory fromJson(Map<String, dynamic> j) => SupportSendResult(
    message: SupportMessage.fromJson(j['message']! as Map<String, dynamic>),
    thread: SupportThread.fromJson(j['thread']! as Map<String, dynamic>),
  );

  final SupportMessage message;
  final SupportThread thread;
}

/// `DmPin` (§10.174.4): one pinned chat; [online] only where the server
/// allows it (§10.174.5) — null draws no dot.
@immutable
class DmPin {
  const new({required this.chat, required this.pinnedAt, this.online});

  /// Null for a chat type this app does not know.
  static DmPin? fromJson(Map<String, dynamic> j) {
    final chat = DmChat.fromJson(j['chat']! as Map<String, dynamic>);
    if (chat == null) return null;
    return DmPin(
      chat: chat,
      pinnedAt: _date(j['pinnedAt']) ?? DateTime.now(),
      online: j['online'] as bool?,
    );
  }

  final DmChat chat;
  final DateTime pinnedAt;
  final bool? online;

  String get id => chat.id;
}

/// `DmPinList`: first pinned first; at most [max] (5).
@immutable
class DmPinList {
  const new(this.data, {this.max = DmPinList.limit});

  factory fromJson(Map<String, dynamic> j) => DmPinList([
    for (final p in j['data']! as List<dynamic>)
      ?DmPin.fromJson(p as Map<String, dynamic>),
  ], max: (j['max'] as num?)?.toInt() ?? limit);

  /// `DM_PIN_MAX` (owner: «يمكن للشخص تثبيت ٥ محادثات»).
  static const limit = 5;

  final List<DmPin> data;
  final int max;

  bool contains(String chatId) => data.any((p) => p.id == chatId);
  bool get full => data.length >= max;
}

/// What the person writes to «دعم كابسو».
sealed class SupportOutgoing {
  const new();
}

final class SupportOutgoingText extends SupportOutgoing {
  const new(this.text);
  final String text;
}

final class SupportOutgoingMedia extends SupportOutgoing {
  const new(this.mediaId, {required this.voice});
  final String mediaId;
  final bool voice;
}
