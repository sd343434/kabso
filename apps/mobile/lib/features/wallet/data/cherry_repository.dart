import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/api_call.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// `CherryLedgerReason` (openapi v1.52-social, D179, CONVENTIONS §10.46):
/// why a cherry balance changed. A value this build does not know is
/// [other].
enum CherryLedgerReason {
  giftReceived('GIFT_RECEIVED'),
  agencyCommission('AGENCY_COMMISSION'),
  parentCommission('PARENT_COMMISSION'),
  giftReversal('GIFT_REVERSAL'),
  agencyCommissionReversal('AGENCY_COMMISSION_REVERSAL'),
  parentCommissionReversal('PARENT_COMMISSION_REVERSAL'),
  withdrawalHold('WITHDRAWAL_HOLD'),
  withdrawalRefund('WITHDRAWAL_REFUND'),

  /// v1.53-social (D184): a Task Center reward.
  taskReward('TASK_REWARD'),
  other('');

  new(this.wire);

  final String wire;

  static CherryLedgerReason fromWire(Object? wire) =>
      values.where((r) => r.wire == wire && r != other).firstOrNull ?? other;
}

/// `CherryPayoutRules`: [rateCherries] cherries are paid [rateMinor] minor
/// units of [currency] (owner: 1 000 000 = $1.10).
@immutable
final class CherryPayoutRules {
  const new({
    required this.currency,
    required this.rateCherries,
    required this.rateMinor,
    required this.minAmountMinor,
    required this.payoutDays,
  });

  factory fromJson(Map<String, dynamic> json) => CherryPayoutRules(
    currency: json['currency']! as String,
    rateCherries: _int(json['rateCherries']),
    rateMinor: _int(json['rateMinor']),
    minAmountMinor: _int(json['minAmountMinor']),
    payoutDays: _int(json['payoutDays']),
  );

  final String currency;
  final int rateCherries;
  final int rateMinor;
  final int minAmountMinor;
  final int payoutDays;

  /// The cherries a request of [amountMinor] holds (the server's rounding:
  /// up).
  int cherriesFor(int amountMinor) =>
      (amountMinor * rateCherries + rateMinor - 1) ~/ rateMinor;

  /// What [cherries] are worth in minor units (rounded down).
  int valueOf(int cherries) =>
      cherries <= 0 ? 0 : cherries * rateMinor ~/ rateCherries;
}

/// `CherryWithdrawalStatus`.
enum CherryWithdrawalStatus { pending, paid, rejected }

/// `CherryWithdrawal`: a payout request (paid by hand by the team).
@immutable
final class CherryWithdrawal {
  const new({
    required this.id,
    required this.status,
    required this.cherries,
    required this.amountMinor,
    required this.currency,
    required this.payoutDetails,
    required this.createdAt,
    this.decidedAt,
    this.decisionNote,
  });

  factory fromJson(Map<String, dynamic> json) => CherryWithdrawal(
    id: json['id']! as String,
    status: switch (json['status']) {
      'PAID' => CherryWithdrawalStatus.paid,
      'REJECTED' => CherryWithdrawalStatus.rejected,
      _ => CherryWithdrawalStatus.pending,
    },
    cherries: _int(json['cherries']),
    amountMinor: _int(json['amountMinor']),
    currency: json['currency']! as String,
    payoutDetails: json['payoutDetails']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    decidedAt: json['decidedAt'] == null
        ? null
        : DateTime.parse(json['decidedAt']! as String),
    decisionNote: json['decisionNote'] as String?,
  );

  final String id;
  final CherryWithdrawalStatus status;
  final int cherries;
  final int amountMinor;
  final String currency;
  final String payoutDetails;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? decisionNote;
}

/// `CherryWallet`: the caller's cherry balance (D179).
@immutable
final class CherryWallet {
  const new({
    required this.cherries,
    required this.valueMinor,
    required this.heldCherries,
    required this.earnedTotal,
    required this.earnedLast7Days,
    required this.earnedLast30Days,
    required this.commissionTotal,
    required this.payout,
    this.pendingWithdrawal,
    this.taskRewardTotal = 0,
    this.lockedTaskCherries = 0,
    int? withdrawableCherries,
    this.taskUnlocked = true,
  }) : withdrawableCherries =
           withdrawableCherries ??
           (cherries - lockedTaskCherries < 0
               ? 0
               : cherries - lockedTaskCherries);

  factory fromJson(Map<String, dynamic> json) => CherryWallet(
    cherries: _int(json['cherries']),
    valueMinor: _int(json['valueMinor']),
    heldCherries: _int(json['heldCherries']),
    earnedTotal: _int(json['earnedTotal']),
    earnedLast7Days: _int(json['earnedLast7Days']),
    earnedLast30Days: _int(json['earnedLast30Days']),
    commissionTotal: _int(json['commissionTotal']),
    taskRewardTotal: _int(json['taskRewardTotal']),
    lockedTaskCherries: _int(json['lockedTaskCherries']),
    // A server before v1.53-social: everything is withdrawable.
    withdrawableCherries: json['withdrawableCherries'] == null
        ? null
        : _int(json['withdrawableCherries']),
    taskUnlocked: switch (json['taskUnlock']) {
      final Map<String, dynamic> u => u['unlocked'] != false,
      _ => true,
    },
    payout: CherryPayoutRules.fromJson(json['payout']! as Map<String, dynamic>),
    pendingWithdrawal: json['pendingWithdrawal'] == null
        ? null
        : CherryWithdrawal.fromJson(
            json['pendingWithdrawal']! as Map<String, dynamic>,
          ),
  );

