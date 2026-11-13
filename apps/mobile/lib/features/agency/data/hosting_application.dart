import 'dart:typed_data';

import 'package:flutter/foundation.dart' show immutable;

/// v1.73-social (D209, CONVENTIONS §10.68): «كن مضيفاً مع الإدارة» — the
/// person applies to host directly with the Kabso Live team (no agency).

/// `HostApplicationStatus`. An unknown value (a newer server) reads as
/// [pending].
enum HostingApplicationStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED'),
  cancelled('CANCELLED');

  new(this.wire);

  final String wire;

  static HostingApplicationStatus fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull ?? pending;
}

/// `HostingApplyRefusal` (plus `UNDER_MIN_AGE`, refused only when sending).
enum HostingApplyRefusal {
  accountNotActive('ACCOUNT_NOT_ACTIVE'),

  /// v1.82-live (D295): a content creator cannot also be a host.
  creator('CREATOR'),
  alreadyHost('ALREADY_HOST'),
  hostOfAgency('HOST_OF_AGENCY'),
  ownsAgency('OWNS_AGENCY'),
  pending('PENDING'),
  reapplyCooldown('REAPPLY_COOLDOWN'),
  underMinAge('UNDER_MIN_AGE');

  new(this.wire);

  final String wire;

  static HostingApplyRefusal? fromWire(Object? wire) =>
      values.where((r) => r.wire == wire).firstOrNull;
}

/// `MyHostingApplication.host.source`: where the caller's hosting permission
/// came from. `identity` = approved here (a host directly with the team).
enum HostingSource {
  admin('ADMIN'),
  agency('AGENCY'),
  identity('IDENTITY'),

  /// v1.82-live (D295): the permission a creator-programme membership gives.
  creator('CREATOR');

  new(this.wire);

  final String wire;

  static HostingSource fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull ?? admin;

  /// Directly with the Kabso Live team (approved, or given by the team).
  bool get withTheTeam => this != agency && this != creator;
}

/// `HostingApplication`: the caller's latest application.
@immutable
final class HostingApplication {
  const new({
    required this.id,
    required this.status,
    required this.displayName,
    required this.country,
    required this.createdAt,
    this.decidedAt,
    this.rejectReason,
    this.cancelReason,
    this.reapplyAt,
  });

  factory fromJson(Map<String, dynamic> json) => HostingApplication(
    id: json['id']! as String,
    status: HostingApplicationStatus.fromWire(json['status']),
    displayName: json['displayName'] as String? ?? '',
    country: json['country'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt']! as String),
    decidedAt: switch (json['decidedAt']) {
      final String s => DateTime.parse(s),
      _ => null,
    },
    rejectReason: json['rejectReason'] as String?,
    cancelReason: json['cancelReason'] as String?,
    reapplyAt: switch (json['reapplyAt']) {
      final String s => DateTime.parse(s),
      _ => null,
    },
  );

  final String id;
  final HostingApplicationStatus status;
  final String displayName;
  final String country;
  final DateTime createdAt;
  final DateTime? decidedAt;

  /// REJECTED only: the team's reason.
  final String? rejectReason;

  /// CANCELLED only: `USER`, `AGENCY` or `ACCOUNT`.
  final String? cancelReason;

  /// REJECTED only: when the person may apply again.
  final DateTime? reapplyAt;
}

/// `MyHostingApplication` (`GET /me/hosting-application`).
@immutable
final class MyHostingApplication {
  const new({
    required this.canApply,
    required this.minAge,
    required this.reapplyDays,
    this.host,
    this.hostSince,
    this.application,
    this.refusal,
  });

  factory fromJson(Map<String, dynamic> json) {
    final rule = json['rule']! as Map<String, dynamic>;
    final host = json['host'] as Map<String, dynamic>?;
    return MyHostingApplication(
      host: host == null ? null : HostingSource.fromWire(host['source']),
      hostSince: switch (host?['grantedAt']) {
        final String s => DateTime.parse(s),
        _ => null,
      },
      application: switch (json['application']) {
        final Map<String, dynamic> a => HostingApplication.fromJson(a),
        _ => null,
      },
      canApply: rule['canApply'] == true,
      refusal: HostingApplyRefusal.fromWire(rule['refusal']),
      minAge: (rule['minAge'] as num?)?.toInt() ?? 18,
      reapplyDays: (rule['reapplyDays'] as num?)?.toInt() ?? 30,
    );
  }

  /// The caller's hosting permission now (any source), or null.
  final HostingSource? host;
  final DateTime? hostSince;
  final HostingApplication? application;
  final bool canApply;
  final HostingApplyRefusal? refusal;
  final int minAge;
  final int reapplyDays;
}

/// The contact methods of `HostingApplicationRequest.contact.type` (the same
/// as «افتح وكالة»).
enum HostingContactType {
  whatsapp('WHATSAPP'),
  telegram('TELEGRAM'),
  phone('PHONE'),
  email('EMAIL'),
  other('OTHER');

  new(this.wire);

  final String wire;
}

/// «كن مضيفاً مع الإدارة» as filled in.
@immutable
final class HostingDraft {
  const new({
    required this.displayName,
    required this.country,
    required this.dateOfBirth,
    required this.contactType,
    required this.contactValue,
    required this.bio,
    required this.links,
    required this.idempotencyKey,
    this.idCard,
    this.idCardType,
    this.selfie,
    this.selfieType,
    this.recruiter,
  });

  /// v1.75-live (D285): «إن كنت تابعاً لمشرف، ضع معرّفه هنا» — a staff ID or
  /// username, checked live (null: none).
  final String? recruiter;

  final String displayName;

  /// ISO alpha-2.
  final String country;

  /// A calendar day (only the date is sent).
  final DateTime dateOfBirth;
  final HostingContactType contactType;
  final String contactValue;
  final String bio;

  /// At most 3 `https` links (empty: none).
  final List<String> links;

  /// v1.80-kyc (D227): null while Didit is on (the identity check replaces
  /// the manual ID pictures; nothing is uploaded).
  final Uint8List? idCard;
  final String? idCardType;
  final Uint8List? selfie;
  final String? selfieType;

  /// One per attempt of the form (a retry after a lost answer reuses it).
  final String idempotencyKey;

  /// `YYYY-MM-DD`.
  String get dateOfBirthWire =>
      '${dateOfBirth.year.toString().padLeft(4, '0')}-'
      '${dateOfBirth.month.toString().padLeft(2, '0')}-'
      '${dateOfBirth.day.toString().padLeft(2, '0')}';
}

/// Whole years between [birth] (a calendar day) and [now].
int ageOn(DateTime birth, DateTime now) {
  var years = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    years -= 1;
  }
  return years;
}
