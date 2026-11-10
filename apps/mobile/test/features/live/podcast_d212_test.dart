// D212 (owner; D237: the party page's three kinds; D342: one mixed list,
// each card with its kind's badge): the live categories, the podcast live
// (stage,
// raised hands, the host's hands sheet, the setup) and the chat rule for
// every category (D236: the rules line stays as a line at the first
// message; each join is a
// line). Fakes stand in for the API and the media engine (tests only).
import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_sheets.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/podcast_hub.dart';
import 'package:kabso_live/features/live/presentation/hub/voice_room_list.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_type_tag.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/l10n/gen/app_localizations.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

UserSummary _u(String id, String name) =>
    UserSummary(id: id, username: id, displayName: name, avatarUrl: null);

LiveRoomSummary _podcastSummary({bool ar = true}) =>
    apiRooms(1, ar: ar).first.copyWith(
      id: 'room-0',
      mode: LiveRoomMode.podcast,
      seatCount: 4,
      viewerCount: 1200,
      podcast: LivePodcast(
        episodeNumber: 12,
        topic: PodcastTopic.business,
        speakers: [
          LivePodcastSpeaker(
            id: 'u1',
            username: 'u1',
            displayName: ar ? 'عمر' : 'Omar',
          ),
        ],
      ),
    );

LiveSeats _podcastSeats({
  required LiveSeatRole role,
  List<String> handsUp = const [],
  LiveSeatRequest? request,
  int? mine,
  DateTime? demoteAt,
}) => LiveSeats(
  roomId: 'room-0',
  mode: LiveRoomMode.podcast,
  version: 1,
  seatCount: 4,
  seats: [
    LiveSeat(
      index: 1,
      state: LiveSeatState.taken,
      user: _u('u1', 'عمر'),
      mutedByHost: true,
      points: 980,
    ),
    LiveSeat(
      index: 2,
      state: LiveSeatState.taken,
      user: mine == 2 ? _u(testUser().id, 'أنا') : _u('u2', 'سارة'),
      points: 410,
      demoteAt: demoteAt,
    ),
    const LiveSeat(index: 3, state: LiveSeatState.empty, user: null),
  ],
  moderators: const [],
  handsUp: handsUp,
  pendingRequests: role == LiveSeatRole.host ? handsUp.length : null,
  mine: LiveSeatsMine(
    role: role,
    seatIndex: mine,
    request: request,
    invite: null,
  ),
);

Future<(FakeLiveRepository, FakeLiveMediaEngine)> _openRoom(
  WidgetTester tester, {
  required LiveSeats seats,
  String language = 'ar',
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
}) async {
  final ar = language == 'ar';
  final live =
      FakeLiveRepository(
          rooms: (_) => apiPage([_podcastSummary(ar: ar)]),
          room: (id) => apiRoom(id: id, ar: ar).copyWith(
            mode: LiveRoomMode.podcast,
            seatCount: 4,
            viewerCount: 1200,
            theme: 'podcast-studio',
            podcast: const LivePodcast(
              episodeNumber: 12,
              topic: PodcastTopic.business,
            ),
          ),
        )
        ..seatState = seats
        ..viewerList = [
          for (final (id, name) in [
            ('v1', 'نور'),
            ('v2', 'خالد'),
            ('v3', 'هادي'),
            ('v4', 'رنا'),
          ])
            LiveViewer(
              kind: LiveViewerKind.user,
              user: _u(id, name),
              guestNumber: null,
              joinedAt: DateTime.utc(2026, 10, 31),
            ),
        ];
  final engine = FakeLiveMediaEngine()
    ..present.add('user-0')
    ..speakingNow = {'user-0'};
  setViewport(tester, viewport);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await pumpKabsoApp(
    tester,
    language: language,
    liveRepository: live,
    liveMediaEngine: engine,
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(storedUser: testUser(), me: testUser()),
      ),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('nav.home')));
  await tester.pumpAndSettle();
  await _openParty(tester);
  await tester.tap(find.byKey(VoiceRoomList.rowKey(0)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(seconds: 1));
  expect(find.byType(LiveRoomScreen), findsOneWidget);
  return (live, engine);
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 12));
}

