// D342 (owner 2026-11-09): the «الحفلة» tab without its top Live switch
// («زر في الاعلى لنقل المستخدم على لايف … ازله»; it was D139's mirror of the
// hub's party button, D240's corner switch) and without its kinds row
// («ازل فلاتر بث صوتي بث بوكاست و بث متعدد … ان يكونو بنفس الصف لكن ميز كل
// واحده بهم»): one mixed list, each card with its kind's badge; a tap opens
// that room. The bar's «البث» tab is the way to the hub. The whole app with
// fakes (tests only).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/live/application/live_room_swipe.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/voice_room_list.dart';
import 'package:kabso_live/features/live/presentation/widgets/party_kind_badge.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

/// The server's mixed party list: audio, podcast, multi, audio, multi,
/// podcast (rooms 0–5).
const List<LiveRoomMode> _modes = [
  LiveRoomMode.audio,
  LiveRoomMode.podcast,
  LiveRoomMode.multi,
  LiveRoomMode.audio,
  LiveRoomMode.multi,
  LiveRoomMode.podcast,
];

LiveRoomMode _modeOf(String id) => _modes[int.parse(id.split('-').last)];

PartyKind _kindOf(LiveRoomMode mode) => switch (mode) {
  LiveRoomMode.podcast => PartyKind.podcast,
  LiveRoomMode.multi => PartyKind.multi,
  _ => PartyKind.audio,
};

Future<FakeLiveRepository> _pumpApp(
  WidgetTester tester,
  AppLanguage language,
) async {
  final ar = language == AppLanguage.ar;
  final live = FakeLiveRepository(
    rooms: (r) => apiPage(
      r.kind == LiveRoomsKind.partyAll
          ? [
              for (final (i, room) in apiRooms(6, ar: ar).indexed)
                room.copyWith(
                  mode: _modes[i],
                  seatCount: _modes[i] == LiveRoomMode.podcast ? 4 : 8,
                  podcast: _modes[i] == LiveRoomMode.podcast
                      ? LivePodcast(
                          episodeNumber: i + 1,
                          topic: PodcastTopic.business,
                        )
                      : null,
                ),
            ]
          // The hub (D239: solo and PK).
          : apiRooms(4, ar: ar),
    ),
    room: (id) => apiRoom(id: id, ar: ar).copyWith(
      mode: _modeOf(id),
      seatCount: _modeOf(id) == LiveRoomMode.podcast ? 4 : 8,
      podcast: _modeOf(id) == LiveRoomMode.podcast
          ? const LivePodcast(episodeNumber: 2, topic: PodcastTopic.business)
          : null,
    ),
  );
  await pumpKabsoApp(
    tester,
    language: language.name,
    liveRepository: live,
    liveMediaEngine: FakeLiveMediaEngine(),
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(storedUser: testUser(), me: testUser()),
      ),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
  );
  await tester.pumpAndSettle();
  return live;
}

GoRouter _router(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(Navigator).first));

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

/// D322: the party page is the «الحفلة» tab.
Future<void> _openFromTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav.party')));
  await tester.pumpAndSettle();
  expect(find.byType(VoiceRoomsScreen), findsOneWidget);
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 12));
}

