// D363 goldens (§10.157): the video podcast «بودكاست فيديو» — the host on
// air with the director's speaker shot (and the guest's lower third), the
// split, the hot seat, the go-live «صوت / فيديو» choice and the hub's video
// badges; the scope extension (owner 2026-11-11): the backstage strip and
// the guest's self-check, the pinned / locked shot with «تلقائي», the
// segment card with the progress bar, the closing card and the audience
// question on screen — ar and en, at 393 × 852 with the phone's insets (59 / 34) and a
// pinned clock. Every "video" is a neutral placeholder frame (D40: no real
// people, no third-party pictures); names are fixtures.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/video_podcast_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_audio_setup.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_mini_window.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_video_podcast_stage.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_video_podcast_studio.dart';
import 'package:kabso_live/features/live/presentation/hub/podcast_hub.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_type_tag.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_live_media_engine.dart';
import '../helpers/fake_live_pk.dart';
import '../helpers/fake_live_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

/// The goldens' clock: 19:18:42 UTC, moved by [_advance] (the director's
/// 2.5 s hold is measured on it).
DateTime _now = DateTime.utc(2026, 10, 16, 19, 18, 42);
void _advance(double seconds) =>
    _now = _now.add(Duration(milliseconds: (seconds * 1000).round()));

void _testGolden(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(name, (tester) {
      _now = DateTime.utc(2026, 10, 16, 19, 18, 42);
      return withClock(Clock(() => _now), () => body(tester));
    });

UserSummary _u(String id, String name) =>
    UserSummary(id: id, username: id, displayName: name, avatarUrl: null);

void _phoneInsets(WidgetTester tester) {
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

/// The neutral "video" of each person (the host's preview is seed 0).
Widget _frame(String? id) => VideoPodcastPlaceholderFrame(
  seed: switch (id) {
    null => 0,
    'u1' => 1,
    'u2' => 2,
    'u3' => 3,
    _ => 4,
  },
);

/// D363 scope extension: the episode's four segments.
List<LivePodcastSegment> _segments(bool ar) => [
  LivePodcastSegment(title: ar ? 'مقدمة الحلقة' : 'Opening'),
  LivePodcastSegment(
    title: ar ? 'الذكاء الاصطناعي والعمل' : 'AI and work',
    minutes: 20,
  ),
  LivePodcastSegment(title: ar ? 'أسئلة الجمهور' : 'Audience questions'),
  LivePodcastSegment(title: ar ? 'الخلاصة' : 'Wrap-up'),
];

typedef _Host = ({
  FakeLiveRepository repo,
  FakeLiveMediaEngine engine,
  ProviderContainer container,
  String hostId,
});

/// The host's screen in a video podcast: the setup, or on air with two
/// guests (Omar with a title) and, for [hotSeat], a listener in the hot
/// seat.
Future<_Host> _host(
  WidgetTester tester, {
  required AppLanguage language,
  required bool onAir,
  bool hotSeat = false,
  bool backstage = false,
  LivePodcastStudio Function({required bool ar})? studio,
}) async {
  final ar = language == AppLanguage.ar;
  final repo = FakeLiveRepository()..podcastEpisode = 7;
  late FakeLiveMediaEngine engine;
  final prefs = await testPrefs(language: language.name);
  _phoneInsets(tester);
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        liveRepositoryProvider.overrideWithValue(repo),
        ...pkTestOverrides(),
        liveMediaEngineProvider.overrideWithValue(
          () => engine = FakeLiveMediaEngine()..videoBuilder = _frame,
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
    bare: true,
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(LiveMiniWindow)),
  );
  final keep = container.listen(liveHostControllerProvider, (_, _) {});
  addTearDown(keep.close);
  final host = container.read(liveHostControllerProvider.notifier);
  await host.setMode(LiveRoomMode.podcast);
  await host.setTheme('podcast-studio');
  host.setPodcastSetup(
    const PodcastSetup(topic: PodcastTopic.tech, video: true),
  );
  // The camera preview (a video podcast's host is on camera).
  await host.startPreview();
  await tester.pump();
  if (onAir) {
    await host.goLive(
      title: ar ? 'مستقبل الذكاء الاصطناعي' : 'The future of AI',
    );
    engine.present.addAll(['u1', 'u2', 'u3', 'u4']);
    repo.seatState = repo.seatState!.copyWith(
      // D363 scope extension: the studio everyone reads.
      studio: studio?.call(ar: ar),
      seats: [
        LiveSeat(
          index: 1,
          state: LiveSeatState.taken,
          user: _u('u1', ar ? 'عمر' : 'Omar'),
          guestTitle: ar ? 'باحث في التقنية' : 'Tech researcher',
        ),
        LiveSeat(
          index: 2,
          state: LiveSeatState.taken,
          user: _u('u2', ar ? 'سارة' : 'Sara'),
        ),
        if (hotSeat)
          LiveSeat(
            index: 3,
            state: LiveSeatState.taken,
            user: _u('u3', ar ? 'نور' : 'Noor'),
            demoteAt: _now.add(const Duration(seconds: 42)),
            hotSeat: LivePodcastHotSeat(
              requestId: 'r1',
              question: ar
                  ? 'هل سيأخذ الذكاء الاصطناعي وظائف المبرمجين؟'
                  : 'Will AI take programmers’ jobs?',
              votes: 128,
            ),
          ),
        // D363 scope extension: an accepted guest waiting backstage.
        if (backstage)
          LiveSeat(
            index: 3,
            state: LiveSeatState.taken,
            user: _u('u4', ar ? 'هدى' : 'Huda'),
            guestTitle: ar ? 'طبيبة' : 'Doctor',
            backstage: true,
          ),
      ],
    );
    container.invalidate(liveSeatsProvider('room-host'));
    await tester.pump();
    await tester.pump();
  }
  await tester.pump();
  await precacheImages(tester);
  return (
    repo: repo,
    engine: engine,
    container: container,
    hostId: container.read(liveHostControllerProvider).room?.host.id ?? '',
  );
}

/// The media server says [ids] speak now; the stage's director hears it.
Future<void> _speak(
  WidgetTester tester,
  FakeLiveMediaEngine engine,
  Set<String> ids,
) async {
  engine
    ..speakingNow = ids
    ..ping();
  await tester.pump();
}

void main() {
  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;

    _testGolden('video podcast setup: «صوت / فيديو» ($language)', (
      tester,
    ) async {
      await _host(tester, language: language, onAir: false);
      await tester.enterText(
        find.byType(EditableText).first,
        ar ? 'مستقبل الذكاء الاصطناعي' : 'The future of AI',
      );
      await tester.pump();
      expect(find.byKey(GoLiveAudioSetup.videoFormatKey), findsOneWidget);
      await expectScreenGolden('video_podcast.setup', language: language);
    });

    _testGolden('video podcast speaker shot ($language)', (tester) async {
      final h = await _host(tester, language: language, onAir: true);
      await _speak(tester, h.engine, {'u1'});
      expect(find.byKey(VideoPodcastStage.lowerThirdKey), findsOneWidget);
      expect(find.byKey(VideoPodcastStage.thumbKey(h.hostId)), findsOneWidget);
      await expectScreenGolden('video_podcast.speaker', language: language);
      // The relay: the host's app sent the shot to the room.
      expect(h.repo.directorShots.last.kind, PodcastShotKind.speaker);
      expect(h.repo.directorShots.last.main, 'u1');
    });

    _testGolden('video podcast split ($language)', (tester) async {
      final h = await _host(tester, language: language, onAir: true);
      await _speak(tester, h.engine, {'u1'});
      _advance(2.6);
      await _speak(tester, h.engine, {h.hostId});
      _advance(2.6);
      await _speak(tester, h.engine, {'u1'});
      expect(h.repo.directorShots.last.kind, PodcastShotKind.split);
      await expectScreenGolden('video_podcast.split', language: language);
    });

    _testGolden('video podcast hot seat ($language)', (tester) async {
      final h = await _host(
        tester,
        language: language,
        onAir: true,
        hotSeat: true,
      );
      expect(find.byKey(VideoPodcastStage.hotSeatKey), findsOneWidget);
      expect(h.repo.directorShots.last.kind, PodcastShotKind.hotSeat);
      await expectScreenGolden('video_podcast.hot_seat', language: language);
    });

    // ---- D363 scope extension (owner 2026-11-11) ------------------------

    _testGolden('video podcast backstage strip ($language)', (tester) async {
      final h = await _host(
        tester,
        language: language,
        onAir: true,
        backstage: true,
      );
      await _speak(tester, h.engine, {'u1'});
      expect(find.byKey(VideoPodcastStudioKeys.backstageStrip), findsOneWidget);
      expect(find.byKey(VideoPodcastStage.thumbKey('u4')), findsNothing);
      await expectScreenGolden('video_podcast.backstage', language: language);
      expect(
        h.repo.directorShots.expand((s) => s.userIds),
        isNot(contains('u4')),
      );
    });

    _testGolden('video podcast backstage self-check ($language)', (
      tester,
    ) async {
      _phoneInsets(tester);
      await pumpGolden(
        tester,
        Stack(
          fit: StackFit.expand,
          children: [
            // The room behind: the host on the director's shot.
            VideoPodcastStage(
              shot: const PodcastDirectorShot(
                kind: PodcastShotKind.speaker,
                userIds: ['h'],
              ),
              people: {
                'h': VideoPodcastPerson(
                  userId: 'h',
                  name: ar ? 'ليلى' : 'Layla',
                  host: true,
                ),
              },
              videoOf: (_) => _frame(null),
            ),
            VideoPodcastBackstageCheck(
              preview: _frame('u4'),
              speaking: true,
              name: ar ? 'هدى' : 'Huda',
              onLeave: () {},
            ),
          ],
        ),
        language: language,
        bare: true,
      );
      await tester.pump();
      await expectScreenGolden('video_podcast.self_check', language: language);
    });

    _testGolden('video podcast pinned and locked, «تلقائي» ($language)', (
      tester,
    ) async {
      final h = await _host(
        tester,
        language: language,
        onAir: true,
        studio: ({required ar}) => const LivePodcastStudio(
          seq: 3,
          pinUserId: 'u1',
          layout: PodcastShotKind.split,
        ),
      );
      await _speak(tester, h.engine, {h.hostId});
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(VideoPodcastStudioKeys.auto), findsOneWidget);
      expect(h.repo.directorShots.last.kind, PodcastShotKind.split);
      expect(h.repo.directorShots.last.main, 'u1');
      expect(h.repo.directorShots.last.locked, isTrue);
      await expectScreenGolden('video_podcast.pinned', language: language);
    });

    _testGolden('video podcast segment card and progress ($language)', (
      tester,
    ) async {
      await _host(
        tester,
        language: language,
        onAir: true,
        studio: ({required ar}) => LivePodcastStudio(
          seq: 2,
          segments: _segments(ar),
          segmentIndex: 1,
          segmentStartedAt: _now.subtract(const Duration(seconds: 1)),
        ),
      );
      expect(find.byKey(VideoPodcastStudioKeys.segmentCard), findsOneWidget);
      expect(find.byKey(VideoPodcastStudioKeys.progress), findsOneWidget);
      expect(find.byKey(VideoPodcastStudioKeys.nextSegment), findsOneWidget);
      await expectScreenGolden('video_podcast.segment', language: language);
    });

    _testGolden('video podcast closing card ($language)', (tester) async {
      await _host(
        tester,
        language: language,
        onAir: true,
        studio: ({required ar}) => LivePodcastStudio(
          seq: 5,
          segments: _segments(ar),
          segmentIndex: 3,
          segmentStartedAt: _now.subtract(const Duration(minutes: 9)),
          closing: true,
        ),
      );
      expect(find.byKey(VideoPodcastStudioKeys.closingCard), findsOneWidget);
      await expectScreenGolden('video_podcast.closing', language: language);
    });

    _testGolden('video podcast audience question on screen ($language)', (
      tester,
    ) async {
      final h = await _host(
        tester,
        language: language,
        onAir: true,
        studio: ({required ar}) => LivePodcastStudio(
          seq: 4,
          onScreen: LivePodcastOnScreen(
            requestId: 'r9',
            user: _u('v9', ar ? 'خالد' : 'Khaled'),
            question: ar
                ? 'كيف أبدأ تعلّم الذكاء الاصطناعي من الصفر؟'
                : 'How do I start learning AI from scratch?',
            answerUserId: 'u2',
          ),
        ),
      );
      expect(find.byKey(VideoPodcastStudioKeys.questionCard), findsOneWidget);
      // The director prefers the answering guest.
      expect(h.repo.directorShots.last.main, 'u2');
      await expectScreenGolden('video_podcast.question', language: language);
    });

    _testGolden('video podcast hub badges ($language)', (tester) async {
      final host = _u('h1', ar ? 'ليلى' : 'Layla');
      await pumpGolden(
        tester,
        ProviderScope(
          overrides: [
            liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScheduledPodcastCard(
                episode: LiveScheduledPodcast(
                  id: 's1',
                  title: ar
                      ? 'حلقة فيديو عن التقنية'
                      : 'A video episode on tech',
                  startsAt: DateTime.utc(2026, 10, 17, 18),
                  podcastTopic: PodcastTopic.tech,
                  host: host,
                  video: true,
                ),
              ),
              const SizedBox(height: 12),
              ScheduledPodcastCard(
                episode: LiveScheduledPodcast(
                  id: 's2',
                  title: ar ? 'حلقة صوتية' : 'An audio episode',
                  startsAt: DateTime.utc(2026, 10, 18, 18),
                  podcastTopic: PodcastTopic.business,
                  host: host,
                ),
              ),
              const SizedBox(height: 12),
              const ColoredBox(
                color: Color(0xFF2A2833),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    children: [
                      LiveTypeTag(kind: LiveCardKind.podcast, video: true),
                      SizedBox(width: 16),
                      LiveTypeTag(kind: LiveCardKind.podcast),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        language: language,
      );
      await tester.pump();
      expect(
        find.byKey(ScheduledPodcastsSection.videoBadgeKey),
        findsOneWidget,
      );
      // D368 (owner: «ازل من بودكاست زر الكاميرة التي خلف التصنيف»): no
      // camera after a video podcast's tag (the scheduled episode's labelled
      // «فيديو» badge stays).
      for (final tag in tester.widgetList(find.byType(LiveTypeTag))) {
        expect(
          find.descendant(of: find.byWidget(tag), matching: find.byType(Icon)),
          findsNothing,
        );
      }
      await expectScreenGolden('video_podcast.hub_badges', language: language);
    });
  });
}
