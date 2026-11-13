// D390 «برنامج سفراء Kabso»: payloads shaped like `AmbassadorProgramme` and
// `AmbassadorDashboard` in openapi.yaml (v1.140-social), with the migration's
// proposed defaults. Test data only (G-26).

import 'package:kabso_live/features/ambassadors/data/ambassador_repository.dart';

const _levels = [
  {
    'code': 'BRONZE',
    'minActiveReferrals': 0,
    'minTopupCoins': 0,
    'commissionBps': 300,
    'reward': {'kind': 'NONE'},
  },
  {
    'code': 'SILVER',
    'minActiveReferrals': 5,
    'minTopupCoins': 3000000,
    'commissionBps': 500,
    'reward': {'kind': 'COINS', 'amount': 100000},
  },
  {
    'code': 'GOLD',
    'minActiveReferrals': 15,
    'minTopupCoins': 15000000,
    'commissionBps': 700,
    'reward': {'kind': 'VIP_DAYS', 'amount': 7, 'vipTier': 'VIP_1'},
  },
  {
    'code': 'DIAMOND',
    'minActiveReferrals': 40,
    'minTopupCoins': 60000000,
    'commissionBps': 1000,
    'reward': {'kind': 'COINS', 'amount': 1000000},
  },
];

/// The programme page: [enabled], the caller's [status] / [refusal].
Map<String, dynamic> ambassadorProgrammeJson({
  bool enabled = true,
  String status = 'NONE',
  String? refusal,
  String? rejectReason,
}) => {
  'enabled': enabled,
  'status': status,
  'canApply': refusal == null && status != 'AMBASSADOR',
  'refusal': refusal,
  'application': rejectReason == null
      ? null
      : {
          'id': '01a39000-0000-7000-8000-000000000001',
          'status': 'REJECTED',
          'country': 'EG',
          'links': ['https://example.com/@me'],
          'audienceSize': 1200,
          'motivation': 'x',
          'createdAt': '2026-11-10T10:00:00.000Z',
          'decidedAt': '2026-11-11T10:00:00.000Z',
          'rejectReason': rejectReason,
        },
  'levels': enabled ? _levels : const <Object>[],
  'rules': {
    'attributionWindowDays': 90,
    'holdDays': 14,
    'minActiveDays': 3,
    'minActiveTopupCoins': 100000,
  },
};

AmbassadorProgramme ambassadorProgramme({
  bool enabled = true,
  String status = 'NONE',
  String? refusal,
  String? rejectReason,
}) => AmbassadorProgramme.fromJson(
  ambassadorProgrammeJson(
    enabled: enabled,
    status: status,
    refusal: refusal,
    rejectReason: rejectReason,
  ),
);

/// A Silver ambassador half-way to Gold this month.
Map<String, dynamic> ambassadorDashboardJson({bool payoutsHeld = false}) => {
  'enabled': true,
  'payoutsHeld': payoutsHeld,
  'since': '2026-09-02T10:00:00.000Z',
  'code': 'K7M4QX2D',
  'link': 'https://kabsolive.com/i/K7M4QX2D',
  'level': {'code': 'SILVER', 'commissionBps': 500},
  'nextLevel': {'code': 'GOLD', 'activeReferrals': 6, 'topupCoins': 6800000},
  'month': {
    'month': '2026-11',
    'activeReferrals': 9,
    'topupCoins': 8200000,
    'target': {
      'code': 'GOLD',
      'minActiveReferrals': 15,
      'minTopupCoins': 15000000,
      'reward': {'kind': 'VIP_DAYS', 'amount': 7, 'vipTier': 'VIP_1'},
    },
  },
  'referrals': {'total': 23, 'active': 17, 'pending': 6, 'void': 2},
  'commissions': {
    'pendingCherries': 410000,
    'heldCherries': 0,
    'paidCherries': 3860000,
    'reversedCherries': 50000,
  },
  'history': [
    {
      'month': '2026-10',
      'activeReferrals': 7,
      'topupCoins': 4100000,
      'commissionCherries': 2050000,
      'levelAfter': 'SILVER',
      'rewardStatus': 'GRANTED',
    },
    {
      'month': '2026-09',
      'activeReferrals': 3,
      'topupCoins': 1500000,
      'commissionCherries': 450000,
      'levelAfter': 'BRONZE',
      'rewardStatus': 'NONE',
    },
  ],
  'recent': [
    {
      'id': '01a39000-0000-7000-8000-0000000000c1',
      'at': '2026-11-12T18:20:00.000Z',
      'friend': 'م***د',
      'coins': 1000000,
      'cherries': 500000,
      'status': 'PENDING',
    },
    {
      'id': '01a39000-0000-7000-8000-0000000000c2',
      'at': '2026-11-03T09:05:00.000Z',
      'friend': 'S***a',
      'coins': 600000,
      'cherries': 300000,
      'status': 'CREDITED',
    },
    {
      'id': '01a39000-0000-7000-8000-0000000000c3',
      'at': '2026-11-01T12:40:00.000Z',
      'friend': 'ع***ي',
      'coins': 100000,
      'cherries': 50000,
      'status': 'REVERSED',
    },
  ],
};

AmbassadorDashboard ambassadorDashboard({bool payoutsHeld = false}) =>
    AmbassadorDashboard.fromJson(
      ambassadorDashboardJson(payoutsHeld: payoutsHeld),
    );

/// A fake repository: the given answers, the drafts it was sent.
class FakeAmbassadorRepository implements AmbassadorRepository {
  new({AmbassadorProgramme? programme, AmbassadorDashboard? dashboard})
    : programmeValue = programme ?? ambassadorProgramme(),
      dashboardValue = dashboard ?? ambassadorDashboard();

  AmbassadorProgramme programmeValue;
  AmbassadorDashboard dashboardValue;
  final List<AmbassadorApplicationDraft> sent = [];

  @override
  Future<AmbassadorProgramme> programme() async => programmeValue;

  @override
  Future<AmbassadorProgramme> apply(AmbassadorApplicationDraft draft) async {
    sent.add(draft);
    programmeValue = ambassadorProgramme(status: 'PENDING', refusal: 'PENDING');
    return programmeValue;
  }

  @override
  Future<AmbassadorDashboard> dashboard() async => dashboardValue;
}
