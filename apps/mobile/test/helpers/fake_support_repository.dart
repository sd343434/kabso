import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/support/data/support_repository.dart';
import 'package:kabso_live/features/support/domain/support_models.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart';

/// An in-memory [SupportRepository] (tests only, D385): the person's
/// «دعم كابسو» thread and its messages (newest first). Every call is
/// recorded in [calls]; the rules mirror the server's (§10.174.3): no open
/// ticket and no topic → 400 `topic`.
class FakeSupportRepository implements SupportRepository {
  new({SupportThread? thread, List<SupportMessage>? messages})
    : thread_ = thread ?? SupportThread.empty,
      messages_ = [...?messages];

  final List<String> calls = [];
  SupportThread thread_;
  final List<SupportMessage> messages_;
  int _seq = 0;

  /// The topic of the last send (null: none).
  WaDepartment? lastTopic;

  /// A staff reply arrives (newest first); the thread counts it unread.
  void reply(String text, {String? firstName = 'Sara'}) {
    _seq++;
    messages_.insert(
      0,
      SupportMessage(
        id: 'r$_seq',
        mine: false,
        kind: DmMessageKind.text,
        text: text,
        staffFirstName: firstName,
        createdAt: DateTime.utc(2026, 11, 12, 10, _seq),
      ),
    );
    thread_ = SupportThread(
      id: thread_.id ?? 't1',
      status: SupportThreadStatus.open,
      department: thread_.department,
      unreadCount: thread_.unreadCount + 1,
      lastMessageAt: DateTime.utc(2026, 11, 12, 10, _seq),
      lastPreview: text,
    );
  }

  @override
  Future<SupportThread> thread() async {
    calls.add('thread');
    return thread_;
  }

  @override
  Future<SupportMessagePage> messages({String? cursor}) async {
    calls.add('messages');
    return SupportMessagePage(data: [...messages_], thread: thread_);
  }

  @override
  Future<SupportSendResult> send(
    SupportOutgoing message, {
    required String clientId,
    WaDepartment? topic,
  }) async {
    calls.add('send:${topic?.wire ?? '-'}');
    lastTopic = topic;
    if (thread_.needsTopic && topic == null) {
      throw const ServerFailure(
        code: ErrorCode.validationFailed,
        rawCode: 'VALIDATION_FAILED',
        debugMessage: 'topic required',
        statusCode: 400,
        details: [FieldIssue(field: 'topic', issue: 'required')],
      );
    }
    _seq++;
    final m = SupportMessage(
      id: 'm$_seq',
      mine: true,
      kind: switch (message) {
        SupportOutgoingText() => DmMessageKind.text,
        SupportOutgoingMedia(:final voice) =>
          voice ? DmMessageKind.voice : DmMessageKind.image,
      },
      text: switch (message) {
        SupportOutgoingText(:final text) => text,
        SupportOutgoingMedia() => null,
      },
      receipt: SupportReceipt.received,
      createdAt: DateTime.utc(2026, 11, 12, 9, _seq),
    );
    messages_.insert(0, m);
    thread_ = SupportThread(
      id: thread_.id ?? 't1',
      status: SupportThreadStatus.open,
      department: thread_.needsTopic ? topic : thread_.department,
      unreadCount: thread_.unreadCount,
      lastMessageAt: m.createdAt,
      lastPreview: m.text,
    );
    return SupportSendResult(message: m, thread: thread_);
  }

  @override
  Future<void> read() async {
    calls.add('read');
    thread_ = SupportThread(
      id: thread_.id,
      status: thread_.status,
      department: thread_.department,
      lastMessageAt: thread_.lastMessageAt,
      lastPreview: thread_.lastPreview,
    );
  }
}

/// An in-memory [DmPinsRepository] (tests only, D385): pins in pin order,
/// at most five (a 6th → 409 `DM_PIN_LIMIT`, as the server).
class FakeDmPinsRepository implements DmPinsRepository {
  new([List<DmPin>? pins]) : pins_ = [...?pins];

  final List<String> calls = [];
  final List<DmPin> pins_;

  /// The presence the server would send per chat id (§10.174.5).
  final Map<String, bool> online = {};

  DmPinList get _list => DmPinList([
    for (final p in pins_)
      DmPin(chat: p.chat, pinnedAt: p.pinnedAt, online: online[p.id]),
  ]);

  @override
  Future<DmPinList> pins() async {
    calls.add('pins');
    return _list;
  }

  @override
  Future<DmPinList> setPinned(DmChat chat, {required bool pinned}) async {
    calls.add('${pinned ? 'pin' : 'unpin'}:${chat.id}');
    if (!pinned) {
      pins_.removeWhere((p) => p.id == chat.id);
      return _list;
    }
    if (pins_.any((p) => p.id == chat.id)) return _list;
    if (pins_.length >= DmPinList.limit) {
      throw const ServerFailure(
        code: ErrorCode.dmPinLimit,
        rawCode: 'DM_PIN_LIMIT',
        debugMessage: 'DM_PIN_LIMIT',
        statusCode: 409,
        details: [FieldIssue(field: 'pins', issue: 'too_many')],
      );
    }
    pins_.add(DmPin(chat: chat, pinnedAt: DateTime.utc(2026, 11, 12)));
    return _list;
  }
}
