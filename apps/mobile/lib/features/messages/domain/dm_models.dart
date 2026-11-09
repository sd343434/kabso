import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart'
    show LiveChatMedia;
import 'package:kabso_live/features/live/domain/live_gift_models.dart'
    show LuckyGiftResult;
import 'package:material_ui/material_ui.dart' show immutable;

/// Direct messages (docs/contracts/openapi.yaml v1.40-social DRAFT, tag
/// `messages`, D155; CONVENTIONS §11.13). Every message lives 24 hours.

/// `DmMessageKind`; [unknown] for a kind this app does not know.
enum DmMessageKind {
  text('TEXT'),
  image('IMAGE'),
  voice('VOICE'),
  emoji('EMOJI'),
  gift('GIFT'),
  unknown('');

  new(this.wire);

  final String wire;

  static DmMessageKind fromWire(Object? v) =>
      values.firstWhere((k) => k.wire == v, orElse: () => unknown);
}

/// `DmConversationStatus`: the caller's side of a conversation.
enum DmConversationStatus {
  accepted('ACCEPTED'),

  /// A message request waiting for the caller («طلبات المراسلة»).
  requestReceived('REQUEST_RECEIVED'),

  /// The caller wrote; the other side has not accepted yet.
  requestSent('REQUEST_SENT');

  new(this.wire);

  final String wire;

  static DmConversationStatus fromWire(Object? v) =>
      values.firstWhere((s) => s.wire == v, orElse: () => accepted);
}

/// Why the caller cannot write (`DmPeer.reason`).
enum DmBlockedReason {
  /// The person's «who can message you» does not allow the caller.
  notAllowed,

  /// The caller used the messages of a request that is not answered yet.
  requestLimit;

  static DmBlockedReason? fromWire(Object? v) => switch (v) {
    'NOT_ALLOWED' => notAllowed,
    'REQUEST_LIMIT' => requestLimit,
    _ => null,
  };
}

/// `DmGift`: a gift sent in the conversation (the name comes from the
/// catalogue).
@immutable
class DmGift {
  const new({
    required this.giftCode,
    required this.assetKey,
    required this.quantity,
    required this.unitPrice,
    required this.totalCoins,
    this.imageUrl,
    this.luckyCoinsWon,
    this.luckyTopMultiplier,
  });

  factory fromJson(Map<String, dynamic> json) {
    final lucky = json['lucky'] as Map<String, dynamic>?;
    return DmGift(
      giftCode: json['giftCode']! as String,
      assetKey: json['assetKey']! as String,
      imageUrl: json['imageUrl'] as String?,
      quantity: json['quantity']! as int,
      unitPrice: json['unitPrice']! as int,
      totalCoins: (json['totalCoins']! as num).toInt(),
      luckyCoinsWon: (lucky?['coinsWon'] as num?)?.toInt(),
      luckyTopMultiplier: lucky?['topMultiplier'] as int?,
    );
  }

  final String giftCode;
  final String assetKey;
  final String? imageUrl;
  final int quantity;
  final int unitPrice;
  final int totalCoins;

  /// A lucky gift: the coins its draws paid (null for other gifts).
  final int? luckyCoinsWon;
  final int? luckyTopMultiplier;

  bool get lucky => luckyCoinsWon != null;
}

/// `DmMessage`.
@immutable
class DmMessage {
  const new({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.mine,
    required this.kind,
    required this.createdAt,
    required this.expiresAt,
    this.text,
    this.token,
    this.media,
    this.gift,
    this.read = false,
  });

  factory fromJson(Map<String, dynamic> json) {
    final media = json['media'] as Map<String, dynamic>?;
    final gift = json['gift'] as Map<String, dynamic>?;
    return DmMessage(
      id: json['id']! as String,
      conversationId: json['conversationId']! as String,
      senderId: json['senderId']! as String,
      mine: json['mine']! as bool,
      kind: DmMessageKind.fromWire(json['kind']),
      text: json['text'] as String?,
      token: json['token'] as String?,
      media: media == null ? null : LiveChatMedia.fromJson(media),
      gift: gift == null ? null : DmGift.fromJson(gift),
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt']! as String),
      expiresAt: DateTime.parse(json['expiresAt']! as String),
    );
  }

