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
    this.stepUpUntil,
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
    stepUpUntil: switch (json['stepUp']) {
      {'expiresAt': final String at} => DateTime.parse(at),
      _ => null,
    },
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

  /// This app session's step-up, while valid; null → the tools ask for the
  /// authenticator code.
  final DateTime? stepUpUntil;

  bool can(String capability) => capabilities.contains(capability);

  bool get unlocked => stepUpUntil != null;

  StaffStatus copyWith({bool? onShift, DateTime? stepUpUntil}) => StaffStatus(
    isStaff: isStaff,
    roles: roles,
    capabilities: capabilities,
    authenticatorEnrolled: authenticatorEnrolled,
    onShift: onShift ?? this.onShift,
    lockedUntil: lockedUntil,
    stepUpUntil: stepUpUntil ?? this.stepUpUntil,
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
