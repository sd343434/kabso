// KL-352 prototype data (labelled fixtures: names, scores and photos are
// made up; photos are the development previews in assets/preview/).
import 'dart:io';

import 'package:kabso_live/features/programs/presentation/event_concepts.dart';
import 'package:kabso_live/features/programs/presentation/event_leaderboard_styles.dart';
import 'package:material_ui/material_ui.dart';

final bgBytes = File('test/fixtures/programs/d303_event_bg_treasure.webp')
    .readAsBytesSync();

const _p = 'assets/preview';

const entries = [
  LbEntry(
    rank: 1,
    name: 'سارة الحربي',
    flag: 'sa',
    score: 60980000,
    photo: '$_p/avatar_layla.webp',
  ),
  LbEntry(
    rank: 2,
    name: 'Khaled.77',
    flag: 'ae',
    score: 36440000,
    photo: '$_p/avatar_karim.webp',
  ),
  LbEntry(
    rank: 3,
    name: 'ليان',
    flag: 'kw',
    score: 8680000,
    photo: '$_p/avatar_rania.webp',
  ),
  LbEntry(
    rank: 4,
    name: 'Omar_Q',
    flag: 'eg',
    score: 5210000,
    photo: '$_p/avatar_omar.webp',
  ),
  LbEntry(
    rank: 5,
    name: 'نورة',
    flag: 'jo',
    score: 2930000,
    photo: '$_p/avatar_huda.webp',
  ),
  LbEntry(rank: 6, name: 'Ahmed Ali', flag: 'iq', score: 1480000),
  LbEntry(rank: 7, name: 'ريم المغربية', flag: 'ma', score: 986400),
];

const me = LbEntry(rank: 23, name: 'أنا', flag: 'sa', score: 412500);

const _cp = 'assets/cp_space';

const tiers = [
  RewardTier(
    from: 1,
    to: 1,
    prizes: [
      RewardPrize(
        kind: RewardKind.entrance,
        name: 'دخولية بوابة القصر',
        days: 7,
        art: '$_cp/privilege_entrance.webp',
        featured: true,
      ),
      RewardPrize(kind: RewardKind.frame, name: 'إطار التاج', days: 7),
      RewardPrize(
        kind: RewardKind.badge,
        name: 'وسام الثراء',
        art: 'assets/medals/medal_wealth_l6.webp',
      ),
      RewardPrize(
        kind: RewardKind.nameBar,
        name: 'شريط الاسم الذهبي',
        days: 30,
      ),
      RewardPrize(
        kind: RewardKind.gift,
        name: 'عربة الأميرة',
        qty: 3,
        art: '$_cp/gift_carriage.webp',
      ),
      RewardPrize(kind: RewardKind.coins, name: 'كوينز', qty: 50000),
    ],
  ),
  RewardTier(
    from: 2,
    to: 2,
    prizes: [
      RewardPrize(kind: RewardKind.frame, name: 'إطار الفضة', days: 7, rank: 2),
      RewardPrize(
        kind: RewardKind.badge,
        name: 'وسام الثراء',
        days: 30,
        art: 'assets/medals/medal_wealth_l5.webp',
      ),
      RewardPrize(
        kind: RewardKind.nameBar,
        name: 'شريط الاسم',
        days: 7,
        rank: 2,
      ),
      RewardPrize(
        kind: RewardKind.gift,
        name: 'البجعة',
        qty: 2,
        art: '$_cp/gift_swan.webp',
      ),
      RewardPrize(kind: RewardKind.coins, name: 'كوينز', qty: 20000),
    ],
  ),
  RewardTier(
    from: 3,
    to: 3,
    prizes: [
      RewardPrize(
        kind: RewardKind.frame,
        name: 'إطار البرونز',
        days: 3,
        rank: 3,
      ),
      RewardPrize(
        kind: RewardKind.badge,
        name: 'وسام الثراء',
        days: 7,
        art: 'assets/medals/medal_wealth_l4.webp',
      ),
      RewardPrize(kind: RewardKind.coins, name: 'كوينز', qty: 10000),
    ],
  ),
  RewardTier(
    from: 4,
    to: 10,
    prizes: [
      RewardPrize(
        kind: RewardKind.badge,
        name: 'شارة الداعم',
        days: 3,
        art: 'assets/recharge_badges/tier_3.webp',
      ),
      RewardPrize(
        kind: RewardKind.gift,
        name: 'وردة',
        qty: 5,
        art: '$_cp/gift_rose.webp',
      ),
      RewardPrize(kind: RewardKind.cherries, name: 'كرز', qty: 500),
    ],
  ),
];

EventShowcase showcase() => EventShowcase(
  title: 'ملك الهدايا',
  dates: '10 – 17 نوفمبر · بتوقيت الرياض',
  startsAt: DateTime.utc(2026, 11, 10, 17),
  endsAt: DateTime.utc(2026, 11, 17, 17),
  gifts: const [
    EventGiftLite('وردة', '$_cp/gift_rose.webp', 10, 20),
    EventGiftLite('البجعة', '$_cp/gift_swan.webp', 520, 520),
    EventGiftLite('الملاك', '$_cp/gift_angel.webp', 1200, 1200),
    EventGiftLite('عربة الأميرة', '$_cp/gift_carriage.webp', 5000, 5000),
    EventGiftLite('الحب الأبدي', '$_cp/gift_eternal.webp', 9999, 9999),
  ],
  entries: entries,
  me: me,
  toNext: 38200,
  tiers: tiers,
  background: MemoryImage(bgBytes),
);
