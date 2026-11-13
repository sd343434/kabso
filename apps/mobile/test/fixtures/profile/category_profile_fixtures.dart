// D386 (CONVENTIONS §10.175): the fake data of the category-profile tests
// and goldens — a verified person per family with a featured section shaped
// like `GET /users/{username}/featured`. Text written for these tests (no
// real person, no real work).

import 'package:kabso_live/core/models/profile_fields.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/profile/category/category_models.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:material_ui/material_ui.dart';

import '../fixture_images.dart';

/// The fixed clock of the D386 goldens.
final DateTime d386Now = DateTime.utc(2026, 11, 12, 9, 30);

const d386Author = UserSummary(
  id: 'user-386',
  username: 'kabso386',
  displayName: 'نور',
  avatarUrl: null,
);

/// A post as the featured section receives it.
Post d386Post(
  String id, {
  required String text,
  MediaType? media,
  bool reel = false,
  int views = 0,
  int durationMs = 0,
}) => Post(
  id: id,
  author: d386Author,
  text: text,
  media: [
    if (media != null)
      MediaAsset(
        id: 'm-$id',
        url: 'https://cdn.k.test/d386/$id.jpg',
        thumbUrl: 'https://cdn.k.test/d386/$id.jpg',
        posterUrl: media == MediaType.video
            ? 'https://cdn.k.test/d386/$id.jpg'
            : null,
        width: 1080,
        height: 1350,
        type: media,
        durationMs: durationMs == 0 ? null : durationMs,
      ),
  ],
  hashtags: const [],
  mentions: const [],
  status: 'PUBLISHED',
  createdAt: d386Now.subtract(const Duration(days: 2)),
  publishedAt: d386Now.subtract(const Duration(days: 2)),
  likeCount: 12,
  commentCount: 3,
  shareCount: 0,
  repostCount: 0,
  viewCount: views,
  viewerHasLiked: false,
  viewerHasSaved: false,
  viewerHasReposted: false,
  isSelf: false,
  pinned: false,
  commentsEnabled: true,
  whoCanComment: WhoCanComment.everyone,
  hideLikeCount: false,
  pendingModeration: false,
  isReel: reel,
);

/// The pictures of the fixtures, by URL (a palette per post).
MemoryImage d386Image(String url) {
  final n = url.hashCode.abs();
  const tops = [
    Color(0xFF3B2A6B),
    Color(0xFF1F5E57),
    Color(0xFF6B3A2A),
    Color(0xFF274A7A),
    Color(0xFF6A2747),
    Color(0xFF4F5F23),
  ];
  const bottoms = [
    Color(0xFFB58BE0),
    Color(0xFF8FD9C4),
    Color(0xFFE8B48A),
    Color(0xFF8DB7F0),
    Color(0xFFF09AC0),
    Color(0xFFCDE08F),
  ];
  return fixtureImage(
    top: tops[n % tops.length],
    bottom: bottoms[(n ~/ 7) % bottoms.length],
  );
}

/// The person's profile with [category] (verified or not).
PublicProfile d386Profile({
  required AccountCategory? category,
  required bool ar,
  bool verified = true,
  bool self = false,
}) => PublicProfile(
  id: 'user-386',
  username: 'kabso386',
  displayName: ar ? 'نور' : 'Noor',
  avatarUrl: null,
  bio: ar ? 'أهلاً بكم في صفحتي' : 'Welcome to my page',
  isPrivate: false,
  followerCount: 18400,
  followingCount: 212,
  isFollowing: false,
  isSelf: self,
  liveRoomId: null,
  category: category,
  categoryVerified: verified && category != null,
  joinedMonth: '2026-03',
  country: 'SA',
);

