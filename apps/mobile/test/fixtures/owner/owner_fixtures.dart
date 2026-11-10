// D301 (§10.112): the app owner's profile — a sample owner, his journey,
// his official announcements and the dashboard's numbers (tests only).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/models/verification_badge.dart';
import 'package:kabso_live/features/owner_profile/domain/owner_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_posts_repository.dart' show postJson;

const ownerPosterAr = 'https://cdn.k.test/owner/cover.ar.webp';
const ownerPosterEn = 'https://cdn.k.test/owner/cover.en.webp';
const ownerVideoAr = 'https://cdn.k.test/owner/cover.ar.mp4';
const ownerVideoEn = 'https://cdn.k.test/owner/cover.en.mp4';

/// The owner's two cover videos (Arabic 24 s, English 18 s).
const OwnerCoverVideo ownerVideos = OwnerCoverVideo(
  ar: CoverVideoVariant(
    url: ownerVideoAr,
    posterUrl: ownerPosterAr,
    durationMs: 24000,
    width: 1080,
    height: 1920,
  ),
  en: CoverVideoVariant(
    url: ownerVideoEn,
    posterUrl: ownerPosterEn,
    durationMs: 18000,
    width: 1080,
    height: 1920,
  ),
);

/// D357: the founder's social links in the fixtures (test URLs only), the
/// row's order shuffled and one other link, as a server could send them.
const List<ProfileLink> ownerSocialLinks = [
  ProfileLink(
    id: 'l-sc',
    url: 'https://www.snapchat.com/add/kabso.test',
    platform: ProfileLinkPlatform.snapchat,
  ),
  ProfileLink(
    id: 'l-ig',
    url: 'https://www.instagram.com/kabso.test',
    platform: ProfileLinkPlatform.instagram,
  ),
  ProfileLink(
    id: 'l-web',
    url: 'https://kabso.test/press',
    label: 'kabso.test',
    platform: ProfileLinkPlatform.other,
  ),
  ProfileLink(
    id: 'l-wa',
    url: 'https://wa.me/966500000000',
    platform: ProfileLinkPlatform.whatsapp,
  ),
  ProfileLink(
    id: 'l-fb',
    url: 'https://www.facebook.com/kabso.test',
    platform: ProfileLinkPlatform.facebook,
  ),
];

/// The app owner «مؤسس كابسو», seen by [self] or not. His payload still
/// carries the retired OWNER seal (an older server's, D357: never drawn).
PublicProfile ownerProfile({
  required bool ar,
  bool self = false,
  OwnerCoverVideo? videos = ownerVideos,
  bool following = false,
  int? feedbackCount = ownerFeedbackCount,
  List<ProfileLink> links = ownerSocialLinks,
}) => PublicProfile(
  id: 'owner-0',
  username: 'kabso',
  displayName: ar ? 'مؤسس كابسو' : 'Kabso Founder',
  avatarUrl: null,
  bio: ar ? 'مؤسس كابسو لايف' : 'Founder of Kabso Live',
  isPrivate: false,
  followerCount: 2400000,
  followingCount: 128,
  isFollowing: following,
  isSelf: self,
  liveRoomId: null,
  kabsoTeam: true,
  staffId: 'Kabso',
  verification: VerificationBadge.owner,
  joinedMonth: '2026-01',
  kabsoOwner: true,
  coverVideo: videos,
  founderFeedbackCount: feedbackCount,
  links: links,
);

/// D357: the founder's «الاقتراحات والشكاوى» in the fixtures (shown «1.2K»).
const int ownerFeedbackCount = 1284;

