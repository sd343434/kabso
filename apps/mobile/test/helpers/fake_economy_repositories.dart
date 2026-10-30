// D179: in-memory cherry and agency repositories for widget tests (labelled
// fixtures, never shown in the app).

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/agency/data/agency_repository.dart';
import 'package:kabso_live/features/wallet/data/cherry_repository.dart';
import 'package:kabso_live/features/wallet/data/wallet_repository.dart';

final DateTime economyAt = DateTime.utc(2026, 10, 29, 9, 30);

const CherryPayoutRules testPayout = CherryPayoutRules(
  currency: 'USD',
  rateCherries: 1000000,
  rateMinor: 110,
  minAmountMinor: 1000,
  payoutDays: 7,
);

const UserSummary economyFan = UserSummary(
  id: 'u-fan',
  username: 'sara.m',
  displayName: 'Sara',
  avatarUrl: null,
);

CherryWallet testCherryWallet({
  int cherries = 12500000,
  int held = 0,
  CherryWithdrawal? pending,
  int lockedTask = 0,
}) => CherryWallet(
  cherries: cherries,
  valueMinor: testPayout.valueOf(cherries),
  heldCherries: held,
  earnedTotal: cherries,
  earnedLast7Days: 650,
  earnedLast30Days: 9000,
  commissionTotal: 75,
  payout: testPayout,
  pendingWithdrawal: pending,
  taskRewardTotal: lockedTask,
  lockedTaskCherries: lockedTask,
  taskUnlocked: lockedTask == 0,
);

CherryWithdrawal testWithdrawal(
  String id, {
  CherryWithdrawalStatus status = CherryWithdrawalStatus.pending,
  String? note,
}) => CherryWithdrawal(
  id: id,
  status: status,
  cherries: 9090910,
  amountMinor: 1000,
  currency: 'USD',
  payoutDetails: 'Bank: IBAN SA00 TEST',
  createdAt: economyAt,
  decidedAt: status == CherryWithdrawalStatus.pending ? null : economyAt,
  decisionNote: note,
);

List<CherryLedgerEntry> testCherryLedger() => [
  CherryLedgerEntry(
    id: 'c3',
    reason: CherryLedgerReason.agencyCommission,
    delta: 75,
    balanceAfter: 12500000,
    createdAt: economyAt,
  ),
  CherryLedgerEntry(
    id: 'c2',
    reason: CherryLedgerReason.giftReceived,
    delta: 500,
    balanceAfter: 12499925,
    createdAt: economyAt,
    gift: const CherryGift(
      giftCode: 'rose',
      giftName: 'Rose',
      quantity: 1,
      giftCoins: 100,
      shareBps: 5000,
      context: EarningContext.dm,
    ),
  ),
  CherryLedgerEntry(
    id: 'c1',
    reason: CherryLedgerReason.giftReceived,
    delta: 650,
    balanceAfter: 12499425,
    createdAt: economyAt,
    gift: const CherryGift(
      giftCode: 'rose',
      giftName: 'Rose',
      quantity: 1,
      giftCoins: 100,
      shareBps: 6500,
      context: EarningContext.live,
      sender: economyFan,
    ),
  ),
];

class FakeCherryRepository implements CherryRepository {
  new({
    CherryWallet? wallet,
    this.entries,
    this.requests = const [],
    this.fail = false,
    this.withdrawError,
  }) : current = wallet ?? testCherryWallet();

  CherryWallet current;
  final List<CherryLedgerEntry>? entries;
  final List<CherryWithdrawal> requests;
  final bool fail;
  final AppFailure? withdrawError;
  final List<({int amountMinor, String details, String key})> sent = [];

  @override
  Future<CherryWallet> wallet() async {
    if (fail) throw const NetworkFailure.offline();
    return current;
  }

  @override
  Future<WalletPage<CherryLedgerEntry>> ledger({String? cursor}) async {
    if (fail) throw const NetworkFailure.offline();
    return (items: entries ?? testCherryLedger(), next: null);
  }

  @override
  Future<WalletPage<CherryWithdrawal>> withdrawals({String? cursor}) async {
    if (fail) throw const NetworkFailure.offline();
    return (items: requests, next: null);
  }

  @override
  Future<CherryWithdrawal> requestWithdrawal({
    required int amountMinor,
    required String payoutDetails,
    required String idempotencyKey,
  }) async {
    sent.add((
      amountMinor: amountMinor,
      details: payoutDetails,
      key: idempotencyKey,
    ));
    if (withdrawError case final e?) throw e;
    final w = testWithdrawal('w-new');
    current = testCherryWallet(
      cherries: current.cherries - testPayout.cherriesFor(amountMinor),
      held: testPayout.cherriesFor(amountMinor),
      pending: w,
    );
    return w;
  }
}

