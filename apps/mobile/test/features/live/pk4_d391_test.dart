// D391 (v1.118-live, CONVENTIONS §10.180, CP-041 phase 2) «PK رباعي»: the
// 4-way PK's data (the contract's shapes and the `pk4-*` messages), the
// room's controller (the highest `seq`, the three other rooms' connections
// on the lowest layer for viewers, the host's mutes, closed at the end, the
// lobby messages), the 2 × 2 stage (this room's team on the reading start
// with this room's host at the top, each host's own score, the team bar, the
// mute switches for a host only, a host who left) at 393 × 852 and 360 × 800
// with text × 1.3 in ar and en, the lobby sheet and the incoming invitation.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_pk4_controller.dart';
import 'package:kabso_live/features/live/data/live_pk4_media.dart';
import 'package:kabso_live/features/live/data/live_pk4_repository.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/domain/live_pk4.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk4_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk4_stage.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_pk4.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _user(String id, String name) => {
  'id': id,
  'username': id.replaceAll('-', '_'),
  'displayName': name,
  'avatarUrl': null,
};

/// A `Pk4Match` exactly as the contract's schema lays it out.
Map<String, dynamic> _matchJson({int seq = 7, String status = 'BATTLE'}) => {
  'id': '0192f1d0-0000-7000-8000-000000000001',
  'format': 'TEAMS',
  'status': status,
  'startedAt': '2026-11-13T10:00:00.000Z',
  'battleEndsAt': '2026-11-13T10:05:00.000Z',
  'endedAt': null,
  'resultEndsAt': null,
  'endReason': null,
  'winnerTeam': null,
  'seq': seq,
  'serverTime': '2026-11-13T10:02:00.000Z',
  'roundSeconds': 300,
  'connectedAt': null,
  'effective': null,
  'organiserRoomId': 'room-0',
  'teams': [
    {
      'team': 'B',
      'score': 300,
      'result': null,
      'boost': null,
      'boosterUses': {
        'DOUBLE': 0,
        'DOUBLE_TURBO': 0,
        'TRIPLE': 0,
        'TRIPLE_TURBO': 0,
      },
      'supporters': <Object>[],
    },
    {
      'team': 'A',
      'score': 1400,
      'result': null,
      'boost': {
        'id': 'b1',
        'kind': 'DOUBLE',
        'multiplier': 2,
        'startsAt': '2026-11-13T10:01:50.000Z',
        'endsAt': '2026-11-13T10:02:20.000Z',
        'sender': null,
      },
      'boosterUses': {
        'DOUBLE': 1,
        'DOUBLE_TURBO': 0,
        'TRIPLE': 0,
        'TRIPLE_TURBO': 0,
      },
      'supporters': [
        {'user': _user('fan-1', 'Fan'), 'points': 1400},
      ],
    },
  ],
  'seats': [
    for (var i = 4; i >= 1; i--)
      {
        'seat': i,
        'team': i <= 2 ? 'A' : 'B',
        'roomId': 'room-${i - 1}',
        'host': _user('user-${i - 1}', 'Host $i'),
        'score': i * 100,
        'out': i == 1,
        'outReason': i == 1 ? 'FORFEIT' : null,
        'mutedRoomIds': i == 1 ? ['room-2'] : <String>[],
        'pkPoints': 3,
      },
  ],
  'boosters': <Object>[],
};

