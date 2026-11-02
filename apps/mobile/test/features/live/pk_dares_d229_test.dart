// D229 (v1.50-live, CONVENTIONS §10.80): «PK أحكام» in the app — the parse of
// the contract's shapes, the PK sheet's type choice (invitations and the
// random match labelled and sent with the type), the incoming card's
// «PK أحكام», and the dare layer over the PK stage: the draw (three cards,
// one per level), the loser's «قبول» / «رفض» (with the \u22123 confirm) and its
// ring, everyone else waiting, the banner with its countdown and ⚠️, the
// winner's «نُفّذ» / «لم يُنفّذ», the outcomes, and the record's points —
// ar and en, 393×852 and 360×800 at text 1.0 / 1.3, no overflow.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_dare.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_pages.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_pk.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Map<String, dynamic> _dareJson(String status, {String? cause}) => {
  'status': status,
  'cause': cause,
  'loserRoomId': 'room-0',
  'winnerRoomId': 'room-b',
  'options': [
    for (final (i, level) in ['EASY', 'MEDIUM', 'HARD'].indexed)
      {
        'id': 'd$i',
        'level': level,
        'category': 'FUNNY',
        'textAr': 'حكم $i',
        'textEn': 'Dare $i',
      },
  ],
  'drawn': 2,
  'revealAt': '2026-11-01T10:00:04.000Z',
  'decideBy': '2026-11-01T10:00:34.000Z',
  'startedAt': null,
  'endsAt': null,
  'finishedAt': null,
  'points': cause == null ? 0 : -3,
  'refusePoints': -5,
};

class _Calls {
  final List<String> list = [];
  PkDareActions actions({bool report = true}) => PkDareActions(
    onAccept: () async => list.add('accept'),
    onRefuse: () async => list.add('refuse'),
    onVerdict: ({required done}) async => list.add('verdict:$done'),
    onReport: report ? (id) async => list.add('report:$id') : null,
  );
}

Future<void> _pumpStage(
  WidgetTester tester,
  PkMatch match, {
  required DateTime now,
  bool isHost = false,
  PkDareActions actions = const PkDareActions(),
  AppLanguage language = AppLanguage.ar,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  bool reduced = true,
}) async {
  setViewport(tester, viewport);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await pumpScreen(
    tester,
    Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: MediaQuery(
        data: MediaQueryData(
          size: viewport.logicalSize,
          disableAnimations: reduced,
          textScaler: TextScaler.linear(textScale),
        ),
        child: SingleChildScrollView(
          child: LivePkStage(
            match: match,
            roomId: 'room-0',
            ownVideo: null,
            opponentVideo: null,
            now: () => now,
            isHost: isHost,
            dareActions: actions,
          ),
        ),
      ),
    ),
    language: language,
  );
  await tester.pump();
}

