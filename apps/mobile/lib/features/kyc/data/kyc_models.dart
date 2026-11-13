import 'package:flutter/foundation.dart' show immutable;

/// v1.80-kyc (D227, CONVENTIONS §10.77): the application an identity check
/// «تأكيد الهوية» is made for.
enum KycPurpose {
  hostApplication('HOST_APPLICATION'),
  agencyOpen('AGENCY_OPEN'),
  rechargeAgent('RECHARGE_AGENT');

  new(this.wire);

  final String wire;

  static KycPurpose? fromWire(String? raw) {
    for (final p in values) {
      if (p.wire == raw) return p;
    }
    return null;
  }
}

/// A check's state (Didit's, mapped by the server). Unknown values read as
/// [notStarted] (a newer server; the app then offers to start).
enum KycStatus {
  notStarted('NOT_STARTED'),
  inProgress('IN_PROGRESS'),
  inReview('IN_REVIEW'),
  approved('APPROVED'),
  declined('DECLINED'),
  expired('EXPIRED'),
  abandoned('ABANDONED');

  new(this.wire);

  final String wire;

  static KycStatus fromWire(String? raw) {
    for (final s in values) {
      if (s.wire == raw) return s;
    }
    return KycStatus.notStarted;
  }
}

/// Why a new session cannot start now.
enum KycRefusal {
  accountNotActive('ACCOUNT_NOT_ACTIVE'),
  alreadyApproved('ALREADY_APPROVED'),
  inReview('IN_REVIEW'),
  dailyLimit('DAILY_LIMIT');

  new(this.wire);

  final String wire;

  static KycRefusal? fromWire(String? raw) {
    for (final r in values) {
      if (r.wire == raw) return r;
    }
    return null;
  }
}

/// `KycCheck`: what the person sees of a check (no personal field).
@immutable
final class KycCheck {
  const new({
    required this.id,
    required this.purpose,
    required this.status,
    required this.reasons,
    required this.createdAt,
    this.decidedAt,
  });

  factory fromJson(Map<String, dynamic> json) => KycCheck(
    id: json['id'] as String,
    purpose:
        KycPurpose.fromWire(json['purpose'] as String?) ??
        KycPurpose.hostApplication,
    status: KycStatus.fromWire(json['status'] as String?),
    reasons: [for (final r in (json['reasons'] as List?) ?? const []) '$r'],
    createdAt: DateTime.parse(json['createdAt'] as String),
    decidedAt: switch (json['decidedAt']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
  );

  final String id;
  final KycPurpose purpose;
  final KycStatus status;

  /// DECLINED / IN_REVIEW only: Didit's warning codes and ours.
  final List<String> reasons;
  final DateTime createdAt;
  final DateTime? decidedAt;
}

/// `KycPurposeState`.
@immutable
final class KycPurposeState {
  const new({
    required this.purpose,
    required this.approved,
    required this.canStart,
    this.check,
    this.refusal,
  });

  factory fromJson(Map<String, dynamic> json) => KycPurposeState(
    purpose:
        KycPurpose.fromWire(json['purpose'] as String?) ??
        KycPurpose.hostApplication,
    approved: json['approved'] == true,
    canStart: json['canStart'] == true,
    check: switch (json['check']) {
      final Map<String, dynamic> c => KycCheck.fromJson(c),
      _ => null,
    },
    refusal: KycRefusal.fromWire(json['refusal'] as String?),
  );

  final KycPurpose purpose;

  /// An approved check counts for this application.
  final bool approved;
  final bool canStart;
  final KycCheck? check;
  final KycRefusal? refusal;

  /// The state the step shows.
  KycStatus get status =>
      approved ? KycStatus.approved : (check?.status ?? KycStatus.notStarted);
}

/// `MyKyc` (`GET /me/kyc`).
@immutable
final class MyKyc {
  const new({
    required this.enabled,
    required this.maxSessionsPerDay,
    required this.startedLast24h,
    required this.purposes,
  });

  factory fromJson(Map<String, dynamic> json) => MyKyc(
    enabled: json['enabled'] == true,
    maxSessionsPerDay: (json['maxSessionsPerDay'] as num?)?.toInt() ?? 3,
    startedLast24h: (json['startedLast24h'] as num?)?.toInt() ?? 0,
    purposes: [
      for (final p in (json['purposes'] as List?) ?? const [])
        KycPurposeState.fromJson(p as Map<String, dynamic>),
    ],
  );

  /// Didit off (or an older server): the manual ID pictures are asked.
  static const off = MyKyc(
    enabled: false,
    maxSessionsPerDay: 3,
    startedLast24h: 0,
    purposes: [],
  );

  /// Didit is on: the applications ask for «تأكيد الهوية», not pictures.
  final bool enabled;
  final int maxSessionsPerDay;
  final int startedLast24h;
  final List<KycPurposeState> purposes;

  KycPurposeState of(KycPurpose purpose) =>
      purposes.where((p) => p.purpose == purpose).firstOrNull ??
      KycPurposeState(purpose: purpose, approved: false, canStart: enabled);
}

/// `KycSessionStart`: Didit's hosted flow and where it ends.
@immutable
final class KycSessionStart {
  const new({
    required this.check,
    required this.url,
    required this.callbackUrl,
  });

  factory fromJson(Map<String, dynamic> json) => KycSessionStart(
    check: KycCheck.fromJson(json['check'] as Map<String, dynamic>),
    url: json['url'] as String,
    callbackUrl: json['callbackUrl'] as String,
  );

  final KycCheck check;

  /// `https://verify.didit.me/…` (personal: never cached or shared).
  final String url;

  /// `kabsolive://kyc/done`: the WebView closes when the flow reaches it.
  final String callbackUrl;
}
