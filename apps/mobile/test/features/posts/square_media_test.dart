// Owner (after D218): «صورة البوست اجعلها مربعة ويمكن ان تكون سكرول مثل
// الانستقرام» — a post's media is square (full width, cover-cropped), and
// several photos swipe with a «1/3» counter in the top corner and dots under
// the media; one photo has no dots.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_post_tile.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/fixture_images.dart';
import '../../fixtures/live/live_fixtures.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

FeedPostData _post(int photos) {
  final images = [
    for (var i = 0; i < photos; i++)
      fixtureImage(
        top: Color(0xFF203040 + i * 0x101010),
        bottom: const Color(0xFFEEBB88),
        width: 120,
        height: 90,
      ),
  ];
  return FeedPostData(
    authorName: 'Sara',
    postedAt: fixtureNow,
    media: images.first,
    gallery: photos > 1 ? images : const [],
    // A landscape photo: the card still shows a square.
    mediaAspect: 4 / 3,
  );
}

Future<void> _pump(WidgetTester tester, int photos, AppLanguage lang) async {
  setViewport(tester, GoldenViewport.phone);
  await withClock(Clock.fixed(fixtureNow), () async {
    await pumpScreen(
      tester,
      Scaffold(
        body: ListView(children: [FeedPostTile(post: _post(photos))]),
      ),
      language: lang,
    );
    await tester.pumpAndSettle();
  });
}

void main() {
  for (final lang in AppLanguage.values) {
    testWidgets('${lang.name}: three photos — a square pager, «1/3» in the '
        'top corner, dots under the media; a swipe shows the next', (
      tester,
    ) async {
      await _pump(tester, 3, lang);
      final pager = tester.getRect(find.byKey(FeedPostTile.mediaPagerKey));
      expect(pager.width, 393);
      expect(pager.height, moreOrLessEquals(393));
      final counter = tester.getRect(find.byKey(FeedPostTile.mediaCounterKey));
      expect(pager.contains(counter.center), isTrue);
      expect(counter.top - pager.top, lessThan(24));
      final dots = tester.getRect(find.byKey(FeedPostTile.mediaDotsKey));
      expect(dots.top, greaterThanOrEqualTo(pager.bottom));
      expect(find.text('1/3'), findsOneWidget);
      // The next photo comes from the reading end (left in Arabic).
      await tester.fling(
        find.byKey(FeedPostTile.mediaPagerKey),
        Offset(lang == AppLanguage.ar ? 300 : -300, 0),
        1500,
      );
      await tester.pumpAndSettle();
      expect(find.text('2/3'), findsOneWidget);
    });
  }

  testWidgets('one photo: a square, no dots, no counter', (tester) async {
    await _pump(tester, 1, AppLanguage.en);
    expect(find.byKey(FeedPostTile.mediaDotsKey), findsNothing);
    expect(find.byKey(FeedPostTile.mediaCounterKey), findsNothing);
    final image = tester.getRect(
      find.descendant(
        of: find.byType(FeedPostTile),
        matching: find.byType(AspectRatio),
      ),
    );
    expect(image.width, 393);
    expect(image.height, moreOrLessEquals(393));
  });
}
