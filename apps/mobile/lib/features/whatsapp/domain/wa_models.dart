/// v1.116-social (D355, CONVENTIONS §10.151): «واتساب» — the official Kabso
/// WhatsApp number answered by the staff. The shapes of `/staff/whatsapp/*`
/// (tag `staff`); nothing here is a fixture.
library;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// A staff member as the inbox shows them (never an e-mail).
class WaStaffRef {
  const new({required this.userId, this.displayName, this.staffId});

  factory fromJson(Map<String, dynamic> j) => WaStaffRef(
    userId: j['userId'] as String,
    displayName: j['displayName'] as String?,
    staffId: j['staffId'] as String?,
  );

  static WaStaffRef? maybe(Object? j) =>
      j is Map<String, dynamic> ? WaStaffRef.fromJson(j) : null;

  final String userId;
  final String? displayName;
  final String? staffId;

  String? get label => displayName ?? staffId;
}

/// The linked Kabso account — only what `users.view` shows.
class WaAccountCard {
  const new({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.status,
    required this.createdAt,
    this.avatarUrl,
    this.countryCode,
  });

  factory fromJson(Map<String, dynamic> j) => WaAccountCard(
    userId: j['userId'] as String,
    username: j['username'] as String,
    displayName: j['displayName'] as String,
    avatarUrl: j['avatarUrl'] as String?,
    status: j['status'] as String,
    countryCode: j['countryCode'] as String?,
    createdAt: _date(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
  );

  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String status;
  final String? countryCode;
  final DateTime createdAt;
}

enum WaFilter {
  unassigned('unassigned'),
  mine('mine'),
  all('all'),
  closed('closed');

  new(this.wire);

  final String wire;
}

class WaSummary {
  const new({
    required this.enabled,
    required this.badge,
    required this.mine,
    required this.unassigned,
  });

  factory fromJson(Map<String, dynamic> j) => WaSummary(
    enabled: j['enabled'] as bool? ?? false,
    badge: (j['badge'] as num?)?.toInt() ?? 0,
    mine: (j['mine'] as num?)?.toInt() ?? 0,
    unassigned: (j['unassigned'] as num?)?.toInt() ?? 0,
  );

  static const off = WaSummary(
    enabled: false,
    badge: 0,
    mine: 0,
    unassigned: 0,
  );

  final bool enabled;
  final int badge;
  final int mine;
  final int unassigned;
}

class WaConversation {
  const new({
    required this.id,
    required this.phone,
    required this.open,
    required this.assignedToMe,
    required this.unreadCount,
    required this.lastMessageAt,
    required this.windowOpen,
    this.name,
    this.assignedTo,
    this.lastPreview,
    this.windowClosesAt,
    this.linkedAccount,
  });

  factory fromJson(Map<String, dynamic> j) {
    final window = j['window'] as Map<String, dynamic>? ?? const {};
    final account = j['linkedAccount'];
    return WaConversation(
      id: j['id'] as String,
      phone: j['phone'] as String,
      name: j['name'] as String?,
      open: j['status'] != 'CLOSED',
      assignedTo: WaStaffRef.maybe(j['assignedTo']),
      assignedToMe: j['assignedToMe'] as bool? ?? false,
      unreadCount: (j['unreadCount'] as num?)?.toInt() ?? 0,
      lastMessageAt: _date(j['lastMessageAt']) ?? DateTime.now(),
      lastPreview: j['lastPreview'] as String?,
      windowOpen: window['open'] as bool? ?? false,
      windowClosesAt: _date(window['closesAt']),
      linkedAccount: account is Map<String, dynamic>
          ? WaAccountCard.fromJson(account)
          : null,
    );
  }

  final String id;

  /// E.164 (shown left to right).
  final String phone;
  final String? name;
  final bool open;
  final WaStaffRef? assignedTo;
  final bool assignedToMe;
  final int unreadCount;
  final DateTime lastMessageAt;
  final String? lastPreview;

  /// Meta's 24-hour customer-service window: free-form replies allowed.
  final bool windowOpen;
  final DateTime? windowClosesAt;
  final WaAccountCard? linkedAccount;

  String get title => name ?? phone;

  /// Someone else has it: no composer, no claim.
  bool get takenByOther => assignedTo != null && !assignedToMe;
}

enum WaMediaState { stored, tooLarge, typeRefused, failed }

class WaMedia {
  const new({
    required this.state,
    required this.voice,
    this.mime,
    this.size,
    this.filename,
  });