void main() {
  group('parse (contract shapes)', () {
    test('PkMatch with a dare, PkInvite / PkRecord additions, defaults', () {
      final dare = PkDare.fromJson(_dareJson('DRAWING'));
      expect(dare.options.map((o) => o.level), PkDareLevel.values);
      expect(dare.chosen!.id, 'd2');
      expect(dare.refusePoints, -5);
      expect(
        dare.statusAt(DateTime.parse('2026-11-01T10:00:03Z')),
        PkDareStatus.drawing,
      );
      expect(
        dare.statusAt(DateTime.parse('2026-11-01T10:00:05Z')),
        PkDareStatus.deciding,
      );
      final refused = PkDare.fromJson(
        _dareJson('REFUSED', cause: 'WINNER_NOT_DONE'),
      );
      expect(refused.notDone, isTrue);
      expect(refused.points, -3);
      expect(PkType.fromWire('DARES'), PkType.dares);
      expect(PkType.fromWire(null), PkType.normal);
      expect(PkType.fromWire('FUTURE'), PkType.normal);
      final record = PkRecord.fromJson(const {
        'wins': 2,
        'losses': 1,
        'draws': 0,
        'points': -1,
        'daresDone': 1,
        'daresRefused': 2,
      });
      expect(
        (record.points, record.daresDone, record.daresRefused),
        (-1, 1, 2),
      );
      // An older server (no new fields): zeros, NORMAL, no dare.
      expect(PkRecord.fromJson(const {'wins': 1}).points, 0);
    });
  });

  group('the PK sheet: «PK عادي» / «PK أحكام»', () {
    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      testWidgets('random and invite send the chosen type (${language.name})', (
        tester,
      ) async {
        setViewport(tester, GoldenViewport.phone);
        final repo = FakeLivePkRepository(
          list: [
            PkCandidate(
              roomId: 'room-x',
              title: 'Live',
              viewerCount: 3,
              host: pkUser('host-x', 'Rana'),
            ),
          ],
        );
        await pumpScreen(
          tester,
          const Scaffold(body: LivePkSheet(roomId: 'room-0')),
          language: language,
          livePkRepository: repo,
          overrides: [currentUserProvider.overrideWithValue(testUser())],
        );
        await tester.pumpAndSettle();
        final l10n = l10nFor(language);
        expect(find.byKey(LivePkSheet.typeKey(PkType.normal)), findsOneWidget);
        expect(find.text(l10n.pkTypeDares), findsOneWidget);
        await tester.tap(find.byKey(LivePkSheet.typeKey(PkType.dares)));
        await tester.pump();
        expect(find.text(l10n.pkTypeDaresHint), findsOneWidget);
        expect(find.text(l10n.pkRandomDares), findsOneWidget);
        await tester.tap(find.text(l10n.pkInvite).first);
        await tester.pumpAndSettle();
        expect(repo.calls, contains('invite:room-x:DARES'));
        expect(find.text(l10n.pkInviteSentDares('Rana')), findsOneWidget);
        await tester.tap(find.byKey(LivePkSheet.cancelInviteKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(LivePkSheet.randomKey));
        await tester.pumpAndSettle();
        expect(repo.calls, contains('random:DARES'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'an invitation to «PK أحكام» is labelled on the incoming card',
      (tester) async {
        setViewport(tester, GoldenViewport.phone);
        final invite = PkInvite(
          id: 'i1',
          status: 'PENDING',
          fromRoomId: 'room-b',
          toRoomId: 'room-0',
          from: pkUser('host-b', 'كريم'),
          to: pkUser('user-0', 'سارة'),
          expiresAt: DateTime.now().add(const Duration(seconds: 15)),
          type: PkType.dares,
        );
        await pumpScreen(
          tester,
          Scaffold(
            body: LivePkIncomingInvite(roomId: 'room-0', invite: invite),
          ),
          language: AppLanguage.ar,
        );
        await tester.pump();
        expect(find.byKey(LivePkIncomingInvite.daresKey), findsOneWidget);
        expect(find.text('PK أحكام'), findsOneWidget);
      },
    );
  });

  group('the dare layer', () {
    final now = DateTime.utc(2026, 11, 1, 10);

    testWidgets('the draw: three cards (easy, medium, hard) for everyone', (
      tester,
    ) async {
      final match = pkDareMatchFixture(
        now: now,
        dare: pkDareFixture(now: now, status: PkDareStatus.drawing),
      );
      await _pumpStage(tester, match, now: now);
      expect(find.byKey(PkDareLayer.drawKey), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(PkDareLayer.cardKey(i)), findsOneWidget);
      }
      expect(find.text('سهل'), findsOneWidget);
      expect(find.text('متوسط'), findsOneWidget);
      expect(find.text('صعب'), findsOneWidget);
      expect(find.byKey(PkDareLayer.acceptKey), findsNothing);
    });

    testWidgets(
      'the loser host: «قبول» starts it; «رفض» asks with the points',
      (tester) async {
        final calls = _Calls();
        final match = pkDareMatchFixture(
          now: now,
          dare: pkDareFixture(now: now),
        );
        await _pumpStage(
          tester,
          match,
          now: now,
          isHost: true,
          actions: calls.actions(),
        );
        expect(find.byKey(PkDareLayer.decideKey), findsOneWidget);
        expect(find.text('21'), findsOneWidget); // the ring's seconds
        await tester.tap(find.byKey(PkDareLayer.acceptKey));
        await tester.pump();
        expect(calls.list, ['accept']);
        await tester.tap(find.byKey(PkDareLayer.refuseKey));
        await tester.pumpAndSettle();
        expect(find.textContaining('\u22123'), findsOneWidget);
        await tester.tap(find.byKey(PkDareLayer.refuseConfirmKey));
        await tester.pumpAndSettle();
        expect(calls.list, ['accept', 'refuse']);
      },
    );

    testWidgets('the winner and the viewers wait while the loser decides', (
      tester,
    ) async {
      final calls = _Calls();
      // This room (room-0) won: the loser is room-b.
      final match = pkDareMatchFixture(
        now: now,
        dare: pkDareFixture(
          now: now,
          loserRoom: 'room-b',
          winnerRoom: 'room-0',
        ),
      );
      await _pumpStage(
        tester,
        match,
        now: now,
        isHost: true,
        actions: calls.actions(),
      );
      expect(find.byKey(PkDareLayer.waitingKey), findsOneWidget);
      expect(find.byKey(PkDareLayer.acceptKey), findsNothing);
      expect(find.byKey(PkDareLayer.refuseKey), findsNothing);
    });

    testWidgets(
      'the timer: the winner judges, the banner counts down, ⚠️ reports',
      (tester) async {
        final calls = _Calls();
        final match = pkDareMatchFixture(
          now: now,
          dare: pkDareFixture(
            now: now,
            status: PkDareStatus.active,
            loserRoom: 'room-b',
            winnerRoom: 'room-0',
          ),
        );
        await _pumpStage(
          tester,
          match,
          now: now,
          isHost: true,
          actions: calls.actions(),
        );
        expect(find.byKey(PkDareLayer.bannerKey), findsOneWidget);
        expect(find.text('2:14'), findsOneWidget);
        await tester.tap(find.byKey(PkDareLayer.doneKey));
        await tester.pump();
        await tester.tap(find.byKey(PkDareLayer.notDoneKey));
        await tester.pump();
        await tester.tap(find.byKey(PkDareLayer.reportKey));
        await tester.pump();
        expect(calls.list, [
          'verdict:true',
          'verdict:false',
          'report:dare-medium',
        ]);
      },
    );

    testWidgets(
      'the loser during the timer: the banner only (no refuse, no verdict)',
      (tester) async {
        final match = pkDareMatchFixture(
          now: now,
          dare: pkDareFixture(now: now, status: PkDareStatus.active),
        );
        await _pumpStage(
          tester,
          match,
          now: now,
          isHost: true,
          actions: _Calls().actions(),
        );
        expect(find.byKey(PkDareLayer.bannerKey), findsOneWidget);
        expect(find.byKey(PkDareLayer.doneKey), findsNothing);
        expect(find.byKey(PkDareLayer.refuseKey), findsNothing);
      },
    );

    testWidgets('a guest viewer has no report button', (tester) async {
      final match = pkDareMatchFixture(
        now: now,
        dare: pkDareFixture(now: now, status: PkDareStatus.active),
      );
      await _pumpStage(
        tester,
        match,
        now: now,
        actions: _Calls().actions(report: false),
      );
      expect(find.byKey(PkDareLayer.reportKey), findsNothing);
    });

    for (final (status, cause, text) in [
      (PkDareStatus.done, 'WINNER_DONE', 'نُفّذ الحكم 🎉'),
      (PkDareStatus.refused, 'LOSER_REFUSED', 'رفض الحكم'),
      (PkDareStatus.refused, 'WINNER_NOT_DONE', 'لم يُنفّذ الحكم'),
    ]) {
      testWidgets('the outcome: $text', (tester) async {
        final match = pkDareMatchFixture(
          now: now,
          dare: pkDareFixture(
            now: now,
            status: status,
            cause: cause,
            points: status == PkDareStatus.done ? 0 : -3,
          ),
        );
        await _pumpStage(tester, match, now: now);
        expect(find.byKey(PkDareLayer.outcomeKey), findsOneWidget);
        expect(find.text(text), findsOneWidget);
      });
    }

    testWidgets('a cancelled dare shows nothing', (tester) async {
      final match = pkDareMatchFixture(
        now: now,
        dare: pkDareFixture(
          now: now,
          status: PkDareStatus.cancelled,
          cause: 'ADMIN',
        ),
      );
      await _pumpStage(tester, match, now: now);
      expect(find.byKey(PkDareLayer.layerKey), findsNothing);
    });

    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      for (final viewport in [GoldenViewport.phone, GoldenViewport.android]) {
        for (final scale in [1.0, 1.3]) {
          for (final status in [
            PkDareStatus.drawing,
            PkDareStatus.deciding,
            PkDareStatus.active,
            PkDareStatus.refused,
          ]) {
            testWidgets('no overflow: ${status.name} ${language.name} '
                '${viewport.name} ×$scale', (tester) async {
              final match = pkDareMatchFixture(
                now: now,
                ar: language == AppLanguage.ar,
                dare: pkDareFixture(
                  now: now,
                  status: status,
                  loserRoom: status == PkDareStatus.active
                      ? 'room-b'
                      : 'room-0',
                  winnerRoom: status == PkDareStatus.active
                      ? 'room-0'
                      : 'room-b',
                  cause: status == PkDareStatus.refused
                      ? 'LOSER_REFUSED'
                      : null,
                  points: status == PkDareStatus.refused ? -3 : 0,
                ),
              );
              await _pumpStage(
                tester,
                match,
                now: now,
                isHost: true,
                actions: _Calls().actions(),
                language: language,
                viewport: viewport,
                textScale: scale,
              );
              expect(tester.takeException(), isNull);
              expect(find.byKey(PkDareLayer.layerKey), findsOneWidget);
            });
          }
        }
      }
    }
  });

  group('the record', () {
    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      testWidgets(
        'PK history shows the points and the dares (${language.name})',
        (tester) async {
          setViewport(tester, GoldenViewport.phone);
          final repo = FakeLivePkRepository()
            ..pkHistory = const PkHistory(
              record: PkRecord(
                wins: 4,
                losses: 2,
                draws: 1,
                points: 7,
                daresDone: 1,
                daresRefused: 1,
              ),
            );
          await pumpScreen(
            tester,
            const PkHistoryPage(),
            language: language,
            livePkRepository: repo,
            overrides: [currentUserProvider.overrideWithValue(testUser())],
          );
          await tester.pumpAndSettle();
          final l10n = l10nFor(language);
          expect(find.byKey(PkHistoryPage.pointsKey), findsOneWidget);
          expect(
            find.text(l10n.pkRecordPoints('\u2066+7\u2069')),
            findsOneWidget,
          );
          expect(find.text(l10n.pkRecordDares('1', '1')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
