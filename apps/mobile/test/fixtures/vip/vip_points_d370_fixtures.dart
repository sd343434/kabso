// D370 «نقاط الشحن»: fake VIP tiers priced in recharge points (the owner's
// table: VIP1 2 000 000, VIP2 3 500 000; VIP3 not redeemable) and a points
// history, for the VIP page and wallet tests and goldens. Test data only.

import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/wallet/data/recharge_points_repository.dart';

/// The goldens' fixed moment.
final DateTime d370Now = DateTime.utc(2026, 11, 11, 9, 30);

VipTier d370Tier(int level, {int? pricePoints, int discount = 15}) => VipTier(
  id: 'p$level',
  code: 'VIP_$level',
  name: 'VIP $level',
  level: level,
  color: const [0xFF2E8B3D, 0xFF2AA7B8, 0xFFE50914][level - 1],
  priceCoins: level * 1000000,
  durationDays: 30,
  renewalDiscountPercent: discount,
  pricePoints: pricePoints,
  renewPricePoints: pricePoints == null
      ? null
      : pricePoints * (100 - discount) ~/ 100,
  perks: const [
    VipPerk(code: 'BADGE', title: 'VIP badge', available: true),
    VipPerk(code: 'AVATAR_FRAME', title: 'Avatar frame', available: true),
    VipPerk(code: 'CHAT_BUBBLE', title: 'Chat bubble', available: true),
  ],
);

final VipTierList d370Tiers = VipTierList(
  tiers: [
    d370Tier(1, pricePoints: 2000000),
    d370Tier(2, pricePoints: 3500000),
    d370Tier(3),
  ],
  maxAheadDays: 400,
);

RechargePointsEntry d370Entry(
  String id,
  RechargePointsReason reason,
  int delta,
  int after, {
  int hoursAgo = 0,
}) => RechargePointsEntry(
  id: id,
  reason: reason,
  delta: delta,
  balanceAfter: after,
  createdAt: d370Now.subtract(Duration(hours: hoursAgo)),
);

final List<RechargePointsEntry> d370History = [
  d370Entry('e5', RechargePointsReason.vipRedeem, -2000000, 2500000),
  d370Entry(
    'e4',
    RechargePointsReason.rechargeAgent,
    3000000,
    4500000,
    hoursAgo: 5,
  ),
  d370Entry(
    'e3',
    RechargePointsReason.reversal,
    -500000,
    1500000,
    hoursAgo: 30,
  ),
  d370Entry(
    'e2',
    RechargePointsReason.rechargeStore,
    500000,
    2000000,
    hoursAgo: 48,
  ),
  d370Entry(
    'e1',
    RechargePointsReason.rechargeWeb,
    1500000,
    1500000,
    hoursAgo: 72,
  ),
];
