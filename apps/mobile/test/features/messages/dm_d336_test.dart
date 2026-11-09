// D336 (owner's reference, layout only): the Messages tab opens on «القصص»
// — a «+» (a new story) and the paper plane (a new message) — over story
// cards from the real stories tray («أضف قصة» first), then «الرسائل» with
// search, the two boxes and the rows: the compact time with the red unread
// count under it. English LTR and Arabic RTL; 360×800 at text scale 1.3.
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/messages/widgets/dm_new_message_sheet.dart';
import 'package:kabso_live/features/messages/widgets/dm_story_cards.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_dm_repository.dart';
import '../../helpers/fake_stories_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

final DateTime _now = DateTime.utc(2026, 10, 28, 12);

/// Every location the screen went to (other than the start).
final List<String> _visited = [];

FakeDmRepository _dm() {
  final dm = FakeDmRepository()..now = _now;
  dm
    ..addConversation(
      dmPerson('sara_2026', name: 'Sara'),
      unread: 2,
      messages: [
        dm.message(
          'c-sara_2026',
          mine: false,
          text: 'are you live?',
          at: _now.subtract(const Duration(minutes: 5)),
        ),
      ],
    )
    ..addConversation(
      dmPerson('omar.k', name: 'Omar'),
      messages: [
        dm.message(
          'c-omar.k',
          mine: false,
          text: 'see you',
          at: _now.subtract(const Duration(hours: 3)),
        ),
      ],
    );
  return dm;
}

StoryTrayItem _tray(String username, {bool unseen = true, int hours = 2}) =>
    StoryTrayItem(
      user: UserSummary(
        id: username == 'layla.k' ? testUser().id : 'u-$username',
        username: username,
        displayName: username == 'layla.k' ? 'Layla' : 'Nour',
        avatarUrl: null,
      ),
      storyCount: 1,
      hasUnseen: unseen,
      latestAt: _now.subtract(Duration(hours: hours)),
    );

