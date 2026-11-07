import 'package:flutter/foundation.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';

/// v1.93-social (D296, CONVENTIONS §10.109): what a staff member may do from a
/// report (`StaffReportAction`). Each needs its own panel capability; the
/// server lists the allowed ones in `StaffReportView.actions` and the app
/// shows only those buttons.
enum StaffReportAction {
  /// «تحذير» — `reports.act`.
  warn('WARN'),

  /// «تقييد» (منع النشر / منع البث / منع الرسائل) — `users.restrict`.
  restrict('RESTRICT'),

  /// «تعليق مؤقت» — the account locked for some days, `users.lock`.
  suspend('SUSPEND'),

  /// «حظر دائم» — the account suspended, `users.ban`.
  ban('BAN'),

  /// «إخفاء المحتوى» — `reports.act`.
  removeContent('REMOVE_CONTENT'),

  /// «حذف نهائي» — a post, reel or story for good, `users.content`
  /// (owner, 2026-11-06: in the app too).
  deleteContent('DELETE_CONTENT'),

  /// «حذف الحساب» — the account's deletion with its grace period,
  /// `users.delete` (OWNER).
  deleteAccount('DELETE_ACCOUNT');

  new(this.wire);

  final String wire;

  static StaffReportAction? fromWire(Object? value) =>
      values.where((v) => v.wire == value).firstOrNull;

  /// The account or the content suffers (a confirmation in red).
  bool get destructive => this != warn;

  /// Takes a number of days.
  bool get timed => this == restrict || this == suspend;

  /// Cannot be undone from the app: the typed confirmation word first.
  bool get permanent => this == deleteContent || this == deleteAccount;

  /// What the server expects in `confirm` for a [permanent] action.
  static const confirmWire = 'DELETE';
}

/// D296: the restrictions RESTRICT offers (D208's kinds).
enum StaffRestriction {
  /// «منع النشر» — no post, reel or story.
  noPosting('NO_POSTING'),

  /// «منع البث» — no going live (a current live ends).
  noLive('NO_LIVE'),

  /// «منع الرسائل» — no direct message, comment or live chat (CHAT_MUTE).
  chatMute('CHAT_MUTE');

  new(this.wire);

  final String wire;

  static StaffRestriction? fromWire(Object? value) =>
      values.where((v) => v.wire == value).firstOrNull;
}

/// D296: the reported item's state, for the «محتوى مُبلّغ عنه» banner.
enum StaffTargetState {
  visible('VISIBLE'),
  hidden('HIDDEN'),
  deleted('DELETED'),
  expired('EXPIRED'),
  live('LIVE'),
  ended('ENDED'),
  gone('GONE');

  new(this.wire);

  final String wire;

  static StaffTargetState fromWire(Object? value) =>
      values.where((v) => v.wire == value).firstOrNull ?? visible;

  /// «المحتوى محذوف»: nothing left to show but the report's snapshot.
  bool get removed => this == deleted || this == gone;
}

/// D296: a reported comment and where it is.
@immutable
class StaffReportComment {
  const new({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.postId,
    this.parentId,
  });

  factory fromJson(Map<String, dynamic> json) => StaffReportComment(
    id: json['id']! as String,
    text: json['text'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt']! as String),
    postId: json['postId']! as String,
    parentId: json['parentId'] as String?,
  );

  final String id;
  final String text;
  final DateTime createdAt;
  final String postId;
  final String? parentId;
}

/// D296: a reported story.
@immutable
class StaffReportStory {
  const new({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.expiresAt,
    this.media,
  });

  factory fromJson(Map<String, dynamic> json) => StaffReportStory(
    id: json['id']! as String,
    text: json['text'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt']! as String),
    expiresAt: DateTime.parse(json['expiresAt']! as String),
    media: switch (json['media']) {
      final Map<String, dynamic> m => MediaAsset.fromJson(m),
      _ => null,
    },
  );

  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime expiresAt;
  final MediaAsset? media;
}

/// D296: the live of a LIVE_ROOM or LIVE_CHAT_MESSAGE report.
@immutable
class StaffReportLive {
  const new({required this.roomId, required this.title, required this.status});

