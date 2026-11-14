import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_sheets.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_video_podcast_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_video_podcast_stage.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_video_podcast_studio.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/pump_app.dart';

/// D363 scope extension (owner 2026-11-11, §10.157): the video podcast's
/// studio — backstage (the host's strip, the guest's self-check), the
/// host's manual control with «تلقائي», the segments (progress bar, card,
/// «الفقرة التالية», the closing card) and the listener question on screen;
/// the audio podcast is untouched.
void main() {
  const host = VideoPodcastPerson(userId: 'h', name: 'Layla', host: true);
  const omar = VideoPodcastPerson(userId: 'u1', name: 'Omar');
  const sara = VideoPodcastPerson(userId: 'u2', name: 'Sara');
  final people = {
    for (final p in [host, omar, sara]) p.userId: p,
  };
  final t0 = DateTime.utc(2026, 11, 11, 20);
  UserSummary u(String id, String name) =>
      UserSummary(id: id, username: id, displayName: name, avatarUrl: null);
  const segments = [
    LivePodcastSegment(title: 'Intro'),
    LivePodcastSegment(title: 'Guests talk', minutes: 20),
    LivePodcastSegment(title: 'Questions'),
  ];

  Widget stage({
    LivePodcastStudio? studio,
    VoidCallback? onAuto,
    VoidCallback? onNext,
    VoidCallback? onHide,
    List<VideoPodcastBackstageGuest> backstage = const [],
    ValueChanged<VideoPodcastBackstageGuest>? onAir,
  }) => VideoPodcastStage(
    shot: const PodcastDirectorShot(
      kind: PodcastShotKind.speaker,
      userIds: ['h', 'u1', 'u2'],
    ),
    people: people,
    videoOf: (id) => VideoPodcastPlaceholderFrame(seed: id.hashCode),
    studio: studio,
    onAuto: onAuto,
    onNextSegment: onNext,
    onHideQuestion: onHide,
    backstage: backstage,
    onBringOnAir: onAir,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    AppLanguage language = AppLanguage.en,
  }) => withClock(
    Clock.fixed(t0),
    () => pumpScreen(tester, Scaffold(body: child), language: language),
  );

  group('manual control', () {
    testWidgets('a pin shows «Pinned: Omar»; the host’s «Auto» gives it back', (
      tester,
    ) async {
      var auto = 0;
      await pump(
        tester,
        stage(
          studio: const LivePodcastStudio(seq: 1, pinUserId: 'u1'),
          onAuto: () => auto++,
        ),
      );
      expect(find.text('Pinned: Omar'), findsOneWidget);
      await tester.tap(find.byKey(VideoPodcastStudioKeys.auto));
      expect(auto, 1);
    });

    testWidgets('a locked layout reads «Locked: Discussion»; viewers get no '
        '«Auto»', (tester) async {
      await pump(
        tester,
        stage(
          studio: const LivePodcastStudio(
            seq: 2,
            layout: PodcastShotKind.split,
          ),
        ),
      );
      expect(find.text('Locked: Discussion'), findsOneWidget);
      expect(find.byKey(VideoPodcastStudioKeys.auto), findsNothing);
    });

    testWidgets('«تلقائي» (no control): no chip', (tester) async {
      await pump(tester, stage(studio: const LivePodcastStudio(seq: 3)));
      expect(find.byKey(VideoPodcastStudioKeys.controlChip), findsNothing);
    });
  });

  group('segments', () {
    testWidgets('the bar, the card for 5 s after a start, «Next segment»', (
      tester,
    ) async {
      var next = 0;
      await pump(
        tester,
        stage(
          studio: LivePodcastStudio(
            seq: 4,
            segments: segments,
            segmentIndex: 1,
            segmentStartedAt: t0.subtract(const Duration(seconds: 2)),
          ),
          onNext: () => next++,
        ),
      );
      expect(find.byKey(VideoPodcastStudioKeys.progress), findsOneWidget);
      expect(find.byKey(VideoPodcastStudioKeys.segmentCard), findsOneWidget);
      expect(find.text('Segment 2 of 3'), findsOneWidget);
      expect(find.text('Guests talk'), findsOneWidget);
      expect(find.text('20 min'), findsOneWidget);
      await tester.tap(find.byKey(VideoPodcastStudioKeys.nextSegment));
      expect(next, 1);
    });

    testWidgets('no card long after the start; «Start segments» before the '
        'first', (tester) async {
      await pump(
        tester,
        stage(
          studio: LivePodcastStudio(
            seq: 5,
            segments: segments,
            segmentIndex: 0,
            segmentStartedAt: t0.subtract(const Duration(minutes: 3)),
          ),
          onNext: () {},
        ),
      );
      expect(find.byKey(VideoPodcastStudioKeys.segmentCard), findsNothing);
      expect(find.text('Next segment'), findsOneWidget);
      await pump(
        tester,
        stage(
          studio: const LivePodcastStudio(seq: 6, segments: segments),
          onNext: () {},
        ),
      );
      expect(find.text('Start segments'), findsOneWidget);
    });

    testWidgets('the closing card; no «Next segment» any more', (tester) async {
      await pump(
        tester,
        stage(
          studio: LivePodcastStudio(
            seq: 7,
            segments: segments,
            segmentIndex: 2,
            segmentStartedAt: t0,
            closing: true,
          ),
          onNext: () {},
        ),
      );
      expect(find.byKey(VideoPodcastStudioKeys.closingCard), findsOneWidget);
      expect(find.text('End of the episode'), findsOneWidget);
      expect(find.byKey(VideoPodcastStudioKeys.segmentCard), findsNothing);
      expect(find.byKey(VideoPodcastStudioKeys.nextSegment), findsNothing);
    });
  });

  testWidgets('the question on screen: tag, asker, question; the host hides '
      'it', (tester) async {
    var hidden = 0;
    await pump(
      tester,
      stage(
        studio: LivePodcastStudio(
          seq: 8,
          onScreen: LivePodcastOnScreen(
            requestId: 'r1',
            user: u('noor', 'Noor'),
            question: 'Will AI replace us?',
            answerUserId: 'u1',
          ),
        ),
        onHide: () => hidden++,
      ),
    );
    expect(find.byKey(VideoPodcastStudioKeys.questionCard), findsOneWidget);
    expect(find.text('Audience question'), findsOneWidget);
    expect(find.text('Noor'), findsOneWidget);
    expect(find.text('Will AI replace us?'), findsOneWidget);
    await tester.tap(find.byKey(VideoPodcastStudioKeys.hideQuestion));
    expect(hidden, 1);
  });

  testWidgets('the host’s backstage strip: the guest and «On air»', (
    tester,
  ) async {
    final onAir = <int>[];
    await pump(
      tester,
      stage(
        backstage: const [
          VideoPodcastBackstageGuest(userId: 'u3', name: 'Huda', seatIndex: 3),
        ],
        onAir: (g) => onAir.add(g.seatIndex),
      ),
    );
    expect(find.byKey(VideoPodcastStudioKeys.backstageStrip), findsOneWidget);
    expect(find.text('Backstage'), findsOneWidget);
    expect(find.text('Huda'), findsOneWidget);
    await tester.tap(find.byKey(VideoPodcastStudioKeys.onAir('u3')));
    expect(onAir, [3]);
  });

  testWidgets('the guest’s self-check: preview or camera off, the mic, leave', (
    tester,
  ) async {
    var left = 0;
    await pump(
      tester,
      VideoPodcastBackstageCheck(
        preview: const VideoPodcastPlaceholderFrame(seed: 2),
        speaking: true,
        name: 'Huda',
        onLeave: () => left++,
      ),
    );
    expect(find.text("You're backstage"), findsOneWidget);
    expect(find.text('Your microphone works'), findsOneWidget);
    expect(find.byType(VideoPodcastPlaceholderFrame), findsOneWidget);
    await tester.tap(find.byKey(VideoPodcastStudioKeys.leaveBackstage));
    expect(left, 1);
    await pump(
      tester,
      const VideoPodcastBackstageCheck(
        preview: null,
        speaking: false,
        name: 'Huda',
      ),
    );
    expect(find.text('Camera off'), findsOneWidget);
    expect(find.text('Say something to test your microphone'), findsOneWidget);
  });

  group('sheets', () {
    testWidgets('hands: «Show on screen» on a question only', (tester) async {
      final shown = <String>[];
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPodcastHandsSheet(
              context,
              load: () async => [
                LiveSeatRequest(
                  id: 'r1',
                  user: u('ann', 'Ann'),
                  seatIndex: null,
                  createdAt: t0,
                  question: 'Why?',
                ),
                LiveSeatRequest(
                  id: 'r2',
                  user: u('bob', 'Bob'),
                  seatIndex: null,
                  createdAt: t0,
                ),
              ],
              freeSeats: 1,
              podcast: const LivePodcast(
                episodeNumber: 1,
                topic: PodcastTopic.tech,
                video: true,
              ),
              config: const LivePodcastConfig(),
              onBringUp: (_) async {},
              onLater: (_) async {},
              onShowOnScreen: (r) async => shown.add(r.id),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(PodcastHandsSheet.onScreenKey('r2')), findsNothing);
      await tester.tap(find.byKey(PodcastHandsSheet.onScreenKey('r1')));
      await tester.pumpAndSettle();
      expect(shown, ['r1']);
    });

    testWidgets('the director: pin, layout, «Auto»', (tester) async {
      ({String? pin, PodcastShotKind? layout})? choice;
      Future<void> open({String? pin, PodcastShotKind? layout}) async {
        await pump(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => choice = await showPodcastDirectorSheet(
                context,
                people: [(id: 'h', name: 'Layla'), (id: 'u1', name: 'Omar')],
                pin: pin,
                layout: layout,
              ),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
      }

      await open();
      // No hot seat now: no HOT_SEAT layout.
      expect(
        find.byKey(PodcastDirectorSheet.layoutKey(PodcastShotKind.hotSeat)),
        findsNothing,
      );
      await tester.tap(find.byKey(PodcastDirectorSheet.optionKey('u1')));
      await tester.pumpAndSettle();
      expect(choice, (pin: 'u1', layout: null));
      await open(pin: 'u1');
      await tester.tap(
        find.byKey(PodcastDirectorSheet.layoutKey(PodcastShotKind.split)),
      );
      await tester.pumpAndSettle();
      expect(choice, (pin: 'u1', layout: PodcastShotKind.split));
      await open(pin: 'u1', layout: PodcastShotKind.split);
      await tester.tap(find.byKey(PodcastDirectorSheet.optionKey(null)));
      await tester.pumpAndSettle();
      expect(choice, (pin: null, layout: null));
    });

    testWidgets('the segments editor: add, edit, remove, save', (tester) async {
      List<LivePodcastSegment>? saved;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => saved = await showPodcastSegmentsSheet(
              context,
              segments: const [LivePodcastSegment(title: 'Intro')],
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(PodcastSegmentsSheet.addKey));
      await tester.pump();
      await tester.enterText(
        find.byKey(PodcastSegmentsSheet.titleKey(1)),
        '  Talk  ',
      );
      await tester.enterText(
        find.byKey(PodcastSegmentsSheet.minutesKey(1)),
        '15',
      );
      await tester.tap(find.byKey(PodcastSegmentsSheet.addKey));
      await tester.pump();
      await tester.enterText(find.byKey(PodcastSegmentsSheet.titleKey(2)), 'X');
      await tester.tap(find.byKey(PodcastSegmentsSheet.removeKey(2)));
      await tester.pump();
      await tester.tap(find.byKey(PodcastSegmentsSheet.saveKey));
      await tester.pumpAndSettle();
      expect(saved, const [
        LivePodcastSegment(title: 'Intro'),
        LivePodcastSegment(title: 'Talk', minutes: 15),
      ]);
    });
  });

  group('the room stage', () {
    late FakeLiveRepository repo;
    late FakeLiveMediaEngine engine;

    LiveSeats seats({LivePodcastStudio? studio, bool backstage = true}) =>
        LiveSeats(
          roomId: 'room-1',
          mode: LiveRoomMode.podcast,
          version: 3,
          seatCount: 4,
          seats: [
            LiveSeat(
              index: 1,
              state: LiveSeatState.taken,
              user: u('u1', 'Omar'),
            ),
            LiveSeat(
              index: 2,
              state: LiveSeatState.taken,
              user: u('u2', 'Sara'),
              backstage: backstage,
            ),
            const LiveSeat(index: 3, state: LiveSeatState.empty, user: null),
          ],
          moderators: const [],
          studio: studio,
        );

    Future<void> pumpRoom(
      WidgetTester tester, {
      required LiveSeats liveSeats,
      bool isHost = true,
      ValueChanged<int>? onBringOnAir,
    }) async {
      repo = FakeLiveRepository();
      engine = FakeLiveMediaEngine()..present.addAll(['u1', 'u2']);
      await pumpScreen(
        tester,
        Scaffold(
          body: VideoPodcastRoomStage(
            roomId: 'room-1',
            host: u('h', 'Layla'),
            seats: liveSeats,
            engine: engine,
            me: isHost ? 'h' : 'viewer',
            isHost: isHost,
            onBringOnAir: onBringOnAir,
          ),
        ),
        overrides: [liveRepositoryProvider.overrideWithValue(repo)],
      );
    }

    testWidgets('a backstage guest is on the host’s strip, not on the stage; '
        '«On air» names the seat', (tester) async {
      final onAir = <int>[];
      await pumpRoom(tester, liveSeats: seats(), onBringOnAir: onAir.add);
      expect(find.byKey(VideoPodcastStage.thumbKey('u1')), findsOneWidget);
      expect(find.byKey(VideoPodcastStage.thumbKey('u2')), findsNothing);
      expect(find.byKey(VideoPodcastStage.frameKey('u2')), findsNothing);
      expect(find.byKey(VideoPodcastStudioKeys.backstageStrip), findsOneWidget);
      await tester.tap(find.byKey(VideoPodcastStudioKeys.onAir('u2')));
      expect(onAir, [2]);
      // The director's relays never name her.
      expect(
        repo.directorShots.expand((s) => s.userIds),
        isNot(contains('u2')),
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('viewers see no backstage strip', (tester) async {
      await pumpRoom(tester, liveSeats: seats(), isHost: false);
      expect(find.byKey(VideoPodcastStudioKeys.backstageStrip), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the host’s pin from the seats is relayed; «Auto» asks the '
        'server and follows its answer', (tester) async {
      await pumpRoom(
        tester,
        liveSeats: seats(
          studio: const LivePodcastStudio(seq: 2, pinUserId: 'u1'),
          backstage: false,
        ),
      );
      expect(repo.directorShots.last.main, 'u1');
      expect(repo.directorShots.last.locked, isTrue);
      await tester.tap(find.byKey(VideoPodcastStudioKeys.auto));
      await tester.pump();
      expect(repo.studioCalls, ['control::']);
      // The fake server's answer (seq 1) is older than the seats' (seq 2):
      // dropped; a newer `studio` message clears the pin.
      engine.podcast.add(const PodcastStudioEvent(LivePodcastStudio(seq: 3)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(repo.directorShots.last.locked, isFalse);
      expect(find.byKey(VideoPodcastStudioKeys.controlChip), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a question on screen moves the shot to the answering guest', (
      tester,
    ) async {
      await pumpRoom(
        tester,
        liveSeats: seats(
          backstage: false,
          studio: LivePodcastStudio(
            seq: 1,
            onScreen: LivePodcastOnScreen(
              requestId: 'r1',
              user: u('noor', 'Noor'),
              question: 'Why?',
              answerUserId: 'u2',
            ),
          ),
        ),
      );
      expect(repo.directorShots.last.main, 'u2');
      expect(find.byKey(VideoPodcastStudioKeys.questionCard), findsOneWidget);
      await tester.tap(find.byKey(VideoPodcastStudioKeys.hideQuestion));
      await tester.pump();
      expect(repo.studioCalls, ['hide']);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
