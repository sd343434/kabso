import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';

/// The caller in DM fakes (the signed-in test user's id, `testUser()`).
const String fakeMeId = '0192f1c2-7c3a-7b2e-9a51-1d2c3b4a5e6f';

UserSummary dmPerson(
  String username, {
  String? name,
  PremiumTier? premiumTier,
}) => UserSummary(
  id: 'u-$username',
  username: username,
  displayName: name ?? username,
  avatarUrl: null,
  premiumTier: premiumTier,
);

/// An in-memory [DmRepository] (tests only): conversations by username,
/// their messages newest first; every call is recorded in [calls] and
/// [failNext] makes the named call throw once.
class FakeDmRepository implements DmRepository {
  final List<String> calls = [];
  final Map<String, Exception> failNext = {};

  /// The people that exist (username → summary).
  final Map<String, UserSummary> people = {};

  /// Conversations by peer username.
  final Map<String, DmConversation> byPeer = {};

  /// Messages by conversation id, newest first.
  final Map<String, List<DmMessage>> messagesOf = {};

  DmUnread unreadCounts = const DmUnread();

  /// What `peer` answers about writing.
  bool canMessage = true;
  DmBlockedReason? reason;
  bool asRequest = false;

  int _seq = 0;
  DateTime now = DateTime.utc(2026, 10, 28, 12);

  void _step(String call) {
    calls.add(call);
    final name = call.split(':').first;
    if (failNext.remove(name) case final e?) throw e;
  }

  /// Adds a conversation with [peer] and its [messages] (newest first).
  DmConversation addConversation(
    UserSummary peer, {
    DmConversationStatus status = DmConversationStatus.accepted,
    List<DmMessage> messages = const [],
    int unread = 0,
    bool muted = false,
    bool markedUnread = false,
    bool canSend = true,
    int? requestLeft,
  }) {
    people[peer.username] = peer;
    final id = 'c-${peer.username}';
    messagesOf[id] = [...messages];
    return byPeer[peer.username] = DmConversation(
      id: id,
      peer: peer,
      status: status,
      lastActivityAt: messages.isEmpty ? now : messages.first.createdAt,
      unreadCount: unread,
      muted: muted,
      markedUnread: markedUnread,
      lastMessage: messages.isEmpty ? null : messages.first,
      canSend: canSend,
      requestMessagesLeft: requestLeft,
    );
  }

  /// A message in conversation [conversationId].
  DmMessage message(
    String conversationId, {
    required bool mine,
    String? text = 'hello',
    DmMessageKind kind = DmMessageKind.text,
    bool read = false,
    String? id,
    String? token,
    DmGift? gift,
    DateTime? at,
  }) {
    _seq++;
    final createdAt = at ?? now.subtract(Duration(minutes: 100 - _seq));
    return DmMessage(
      id: id ?? 'm$_seq',
      conversationId: conversationId,
      senderId: mine ? fakeMeId : 'peer',
      mine: mine,
      kind: kind,
      text: kind == DmMessageKind.text ? text : null,
      token: token,
      gift: gift,
      read: read,
      createdAt: createdAt,
      expiresAt: createdAt.add(const Duration(hours: 24)),
    );
  }

  ServerFailure failure(ErrorCode code, {int status = 403}) => ServerFailure(
    code: code,
    rawCode: code.wire,
    debugMessage: code.wire,
    statusCode: status,
  );

  @override
  Future<DmConversationPage> conversations({
    bool requests = false,
    String? cursor,
    String? query,
  }) async {
    _step(
      'conversations:${requests ? 'requests' : 'inbox'}'
      '${query == null ? '' : ':q=$query'}',
    );
    final q = query?.toLowerCase();
    final list = [
      for (final c in byPeer.values)
        if ((c.status == DmConversationStatus.requestReceived) == requests &&
            (q == null ||
                c.peer.username.toLowerCase().startsWith(q) ||
                c.peer.displayName.toLowerCase().startsWith(q)))
          c,
    ]..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    return DmConversationPage(list, null);
  }

  @override
  Future<DmUnread> unread() async {
    _step('unread');
    return unreadCounts;
  }

  @override
  Future<DmPeer> peer(String username) async {
    _step('peer:$username');
    final user = people[username] ?? dmPerson(username);
    people[username] = user;
    return DmPeer(
      user: user,
      conversation: byPeer[username],
      canMessage: canMessage,
      reason: reason,
      asRequest: asRequest,
    );
  }

  @override
  Future<DmMessagePage> messages(
    String conversationId, {
    String? cursor,
  }) async {
    _step('messages:$conversationId');
    final c = byPeer.values.firstWhere((c) => c.id == conversationId);
    return DmMessagePage(
      data: [...messagesOf[conversationId] ?? const <DmMessage>[]],
      nextCursor: null,
      conversation: c,
    );
  }