  final String id;
  final String conversationId;
  final String senderId;

  /// The caller sent it.
  final bool mine;
  final DmMessageKind kind;
  final String? text;

  /// `EMOJI`: the pack emoji token `:<pack>_<id>:`.
  final String? token;
  final LiveChatMedia? media;
  final DmGift? gift;

  /// On the caller's own messages: the peer has read it (✓✓).
  final bool read;
  final DateTime createdAt;

  /// Sent + 24 h: the message is deleted then (D155, owner).
  final DateTime expiresAt;
}

/// `DmConversation`.
@immutable
class DmConversation {
  const new({
    required this.id,
    required this.peer,
    required this.status,
    required this.lastActivityAt,
    this.muted = false,
    this.markedUnread = false,
    this.archived = false,
    this.unreadCount = 0,
    this.lastMessage,
    this.peerReadAt,
    this.canSend = true,
    this.requestMessagesLeft,
  });

  factory fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'] as Map<String, dynamic>?;
    final read = json['peerReadAt'] as String?;
    return DmConversation(
      id: json['id']! as String,
      peer: UserSummary.fromJson(json['peer']! as Map<String, dynamic>),
      status: DmConversationStatus.fromWire(json['status']),
      muted: json['muted'] as bool? ?? false,
      markedUnread: json['markedUnread'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      unreadCount: json['unreadCount'] as int? ?? 0,
      lastMessage: last == null ? null : DmMessage.fromJson(last),
      lastActivityAt: DateTime.parse(json['lastActivityAt']! as String),
      peerReadAt: read == null ? null : DateTime.parse(read),
      canSend: json['canSend'] as bool? ?? true,
      requestMessagesLeft: json['requestMessagesLeft'] as int?,
    );
  }

  final String id;
  final UserSummary peer;
  final DmConversationStatus status;
  final bool muted;

  /// v1.43.1-social (D165): the caller marked it unread (a dot until read).
  final bool markedUnread;

  /// v1.103-social (D339): the caller archived it «المؤرشفة».
  final bool archived;

  /// Unread for the caller: unread messages or the mark (D165).
  bool get isUnread => unreadCount > 0 || markedUnread;

  /// 0–99 (the row shows "99+").
  final int unreadCount;

  /// The newest message still readable (null after 24 h or deletion).
  final DmMessage? lastMessage;
  final DateTime lastActivityAt;
  final DateTime? peerReadAt;
  final bool canSend;

  /// `REQUEST_SENT` only: messages the caller may still send.
  final int? requestMessagesLeft;

  DmConversation copyWith({
    bool? muted,
    DmConversationStatus? status,
    bool? markedUnread,
    bool? archived,
    int? unreadCount,
  }) => DmConversation(
    id: id,
    peer: peer,
    status: status ?? this.status,
    muted: muted ?? this.muted,
    markedUnread: markedUnread ?? this.markedUnread,
    archived: archived ?? this.archived,
    unreadCount: unreadCount ?? this.unreadCount,
    lastMessage: lastMessage,
    lastActivityAt: lastActivityAt,
    peerReadAt: peerReadAt,
    canSend: canSend,
    requestMessagesLeft: requestMessagesLeft,
  );
}

/// A page of conversations.
@immutable
class DmConversationPage {
  const new(this.data, this.nextCursor);

  final List<DmConversation> data;
  final String? nextCursor;
}

/// `DmMessagePage`: newest first, with the conversation's state.
@immutable
class DmMessagePage {
  const new({
    required this.data,
    required this.nextCursor,
    required this.conversation,
  });

