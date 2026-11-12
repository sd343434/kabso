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

/// v1.123-social (D366, CONVENTIONS §10.159): the WhatsApp departments — a
/// fixed set. Every conversation is in one (GENERAL until a transfer moves
/// it); a staff member answers for one or more (GENERAL by default).
enum WaDepartment {
  payments('PAYMENTS'),
  agencies('AGENCIES'),
  technical('TECHNICAL'),
  reports('REPORTS'),
  general('GENERAL');

  new(this.wire);

  final String wire;

  /// An unknown or missing value (a server before D366) reads as GENERAL.
  static WaDepartment fromWire(Object? v) => WaDepartment.values.firstWhere(
    (d) => d.wire == v,
    orElse: () => WaDepartment.general,
  );
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
    this.inApp = false,
  });

  factory fromJson(Map<String, dynamic> j) => WaSummary(
    enabled: j['enabled'] as bool? ?? false,
    inApp: j['inApp'] as bool? ?? false,
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

  /// v1.137-social (D385, §10.174.6): the in-app «دعم كابسو» threads are
  /// served (also while WhatsApp itself is off).
  final bool inApp;
  final int badge;
  final int mine;
  final int unassigned;

  /// The inbox has something to show: WhatsApp, the in-app threads or both.
  bool get served => enabled || inApp;
}

/// v1.137-social (D385, §10.174.6): where a support conversation is.
enum WaChannel {
  whatsapp('WHATSAPP'),
  inApp('IN_APP');

  new(this.wire);

  final String wire;

  /// An unknown or missing value (a server before D385) reads as WhatsApp.
  static WaChannel fromWire(Object? v) => v == 'IN_APP' ? inApp : whatsapp;
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
    this.department = WaDepartment.general,
    this.channel = WaChannel.whatsapp,
  });

  factory fromJson(Map<String, dynamic> j) {
    final window = j['window'] as Map<String, dynamic>? ?? const {};
    final account = j['linkedAccount'];
    return WaConversation(
      id: j['id'] as String,
      phone: j['phone'] as String?,
      channel: WaChannel.fromWire(j['channel']),
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
      department: WaDepartment.fromWire(j['department']),
    );
  }

  final String id;

  /// E.164 (shown left to right); (D385) null for an in-app thread.
  final String? phone;

  /// D385: WhatsApp, or «دعم كابسو» inside the app «داخل التطبيق» (no
  /// 24-hour window, no templates, text replies, never linked).
  final WaChannel channel;

  bool get inApp => channel == WaChannel.inApp;
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

  /// D366: the department «القسم» (changed only by a transfer).
  final WaDepartment department;

  String get title => name ?? phone ?? '';

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
    this.errorCode,
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
      errorCode: (error?['code'] as num?)?.toInt(),
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

  /// Meta's own words for a failed send (English, never shown in the app:
  /// D365 shows [errorCode] in words instead).
  final String? errorTitle;

  /// Meta's numeric error code (131047 the window, 131026 undeliverable, …).
  final int? errorCode;
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
  const new({
    required this.ref,
    required this.onShift,
    this.departments = const [WaDepartment.general],
    this.openCount = 0,
  });

  factory fromJson(Map<String, dynamic> j) {
    final depts = j['departments'];
    return WaAgent(
      ref: WaStaffRef.fromJson(j),
      onShift: j['onShift'] as bool? ?? false,
      departments: depts is List && depts.isNotEmpty
          ? [for (final d in depts) WaDepartment.fromWire(d)]
          : const [WaDepartment.general],
      openCount: (j['openCount'] as num?)?.toInt() ?? 0,
    );
  }

  final WaStaffRef ref;
  final bool onShift;

  /// D366: the departments the agent answers for.
  final List<WaDepartment> departments;

  /// D366: open conversations assigned to the agent now.
  final int openCount;
}

/// D366 (§10.159.2): what the transfer sheet chose — a department, a person
/// in it (null: «أول متاح في القسم») and an internal note.
class WaTransferChoice {
  const new({required this.department, this.to, this.note});

  final WaDepartment department;
  final WaAgent? to;
  final String? note;
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