void main() {
  for (final language in AppLanguage.values) {
    final l10n = l10nFor(language);
    group('${language.name}: the party tab (D342)', () {
      testWidgets('no Live switch and no kinds row; one party_all list; the '
          "bar's «البث» tab still opens the hub", (tester) async {
        final live = await _pumpApp(tester, language);
        await _openFromTab(tester);
        expect(_location(tester), AppRoutes.voiceRooms);
        final page = find.byType(VoiceRoomsScreen);
        // The switch is gone: its key, its animated icon, its name.
        expect(find.byKey(const Key('voiceRooms.live')), findsNothing);
        expect(
          find.descendant(of: page, matching: find.byType(KLiveIcon)),
          findsNothing,
        );
        expect(
          find.descendant(of: page, matching: find.byType(IconButton)),
          findsOneWidget, // only the list/grid switch
        );
        expect(
          find.descendant(
            of: page,
            matching: find.byKey(VoiceRoomsScreen.layoutKey),
          ),
          findsOneWidget,
        );
        // The kinds row and its three tabs are gone.
        expect(find.byKey(const Key('voiceRooms.kinds')), findsNothing);
        for (final k in LiveHubCategory.partyPage) {
          expect(find.byKey(Key('voiceRooms.kind.${k.name}')), findsNothing);
        }
        expect(
          find.descendant(
            of: page,
            matching: find.text(l10n.liveCategoryRowLabel),
          ),
          findsNothing,
        );
        // One list of every party kind.
        expect(live.requests.last.kind, LiveRoomsKind.partyAll);
        for (final kind in PartyKind.values) {
          expect(find.byKey(PartyKindBadge.keyOf(kind)), findsWidgets);
        }
        // D322: the bar's «البث» tab is the way to the hub.
        await tester.tap(find.byKey(const Key('nav.home')));
        await tester.pumpAndSettle();
        expect(find.byType(LiveScreen), findsOneWidget);
        expect(_location(tester), AppRoutes.home);
        await _close(tester);
      });

      for (final (index, mode) in [
        (0, LiveRoomMode.audio),
        (1, LiveRoomMode.podcast),
        (2, LiveRoomMode.multi),
      ]) {
        testWidgets('a tap on the ${mode.name} card (its badge) opens that '
            'room; the swipe list is the mixed list', (tester) async {
          final live = await _pumpApp(tester, language);
          await _openFromTab(tester);
          final row = find.byKey(VoiceRoomList.rowKey(index));
          expect(
            find.descendant(
              of: row,
              matching: find.byKey(PartyKindBadge.keyOf(_kindOf(mode))),
            ),
            findsOneWidget,
          );
          await tester.tap(row);
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          expect(find.byType(LiveRoomScreen), findsOneWidget);
          expect(
            tester.widget<LiveRoomScreen>(find.byType(LiveRoomScreen)).roomId,
            'room-$index',
          );
          expect(live.roomRequests, contains('room-$index'));
          // Swiping inside the room moves through the mixed list, in order.
          final container = ProviderScope.containerOf(
            tester.element(find.byType(LiveRoomScreen)),
          );
          expect(
            container.read(liveRoomSwipeListProvider).map((r) => r.roomId),
            [for (var i = 0; i < _modes.length; i++) 'room-$i'],
          );
          await _close(tester);
        });
      }

      testWidgets('360×800 at text ×1.3 (real fonts): no overflow, the four '
          'filters whole on screen, each badge whole on its picture', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await loadAppFonts();
        await _pumpApp(tester, language);
        await _openFromTab(tester);
        expect(tester.takeException(), isNull);
        for (final f in VoiceRoomsScreen.filters) {
          final tab = tester.getRect(find.byKey(VoiceRoomsScreen.filterKey(f)));
          expect(tab.left, greaterThanOrEqualTo(0));
          expect(tab.right, lessThanOrEqualTo(360));
        }
        for (final i in [0, 1, 2]) {
          final row = tester.getRect(find.byKey(VoiceRoomList.rowKey(i)));
          final badge = tester.getRect(
            find.descendant(
              of: find.byKey(VoiceRoomList.rowKey(i)),
              matching: find.byType(PartyKindBadge),
            ),
          );
          // On the cover, at the reading start.
          if (language == AppLanguage.ar) {
            expect(badge.right, lessThanOrEqualTo(row.right));
            expect(badge.left, greaterThanOrEqualTo(row.right - 68.6));
          } else {
            expect(badge.left, greaterThanOrEqualTo(row.left));
            expect(badge.right, lessThanOrEqualTo(row.left + 68.6));
          }
        }
        await tester.tap(find.byKey(VoiceRoomsScreen.layoutKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(PartyKindBadge), findsWidgets);
        await _close(tester);
      });
    });
  }
}
