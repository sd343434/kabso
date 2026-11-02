// D168: Ludo inside the live room — the board in the prototype's layout
// (every piece where the prototype puts it), the player's turn (the die,
// a choice of pieces), a spectator, the lobby, the winner card, the `ludo`
// data message, versions only growing, and Arabic RTL (the panel mirrors,
// the board does not). Fixture games only; the server decides everything.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/games/ludo/application/ludo_controller.dart';
import 'package:kabso_live/features/live/games/ludo/data/ludo_repository.dart';
import 'package:kabso_live/features/live/games/ludo/domain/ludo_board.dart';
import 'package:kabso_live/features/live/games/ludo/domain/ludo_game.dart';
import 'package:kabso_live/features/live/games/ludo/presentation/ludo_board_view.dart';
import 'package:kabso_live/features/live/games/ludo/presentation/ludo_panel.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_ludo_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';

const _room = 'room-1';
final User _me = testUser();

Map<String, dynamic> _seat(
  int seat,
  String? userId,
  String? name,
  List<int> pieces, {
  bool auto = false,
}) => {
  'seat': seat,
  'color': ['RED', 'GREEN', 'YELLOW', 'BLUE'][seat],
  'user': userId == null
      ? null
      : {
          'id': userId,
          'username': name!.toLowerCase(),
          'displayName': name,
          'avatarUrl': null,
        },
  'auto': auto,
  'pieces': pieces,
};

/// A game as the server sends it (CONVENTIONS §10.42).
LudoGame _game({
  String status = 'PLAYING',
  int version = 5,
  int? turn = 0,
  String? phase = 'ROLL',
  int? dice,
  List<int> movable = const [],
  int? winner,
  List<Map<String, dynamic>>? seats,
  List<Map<String, dynamic>> events = const [],
}) => LudoGame.fromJson({
  'id': 'g1',
  'roomId': _room,
  'status': status,
  'mode': 'CLASSIC',
  'maxPlayers': 4,
  'piecesPerPlayer': 4,
  'version': version,
  'seats':
      seats ??
      [
        _seat(0, _me.id, _me.displayName, [-1, 5, -1, 57]),
        _seat(1, 'u-sara', 'Sara', [-1, -1, -1, -1], auto: true),
        _seat(2, 'u-omar', 'Omar', [10, -1, -1, -1]),
        _seat(3, 'u-nabil', 'Nabil', [-1, -1, 53, -1]),
      ],
  'turn': status == 'PLAYING' ? turn : null,
  'phase': status == 'PLAYING' ? phase : null,
  'dice': dice,
  'sixes': 0,
  'movable': movable,
  'turnEndsAt': '2026-11-02T12:00:15.000Z',
  'turnSeconds': 15,
  'winner': winner,
  'events': events,
  'serverTime': '2026-11-02T12:00:00.000Z',
  'createdAt': '2026-11-02T11:59:00.000Z',
  'startedAt': '2026-11-02T11:59:30.000Z',
  'endedAt': null,
});

/// The room's lower part with the Ludo layer, as in the live room.
Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeLudoRepository repo, {
  AppLanguage language = AppLanguage.en,
  bool host = false,
  bool signedIn = true,
}) async {
  setViewport(tester, GoldenViewport.phone);
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      ludoRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(signedIn ? _me : null),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(
          brightness: Brightness.dark,
          locale: language.locale,
        ),
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: app!,
        ),
        home: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFF3B1B9E)),
              ),
              LiveLudoLayer(roomId: _room, host: host),
            ],
          ),
        ),
      ),
    ),
  );
  await container.read(liveLudoProvider(_room).notifier).load();
  container.read(liveLudoProvider(_room).notifier).show();
  await tester.pump();
  return container;
}

String _status(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(LudoKeys.status)).data!;