  factory fromJson(Map<String, dynamic> json) => DmMessagePage(
    data: [
      for (final m in json['data']! as List<dynamic>)
        DmMessage.fromJson(m as Map<String, dynamic>),
    ],
    nextCursor:
        (json['page']! as Map<String, dynamic>)['nextCursor'] as String?,
    conversation: DmConversation.fromJson(
      json['conversation']! as Map<String, dynamic>,
    ),
  );

  final List<DmMessage> data;
  final String? nextCursor;
  final DmConversation conversation;
}

/// `DmUnread`: the Messages tab badge ([messages] + [groups]) and the
/// requests count.
@immutable
class DmUnread {
  const new({
    this.messages = 0,
    this.conversations = 0,
    this.requests = 0,
    this.groups = 0,
  });

  factory fromJson(Map<String, dynamic> json) => DmUnread(
    messages: json['messages'] as int? ?? 0,
    conversations: json['conversations'] as int? ?? 0,
    requests: json['requests'] as int? ?? 0,
    groups: json['groups'] as int? ?? 0,
  );

  final int messages;
  final int conversations;
  final int requests;

  /// v1.103-social (D339): unread group messages (not muted or archived).
  final int groups;

  /// The tab badge: direct and group messages, capped at 99.
  int get badge => (messages + groups).clamp(0, 99);

  @override
  bool operator ==(Object other) =>
      other is DmUnread &&
      other.messages == messages &&
      other.conversations == conversations &&
      other.requests == requests &&
      other.groups == groups;

  @override
  int get hashCode => Object.hash(messages, conversations, requests, groups);
}

/// `DmPeer`: the person, the conversation if any, and whether the caller
/// may write.
@immutable
class DmPeer {
  const new({
    required this.user,
    required this.canMessage,
    this.conversation,
    this.reason,
    this.asRequest = false,
  });

  factory fromJson(Map<String, dynamic> json) {
    final conversation = json['conversation'] as Map<String, dynamic>?;
    return DmPeer(
      user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
      conversation: conversation == null
          ? null
          : DmConversation.fromJson(conversation),
      canMessage: json['canMessage'] as bool? ?? false,
      reason: DmBlockedReason.fromWire(json['reason']),
      asRequest: json['asRequest'] as bool? ?? false,
    );
  }

  final UserSummary user;
  final DmConversation? conversation;
  final bool canMessage;
  final DmBlockedReason? reason;

  /// The caller's next message would be a message request.
  final bool asRequest;
}

/// `DmSendResult` / `DmGiftResult`.
@immutable
class DmSendResult {
  const new({
    required this.message,
    required this.conversation,
    this.coins,
    this.bagQuantity,
    this.luckyResult,
  });

  factory fromJson(Map<String, dynamic> json) {
    final lucky = json['luckyResult'] as Map<String, dynamic>?;
    return DmSendResult(
      message: DmMessage.fromJson(json['message']! as Map<String, dynamic>),
      conversation: DmConversation.fromJson(
        json['conversation']! as Map<String, dynamic>,
      ),
      coins: (json['coins'] as num?)?.toInt(),
      bagQuantity: json['bagQuantity'] as int?,
      luckyResult: lucky == null ? null : LuckyGiftResult.fromJson(lucky),
    );
  }

  final DmMessage message;
  final DmConversation conversation;

  /// Gifts only: the balance and the bag after the send, and a lucky gift's
  /// draws.
  final int? coins;
  final int? bagQuantity;
  final LuckyGiftResult? luckyResult;
}

/// What the composer sends (the first message creates the conversation).
sealed class DmOutgoing {
  const new();
}

final class DmOutgoingText extends DmOutgoing {
  const new(this.text);
  final String text;
}

final class DmOutgoingEmoji extends DmOutgoing {
  const new(this.token);
  final String token;
}

/// A picture or voice note already uploaded (`DM_IMAGE` / `DM_VOICE`).
final class DmOutgoingMedia extends DmOutgoing {
  const new(this.mediaId, {required this.voice});
  final String mediaId;
  final bool voice;
}