const UserSummary testAgent = UserSummary(
  id: 'u-agent',
  username: 'omar.agency',
  displayName: 'Omar',
  avatarUrl: null,
);

const AgencyPreview testAgencyPreview = AgencyPreview(
  inviteCode: 'KAB5Q7XZ',
  owner: testAgent,
  rank: AgencyRank.agent,
  hostCount: 12,
);

MyAgency testMyAgency({AgencyMembership? membership, OwnAgency? own}) =>
    MyAgency(
      membership: membership,
      ownAgency: own,
      activeMinDays: 7,
      activeMinHours: 10,
      activeWindowDays: 30,
      leaveDays: 14,
    );

AgencyMembership testMembership({
  bool canLeave = true,
  AgencyComplaint? complaint,
}) => AgencyMembership(
  agency: testAgencyPreview,
  joinedAt: economyAt,
  leaveUntil: economyAt.add(const Duration(days: 14)),
  canLeave: canLeave,
  complaint: complaint,
);

OwnAgency testOwnAgency({
  AgencyRank rank = AgencyRank.agent,
  bool subs = false,
  String? hostAgentCode,
  bool hostAgentActive = true,
  bool hostAgentUsernameShown = true,
}) => OwnAgency(
  hostAgentCode: hostAgentCode,
  hostAgentActive: hostAgentActive,
  hostAgentUsernameShown: hostAgentUsernameShown,
  inviteCode: 'KAB5Q7XZ',
  rank: rank,
  month: '2026-10',
  commissionRateBps: 1500,
  hostCount: 6,
  activeHosts: 4,
  requiredActiveHosts: 5,
  monthHostCherries: 126500000,
  lastMonthHostCherries: 98000000,
  exceptionCherries: 200000000,
  tierCherries: 1500000000,
  qualifiesNow: false,
  qualifiedSubAgencies: subs ? 2 : 0,
  requiredSubAgencies: 3,
  commission: (thisMonth: 18975000, lastMonth: 14700000, total: 33675000),
  parentCommission: subs
      ? (thisMonth: 3795000, lastMonth: 0, total: 3795000)
      : (thisMonth: 0, lastMonth: 0, total: 0),
  subAgencies: subs
      ? const [
          SubAgency(
            inviteCode: 'SUB22222',
            owner: UserSummary(
              id: 'u-sub',
              username: 'nour.sub',
              displayName: 'Nour',
              avatarUrl: null,
            ),
            rank: AgencyRank.agent,
            activeHosts: 6,
            monthHostCherries: 52000000,
            qualifies: true,
          ),
        ]
      : const [],
);

List<AgencyHostRow> testHosts() => [
  AgencyHostRow(
    user: economyFan,
    joinedAt: economyAt,
    liveDays: 9,
    liveSeconds: 14 * 3600,
    active: true,
    monthCherries: 6500000,
    commissionEligible: true,
  ),
  AgencyHostRow(
    user: const UserSummary(
      id: 'u-h2',
      username: 'mona.live',
      displayName: 'Mona',
      avatarUrl: null,
    ),
    joinedAt: economyAt,
    liveDays: 3,
    liveSeconds: 4 * 3600,
    active: false,
    monthCherries: 0,
    commissionEligible: false,
  ),
];

class FakeAgencyRepository implements AgencyRepository {
  new({MyAgency? mine, this.hostRows, this.fail = false})
    : current = mine ?? testMyAgency();

  MyAgency current;
  final List<AgencyHostRow>? hostRows;
  final bool fail;
  final List<String> calls = [];

  @override
  Future<MyAgency> mine() async {
    calls.add('mine');
    if (fail) throw const NetworkFailure.offline();
    return current;
  }

  @override
  Future<AgencyPreview> byCode(String inviteCode) async {
    calls.add('byCode $inviteCode');
    if (inviteCode.toUpperCase() != testAgencyPreview.inviteCode) {
      throw const ServerFailure(
        code: ErrorCode.notFound,
        rawCode: 'NOT_FOUND',
        debugMessage: 'not found',
        statusCode: 404,
      );
    }
    return testAgencyPreview;
  }

  @override
  Future<MyAgency> join(String inviteCode) async {
    calls.add('join $inviteCode');
    return current = testMyAgency(membership: testMembership());
  }

  @override
  Future<MyAgency> leave() async {
    calls.add('leave');
    return current = testMyAgency();
  }

  @override
  Future<AgencyComplaint> complain(String text) async {
    calls.add('complain $text');
    final c = AgencyComplaint(
      id: 'cp1',
      open: true,
      text: text,
      createdAt: economyAt,
    );
    current = testMyAgency(
      membership: testMembership(canLeave: false, complaint: c),
    );
    return c;
  }

  @override
  Future<WalletPage<AgencyHostRow>> hosts({String? cursor}) async {
    calls.add('hosts');
    return (items: hostRows ?? testHosts(), next: null);
  }
}