/// «رحلة Kabso» as in mock-up 5 (the last one «الأحدث»).
const List<JourneyMilestone> ownerJourney = [
  JourneyMilestone(
    id: 'm1',
    titleAr: 'إطلاق كابسو لايف — 2026',
    titleEn: 'Kabso Live launch — 2026',
    lineAr: 'اليوم الأول: بث واحد وحلم كبير.',
    lineEn: 'Day one: one live and a big dream.',
    year: 2026,
    month: 1,
    icon: JourneyIcon.rocket,
  ),
  JourneyMilestone(
    id: 'm2',
    titleAr: 'أول 100 ألف مستخدم',
    titleEn: 'The first 100K users',
    lineAr: 'مجتمع عربي ينمو كل يوم.',
    lineEn: 'An Arab community growing every day.',
    year: 2026,
    month: 3,
    icon: JourneyIcon.users,
    position: 1,
  ),
  JourneyMilestone(
    id: 'm3',
    titleAr: 'أول وكالة',
    titleEn: 'The first agency',
    lineAr: 'أول شراكة لإدارة المضيفين ودعمهم.',
    lineEn: 'The first partner to manage and support hosts.',
    year: 2026,
    month: 5,
    icon: JourneyIcon.agency,
    position: 2,
  ),
  JourneyMilestone(
    id: 'm4',
    titleAr: 'مليون مستخدم',
    titleEn: 'One million users',
    lineAr: 'كابسو لايف في كل بيت عربي.',
    lineEn: 'Kabso Live in every Arab home.',
    year: 2026,
    month: 8,
    icon: JourneyIcon.globe,
    position: 3,
  ),
  JourneyMilestone(
    id: 'm5',
    titleAr: 'إطلاق صناع المحتوى',
    titleEn: 'Content creators launch',
    lineAr: 'برنامج يدعم المبدعين ويكافئهم.',
    lineEn: 'A programme that supports and rewards creators.',
    year: 2026,
    month: 10,
    icon: JourneyIcon.sparkles,
    latest: true,
    position: 4,
  ),
];

/// Three official announcements (the first pinned), published [now] minus
/// 2 days, 5 days and a month.
List<Post> ownerOfficialPosts({required bool ar, required DateTime now}) {
  Post post(String id, String text, Duration ago, {bool pinned = false}) {
    final at = now.subtract(ago).toUtc().toIso8601String();
    return Post.fromJson({
      ...postJson(id, text: text),
      'author': {
        'id': 'owner-0',
        'username': 'kabso',
        'displayName': ar ? 'مؤسس كابسو' : 'Kabso Founder',
        'avatarUrl': null,
      },
      'createdAt': at,
      'publishedAt': at,
      'pinned': pinned,
      'official': true,
    });
  }

  return [
    post(
      'o1',
      ar
          ? 'إطلاق الإصدار 2.0 من كابسو لايف\nكل الجديد في البثوث'
          : 'Kabso Live 2.0 is here\nEverything new in lives',
      const Duration(days: 2),
      pinned: true,
    ),
    post(
      'o2',
      ar
          ? 'تحديث قواعد المجتمع والإشراف'
          : 'Community and moderation rules update',
      const Duration(days: 5),
    ),
    post(
      'o3',
      ar
          ? 'شكراً لمليون مستخدم — هدايا للجميع'
          : 'Thank you, one million users — gifts for all',
      const Duration(days: 31),
    ),
  ];
}

/// «لوحة المؤسس»: 48 213 online, 1 284 lives, $8 431.25 today.
OwnerDashboard ownerDashboard({DateTime? at}) => OwnerDashboard(
  onlineNow: 48213,
  liveRoomsNow: 1284,
  incomeMinor: 843125,
  websiteMinor: 612500,
  agentsMinor: 230625,
  currency: 'USD',
  timeZone: 'Asia/Riyadh',
  generatedAt: at ?? DateTime.utc(2026, 11, 7, 9, 41),
);

/// The Kabso Team accounts «أبلغ عن موظف» finds.
const List<FeedbackStaff> ownerFeedbackStaff = [
  FeedbackStaff(
    id: 'staff-1',
    username: 'mod_sara',
    displayName: 'سارة — مشرفة',
    staffId: 'Kabso01',
  ),
  FeedbackStaff(
    id: 'staff-2',
    username: 'support_ali',
    displayName: 'علي — دعم',
    staffId: 'Kabso02',
  ),
];

/// A stage-like poster (dark red, two warm spotlights) painted for the
/// tests — no third-party picture.
Future<Uint8List> paintOwnerPoster() async {
  final recorder = ui.PictureRecorder();
  const size = Size(540, 960);
  final canvas = ui.Canvas(recorder)
    ..drawRect(
      Offset.zero & size,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(0, 960),
          [
            const Color(0xFF2A0508),
            const Color(0xFF8A050C),
            const Color(0xFF1A0204),
          ],
          [0, 0.55, 1],
        ),
    );
  for (final (x, c) in [
    (140.0, const Color(0x66FFB347)),
    (400.0, const Color(0x55FF5A5F)),
  ]) {
    canvas.drawCircle(
      Offset(x, 260),
      220,
      ui.Paint()
        ..shader = ui.Gradient.radial(Offset(x, 260), 220, [
          c,
          const Color(0x00000000),
        ]),
    );
  }
  canvas.drawRect(
    const Rect.fromLTWH(0, 760, 540, 200),
    ui.Paint()..color = const Color(0xFF120203),
  );
  final image = await recorder.endRecording().toImage(540, 960);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// D301 follow-up (§10.112.10): the owner's fixed monthly costs.