/// The featured section of [category] (its server section, sample items).
ProfileFeatured d386Featured(AccountCategory category, {required bool ar}) {
  final section = FeaturedSection.of(category);
  if (section == null) return ProfileFeatured.empty;
  String t(String a, String e) => ar ? a : e;
  final items = switch (section) {
    FeaturedSection.works => [
      d386Post(
        'w1',
        text: t('أغنية المساء', 'Evening song'),
        media: MediaType.video,
      ),
      d386Post(
        'w2',
        text: t('على المسرح', 'On stage'),
        media: MediaType.video,
        reel: true,
      ),
      d386Post('w3', text: t('بروفة', 'Rehearsal'), media: MediaType.video),
    ],
    FeaturedSection.recitations || FeaturedSection.stories => [
      d386Post(
        'r1',
        text: section == FeaturedSection.recitations
            ? t('سورة الرحمن', 'Surah Ar-Rahman')
            : t('حكاية الصياد', 'The fisherman’s tale'),
        media: MediaType.video,
        durationMs: 312000,
      ),
      d386Post(
        'r2',
        text: section == FeaturedSection.recitations
            ? t('سورة الملك', 'Surah Al-Mulk')
            : t('الأميرة والقمر', 'The princess and the moon'),
        media: MediaType.video,
        durationMs: 245000,
      ),
      d386Post(
        'r3',
        text: section == FeaturedSection.recitations
            ? t('سورة يس', 'Surah Ya-Sin')
            : t('رحلة السندباد', 'Sindbad’s voyage'),
        media: MediaType.video,
        durationMs: 498000,
      ),
    ],
    FeaturedSection.poems => [
      d386Post(
        'p1',
        text: t(
          'وأحببتُ في الليلِ هدوءَهُ\nكأنّ النجومَ تُصغي لقلبي',
          'I loved the night for its calm\n'
              'as if the stars listened to my heart',
        ),
      ),
      d386Post(
        'p2',
        text: t(
          'على شاطئِ الأيامِ كتبتُ اسمي\nفجاءَ الموجُ يحفظُهُ',
          'On the shore of days I wrote my name\nand the wave came to keep it',
        ),
      ),
    ],
    FeaturedSection.articles || FeaturedSection.reports => [
      d386Post(
        'a1',
        text: t(
          'كيف تغيّرت المدن في عشر سنوات\nجولة بين الأحياء القديمة والجديدة',
          'How cities changed in ten years\n'
              'A walk through old and new quarters',
        ),
        media: section == FeaturedSection.reports ? MediaType.image : null,
      ),
      d386Post(
        'a2',
        text: t(
          'القراءة في زمن الشاشات\nلماذا نعود إلى الكتب الورقية',
          'Reading in the age of screens\nWhy we return to paper books',
        ),
        media: section == FeaturedSection.reports ? MediaType.image : null,
      ),
    ],
    FeaturedSection.gallery => [
      for (var i = 1; i <= 6; i++)
        d386Post('g$i', text: t('لقطة $i', 'Shot $i'), media: MediaType.image),
    ],
    FeaturedSection.mostViewed => [
      d386Post(
        'v1',
        text: t('مشهد', 'Sketch'),
        media: MediaType.video,
        reel: true,
        views: 1250000,
      ),
      d386Post(
        'v2',
        text: t('كواليس', 'Backstage'),
        media: MediaType.video,
        reel: true,
        views: 84000,
      ),
      d386Post(
        'v3',
        text: t('تحدٍّ', 'Challenge'),
        media: MediaType.video,
        reel: true,
        views: 9100,
      ),
    ],
    FeaturedSection.program => const <Post>[],
    FeaturedSection.games ||
    FeaturedSection.achievements ||
    FeaturedSection.highlights => [
      d386Post(
        'h1',
        text: t('البطولة الأولى', 'First championship'),
        media: MediaType.image,
      ),
      d386Post(
        'h2',
        text: t('يوم التدريب', 'Training day'),
        media: MediaType.image,
      ),
      d386Post('h3', text: t('الفريق', 'The team'), media: MediaType.image),
    ],
  };
  return ProfileFeatured(
    section: section,
    source: FeaturedSource.pinned,
    items: items,
    schedule: section == FeaturedSection.program
        ? [
            FeaturedScheduleItem(
              id: 's1',
              title: t('حلقة الأسبوع', 'This week’s episode'),
              startsAt: d386Now.add(const Duration(days: 1, hours: 9)),
              podcast: true,
            ),
            FeaturedScheduleItem(
              id: 's2',
              title: t('لقاء مباشر', 'Live meetup'),
              startsAt: d386Now.add(const Duration(days: 3, hours: 10)),
            ),
          ]
        : const [],
  );
}

/// One category per family (the composites and the per-family tests).
const Map<CategoryFamily, AccountCategory> d386FamilySample = {
  CategoryFamily.music: AccountCategory.singer,
  CategoryFamily.reciter: AccountCategory.quranReciter,
  CategoryFamily.word: AccountCategory.poet,
  CategoryFamily.visual: AccountCategory.photographer,
  CategoryFamily.performer: AccountCategory.comedian,
  CategoryFamily.sportsGames: AccountCategory.athlete,
  CategoryFamily.lifestyle: AccountCategory.chef,
  CategoryFamily.public: AccountCategory.other,
};
