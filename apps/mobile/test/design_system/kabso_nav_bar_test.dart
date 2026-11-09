// D322: the owner's bottom bar (`KabsoNavBar`, his design) as a component
// and as the app's real shell bar.

import 'dart:ui' show Tristate;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/app/shell/app_shell.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/home/feed_screen.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:kabso_live/features/messages/unread_messages.dart';
import 'package:kabso_live/features/profile/me_hub_screen.dart';
import 'package:kabso_live/features/stories/application/stories_controller.dart';
import 'package:kabso_live/features/stories/domain/story_models.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/component_harness.dart';
import '../helpers/fakes.dart';
import '../helpers/pump_app.dart';

const List<Key> _keys = ShellNavKeys.all;

bool _selected(WidgetTester tester, Key key) =>
    tester
        .getSemantics(find.byKey(key))
        .getSemanticsData()
        .flagsCollection
        .isSelected ==
    Tristate.isTrue;

String _label(WidgetTester tester, Key key) =>
    tester.getSemantics(find.byKey(key)).getSemanticsData().label;

Color _labelColour(WidgetTester tester, String text) =>
    DefaultTextStyle.of(tester.element(find.text(text))).style.color!;

String _location(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first))
        .routerDelegate
        .currentConfiguration
        .uri
        .toString();

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

  group('KabsoNavBar component (D322)', () {
    late List<int> taps;
    late List<int> reselects;
    late List<String> haptics;

    setUp(() {
      taps = [];
      reselects = [];
      haptics = [];
    });

    Future<void> pumpBar(
      WidgetTester tester, {
      required int index,
      Brightness brightness = Brightness.light,
      bool disableAnimations = false,
      double textScale = 1,
      AppLanguage language = AppLanguage.en,
      int unread = 0,
      bool newStories = false,
      double bottomPadding = 0,
    }) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpComponent(
        tester,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
              padding: EdgeInsets.only(bottom: bottomPadding),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: shellNavBar(
                l10nFor(language),
                currentIndex: index,
                onTap: taps.add,
                onReselect: reselects.add,
                unreadMessages: unread,
                newStories: newStories,
              ),
            ),
          ),
        ),
        brightness: brightness,
        disableAnimations: disableAnimations,
        language: language,
      );
    }

    KabsoNavBarState state(WidgetTester tester) =>
        tester.state<KabsoNavBarState>(find.byType(KabsoNavBar));

    testWidgets('tap: another tab calls onTap (not onReselect) with a '
        'selection haptic', (tester) async {
      await pumpBar(tester, index: 0);
      await tester.tap(find.byKey(ShellNavKeys.messages));
      expect(taps, [3]);
      expect(reselects, isEmpty);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('the new selection plays its animation, then rests', (
      tester,
    ) async {
      await pumpBar(tester, index: 0);
      expect(state(tester).isAnimating(1), isFalse);
      await pumpBar(tester, index: 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(state(tester).isAnimating(1), isTrue);
      expect(_selected(tester, ShellNavKeys.party), isTrue);
      await tester.pumpAndSettle();
      expect(state(tester).isAnimating(1), isFalse);
    });

    testWidgets('re-tap replays the animation and calls onReselect', (
      tester,
    ) async {
      await pumpBar(tester, index: 2);
      expect(state(tester).isAnimating(2), isFalse);
      await tester.tap(find.byKey(ShellNavKeys.moments));
      await tester.pump(const Duration(milliseconds: 50));
      expect(state(tester).isAnimating(2), isTrue);
      expect(reselects, [2]);
      expect(taps, isEmpty);
      expect(haptics, ['HapticFeedbackType.selectionClick']);
      await tester.pumpAndSettle();
      // Again: it replays every time.
      await tester.tap(find.byKey(ShellNavKeys.moments));
      await tester.pump(const Duration(milliseconds: 50));
      expect(state(tester).isAnimating(2), isTrue);
      expect(reselects, [2, 2]);
      await tester.pumpAndSettle();
    });

    testWidgets('reduced motion: no animation on a new selection or a '
        're-tap; the tap still works', (tester) async {
      await pumpBar(tester, index: 0, disableAnimations: true);
      await tester.tap(find.byKey(ShellNavKeys.me));
      expect(taps, [4]);
      await pumpBar(tester, index: 4, disableAnimations: true);
      for (var i = 0; i < 5; i++) {
        expect(state(tester).isAnimating(i), isFalse, reason: '$i');
      }
      await tester.tap(find.byKey(ShellNavKeys.me));
      await tester.pump();
      expect(reselects, [4]);
      for (var i = 0; i < 5; i++) {
        expect(state(tester).isAnimating(i), isFalse, reason: '$i');
      }
    });

    testWidgets('badge: the unread count, "99+" above 99, announced', (
      tester,
    ) async {
      await pumpBar(tester, index: 0);
      expect(find.byKey(KabsoNavBar.badgeKey), findsNothing);
      expect(_label(tester, ShellNavKeys.messages), en.navMessages);

      await pumpBar(tester, index: 0, unread: 7);
      expect(tester.widget<Text>(find.byKey(KabsoNavBar.badgeKey)).data, '7');
      expect(
        _label(tester, ShellNavKeys.messages),
        '${en.navMessages}, ${en.navMessagesUnread(7)}',
      );

      await pumpBar(tester, index: 0, unread: 128);
      expect(tester.widget<Text>(find.byKey(KabsoNavBar.badgeKey)).data, '99+');
      expect(
        _label(tester, ShellNavKeys.messages),
        '${en.navMessages}, ${en.navMessagesUnreadMany}',
      );
    });

    testWidgets('new stories: a dot on Moments, not while it is selected', (
      tester,
    ) async {
      await pumpBar(tester, index: 0, newStories: true);
      expect(find.byKey(KabsoNavBar.dotKey), findsOneWidget);
      expect(
        _label(tester, ShellNavKeys.moments),
        '${en.navMoments}, ${en.navMomentsNew}',
      );
      await pumpBar(tester, index: 2, newStories: true);
      expect(find.byKey(KabsoNavBar.dotKey), findsNothing);
    });

    testWidgets('semantics: five buttons with their labels; one selected', (
      tester,
    ) async {
      await pumpBar(tester, index: 3);
      final labels = [
        en.navLive,
        en.navParty,
        en.navMoments,
        en.navMessages,
        en.navProfile,
      ];
      for (final (i, key) in _keys.indexed) {
        expect(
          tester.getSemantics(find.byKey(key)),
          isSemantics(
            label: labels[i],
            isButton: true,
            isSelected: i == 3,
            hasTapAction: true,
          ),
        );
      }
    });

    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: order follows the ambient direction '
          '(Arabic right → left, English left → right)', (tester) async {
        await pumpBar(tester, index: 0, language: language);
        final xs = [for (final k in _keys) tester.getCenter(find.byKey(k)).dx];
        final sorted = [...xs]..sort();
        expect(
          xs,
          language == AppLanguage.ar ? sorted.reversed.toList() : sorted,
        );
        final l10n = l10nFor(language);
        for (final label in [
          l10n.navLive,
          l10n.navParty,
          l10n.navMoments,
          l10n.navMessages,
          l10n.navProfile,
        ]) {
          expect(
            find.descendant(
              of: find.byType(KabsoNavBar),
              matching: find.text(label),
            ),
            findsOneWidget,
            reason: label,
          );
        }
      });
    }

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: token colours (bar, hairline, '
          'labels)', (tester) async {
        await pumpBar(tester, index: 0, brightness: brightness);
        final p = brightness == Brightness.dark
            ? KPalette.dark
            : KPalette.light;
        final bar = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(KabsoNavBar),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = bar.decoration! as BoxDecoration;
        expect(decoration.color, p.surfaceRaised);
        expect(
          (decoration.border! as Border).top.color,
          brightness == Brightness.dark ? p.border : p.surfaceOverlay,
        );
        await tester.pumpAndSettle();
        expect(_labelColour(tester, 'Live'), p.primaryText);
        for (final label in ['Party', 'Moments', 'Messages', 'Me']) {
          expect(_labelColour(tester, label), p.textSecondary, reason: label);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('safe area: the bar grows by the bottom inset', (tester) async {
      await pumpBar(tester, index: 0, bottomPadding: 34);
      expect(tester.getSize(find.byType(KabsoNavBar)).height, 64 + 34);
      // The owner's 64 pt includes the 1 pt hairline on top.
      final tab = tester.getRect(find.byKey(ShellNavKeys.live));
      expect(tab.height, 63);
      expect(tab.bottom, tester.getRect(find.byType(KabsoNavBar)).bottom - 34);
    });

    for (final scale in [1.3, 2.0]) {
      for (final language in AppLanguage.values) {
        testWidgets('text scale $scale, ${language.name}, 360 dp: no '
            'overflow, 48 dp targets', (tester) async {
          tester.view
            ..physicalSize = const Size(360, 800)
            ..devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await pumpBar(
            tester,
            index: 4,
            textScale: scale,
            language: language,
            unread: 128,
          );
          expect(tester.takeException(), isNull);
          for (final k in _keys) {
            final size = tester.getSize(find.byKey(k));
            expect(size.width, greaterThanOrEqualTo(KSizes.minTouchTarget));
            expect(size.height, greaterThanOrEqualTo(KSizes.minTouchTarget));
          }
        });
      }
    }

    testWidgets("Arabic labels are the owner's", (tester) async {
      expect(
        [ar.navLive, ar.navParty, ar.navMoments, ar.navMessages, ar.navProfile],
        ['البث', 'الحفلة', 'اللحظات', 'الرسائل', 'أنا'],
      );
      expect(
        [en.navLive, en.navParty, en.navMoments, en.navMessages, en.navProfile],
        ['Live', 'Party', 'Moments', 'Messages', 'Me'],
      );
    });
  });

  group('shell bar (D322)', () {
    testWidgets('the five tabs open their real pages; the old bar and its '
        'centre button are gone', (tester) async {
      await _pumpShell(tester);
      expect(find.byType(KabsoNavBar), findsOneWidget);
      expect(find.byKey(const Key('nav.create')), findsNothing);
      expect(_selected(tester, ShellNavKeys.live), isTrue);
      expect(find.byType(LiveScreen), findsOneWidget);

      final pages = <Key, (Type, String)>{
        ShellNavKeys.party: (VoiceRoomsScreen, AppRoutes.voiceRooms),
        ShellNavKeys.moments: (FeedScreen, AppRoutes.reels),
        ShellNavKeys.me: (MeHubScreen, AppRoutes.profile),
        ShellNavKeys.live: (LiveScreen, AppRoutes.home),
      };
      for (final MapEntry(:key, value: (type, location)) in pages.entries) {
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(_selected(tester, key), isTrue, reason: '$key');
        expect(find.byType(type), findsOneWidget, reason: '$key');
        expect(_location(tester), location);
      }
      await tester.tap(find.byKey(ShellNavKeys.messages));
      await tester.pumpAndSettle();
      expect(_location(tester), AppRoutes.messages);
      // D155: the real conversation list (no conversations in the fake).
      expect(find.text(en.conversationsEmptyTitle), findsOneWidget);
    });

    testWidgets('deep links select their tab: /live/voice → «الحفلة»', (
      tester,
    ) async {
      await _pumpShell(tester, language: 'ar');
      GoRouter.of(tester.element(find.byType(Navigator).first))
          .go(AppRoutes.voiceRooms);
      await tester.pumpAndSettle();
      expect(find.byType(VoiceRoomsScreen), findsOneWidget);
      expect(_selected(tester, ShellNavKeys.party), isTrue);
      expect(find.byType(KabsoNavBar), findsOneWidget);
    });

    testWidgets('per-tab state: the hub keeps its filter across a tab '
        'switch; re-tapping a tab keeps its page', (tester) async {
      await _pumpShell(tester);
      final explore = find.byKey(
        LiveHubFilterBar.pillKey(LiveHubFilter.explore),
      );
      await tester.tap(explore);
      await tester.pumpAndSettle();
      bool exploreSelected() =>
          tester
              .getSemantics(explore)
              .getSemanticsData()
              .flagsCollection
              .isSelected ==
          Tristate.isTrue;
      expect(exploreSelected(), isTrue);
      await tester.tap(find.byKey(ShellNavKeys.party));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ShellNavKeys.live));
      await tester.pumpAndSettle();
      expect(exploreSelected(), isTrue);
      await tester.tap(find.byKey(ShellNavKeys.live));
      await tester.pumpAndSettle();
      expect(find.byType(LiveScreen), findsOneWidget);
      expect(_location(tester), AppRoutes.home);
    });

    testWidgets('the badge shows the real unread provider', (tester) async {
      await _pumpShell(
        tester,
        overrides: [unreadMessagesProvider.overrideWithValue(7)],
      );
      expect(tester.widget<Text>(find.byKey(KabsoNavBar.badgeKey)).data, '7');
      expect(
        _label(tester, ShellNavKeys.messages),
        '${en.navMessages}, ${en.navMessagesUnread(7)}',
      );
    });

    testWidgets('no unread messages: no badge; no unseen stories: no dot', (
      tester,
    ) async {
      await _pumpShell(tester);
      expect(find.byKey(KabsoNavBar.badgeKey), findsNothing);
      expect(find.byKey(KabsoNavBar.dotKey), findsNothing);
    });

    testWidgets("a followed account's unseen story puts the dot on "
        'Moments', (tester) async {
      await _pumpShell(
        tester,
        overrides: [
          storyTrayProvider.overrideWith(
            (ref) => [
              _trayItem(testUser().id, unseen: true),
              _trayItem('friend', unseen: true),
            ],
          ),
        ],
      );
      expect(find.byKey(KabsoNavBar.dotKey), findsOneWidget);
      await tester.tap(find.byKey(ShellNavKeys.moments));
      await tester.pumpAndSettle();
      expect(find.byKey(KabsoNavBar.dotKey), findsNothing);
    });

    for (final language in ['ar', 'en']) {
      testWidgets('$language: the shell bar mirrors with the language', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(393, 852) * 3
          ..devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await _pumpShell(tester, language: language);
        final xs = [for (final k in _keys) tester.getCenter(find.byKey(k)).dx];
        final sorted = [...xs]..sort();
        expect(xs, language == 'ar' ? sorted.reversed.toList() : sorted);
      });
    }
  });
}
