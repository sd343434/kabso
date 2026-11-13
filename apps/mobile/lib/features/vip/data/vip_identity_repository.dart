import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/premium/domain/premium_models.dart';

/// v1.131-social (D378, §10.168.4): the caller's golden ID
/// (`VipGoldenIdHolding`): HELD (shown) or GRACE (kept for them after their
/// membership, not shown, until [graceUntil]).
@immutable
final class VipGoldenIdHolding {
  const new({
    required this.number,
    required this.goldenClass,
    required this.grace,
    this.heldUntil,
    this.graceUntil,
  });

  factory fromJson(Map<String, dynamic> json) => VipGoldenIdHolding(
    number: json['number']! as String,
    goldenClass: json['class']! as String,
    grace: json['state'] == 'GRACE',
    heldUntil: _date(json['heldUntil']),
    graceUntil: _date(json['graceUntil']),
  );

  final String number;
  final String goldenClass;
  final bool grace;
  final DateTime? heldUntil;
  final DateTime? graceUntil;
}

DateTime? _date(Object? v) => v is String ? DateTime.parse(v) : null;

/// `VipGoldenIdChoice` (`GET /me/vip/golden-ids`): the class the caller's
/// GOLDEN_ID lets them pick ([goldenClass], null without the perk), their own
/// number and up to 60 free numbers of the class, shortest first.
@immutable
final class VipGoldenIdChoice {
  const new({required this.goldenClass, required this.available, this.mine});

  factory fromJson(Map<String, dynamic> json) => VipGoldenIdChoice(
    goldenClass: json['class'] as String?,
    mine: switch (json['mine']) {
      final Map<String, dynamic> m => VipGoldenIdHolding.fromJson(m),
      _ => null,
    },
    available: [
      for (final n in json['available']! as List<dynamic>)
        if (n is String) n,
    ],
  );

  final String? goldenClass;
  final VipGoldenIdHolding? mine;
  final List<String> available;
}

/// The server's VIP identity perk calls (D378). Every method throws an
/// `AppFailure`.
abstract interface class VipIdentityRepository {
  /// `PUT /me/vip/signature`: sets (or with null clears) the caller's
  /// ANIMATED_SIGNATURE text; the text as stored.
  Future<String?> setSignature(String? signature);

  /// `GET /me/vip/golden-ids`.
  Future<VipGoldenIdChoice> goldenIds();

  /// `POST /me/vip/golden-id`: takes [number] (a held one is given back
  /// first).
  Future<VipGoldenIdHolding> claimGoldenId(String number);

  /// `DELETE /me/vip/golden-id`: gives the caller's number back now.
  Future<void> releaseGoldenId();

  /// `POST /me/premium-username/vip-claim` (§10.168.3): [username] claimed
  /// free with PREMIUM_USERNAME for the membership.
  Future<MyPremiumUsername> claimPremiumUsername(String username);

  /// `GET /premium-usernames`' `vipTier`: the highest medal the caller's VIP
  /// claims free (it and every lower one), the claimable suggestions; null
  /// without the perk.
  Future<({PremiumTier? vipTier, List<PremiumNameStatus> names})>
  premiumChoice();
}

class VipIdentityRepositoryImpl implements VipIdentityRepository {
  new(this._dio);

  final Dio _dio;

  @override
  Future<String?> setSignature(String? signature) => guardApiCall(() async {
    final res = await _dio.put<Map<String, dynamic>>(
      '/me/vip/signature',
      data: {'signature': signature},
    );
    return res.data!['signature'] as String?;
  });

  @override
  Future<VipGoldenIdChoice> goldenIds() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/me/vip/golden-ids');
    return VipGoldenIdChoice.fromJson(res.data!);
  });

  @override
  Future<VipGoldenIdHolding> claimGoldenId(String number) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/me/vip/golden-id',
          data: {'number': number},
        );
        return VipGoldenIdHolding.fromJson(res.data!);
      });

  @override
  Future<void> releaseGoldenId() =>
      guardApiCall(() => _dio.delete<void>('/me/vip/golden-id'));

  @override
  Future<MyPremiumUsername> claimPremiumUsername(String username) =>
      guardApiCall(() async {
        final res = await _dio.post<Map<String, dynamic>>(
          '/me/premium-username/vip-claim',
          data: {'username': username},
        );
        return MyPremiumUsername.fromJson(
          res.data!['premium']! as Map<String, dynamic>,
        );
      });

  @override
  Future<({PremiumTier? vipTier, List<PremiumNameStatus> names})>
  premiumChoice() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/premium-usernames');
    final body = res.data!;
    final vipTier = PremiumTier.fromWire(body['vipTier']);
    final names = [
      for (final s in body['suggestions']! as List<dynamic>)
        PremiumNameStatus.fromJson(s as Map<String, dynamic>),
    ];
    return (
      vipTier: vipTier,
      names: vipTier == null
          ? const <PremiumNameStatus>[]
          : [
              for (final n in names)
                if (n.tier case final t? when vipPremiumClaimAllows(vipTier, t))
                  n,
            ],
    );
  });
}

/// D378 (§10.168.3): whether a PREMIUM_USERNAME perk of medal [perk] claims
/// a name of medal [name] — the same or a lower one (LEGEND > RUBY > GOLD >
/// SILVER), as the server decides.
bool vipPremiumClaimAllows(PremiumTier perk, PremiumTier name) =>
    _rank(name) <= _rank(perk);

int _rank(PremiumTier t) => switch (t) {
  PremiumTier.legend => 4,
  PremiumTier.ruby => 3,
  PremiumTier.gold => 2,
  PremiumTier.silver => 1,
};

final vipIdentityRepositoryProvider = Provider<VipIdentityRepository>(
  (ref) => VipIdentityRepositoryImpl(ref.watch(apiDioProvider)),
);
