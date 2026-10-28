// In-memory D146 premium usernames (tests only). Every call is recorded in
// `calls`; a failure set in `failNext[method]` is thrown once by it.

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/premium/data/premium_repository.dart';
import 'package:kabso_live/features/premium/domain/premium_models.dart';

/// A `ServerFailure` with [code] (409 unless given).
ServerFailure premiumFailure(ErrorCode code, {int status = 409}) =>
    ServerFailure(
      code: code,
      rawCode: code.wire,
      debugMessage: code.wire,
      statusCode: status,
    );

class FakePremiumRepository implements PremiumRepository {
  new({
    this.prices = const {
      PremiumTier.legend: 50000,
      PremiumTier.ruby: 20000,
      PremiumTier.gold: 12000,
      PremiumTier.silver: null,
    },
    this.suggestions = const ['777', '7777', '8888', '1221'],
    this.mineValue,
    this.user,
  });

  /// The monthly price per tier (null: not on sale).
  Map<PremiumTier, int?> prices;
  List<String> suggestions;
  MyPremiumUsername? mineValue;
  User? user;

  /// Names another account has.
  final Set<String> taken = {'1234'};

  final List<String> calls = [];
  final Map<String, AppFailure> failNext = {};

  void _record(String call) {
    calls.add(call);
    final name = call.split(':').first;
    if (failNext.remove(name) case final failure?) throw failure;
  }

  /// A simplified copy of the server's rule (the app never decides tiers).
  static PremiumTier? tierOf(String name) {
    if (!RegExp(r'^[a-z0-9]{1,30}$').hasMatch(name)) return null;
    if (name.length <= 3) return PremiumTier.legend;
    if (RegExp(r'^(.)\1+$').hasMatch(name)) return PremiumTier.ruby;
    if (name.length <= 5) return PremiumTier.gold;
    if (RegExp(r'^([a-z]+|[0-9]+)$').hasMatch(name)) return PremiumTier.silver;
    return null;
  }

  PremiumNameStatus statusOf(String name) {
    final tier = tierOf(name);
    final price = tier == null ? null : prices[tier];
    final PremiumNameState state;
    if (tier == null) {
      state = PremiumNameState.regular;
    } else if (mineValue?.username == name) {
      state = mineValue!.grace
          ? PremiumNameState.yoursGrace
          : PremiumNameState.yours;
    } else if (taken.contains(name)) {
      state = PremiumNameState.taken;
    } else if (price == null) {
      state = PremiumNameState.notForSale;
    } else {
      state = PremiumNameState.available;
    }
    return PremiumNameStatus(
      username: name,
      tier: tier,
      state: state,
      priceCoins: state.purchasable ? price : null,
      periodDays: 30,
    );
  }

  @override
  Future<PremiumStore> store({PremiumTier? tier}) async {
    _record('store:${tier?.wire ?? 'ALL'}');
    final names = [
      for (final s in suggestions)
        if (tier == null || tierOf(s) == tier)
          if (statusOf(s).state == PremiumNameState.available) statusOf(s),
    ];
    return PremiumStore(
      periodDays: 30,
      graceDays: 7,
      tiers: [
        for (final t in PremiumTier.values) (tier: t, priceCoins: prices[t]),
      ],
      suggestions: names,
    );
  }

  @override
  Future<PremiumNameStatus> status(String username) async {
    _record('status:$username');
    return statusOf(username);
  }

  @override
  Future<MyPremiumUsername?> mine() async {
    _record('mine');
    return mineValue;
  }

  /// The arguments of the last rent.
  ({String username, int priceCoins, String key})? lastRent;

  @override
  Future<PremiumRental> rent({
    required String username,
    required int priceCoins,
    required String idempotencyKey,
  }) async {
    _record('rent:$username');
    lastRent = (
      username: username,
      priceCoins: priceCoins,
      key: idempotencyKey,
    );
    final now = DateTime.now();
    mineValue = MyPremiumUsername(
      username: username,
      tier: tierOf(username)!,
      grace: false,
      granted: false,
      startedAt: now,
      expiresAt: now.add(const Duration(days: 30)),
      graceUntil: null,
      regularUsername: 'sara_2026',
      renewPriceCoins: priceCoins,
      canRenew: true,
    );
    return (premium: mineValue!, coins: 1000);
  }

  @override
  Future<void> release() async {
    _record('release');
    mineValue = null;
  }

  @override
  Future<User> changeUsername(String username) async {
    _record('changeUsername:$username');
    final u = user!.copyWith(username: username, premiumTier: null);
    user = u;
    return u;
  }
}