  DmSendResult _store(String to, DmMessage m) {
    final c = byPeer[to] ?? addConversation(people[to] ?? dmPerson(to));
    messagesOf[c.id] = [m, ...messagesOf[c.id] ?? const <DmMessage>[]];
    final next = DmConversation(
      id: c.id,
      peer: c.peer,
      status: c.status == DmConversationStatus.requestReceived
          ? DmConversationStatus.accepted
          : (asRequest ? DmConversationStatus.requestSent : c.status),
      lastActivityAt: m.createdAt,
      lastMessage: m,
      muted: c.muted,
      canSend: c.canSend,
      requestMessagesLeft: c.requestMessagesLeft,
    );
    byPeer[to] = next;
    return DmSendResult(message: m, conversation: next);
  }

  @override
  Future<DmSendResult> send(
    String to,
    DmOutgoing message, {
    required String clientId,
  }) async {
    final desc = switch (message) {
      DmOutgoingText(:final text) => 'text:$text',
      DmOutgoingEmoji(:final token) => 'emoji:$token',
      DmOutgoingMedia(:final mediaId, :final voice) =>
        '${voice ? 'voice' : 'image'}:$mediaId',
    };
    _step('send:$to:$desc');
    final id = 'c-$to';
    _seq++;
    final at = now.add(Duration(seconds: _seq));
    return _store(
      to,
      DmMessage(
        id: 'sent-$_seq',
        conversationId: id,
        senderId: fakeMeId,
        mine: true,
        kind: switch (message) {
          DmOutgoingText() => DmMessageKind.text,
          DmOutgoingEmoji() => DmMessageKind.emoji,
          DmOutgoingMedia(:final voice) =>
            voice ? DmMessageKind.voice : DmMessageKind.image,
        },
        text: message is DmOutgoingText ? message.text : null,
        token: message is DmOutgoingEmoji ? message.token : null,
        createdAt: at,
        expiresAt: at.add(const Duration(hours: 24)),
      ),
    );
  }

  @override
  Future<DmSendResult> sendGift(
    String to, {
    required String giftCode,
    required int quantity,
    required LiveGiftSource source,
    required String clientId,
  }) async {
    _step('sendGift:$to:$giftCode:$quantity');
    _seq++;
    final at = now.add(Duration(seconds: _seq));
    final result = _store(
      to,
      DmMessage(
        id: 'gift-$_seq',
        conversationId: 'c-$to',
        senderId: fakeMeId,
        mine: true,
        kind: DmMessageKind.gift,
        gift: DmGift(
          giftCode: giftCode,
          assetKey: 'gift_$giftCode',
          quantity: quantity,
          unitPrice: 10,
          totalCoins: 10 * quantity,
        ),
        createdAt: at,
        expiresAt: at.add(const Duration(hours: 24)),
      ),
    );
    return DmSendResult(
      message: result.message,
      conversation: result.conversation,
      coins: 90,
      bagQuantity: 0,
    );
  }

  @override
  Future<void> markRead(String conversationId, String lastMessageId) async {
    _step('markRead:$conversationId:$lastMessageId');
    for (final e in byPeer.entries.toList()) {
      if (e.value.id == conversationId) {
        byPeer[e.key] = e.value.copyWith(markedUnread: false);
      }
    }
  }

  @override
  Future<void> accept(String conversationId) async {
    _step('accept:$conversationId');
    final entry = byPeer.entries.firstWhere(
      (e) => e.value.id == conversationId,
    );
    byPeer[entry.key] = entry.value.copyWith(
      status: DmConversationStatus.accepted,
    );
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    _step('deleteConversation:$conversationId');
    byPeer.removeWhere((_, c) => c.id == conversationId);
  }

  @override
  Future<void> setMuted(String conversationId, {required bool muted}) async {
    _step('mute:$conversationId:$muted');
    for (final e in byPeer.entries.toList()) {
      if (e.value.id == conversationId) {
        byPeer[e.key] = e.value.copyWith(muted: muted);
      }
    }
  }

  @override
  Future<void> setMarkedUnread(
    String conversationId, {
    required bool marked,
  }) async {
    _step('markUnread:$conversationId:$marked');
    for (final e in byPeer.entries.toList()) {
      if (e.value.id == conversationId) {
        byPeer[e.key] = e.value.copyWith(markedUnread: marked);
      }
    }
  }

  @override
  Future<void> deleteMessage(
    String messageId, {
    required bool forEveryone,
  }) async {
    _step('deleteMessage:$messageId:${forEveryone ? 'everyone' : 'me'}');
    for (final list in messagesOf.values) {
      list.removeWhere((m) => m.id == messageId);
    }
  }

  @override
  Future<void> reportMessage(String messageId, ReportReason reason) async =>
      _step('report:$messageId:${reason.wire}');
}
