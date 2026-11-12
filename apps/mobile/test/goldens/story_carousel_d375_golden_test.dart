// D375 (owner 2026-11-11): the story viewer with its people carousel.
//
//   story.carousel.visible.<ar|en>   opened on the third person: the centred
//                                    author (red-to-gold ring, name under
//                                    it), smaller faded neighbours cut at
//                                    both edges, a seen (grey) neighbour,
//                                    the bottom fade, reply and ⋯
//   story.carousel.hidden.<ar|en>    the same after KStoryCarousel.autoHide:
//                                    the carousel and its fade are gone
//   story.carousel.first.<ar|en>     opened on the first person: neighbours
//                                    on the reading-end side only
//
// Dark only: the viewer is always black. 393 × 852 with the status bar 59
// and the home indicator 34; the clock is pinned (d375Now); animations are
// disabled (reduced motion: instant show and hide). Regenerate on Linux
// with the pinned Flutter:
//   flutter test --update-goldens test/goldens/story_carousel_d375_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/stories/presentation/story_people_carousel.dart';

import '../features/stories/story_carousel_harness.dart';
import '../fixtures/stories/story_carousel_d375_fixtures.dart';

void main() {
  for (final language in [AppLanguage.ar, AppLanguage.en]) {
    final lang = language.name;

    testWidgets('carousel visible ($lang)', (tester) async {
      await withD375Photos(
        () => withClock(Clock.fixed(d375Now), () async {
          await pumpCarousel(
            tester,
            language: language,
            reduceMotion: true,
            device: true,
          );
          await expectLater(
            find.byKey(carouselBoundaryKey),
            matchesGoldenFile('png/story.carousel.visible.$lang.phone.png'),
          );
        }),
      );
    });

    testWidgets('carousel hidden ($lang)', (tester) async {
      await withD375Photos(
        () => withClock(Clock.fixed(d375Now), () async {
          await pumpCarousel(
            tester,
            language: language,
            reduceMotion: true,
            device: true,
          );
          await tester.pump(KStoryCarousel.autoHide);
          await tester.pump();
          await expectLater(
            find.byKey(carouselBoundaryKey),
            matchesGoldenFile('png/story.carousel.hidden.$lang.phone.png'),
          );
        }),
      );
    });

    testWidgets('carousel on the first person ($lang)', (tester) async {
      await withD375Photos(
        () => withClock(Clock.fixed(d375Now), () async {
          await pumpCarousel(
            tester,
            open: 'nour',
            language: language,
            reduceMotion: true,
            device: true,
          );
          await expectLater(
            find.byKey(carouselBoundaryKey),
            matchesGoldenFile('png/story.carousel.first.$lang.phone.png'),
          );
        }),
      );
    });
  }
}