  factory fromJson(Map<String, dynamic> j) => WaMedia(
    state: switch (j['state']) {
      'STORED' => WaMediaState.stored,
      'TOO_LARGE' => WaMediaState.tooLarge,
      'TYPE_REFUSED' => WaMediaState.typeRefused,
      _ => WaMediaState.failed,
    },
    mime: j['mime'] as String?,
    size: (j['size'] as num?)?.toInt(),
    filename: j['filename'] as String?,
    voice: j['voice'] as bool? ?? false,
  );

  final WaMediaState state;
  final String? mime;
  final int? size;
  final String? filename;
  final bool voice;
}

enum WaTick { received, sent, delivered, read, failed }

class WaMessage {
  const new({
    required this.id,
    required this.outbound,
    required this.type,
    required this.tick,
    required this.at,
    this.text,
    this.media,
    this.latitude,
    this.longitude,
    this.locationName,
    this.reaction,
    this.templateName,
    this.errorTitle,
    this.sentBy,
  });

  factory fromJson(Map<String, dynamic> j) {
    final media = j['media'];
    final location = j['location'] as Map<String, dynamic>?;
    final template = j['template'] as Map<String, dynamic>?;
    final error = j['error'] as Map<String, dynamic>?;
    return WaMessage(
      id: j['id'] as String,
      outbound: j['direction'] == 'OUTBOUND',
      type: j['type'] as String? ?? 'UNSUPPORTED',
      text: j['text'] as String?,
      media: media is Map<String, dynamic> ? WaMedia.fromJson(media) : null,
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
      locationName: location?['name'] as String?,
      reaction: j['reaction'] as String?,
      templateName: template?['name'] as String?,
      tick: switch (j['status']) {
        'SENT' => WaTick.sent,
        'DELIVERED' => WaTick.delivered,
        'READ' => WaTick.read,
        'FAILED' => WaTick.failed,
        _ => WaTick.received,
      },
      errorTitle: error == null
          ? null
          : (error['title'] as String? ?? '${error['code'] ?? ''}'),
      sentBy: WaStaffRef.maybe(j['sentBy']),
      at: _date(j['at']) ?? DateTime.now(),
    );
  }

  final String id;
  final bool outbound;
  final String type;
  final String? text;
  final WaMedia? media;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? reaction;
  final String? templateName;
  final WaTick tick;
  final String? errorTitle;
  final WaStaffRef? sentBy;
  final DateTime at;
}

class WaTemplate {
  const new({
    required this.name,
    required this.language,
    required this.parameterCount,
    this.body,
  });

  factory fromJson(Map<String, dynamic> j) => WaTemplate(
    name: j['name'] as String,
    language: j['language'] as String,
    body: j['body'] as String?,
    parameterCount: (j['parameterCount'] as num?)?.toInt() ?? 0,
  );

  final String name;
  final String language;
  final String? body;
  final int parameterCount;
}

class WaQuickReply {
  const new({required this.id, required this.title, required this.body});

  factory fromJson(Map<String, dynamic> j) => WaQuickReply(
    id: j['id'] as String,
    title: j['title'] as String,
    body: j['body'] as String,
  );

  final String id;
  final String title;
  final String body;
}

class WaNote {
  const new({
    required this.id,
    required this.body,
    required this.at,
    this.author,
  });

  factory fromJson(Map<String, dynamic> j) => WaNote(
    id: j['id'] as String,
    body: j['body'] as String,
    author: WaStaffRef.maybe(j['author']),
    at: _date(j['at']) ?? DateTime.now(),
  );

  final String id;
  final String body;
  final WaStaffRef? author;
  final DateTime at;
}

class WaAgent {
  const new({required this.ref, required this.onShift});

  factory fromJson(Map<String, dynamic> j) => WaAgent(
    ref: WaStaffRef.fromJson(j),
    onShift: j['onShift'] as bool? ?? false,
  );

  final WaStaffRef ref;
  final bool onShift;
}

/// The conversation screen's data: the conversation, a page of messages
/// (newest first, as the API answers) and the notes.
class WaThread {
  const new({
    required this.conversation,
    required this.messages,
    required this.notes,
  });

  final WaConversation conversation;
  final List<WaMessage> messages;
  final List<WaNote> notes;
}
