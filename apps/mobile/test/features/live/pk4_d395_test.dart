// D395 (v1.119-live, CONVENTIONS §10.181, CP-041 phases 3–4; owner «أ و ب»)
// «PK رباعي» for two to four hosts: the data (two to four places, FREE_FOR_ALL
// with no teams, places and results, the dare and the rematch, the queue
// message; an unknown shape ignored), the stage's layouts (two: half the
// screen each; three: two stacked and one tile the size of two; four: the
// 2 × 2 grid — TEAMS and FREE_FOR_ALL), the result badge under the scores line
// (win with the crown, loss, draw; FREE_FOR_ALL places), the smaller friends
// list in both tabs of the PK sheet, «ابدأ الآن», the TEAMS / FREE_FOR_ALL
// choice and «PK أحكام», the 4-way random queue, the dare card and
// «جولة أخرى» for four, and the controller's queue and rematch messages.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_pk4_controller.dart';
import 'package:kabso_live/features/live/data/live_pk4_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/domain/live_pk4.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk4_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk4_stage.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_dare.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_pk.dart';
import '../../helpers/fake_live_pk4.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _user(String id, String name) => {
  'id': id,
  'username': id.replaceAll('-', '_'),
  'displayName': name,
  'avatarUrl': null,
};

Map<String, dynamic> _uses() => {
  'DOUBLE': 0,
  'DOUBLE_TURBO': 0,
  'TRIPLE': 0,
  'TRIPLE_TURBO': 0,
};

/// A v1.119-live `Pk4Match` exactly as the contract lays it out.
Map<String, dynamic> _matchJson({
  required List<int> seats,
  String format = 'FREE_FOR_ALL',
  String status = 'RESULT',
  List<int?> places = const [],
  List<String?> results = const [],
  Map<String, dynamic>? dare,
  Map<String, dynamic>? rematch,
}) => {
  'id': '0192f1d0-0000-7000-8000-000000000009',
  'format': format,
  'type': dare == null ? 'NORMAL' : 'DARES',
  'source': 'INVITE',
  'playerCount': seats.length,
  'status': status,
  'startedAt': '2026-11-13T10:00:00.000Z',
  'battleEndsAt': '2026-11-13T10:05:00.000Z',
  'endedAt': '2026-11-13T10:05:00.000Z',
  'resultEndsAt': '2026-11-13T10:06:00.000Z',
  'endReason': 'TIME',
  'winnerTeam': null,
  'seq': 9,
  'serverTime': '2026-11-13T10:05:10.000Z',
  'roundSeconds': 300,
  'connectedAt': null,
  'effective': true,
  'organiserRoomId': 'room-0',
  'teams': format == 'TEAMS'
      ? [
          for (final t in ['A', 'B'])
            {
              'team': t,
              'score': 100,
              'result': 'DRAW',
              'boost': null,
              'boosterUses': _uses(),
              'supporters': <Object>[],
            },
        ]
      : <Object>[],
  'seats': [
    for (final (i, seat) in seats.indexed)
      {
        'seat': seat,
        'team': seat <= 2 ? 'A' : 'B',
        'roomId': 'room-$i',
        'host': _user('user-$i', 'Host $i'),
        'score': 100 * (i + 1),
        'out': false,
        'outReason': null,
        'mutedRoomIds': <String>[],
        'pkPoints': 3,
        'place': i < places.length ? places[i] : null,
        'result': i < results.length ? results[i] : null,
        'boost': null,
        'boosterUses': _uses(),
        'supporters': <Object>[],
      },
  ],
  'boosters': <Object>[],
  'dare': dare,
  'rematch': rematch,
  'rematchOf': null,
  'rematchesLeft': 4,
};

