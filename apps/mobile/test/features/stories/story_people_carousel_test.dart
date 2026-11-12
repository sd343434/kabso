// D375 (owner 2026-11-11): the story viewer's people carousel — the tray's
// people with stories at the bottom, the current author centred and
// larger; a tap or a swipe jumps to someone; it fades out after
// KStoryCarousel.autoHide and comes back on touch, long press or typing.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/stories/presentation/story_people_carousel.dart';
import 'package:kabso_live/features/stories/presentation/story_viewer_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';
import 'story_carousel_harness.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);
final AppLocalizations _ar = l10nFor(AppLanguage.ar);

Finder _person(String username) =>
    find.byKey(StoryPeopleCarousel.personKey(username));

StoryRingPainter _ring(WidgetTester tester, String username) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: _person(username),
                matching: find.byWidgetPredicate(
                  (w) => w is CustomPaint && w.painter is StoryRingPainter,
                ),
              ),
            )
            .painter!
        as StoryRingPainter;

double _ringSize(WidgetTester tester, String username) => tester
    .getSize(
      find.descendant(
        of: _person(username),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is StoryRingPainter,
        ),
      ),
    )
    .width;

double _opacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.byKey(StoryViewerScreen.carouselVisibilityKey),
    )
    .opacity;

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A swipe: the snap, then the person's stories load.
Future<void> _glide(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Past the fade-out delay and the fade itself.
Future<void> _waitHide(WidgetTester tester) async {
  await tester.pump(KStoryCarousel.autoHide);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('the carousel shows everyone with stories in tray order; the '
      'current author is centred, larger, with a label', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCarousel(tester);
    expect(find.byKey(StoryPeopleCarousel.carouselKey), findsOneWidget);
    expect(_opacity(tester), 1);
    final centre = tester.getCenter(_person('sara'));
    expect(centre.dx, moreOrLessEquals(393 / 2, epsilon: 0.5));
    // Neighbours: smaller, in reading order (Omar before, Huda after).
    expect(_ringSize(tester, 'sara'), KStoryCarousel.centre);
    expect(_ringSize(tester, 'huda'), KStoryCarousel.side);
    expect(_ringSize(tester, 'omar'), KStoryCarousel.side);
    expect(tester.getCenter(_person('omar')).dx, lessThan(centre.dx));
    expect(tester.getCenter(_person('huda')).dx, greaterThan(centre.dx));
    // The second neighbour on each side is cut by the screen's edge.
    final nour = tester.getRect(
      find
          .descendant(of: _person('nour'), matching: find.byType(CustomPaint))
          .first,
    );
    expect(nour.left, lessThan(0));
    expect(find.bySemanticsLabel(_en.storyPeopleOf('Sara')), findsOneWidget);
    expect(
      tester.getSemantics(_person('sara')),
      matchesSemantics(
        label: _en.storyPeopleOf('Sara'),
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('a tap on someone jumps to their stories and centres them', (
    tester,
  ) async {
    await pumpCarousel(tester);
    expect(find.byKey(StoryViewerScreen.storyKey('d375-sara-1')), findsOne);
    await tester.tap(_person('huda'));
    await _settle(tester);
    expect(find.byKey(StoryViewerScreen.storyKey('d375-huda-1')), findsOne);
    expect(
      tester.getCenter(_person('huda')).dx,
      moreOrLessEquals(393 / 2, epsilon: 0.5),
    );
    expect(_ringSize(tester, 'huda'), KStoryCarousel.centre);
  });

  testWidgets('a swipe on the carousel jumps to the person it settles on', (
    tester,
  ) async {
    await pumpCarousel(tester);
    // English: drag towards the start to bring the next person in.
    await tester.drag(
      find.byKey(StoryPeopleCarousel.carouselKey),
      const Offset(-95, 0),
    );
    await _glide(tester);
    expect(find.byKey(StoryViewerScreen.storyKey('d375-huda-1')), findsOne);
    await tester.drag(
      find.byKey(StoryPeopleCarousel.carouselKey),
      const Offset(190, 0),
    );
    await _glide(tester);
    // Omar's stories were all seen: he opens at his first.
    expect(find.byKey(StoryViewerScreen.storyKey('d375-omar-1')), findsOne);
  });

  testWidgets('Arabic: the carousel follows the reading direction and says '
      '«قصص …»', (tester) async {
    await pumpCarousel(tester, language: AppLanguage.ar);
    final centre = tester.getCenter(_person('sara')).dx;
    expect(centre, moreOrLessEquals(393 / 2, epsilon: 0.5));
    // The next in the tray (Huda) is on the left, the one before on the
    // right, as in the tray.
    expect(tester.getCenter(_person('huda')).dx, lessThan(centre));
    expect(tester.getCenter(_person('omar')).dx, greaterThan(centre));
    expect(find.bySemanticsLabel(_ar.storyPeopleOf('سارة')), findsOneWidget);
    // A swipe towards the right (Arabic's reading end) brings Huda in.
    await tester.drag(
      find.byKey(StoryPeopleCarousel.carouselKey),
      const Offset(95, 0),
    );
    await _glide(tester);
    expect(find.byKey(StoryViewerScreen.storyKey('d375-huda-1')), findsOne);
  });

  testWidgets('the media taps still turn stories; going back from the '
      'first story reaches the previous person in the tray', (tester) async {
    await pumpCarousel(tester);
    await tester.tapAt(const Offset(350, 400));
    await _settle(tester);
    expect(find.byKey(StoryViewerScreen.storyKey('d375-sara-2')), findsOne);
    await tester.tapAt(const Offset(40, 400));
    await _settle(tester);
    expect(find.byKey(StoryViewerScreen.storyKey('d375-sara-1')), findsOne);
    await tester.tapAt(const Offset(40, 400));
    await _settle(tester);
    expect(find.byKey(StoryViewerScreen.storyKey('d375-omar-1')), findsOne);
    expect(
      tester.getCenter(_person('omar')).dx,
      moreOrLessEquals(393 / 2, epsilon: 0.5),
    );
  });

  testWidgets('it fades out after the delay; a touch on the lower area brings '
      'it back without turning the story', (tester) async {
    await pumpCarousel(tester);
    await tester.pump(
      KStoryCarousel.autoHide - const Duration(milliseconds: 300),
    );
    expect(_opacity(tester), 1);
    await _waitHide(tester);
    expect(_opacity(tester), 0);
    // A hidden carousel cannot be tapped through.
    final at = tester.getCenter(_person('huda'));
    await tester.tapAt(at);
    await tester.pump();
    expect(_opacity(tester), 1);
    await _settle(tester);
    expect(find.byKey(StoryViewerScreen.storyKey('d375-sara-1')), findsOne);
    // And it fades out again.
    await _waitHide(tester);
    expect(_opacity(tester), 0);
  });

  testWidgets('it never hides while a finger is down on it', (tester) async {
    await pumpCarousel(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(StoryPeopleCarousel.carouselKey)),
    );
    await tester.pump(KStoryCarousel.autoHide * 2);
    expect(_opacity(tester), 1);
    await gesture.up();
    await _waitHide(tester);
    expect(_opacity(tester), 0);
  });

  testWidgets('a long press (pause) brings it back and keeps it up', (
    tester,
  ) async {
    await pumpCarousel(tester);
    await _waitHide(tester);
    expect(_opacity(tester), 0);
    final gesture = await tester.startGesture(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_opacity(tester), 1);
    await tester.pump(KStoryCarousel.autoHide * 2);
    expect(_opacity(tester), 1);
    await gesture.up();
    await _waitHide(tester);
    expect(_opacity(tester), 0);
  });

  testWidgets('it does not hide while a reply is being typed', (tester) async {
    await pumpCarousel(tester);
    // The reference has no field box: the caption line opens it.
    expect(find.byKey(StoryViewerScreen.replyFieldKey), findsNothing);
    await tester.tap(find.byKey(StoryViewerScreen.replyOpenKey));
    await tester.pump();
    expect(find.byKey(StoryViewerScreen.replyFieldKey), findsOneWidget);
    await tester.enterText(find.byKey(StoryViewerScreen.replyFieldKey), 'hi');
    await tester.pump(KStoryCarousel.autoHide * 2);
    expect(_opacity(tester), 1);
    // Done typing: it fades out after the delay.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await _waitHide(tester);
    expect(_opacity(tester), 0);
    // With text it stays; emptied and left, it closes back to the caption
    // line.
    expect(find.byKey(StoryViewerScreen.replyFieldKey), findsOneWidget);
    await tester.enterText(find.byKey(StoryViewerScreen.replyFieldKey), '');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(find.byKey(StoryViewerScreen.replyFieldKey), findsNothing);
    expect(find.byKey(StoryViewerScreen.replyOpenKey), findsOneWidget);
  });

  testWidgets('a change of person shows it again', (tester) async {
    await pumpCarousel(tester);
    await _waitHide(tester);
    expect(_opacity(tester), 0);
    // Forward twice: Sara's second story, then Huda.
    await tester.tapAt(const Offset(350, 400));
    await tester.pump();
    expect(_opacity(tester), 0);
    await tester.tapAt(const Offset(350, 400));
    await _settle(tester);
    expect(find.byKey(StoryViewerScreen.storyKey('d375-huda-1')), findsOne);
    expect(_opacity(tester), 1);
  });

  testWidgets('reduced motion: shows and hides at once, without a slide', (
    tester,
  ) async {
    await pumpCarousel(tester, reduceMotion: true);
    final fade = tester.widget<AnimatedOpacity>(
      find.byKey(StoryViewerScreen.carouselVisibilityKey),
    );
    expect(fade.duration, Duration.zero);
    await tester.pump(KStoryCarousel.autoHide);
    await tester.pump();
    expect(_opacity(tester), 0);
    final slide = tester.widget<AnimatedSlide>(
      find.ancestor(
        of: find.byKey(StoryViewerScreen.carouselVisibilityKey),
        matching: find.byType(AnimatedSlide),
      ),
    );
    expect(slide.offset, Offset.zero);
    // A tap on someone centres them at once.
    await tester.tapAt(tester.getCenter(_person('huda')));
    await tester.pump();
    expect(_opacity(tester), 1);
    await tester.tap(_person('huda'));
    await tester.pump();
    await tester.pump();
    expect(
      tester.getCenter(_person('huda')).dx,
      moreOrLessEquals(393 / 2, epsilon: 0.5),
    );
  });

  testWidgets('rings: unseen people in red to gold, seen ones grey; someone '
      'watched to the end turns grey', (tester) async {
    await pumpCarousel(tester);
    expect(_ring(tester, 'sara').style, StoryRingStyle.unseen);
    expect(_ring(tester, 'omar').style, StoryRingStyle.seen);
    expect(_ring(tester, 'ali').style, StoryRingStyle.seen);
    expect(StoryRingStyle.unseen.colors, const [
      Color(0xFFE50914),
      Color(0xFFFF3B47),
      Color(0xFFF5C451),
    ]);
    // Watch both of Sara's stories, then move on to Huda.
    await tester.tapAt(const Offset(350, 400));
    await _settle(tester);
    await tester.tapAt(const Offset(350, 400));
    await _settle(tester);
    expect(find.byKey(StoryViewerScreen.storyKey('d375-huda-1')), findsOne);
    expect(_ring(tester, 'sara').style, StoryRingStyle.seen);
    expect(_ring(tester, 'huda').style, StoryRingStyle.unseen);
  });

  testWidgets('the bottom ⋯ opens the story menu (mute, report)', (
    tester,
  ) async {
    await pumpCarousel(tester);
    await tester.tap(find.byKey(StoryViewerScreen.moreBottomKey));
    await _settle(tester);
    expect(find.byKey(StoryViewerScreen.reportKey), findsOneWidget);
    expect(find.byKey(StoryViewerScreen.muteKey), findsOneWidget);
  });

  testWidgets('Arabic at text scale 1.3 and 360 dp: no overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpCarousel(tester, language: AppLanguage.ar);
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byKey(StoryPeopleCarousel.carouselKey), findsOneWidget);
  });
}
