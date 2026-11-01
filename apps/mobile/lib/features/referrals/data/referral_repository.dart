import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/wallet/data/cherry_repository.dart'
    show CherryPayoutRules;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// `ReferralStatus` (openapi v1.74-social, D217, CONVENTIONS §10.71).
enum ReferralStatus {
  pending('PENDING'),
  qualified('QUALIFIED'),
  rejected('REJECTED'),
  voided('VOID');

  new(this.wire);

  final String wire;

  static ReferralStatus fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull ?? pending;
}

/// `ReferralMilestoneState`: locked, reached counting friends still in
/// their hold, or the bonus credited.
enum MilestoneState {
  locked('LOCKED'),
  unlocked('UNLOCKED'),
  claimed('CLAIMED');

  new(this.wire);

  final String wire;

  static MilestoneState fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull ?? locked;
}

/// `ReferralRewardKind`.
enum ReferralRewardKind {
  signupInviter('SIGNUP_INVITER'),
  signupInvitee('SIGNUP_INVITEE'),
  firstRecharge('FIRST_RECHARGE'),
  milestone('MILESTONE');

  new(this.wire);

  final String wire;

  static ReferralRewardKind fromWire(Object? wire) =>
      values.where((s) => s.wire == wire).firstOrNull ?? signupInviter;
}

/// `ReferralMilestone`.
@immutable
final class ReferralMilestone {
  const new({
    required this.friends,
    required this.cherries,
    required this.state,
  });

  factory fromJson(Map<String, dynamic> json) => ReferralMilestone(
    friends: _int(json['friends']),
    cherries: _int(json['cherries']),
    state: MilestoneState.fromWire(json['state']),
  );

  final int friends;
  final int cherries;
  final MilestoneState state;
}

/// `ReferralInvitee`: a person the caller invited (masked name, no id).
@immutable
final class ReferralInvitee {
  const new({
    required this.name,
    required this.status,
    required this.joinedAt,
    required this.firstRecharge,
  });

  factory fromJson(Map<String, dynamic> json) => ReferralInvitee(
    name: json['name'] as String? ?? '',
    status: ReferralStatus.fromWire(json['status']),
    joinedAt: DateTime.parse(json['joinedAt']! as String),
    firstRecharge: json['firstRecharge'] == true,
  );

  final String name;
  final ReferralStatus status;
  final DateTime joinedAt;
  final bool firstRecharge;
}

/// The amounts and rules the server is set to (`MyReferral.rules`). The app
/// shows these values and has no number of its own.
@immutable
final class ReferralRules {
  const new({
    required this.inviterSignupCherries,
    required this.inviteeSignupCherries,
    required this.firstRechargeBps,
    required this.holdHours,
    required this.applyWindowDays,
    required this.dailySignupCap,
  });

  factory fromJson(Map<String, dynamic> json) => ReferralRules(
    inviterSignupCherries: _int(json['inviterSignupCherries']),
    inviteeSignupCherries: _int(json['inviteeSignupCherries']),
    firstRechargeBps: _int(json['firstRechargeBps']),
    holdHours: _int(json['holdHours']),
    applyWindowDays: _int(json['applyWindowDays']),
    dailySignupCap: _int(json['dailySignupCap']),
  );

  final int inviterSignupCherries;
  final int inviteeSignupCherries;

  /// Basis points of the friend's first recharge (500 = 5 %).
  final int firstRechargeBps;
  final int holdHours;
  final int applyWindowDays;

  /// 0 = no cap.
  final int dailySignupCap;
}

/// `MyReferral` (`GET /me/referral`).
@immutable
final class MyReferral {
  const new({
    required this.enabled,
    required this.code,
    required this.link,
    required this.rules,
    required this.upToTotal,
    required this.upToMilestones,
    required this.payout,
    required this.invited,
    required this.qualified,
    required this.pending,
    required this.pendingCherries,
    required this.creditedCherries,
    required this.milestones,
    required this.invitees,
    required this.canApply,
    this.invitedByStatus,
    this.applyUntil,
  });