Future<void> _stage(
  WidgetTester tester,
  Pk4Match match, {
  AppLanguage language = AppLanguage.ar,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
}) async {
  await loadAppFonts();
  setViewport(tester, viewport);
  await pumpScreen(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: viewport.logicalSize,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: SingleChildScrollView(
          child: LivePk4Stage(
            match: match,
            roomId: 'room-0',
            now: () => match.serverTime,
            video: (_) => null,
          ),
        ),
      ),
    ),
    language: language,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the data (two to four hosts, FREE_FOR_ALL)', () {
    test('three FREE_FOR_ALL places: no teams (each side summed), places and '
        'results, the four-part order', () {
      final m = Pk4Match.fromJson(
        _matchJson(
          seats: [1, 2, 3],
          places: [3, 1, 2],
          results: ['LOSS', 'WIN', 'LOSS'],
        ),
      );
      expect(m.ffa, isTrue);
      expect(m.playerCount, 3);
      expect(m.seats.map((s) => s.team), [Pk4Team.a, Pk4Team.a, Pk4Team.b]);
      expect(m.teams.$1.score, 300);
      expect(m.teams.$2.score, 300);
      expect(m.seatOf('room-1')!.place, 1);
      expect(m.resultOf('room-1'), Pk4Result.win);
      expect(m.resultOf('room-0'), Pk4Result.loss);
      expect(m.ranked.map((s) => s.roomId), ['room-2', 'room-1', 'room-0']);
      expect(m.rematchesLeft, 4);
    });

    test('two TEAMS places like a 1 v 1; a team result without seat results '
        '(an older server) still reads', () {
      final json = _matchJson(seats: [1, 3], format: 'TEAMS');
      for (final s in json['seats'] as List<dynamic>) {
        (s as Map<String, dynamic>)
          ..remove('result')
          ..remove('place');
      }
      final m = Pk4Match.fromJson(json);
      expect(m.ffa, isFalse);
      expect(m.seatsOf(Pk4Team.a).single.roomId, 'room-0');
      expect(m.seatsOf(Pk4Team.b).single.roomId, 'room-1');
      expect(m.resultOf('room-0'), Pk4Result.draw);
    });

    test('a future shape (five places, one team) is ignored, never half '
        'drawn; the queue message', () {
      expect(
        Pk4Event.parse({
          'type': 'pk4-match',
          'event': 'started',
          'match': _matchJson(seats: [1, 2, 3, 4, 4]),
        }),
        isNull,
      );
      final one = _matchJson(seats: [1, 3], format: 'TEAMS');
      (one['teams'] as List<dynamic>).removeLast();
      expect(
        Pk4Event.parse({'type': 'pk4-match', 'event': 'x', 'match': one}),
        isNull,
      );
      final q = Pk4Event.parse({'type': 'pk4-queue', 'status': 'EXPIRED'});
      expect(q, isA<Pk4QueueEvent>());
      expect((q! as Pk4QueueEvent).matched, isFalse);
      final m = Pk4Event.parse({
        'type': 'pk4-queue',
        'status': 'MATCHED',
        'matchId': 'm-1',
      });
      expect((m! as Pk4QueueEvent).matchId, 'm-1');
    });

    test('the dare from each room’s side; the rematch offer', () {
      final m = Pk4Match.fromJson(
        _matchJson(
          seats: [1, 2, 3, 4],
          dare: {
            'status': 'DECIDING',
            'cause': null,
            'loserRoomIds': ['room-2', 'room-3'],
            'winnerRoomIds': ['room-0', 'room-1'],
            'options': [
              for (final level in ['EASY', 'MEDIUM', 'HARD'])
                {
                  'id': 'd-$level',
                  'level': level,
                  'category': 'FUNNY',
                  'textAr': 'حكم',
                  'textEn': 'Dare',
                },
            ],
            'drawn': 1,
            'revealAt': '2026-11-13T10:05:04.000Z',
            'decideBy': '2026-11-13T10:05:34.000Z',
            'startedAt': null,
            'endsAt': null,
            'finishedAt': null,
            'points': 0,
            'refusePoints': -3,
          },
          rematch: {
            'byRoomId': 'room-1',
            'expiresAt': '2026-11-13T10:05:20.000Z',
            'acceptedRoomIds': ['room-1'],
            'waitingRoomIds': ['room-0', 'room-2', 'room-3'],
          },
        ),
      );
      expect(m.type, PkType.dares);
      // A loser's room answers as the loser; a winner's judges.
      expect(m.dareView('room-3')!.dare!.loserRoomId, 'room-3');
      expect(m.dareView('room-1')!.dare!.winnerRoomId, 'room-1');
      expect(m.dareView('room-1')!.dare!.loserRoomId, 'room-2');
      // The losing side's names are joined on the card.
      expect(
        m.dareView('room-0')!.sides.$1.host.displayName,
        'Host 2 · Host 3',
      );
      expect(m.rematch!.waitingRoomIds, hasLength(3));
      expect(m.canOfferRematch, isFalse);
    });
  });

  group('the stage’s layouts', () {
    final now = DateTime.utc(2026, 11, 13, 10);

    for (final ffa in [false, true]) {
      final name = ffa ? 'FREE_FOR_ALL' : 'TEAMS';
      testWidgets('$name with two: half the screen each', (tester) async {
        await _stage(tester, pk4PlayersFixture(now: now, players: 2, ffa: ffa));
        final a = tester.getRect(find.byKey(LivePk4Stage.paneKey(1)));
        final b = tester.getRect(find.byKey(LivePk4Stage.paneKey(3)));
        expect(a.height, closeTo(b.height, 0.5));
        expect(a.width, closeTo(b.width, 0.5));
        expect(a.top, b.top);
        // RTL: this room on the right.
        expect(a.left > b.left, isTrue);
        expect(
          find.byKey(ffa ? LivePk4Stage.ffaBarKey : LivePk4Stage.barKey),
          findsOneWidget,
        );
      });

      testWidgets('$name with three: two stacked, the third alone in a tile '
          'the size of two', (tester) async {
        await _stage(tester, pk4PlayersFixture(now: now, players: 3, ffa: ffa));
        final one = tester.getRect(find.byKey(LivePk4Stage.paneKey(1)));
        final two = tester.getRect(find.byKey(LivePk4Stage.paneKey(2)));
        final big = tester.getRect(find.byKey(LivePk4Stage.paneKey(3)));
        expect(one.left, two.left);
        expect(one.bottom < two.top, isTrue);
        expect(big.height, closeTo(one.height + two.height + 2, 0.5));
        expect(big.top, one.top);
        expect(big.width, closeTo(one.width, 0.5));
      });

      testWidgets('$name with four: the 2 × 2 grid', (tester) async {
        await _stage(tester, pk4PlayersFixture(now: now, players: 4, ffa: ffa));
        final rects = [
          for (final s in [1, 2, 3, 4])
            tester.getRect(find.byKey(LivePk4Stage.paneKey(s))),
        ];
        for (final r in rects.skip(1)) {
          expect(r.height, closeTo(rects[0].height, 0.5));
        }
        expect(rects[0].left, rects[1].left);
        expect(rects[2].left, rects[3].left);
        expect(rects[0].top, rects[2].top);
      });
    }

    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      for (final players in [2, 3, 4]) {
        testWidgets('no overflow at 360 × 800 × 1.3 (FREE_FOR_ALL $players, '
            '${language.name})', (tester) async {
          await _stage(
            tester,
            pk4PlayersFixture(
              now: now,
              players: players,
              ffa: true,
              ar: language == AppLanguage.ar,
              status: PkMatchStatus.result,
              places: const [2, 1, 3, 4],
              results: const [
                Pk4Result.loss,
                Pk4Result.win,
                Pk4Result.loss,
                Pk4Result.loss,
              ],
              scores: const [98765432, 1234567, 87654321, 7654321],
            ),
            language: language,
            viewport: GoldenViewport.android,
            textScale: 1.3,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('FREE_FOR_ALL result: a place medal on each pane', (
      tester,
    ) async {
      await _stage(
        tester,
        pk4PlayersFixture(
          now: now,
          players: 4,
          ffa: true,
          status: PkMatchStatus.result,
          places: const [2, 1, 3, 4],
          results: const [
            Pk4Result.loss,
            Pk4Result.win,
            Pk4Result.loss,
            Pk4Result.loss,
          ],
        ),
      );
      for (final seat in [1, 2, 3, 4]) {
        expect(find.byKey(LivePk4Stage.placeKey(seat)), findsOneWidget);
      }
      expect(find.text('#1'), findsOneWidget);
      expect(find.byKey(LivePk4Stage.timerKey), findsNothing);
    });
  });

  group('the result badge under the scores line', () {
    final now = DateTime.utc(2026, 11, 13, 10);

    testWidgets('TEAMS win: gold with the crown, «فاز فريقكم»', (tester) async {
      await _stage(
        tester,
        pk4PlayersFixture(
          now: now,
          players: 4,
          status: PkMatchStatus.result,
          winner: Pk4Team.a,
        ),
      );
      expect(find.byKey(Pk4ResultBadge.crownKey), findsOneWidget);
      expect(find.text('فاز فريقكم'), findsOneWidget);
      // Directly under the bar.
      final bar = tester.getRect(find.byKey(LivePk4Stage.barKey));
      final badge = tester.getRect(find.byKey(LivePk4Stage.resultKey));
      expect(badge.top - bar.bottom, lessThan(8));
    });

    testWidgets('TEAMS loss: calm, no crown', (tester) async {
      await _stage(
        tester,
        pk4PlayersFixture(
          now: now,
          players: 4,
          status: PkMatchStatus.result,
          winner: Pk4Team.b,
        ),
      );
      expect(find.byKey(Pk4ResultBadge.crownKey), findsNothing);
      expect(find.text('خسر فريقكم'), findsOneWidget);
    });

    testWidgets('a draw; alone on a side («فزت»); FREE_FOR_ALL places', (
      tester,
    ) async {
      await _stage(
        tester,
        pk4PlayersFixture(now: now, players: 4, status: PkMatchStatus.result),
      );
      expect(find.text('تعادل الفريقان'), findsOneWidget);
      await _stage(
        tester,
        pk4PlayersFixture(
          now: now,
          players: 2,
          status: PkMatchStatus.result,
          winner: Pk4Team.a,
        ),
      );
      expect(find.text('فزت'), findsOneWidget);
      await _stage(
        tester,
        pk4PlayersFixture(
          now: now,
          players: 3,
          ffa: true,
          status: PkMatchStatus.result,
          places: const [3, 1, 2],
          results: const [Pk4Result.loss, Pk4Result.win, Pk4Result.loss],
        ),
      );
      expect(find.text('المركز 3'), findsOneWidget);
      await _stage(
        tester,
        pk4PlayersFixture(
          now: now,
          players: 2,
          ffa: true,
          status: PkMatchStatus.result,
          places: const [1, 1],
          results: const [Pk4Result.draw, Pk4Result.draw],
        ),
      );
      expect(find.text('تعادل على المركز الأول'), findsOneWidget);
    });
  });

  group('the PK sheet: the smaller friends list, the 4-way panel', () {
    final candidate = PkCandidate(
      roomId: 'room-9',
      title: 'Live',
      viewerCount: 12,
      host: pk4User('user-9', 'Nora'),
    );

    Future<FakeLivePk4Repository> sheet(
      WidgetTester tester, {
      PkSheetMode mode = PkSheetMode.team,
      Pk4Lobby? lobby,
      Pk4Queue? queue,
    }) async {
      await loadAppFonts();
      setViewport(tester, GoldenViewport.phone);
      final now = DateTime.now();
      final repo =
          FakeLivePk4Repository(
              snapshot: Pk4State(lobby: lobby, queue: queue),
              list: [candidate],
            )
            ..lobbyOnOpen = pk4LobbyFormatFixture(
              now: now,
              states: const [
                Pk4SeatState.empty,
                Pk4SeatState.empty,
                Pk4SeatState.empty,
              ],
            )
            ..randomResult = Pk4RandomResult(
              queue: Pk4Queue(
                format: Pk4Format.teams,
                expiresAt: now.add(const Duration(minutes: 2)),
              ),
            );
      final pk = FakeLivePkRepository(list: [candidate]);
      await pumpScreen(
        tester,
        Consumer(
          builder: (context, ref, _) {
            ref.watch(livePk4Provider('room-0'));
            return Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: LivePkSheet(roomId: 'room-0', initialMode: mode),
              ),
            );
          },
        ),
        language: AppLanguage.ar,
        brightness: Brightness.light,
        livePk4Repository: repo,
        livePkRepository: pk,
      );
      if (mode == PkSheetMode.team) {
        final element = tester.element(find.byType(LivePk4Panel));
        final controller = ProviderScope.containerOf(element).read(
          livePk4Provider('room-0').notifier,
        )..attach(const Stream.empty(), host: true);
        if (lobby != null) controller.debugSetLobby(lobby);
        if (queue != null) controller.debugSetQueue(queue);
      }
      await tester.pumpAndSettle();
      return repo;
    }

    void expectSmallRow(WidgetTester tester, Finder row) {
      final avatar = tester.getSize(
        find.descendant(of: row, matching: find.byKey(PkFriendRow.avatarKey)),
      );
      expect(avatar.width, PkFriendsMetrics.avatar);
      final button = tester.getSize(
        find.descendant(of: row, matching: find.byKey(PkFriendRow.inviteKey)),
      );
      expect(button.height, PkFriendsMetrics.button);
      // Less space: a row is far shorter than D199's two-line tile (64).
      expect(tester.getSize(row).height, lessThan(48));
    }

    testWidgets('«PK ثنائي»: the smaller header and rows', (tester) async {
      await sheet(tester, mode: PkSheetMode.oneVsOne);
      final header = tester.widget<Text>(find.byKey(PkFriendsHeader.textKey));
      expect(header.style!.fontSize, PkFriendsMetrics.header);
      expectSmallRow(tester, find.byKey(LivePkSheet.candidateKey('room-9')));
    });

    testWidgets('«PK رباعي»: the same smaller header and rows', (tester) async {
      await sheet(
        tester,
        lobby: pk4LobbyFormatFixture(
          now: DateTime.now(),
          states: const [
            Pk4SeatState.accepted,
            Pk4SeatState.empty,
            Pk4SeatState.empty,
          ],
        ),
      );
      await tester.tap(find.byKey(LivePk4Panel.placeKey(3)));
      await tester.pumpAndSettle();
      final header = tester.widget<Text>(find.byKey(PkFriendsHeader.textKey));
      expect(header.style!.fontSize, PkFriendsMetrics.header);
      expectSmallRow(tester, find.byKey(LivePk4Panel.candidateKey('room-9')));
    });

    testWidgets('«ابدأ الآن»: shown once one invited host joined; starts', (
      tester,
    ) async {
      final repo = await sheet(
        tester,
        lobby: pk4LobbyFormatFixture(now: DateTime.now()),
      );
      expect(find.byKey(LivePk4Panel.startNowKey), findsOneWidget);
      expect(find.text('انضم 2 — ابدأ الآن أو انتظر البقية'), findsOneWidget);
      await tester.tap(find.byKey(LivePk4Panel.startNowKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('startLobby'));
    });

    testWidgets('no «ابدأ الآن» with nobody in yet', (tester) async {
      await sheet(
        tester,
        lobby: pk4LobbyFormatFixture(
          now: DateTime.now(),
          states: const [
            Pk4SeatState.invited,
            Pk4SeatState.empty,
            Pk4SeatState.empty,
          ],
        ),
      );
      expect(find.byKey(LivePk4Panel.startNowKey), findsNothing);
    });

    testWidgets('the TEAMS / FREE_FOR_ALL choice and «PK أحكام» open the '
        'lobby with them', (tester) async {
      final repo = await sheet(tester);
      expect(find.text('٢ ضد ٢'), findsOneWidget);
      expect(find.text('الكل ضد الكل'), findsOneWidget);
      await tester.tap(
        find.byKey(LivePk4Panel.formatKey(Pk4Format.freeForAll)),
      );
      await tester.tap(find.byKey(LivePk4Panel.daresKey));
      await tester.pump();
      await tester.tap(find.byKey(LivePk4Panel.openKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('open:FREE_FOR_ALL:DARES'));
    });

    testWidgets('the 4-way random queue: join, the countdown, stop', (
      tester,
    ) async {
      final repo = await sheet(tester);
      await tester.tap(find.byKey(LivePk4Panel.randomKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('random:TEAMS:NORMAL'));
      expect(find.byKey(LivePk4Panel.searchingKey), findsOneWidget);
      expect(find.textContaining('جارٍ البحث عن ٣ مضيفين'), findsOneWidget);
      await tester.tap(find.byKey(LivePk4Panel.stopRandomKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('leaveRandom'));
      expect(find.byKey(LivePk4Panel.openKey), findsOneWidget);
    });

    testWidgets('a FREE_FOR_ALL lobby: every invited place is a player', (
      tester,
    ) async {
      await sheet(
        tester,
        lobby: pk4LobbyFormatFixture(
          now: DateTime.now(),
          format: Pk4Format.freeForAll,
        ),
      );
      expect(find.textContaining('لاعب'), findsNWidgets(3));
      expect(find.textContaining('زميلك'), findsNothing);
    });
  });

  group('the dare card and «جولة أخرى» for four', () {
    final now = DateTime.utc(2026, 11, 13, 10);

    Future<List<String>> dock(
      WidgetTester tester,
      Pk4Match match,
      String roomId,
    ) async {
      final calls = <String>[];
      Future<void> add(String c) async => calls.add(c);
      await pumpScreen(
        tester,
        Scaffold(
          body: Center(
            child:
                LivePk4Stage.dock(
                  match: match,
                  roomId: roomId,
                  now: () => now,
                  isHost: true,
                  actions: PkDareActions(
                    onAccept: () => add('accept'),
                    onRefuse: () => add('refuse'),
                    onVerdict: ({required done}) => add('verdict:$done'),
                  ),
                  rematch: Pk4RematchActions(
                    onOffer: () => add('offer'),
                    onAccept: () => add('rematch:accept'),
                    onDecline: () => add('rematch:decline'),
                    onCancel: () => add('rematch:cancel'),
                  ),
                ) ??
                const SizedBox.shrink(),
          ),
        ),
        language: AppLanguage.ar,
      );
      await tester.pumpAndSettle();
      return calls;
    }

    Pk4Dare dare(PkDareStatus status) => Pk4Dare(
      status: status,
      loserRoomIds: const ['room-2', 'room-3'],
      winnerRoomIds: const ['room-0', 'room-1'],
      options: [
        for (final level in PkDareLevel.values)
          PkDareOption(
            id: 'd-${level.wire}',
            level: level,
            category: 'FUNNY',
            textAr: 'قلّد صوت قطة',
            textEn: 'Do a cat',
          ),
      ],
      drawn: 0,
      revealAt: now.subtract(const Duration(seconds: 1)),
      decideBy: now.add(const Duration(seconds: 25)),
      startedAt: status == PkDareStatus.active ? now : null,
      endsAt: status == PkDareStatus.active
          ? now.add(const Duration(minutes: 3))
          : null,
    );

    testWidgets('a losing host of the team answers for the side', (
      tester,
    ) async {
      final match = pk4PlayersFixture(
        now: now,
        players: 4,
        status: PkMatchStatus.result,
        winner: Pk4Team.a,
        type: PkType.dares,
        dare: dare(PkDareStatus.deciding),
      );
      final calls = await dock(tester, match, 'room-3');
      await tester.tap(find.byKey(PkDareLayer.acceptKey));
      await tester.pumpAndSettle();
      expect(calls, ['accept']);
    });

    testWidgets('a winning host judges the active dare', (tester) async {
      final match = pk4PlayersFixture(
        now: now,
        players: 4,
        status: PkMatchStatus.result,
        winner: Pk4Team.a,
        type: PkType.dares,
        dare: dare(PkDareStatus.active),
      );
      final calls = await dock(tester, match, 'room-1');
      await tester.tap(find.byKey(PkDareLayer.doneKey));
      await tester.pumpAndSettle();
      expect(calls, ['verdict:true']);
    });

    testWidgets('«جولة أخرى»: offer; another’s offer → accept / decline; '
        'accepted → waiting', (tester) async {
      final base = pk4PlayersFixture(
        now: now,
        players: 3,
        status: PkMatchStatus.result,
        winner: Pk4Team.a,
      );
      var calls = await dock(tester, base, 'room-0');
      expect(find.text('العب جولة أخرى مع الجميع؟'), findsOneWidget);
      await tester.tap(find.byKey(Pk4RematchDock.offerKey));
      await tester.pumpAndSettle();
      expect(calls, ['offer']);
      final offered = pk4PlayersFixture(
        now: now,
        players: 3,
        status: PkMatchStatus.result,
        winner: Pk4Team.a,
        rematch: Pk4Rematch(
          byRoomId: 'room-1',
          expiresAt: now.add(const Duration(seconds: 12)),
          acceptedRoomIds: const ['room-1'],
          waitingRoomIds: const ['room-0', 'room-2'],
        ),
      );
      calls = await dock(tester, offered, 'room-0');
      expect(find.byKey(Pk4RematchDock.promptKey), findsOneWidget);
      await tester.tap(find.byKey(Pk4RematchDock.acceptKey));
      await tester.pumpAndSettle();
      expect(calls, ['rematch:accept']);
      await dock(tester, offered, 'room-1');
      expect(find.byKey(Pk4RematchDock.waitingKey), findsOneWidget);
      expect(find.text('بانتظار موافقة 2…'), findsOneWidget);
      // A host out of the battle is not present: nothing.
      final out = pk4PlayersFixture(
        now: now,
        players: 3,
        status: PkMatchStatus.result,
        winner: Pk4Team.a,
        out: const [0],
      );
      expect(Pk4RematchDock.shows(out, 'room-0'), isFalse);
      expect(
        LivePk4Stage.dock(match: out, roomId: 'room-0', now: () => now),
        isNull,
      );
    });
  });

  group('the controller', () {
    testWidgets('the random wait ran out → «لم نجد مضيفين كافيين»; a late '
        'message of a rematched match never clears the new battle', (
      tester,
    ) async {
      final now = DateTime.now();
      final repo = FakeLivePk4Repository();
      final container = ProviderContainer(
        overrides: [livePk4RepositoryProvider.overrideWithValue(repo)],
      );
      final events = StreamController<Pk4Event>();
      addTearDown(events.close);
      final sub = container.listen(livePk4Provider('room-0'), (_, _) {});
      final controller = container.read(livePk4Provider('room-0').notifier)
        ..attach(events.stream, host: true)
        ..debugSetQueue(
          Pk4Queue(
            format: Pk4Format.teams,
            expiresAt: now.add(const Duration(minutes: 1)),
          ),
        );
      expect(container.read(livePk4Provider('room-0')).searching, isTrue);
      events.add(const Pk4QueueEvent(matched: false));
      await tester.pump();
      final s = container.read(livePk4Provider('room-0'));
      expect(s.queue, isNull);
      expect(s.notice, Pk4Notice.queueExpired);
      // The new battle (a rematch) is in place; the old match's `closed`
      // arrives late.
      final fresh = pk4PlayersFixture(now: now, players: 3);
      controller.debugSetMatch(fresh);
      final old = pk4PlayersFixture(
        now: now,
        players: 4,
        status: PkMatchStatus.closed,
      );
      events.add(Pk4MatchEvent(event: 'closed', match: old));
      await tester.pump();
      expect(container.read(livePk4Provider('room-0')).match?.id, fresh.id);
      // The refresh timer stops with the room.
      sub.close();
      container.dispose();
    });
  });
}