void main() {
  group('D168 Ludo board geometry (the prototype)', () {
    test('52 track and 20 home squares, none on a base or the centre', () {
      expect(LudoBoard.track, hasLength(52));
      expect(LudoBoard.track.toSet(), hasLength(52));
      final homes = [for (final h in LudoBoard.home) ...h];
      expect(homes.toSet(), hasLength(20));
      bool inBase((int, int) cell) => LudoBoard.base.any(
        (b) =>
            cell.$1 >= b.$1 &&
            cell.$1 < b.$1 + 6 &&
            cell.$2 >= b.$2 &&
            cell.$2 < b.$2 + 6,
      );
      bool inCentre((int, int) cell) =>
          cell.$1 >= 6 && cell.$1 < 9 && cell.$2 >= 6 && cell.$2 < 9;
      for (final cell in [...LudoBoard.track, ...homes]) {
        expect(inBase(cell) || inCentre(cell), isFalse, reason: '$cell');
      }
      // Neighbouring squares of the track touch (a closed loop).
      for (var i = 0; i < 52; i++) {
        final (r, c) = LudoBoard.track[i];
        final (r2, c2) = LudoBoard.track[(i + 1) % 52];
        expect(
          (r - r2).abs() + (c - c2).abs(),
          lessThanOrEqualTo(2),
          reason: '$i',
        );
      }
    });

    test('pieces sit where the prototype puts them', () {
      // Red's base slots, its start square, a home square and the centre.
      expect(LudoBoard.cellOf(0, -1, 0).dx, closeTo(1.988, 0.001));
      expect(
        LudoBoard.cellOf(0, -1, 3),
        Offset(LudoBoard.cellOf(0, -1, 1).dx, LudoBoard.cellOf(0, -1, 2).dy),
      );
      expect(LudoBoard.cellOf(0, 0, 0), const Offset(1.5, 6.5));
      expect(LudoBoard.cellOf(1, 0, 0), const Offset(8.5, 1.5));
      expect(LudoBoard.cellOf(2, 52, 0), const Offset(13.5, 7.5));
      expect(LudoBoard.cellOf(3, 57, 0), const Offset(7.5, 8.25));
      expect(LudoBoard.square(3, 13), 0);
      expect(LudoBoard.points([-1, 0, 56, 57]), 100 + 5700 + 5800);
    });
  });

  group('D168 the ludo data message', () {
    test('parses as a LiveLudoChanged event', () {
      final event = LiveChatEvent.parse({
        'type': 'ludo',
        'game': {
          'id': 'g1',
          'roomId': _room,
          'status': 'LOBBY',
          'mode': 'QUICK',
          'maxPlayers': 2,
          'piecesPerPlayer': 2,
          'version': 0,
          'seats': [
            _seat(0, null, null, const []),
            _seat(2, null, null, const []),
          ],
          'turn': null,
          'phase': null,
          'dice': null,
          'sixes': 0,
          'movable': <int>[],
          'turnEndsAt': null,
          'turnSeconds': 15,
          'winner': null,
          'events': <Object>[],
          'serverTime': '2026-11-02T12:00:00.000Z',
          'createdAt': '2026-11-02T12:00:00.000Z',
          'startedAt': null,
          'endedAt': null,
        },
      });
      expect(event, isA<LiveLudoChanged>());
      final game = (event! as LiveLudoChanged).game;
      expect(game.quick, isTrue);
      expect(game.status, LudoStatus.lobby);
      expect(game.seats.map((s) => s.seat), [0, 2]);
    });
  });

  group('D168 the Ludo panel', () {
    testWidgets('the board with every piece of every seat and the chips', (
      tester,
    ) async {
      await _pump(tester, FakeLudoRepository(game: _game()));
      expect(find.byKey(LudoKeys.panel), findsOneWidget);
      expect(find.byKey(LudoKeys.board), findsOneWidget);
      for (var seat = 0; seat < 4; seat++) {
        expect(find.byKey(LudoKeys.chip(seat)), findsOneWidget);
        expect(find.byKey(LudoKeys.tabs(seat)), findsOneWidget);
        for (var i = 0; i < 4; i++) {
          expect(find.byKey(LudoKeys.piece(seat, i)), findsOneWidget);
        }
      }
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 4'), findsOneWidget);
      expect(find.text('AUTO'), findsOneWidget);
      // The rank pill: the two leading seats' progress points.
      expect(find.text('RANK 1'), findsOneWidget);
      expect(find.text('6400'), findsOneWidget); // red: 5 → 600, 57 → 5800
      expect(find.text('5400'), findsOneWidget); // blue: 53 → 5400
      // The prototype's layout: red top-left, green top-right, yellow
      // bottom-right, blue bottom-left; a piece on its square.
      final board = tester.getRect(find.byKey(LudoKeys.board));
      final u = board.width / 15;
      Offset centreOf(int seat, int i) =>
          tester.getCenter(find.byKey(LudoKeys.piece(seat, i))) - board.topLeft;
      expect(centreOf(0, 0).dx, closeTo(1.988 * u, 1));
      expect(centreOf(0, 0).dy, closeTo(1.988 * u, 1));
      expect(
        centreOf(0, 1),
        offsetMoreOrLessEquals(const Offset(6.5, 5.5) * u, epsilon: 1),
      );
      expect(centreOf(1, 0).dx, greaterThan(9 * u));
      expect(
        centreOf(2, 0),
        offsetMoreOrLessEquals(LudoBoard.cellOf(2, 10, 0) * u, epsilon: 1),
      );
      expect(centreOf(3, 0).dy, greaterThan(9 * u));
      expect(centreOf(3, 0).dx, lessThan(6 * u));
    });

    testWidgets('your turn: the die on your base; a tap rolls (an intent)', (
      tester,
    ) async {
      final repo = FakeLudoRepository(game: _game());
      await _pump(tester, repo);
      expect(_status(tester), 'Your turn: tap the die');
      expect(find.bySemanticsLabel('Roll the die'), findsOneWidget);
      final board = tester.getRect(find.byKey(LudoKeys.board));
      final die = tester.getCenter(find.byKey(LudoKeys.die)) - board.topLeft;
      expect(
        die,
        offsetMoreOrLessEquals(
          const Offset(4.4, 0.35) * (board.width / 15),
          epsilon: 1,
        ),
      );
      repo.next = _game(version: 6, phase: 'MOVE', dice: 6, movable: [0, 1, 2]);
      await tester.tap(find.byKey(LudoKeys.die));
      await tester.pump();
      expect(repo.calls, ['roll 5']);
      expect(_status(tester), 'You rolled 6: choose a plane');
      await tester.tap(find.byKey(LudoKeys.piece(0, 2)));
      await tester.pump();
      expect(repo.calls.last, 'move 6 2');
    });

    testWidgets('a spectator: no die to roll, the turn is named', (
      tester,
    ) async {
      final repo = FakeLudoRepository(
        game: _game(
          turn: 2,
          seats: [
            _seat(0, 'u-layan', 'Layan', [-1, -1, -1, -1]),
            _seat(2, 'u-omar', 'Omar', [10, -1, -1, -1]),
          ],
        ),
      );
      await _pump(tester, repo);
      expect(_status(tester), 'Turn: Omar… · You are watching');
      expect(find.bySemanticsLabel('Roll the die'), findsNothing);
      await tester.tap(find.byKey(LudoKeys.die));
      await tester.pump();
      expect(repo.calls, isEmpty);
      expect(find.byKey(LudoKeys.chip(1)), findsNothing);
    });

    testWidgets('the lobby: free seats; the host starts with 2 seated', (
      tester,
    ) async {
      final lobby = _game(
        status: 'LOBBY',
        version: 2,
        seats: [
          _seat(0, 'u-layan', 'Layan', const []),
          _seat(1, null, null, const []),
          _seat(2, 'u-omar', 'Omar', const []),
          _seat(3, null, null, const []),
        ],
      );
      final repo = FakeLudoRepository(game: lobby);
      await _pump(tester, repo, host: true);
      expect(_status(tester), 'Waiting for players (2/4)');
      expect(find.text('Sit'), findsNWidgets(2));
      await tester.tap(find.byKey(LudoKeys.chip(3)));
      await tester.pump();
      expect(repo.calls, ['seat 3']);
      await tester.tap(find.byKey(LudoKeys.start));
      await tester.pump();
      expect(repo.calls.last, 'start 2');
    });

    testWidgets('the winner card', (tester) async {
      await _pump(
        tester,
        FakeLudoRepository(game: _game(status: 'FINISHED', winner: 2)),
      );
      expect(find.byKey(LudoKeys.winner), findsOneWidget);
      expect(find.text('Omar won'), findsWidgets);
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(find.byKey(LudoKeys.panel), findsNothing);
    });

    testWidgets('you won', (tester) async {
      await _pump(
        tester,
        FakeLudoRepository(game: _game(status: 'FINISHED', winner: 0)),
      );
      expect(find.text('You won the round!'), findsOneWidget);
    });

    testWidgets('Arabic: the panel is RTL, the board is not mirrored', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeLudoRepository(game: _game()),
        language: AppLanguage.ar,
      );
      expect(_status(tester), 'دورك: اضغط على النرد');
      expect(find.text('اللاعب 1'), findsOneWidget);
      // Close at the right (the reading start), fold at the left.
      expect(
        tester.getCenter(find.byKey(LudoKeys.close)).dx,
        greaterThan(tester.getCenter(find.byKey(LudoKeys.collapse)).dx),
      );
      // Red stays top-left.
      expect(
        tester.getCenter(find.byKey(LudoKeys.piece(0, 0))).dx,
        lessThan(tester.getCenter(find.byKey(LudoKeys.piece(1, 0))).dx),
      );
    });

    testWidgets('folds to its bar and opens again', (tester) async {
      await _pump(tester, FakeLudoRepository(game: _game()));
      await tester.tap(find.byKey(LudoKeys.collapse));
      await tester.pump();
      expect(find.byKey(LudoKeys.board), findsNothing);
      expect(
        tester.getSize(find.byKey(LudoKeys.panel)).height,
        LiveLudoLayer.foldedHeight,
      );
      await tester.tap(find.byKey(LudoKeys.collapse));
      await tester.pump();
      expect(find.byKey(LudoKeys.board), findsOneWidget);
    });

    testWidgets('a spectator closes the panel; the banner reopens it', (
      tester,
    ) async {
      await _pump(
        tester,
        FakeLudoRepository(
          game: _game(
            seats: [
              _seat(0, 'u-layan', 'Layan', [-1, -1, -1, -1]),
              _seat(2, 'u-omar', 'Omar', [10, -1, -1, -1]),
            ],
          ),
        ),
      );
      await tester.tap(find.byKey(LudoKeys.close));
      await tester.pump();
      expect(find.byKey(LudoKeys.panel), findsNothing);
      expect(find.text('Ludo: watch the game'), findsOneWidget);
      await tester.tap(find.byKey(LudoKeys.banner));
      await tester.pump();
      expect(find.byKey(LudoKeys.panel), findsOneWidget);
    });
  });

  group('D168 the controller', () {
    test('keeps the newest version; an ended game goes away', () {
      final container = ProviderContainer(
        overrides: [
          ludoRepositoryProvider.overrideWithValue(FakeLudoRepository()),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(liveLudoProvider(_room).notifier)
        ..apply(_game(version: 7));
      expect(container.read(liveLudoProvider(_room)).game?.version, 7);
      controller.apply(_game(version: 6));
      expect(container.read(liveLudoProvider(_room)).game?.version, 7);
      controller.apply(_game(version: 8, turn: 2));
      expect(container.read(liveLudoProvider(_room)).game?.turn, 2);
      controller.apply(_game(status: 'ENDED', version: 9));
      expect(container.read(liveLudoProvider(_room)).game, isNull);
      // Another room's game is not this room's.
      controller.apply(LudoGame.fromJson({..._json(), 'roomId': 'other'}));
      expect(container.read(liveLudoProvider(_room)).game, isNull);
    });
  });
}

Map<String, dynamic> _json() => {
  'id': 'g2',
  'roomId': _room,
  'status': 'LOBBY',
  'mode': 'CLASSIC',
  'maxPlayers': 4,
  'version': 0,
  'seats': [_seat(0, null, null, const []), _seat(2, null, null, const [])],
  'serverTime': '2026-11-02T12:00:00.000Z',
};
