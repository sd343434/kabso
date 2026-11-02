// D212 goldens: the hub's category row and podcast cards, the podcast setup,
// the podcast room (listener and host with the hands sheet) and the chat
// after the rules line went, ar and en. Fake repositories and the fake media
// engine (tests only; names are fixtures, no real people).
//
// With KABSO_CAPTURE_DIR set, each screen is also written there at @3x for
// the owner (never committed: the directory is outside the repository).
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/podcast_golden_test.dart
@Tags(['golden'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_mini_window.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_room.dart';
import 'package:kabso_live/features/live/presentation/hub/live_hub_filters.dart';
import 'package:kabso_live/features/live/presentation/hub/podcast_hub.dart';
import 'package:kabso_live/features/live/voice_rooms_screen.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../fixtures/live/live_api_fixtures.dart';
import '../helpers/fake_live_media_engine.dart';
import '../helpers/fake_live_pk.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fake_profile_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

final String? _captureDir = Platform.environment['KABSO_CAPTURE_DIR'];

/// Writes the whole screen at @3x to KABSO_CAPTURE_DIR (when set).
Future<void> _capture(WidgetTester tester, String name) async {
  final dir = _captureDir;
  if (dir == null) return;
  final view = tester.binding.renderViews.first;
  await tester.runAsync(() async {
    // The root layer already scales logical to physical pixels (@3x).
    final layer = view.debugLayer! as OffsetLayer;
    final image = await layer.toImage(
      Offset.zero & (view.size * GoldenViewport.pixelRatio),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

/// The fixtures' lives start at 19:00 UTC; the goldens are taken 18:42
/// later (the episode timer), the timed question 1:20 from its end.
final DateTime _now = DateTime.utc(2026, 10, 16, 19, 18, 42);

/// Runs a golden at the fixed [_now] (the room timers read `clock`).
void _testGolden(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(
      name,
      (tester) => withClock(Clock.fixed(_now), () => body(tester)),
    );

UserSummary _u(String id, String name) =>
    UserSummary(id: id, username: id, displayName: name, avatarUrl: null);

List<LiveViewer> _viewers(bool ar) => [
  for (final (id, a, e) in [
    ('v1', 'نور', 'Noor'),
    ('v2', 'خالد', 'Khaled'),
    ('v3', 'هادي', 'Hadi'),
    ('v4', 'رنا', 'Rana'),
    ('v5', 'فهد', 'Fahd'),
    ('v6', 'جود', 'Joud'),
    ('v7', 'كريم', 'Karim'),
  ])
    LiveViewer(
      kind: LiveViewerKind.user,
      user: _u(id, ar ? a : e),
      guestNumber: null,
      joinedAt: DateTime.utc(2026, 10, 31),
    ),
];

void _phoneInsets(WidgetTester tester, GoldenViewport viewport) {
  if (viewport != GoldenViewport.phone) return;
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

/// The host's screen in podcast mode: setup, or on air with speakers,
/// raised hands and chat lines.
Future<(FakeLiveRepository, FakeLiveMediaEngine, ProviderContainer)> _host(
  WidgetTester tester, {
  required AppLanguage language,
  required bool onAir,
  GoldenViewport viewport = GoldenViewport.phone,
  String theme = 'podcast-studio',
  bool insets = true,
}) async {
  final ar = language == AppLanguage.ar;
  final repo = FakeLiveRepository()..podcastEpisode = 12;
  late FakeLiveMediaEngine engine;
  final prefs = await testPrefs(language: language.name);
  if (insets) _phoneInsets(tester, viewport);
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveRepositoryProvider.overrideWithValue(repo),
        ...pkTestOverrides(),
        liveMediaEngineProvider.overrideWithValue(
          () => engine = FakeLiveMediaEngine(),
        ),
        currentUserProvider.overrideWithValue(
          testUser(displayName: ar ? 'ليلى' : 'Layla').copyWith(canHost: true),
        ),
      ],
      child: Stack(
        children: [
          const GoLiveScreen(),
          LiveMiniWindow(router: GoRouter(routes: [])),
        ],
      ),
    ),
    language: language,
    viewport: viewport,
    bare: true,
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LiveMiniWindow)),
  );
  final keep = container.listen(liveHostControllerProvider, (_, _) {});
  addTearDown(keep.close);
  final host = container.read(liveHostControllerProvider.notifier);
  await host.setMode(LiveRoomMode.podcast);
  await host.setTheme(theme);
  host.setPodcastSetup(const PodcastSetup(topic: PodcastTopic.business));
  if (onAir) {
    repo
      ..viewerList = _viewers(ar)
      ..pendingSeatRequests = [
        LiveSeatRequest(
          id: 'r1',
          user: _u('v1', ar ? 'نور' : 'Noor'),
          seatIndex: null,
          createdAt: DateTime.utc(2026, 10, 31, 18),
          question: ar
              ? 'كيف أختار الشريك المناسب؟'
              : 'How do I pick a partner?',
        ),
        LiveSeatRequest(
          id: 'r2',
          user: _u('v2', ar ? 'خالد' : 'Khaled'),
          seatIndex: null,
          createdAt: DateTime.utc(2026, 10, 31, 18, 1),
        ),
      ];
    await host.goLive(
      title: ar
          ? 'كيف تبدأ مشروعك الأول برأس مال صغير؟'
          : 'Starting your first business on a small budget',
    );
    engine.speakingNow = {repo.hostRoom!.host.id};
    repo.seatState = repo.seatState!.copyWith(
      handsUp: ['v1', 'v2'],
      pendingRequests: 2,
      seats: [
        LiveSeat(
          index: 1,
          state: LiveSeatState.taken,
          user: _u('u1', ar ? 'عمر' : 'Omar'),
          mutedByHost: true,
          points: 980,
        ),
        LiveSeat(
          index: 2,
          state: LiveSeatState.taken,
          user: _u('u2', ar ? 'سارة' : 'Sara'),
          points: 410,
        ),
        LiveSeat(
          index: 3,
          state: LiveSeatState.taken,
          user: _u('u3', ar ? 'مازن' : 'Mazen'),
          demoteAt: _now.add(const Duration(seconds: 80)),
        ),
      ],
    );
    container.invalidate(liveSeatsProvider('room-host'));
    await tester.pump();
    await tester.pump();
  }
  await tester.pump();
  await precacheImages(tester);
  return (repo, engine, container);
}

void main() {
  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;

    _testGolden('podcast setup ($language)', (tester) async {
      await _host(tester, language: language, onAir: false);
      await tester.enterText(
        find.byType(EditableText).first,
        ar ? 'كيف تبدأ مشروعك الأول؟' : 'Your first business',
      );
      await tester.pump();
      await expectScreenGolden('podcast.setup', language: language);
      await _capture(tester, 'setup.${language.name}@3x');
    });

    for (final viewport in GoldenViewport.values) {
      _testGolden('podcast host on air ($language, ${viewport.name})', (
        tester,
      ) async {
        final (_, engine, _) = await _host(
          tester,
          language: language,
          onAir: true,
          viewport: viewport,
        );
        // Joins as lines; then a message (the rules line goes).
        engine.chat
          ..add(
            LiveChatJoined(
              _u('j1', ar ? 'جود' : 'Joud'),
              gender: LiveJoinGender.male,
            ),
          )
          ..add(LiveChatJoined(_u('j2', ar ? 'كريم' : 'Karim')))
          ..add(
            LiveChatReceived(
              LiveChatEntry(
                id: 'm1',
                roomId: 'room-host',
                author: _u('v1', ar ? 'نور' : 'Noor'),
                authorRole: LiveChatRole.viewer,
                text: ar ? 'كيف أختار الشريك المناسب؟ 🙏' : 'How to pick? 🙏',
                createdAt: DateTime.utc(2026, 10, 31, 18),
              ),
            ),
          )
          ..add(
            LiveChatJoined(
              _u('j3', ar ? 'دانة' : 'Dana'),
              gender: LiveJoinGender.female,
            ),
          );
        await tester.pump();
        await tester.pump();
        await expectScreenGolden(
          'podcast.host_live',
          language: language,
          viewport: viewport,
        );
        await _capture(
          tester,
          'host_room.${language.name}.${viewport.name}@3x',
        );
      });
    }

    // The approved mockup was drawn over the audio room's golden (no status
    // bar insets, the classic background): the same frame for comparing.
    _testGolden('podcast host, mockup frame ($language)', (tester) async {
      final (_, engine, _) = await _host(
        tester,
        language: language,
        onAir: true,
        theme: LiveThemes.classic,
        insets: false,
      );
      engine.chat
        ..add(
          LiveChatJoined(
            _u('j1', ar ? 'جود' : 'Joud'),
            gender: LiveJoinGender.male,
          ),
        )
        ..add(
          LiveChatJoined(
            _u('j2', ar ? 'كريم' : 'Karim'),
            gender: LiveJoinGender.male,
          ),
        )
        ..add(
          LiveChatReceived(
            LiveChatEntry(
              id: 'm1',
              roomId: 'room-host',
              author: _u('v1', ar ? 'نور' : 'Noor'),
              authorRole: LiveChatRole.viewer,
              text: ar ? 'كيف أختار الشريك المناسب؟' : 'How do I pick?',
              createdAt: DateTime.utc(2026, 10, 31, 18),
            ),
          ),
        )
        ..add(
          LiveChatJoined(
            _u('j3', ar ? 'دانة' : 'Dana'),
            gender: LiveJoinGender.female,
          ),
        );
      await tester.pump();
      await tester.pump();
      await expectScreenGolden('podcast.mockup_frame', language: language);
      await _capture(tester, 'mockup_frame.${language.name}@3x');
    });

    _testGolden('podcast host: the hands sheet ($language)', (tester) async {
      final (repo, _, container) = await _host(
        tester,
        language: language,
        onAir: true,
      );
      // One speaker seat free (the mockup's «مقعد واحد متاح»).
      repo.seatState = repo.seatState!.copyWith(
        seats: [
          ...repo.seatState!.seats.where((s) => s.index != 3),
          const LiveSeat(index: 3, state: LiveSeatState.empty, user: null),
        ],
      );
      container.invalidate(liveSeatsProvider('room-host'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(PodcastHandButton.buttonKey));
      await tester.pumpAndSettle();
      await expectScreenGolden('podcast.hands_sheet', language: language);
      await _capture(tester, 'host_hands_sheet.${language.name}@3x');
    });

    Future<void> hub(WidgetTester tester, {required bool podcast}) async {
      final live =
          FakeLiveRepository(
              rooms: (r) => apiPage(
                r.kind == LiveRoomsKind.podcast
                    ? [
                        for (final (i, t) in [
                          (
                            0,
                            ar
                                ? 'كيف تبدأ مشروعك الأول برأس مال صغير؟'
                                : 'Your first business',
                          ),
                          (
                            1,
                            ar
                                ? 'التقنية في حياتنا اليومية'
                                : 'Tech in daily life',
                          ),
                        ])
                          apiRooms(1, start: i, ar: ar).first.copyWith(
                            title: t,
                            mode: LiveRoomMode.podcast,
                            seatCount: 4,
                            viewerCount: i == 0 ? 1200 : 86,
                            podcast: LivePodcast(
                              episodeNumber: i == 0 ? 12 : 3,
                              topic: i == 0
                                  ? PodcastTopic.business
                                  : PodcastTopic.tech,
                              speakers: [
                                LivePodcastSpeaker(
                                  id: 'u1',
                                  username: 'u1',
                                  displayName: ar ? 'عمر' : 'Omar',
                                ),
                                LivePodcastSpeaker(
                                  id: 'u2',
                                  username: 'u2',
                                  displayName: ar ? 'سارة' : 'Sara',
                                ),
                              ],
                            ),
                          ),
                      ]
                    : apiRooms(6, ar: ar),
              ),
            )
            ..scheduled = [
              LiveScheduledPodcast(
                id: 'slot-1',
                title: ar ? 'الحلقة القادمة: التسويق' : 'Next: marketing',
                startsAt: DateTime.utc(2026, 11, 2, 18),
                podcastTopic: PodcastTopic.business,
                host: _u('h9', ar ? 'ليلى' : 'Layla'),
              ),
            ];
      setViewport(tester, GoldenViewport.phone);
      _phoneInsets(tester, GoldenViewport.phone);
      await loadAppFonts();
      await pumpKabsoApp(
        tester,
        language: language.name,
        liveRepository: live,
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
      if (podcast) {
        await _tapTab(tester, LiveHubCategory.podcast);
        await tester.pumpAndSettle();
      }
      await precacheImages(tester);
    }

    for (final theme in ['podcast-studio', LiveThemes.classic]) {
      _testGolden('listener room ($language, $theme)', (tester) async {
        final live =
            FakeLiveRepository(
                rooms: (_) => apiPage([
                  apiRooms(1, ar: ar).first.copyWith(
                    mode: LiveRoomMode.podcast,
                    seatCount: 4,
                    viewerCount: 1200,
                    podcast: const LivePodcast(
                      episodeNumber: 12,
                      topic: PodcastTopic.business,
                    ),
                  ),
                ]),
                room: (id) => apiRoom(id: id, ar: ar).copyWith(
                  title: ar
                      ? 'كيف تبدأ مشروعك الأول برأس مال صغير؟'
                      : 'Starting your first business on a small budget',
                  mode: LiveRoomMode.podcast,
                  seatCount: 4,
                  viewerCount: 1200,
                  theme: theme,
                  podcast: const LivePodcast(
                    episodeNumber: 12,
                    topic: PodcastTopic.business,
                  ),
                ),
              )
              ..viewerList = _viewers(ar)
              ..seatState = LiveSeats(
                roomId: 'room-0',
                mode: LiveRoomMode.podcast,
                version: 1,
                seatCount: 4,
                seats: [
                  LiveSeat(
                    index: 1,
                    state: LiveSeatState.taken,
                    user: _u('u1', ar ? 'عمر' : 'Omar'),
                    mutedByHost: true,
                    points: 980,
                  ),
                  LiveSeat(
                    index: 2,
                    state: LiveSeatState.taken,
                    user: _u('u2', ar ? 'سارة' : 'Sara'),
                    points: 410,
                  ),
                  LiveSeat(
                    index: 3,
                    state: LiveSeatState.taken,
                    user: _u('u3', ar ? 'مازن' : 'Mazen'),
                    demoteAt: _now.add(const Duration(seconds: 80)),
                  ),
                ],
                moderators: const [],
                handsUp: const ['v1', 'v2'],
                mine: const LiveSeatsMine(
                  role: LiveSeatRole.viewer,
                  seatIndex: null,
                  request: null,
                  invite: null,
                ),
              );
        final engine = FakeLiveMediaEngine()
          ..present.add('user-0')
          ..speakingNow = {'user-0'};
        setViewport(tester, GoldenViewport.phone);
        _phoneInsets(tester, GoldenViewport.phone);
        await loadAppFonts();
        await pumpKabsoApp(
          tester,
          language: language.name,
          liveRepository: live,
          liveMediaEngine: engine,
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(storedUser: testUser(), me: testUser()),
            ),
            secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(apiProfile(ar: ar)),
            ),
          ],
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('nav.home')));
        await tester.pumpAndSettle();
        await _tapTab(tester, LiveHubCategory.podcast);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(PodcastHubList.cardKey('room-0')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        engine.chat
          ..add(
            LiveChatJoined(
              _u('j1', ar ? 'جود' : 'Joud'),
              gender: LiveJoinGender.male,
            ),
          )
          ..add(
            LiveChatJoined(
              _u('j2', ar ? 'كريم' : 'Karim'),
              gender: LiveJoinGender.male,
            ),
          )
          ..add(
            LiveChatReceived(
              LiveChatEntry(
                id: 'm1',
                roomId: 'room-0',
                author: _u('v1', ar ? 'نور' : 'Noor'),
                authorRole: LiveChatRole.viewer,
                text: ar ? 'كيف أختار الشريك المناسب؟ 🙏' : 'How to pick? 🙏',
                createdAt: DateTime.utc(2026, 10, 31, 18),
              ),
            ),
          )
          ..add(
            LiveChatJoined(
              _u('j3', ar ? 'دانة' : 'Dana'),
              gender: LiveJoinGender.female,
            ),
          );
        await tester.pump();
        await tester.pump();
        await precacheImages(tester);
        await _capture(tester, 'listener_room.${language.name}.$theme@3x');
        expect(find.byKey(PodcastStage.stageKey), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 12));
      });
    }

    _testGolden('hub: no category row, every card names its kind (D237) '
        '($language)', (tester) async {
      await hub(tester, podcast: false);
      await _capture(tester, 'hub_categories.${language.name}@3x');
      expect(find.byType(LiveHubCategoryBar), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 12));
    });

    _testGolden('hub: podcast cards ($language)', (tester) async {
      await hub(tester, podcast: true);
      await _capture(tester, 'hub_podcasts.${language.name}@3x');
      expect(find.byType(PodcastHubCard), findsNWidgets(2));
      expect(find.byType(ScheduledPodcastCard), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 12));
    });
  });
}

/// D237: a live category is a kind tab of the party page (the hub's party
/// button).
Future<void> _tapTab(WidgetTester tester, LiveHubCategory category) async {
  await tester.tap(find.byKey(LiveHubPartyButton.buttonKey));
  await tester.pumpAndSettle();
  // D240: the kinds are the party page's top tabs.
  final tab = find.byKey(VoiceRoomsScreen.kindKey(category));
  await tester.ensureVisible(tab);
  await tester.pumpAndSettle();
  await tester.tap(tab);
}
