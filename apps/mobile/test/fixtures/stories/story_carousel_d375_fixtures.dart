// D375 fixtures: the people with stories in the viewer's carousel (tray
// order) and their photo stories. Avatars and photos are generated
// gradients (no real people, no third-party art).

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/posts/domain/post_models.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';
import 'package:material_ui/material_ui.dart';

import '../fixture_images.dart';

/// The clock the goldens pin: two hours after the stories were posted.
final DateTime d375Now = DateTime.utc(2026, 11, 11, 11);

/// One person: username, Arabic and English names, colours, seen.
typedef D375Person = ({
  String username,
  String ar,
  String en,
  Color top,
  Color bottom,
  bool seen,
});

const List<D375Person> d375People = [
  (
    username: 'nour',
    ar: 'نور',
    en: 'Nour',
    top: Color(0xFF3A6EA5),
    bottom: Color(0xFFF2C14E),
    seen: false,
  ),
  (
    username: 'omar',
    ar: 'عمر',
    en: 'Omar',
    top: Color(0xFF2D6A4F),
    bottom: Color(0xFF95D5B2),
    seen: true,
  ),
  (
    username: 'sara',
    ar: 'سارة',
    en: 'Sara',
    top: Color(0xFF6D597A),
    bottom: Color(0xFFE56B6F),
    seen: false,
  ),
  (
    username: 'huda',
    ar: 'هدى',
    en: 'Huda',
    top: Color(0xFF14213D),
    bottom: Color(0xFFFCA311),
    seen: false,
  ),
  (
    username: 'ali',
    ar: 'علي',
    en: 'Ali',
    top: Color(0xFF264653),
    bottom: Color(0xFF2A9D8F),
    seen: true,
  ),
  (
    username: 'reem',
    ar: 'ريم',
    en: 'Reem',
    top: Color(0xFF9D0208),
    bottom: Color(0xFFFFBA08),
    seen: false,
  ),
];

/// The tray as the viewer reads it (`homeStoriesProvider`).
List<FeedStoryData> d375Tray({required bool ar}) => [
  for (final p in d375People)
    FeedStoryData(
      authorName: ar ? p.ar : p.en,
      authorAvatar: fixtureImage(top: p.top, bottom: p.bottom),
      username: p.username,
      seen: p.seen,
    ),
];

/// The photo served for [url] (each person's own gradient).
MemoryImage d375Photo(String url) {
  for (final p in d375People) {
    if (url.contains('/d375-${p.username}-')) {
      return fixtureImage(
        top: p.top,
        bottom: p.bottom,
        width: 360,
        height: 640,
      );
    }
  }
  return fixtureImage(
    top: const Color(0xFF333333),
    bottom: const Color(0xFF777777),
  );
}

/// Two photo stories per person (the first already seen for seen people).
Map<String, List<Story>> d375Stories({required bool ar}) => {
  for (final p in d375People)
    p.username: [
      for (var i = 1; i <= 2; i++)
        Story(
          id: 'd375-${p.username}-$i',
          author: UserSummary(
            id: 'u-${p.username}',
            username: p.username,
            displayName: ar ? p.ar : p.en,
            avatarUrl: null,
          ),
          media: MediaAsset(
            id: 'd375-${p.username}-$i-m',
            url:
                'https://media.example.test/media/d375-${p.username}-$i/1920.webp',
            thumbUrl:
                'https://media.example.test/media/d375-${p.username}-$i/320.webp',
            width: 1080,
            height: 1920,
          ),
          text: '',
          mentions: const [],
          createdAt: DateTime.utc(2026, 11, 11, 9),
          expiresAt: DateTime.utc(2026, 11, 12, 9),
          viewerHasSeen: p.seen,
          isSelf: false,
        ),
    ],
};