void main() {
  group('the data', () {
    test('a Pk4Match from the contract: teams by letter, places in order', () {
      final m = Pk4Match.fromJson(_matchJson());
      expect(m.teams.$1.team, Pk4Team.a);
      expect(m.teams.$1.score, 1400);
      expect(m.teams.$1.boost?.kind, PkBoosterKind.double);
      expect(m.seats.map((s) => s.seat), [1, 2, 3, 4]);
      expect(m.seatOf('room-0')!.out, isTrue);
      expect(m.seatOf('room-0')!.outReason, PkEndReason.forfeit);
      expect(m.seatOf('room-0')!.mutedRoomIds, ['room-2']);
      expect(m.teamOf('room-3'), Pk4Team.b);
      expect(m.seatsOf(Pk4Team.a, first: 'room-1').first.roomId, 'room-1');
      // The gift panel's booster tab reads the team's battle.
      final view = m.boosterView('room-1');
      expect(view.status, PkMatchStatus.battle);
      expect(view.of('room-1').$1.boost?.kind, PkBoosterKind.double);
      expect(view.of('room-1').$1.boosterUses[PkBoosterKind.double], 1);
    });

    test('the `pk4-*` messages; anything else is not a 4-way message', () {
      final match = Pk4Event.parse({
        'type': 'pk4-match',
        'event': 'boost',
        'match': _matchJson(),
        'boost': {
          'team': 'A',
          'roomId': 'room-1',
          'kind': 'DOUBLE',
          'multiplier': 2,
          'endsAt': '2026-11-13T10:02:20.000Z',
        },
      });
      expect(match, isA<Pk4MatchEvent>());
      expect((match! as Pk4MatchEvent).boostTeam, Pk4Team.a);
      final lobby = Pk4Event.parse({
        'type': 'pk4-lobby',
        'event': 'expired',
        'lobby': {
          'id': 'l1',
          'format': 'TEAMS',
          'status': 'EXPIRED',
          'organiserRoomId': 'room-0',
          'createdAt': '2026-11-13T10:00:00.000Z',
          'expiresAt': '2026-11-13T10:02:00.000Z',
          'matchId': null,
          'serverTime': '2026-11-13T10:02:00.000Z',
          'seats': [
            {
              'seat': 1,
              'team': 'A',
              'role': 'ORGANISER',
              'state': 'ACCEPTED',
              'roomId': 'room-0',
              'host': _user('user-0', 'Sara'),
              'invite': null,
            },
          ],
        },
      });
      expect((lobby! as Pk4LobbyEvent).lobby.open, isFalse);
      expect(Pk4Event.parse({'type': 'pk-match'}), isNull);
      expect(Pk4Event.parse({'type': 'pk4-match', 'match': 'x'}), isNull);
    });
  });

  group('the room controller', () {
    late FakeLivePk4Repository repo;
    late List<FakePk4RoomMedia> made;
    late ProviderContainer container;

    setUp(() {
      repo = FakeLivePk4Repository();
      made = [];
      container = ProviderContainer(
        overrides: [
          currentUserProvider.overrideWithValue(testUser()),
          livePk4RepositoryProvider.overrideWithValue(repo),
          livePk4RoomMediaFactoryProvider.overrideWithValue(() {
            final m = FakePk4RoomMedia();
            made.add(m);
            return m;
          }),
        ],
      );
      addTearDown(container.dispose);
    });

    test(
      'three other rooms, the lowest layer, the mutes; closed → left',
      () async {
        final now = DateTime.now();
        repo.access = const Pk4MediaAccess(
          url: 'ws://media',
          rooms: [
            Pk4MediaRoom(
              roomId: 'room-1',
              token: 't1',
              identity: 'pk4:m:me',
              hostIdentity: 'user-1',
            ),
            Pk4MediaRoom(
              roomId: 'room-2',
              token: 't2',
              identity: 'pk4:m:me',
              hostIdentity: 'user-2',
            ),
            Pk4MediaRoom(
              roomId: 'room-3',
              token: 't3',
              identity: 'pk4:m:me',
              hostIdentity: 'user-3',
            ),
          ],
        );
        final sub = container.listen(livePk4Provider('room-0'), (_, _) {});
        addTearDown(sub.close);
        final controller = container.read(livePk4Provider('room-0').notifier)
          ..debugSetMatch(
            pk4MatchFixture(now: now, mutedByMe: const ['room-2']),
          );
        await pumpEventQueue();
        expect(repo.calls, contains('media'));
        expect(made, hasLength(3));
        expect(made.every((m) => m.joined && m.low == true), isTrue);
        expect(controller.rooms.keys, ['room-1', 'room-2', 'room-3']);
        expect(controller.rooms['room-2']!.audioMuted, isTrue);
        expect(controller.rooms['room-1']!.audioMuted, isFalse);
        expect(container.read(livePk4Provider('room-0')).joined, 3);
        // A hidden stage pauses the video (the sound stays).
        await controller.setVideoPaused(paused: true);
        expect(made.every((m) => m.paused), isTrue);
        // An older message never replaces a newer one.
        controller.debugSetMatch(pk4MatchFixture(now: now, seq: 9));
        expect(container.read(livePk4Provider('room-0')).match!.seq, 9);
        // Closed: every connection is left.
        controller.debugSetMatch(null);
        await pumpEventQueue();
        expect(made.every((m) => !m.joined), isTrue);
        expect(controller.rooms, isEmpty);
      },
    );
  });

  group('the 2 × 2 stage', () {
    Future<List<(int, bool)>> stage(
      WidgetTester tester,
      Pk4Match match, {
      AppLanguage language = AppLanguage.ar,
      GoldenViewport viewport = GoldenViewport.phone,
      double textScale = 1,
      bool isHost = false,
    }) async {
      await loadAppFonts();
      setViewport(tester, viewport);
      final mutes = <(int, bool)>[];
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
                isHost: isHost,
                onMute: (seat, {required muted}) =>
                    mutes.add((seat.seat, muted)),
              ),
            ),
          ),
        ),
        language: language,
      );
      await tester.pumpAndSettle();
      return mutes;
    }

    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      testWidgets('this team on the reading start, this host at the top '
          '(${language.name})', (tester) async {
        final match = pk4MatchFixture(now: DateTime.now());
        await stage(tester, match, language: language);
        final own = tester.getCenter(find.byKey(LivePk4Stage.paneKey(1)));
        final mate = tester.getCenter(find.byKey(LivePk4Stage.paneKey(2)));
        final opponent = tester.getCenter(find.byKey(LivePk4Stage.paneKey(3)));
        final mid =
            tester.view.physicalSize.width / tester.view.devicePixelRatio / 2;
        final rtl = language == AppLanguage.ar;
        expect(own.dx > mid, rtl);
        expect(opponent.dx > mid, !rtl);
        expect(own.dx, mate.dx);
        expect(own.dy < mate.dy, isTrue);
        // Each host's own score under their pane.
        expect(
          find.descendant(
            of: find.byKey(LivePk4Stage.scoreKey(3)),
            matching: find.byType(Text),
          ),
          findsOneWidget,
        );
        expect(find.byKey(LivePk4Stage.barKey), findsOneWidget);
        expect(find.byKey(LivePk4Stage.timerKey), findsOneWidget);
      });
    }

    testWidgets('a host mutes any of the other three; a viewer has no switch', (
      tester,
    ) async {
      final match = pk4MatchFixture(now: DateTime.now(), mutedByMe: ['room-2']);
      final mutes = await stage(tester, match, isHost: true);
      expect(find.byKey(LivePk4Stage.muteKey(1)), findsNothing);
      for (final seat in [2, 3, 4]) {
        expect(find.byKey(LivePk4Stage.muteKey(seat)), findsOneWidget);
      }
      await tester.tap(find.byKey(LivePk4Stage.muteKey(3)));
      await tester.tap(find.byKey(LivePk4Stage.muteKey(4)));
      expect(mutes, [(3, false), (4, true)]);
      await stage(tester, match);
      expect(find.byKey(LivePk4Stage.muteKey(2)), findsNothing);
    });

    testWidgets('a host who left; a team booster; the result', (tester) async {
      final now = DateTime.now();
      await stage(
        tester,
        pk4MatchFixture(now: now, out: [2], boostA: PkBoosterKind.triple),
      );
      expect(find.text('غادر'), findsOneWidget);
      expect(find.byKey(LivePk4Stage.boostKey(Pk4Team.a)), findsOneWidget);
      expect(find.byKey(LivePk4Stage.boostKey(Pk4Team.b)), findsNothing);
      await stage(
        tester,
        pk4MatchFixture(
          now: now,
          status: PkMatchStatus.result,
          winner: Pk4Team.a,
        ),
      );
      expect(find.byKey(LivePk4Stage.resultKey), findsOneWidget);
      expect(find.text('فاز فريقكم'), findsOneWidget);
      expect(find.byKey(LivePk4Stage.timerKey), findsNothing);
    });

    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      for (final status in [PkMatchStatus.battle, PkMatchStatus.result]) {
        testWidgets('no overflow at 360 × 800 × 1.3 '
            '(${language.name}, ${status.name})', (tester) async {
          await stage(
            tester,
            pk4MatchFixture(
              now: DateTime.now(),
              ar: language == AppLanguage.ar,
              status: status,
              winner: Pk4Team.b,
              boostB: PkBoosterKind.tripleTurbo,
              out: const [4],
              scores: const [98765432, 1234567, 87654321, 7654321],
            ),
            language: language,
            viewport: GoldenViewport.android,
            textScale: 1.3,
            isHost: true,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('the lobby sheet', () {
    Future<FakeLivePk4Repository> sheet(
      WidgetTester tester, {
      Pk4Lobby? lobby,
      AppLanguage language = AppLanguage.ar,
      GoldenViewport viewport = GoldenViewport.phone,
      double textScale = 1,
    }) async {
      await loadAppFonts();
      setViewport(tester, viewport);
      final now = DateTime.now();
      final repo =
          FakeLivePk4Repository(
              snapshot: Pk4State(lobby: lobby),
              list: [
                PkCandidate(
                  roomId: 'room-9',
                  title: 'Live',
                  viewerCount: 12,
                  host: pk4User('user-9', 'Nora'),
                ),
              ],
            )
            ..lobbyOnOpen = pk4LobbyFixture(
              now: now,
              states: const [
                Pk4SeatState.empty,
                Pk4SeatState.empty,
                Pk4SeatState.empty,
              ],
            )
            ..lobbyOnInvite = pk4LobbyFixture(now: now);
      await pumpScreen(
        tester,
        MediaQuery(
          data: MediaQueryData(
            size: viewport.logicalSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(livePk4Provider('room-0'));
              return const Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: LivePk4Sheet(roomId: 'room-0'),
                ),
              );
            },
          ),
        ),
        language: language,
        brightness: Brightness.light,
        livePk4Repository: repo,
      );
      final element = tester.element(find.byType(LivePk4Sheet));
      final container = ProviderScope.containerOf(element);
      final controller = container.read(livePk4Provider('room-0').notifier)
        ..attach(const Stream.empty(), host: true);
      if (lobby != null) controller.debugSetLobby(lobby);
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('open a lobby, pick a place, invite a candidate', (
      tester,
    ) async {
      final repo = await sheet(tester);
      await tester.tap(find.byKey(LivePk4Sheet.openKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('open'));
      expect(find.byKey(LivePk4Sheet.placeKey(4)), findsOneWidget);
      await tester.tap(find.byKey(LivePk4Sheet.placeKey(4)));
      await tester.pumpAndSettle();
      expect(find.byKey(LivePk4Sheet.candidateKey('room-9')), findsOneWidget);
      await tester.tap(
        find
            .descendant(
              of: find.byKey(LivePk4Sheet.candidateKey('room-9')),
              matching: find.byType(InkWell),
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(repo.calls, contains('invite:room-9:4'));
      // The returned lobby: place 2 ready, 3 waiting (with withdraw), 4 free.
      expect(find.byKey(LivePk4Sheet.withdrawKey(3)), findsOneWidget);
      // The snapshot read after the withdrawal still has the lobby.
      repo.snapshot = Pk4State(lobby: repo.lobbyOnInvite);
      await tester.tap(find.byKey(LivePk4Sheet.withdrawKey(3)));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('cancel:invite-3'));
      await tester.tap(find.byKey(LivePk4Sheet.cancelKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('close'));
    });

    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      testWidgets('no overflow at 360 × 800 × 1.3 (${language.name})', (
        tester,
      ) async {
        await sheet(
          tester,
          lobby: pk4LobbyFixture(
            now: DateTime.now(),
            ar: language == AppLanguage.ar,
          ),
          language: language,
          viewport: GoldenViewport.android,
          textScale: 1.3,
        );
        expect(find.byKey(LivePk4Sheet.placeKey(2)), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the incoming invitation', () {
    for (final answer in ['accept', 'decline']) {
      testWidgets('«$answer» answers the invitation', (tester) async {
        final now = DateTime.now();
        final repo = FakeLivePk4Repository();
        final invite = pk4LobbyFixture(now: now).seat(3).invite!;
        await pumpScreen(
          tester,
          Consumer(
            builder: (context, ref, _) {
              final pk4 = ref.watch(livePk4Provider('room-2'));
              return Scaffold(
                backgroundColor: const Color(0xFF000000),
                body: pk4.incoming == null
                    ? const SizedBox.shrink()
                    : LivePk4IncomingInvite(
                        roomId: 'room-2',
                        invite: pk4.incoming!,
                      ),
              );
            },
          ),
          language: AppLanguage.ar,
          livePk4Repository: repo,
        );
        final element = tester.element(find.byType(Scaffold));
        ProviderScope.containerOf(element)
            .read(livePk4Provider('room-2').notifier)
            .debugSetIncoming(invite);
        await tester.pumpAndSettle();
        expect(find.text('دعوة PK رباعي'), findsOneWidget);
        await tester.tap(
          find.byKey(
            answer == 'accept'
                ? LivePk4IncomingInvite.acceptKey
                : LivePk4IncomingInvite.declineKey,
          ),
        );
        await tester.pumpAndSettle();
        expect(repo.calls, contains('$answer:invite-3'));
        expect(find.byType(LivePk4IncomingInvite), findsNothing);
      });
    }
  });
}
