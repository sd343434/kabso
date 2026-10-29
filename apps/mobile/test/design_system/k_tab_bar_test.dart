// D130: the owner's animated bottom tab bar in the real shell, and the
// party button in the Live hub's top bar.

import 'dart:ui' show Tristate;

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/create/create_menu_sheet.dart';
import 'package:kabso_live/features/create/create_screen.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:kabso_live/features/messages/unread_messages.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_api_fixtures.dart';
import '../helpers/component_harness.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

const _keys = [
  Key('nav.home'),
  Key('nav.reels'),
  Key('nav.create'),
  Key('nav.messages'),
  Key('nav.profile'),
];

bool _selected(WidgetTester tester, Key key) =>
    tester
        .getSemantics(find.byKey(key))
        .getSemanticsData()
        .flagsCollection
        .isSelected ==
    Tristate.isTrue;

String _label(WidgetTester tester, Key key) =>
    tester.getSemantics(find.byKey(key)).getSemanticsData().label;

Future<void> _pumpShell(
  WidgetTester tester, {
  String language = 'en',
  List<Override> overrides = const [],
}) async {
  await pumpKabsoApp(
    tester,
    language: language,
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(storedUser: testUser()),
      ),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      ...overrides,
    ],
  );
  await tester.pumpAndSettle();
}