// ---- v1.103-social (DRAFT, D339): archived chats and group messages ------
// (CONVENTIONS §10.132, §10.133).

/// `DmGroupRole`.
enum DmGroupRole {
  admin('ADMIN'),
  member('MEMBER');

  new(this.wire);

  final String wire;

  static DmGroupRole fromWire(Object? v) => v == 'ADMIN' ? admin : member;
}

/// `DmGroupMessage`: a message in a group (no gifts).
@immutable
class DmGroupMessage {
  const new({
    required this.id,
    required this.groupId,
    required this.mine,
    required this.kind,
    required this.createdAt,
    required this.expiresAt,
    this.sender,
    this.text,
    this.token,
    this.media,
    this.readCount = 0,
  });

  factory fromJson(Map<String, dynamic> json) {
    final media = json['media'] as Map<String, dynamic>?;
    final sender = json['sender'] as Map<String, dynamic>?;
    return DmGroupMessage(
      id: json['id']! as String,
      groupId: json['groupId']! as String,
      sender: sender == null ? null : UserSummary.fromJson(sender),
      mine: json['mine']! as bool,
      kind: DmMessageKind.fromWire(json['kind']),
      text: json['text'] as String?,
      token: json['token'] as String?,
      media: media == null ? null : LiveChatMedia.fromJson(media),
      readCount: json['readCount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt']! as String),
      expiresAt: DateTime.parse(json['expiresAt']! as String),
    );
  }

  final String id;
  final String groupId;

  /// Null when the sender's account is gone.
  final UserSummary? sender;
  final bool mine;
  final DmMessageKind kind;
  final String? text;
  final String? token;
  final LiveChatMedia? media;

  /// On the caller's own messages: how many other members have read it.
  final int readCount;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// The same message as a conversation bubble shows it ([read]: every
  /// other member has read it, ✓✓).
  DmMessage asDmMessage({required bool read}) => DmMessage(
    id: id,
    conversationId: groupId,
    senderId: sender?.id ?? '',
    mine: mine,
    kind: kind,
    text: text,
    token: token,
    media: media,
    read: read,
    createdAt: createdAt,
    expiresAt: expiresAt,
  );
}

/// `DmGroup`: a group as the caller sees it.
@immutable
class DmGroup {
  const new({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.role,
    required this.lastActivityAt,
    required this.createdAt,
    this.photoUrl,
    this.muted = false,
    this.archived = false,
    this.unreadCount = 0,
    this.lastMessage,
  });

  factory fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'] as Map<String, dynamic>?;
    return DmGroup(
      id: json['id']! as String,
      name: json['name']! as String,
      photoUrl: json['photoUrl'] as String?,
      memberCount: json['memberCount'] as int? ?? 1,
      role: DmGroupRole.fromWire(json['role']),
      muted: json['muted'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      unreadCount: json['unreadCount'] as int? ?? 0,
      lastMessage: last == null ? null : DmGroupMessage.fromJson(last),
      lastActivityAt: DateTime.parse(json['lastActivityAt']! as String),
      createdAt: DateTime.parse(json['createdAt']! as String),
    );
  }

  final String id;
  final String name;
  final String? photoUrl;
  final int memberCount;

  /// The caller's role.
  final DmGroupRole role;
  final bool muted;
  final bool archived;
  final int unreadCount;
  final DmGroupMessage? lastMessage;
  final DateTime lastActivityAt;
  final DateTime createdAt;

  bool get isAdmin => role == DmGroupRole.admin;

  DmGroup copyWith({
    String? name,
    String? photoUrl,
    bool clearPhoto = false,
    bool? muted,
    bool? archived,
    int? unreadCount,
    int? memberCount,
    DmGroupRole? role,
    DmGroupMessage? lastMessage,
    DateTime? lastActivityAt,
  }) => DmGroup(
    id: id,
    name: name ?? this.name,
    photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
    memberCount: memberCount ?? this.memberCount,
    role: role ?? this.role,
    muted: muted ?? this.muted,
    archived: archived ?? this.archived,
    unreadCount: unreadCount ?? this.unreadCount,
    lastMessage: lastMessage ?? this.lastMessage,
    lastActivityAt: lastActivityAt ?? this.lastActivityAt,
    createdAt: createdAt,
  );
}