Future<void> _pump(
  WidgetTester tester, {
  FakeDmRepository? dm,
  FakeStoriesRepository? stories,
  AppLanguage language = AppLanguage.en,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  _visited.clear();
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final prefs = await testPrefs(language: language.name);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const MessagesTab())],
    errorBuilder: (_, state) {
      _visited.add(state.uri.toString());
      return Scaffold(body: Text('at ${state.uri}'));
    },
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dmRepositoryProvider.overrideWithValue(dm ?? _dm()),
        storiesRepositoryProvider.overrideWithValue(
          stories ?? FakeStoriesRepository(),
        ),
        currentUserProvider.overrideWithValue(testUser()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(
          brightness: Brightness.light,
          locale: language.locale,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  group('stories', () {
    testWidgets('«Stories» with «+» (a new story) and the paper plane (a new '
        "message), then «Add story» first and the followed accounts' cards "
        'with their compact time; a card opens their stories', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        final stories = FakeStoriesRepository()
          ..trayItems = [_tray('nour', hours: 4)];
        await _pump(tester, stories: stories);
        expect(find.text(en.dmStoriesTitle), findsOneWidget);
        expect(find.text(en.dmStoriesAdd), findsOneWidget);
        expect(find.byKey(DmStoryCards.cardKey('nour')), findsOneWidget);
        expect(find.text('Nour'), findsOneWidget);
        expect(find.text(en.relativeShortHours(4)), findsOneWidget);
        // «Add story» is first (at the reading start).
        expect(
          tester.getTopLeft(find.byKey(DmStoryCards.addKey)).dx,
          lessThan(
            tester.getTopLeft(find.byKey(DmStoryCards.cardKey('nour'))).dx,
          ),
        );
        // The cards sit between «Stories» and «Messages».
        final cards = tester.getRect(find.byKey(DmStoryCards.rowKey));
        expect(
          cards.top,
          greaterThan(
            tester.getBottomLeft(find.byKey(DmInboxScreen.storiesTitleKey)).dy,
          ),
        );
        expect(
          cards.bottom,
          lessThan(tester.getTopLeft(find.text(en.conversationsTitle)).dy),
        );

        await tester.tap(find.byKey(DmStoryCards.cardKey('nour')));
        await tester.pumpAndSettle();
        expect(_visited, [AppRoutes.stories('nour')]);
      });
    });

    testWidgets('«Add story» opens a new story; the header «+» opens «New '
        'group» (D339, owner)', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(DmStoryCards.addKey));
      await tester.pumpAndSettle();
      expect(_visited, [AppRoutes.newStory]);

      // D339 (owner: «ال+ في الاعلى … يجب ان يكون هذا الزر + زر عمل مجموعة»).
      await _pump(tester);
      final plus = find.byKey(DmInboxScreen.newGroupKey);
      expect(plus, findsOneWidget);
      expect(tester.widget<IconButton>(plus).tooltip, en.dmNewGroup);
      expect(
        find.descendant(of: plus, matching: find.byIcon(Icons.add_rounded)),
        findsOneWidget,
      );
      await tester.tap(plus);
      await tester.pumpAndSettle();
      expect(_visited, [AppRoutes.newGroup]);
    });

    testWidgets("with a story of their own the caller's card is «Your story» "
        'and opens it; its «+» still adds one', (tester) async {
      final stories = FakeStoriesRepository()
        ..trayItems = [_tray('layla.k'), _tray('nour')];
      await _pump(tester, stories: stories);
      expect(find.text(en.storyYourStory), findsOneWidget);
      expect(find.text(en.dmStoriesAdd), findsNothing);
      // Not twice: the caller's entry is not also a card of its own.
      expect(find.byKey(DmStoryCards.cardKey('layla.k')), findsNothing);
      await tester.tap(find.byKey(DmStoryCards.addKey));
      await tester.pumpAndSettle();
      expect(_visited, [AppRoutes.stories('layla.k')]);

      await _pump(tester, stories: stories);
      await tester.tap(find.byKey(DmStoryCards.addBadgeKey));
      await tester.pumpAndSettle();
      expect(_visited, [AppRoutes.newStory]);
    });

    testWidgets("a failed tray shows only the caller's card (nothing "
        'guessed); the conversations are still there', (tester) async {
      final stories = FakeStoriesRepository()
        ..trayItems = [_tray('nour')]
        ..failWith = const NetworkFailure.offline();
      await _pump(tester, stories: stories);
      expect(find.byKey(DmStoryCards.addKey), findsOneWidget);
      expect(find.byKey(DmStoryCards.cardKey('nour')), findsNothing);
      expect(find.byKey(DmInboxScreen.rowKey('c-sara_2026')), findsOneWidget);
    });

    testWidgets('the paper plane opens «New message»', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(DmInboxScreen.newMessageKey));
      await tester.pumpAndSettle();
      expect(find.byType(DmNewMessageSheet), findsOneWidget);
    });

    testWidgets('while searching the stories step aside and come back on '
        'close', (tester) async {
      await _pump(tester);
      await tester.tap(find.byKey(DmInboxScreen.searchKey));
      await tester.pumpAndSettle();
      expect(find.byKey(DmStoryCards.rowKey), findsNothing);
      expect(find.byKey(DmInboxScreen.searchFieldKey), findsOneWidget);
      await tester.tap(find.byKey(DmInboxScreen.searchCloseKey));
      await tester.pumpAndSettle();
      expect(find.byKey(DmStoryCards.rowKey), findsOneWidget);
    });
  });

  group('boxes button', () {
    for (final language in AppLanguage.values) {
      testWidgets('no row of boxes in the page: the button beside search opens '
          'and closes them, shows the pending requests, and a box closes the '
          'panel (${language.name})', (tester) async {
        final l10n = language == AppLanguage.ar ? ar : en;
        final dm = _dm()
          ..addConversation(
            dmPerson('omar.k', name: 'Omar'),
            status: DmConversationStatus.requestReceived,
            unread: 1,
            messages: [FakeDmRepository().message('c-omar.k', mine: false)],
          )
          ..unreadCounts = const DmUnread(requests: 3);
        await _pump(tester, dm: dm, language: language);
        // Collapsed: no boxes in the page; the requests on the button.
        expect(find.byKey(DmInboxScreen.boxesPanelKey), findsNothing);
        expect(find.byKey(DmInboxScreen.requestsTabKey), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(DmInboxScreen.boxesBadgeKey),
            matching: find.text('3'),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<IconButton>(find.byKey(DmInboxScreen.boxesToggleKey))
              .tooltip,
          l10n.dmBoxes,
        );
        // The button sits in the «Messages» row, before search.
        final toggle = tester.getCenter(
          find.byKey(DmInboxScreen.boxesToggleKey),
        );
        final search = tester.getCenter(find.byKey(DmInboxScreen.searchKey));
        expect(toggle.dy, moreOrLessEquals(search.dy));
        if (language == AppLanguage.ar) {
          expect(toggle.dx, greaterThan(search.dx));
        } else {
          expect(toggle.dx, lessThan(search.dx));
        }
        // The first row sits right under the «Messages» row.
        final rowTop = tester
            .getTopLeft(find.byKey(DmInboxScreen.rowKey('c-sara_2026')))
            .dy;
        expect(
          rowTop - tester.getBottomLeft(find.byKey(DmInboxScreen.searchKey)).dy,
          lessThan(KSpacing.lg),
        );

        await tester.tap(find.byKey(DmInboxScreen.boxesToggleKey));
        await tester.pumpAndSettle();
        expect(find.byKey(DmInboxScreen.boxesPanelKey), findsOneWidget);
        expect(find.text(l10n.dmTabChats), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            l10n.dmTabRequestsCount(KFormat.compact(3, l10n)),
          ),
          findsOneWidget,
        );
        // The panel pushes the list down.
        expect(
          tester.getTopLeft(find.byKey(DmInboxScreen.rowKey('c-sara_2026'))).dy,
          greaterThan(rowTop),
        );
        // Tap again: closed.
        await tester.tap(find.byKey(DmInboxScreen.boxesToggleKey));
        await tester.pumpAndSettle();
        expect(find.byKey(DmInboxScreen.boxesPanelKey), findsNothing);

        // A box opens and closes the panel; the title names it.
        await tester.tap(find.byKey(DmInboxScreen.boxesToggleKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(DmInboxScreen.requestsTabKey));
        await tester.pumpAndSettle();
        expect(find.byKey(DmInboxScreen.boxesPanelKey), findsNothing);
        expect(find.text(l10n.dmTabRequests), findsOneWidget);
        expect(find.byKey(DmInboxScreen.rowKey('c-omar.k')), findsOneWidget);
        expect(dm.calls, contains('conversations:requests'));
      });
    }

    testWidgets('no pending requests: no count on the button', (tester) async {
      await _pump(tester);
      expect(find.byKey(DmInboxScreen.boxesToggleKey), findsOneWidget);
      expect(find.byKey(DmInboxScreen.boxesBadgeKey), findsNothing);
    });
  });

  group('rows', () {
    for (final language in AppLanguage.values) {
      testWidgets('compact time with the red count under it; the picture at '
          'the reading start (${language.name})', (tester) async {
        await withClock(Clock.fixed(_now), () async {
          final l10n = language == AppLanguage.ar ? ar : en;
          await _pump(tester, language: language);
          final row = find.byKey(DmInboxScreen.rowKey('c-sara_2026'));
          final time = find.descendant(
            of: row,
            matching: find.text(l10n.relativeShortMinutes(5)),
          );
          final count = find.descendant(of: row, matching: find.text('2'));
          expect(time, findsOneWidget);
          expect(count, findsOneWidget);
          expect(
            tester.getTopLeft(count).dy,
            greaterThan(tester.getBottomLeft(time).dy),
          );
          // The badge is Kabso red.
          final badge = tester.widget<Container>(
            find.ancestor(of: count, matching: find.byType(Container)).first,
          );
          expect(
            (badge.decoration! as BoxDecoration).color,
            KPalette.light.primary,
          );
          final avatar = tester.getCenter(
            find.descendant(of: row, matching: find.byType(KAvatar)),
          );
          final name = tester.getCenter(
            find.descendant(of: row, matching: find.text('Sara')),
          );
          if (language == AppLanguage.ar) {
            expect(avatar.dx, greaterThan(name.dx));
          } else {
            expect(avatar.dx, lessThan(name.dx));
          }
          // In words for screen readers.
          expect(
            tester.getSemantics(row).value,
            contains(l10n.relativeMinutesAgo(5)),
          );
        });
      });

      testWidgets('360×800 at text ×1.3 with long names, an old date and '
          'stories: no overflow (${language.name})', (tester) async {
        final dm = _dm()
          ..addConversation(
            dmPerson('long', name: 'A very long display name ' * 3),
            unread: 120,
            messages: [
              FakeDmRepository().message(
                'c-long',
                mine: false,
                text: 'a long message ' * 10,
                at: DateTime.utc(2025, 3, 2),
              ),
            ],
          );
        final stories = FakeStoriesRepository()
          ..trayItems = [
            _tray('nour'),
            for (var i = 0; i < 6; i++) _tray('n$i', unseen: i.isEven),
          ];
        await _pump(
          tester,
          dm: dm,
          stories: stories,
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('99+'), findsOneWidget);
        await tester.tap(find.byKey(DmInboxScreen.boxesToggleKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(DmInboxScreen.boxesPanelKey), findsOneWidget);
      });
    }
  });

  test('KFormat.relativeShort: minutes, hours, days, then a short date', () {
    final now = DateTime.utc(2026, 10, 28, 12);
    String? f(Duration d, AppLocalizations l, String tag) =>
        KFormat.relativeShort(now.subtract(d), now, l, tag);
    expect(f(const Duration(seconds: 30), en, 'en'), isNull);
    expect(f(const Duration(minutes: 5), en, 'en'), '5m');
    expect(f(const Duration(hours: 3), en, 'en'), '3h');
    expect(f(const Duration(days: 2), en, 'en'), '2d');
    expect(f(const Duration(minutes: 5), ar, 'ar'), '5د');
    expect(f(const Duration(hours: 3), ar, 'ar'), '3س');
    expect(f(const Duration(days: 2), ar, 'ar'), '2ي');
    expect(f(const Duration(days: 20), en, 'en'), '8 Oct');
    expect(
      KFormat.relativeShort(DateTime.utc(2025, 3, 1, 12), now, en, 'en'),
      '1/3/25',
    );
  });
}