const List<OwnerFixedCost> ownerFixedCosts = [
  OwnerFixedCost(
    id: 'c1',
    name: 'Claude',
    monthlyMinor: 6000,
    activeFrom: '2026-01-01',
  ),
  OwnerFixedCost(
    id: 'c2',
    name: 'LiveKit',
    monthlyMinor: 45000,
    activeFrom: '2026-01-01',
  ),
  OwnerFixedCost(
    id: 'c3',
    name: 'Servers',
    monthlyMinor: 120000,
    activeFrom: '2026-01-01',
  ),
  OwnerFixedCost(
    id: 'c4',
    name: 'DeepAR filters',
    monthlyMinor: 30000,
    activeFrom: '2026-03-01',
    activeTo: '2026-10-31',
  ),
];

List<ProfitDeduction> _deductions(List<int> minor, List<int> cherries) => [
  for (final (i, k) in ProfitDeductionKey.values.indexed)
    ProfitDeduction(
      key: k,
      amountMinor: minor[i],
      cherries:
          k == ProfitDeductionKey.cardFees ||
              k == ProfitDeductionKey.coinRewards
          ? null
          : cherries[i],
      orders: k == ProfitDeductionKey.cardFees ? cherries[i] : null,
      coins: k == ProfitDeductionKey.coinRewards ? cherries[i] : null,
    ),
];

List<FixedCostShare> _shares(int days) => [
  for (final c in ownerFixedCosts.take(3))
    FixedCostShare(
      id: c.id,
      name: c.name,
      monthlyMinor: c.monthlyMinor,
      days: days,
      shareMinor: (c.monthlyMinor * days / 30).round(),
    ),
];

/// «الربح» of 7 November 2026 and November to date (7 of 30 days). With
/// [loss], the month's costs exceed the income (after < 0).
OwnerProfit ownerProfit({bool loss = false}) => OwnerProfit(
  today: '2026-11-07',
  rateCherries: 1000000,
  rateMinor: 110,
  cardFeeBps: 290,
  cardFeeFixedMinor: 30,
  coinValueMinorPerMillion: 1200,
  generatedAt: DateTime.utc(2026, 11, 7, 9, 41),
  day: OwnerProfitPeriod(
    month: false,
    key: '2026-11-07',
    from: '2026-11-07',
    to: '2026-11-07',
    days: 1,
    daysInMonth: 30,
    beforeMinor: 843125,
    cardChargedMinor: 650000,
    refundsMinor: 25000,
    chargebacksMinor: 12500,
    agentsMinor: 230625,
    deductions: _deductions(
      [412000, 61800, 4400, 8800, 2200, 0, 1440, 22600],
      [3745454545, 561818181, 40000000, 80000000, 20000000, 0, 1200000, 125],
    ),
    fixedCostsMinor: 5700,
    fixedCosts: _shares(1),
    afterMinor: 843125 - 513240 - 5700,
    otherCurrencies: const [
      ProfitOtherCurrency(
        currency: 'EUR',
        beforeMinor: 5000,
        deductionsMinor: 0,
        afterMinor: 5000,
      ),
    ],
  ),
  month: OwnerProfitPeriod(
    month: true,
    key: '2026-11',
    from: '2026-11-01',
    to: '2026-11-07',
    days: 7,
    daysInMonth: 30,
    partial: true,
    beforeMinor: loss ? 300000 : 5120000,
    cardChargedMinor: loss ? 250000 : 4000000,
    refundsMinor: 50000,
    chargebacksMinor: 25000,
    agentsMinor: loss ? 125000 : 1195000,
    deductions: _deductions(
      [2560000, 384000, 27000, 51000, 13000, -5000, 10000, 140000],
      [
        23272727272,
        3490909090,
        245454545,
        463636363,
        118181818,
        -45454545,
        8333333,
        760,
      ],
    ),
    fixedCostsMinor: 39900,
    fixedCosts: _shares(7),
    afterMinor: (loss ? 300000 : 5120000) - 3180000 - 39900,
  ),
);