/// `DmGroupMember`.
@immutable
class DmGroupMember {
  const new({
    required this.user,
    required this.role,
    required this.joinedAt,
    this.creator = false,
  });

  factory fromJson(Map<String, dynamic> json) => DmGroupMember(
    user: UserSummary.fromJson(json['user']! as Map<String, dynamic>),
    role: DmGroupRole.fromWire(json['role']),
    creator: json['creator'] as bool? ?? false,
    joinedAt: DateTime.parse(json['joinedAt']! as String),
  );

  final UserSummary user;
  final DmGroupRole role;
  final bool creator;
  final DateTime joinedAt;
}

/// `DmGroupDetail`: the group, its members and the cap.
@immutable
class DmGroupDetail {
  const new({
    required this.group,
    required this.members,
    required this.maxMembers,
  });

  factory fromJson(Map<String, dynamic> json) => DmGroupDetail(
    group: DmGroup.fromJson(json['group']! as Map<String, dynamic>),
    members: [
      for (final m in json['members']! as List<dynamic>)
        DmGroupMember.fromJson(m as Map<String, dynamic>),
    ],
    maxMembers: json['maxMembers'] as int? ?? 100,
  );

  final DmGroup group;
  final List<DmGroupMember> members;
  final int maxMembers;
}

/// `DmGroupMessagePage`: newest first, with the group's state.
@immutable
class DmGroupMessagePage {
  const new({
    required this.data,
    required this.nextCursor,
    required this.group,
  });

  factory fromJson(Map<String, dynamic> json) => DmGroupMessagePage(
    data: [
      for (final m in json['data']! as List<dynamic>)
        DmGroupMessage.fromJson(m as Map<String, dynamic>),
    ],
    nextCursor:
        (json['page']! as Map<String, dynamic>)['nextCursor'] as String?,
    group: DmGroup.fromJson(json['group']! as Map<String, dynamic>),
  );

  final List<DmGroupMessage> data;
  final String? nextCursor;
  final DmGroup group;
}

/// `DmGroupSendResult`.
@immutable
class DmGroupSendResult {
  const new({required this.message, required this.group});

  factory fromJson(Map<String, dynamic> json) => DmGroupSendResult(
    message: DmGroupMessage.fromJson(json['message']! as Map<String, dynamic>),
    group: DmGroup.fromJson(json['group']! as Map<String, dynamic>),
  );

  final DmGroupMessage message;
  final DmGroup group;
}

/// `DmChat`: one row of «الدردشات» / «المؤرشفة» — a conversation or a group.
@immutable
class DmChat {
  const new direct(DmConversation this.conversation) : group = null;
  const new group(DmGroup this.group) : conversation = null;

  /// Null for a type this app does not know.
  static DmChat? fromJson(Map<String, dynamic> json) {
    final c = json['conversation'] as Map<String, dynamic>?;
    final g = json['group'] as Map<String, dynamic>?;
    return switch (json['type']) {
      'DIRECT' when c != null => DmChat.direct(DmConversation.fromJson(c)),
      'GROUP' when g != null => DmChat.group(DmGroup.fromJson(g)),
      _ => null,
    };
  }

  final DmConversation? conversation;
  final DmGroup? group;

  String get id => conversation?.id ?? group!.id;
  bool get isGroup => group != null;
  DateTime get lastActivityAt =>
      conversation?.lastActivityAt ?? group!.lastActivityAt;
}

/// A page of chats.
@immutable
class DmChatPage {
  const new(this.data, this.nextCursor);

  final List<DmChat> data;
  final String? nextCursor;
}
