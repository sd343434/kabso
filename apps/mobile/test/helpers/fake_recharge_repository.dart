// D185: an in-memory recharge-agent repository (labelled fixtures, tests and
// captures only).

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/recharge/data/recharge_repository.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';

const fixtureRules = RechargeRules(
  activationMinCoins: 30000000,
  cherryUnit: 1000000,
  coinsPerCherryUnit: 93220,
  minCherries: 1000000,
  stepCherries: 100000,
  requestTtlMinutes: 30,
  payoutRateCherries: 1000000,
  payoutRateMinor: 110,
  currency: 'USD',
);

const SalesStats _noSales = (
  today: (count: 0, coins: 0),
  last7Days: (count: 0, coins: 0),
  last30Days: (count: 0, coins: 0),
);

/// The caller has never applied.
const RechargeAgentMe fixtureNone = RechargeAgentMe(
  status: RechargeAgentStatus.none,
  canApply: true,
  rules: fixtureRules,
);

/// An ACTIVE agent `coin0007` with a stock and today's sales.
RechargeAgentMe fixtureActive({
  RechargeAgentStatus status = RechargeAgentStatus.active,
  int stock = 28750000,
  // Owner («حد وكيل مفتوح»): no daily cherry cap by default (0).
  int cap = 0,
}) => RechargeAgentMe(
  status: status,
  canApply: false,
  rules: fixtureRules,
  agent: RechargeAgentDashboard(
    code: 'coin0007',
    status: status,
    stockCoins: stock,
    activatedAt: DateTime.utc(2026, 10, 30, 9),
    dailyCherryCap: cap,
    todayCherries: 2000000,
    availability: const RechargeAvailability(
      timeZone: 'Africa/Cairo',
      slots: [
        WeeklySlot(
          days: [6, 7, 1, 2, 3, 4],
          start: '10:00',
          end: '22:00',
          whatsapp: '+201001234567',
          paymentMethod: 'InstaPay',
        ),
      ],
    ),
    sales: (
      today: (count: 3, coins: 1250000),
      last7Days: (count: 18, coins: 9400000),
      last30Days: (count: 64, coins: 31000000),
    ),
  ),
);

const fixtureAgentUser = UserSummary(
  id: 'u-agent',
  username: 'nour.store',
  displayName: 'نور للشحن',
  avatarUrl: null,
  rechargeAgentCode: 'coin0007',
);

const fixtureStaff = UserSummary(
  id: 'u-staff',
  username: 'sami',
  displayName: 'سامي',
  avatarUrl: null,
);

const fixtureBuyer = UserSummary(
  id: 'u-buyer',
  username: 'layla.k',
  displayName: 'ليلى',
  avatarUrl: null,
);

class FakeRechargeRepository implements RechargeRepository {
  new({
    this.mine = fixtureNone,
    List<RechargeEmployee>? staff,
    List<RechargeAgentListing>? agents,
    List<RechargeCherryRequest>? requests,
  }) : staff = staff ?? [],
       agents = agents ?? [],
       requests = requests ?? [];

  RechargeAgentMe mine;
  final List<RechargeEmployee> staff;
  final List<RechargeAgentListing> agents;
  final List<RechargeCherryRequest> requests;

  final applied = <RechargeApplicationDraft>[];
  final sold = <({String buyer, int coins, String key})>[];
  final answered = <(String, String)>[];
  final created = <({int cherries, String? agentCode, String? host})>[];
  final removed = <String>[];
  RechargeAvailability? savedAvailability;
  String? lastCountry;
  Exception? sellError;

  @override
  Future<RechargeAgentMe> me() async => mine;

  @override
  Future<RechargeAgentMe> apply(RechargeApplicationDraft draft) async {
    applied.add(draft);
    return mine = const RechargeAgentMe(
      status: RechargeAgentStatus.pending,
      canApply: false,
      rules: fixtureRules,
    );
  }

  @override
  Future<RechargeAvailability> setAvailability(
    RechargeAvailability value,
  ) async => savedAvailability = value;

  @override
  Future<RechargeSale> sell({
    required String buyer,
    required int coins,
    required String idempotencyKey,
  }) async {
    if (sellError case final e?) throw e;
    sold.add((buyer: buyer, coins: coins, key: idempotencyKey));
    return RechargeSale(
      id: 'sale-${sold.length}',
      coins: coins,
      buyer: fixtureBuyer,
      seller: fixtureAgentUser,
      agentCode: 'coin0007',
      stockAfter: 1000,
      createdAt: DateTime.utc(2026, 10, 30, 12),
    );
  }

  @override
  Future<WalletPage<RechargeSale>> sales({String? cursor}) async =>
      (items: const <RechargeSale>[], next: null);

  @override
  Future<List<RechargeEmployee>> employees() async => staff;

  @override
  Future<RechargeEmployee> addEmployee(
    String username,
    String timeZone,
    List<WeeklySlot> schedule,
  ) async {
    final e = RechargeEmployee(
      user: UserSummary(
        id: 'u-$username',
        username: username,
        displayName: username,
        avatarUrl: null,
      ),
      timeZone: timeZone,
      schedule: schedule,
      onShiftNow: true,
      addedAt: DateTime.utc(2026, 10, 30),
      sales: _noSales,
    );
    staff.add(e);
    return e;
  }

  @override
  Future<RechargeEmployee> updateEmployee(
    String username,
    String timeZone,
    List<WeeklySlot> schedule,
  ) async => staff.firstWhere((e) => e.user.username == username);

  @override
  Future<void> removeEmployee(String username) async {
    removed.add(username);
    staff.removeWhere((e) => e.user.username == username);
  }

  @override
  Future<WalletPage<RechargeAgentListing>> directory(
    String country, {
    String? cursor,
  }) async {
    lastCountry = country;
    return (items: agents, next: null);
  }

  @override
  Future<RechargeCherryRequest> createCherryRequest({
    required int cherries,
    required String idempotencyKey,
    String? agentCode,
    String? host,
  }) async {
    created.add((cherries: cherries, agentCode: agentCode, host: host));
    return requests.first;
  }

  @override
  Future<WalletPage<RechargeCherryRequest>> cherryRequests({
    String? cursor,
  }) async => (items: requests, next: null);

  @override
  Future<RechargeCherryRequest> answerCherryRequest(
    String id,
    String action,
  ) async {
    answered.add((id, action));
    return requests.firstWhere((r) => r.id == id);
  }
}
