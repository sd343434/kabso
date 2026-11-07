import 'package:flutter/foundation.dart';

/// v1.68-live (D273, §10.96.6): how a Kabso staff member enters a live from
/// the app — «دخول ظاهر (فريق كابسو)» (listed with the badge, never counted)
/// or «مراقبة خفية» (the D250 observer: not listed, not counted, no chat).
enum StaffVisibility {
  visible('VISIBLE'),
  hidden('HIDDEN');

  new(this.wire);

  final String wire;

  static StaffVisibility? fromWire(Object? value) =>
      values.where((v) => v.wire == value).firstOrNull;
}

/// The panel capabilities the staff tools use (`StaffStatus.capabilities`).
abstract final class StaffCapability {
  static const watch = 'lives.watch';
  static const watchHidden = 'lives.watch.hidden';
  static const reports = 'lives.reports';
  static const moderate = 'lives.moderate';
  static const deviceBan = 'devices.ban';
}

/// `StaffStatus` (D273): the caller's «فريق كابسو» state.
@immutable
class StaffStatus {
  const new({
    required this.isStaff,
    required this.roles,
    required this.capabilities,
    required this.authenticatorEnrolled,
    required this.onShift,
    this.lockedUntil,
  });

  factory fromJson(Map<String, dynamic> json) => StaffStatus(
    isStaff: json['isStaff'] as bool? ?? false,
    roles: [for (final r in json['roles'] as List<dynamic>? ?? const []) '$r'],
    capabilities: [
      for (final c in json['capabilities'] as List<dynamic>? ?? const []) '$c',
    ],
    authenticatorEnrolled: json['authenticatorEnrolled'] as bool? ?? false,
    onShift: json['onShift'] as bool? ?? false,
    lockedUntil: switch (json['lockedUntil']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    // D286 (v1.76-live): `stepUp` is deprecated — the tools need no code.
  );

  static const none = StaffStatus(
    isStaff: false,
    roles: [],
    capabilities: [],
    authenticatorEnrolled: false,
    onShift: false,
  );

  final bool isStaff;
  final List<String> roles;
  final List<String> capabilities;
  final bool authenticatorEnrolled;
  final bool onShift;
  final DateTime? lockedUntil;

  bool can(String capability) => capabilities.contains(capability);

  StaffStatus copyWith({bool? onShift}) => StaffStatus(
    isStaff: isStaff,
    roles: roles,
    capabilities: capabilities,
    authenticatorEnrolled: authenticatorEnrolled,
    onShift: onShift ?? this.onShift,
    lockedUntil: lockedUntil,
  );
}

/// `StaffLive` (D273): one of «بثوثي».
@immutable
class StaffLive {
  const new({
    required this.roomId,
    required this.title,
    required this.hostName,
    required this.hostUsername,
    required this.viewerCount,
    required this.openReports,
    required this.startedAt,
    this.hostAvatarUrl,
  });