  factory fromJson(Map<String, dynamic> json) {
    final upTo = json['upTo']! as Map<String, dynamic>;
    final counts = json['counts']! as Map<String, dynamic>;
    final rewards = json['rewards']! as Map<String, dynamic>;
    final payout = json['payout']! as Map<String, dynamic>;
    final invitedBy = json['invitedBy'] as Map<String, dynamic>?;
    final until = json['applyUntil'] as String?;
    return MyReferral(
      enabled: json['enabled'] == true,
      code: json['code']! as String,
      link: json['link']! as String,
      rules: ReferralRules.fromJson(json['rules']! as Map<String, dynamic>),
      upToTotal: _int(upTo['total']),
      upToMilestones: _int(upTo['milestones']),
      payout: CherryPayoutRules(
        currency: payout['currency']! as String,
        rateCherries: _int(payout['rateCherries']),
        rateMinor: _int(payout['rateMinor']),
        minAmountMinor: 0,
        payoutDays: 0,
      ),
      invited: _int(counts['invited']),
      qualified: _int(counts['qualified']),
      pending: _int(counts['pending']),
      pendingCherries: _int(rewards['pendingCherries']),
      creditedCherries: _int(rewards['creditedCherries']),
      milestones: [
        for (final m in json['milestones']! as List<dynamic>)
          ReferralMilestone.fromJson(m as Map<String, dynamic>),
      ],
      invitees: [
        for (final i in json['invitees']! as List<dynamic>)
          ReferralInvitee.fromJson(i as Map<String, dynamic>),
      ],
      canApply: json['canApply'] == true,
      invitedByStatus: invitedBy == null
          ? null
          : ReferralStatus.fromWire(invitedBy['status']),
      applyUntil: until == null ? null : DateTime.parse(until),
    );
  }

  final bool enabled;
  final String code;
  final String link;
  final ReferralRules rules;

  /// «اربح حتى N» (the server's sum; the recharge share is on top).
  final int upToTotal;

  /// «ادعُ أصدقاء جدداً واربح حتى Z»: the milestones' total.
  final int upToMilestones;

  /// The cherry wallet's payout rate (only `currency`, `rateCherries` and
  /// `rateMinor` are set), for the money hint.
  final CherryPayoutRules payout;
  final int invited;
  final int qualified;
  final int pending;
  final int pendingCherries;
  final int creditedCherries;
  final List<ReferralMilestone> milestones;
  final List<ReferralInvitee> invitees;
  final bool canApply;

  /// The caller's own referral (who invited them), or null.
  final ReferralStatus? invitedByStatus;
  final DateTime? applyUntil;
}

/// `ReferralTickerItem`: a real reward credited lately (masked name).
@immutable
final class ReferralTickerItem {
  const new({required this.name, required this.cherries, required this.kind});

  factory fromJson(Map<String, dynamic> json) => ReferralTickerItem(
    name: json['name'] as String? ?? '',
    cherries: _int(json['cherries']),
    kind: ReferralRewardKind.fromWire(json['kind']),
  );

  final String name;
  final int cherries;
  final ReferralRewardKind kind;
}

/// «دعوة الأصدقاء» (v1.74-social, D217, CONVENTIONS §10.71).
abstract interface class ReferralRepository {
  /// `GET /me/referral`; null from an older server (404: the page is
  /// hidden and «اربح المال» opens the cherry wallet).
  Future<MyReferral?> mine();

  /// `POST /me/referral/apply` (a code or a link, once, within the window).
  Future<MyReferral> apply(String code, {String? installId});

  /// `GET /referrals/recent-rewards` (public; empty when there is none).
  Future<List<ReferralTickerItem>> ticker();
}

class ReferralRepositoryImpl implements ReferralRepository {
  const new(this._dio);

  final Dio _dio;

  @override
  Future<MyReferral?> mine() => guardApiCall(() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me/referral');
      return MyReferral.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  });

  @override
  Future<MyReferral> apply(String code, {String? installId}) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/me/referral/apply',
          data: {'code': code.trim(), 'installId': ?installId},
        );
        return MyReferral.fromJson(res.data!);
      });

  @override
  Future<List<ReferralTickerItem>> ticker() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/referrals/recent-rewards',
    );
    return [
      for (final i in res.data!['data']! as List<dynamic>)
        ReferralTickerItem.fromJson(i as Map<String, dynamic>),
    ];
  });
}

final referralRepositoryProvider = Provider<ReferralRepository>(
  (ref) => ReferralRepositoryImpl(ref.watch(apiDioProvider)),
);