  factory fromJson(Map<String, dynamic> json) => StaffReportLive(
    roomId: json['roomId']! as String,
    title: json['title'] as String? ?? '',
    status: json['status'] as String? ?? '',
  );

  final String roomId;
  final String title;
  final String status;

  bool get isLive => status == 'LIVE';
}

/// D296 (D155): the frozen copy of a reported direct message — what the
/// report kept, never the conversation.
@immutable
class StaffDmSnapshot {
  const new({
    required this.kind,
    required this.sentAt,
    this.text,
    this.token,
    this.sender,
    this.mediaUrl,
    this.giftCode,
    this.quantity,
    this.purged = false,
  });

  factory fromJson(Map<String, dynamic> json) => StaffDmSnapshot(
    kind: json['kind'] as String? ?? 'TEXT',
    sentAt: DateTime.parse(json['sentAt']! as String),
    text: json['text'] as String?,
    token: json['token'] as String?,
    sender: json['sender'] as String?,
    mediaUrl: json['mediaUrl'] as String?,
    giftCode: json['giftCode'] as String?,
    quantity: json['quantity'] as int?,
    purged: json['purged'] as bool? ?? false,
  );

  /// TEXT, EMOJI, IMAGE, VOICE or GIFT.
  final String kind;
  final DateTime sentAt;
  final String? text;
  final String? token;

  /// The sender's username when reported.
  final String? sender;
  final String? mediaUrl;
  final String? giftCode;
  final int? quantity;

  /// 30 days after resolution the text and the file were cleared.
  final bool purged;
}

/// D296 (owner: «مثل طريقة نزاع وكيل الشحن»): one message of the conversation
/// frozen with the report.
@immutable
class StaffThreadMessage {
  const new({
    required this.id,
    required this.kind,
    required this.sentAt,
    this.sender,
    this.fromReported = false,
    this.text,
    this.token,
    this.mediaUrl,
    this.mediaMissing = false,
    this.giftCode,
    this.quantity,
    this.reported = false,
  });

  factory fromJson(Map<String, dynamic> json) => StaffThreadMessage(
    id: json['id'] as String? ?? '',
    kind: json['kind'] as String? ?? 'TEXT',
    sentAt: DateTime.parse(json['sentAt']! as String),
    sender: json['sender'] as String?,
    fromReported: json['fromReported'] as bool? ?? false,
    text: json['text'] as String?,
    token: json['token'] as String?,
    mediaUrl: json['mediaUrl'] as String?,
    mediaMissing: json['mediaMissing'] as bool? ?? false,
    giftCode: json['giftCode'] as String?,
    quantity: json['quantity'] as int?,
    reported: json['reported'] as bool? ?? false,
  );

  final String id;
  final String kind;
  final DateTime sentAt;

  /// The sender's username now.
  final String? sender;

  /// Sent by the reported person (the other side is the reporter).
  final bool fromReported;
  final String? text;
  final String? token;
  final String? mediaUrl;

  /// A picture or voice clip beyond the files the report copied.
  final bool mediaMissing;
  final String? giftCode;
  final int? quantity;

  /// The reported message itself.
  final bool reported;
}

/// D296: the whole conversation as it was when the report was filed.
@immutable
class StaffThread {
  const new({
    required this.capturedAt,
    required this.messages,
    this.total = 0,
    this.truncated = false,
  });

  factory fromJson(Map<String, dynamic> json) => StaffThread(
    capturedAt: DateTime.parse(json['capturedAt']! as String),
    total: json['total'] as int? ?? 0,
    truncated: json['truncated'] as bool? ?? false,
    messages: [
      for (final m in json['messages'] as List<dynamic>? ?? const [])
        StaffThreadMessage.fromJson(m as Map<String, dynamic>),
    ],
  );