  factory fromJson(Map<String, dynamic> json) {
    final host = json['host'] as Map<String, dynamic>? ?? const {};
    return StaffLive(
      roomId: json['roomId']! as String,
      title: json['title'] as String? ?? '',
      hostName: host['displayName'] as String? ?? '',
      hostUsername: host['username'] as String? ?? '',
      hostAvatarUrl: host['avatarUrl'] as String?,
      viewerCount: (json['viewerCount'] as num?)?.toInt() ?? 0,
      openReports: (json['openReports'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.parse(json['startedAt']! as String),
    );
  }

  final String roomId;
  final String title;
  final String hostName;
  final String hostUsername;
  final String? hostAvatarUrl;
  final int viewerCount;
  final int openReports;
  final DateTime startedAt;
}

/// A person in a staff list (`AdminPersonRef`).
@immutable
class StaffPerson {
  const new({
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  static StaffPerson? fromJson(Object? json) => switch (json) {
    final Map<String, dynamic> m => StaffPerson(
      username: m['username'] as String? ?? '',
      displayName: m['displayName'] as String? ?? '',
      avatarUrl: m['avatarUrl'] as String?,
    ),
    _ => null,
  };

  final String username;
  final String displayName;
  final String? avatarUrl;
}

/// What a report is about (`AdminLiveReport.targetType`).
enum StaffReportTarget { live, user, message }

/// `AdminLiveReport` as the staff tools show it.
@immutable
class StaffReport {
  const new({
    required this.id,
    required this.target,
    required this.reason,
    required this.open,
    required this.createdAt,
    this.note,
    this.reporter,
    this.person,
    this.messageId,
    this.messageText,
  });

  factory fromJson(Map<String, dynamic> json) {
    final t = json['target'] as Map<String, dynamic>?;
    return StaffReport(
      id: json['id']! as String,
      target: switch (json['targetType']) {
        'USER' => StaffReportTarget.user,
        'LIVE_CHAT_MESSAGE' => StaffReportTarget.message,
        _ => StaffReportTarget.live,
      },
      reason: json['reason'] as String? ?? 'OTHER',
      note: json['note'] as String?,
      open: json['status'] == 'OPEN',
      createdAt: DateTime.parse(json['createdAt']! as String),
      reporter: StaffPerson.fromJson(json['reporter']),
      person: StaffPerson.fromJson(t?['user']),
      messageId: t?['messageId'] as String?,
      messageText: t?['text'] as String?,
    );
  }

  final String id;
  final StaffReportTarget target;
  final String reason;
  final String? note;
  final bool open;
  final DateTime createdAt;
  final StaffPerson? reporter;

  /// The reported person (a user report, or a message's author).
  final StaffPerson? person;
  final String? messageId;
  final String? messageText;
}

/// The panel's live actions (`AdminLiveModerateRequest.action`).
enum StaffLiveAction {
  warn('WARN'),
  end('END'),
  noLive('NO_LIVE'),
  suspend('SUSPEND');

  new(this.wire);

  final String wire;

  /// NO_LIVE and SUSPEND last a while (the panel's 1 h … 30 d).
  bool get timed => this == noLive || this == suspend;
}

/// v1.78-live (D288, §10.101): the capabilities of «بلاغات» — the shared
/// report queue (OWNER, MODERATION, SUPPORT).
abstract final class SharedReportCapability {
  static const view = 'reports.view';
  static const resolve = 'reports.resolve';
}

/// D288: the two tabs of «بلاغات» — `OPEN` «غير محلولة» and `RESOLVED`
/// «تم حلها» (every closed report, newest resolution first).
enum SharedReportTab {
  open('OPEN'),
  resolved('RESOLVED');

  new(this.wire);

  final String wire;
}

/// D288: who resolved a report (`ReportResolver`).
@immutable
class SharedReportResolver {
  const new({
    required this.id,
    required this.username,
    required this.displayName,
  });

  factory fromJson(Map<String, dynamic> json) => SharedReportResolver(
    id: json['id']! as String,
    username: json['username'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
  );

  final String id;
  final String username;
  final String displayName;

  /// The name the queue shows: the display name, else `@username`.
  String get label => displayName.isNotEmpty ? displayName : '@$username';
}

/// D288: one report of the shared queue (`AdminPanelReport`): what it is
/// about, why, the preview, who reported it and — once closed — who resolved
/// it, when and their note.
@immutable
class SharedReport {
  const new({
    required this.id,
    required this.targetType,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.targetId = '',
    this.resolutionAction,
    this.note,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNote,
    this.reporterName,
    this.reporterUsername,
    this.authorName,
    this.authorUsername,
    this.previewText,
    this.gone = false,
  });

  factory fromJson(Map<String, dynamic> json) {
    final preview = json['preview'] as Map<String, dynamic>? ?? const {};
    final author = preview['author'] as Map<String, dynamic>?;
    final reporter = json['reporter'] as Map<String, dynamic>?;
    final dm = json['dmSnapshot'] as Map<String, dynamic>?;
    final link = json['linkSnapshot'] as Map<String, dynamic>?;
    return SharedReport(
      id: json['id']! as String,
      targetType: json['targetType'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      status: json['status'] as String? ?? 'OPEN',
      createdAt: DateTime.parse(json['createdAt']! as String),
      targetId: json['targetId'] as String? ?? '',
      resolutionAction: json['resolutionAction'] as String?,
      note: json['note'] as String?,
      resolvedAt: switch (json['resolvedAt']) {
        final String at => DateTime.parse(at),
        _ => null,
      },
      resolvedBy: switch (json['resolvedBy']) {
        final Map<String, dynamic> r => SharedReportResolver.fromJson(r),
        _ => null,
      },
      resolutionNote: json['resolutionNote'] as String?,
      reporterName: reporter?['displayName'] as String?,
      reporterUsername: reporter?['username'] as String?,
      authorName: author?['displayName'] as String?,
      authorUsername: author?['username'] as String?,
      previewText:
          dm?['text'] as String? ??
          link?['url'] as String? ??
          preview['text'] as String?,
      gone: preview['gone'] as bool? ?? false,
    );
  }

  final String id;

  /// `Report.targetType` (POST, COMMENT, STORY, USER, LIVE_ROOM …).
  final String targetType;

  /// `ReportReason` (SPAM, NUDITY …).
  final String reason;

  /// The reported item's id (a username for USER).
  final String targetId;

  /// v1.93-social (D296): the action that resolved it (WARN, RESTRICT,
  /// SUSPEND, BAN, REMOVE_CONTENT, DISMISS); null for «تم حله» alone.
  final String? resolutionAction;

  /// OPEN, ACTIONED or DISMISSED.
  final String status;
  final DateTime createdAt;

  /// The reporter's own note.
  final String? note;
  final DateTime? resolvedAt;
  final SharedReportResolver? resolvedBy;
  final String? resolutionNote;
  final String? reporterName;
  final String? reporterUsername;
  final String? authorName;
  final String? authorUsername;

  /// The reported text (post, comment, message, the link, the user's bio).
  final String? previewText;

  /// The reported item is already gone.
  final bool gone;

  bool get isOpen => status == 'OPEN';
}

/// D288: one page of the shared queue.
@immutable
class SharedReportPage {
  const new({required this.items, this.nextCursor});

  final List<SharedReport> items;
  final String? nextCursor;
}
