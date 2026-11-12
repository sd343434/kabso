// D375 (owner «واجعل الستوري تظهر بالخارج بنفس طريقة هذه ١٠٠٪»): the stories
// tray as portrait cards — «قصتك» first with the red «+», then a card per
// account (its first unseen story's thumbnail, the author's small picture at
// the top-start corner; dimmed with a grey border once seen; «LIVE» on a live
// account), 80 × 101 dp, 12 dp corners, 8 dp apart, 18 dp from the sides.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/home/presentation/widgets/feed_stories_tray.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/features/stories/presentation/story_people_carousel.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/stories/story_carousel_d375_fixtures.dart';
import '../../helpers/fake_stories_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final AppLocalizations _en = l10nFor(AppLanguage.en);

Future<void> _pump(
  WidgetTester tester, {
  required List<FeedStoryData> stories,
  AppLanguage language = AppLanguage.en,
  FakeStoriesRepository? repo,
  ValueChanged<FeedStoryData>? onOpen,
  VoidCallback? onAdd,
  ValueChanged<String>? onOpenLive,
  StoryRingStyle? Function(FeedStoryData)? ringStyleOf,
}) async {
  setViewport(tester, GoldenViewport.phone);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        storiesRepositoryProvider.overrideWithValue(
          repo ?? FakeStoriesRepository(),
        ),
      ],
      child: MaterialApp(
        locale: language.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: KabsoApp.supportedLocales,
        theme: buildAppTheme(
          brightness: Brightness.light,
          locale: language.locale,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: FeedStoriesTray(
              stories: stories,
              onOpen: onOpen,
              onAdd: onAdd,
              onOpenLive: onOpenLive,
              ringStyleOf: ringStyleOf,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Finder _card(String username) => find.byKey(FeedStoriesTray.itemKey(username));

void main() {
  testWidgets('cards: «Your story» first, then 80 × 101 cards 8 dp apart, '
      '18 dp from the start, cut at the screen edge', (tester) async {
    final opened = <String>[];
    var added = 0;
    await _pump(
      tester,
      stories: d375TrayCards(ar: false),
      onOpen: (s) => opened.add(s.username!),
      onAdd: () => added++,
      onOpenLive: opened.add,
    );
    final own = tester.getRect(find.byKey(FeedStoriesTray.addKey));
    expect(own.size, const Size(80, 101));
    expect(own.left, 18);
    expect(find.text(_en.storyYourStory), findsOneWidget);
    expect(find.byKey(FeedStoriesTray.addBadgeKey), findsOneWidget);
    final nour = tester.getRect(_card('nour'));
    expect(nour.size, const Size(80, 101));
    expect(nour.left - own.right, 8);
    final omar = tester.getRect(_card('omar'));
    expect(omar.left - nour.right, 8);
    // The fifth card runs past the 393 dp screen.
    expect(tester.getRect(_card('huda')).right, greaterThan(393));
    // The author's small picture: 29 dp at the card's top-start corner.
    final small = tester.getRect(
      find
          .descendant(
            of: find.byKey(FeedStoriesTray.badgeKey('nour')),
            matching: find.byType(KAvatar),
          )
          .first,
    );
    expect(small.left - nour.left, closeTo(4 + 2, 0.5));
    expect(small.top - nour.top, closeTo(5 + 2, 0.5));

    await tester.tap(find.byKey(FeedStoriesTray.addKey));
    expect(added, 1);
    await tester.tap(find.byKey(FeedStoriesTray.addBadgeKey));
    expect(added, 2);
    await tester.tap(_card('nour'));
    expect(opened, ['nour']);
    expect(find.bySemanticsLabel(_en.storyOpen('Nour')), findsOneWidget);
    expect(find.bySemanticsLabel(_en.storyAdd), findsOneWidget);
  });

  testWidgets('Arabic: «قصتك» starts on the right', (tester) async {
    await _pump(
      tester,
      stories: d375TrayCards(ar: true),
      language: AppLanguage.ar,
      onOpen: (_) {},
      onAdd: () {},
    );
    final own = tester.getRect(find.byKey(FeedStoriesTray.addKey));
    expect(own.right, 393 - 18);
    expect(tester.getRect(_card('nour')).right, own.left - 8);
  });

  testWidgets('seen: the card is dimmed and the small picture has a grey '
      'border; unseen: white; live: «LIVE» and the room opens', (tester) async {
    final rooms = <String>[];
    await _pump(
      tester,
      stories: d375TrayCards(ar: false),
      onOpen: (_) {},
      onAdd: () {},
      onOpenLive: rooms.add,
    );
    Color border(String username) =>
        (tester
                    .widget<Container>(
                      find.byKey(FeedStoriesTray.badgeKey(username)),
                    )
                    .decoration!
                as BoxDecoration)
            .color!;
    Finder dim(String username) => find.descendant(
      of: find.byKey(FeedStoriesTray.cardKey(username)),
      matching: find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == KStoriesTray.seenDim,
      ),
    );
    expect(border('nour'), const Color(0xFFFFFFFF));
    expect(dim('nour'), findsNothing);
    expect(border('omar'), KPalette.light.borderStrong);
    expect(dim('omar'), findsOneWidget);
    // Huda (fourth) is live.
    expect(
      find.descendant(
        of: find.byKey(FeedStoriesTray.cardKey('huda')),
        matching: find.byType(KBadge),
      ),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(FeedStoriesTray.trayKey),
      const Offset(-200, 0),
    );
    await tester.pump();
    await tester.tap(_card('huda'));
    expect(rooms, ['room-huda']);
  });

  testWidgets("the card shows the account's first unseen story's thumbnail "
      '(the same request the viewer makes)', (tester) async {
    final repo = FakeStoriesRepository()
      ..stories['sara'] = [testStory('s1', seen: true), testStory('s2')];
    await _pump(
      tester,
      repo: repo,
      stories: const [FeedStoryData(authorName: 'Sara', username: 'sara')],
      onOpen: (_) {},
    );
    await tester.pump();
    expect(repo.calls, contains('userStories:sara'));
    final pictures = tester
        .widgetList<Image>(
          find.descendant(
            of: find.byKey(FeedStoriesTray.cardKey('sara')),
            matching: find.byType(Image),
          ),
        )
        .map((i) => i.image)
        .whereType<NetworkImage>()
        .map((n) => n.url);
    expect(
      pictures,
      contains('https://media.example.test/media/s2-m/320.webp'),
    );
  });

  testWidgets('D374 hook: a ring style for the small picture (VIP '
      '«STORY_RING», not built)', (tester) async {
    await _pump(
      tester,
      stories: d375TrayCards(ar: false),
      onOpen: (_) {},
      ringStyleOf: (s) => s.username == 'nour' ? StoryRingStyle.unseen : null,
    );
    expect(
      find.descendant(
        of: find.byKey(FeedStoriesTray.cardKey('nour')),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is StoryRingPainter,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('text scale 1.3 at 360 dp: no overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(
      tester,
      stories: d375TrayCards(ar: true),
      language: AppLanguage.ar,
      onOpen: (_) {},
      onAdd: () {},
    );
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