  /// The available balance (below 0 only after a reversal: a debt).
  final int cherries;
  final int valueMinor;
  final int heldCherries;
  final int earnedTotal;
  final int earnedLast7Days;
  final int earnedLast30Days;
  final int commissionTotal;
  final CherryPayoutRules payout;
  final CherryWithdrawal? pendingWithdrawal;

  /// v1.53-social (D184): Task Center rewards, all time.
  final int taskRewardTotal;

  /// v1.53-social (D184, CONVENTIONS §10.46.1): task cherries not
  /// withdrawable yet (0 once the unlock rule passed).
  final int lockedTaskCherries;

  /// What a withdrawal may take now: [cherries] less [lockedTaskCherries].
  final int withdrawableCherries;

  /// The unlock rule for task cherries passed (the owner's rule; pending).
  final bool taskUnlocked;
}

/// The gift of a `GIFT_RECEIVED` / `GIFT_REVERSAL` row.
@immutable
final class CherryGift {
  const new({
    required this.giftCode,
    required this.giftName,
    required this.quantity,
    required this.giftCoins,
    required this.shareBps,
    required this.context,
    this.sender,
  });

  factory fromJson(Map<String, dynamic> json) => CherryGift(
    giftCode: json['giftCode']! as String,
    giftName: json['giftName']! as String,
    quantity: _int(json['quantity']),
    giftCoins: _int(json['giftCoins']),
    shareBps: _int(json['shareBps']),
    context: json['context'] == 'DM' ? EarningContext.dm : EarningContext.live,
    sender: json['sender'] == null
        ? null
        : UserSummary.fromJson(json['sender']! as Map<String, dynamic>),
  );

  final String giftCode;
  final String giftName;
  final int quantity;
  final int giftCoins;
  final int shareBps;
  final EarningContext context;

  /// Null when not active or a block stands between them.
  final UserSummary? sender;
}

/// `CherryLedgerEntry`: one change of the caller's cherries.
@immutable
final class CherryLedgerEntry {
  const new({
    required this.id,
    required this.reason,
    required this.delta,
    required this.balanceAfter,
    required this.createdAt,
    this.gift,
  });

  factory fromJson(Map<String, dynamic> json) => CherryLedgerEntry(
    id: json['id']! as String,
    reason: CherryLedgerReason.fromWire(json['reason']),
    delta: _int(json['delta']),
    balanceAfter: _int(json['balanceAfter']),
    createdAt: DateTime.parse(json['createdAt']! as String),
    gift: json['gift'] == null
        ? null
        : CherryGift.fromJson(json['gift']! as Map<String, dynamic>),
  );

  final String id;
  final CherryLedgerReason reason;
  final int delta;
  final int balanceAfter;
  final DateTime createdAt;
  final CherryGift? gift;
}

/// The caller's cherries and withdrawal requests (openapi v1.52-social,
/// D179). Every method throws an `AppFailure`.
abstract interface class CherryRepository {
  /// `GET /wallet/me/cherries`.
  Future<CherryWallet> wallet();

  /// `GET /wallet/me/cherries/ledger`.
  Future<WalletPage<CherryLedgerEntry>> ledger({String? cursor});

  /// `GET /wallet/me/cherries/withdrawals`.
  Future<WalletPage<CherryWithdrawal>> withdrawals({String? cursor});

  /// `POST /wallet/me/cherries/withdrawals` with [idempotencyKey] (a retry
  /// with the same key returns the same request).
  Future<CherryWithdrawal> requestWithdrawal({
    required int amountMinor,
    required String payoutDetails,
    required String idempotencyKey,
  });
}

class CherryRepositoryImpl implements CherryRepository {
  new(this._dio);

  final Dio _dio;

  Future<WalletPage<T>> _page<T>(
    String path,
    String? cursor,
    T Function(Map<String, dynamic>) item,
  ) => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: {'cursor': ?cursor},
    );
    final body = res.data!;
    final page = PageInfo.fromJson(body['page']! as Map<String, dynamic>);
    return (
      items: [
        for (final e in body['data']! as List<dynamic>)
          item(e as Map<String, dynamic>),
      ],
      next: page.hasMore ? page.nextCursor : null,
    );
  });

  @override
  Future<CherryWallet> wallet() => guardApiCall(() async {
    final res = await _dio.get<Map<String, dynamic>>('/wallet/me/cherries');
    return CherryWallet.fromJson(res.data!);
  });

  @override
  Future<WalletPage<CherryLedgerEntry>> ledger({String? cursor}) =>
      _page('/wallet/me/cherries/ledger', cursor, CherryLedgerEntry.fromJson);

  @override
  Future<WalletPage<CherryWithdrawal>> withdrawals({String? cursor}) => _page(
    '/wallet/me/cherries/withdrawals',
    cursor,
    CherryWithdrawal.fromJson,
  );

  @override
  Future<CherryWithdrawal> requestWithdrawal({
    required int amountMinor,
    required String payoutDetails,
    required String idempotencyKey,
  }) => guardApiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/wallet/me/cherries/withdrawals',
      data: {'amountMinor': amountMinor, 'payoutDetails': payoutDetails},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return CherryWithdrawal.fromJson(res.data!);
  });
}

final cherryRepositoryProvider = Provider<CherryRepository>(
  (ref) => CherryRepositoryImpl(ref.watch(apiDioProvider)),
);
