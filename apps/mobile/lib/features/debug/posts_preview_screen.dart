import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/home/application/home_feed_provider.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/home/presentation/widgets/home_reel.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/debug/posts-preview` — the real Reels tab ([FeedScreen], D52) with
/// labelled test data: its posts, stories and reels sources are overridden
/// (production returns "unavailable"), under the app's bottom bar. Names
/// carry "(test)" and the photos are the dev-only preview set.
class PostsPreviewScreen extends StatelessWidget {
  const new({super.key, this.initialTab = HomeTab.initial});

  final HomeTab initialTab;

  @override
  Widget build(BuildContext context) {
    final ar = Directionality.of(context) == TextDirection.rtl;
    final now = clock.now();
    final fixture = postsPreviewFixture(ar: ar, now: now);
    return ProviderScope(
      overrides: [
        // Following shows a smaller feed than Trending.
        homePostsProvider.overrideWith(
          (ref, feed) => FeedItems(
            feed == HomeFeed.trending ? fixture : fixture.sublist(2),
          ),
        ),
        homeStoriesProvider.overrideWithValue(
          AsyncData(FeedItems(storiesPreviewFixture(ar: ar))),
        ),
        homeReelsProvider.overrideWith((ref, feed) {
          final reels = reelsPreviewFixture(fixture);
          return FeedItems(
            feed == HomeFeed.trending ? reels : reels.reversed.toList(),
          );
        }),
        // Follow on a reel succeeds locally: the preview has no server.
        profileRepositoryProvider.overrideWithValue(_PreviewFollow()),
      ],
      child: Scaffold(
        body: FeedScreen(initialTab: initialTab, showNotifications: false),
        bottomNavigationBar: KBottomNav(
          currentIndex: AppRoutes.shellBranches.indexOf(AppRoutes.reels),
          onSelect: (i) => context.go(AppRoutes.shellBranches[i]),
          items: shellNavItems(context.l10n),
        ),
      ),
    );
  }
}

/// Reels of the preview (labelled test data): the posts' authors, portrait
/// covers, counts, and one author the viewer already follows.
List<FeedReelData> reelsPreviewFixture(List<FeedPostData> posts) => [
  for (final (i, post) in posts.indexed)
    FeedReelData(
      authorName: post.authorName,
      authorAvatar: post.authorAvatar,
      authorUsername: 'preview_test_$i',
      isFollowingAuthor: i == 1,
      postedAt: post.postedAt,
      caption: post.text,
      cover: PreviewPhotos.cover(4 + i),
      likes: const [432000, 8400, 1250][i % 3],
      comments: const [1230, 312, 48][i % 3],
      shares: const [980, 45, 12][i % 3],
    ),
];

/// Follow for the preview only: succeeds without a server.
class _PreviewFollow implements ProfileRepository {
  @override
  Future<PublicProfile> getProfile(String username) =>
      throw UnsupportedError('preview');

  @override
  Future<FollowState> follow(String username) async =>
      const FollowState(isFollowing: true, followerCount: 1);

  @override
  Future<FollowState> unfollow(String username) async =>
      const FollowState(isFollowing: false, followerCount: 0);
}

/// Stories of the preview (labelled test data).
List<FeedStoryData> storiesPreviewFixture({required bool ar}) => [
  for (final (i, (en, arName)) in const [
    ('Layla (test)', 'ليلى (تجربة)'),
    ('Omar (test)', 'عمر (تجربة)'),
    ('Huda (test)', 'هدى (تجربة)'),
    ('Sami (test)', 'سامي (تجربة)'),
    ('Nour (test)', 'نور (تجربة)'),
  ].indexed)
    FeedStoryData(
      authorName: ar ? arName : en,
      authorAvatar: i < PreviewPhotos.avatars.length
          ? PreviewPhotos.avatar(i)
          : null,
      seen: i == 3,
    ),
];

/// Posts of the preview (labelled test data): a video post, a text-only
/// post and a photo post, each with counts.
List<FeedPostData> postsPreviewFixture({
  required bool ar,
  required DateTime now,
}) => [
  FeedPostData(
    authorName: ar ? 'ليلى (تجربة)' : 'Layla (test)',
    authorAvatar: PreviewPhotos.avatar(0),
    authorUsername: 'preview_test_0',
    isFollowingAuthor: false,
    postedAt: now.subtract(const Duration(hours: 2)),
    text: ar
        ? 'جولة مسائية في المدينة القديمة، نص تجريبي طويل يلتف على أكثر من '
              'سطرين ليظهر زر عرض المزيد #بيانات_اختبار'
        : 'An evening walk through the old town, a long test caption that '
              'wraps past two lines to show see more #test_data',
    location: ar ? 'موقع تجريبي' : 'Test location',
    media: PreviewPhoto.enabled
        ? PreviewPhotos.image(PreviewPhotoKind.landscape, 0)
        : null,
    mediaAspect: 4 / 3,
    isVideo: true,
    likes: 105,
    comments: 15,
    shares: 50,
  ),
  FeedPostData(
    authorName: ar ? 'هدى (تجربة)' : 'Huda (test)',
    authorAvatar: PreviewPhotos.avatar(2),
    authorUsername: 'preview_test_2',
    isFollowingAuthor: true,
    postedAt: now.subtract(const Duration(hours: 5)),
    text: ar
        ? 'منشور نصي تجريبي بلا صورة، يلتف على سطرين ثم يختصر ليظهر عرض '
              'المزيد في نهايته #بيانات_اختبار'
        : 'A text-only test post with no photo; it wraps onto two lines and '
              'is then shortened with see more #test_data',
    likes: 12400,
    comments: 312,
    shares: 45,
  ),
  FeedPostData(
    authorName: ar ? 'عمر (تجربة)' : 'Omar (test)',
    authorAvatar: PreviewPhotos.avatar(1),
    postedAt: now.subtract(const Duration(days: 1)),
    text: ar ? 'صورة تجريبية #بيانات_اختبار' : 'A test photo #test_data',
    media: PreviewPhoto.enabled
        ? PreviewPhotos.image(PreviewPhotoKind.landscape, 2)
        : null,
    mediaAspect: 4 / 3,
    likes: 980,
    comments: 41,
    shares: 7,
  ),
];
