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

  /// 0–99 (the row shows "99+").
  final int unreadCount;

  /// The newest message still readable (null after 24 h or deletion).
  final DmMessage? lastMessage;
  final DateTime lastActivityAt;
  final DateTime? peerReadAt;
  final bool canSend;

  /// `REQUEST_SENT` only: messages the caller may still send.
  final int? requestMessagesLeft;

  DmConversation copyWith({bool? muted, DmConversationStatus? status}) =>
      DmConversation(
        id: id,
        peer: peer,
        status: status ?? this.status,
        muted: muted ?? this.muted,
        unreadCount: unreadCount,
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

/// `DmUnread`: the Messages tab badge ([messages]) and the requests count.
@immutable
class DmUnread {
  const new({this.messages = 0, this.conversations = 0, this.requests = 0});

  factory fromJson(Map<String, dynamic> json) => DmUnread(
    messages: json['messages'] as int? ?? 0,
    conversations: json['conversations'] as int? ?? 0,
    requests: json['requests'] as int? ?? 0,
  );

  final int messages;
  final int conversations;
  final int requests;

  @override
  bool operator ==(Object other) =>
      other is DmUnread &&
      other.messages == messages &&
      other.conversations == conversations &&
      other.requests == requests;

  @override
  int get hashCode => Object.hash(messages, conversations, requests);
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
