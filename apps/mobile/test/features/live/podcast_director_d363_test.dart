import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/live/application/podcast_director.dart';
import 'package:kabso_live/features/live/domain/live_podcast_video.dart';

/// D363 (§10.157): the video podcast's automatic director — hysteresis,
/// split, grid, the host's lock, the hot seat, a viewer's own pick and the
/// fallback when the host's director is not heard.
void main() {
  const host = 'host';
  const a = 'guest-a';
  const b = 'guest-b';
  const c = 'guest-c';
  final t0 = DateTime.utc(2026, 11, 10, 20);
  DateTime at(num seconds) =>
      t0.add(Duration(milliseconds: (seconds * 1000).round()));

  PodcastDirector director() =>
      PodcastDirector(hostId: host)..setStage([a, b, c], t0);

  group('speaker shot and hysteresis', () {
    test('starts on the host, the others as thumbnails in stage order', () {
      final d = director();
      expect(d.shot.kind, PodcastShotKind.speaker);
      expect(d.shot.userIds, [host, a, b, c]);
      expect(d.shot.locked, isFalse);
    });

    test('cuts to a new speaker only after the shot was held 2.5 s', () {
      final d = director();
      // The first cut: nothing was on screen long yet, but the hold starts
      // with the first decision — the host's opening shot has no start.
      expect(d.onSpeakers({a}, at(1))?.main, a);
      // b answers 1 s later: held for 1 s only → no cut.
      expect(d.onSpeakers({b}, at(2)), isNull);
      expect(d.shot.main, a);
      // Still b at 3.4 s (2.4 s held) → no cut; at 3.6 s → cut to b.
      expect(d.tick(at(3.4)), isNull);
      final cut = d.tick(at(3.6));
      expect(cut?.kind, PodcastShotKind.speaker);
      expect(cut?.main, b);
      expect(cut!.userIds, [b, host, a, c]);
    });

    test('silence keeps the last speaker on screen', () {
      final d = director()..onSpeakers({a}, at(1));
      expect(d.onSpeakers(const {}, at(5)), isNull);
      expect(d.tick(at(20)), isNull);
      expect(d.shot.main, a);
    });

    test('a shot carries an increasing sequence number', () {
      final d = director();
      final first = d.onSpeakers({a}, at(1))!;
      // Held 3 s: b's turn cuts at once.
      final second = d.onSpeakers({b}, at(4))!;
      expect(second.seq, greaterThan(first.seq));
    });

    test('people off stage are ignored; leaving the stage cuts at once', () {
      final d = director()..onSpeakers({a}, at(1));
      expect(d.onSpeakers({'listener'}, at(4)), isNull);
      final cut = d.setStage([b, c], at(4.5));
      expect(cut, isNotNull);
      expect(cut!.userIds, isNot(contains(a)));
    });
  });

  group('split', () {
    test('two people alternating within 6 s split the screen', () {
      // a, then b (held: cut to b).
      final d = director()
        ..onSpeakers({a}, at(0))
        ..onSpeakers({b}, at(3));
      final split = d.onSpeakers({a}, at(5.6)); // b → a: alternating
      expect(split?.kind, PodcastShotKind.split);
      expect(split!.userIds, [a, b]);
      // The same two going on keep the split (no reordering flicker).
      expect(d.onSpeakers({b}, at(8.2)), isNull);
      expect(d.shot.kind, PodcastShotKind.split);
    });

    test('back to the speaker shot when only one goes on talking', () {
      final d = director()
        ..onSpeakers({a}, at(0))
        ..onSpeakers({b}, at(3))
        ..onSpeakers({a}, at(5.6));
      expect(d.shot.kind, PodcastShotKind.split);
      // a talks alone: past the 6 s window there is no alternation.
      final back = d.tick(at(12));
      expect(back?.kind, PodcastShotKind.speaker);
      expect(back?.main, a);
    });

    test('three different people do not make a split', () {
      final d = director()
        ..onSpeakers({a}, at(0))
        ..onSpeakers({b}, at(3))
        ..onSpeakers({c}, at(5.6));
      expect(d.shot.kind, PodcastShotKind.speaker);
      expect(d.shot.main, c);
    });
  });

  group('grid', () {
    test('three or more at once show everyone, then return', () {
      final d = director()..onSpeakers({a}, at(0));
      final grid = d.onSpeakers({a, b, c}, at(3));
      expect(grid?.kind, PodcastShotKind.grid);
      expect(grid!.userIds, [host, a, b, c]);
      // The burst ends at 4 s; the grid stays its 3 s, then returns.
      expect(d.onSpeakers({b}, at(4)), isNull);
      expect(d.tick(at(6.9)), isNull);
      final back = d.tick(at(7.1));
      expect(back?.kind, PodcastShotKind.speaker);
      expect(back?.main, b);
    });

    test('no grid with fewer than three on stage', () {
      final d = PodcastDirector(hostId: host)
        ..setStage([a], t0)
        ..onSpeakers({host, a}, at(3));
      expect(d.shot.kind, isNot(PodcastShotKind.grid));
    });
  });

  group('the host lock and the hot seat', () {
    test('a lock applies at once, holds against speakers, and unlocks', () {
      final d = director()..onSpeakers({a}, at(0));
      final locked = d.lock(c, at(0.5));
      expect(locked?.kind, PodcastShotKind.speaker);
      expect(locked?.main, c);
      expect(locked?.locked, isTrue);
      expect(d.onSpeakers({a, b, host}, at(5)), isNull);
      expect(d.tick(at(30))?.main, isNull);
      final free = d.lock(null, at(31));
      expect(free?.locked, isFalse);
      expect(d.locked, isNull);
    });

    test('the lock is dropped when the pinned guest leaves', () {
      final d = director()
        ..lock(b, at(1))
        ..setStage([a, c], at(2));
      expect(d.locked, isNull);
      expect(d.shot.locked, isFalse);
    });

    test('the hot seat shows at once and ends back on the director', () {
      final d = director()
        ..onSpeakers({a}, at(0))
        ..setStage([a, b, c, 'asker'], at(0.2));
      final hot = d.setHotSeat('asker', at(0.4));
      expect(hot?.kind, PodcastShotKind.hotSeat);
      expect(hot?.main, 'asker');
      expect(d.onSpeakers({a, b, c}, at(5)), isNull); // no grid over it
      final back = d.setHotSeat(null, at(6));
      expect(back?.kind, isNot(PodcastShotKind.hotSeat));
    });
  });

  group('viewers: the relayed shot, their own pick, the fallback', () {
    test('follows the host, drops older messages, falls back after 15 s', () {
      final local = director();
      final f = PodcastShotFollower(local);
      const relayed = PodcastDirectorShot(
        kind: PodcastShotKind.split,
        userIds: [a, b],
        seq: 5,
      );
      expect(f.onRemote(relayed, at(1)), isTrue);
      expect(f.shotAt(at(2)).kind, PodcastShotKind.split);
      expect(
        f.onRemote(relayed.copyWith(kind: PodcastShotKind.grid, seq: 4), at(3)),
        isFalse,
      );
      expect(f.following(at(10)), isTrue);
      // The host went quiet (background): the local director takes over.
      local.onSpeakers({c}, at(14));
      expect(f.following(at(16.5)), isFalse);
      expect(f.shotAt(at(16.5)).main, c);
      // The host is back with a new sequence (an app restart): taken.
      expect(f.onRemote(relayed.copyWith(seq: 1), at(17)), isTrue);
      expect(f.shotAt(at(17)).kind, PodcastShotKind.split);
    });

    test('a thumbnail tap watches that person until «رجوع للمخرج»', () {
      final f = PodcastShotFollower(director())..pinned = b;
      expect(f.free, isTrue);
      expect(f.shotAt(at(1)).userIds.first, b);
      expect(f.shotAt(at(1)).kind, PodcastShotKind.speaker);
      f.pinned = null;
      expect(f.free, isFalse);
      expect(f.shotAt(at(1)).main, host);
    });

    test('people who left since the message are not drawn', () {
      final local = director();
      final f = PodcastShotFollower(local)
        ..onRemote(
          const PodcastDirectorShot(
            kind: PodcastShotKind.split,
            userIds: [a, b],
            seq: 1,
          ),
          at(1),
        );
      local.setStage([b, c], at(2));
      expect(f.shotAt(at(2)).userIds, [b]);
    });
  });

  group('wire', () {
    test('parses director and vote messages; ignores others', () {
      final shot = PodcastEvent.parse({
        'type': 'director',
        'shot': 'HOT_SEAT',
        'userIds': [a, host],
        'locked': false,
        'seq': 9,
        'at': '2026-11-10T20:00:00.000Z',
      });
      expect(shot, isA<PodcastDirectorEvent>());
      final s = (shot! as PodcastDirectorEvent).shot;
      expect(s.kind, PodcastShotKind.hotSeat);
      expect(s.userIds, [a, host]);
      expect(s.seq, 9);
      final votes = PodcastEvent.parse({
        'type': 'question-votes',
        'requestId': 'r1',
        'votes': 4,
      });
      expect(votes, isA<PodcastVotesEvent>());
      expect((votes! as PodcastVotesEvent).votes, 4);
      expect(PodcastEvent.parse({'type': 'director', 'shot': 'WIDE'}), isNull);
      expect(PodcastEvent.parse('x'), isNull);
      expect(
        const PodcastDirectorShot(
          kind: PodcastShotKind.split,
          userIds: [a, b],
          locked: true,
          seq: 3,
        ).toJson(),
        {
          'shot': 'SPLIT',
          'userIds': [a, b],
          'locked': true,
          'seq': 3,
        },
      );
    });
  });

  // D363 scope extension (owner 2026-11-11): the host's manual control (a
  // pinned person, a locked layout, «تلقائي») and the question on screen.
  group('manual control: pin, layout lock, «تلقائي»', () {
    test('a pin keeps the shot on that person against the speakers', () {
      final d = director()..onSpeakers({a}, at(1));
      final pinned = d.control(pin: b, layout: null, now: at(1.5));
      expect(pinned?.kind, PodcastShotKind.speaker);
      expect(pinned?.main, b);
      expect(pinned?.locked, isTrue);
      expect(d.onSpeakers({c}, at(5)), isNull);
      expect(d.tick(at(30)), isNull);
      expect(d.shot.main, b);
      // «تلقائي»: back to the director at once (the latest voice, c).
      final auto = d.control(pin: null, layout: null, now: at(31));
      expect(auto?.locked, isFalse);
      expect(auto?.main, c);
    });

    test('a locked SPEAKER layout follows the voices but never splits', () {
      final d = director()
        ..control(pin: null, layout: PodcastShotKind.speaker, now: at(0.5));
      expect(d.shot.locked, isTrue);
      expect(d.layout, PodcastShotKind.speaker);
      // A → B → A within 6 s would split; locked, it stays a speaker shot.
      d
        ..onSpeakers({a}, at(1))
        ..onSpeakers({b}, at(4))
        ..onSpeakers({a}, at(7))
        ..tick(at(9.6));
      expect(d.shot.kind, PodcastShotKind.speaker);
      expect(d.shot.main, a);
      // Three at once: no grid either.
      expect(
        d.onSpeakers({a, b, c}, at(20))?.kind,
        isNot(PodcastShotKind.grid),
      );
      expect(d.shot.kind, PodcastShotKind.speaker);
    });

    test(
      'a locked SPLIT puts the pinned person on top, the latest voice under',
      () {
        final d = director()..onSpeakers({c}, at(1));
        final split = d.control(
          pin: a,
          layout: PodcastShotKind.split,
          now: at(2),
        );
        expect(split?.kind, PodcastShotKind.split);
        expect(split?.userIds, [a, c]);
        expect(split?.locked, isTrue);
        // Without a pin: the latest two voices.
        final d2 = director()
          ..onSpeakers({b}, at(1))
          ..onSpeakers({c}, at(4));
        final split2 = d2.control(
          pin: null,
          layout: PodcastShotKind.split,
          now: at(5),
        );
        expect(split2?.userIds.toSet(), {b, c});
      },
    );

    test('a HOT_SEAT layout needs a hot seat; then it holds the card', () {
      final d = director();
      expect(
        d.control(pin: null, layout: PodcastShotKind.hotSeat, now: at(1)),
        isNull,
      );
      expect(d.shot.kind, PodcastShotKind.speaker);
      final hot = d.setHotSeat(c, at(2));
      expect(hot?.kind, PodcastShotKind.hotSeat);
      expect(hot?.locked, isTrue);
      expect(d.onSpeakers({a}, at(10)), isNull);
      expect(d.shot.kind, PodcastShotKind.hotSeat);
    });

    test('GRID is never locked; someone off stage is never pinned', () {
      final d = director();
      expect(
        d.control(pin: 'nobody', layout: PodcastShotKind.grid, now: at(1)),
        isNull,
      );
      expect(d.locked, isNull);
      expect(d.layout, isNull);
      // A pinned guest who leaves: the pin goes, the layout stays.
      d
        ..control(pin: b, layout: PodcastShotKind.speaker, now: at(2))
        ..setStage([a, c], at(3));
      expect(d.locked, isNull);
      expect(d.layout, PodcastShotKind.speaker);
      expect(d.shot.userIds, isNot(contains(b)));
    });
  });

  group('the question on screen', () {
    test('the answering person is preferred at once over the voices', () {
      final d = director()..onSpeakers({a}, at(1));
      final answer = d.setAnswer(c, at(1.2));
      expect(answer?.main, c);
      expect(answer?.locked, isFalse);
      // Someone else speaks a while: the shot stays on the answer.
      expect(d.onSpeakers({b}, at(5)), isNull);
      expect(d.tick(at(20)), isNull);
      expect(d.shot.main, c);
      // The card goes: the director takes over again (b spoke last).
      expect(d.setAnswer(null, at(21))?.main, b);
    });

    test('the host’s control and the hot seat win over the question', () {
      final d = director()..setAnswer(c, at(1));
      expect(d.control(pin: a, layout: null, now: at(2))?.main, a);
      d.control(pin: null, layout: null, now: at(3));
      expect(d.shot.main, c);
      expect(d.setHotSeat(b, at(4))?.kind, PodcastShotKind.hotSeat);
      expect(d.setHotSeat(null, at(5))?.main, c);
    });

    test('an answerer who leaves the stage is forgotten', () {
      final d = director()
        ..setAnswer(c, at(1))
        ..setStage([a, b], at(2));
      expect(d.answering, isNull);
      expect(d.shot.userIds, isNot(contains(c)));
    });
  });

  group('studio wire', () {
    test('parses a `studio` message; drops malformed ones', () {
      final event = PodcastEvent.parse({
        'type': 'studio',
        'studio': {
          'seq': 4,
          'pinUserId': a,
          'layout': 'SPLIT',
          'segments': [
            {'title': 'مقدمة', 'minutes': null},
            {'title': 'نقاش', 'minutes': 20},
          ],
          'segmentIndex': 1,
          'segmentStartedAt': '2026-11-10T20:00:00.000Z',
          'closing': false,
          'onScreen': {
            'requestId': 'r1',
            'user': {
              'id': 'u9',
              'username': 'noor',
              'displayName': 'نور',
              'avatarUrl': null,
            },
            'question': 'سؤال؟',
            'answerUserId': b,
            'at': '2026-11-10T20:00:00.000Z',
          },
        },
      });
      expect(event, isA<PodcastStudioEvent>());
      final studio = (event! as PodcastStudioEvent).studio;
      expect(studio.seq, 4);
      expect(studio.pinUserId, a);
      expect(studio.layout, PodcastShotKind.split);
      expect(studio.automatic, isFalse);
      expect(
        studio.segment,
        const LivePodcastSegment(title: 'نقاش', minutes: 20),
      );
      expect(studio.onScreen?.answerUserId, b);
      expect(studio.onScreen?.user.displayName, 'نور');
      expect(LivePodcastStudio.fromJson(studio.toJson()), studio);
      expect(PodcastEvent.parse({'type': 'studio', 'studio': 3}), isNull);
      expect(const LivePodcastStudio().automatic, isTrue);
      expect(const LivePodcastStudio().segment, isNull);
    });
  });
}