void main() {
  group('hub categories', () {
    Future<FakeLiveRepository> hub(
      WidgetTester tester, {
      String language = 'ar',
      List<LiveScheduledPodcast> scheduled = const [],
      FakeProfileRepository? profiles,
    }) async {
      final ar = language == 'ar';
      final live = FakeLiveRepository(
        rooms: (r) => apiPage(
          r.kind == LiveRoomsKind.partyAll
              // D342: the server's one mixed list.
              ? [
                  apiRooms(
                    1,
                    start: 5,
                    ar: ar,
                  ).first.copyWith(mode: LiveRoomMode.audio, seatCount: 8),
                  _podcastSummary(ar: ar),
                  apiRooms(
                    1,
                    start: 6,
                    ar: ar,
                  ).first.copyWith(mode: LiveRoomMode.multi, seatCount: 4),
                ]
              : apiRooms(3, ar: ar),
        ),
      )..scheduled = scheduled;
      setViewport(tester, GoldenViewport.phone);
      await pumpKabsoApp(
        tester,
        language: language,
        liveRepository: live,
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(storedUser: testUser(), me: testUser()),
          ),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          profileRepositoryProvider.overrideWithValue(
            profiles ?? FakeProfileRepository(apiProfile()),
          ),
        ],
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav.home')));
      await tester.pumpAndSettle();
      return live;
    }

    testWidgets('D237: no category row on the hub. D342: the party page '
        'has no kinds row — one server list (kind=party_all) under each '
        'filter, the podcast among the audio and multi rooms, each card with '
        "its kind's badge", (tester) async {
      final live = await hub(tester);
      final l10n = lookupAppLocalizations(AppLanguage.ar.locale);
      expect(find.byType(LiveHubCategoryBar), findsNothing);
      // D239: the hub is solo and PK only.
      expect(live.requests.last.kind, LiveRoomsKind.solo);
      final before = live.requests.length;
      await _openParty(tester);
      expect(find.byType(VoiceRoomsScreen), findsOneWidget);
      expect(live.requests.last.kind, LiveRoomsKind.partyAll);
      expect(live.requests.skip(before).map((r) => r.kind).toSet(), {
        LiveRoomsKind.partyAll,
      });
      expect(find.byKey(const Key('voiceRooms.kinds')), findsNothing);
      for (final c in LiveHubCategory.partyPage) {
        expect(find.byKey(Key('voiceRooms.kind.${c.name}')), findsNothing);
      }
      expect(find.text(l10n.liveCategoryStreamer), findsNothing);
      // The server's order, the kinds mixed.
      for (final (i, kind) in [
        (0, PartyKind.audio),
        (1, PartyKind.podcast),
        (2, PartyKind.multi),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(VoiceRoomList.rowKey(i)),
            matching: find.byKey(LiveTypeTag.keyOf(kind.cardKind)),
          ),
          findsOneWidget,
          reason: kind.name,
        );
      }
      // The filters (the top tabs) apply to the one list: Following.
      await tester.tap(
        find.byKey(VoiceRoomsScreen.filterKey(LiveHubFilter.following)),
      );
      await tester.pumpAndSettle();
      expect(live.requests.last.tab, LiveRoomsTab.following);
      expect(live.requests.last.kind, LiveRoomsKind.partyAll);
      expect(
        find.byKey(LiveTypeTag.keyOf(PartyKind.podcast.cardKind)),
        findsOne,
      );
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    testWidgets('D342: a podcast is a party card with its badge, its '
        'episode and topic; the announced episode with «ذكّرني» (follows '
        'the host) stays above the list', (tester) async {
      final profiles = FakeProfileRepository(apiProfile());
      final live = await hub(
        tester,
        profiles: profiles,
        scheduled: [
          LiveScheduledPodcast(
            id: 'slot-1',
            title: 'الحلقة القادمة',
            startsAt: DateTime.utc(2026, 11, 2, 18),
            podcastTopic: PodcastTopic.tech,
            host: _u('h9', 'ليلى'),
          ),
        ],
      );
      await _openParty(tester);
      expect(live.requests.last.kind, LiveRoomsKind.partyAll);
      final card = find.byKey(VoiceRoomList.rowKey(1));
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(LiveTypeTag.keyOf(PartyKind.podcast.cardKind)),
        ),
        findsOneWidget,
      );
      expect(
        // D362: the owner's English tag, in Arabic too.
        find.descendant(of: card, matching: find.text('Podcast')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('الحلقة 12 · ريادة أعمال'),
        ),
        findsOneWidget,
      );
      final section = find.byKey(ScheduledPodcastsSection.sectionKey);
      expect(section, findsOneWidget);
      expect(
        tester.getRect(section).bottom,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(VoiceRoomList.rowKey(0))).top,
        ),
      );
      await tester.tap(
        find.byKey(ScheduledPodcastsSection.remindKey('slot-1')),
      );
      await tester.pumpAndSettle();
      expect(profiles.calls, contains('PUT h9'));
      expect(find.text('سنذكّرك'), findsOneWidget);
      await _close(tester);
    });
  });

  group('podcast room', () {
    testWidgets('listener: the episode card, four speakers (host tag, the '
        'speaking ring, mic badges, cherries), the listeners with raised '
        'hands first and their ✋ never clipped', (tester) async {
      await _openRoom(
        tester,
        seats: _podcastSeats(role: LiveSeatRole.viewer, handsUp: const ['v3']),
      );
      expect(find.byKey(PodcastStage.stageKey), findsOneWidget);
      expect(find.byKey(PodcastEpisodeCard.cardKey), findsOneWidget);
      expect(find.text('الحلقة 12'), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(PodcastSpeakers.seatKey(i)), findsOneWidget);
      }
      expect(find.byKey(PodcastSpeakers.hostTagKey), findsOneWidget);
      expect(find.byKey(PodcastSpeakers.ringKey), findsOneWidget);
      expect(find.text('980'), findsOneWidget);
      // Raised hands first (hadi is 3rd in the viewers, 1st in the row).
      final row = find.byKey(PodcastListeners.rowKey);
      final first = tester.getTopLeft(
        find.byKey(PodcastListeners.listenerKey('v3')),
      );
      final second = tester.getTopLeft(
        find.byKey(PodcastListeners.listenerKey('v1')),
      );
      // RTL: the first item is at the right.
      expect(first.dx, greaterThan(second.dx));
      final badge = tester.getRect(find.byKey(PodcastListeners.handKey('v3')));
      final box = tester.getRect(row);
      expect(badge.top, greaterThanOrEqualTo(box.top));
      expect(
        box.contains(badge.topLeft) || box.contains(badge.topRight),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await _close(tester);
    });

    testWidgets('listener raises a hand with a question; the red ✋ lowers '
        'it', (tester) async {
      final (live, _) = await _openRoom(
        tester,
        seats: _podcastSeats(role: LiveSeatRole.viewer),
      );
      final hand = find.byKey(PodcastHandButton.buttonKey);
      expect(hand, findsOneWidget);
      // The red ✋ is the bar buttons' size.
      expect(tester.getSize(hand).width, 48);
      await tester.tap(hand);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(PodcastAsk.fieldKey), 'كيف أبدأ؟');
      await tester.tap(find.byKey(PodcastAsk.sendKey));
      await tester.pumpAndSettle();
      expect(live.seatCalls, contains('requestSeat:'));
      expect(live.lastQuestion, 'كيف أبدأ؟');
      await _close(tester);
    });

    testWidgets('closed hands: the ✋ says so and asks nothing', (tester) async {
      final ar = lookupAppLocalizations(AppLanguage.ar.locale);
      final live = FakeLiveRepository();
      await _openRoomWith(tester, live, questionsOpen: false);
      await tester.tap(find.byKey(PodcastHandButton.buttonKey));
      await tester.pumpAndSettle();
      expect(find.text(ar.podcastQuestionsClosed), findsOneWidget);
      expect(live.seatCalls.where((c) => c.startsWith('requestSeat')), isEmpty);
      await _close(tester);
    });

    testWidgets("a timed question: the speaker's pill counts down and their "
        'app leaves the seat when it ends', (tester) async {
      final start = clock.now();
      final (live, _) = await _openRoom(
        tester,
        seats: _podcastSeats(
          role: LiveSeatRole.seated,
          mine: 2,
          demoteAt: start.add(const Duration(seconds: 80)),
        ),
      );
      expect(find.byKey(PodcastSpeakers.questionKey), findsOneWidget);
      expect(find.textContaining('سؤال ·'), findsOneWidget);
      await tester.pump(const Duration(seconds: 81));
      await tester.pump();
      expect(live.seatCalls, contains('leaveSeat'));
      await _close(tester);
    });

    for (final (language, viewport, scale) in [
      ('ar', GoldenViewport.phone, 1.0),
      ('en', GoldenViewport.phone, 1.0),
      ('ar', GoldenViewport.android, 1.3),
      ('en', GoldenViewport.android, 1.3),
    ]) {
      testWidgets('no overflow ($language, ${viewport.name}, ×$scale)', (
        tester,
      ) async {
        await _openRoom(
          tester,
          language: language,
          viewport: viewport,
          textScale: scale,
          seats: _podcastSeats(
            role: LiveSeatRole.viewer,
            handsUp: const ['v1', 'v2'],
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(PodcastStage.stageKey), findsOneWidget);
        await _close(tester);
      });
    }
  });

  group("the host's hands sheet", () {
    testWidgets('«N طلبات · مقعد واحد متاح», «لاحقاً», «اصعد», the switch '
        'and the question time', (tester) async {
      final live = FakeLiveRepository()
        ..seatState = _podcastSeats(role: LiveSeatRole.host)
        ..pendingSeatRequests = [
          LiveSeatRequest(
            id: 'r1',
            user: _u('v1', 'نور'),
            seatIndex: null,
            createdAt: DateTime.utc(2026, 10, 31, 18),
            question: 'كيف أختار الشريك المناسب؟',
          ),
          LiveSeatRequest(
            id: 'r2',
            user: _u('v2', 'خالد'),
            seatIndex: null,
            createdAt: DateTime.utc(2026, 10, 31, 18, 1),
          ),
        ];
      final settings = <String>[];
      final ups = <String>[];
      final laters = <String>[];
      setViewport(tester, GoldenViewport.phone);
      await loadAppFonts();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [liveRepositoryProvider.overrideWithValue(live)],
          child: MaterialApp(
            locale: AppLanguage.ar.locale,
            theme: buildAppTheme(
              brightness: Brightness.light,
              locale: AppLanguage.ar.locale,
            ),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () => unawaited(
                      showPodcastHandsSheet(
                        context,
                        load: () async =>
                            (await live.seatRequests('room-0')).items,
                        freeSeats: 1,
                        podcast: const LivePodcast(
                          episodeNumber: 3,
                          topic: PodcastTopic.tech,
                        ),
                        config: const LivePodcastConfig(),
                        onBringUp: (r) async => ups.add(r.id),
                        onLater: (r) async => laters.add(r.id),
                        onSettings: ({questionsOpen, seconds}) async =>
                            settings.add(
                              'open:$questionsOpen seconds:${seconds?.call()}',
                            ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(PodcastHandsSheet.sheetKey), findsOneWidget);
      expect(find.text('رفع الأيدي ✋'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(PodcastHandsSheet.summaryKey)).data,
        'طلبان · مقعد واحد متاح',
      );
      expect(find.text('كيف أختار الشريك المناسب؟'), findsOneWidget);
      await tester.tap(find.byKey(PodcastHandsSheet.laterKey('r1')));
      await tester.pumpAndSettle();
      expect(laters, ['r1']);
      await tester.tap(find.byKey(PodcastHandsSheet.upKey('r2')));
      await tester.pumpAndSettle();
      expect(ups, ['r2']);
      // No seat left: «اصعد» is off.
      expect(
        tester
            .widget<FilledButton>(find.byKey(PodcastHandsSheet.upKey('r1')))
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(PodcastHandsSheet.secondsKey(300)));
      await tester.tap(find.byKey(PodcastHandsSheet.secondsKey(300)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(PodcastHandsSheet.secondsKey(null)),
      );
      await tester.tap(find.byKey(PodcastHandsSheet.secondsKey(null)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PodcastHandsSheet.openKey));
      await tester.pumpAndSettle();
      expect(settings, [
        'open:null seconds:300',
        'open:null seconds:null',
        'open:false seconds:null',
      ]);
      expect(tester.takeException(), isNull);
    });
  });

  group('chat rule (every category)', () {
    testWidgets(
      'D236: the rules line stays at the first message; each join is its '
      'own line, by the shown gender',
      (tester) async {
        final (_, engine) = await _openRoom(
          tester,
          seats: _podcastSeats(role: LiveSeatRole.viewer),
        );
        expect(find.byKey(LiveRoomChatLines.noticeKey), findsOneWidget);
        engine.chat
          ..add(LiveChatJoined(_u('j1', 'جود'), gender: LiveJoinGender.male))
          ..add(LiveChatJoined(_u('j2', 'دانة'), gender: LiveJoinGender.female))
          ..add(LiveChatJoined(_u('j3', 'كريم')));
        await tester.pump();
        await tester.pump();
        // Joins do not count as writing: the rules line stays.
        expect(find.byKey(LiveRoomChatLines.noticeKey), findsOneWidget);
        Finder has(String t) => find.textContaining(t, findRichText: true);
        expect(has('دخل البث'), findsOneWidget);
        expect(has('دخلت البث'), findsOneWidget);
        expect(has('انضم'), findsOneWidget);
        engine.chat.add(
          LiveChatReceived(
            LiveChatEntry(
              id: 'm1',
              roomId: 'room-0',
              author: _u('v1', 'نور'),
              text: 'كيف أختار الشريك المناسب؟',
              createdAt: DateTime.utc(2026, 10, 31, 18),
              authorRole: LiveChatRole.viewer,
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byKey(LiveRoomChatLines.noticeKey), findsOneWidget);
        expect(
          find.textContaining('كيف أختار', findRichText: true),
          findsWidgets,
        );
        await _close(tester);
      },
    );

    testWidgets("D261: a listener's message goes to the server (the host "
        'sees it through the room)', (tester) async {
      final (live, _) = await _openRoom(
        tester,
        seats: _podcastSeats(role: LiveSeatRole.viewer),
      );
      await tester.tap(find.byKey(AudioRoomViewKeys.chat));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).last, 'مرحبا');
      await tester.tap(find.byKey(const Key('liveChat.send')));
      await tester.pump();
      await tester.pump();
      expect(live.chatCalls, contains('send:مرحبا'));
      await _close(tester);
    });

    test('D230: `written` comes from the controller (what arrives during '
        'the visit), never from where the history sits', () {
      expect(const LiveChatState().written, isFalse);
      expect(const LiveChatState().copyWith(written: true).written, isTrue);
      expect(
        const LiveChatState(written: true).copyWith(loaded: true).written,
        isTrue,
      );
    });
  });

  group('contrast on the podcast themes', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (la > lb ? la + 0.05 : lb + 0.05) /
          (la > lb ? lb + 0.05 : la + 0.05);
    }

    // The brightest pixel under the stage of each podcast background,
    // cover-fit at 393 × 852 with the room's scrims (measured from the
    // assets), and the classic navy.
    const brightest = [
      Color(0xFF990D1F), // podcast-studio
      Color(0xFFE5E5BF), // podcast-majlis (a lantern)
      Color(0xFF057257), // podcast-library
      Color(0xFF0A1220), // classic
    ];

    test('white text on the question / cherry pill reads at ≥ 4.5 : 1', () {
      for (final under in brightest) {
        final box = Color.alphaBlend(KPodcast.pill, under);
        expect(
          contrast(const Color(0xFFFFFFFF), box),
          greaterThanOrEqualTo(4.5),
          reason: '$under',
        );
      }
    });

    test('the host tag keeps 3 : 1 at its edge (its dark outline)', () {
      for (final under in brightest) {
        final outline = Color.alphaBlend(KPodcast.hostTagOutline, under);
        expect(
          contrast(KPodcast.hostTag, outline),
          greaterThanOrEqualTo(3),
          reason: '$under',
        );
      }
    });
  });

  group('listener order', () {
    test('raised hands first in queue order, then the others as they came', () {
      PodcastListenerData l(String id) =>
          PodcastListenerData(userId: id, name: id);
      final out = podcastListenerOrder(
        [l('a'), l('b'), l('c'), l('d')],
        ['d', 'b'],
      );
      expect(out.map((e) => e.userId), ['d', 'b', 'a', 'c']);
      expect(out.map((e) => e.handUp), [true, true, false, false]);
    });

    test('clock text', () {
      expect(podcastClock(const Duration(seconds: 80)), '1:20');
      expect(podcastClock(const Duration(hours: 1, seconds: 5)), '1:00:05');
      expect(podcastClock(const Duration(seconds: -3)), '0:00');
    });
  });
}

/// A podcast room with [questionsOpen] (the hands switch).
Future<void> _openRoomWith(
  WidgetTester tester,
  FakeLiveRepository live, {
  required bool questionsOpen,
}) async {
  live
    ..rooms = ((_) => apiPage([_podcastSummary()]))
    ..room = ((id) => apiRoom(id: id, ar: true).copyWith(
      mode: LiveRoomMode.podcast,
      seatCount: 4,
      podcast: LivePodcast(
        episodeNumber: 2,
        topic: PodcastTopic.tech,
        questionsOpen: questionsOpen,
      ),
    ))
    ..seatState = _podcastSeats(role: LiveSeatRole.viewer);
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  setViewport(tester, GoldenViewport.phone);
  await pumpKabsoApp(
    tester,
    language: 'ar',
    liveRepository: live,
    liveMediaEngine: engine,
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(storedUser: testUser(), me: testUser()),
      ),
      secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('nav.home')));
  await tester.pumpAndSettle();
  await _openParty(tester);
  await tester.tap(find.byKey(VoiceRoomList.rowKey(0)));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

/// D237: opens the party page — D322: the «الحفلة» tab.
Future<void> _openParty(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('nav.party')));
  await tester.pumpAndSettle();
}
