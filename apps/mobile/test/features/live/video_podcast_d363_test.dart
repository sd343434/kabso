import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_podcast_sheets.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_video_podcast_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_video_podcast_stage.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/pump_app.dart';

/// D363 (§10.157): the video podcast's stage (shots, thumbnails, the viewer's
/// own pick, the lower third, the hot seat card, RTL), the listeners'
/// questions with upvotes and the host's hands sheet with the hot seat.
void main() {
  const host = VideoPodcastPerson(userId: 'h', name: 'Layla', host: true);
  const omar = VideoPodcastPerson(
    userId: 'u1',
    name: 'Omar',
    guestTitle: 'Tech researcher',
    speaking: true,
  );
  const sara = VideoPodcastPerson(userId: 'u2', name: 'Sara');
  final people = {
    for (final p in [host, omar, sara]) p.userId: p,
  };

  Widget stage(
    PodcastDirectorShot shot, {
    bool free = false,
    ValueChanged<String>? onThumbTap,
    VoidCallback? onBack,
    VideoPodcastHotSeat? hotSeat,
  }) => VideoPodcastStage(
    shot: shot,
    people: people,
    videoOf: (id) => VideoPodcastPlaceholderFrame(seed: id.hashCode),
    free: free,
    onThumbTap: onThumbTap,
    onBackToDirector: onBack,
    hotSeat: hotSeat,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    AppLanguage language = AppLanguage.en,
  }) => pumpScreen(tester, Scaffold(body: child), language: language);

  testWidgets('speaker shot: main frame, the others as thumbnails, the chip, '
      'the guest lower third', (tester) async {
    String? tapped;
    await pump(
      tester,
      stage(
        const PodcastDirectorShot(
          kind: PodcastShotKind.speaker,
          userIds: ['u1', 'h', 'u2'],
        ),
        onThumbTap: (id) => tapped = id,
      ),
    );
    expect(find.byKey(VideoPodcastStage.frameKey('u1')), findsOneWidget);
    expect(find.byKey(VideoPodcastStage.thumbKey('h')), findsOneWidget);
    expect(find.byKey(VideoPodcastStage.thumbKey('u2')), findsOneWidget);
    expect(find.text('Speaker shot'), findsOneWidget);
    expect(find.text('Guest: Omar — Tech researcher'), findsOneWidget);
    // The viewer's own pick.
    await tester.tap(find.byKey(VideoPodcastStage.thumbKey('u2')));
    expect(tapped, 'u2');
    // The lower third goes after 4 s.
    await tester.pump(const Duration(seconds: 5));
    expect(find.byKey(VideoPodcastStage.lowerThirdKey), findsNothing);
  });

  testWidgets('no lower third for the host', (tester) async {
    await pump(
      tester,
      stage(
        const PodcastDirectorShot(
          kind: PodcastShotKind.speaker,
          userIds: ['h', 'u1', 'u2'],
        ),
      ),
    );
    expect(find.byKey(VideoPodcastStage.lowerThirdKey), findsNothing);
  });

  testWidgets('split, grid and «رجوع للمخرج»', (tester) async {
    var back = 0;
    await pump(
      tester,
      stage(
        const PodcastDirectorShot(
          kind: PodcastShotKind.split,
          userIds: ['u1', 'h', 'u2'],
        ),
        free: true,
        onBack: () => back++,
      ),
    );
    expect(find.byKey(VideoPodcastStage.frameKey('u1')), findsOneWidget);
    expect(find.byKey(VideoPodcastStage.frameKey('h')), findsOneWidget);
    expect(find.byKey(VideoPodcastStage.thumbKey('u2')), findsOneWidget);
    expect(find.text('Discussion'), findsOneWidget);
    await tester.tap(find.byKey(VideoPodcastStage.backToDirectorKey));
    expect(back, 1);

    await pump(
      tester,
      stage(
        const PodcastDirectorShot(
          kind: PodcastShotKind.grid,
          userIds: ['h', 'u1', 'u2'],
        ),
      ),
    );
    // The cross-fade from the split ends.
    await tester.pump(const Duration(seconds: 1));
    for (final id in ['h', 'u1', 'u2']) {
      expect(find.byKey(VideoPodcastStage.frameKey(id)), findsOneWidget);
    }
    expect(find.byKey(VideoPodcastStage.backToDirectorKey), findsNothing);
    expect(find.text('Group talk'), findsOneWidget);
  });

  testWidgets('the hot seat card: question, votes, asker and timer', (
    tester,
  ) async {
    await pump(
      tester,
      stage(
        const PodcastDirectorShot(
          kind: PodcastShotKind.hotSeat,
          userIds: ['u2', 'h', 'u1'],
        ),
        hotSeat: VideoPodcastHotSeat(
          askerId: 'u2',
          question: 'Will AI take our jobs?',
          votes: 12,
          endsAt: DateTime.now().add(const Duration(seconds: 30)),
        ),
      ),
    );
    expect(find.byKey(VideoPodcastStage.hotSeatKey), findsOneWidget);
    expect(find.text('Will AI take our jobs?'), findsOneWidget);
    expect(find.text('Question from Sara'), findsOneWidget);
    expect(find.text('\u206612\u2069'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The host's picture is behind the card.
    expect(find.byKey(VideoPodcastStage.frameKey('h')), findsOneWidget);
  });

  testWidgets('RTL: the thumbnails sit at the reading end (left)', (
    tester,
  ) async {
    await pump(
      tester,
      stage(
        const PodcastDirectorShot(
          kind: PodcastShotKind.speaker,
          userIds: ['u1', 'h'],
        ),
      ),
      language: AppLanguage.ar,
    );
    final thumb = tester.getRect(find.byKey(VideoPodcastStage.thumbKey('h')));
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(thumb.left, lessThan(width / 2));
    expect(find.text('لقطة المتحدث'), findsOneWidget);
    await pump(
      tester,
      stage(
        const PodcastDirectorShot(
          kind: PodcastShotKind.speaker,
          userIds: ['u1', 'h'],
        ),
      ),
    );
    final ltr = tester.getRect(find.byKey(VideoPodcastStage.thumbKey('h')));
    expect(ltr.left, greaterThan(width / 2));
  });

  test('the hot seat timer total is the smallest question time that holds '
      'what is left', () {
    final now = DateTime.utc(2026, 11, 10, 20);
    expect(hotSeatTotal(null, now), 60);
    expect(hotSeatTotal(now.add(const Duration(seconds: 42)), now), 60);
    expect(hotSeatTotal(now.add(const Duration(seconds: 100)), now), 120);
    expect(hotSeatTotal(now.add(const Duration(seconds: 299)), now), 300);
  });

  testWidgets('listeners upvote others’ questions, not their own', (
    tester,
  ) async {
    final calls = <(String, bool)>[];
    UserSummary u(String id) =>
        UserSummary(id: id, username: id, displayName: id, avatarUrl: null);
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showPodcastQuestionsSheet(
            context,
            me: 'me',
            questions: [
              LivePodcastQuestion(
                requestId: 'q1',
                user: u('ann'),
                question: 'First?',
                votes: 3,
              ),
              LivePodcastQuestion(
                requestId: 'q2',
                user: u('me'),
                question: 'Mine?',
              ),
            ],
            onVote: (q, {required vote}) async {
              calls.add((q.requestId, vote));
              return LivePodcastQuestionVotes(
                requestId: q.requestId,
                votes: q.votes + (vote ? 1 : -1),
                votedByMe: vote,
              );
            },
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(PodcastQuestionsSheet.sheetKey), findsOneWidget);
    await tester.tap(find.byKey(PodcastQuestionsSheet.voteKey('q1')));
    await tester.pumpAndSettle();
    expect(calls, [('q1', true)]);
    expect(find.text('\u20664\u2069'), findsOneWidget);
    // Again: the vote is taken back.
    await tester.tap(find.byKey(PodcastQuestionsSheet.voteKey('q1')));
    await tester.pumpAndSettle();
    expect(calls.last, ('q1', false));
    // The asker's own question has no vote.
    await tester.tap(find.byKey(PodcastQuestionsSheet.voteKey('q2')));
    await tester.pumpAndSettle();
    expect(calls, hasLength(2));
  });

  testWidgets('the host’s hands: by votes, «الكرسي الساخن» on a question', (
    tester,
  ) async {
    final hot = <String>[];
    UserSummary u(String id) =>
        UserSummary(id: id, username: id, displayName: id, avatarUrl: null);
    final requests = [
      LiveSeatRequest(
        id: 'r1',
        user: u('ann'),
        seatIndex: null,
        createdAt: DateTime.utc(2026, 11, 10, 20),
        question: 'Older, fewer votes',
        votes: 1,
      ),
      LiveSeatRequest(
        id: 'r2',
        user: u('bob'),
        seatIndex: null,
        createdAt: DateTime.utc(2026, 11, 10, 20, 1),
        question: 'Newer, more votes',
        votes: 5,
      ),
      LiveSeatRequest(
        id: 'r3',
        user: u('cat'),
        seatIndex: null,
        createdAt: DateTime.utc(2026, 11, 10, 20, 2),
      ),
    ];
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showPodcastHandsSheet(
            context,
            load: () async => requests,
            freeSeats: 2,
            podcast: const LivePodcast(
              episodeNumber: 1,
              topic: PodcastTopic.tech,
              video: true,
            ),
            config: const LivePodcastConfig(),
            onBringUp: (_) async {},
            onLater: (_) async {},
            onHotSeat: (r) async => hot.add(r.id),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.text('Newer, more votes')).dy;
    final next = tester.getTopLeft(find.text('Older, fewer votes')).dy;
    expect(top, lessThan(next));
    // A hand without a question has no hot seat.
    expect(find.byKey(PodcastHandsSheet.hotSeatKey('r3')), findsNothing);
    await tester.tap(find.byKey(PodcastHandsSheet.hotSeatKey('r2')));
    await tester.pumpAndSettle();
    expect(hot, ['r2']);
  });

  test('a video podcast is drawn as a video live; an audio one is not', () {
    const facts = LivePodcast(episodeNumber: 1, topic: PodcastTopic.tech);
    final audio = apiRoom(id: 'a')
        .copyWith(mode: LiveRoomMode.podcast, podcast: facts);
    final video = audio.copyWith(podcast: facts.copyWith(video: true));
    expect(audio.videoPodcast, isFalse);
    expect(audio.voiceOnly, isTrue);
    expect(video.videoPodcast, isTrue);
    expect(video.voiceOnly, isFalse);
    expect(video.mode.isVoice, isTrue); // still the podcast kind
    expect(
      apiRoom(id: 'b').copyWith(mode: LiveRoomMode.audio).voiceOnly,
      isTrue,
    );
    // The wire: `video` only when on (an audio podcast's body is D212's).
    expect(
      const PodcastSetup(topic: PodcastTopic.tech)
          .toJson()
          .containsKey('video'),
      isFalse,
    );
    expect(
      const PodcastSetup(
        topic: PodcastTopic.tech,
        video: true,
      ).toJson()['video'],
      isTrue,
    );
    expect(
      LivePodcast.fromJson({'episodeNumber': 2, 'topic': 'tech'}).video,
      isFalse,
    );
  });
}