StoryTrayItem _trayItem(String id, {required bool unseen}) => StoryTrayItem(
  user: UserSummary(
    id: id,
    username: 'user_$id',
    displayName: 'User $id',
    avatarUrl: null,
  ),
  storyCount: 1,
  hasUnseen: unseen,
  latestAt: DateTime.utc(2026, 10, 27),
);

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  group('shell bar (D130)', () {
    testWidgets('switching tabs moves the selection (semantics) and '
        'keeps the routes', (tester) async {
      await _pumpShell(tester);
      expect(find.byType(KTabBar), findsOneWidget);
      expect(_selected(tester, const Key('nav.home')), isTrue);
      expect(find.byType(LiveScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav.reels')));
      await tester.pumpAndSettle();
      expect(_selected(tester, const Key('nav.reels')), isTrue);
      expect(_selected(tester, const Key('nav.home')), isFalse);
      expect(find.byType(FeedScreen), findsOneWidget);
      expect(_label(tester, const Key('nav.reels')), en.navMoments);

      await tester.tap(find.byKey(const Key('nav.messages')));
      await tester.pumpAndSettle();
      expect(_selected(tester, const Key('nav.messages')), isTrue);
      // D155: the real conversation list (no conversations in the fake).
      expect(find.text(en.conversationsEmptyTitle), findsOneWidget);
    });

    testWidgets('the camera button opens Create (bar hidden there), Close '
        'returns', (tester) async {
      await _pumpShell(tester);
      expect(_label(tester, const Key('nav.create')), en.navCreate);
      await tester.tap(find.byKey(const Key('nav.create')));
      await tester.pumpAndSettle();
      // D162: the camera button opens the ➕ menu; «منشور» opens Create.
      await tester.tap(
        find.byKey(CreateMenuSheet.choiceKey(CreateChoice.post)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CreateScreen), findsOneWidget);
      expect(find.byType(KTabBar), findsNothing);
      await tester.tap(find.byKey(CreateScreen.closeKey));
      await tester.pumpAndSettle();
      expect(find.byType(KTabBar), findsOneWidget);
    });

    testWidgets('no messaging API: no badge; no unseen stories: no dot', (
      tester,
    ) async {
      await _pumpShell(tester);
      expect(find.byKey(KTabBarKeys.badge), findsNothing);
      expect(find.byKey(KTabBarKeys.dot), findsNothing);
      expect(_label(tester, const Key('nav.messages')), en.navMessages);
    });

    testWidgets('the badge shows the unread provider: 7, then 99+', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        overrides: [unreadMessagesProvider.overrideWithValue(7)],
      );
      expect(tester.widget<Text>(find.byKey(KTabBarKeys.badge)).data, '7');
      expect(
        _label(tester, const Key('nav.messages')),
        '${en.navMessages}, ${en.navMessagesUnread(7)}',
      );
    });

    testWidgets('more than 99 unread: "99+" and announced as such', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        overrides: [unreadMessagesProvider.overrideWithValue(128)],
      );
      expect(tester.widget<Text>(find.byKey(KTabBarKeys.badge)).data, '99+');
      expect(
        _label(tester, const Key('nav.messages')),
        '${en.navMessages}, ${en.navMessagesUnreadMany}',
      );
    });

    testWidgets('a followed account with an unseen story puts the dot on '
        "Moments; the caller's own story does not", (tester) async {
      final stories = [
        _trayItem(testUser().id, unseen: true),
        _trayItem('friend', unseen: true),
      ];
      await _pumpShell(
        tester,
        overrides: [storyTrayProvider.overrideWith((ref) => stories)],
      );
      expect(find.byKey(KTabBarKeys.dot), findsOneWidget);
      expect(
        _label(tester, const Key('nav.reels')),
        '${en.navMoments}, ${en.navMomentsNew}',
      );
      // On Moments itself the rings show it: no dot.
      await tester.tap(find.byKey(const Key('nav.reels')));
      await tester.pumpAndSettle();
      expect(find.byKey(KTabBarKeys.dot), findsNothing);
    });

    testWidgets('only my own unseen story: no dot', (tester) async {
      final stories = [
        _trayItem(testUser().id, unseen: true),
        _trayItem('friend', unseen: false),
      ];
      await _pumpShell(
        tester,
        overrides: [storyTrayProvider.overrideWith((ref) => stories)],
      );
      expect(find.byKey(KTabBarKeys.dot), findsNothing);
    });

    for (final language in ['ar', 'en']) {
      testWidgets('$language: order follows the direction, labels from l10n, '
          '48 dp targets', (tester) async {
        tester.view
          ..physicalSize = const Size(393, 852) * 3
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await _pumpShell(tester, language: language);
        final xs = [for (final k in _keys) tester.getCenter(find.byKey(k)).dx];
        final sorted = [...xs]..sort();
        // ar: Live at the right; en: Live at the left.
        expect(xs, language == 'ar' ? sorted.reversed.toList() : sorted);
        final l10n = language == 'ar' ? ar : en;
        for (final label in [
          l10n.navLive,
          l10n.navMoments,
          l10n.navMessages,
          l10n.navProfile,
        ]) {
          expect(
            find.descendant(
              of: find.byType(KTabBar),
              matching: find.text(label),
            ),
            findsOneWidget,
            reason: label,
          );
        }
        for (final k in _keys) {
          final size = tester.getSize(find.byKey(k));
          expect(size.width, greaterThanOrEqualTo(KSizes.minTouchTarget));
          expect(size.height, greaterThanOrEqualTo(KSizes.minTouchTarget));
        }
      });
    }

    testWidgets("Arabic labels are the owner's", (tester) async {
      expect(
        [ar.navLive, ar.navMoments, ar.navMessages, ar.navProfile],
        ['البث', 'اللحظات', 'الرسائل', 'أنا'],
      );
      expect(
        [en.navLive, en.navMoments, en.navMessages, en.navProfile],
        ['Live', 'Moments', 'Messages', 'Me'],
      );
    });
  });

  group('KTabBar component', () {
    Future<void> pumpBar(
      WidgetTester tester, {
      required int index,
      Brightness brightness = Brightness.dark,
      bool disableAnimations = true,
      double textScale = 1,
      AppLanguage language = AppLanguage.en,
      ValueChanged<int>? onSelect,
    }) => pumpComponent(
      tester,
      MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 800),
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: KTabBar(
            items: shellTabItems(l10nFor(language), unreadMessages: 3),
            currentIndex: index,
            onSelect: onSelect ?? (_) {},
          ),
        ),
      ),
      brightness: brightness,
      disableAnimations: disableAnimations,
      language: language,
    );

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: palette surface, labels and badge', (
        tester,
      ) async {
        await pumpBar(tester, index: 0, brightness: brightness);
        final p = brightness == Brightness.dark
            ? KPalette.dark
            : KPalette.light;
        final bar = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(KTabBar),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final decoration = bar.decoration as BoxDecoration;
        expect(decoration.color, p.surfaceRaised);
        // Light: the owner's soft shadow; dark: a hairline instead.
        expect(
          decoration.boxShadow,
          brightness == Brightness.light ? isNotEmpty : isNull,
        );
        Color colour(String text) =>
            tester.widget<Text>(find.text(text)).style!.color!;
        expect(colour('Live'), p.primaryText);
        expect(colour('Moments'), p.textTertiary);
        expect(
          tester.widget<Text>(find.byKey(KTabBarKeys.badge)).style!.color,
          p.onPrimary,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('reduced motion: a new selection is drawn at once, nothing '
        'keeps animating', (tester) async {
      var index = 0;
      await pumpBar(tester, index: index, onSelect: (i) => index = i);
      await tester.tap(find.byKey(const Key('nav.messages')));
      expect(index, 3);
      await pumpBar(tester, index: 3);
      // One frame later the selection is already at its end state.
      expect(
        tester.widget<Text>(find.text('Messages')).style!.color,
        KPalette.dark.primaryText,
      );
    });

    testWidgets('with motion: the selection animates, then settles', (
      tester,
    ) async {
      await pumpBar(tester, index: 0, disableAnimations: false);
      await pumpBar(tester, index: 1, disableAnimations: false);
      // Mid-animation the label is still on its way to red.
      expect(
        tester.widget<Text>(find.text('Moments')).style!.color,
        isNot(KPalette.dark.primaryText),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Moments')).style!.color,
        KPalette.dark.primaryText,
      );
    });

    for (final scale in [1.3, 2.0]) {
      for (final language in AppLanguage.values) {
        testWidgets('text scale $scale, ${language.name}, 360 dp: no '
            'overflow', (tester) async {
          tester.view
            ..physicalSize = const Size(360, 800)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await pumpBar(tester, index: 4, textScale: scale, language: language);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Live hub party button (D130, D131: opens the voice rooms)', () {
    for (final language in ['en', 'ar']) {
      testWidgets('$language: next to the bell; a tap pops, then opens the '
          'voice rooms (kind=audio); back returns to the hub', (tester) async {
        final live = FakeLiveRepository(
          rooms: (r) => apiPage([
            for (final room in apiRooms(4))
              if (r.kind == LiveRoomsKind.audio)
                room.copyWith(mode: LiveRoomMode.audio)
              else
                room,
          ]),
        );
        await pumpKabsoApp(
          tester,
          language: language,
          liveRepository: live,
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(storedUser: testUser()),
            ),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          ],
        );
        await tester.pumpAndSettle();
        final l10n = language == 'ar' ? ar : en;
        final party = find.byKey(LiveHubPartyButton.buttonKey);
        expect(party, findsOneWidget);
        expect(find.byType(KPartyIcon), findsOneWidget);
        // Same 48 dp target as the bell, right beside it.
        final bell = tester.getRect(
          find.byKey(const Key('notifications.bell')),
        );
        final rect = tester.getRect(party);
        expect(rect.size, bell.size);
        expect((rect.center.dx - bell.center.dx).abs(), 48);
        expect(find.bySemanticsLabel(l10n.liveVoiceRoomsTitle), findsWidgets);
        // The hub lists video lives only.
        expect(live.requests.map((r) => r.kind).toSet(), {LiveRoomsKind.video});

        live.requests.clear();
        await tester.tap(party);
        await tester.pump();
        // The pop plays first; the voice rooms open after it.
        expect(find.byType(VoiceRoomsScreen), findsNothing);
        await tester.pumpAndSettle();
        expect(find.byType(VoiceRoomsScreen), findsOneWidget);
        expect(live.requests, isNotEmpty);
        expect(live.requests.map((r) => r.kind).toSet(), {LiveRoomsKind.audio});
        await tester.tap(find.byKey(VoiceRoomsScreen.backKey));
        await tester.pumpAndSettle();
        expect(find.byType(VoiceRoomsScreen), findsNothing);
        expect(find.byType(LiveScreen), findsOneWidget);
      });
    }
  });
}