  final DateTime capturedAt;
  final int total;

  /// More messages existed than the report keeps (the oldest left out).
  final bool truncated;

  /// Oldest first.
  final List<StaffThreadMessage> messages;
}

/// D296: the reported item as the staff see it, whatever its visibility
/// (`StaffReportedItem`).
@immutable
class StaffReportedItem {
  const new({
    required this.type,
    required this.state,
    this.author,
    this.post,
    this.comment,
    this.story,
    this.live,
    this.dmSnapshot,
    this.dmRecipient,
    this.dmThread,
    this.text,
  });

  factory fromJson(Map<String, dynamic> json) {
    UserSummary? user(Object? raw) => switch (raw) {
      final Map<String, dynamic> m => UserSummary.fromJson(m),
      _ => null,
    };
    final dm = json['dm'] as Map<String, dynamic>?;
    return StaffReportedItem(
      type: json['type'] as String? ?? '',
      state: StaffTargetState.fromWire(json['state']),
      author: user(json['author']),
      post: switch (json['post']) {
        final Map<String, dynamic> p => Post.fromJson(p),
        _ => null,
      },
      comment: switch (json['comment']) {
        final Map<String, dynamic> c => StaffReportComment.fromJson(c),
        _ => null,
      },
      story: switch (json['story']) {
        final Map<String, dynamic> s => StaffReportStory.fromJson(s),
        _ => null,
      },
      live: switch (json['live']) {
        final Map<String, dynamic> l => StaffReportLive.fromJson(l),
        _ => null,
      },
      dmSnapshot: switch (dm?['snapshot']) {
        final Map<String, dynamic> s => StaffDmSnapshot.fromJson(s),
        _ => null,
      },
      dmRecipient: user(dm?['recipient']),
      dmThread: switch (dm?['thread']) {
        final Map<String, dynamic> t => StaffThread.fromJson(t),
        _ => null,
      },
      text: json['text'] as String?,
    );
  }

  /// `Report.targetType`.
  final String type;
  final StaffTargetState state;

  /// The author (the reported user for USER, the sender for DM_MESSAGE).
  final UserSummary? author;

  /// POST: the post or reel; COMMENT: the post it is on.
  final Post? post;
  final StaffReportComment? comment;
  final StaffReportStory? story;
  final StaffReportLive? live;
  final StaffDmSnapshot? dmSnapshot;

  /// DM_MESSAGE: the person who received it (the reporter).
  final UserSummary? dmRecipient;

  /// The whole conversation frozen with the report (a DM report, or a person
  /// reported from the conversation); null when none or purged.
  final StaffThread? dmThread;

  /// A live chat message, a CP confession, a family chat message or a link.
  final String? text;
}

/// D296: one report opened from «بلاغات» (`StaffReportView`).
@immutable
class StaffReportView {
  const new({
    required this.report,
    required this.target,
    this.actions = const [],
    this.restrictions = const [],
    this.canResolve = false,
  });

  factory fromJson(Map<String, dynamic> json) => StaffReportView(
    report: SharedReport.fromJson(json['report']! as Map<String, dynamic>),
    target: StaffReportedItem.fromJson(json['target']! as Map<String, dynamic>),
    actions: [
      for (final a in json['actions'] as List<dynamic>? ?? const [])
        ?StaffReportAction.fromWire(a),
    ],
    restrictions: [
      for (final r in json['restrictions'] as List<dynamic>? ?? const [])
        ?StaffRestriction.fromWire(r),
    ],
    canResolve: json['canResolve'] as bool? ?? false,
  );

  final SharedReport report;
  final StaffReportedItem target;

  /// Only these buttons are shown (the server's capability matrix).
  final List<StaffReportAction> actions;
  final List<StaffRestriction> restrictions;

  /// «تم حله» without an action.
  final bool canResolve;
}
