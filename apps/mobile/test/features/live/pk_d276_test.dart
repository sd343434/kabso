// D276 (owner, from a device: «زر اعادة بيكيه لا يظهر — يظهر فقط كتم الخصم،
// انهاء التحدي. ويجب ان يظهر لكل شخص نقاط بيكيه الاخر»; then «انسحاب = −٣»):
// «جولة أخرى» in the result's dock and in the host's PK controls next to
// «كتم الخصم» / «إنهاء التحدي» (offer, waiting / cancel, accept / refuse,
// disabled while the dare runs); both hosts' «نقاط PK» on their halves for
// either room; the «إنهاء التحدي» confirm says what withdrawing costs in
// «PK أحكام» only (owner: «الاحكام فقط»).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_rematch.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_pk.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

PkRematchActions _actions(List<String> calls) => PkRematchActions(
  onOffer: () async => calls.add('offer'),
  onAccept: () async => calls.add('accept'),
  onDecline: () async => calls.add('decline'),
  onCancel: () async => calls.add('cancel'),
);

Future<void> _pumpStage(
  WidgetTester tester,
  PkMatch match, {
  required DateTime now,
  String roomId = 'room-0',
  PkRematchActions? rematch,
  AppLanguage language = AppLanguage.ar,
}) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: GoldenViewport.phone.logicalSize,
        disableAnimations: true,
        padding: const EdgeInsets.only(top: 59, bottom: 34),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: KLiveRoomScaffold(
          header: const SizedBox(height: 48),
          stage: LivePkStage(
            match: match,
            roomId: roomId,
            ownVideo: null,
            opponentVideo: null,
            now: () => now,
          ),
          stageEdgeToEdge: true,
          chat: const SizedBox(height: 120),
          dock: LivePkStage.dareDock(
            match: match,
            roomId: roomId,
            now: () => now,
            isHost: rematch != null,
            rematch: rematch,
          ),
          actionBar: const SizedBox(height: 76),
        ),
      ),
    ),
    language: language,
  );
  await tester.pump();
}

Future<FakeLivePkRepository> _pumpSheet(
  WidgetTester tester,
  PkMatch match, {
  AppLanguage language = AppLanguage.ar,
}) async {
  setViewport(tester, GoldenViewport.phone);
  final repo = FakeLivePkRepository(snapshot: PkState(match: match));
  await pumpScreen(
    tester,
    const Scaffold(body: LivePkSheet(roomId: 'room-0')),
    language: language,
    livePkRepository: repo,
  );
  ProviderScope.containerOf(tester.element(find.byType(LivePkSheet)))
      .read(livePkProvider('room-0').notifier)
      .debugSetMatch(match);
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  final now = DateTime.utc(2026, 11, 4, 10);

  setUp(() => PkRematchDock.debugSeconds = 12);
  tearDown(() => PkRematchDock.debugSeconds = null);

  test(
    'the model reads pkPoints and forfeitPoints (null from older servers)',
    () {
      Map<String, dynamic> side(String r, Object? points) => {
        'roomId': r,
        'host': {'id': 'h-$r', 'username': 'u$r', 'displayName': 'H'},
        'score': 0,
        'pkPoints': ?points,
      };
      Map<String, dynamic> match(Object? a, Object? b, Object? f) => {
        'id': 'm',
        'status': 'BATTLE',
        'startedAt': '2026-11-04T10:00:00Z',
        'battleEndsAt': '2026-11-04T10:05:00Z',
        'seq': 1,
        'serverTime': '2026-11-04T10:01:00Z',
        'sides': [side('room-0', a), side('room-b', b)],
        'forfeitPoints': ?f,
      };
      final m = PkMatch.fromJson(match(-3, 27, -3));
      expect(m.sides.$1.pkPoints, -3);
      expect(m.sides.$2.pkPoints, 27);
      expect(m.forfeitPoints, -3);
      final old = PkMatch.fromJson(match(null, null, null));
      expect(old.sides.$1.pkPoints, isNull);
      expect(old.forfeitPoints, isNull);
    },
  );

  group('«نقاط PK» on the stage', () {
    for (final language in AppLanguage.values) {
      testWidgets("both hosts' points, for the host (${language.name})", (
        tester,
      ) async {
        await _pumpStage(
          tester,
          pkMatchFixture(
            now: now,
            ar: language == AppLanguage.ar,
            ownPkPoints: 42,
            otherPkPoints: -3,
          ),
          now: now,
          language: language,
        );
        final own = find.byKey(LivePkStage.pointsKey('room-0'));
        final other = find.byKey(LivePkStage.pointsKey('room-b'));
        expect(own, findsOneWidget);
        expect(other, findsOneWidget);
        final label = language == AppLanguage.ar ? 'نقاط PK' : 'PK points';
        expect(
          find.descendant(of: own, matching: find.text(label)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: own, matching: find.textContaining('42')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: other, matching: find.textContaining('−3')),
          findsOneWidget,
        );
        // Each on its own half: the own side on the reading start.
        final ownX = tester.getCenter(own).dx;
        final otherX = tester.getCenter(other).dx;
        final width = GoldenViewport.phone.logicalSize.width;
        if (language == AppLanguage.ar) {
          expect(ownX, greaterThan(width / 2));
          expect(otherX, lessThan(width / 2));
        } else {
          expect(ownX, lessThan(width / 2));
          expect(otherX, greaterThan(width / 2));
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the other room (and its viewers) sees both too', (
      tester,
    ) async {
      await _pumpStage(
        tester,
        pkMatchFixture(now: now, ownPkPoints: 42, otherPkPoints: 9),
        now: now,
        roomId: 'room-b',
      );
      expect(find.byKey(LivePkStage.pointsKey('room-0')), findsOneWidget);
      expect(find.byKey(LivePkStage.pointsKey('room-b')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              RegExp('نقاط PK لـ.*سارة.*: .*42')
                  .hasMatch(w.properties.label ?? ''),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an older server (no points): nothing', (tester) async {
      await _pumpStage(tester, pkMatchFixture(now: now), now: now);
      expect(find.byKey(LivePkStage.pointsKey('room-0')), findsNothing);
      expect(find.byKey(LivePkStage.pointsKey('room-b')), findsNothing);
    });
  });

  group('«جولة أخرى»', () {
    testWidgets('the result phase docks it for the host', (tester) async {
      final calls = <String>[];
      await _pumpStage(
        tester,
        pkRematchFixture(now: now, ownPkPoints: 45, otherPkPoints: 0),
        now: now,
        rematch: _actions(calls),
      );
      expect(find.byKey(PkRematchDock.offerKey), findsOneWidget);
      expect(find.text('جولة أخرى'), findsOneWidget);
      await tester.tap(find.byKey(PkRematchDock.offerKey));
      await tester.pump();
      expect(calls, ['offer']);
    });

    testWidgets('the controls sheet: next to mute and end in the result', (
      tester,
    ) async {
      final repo = await _pumpSheet(tester, pkRematchFixture(now: now));
      expect(find.byKey(LivePkSheet.muteKey), findsOneWidget);
      expect(find.byKey(LivePkSheet.endKey), findsOneWidget);
      expect(find.byKey(LivePkSheet.rematchKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(LivePkSheet.rematchKey),
          matching: find.text('جولة أخرى'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(LivePkSheet.rematchKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('rematch:offer'));
    });

    testWidgets('the sheet: the asking host waits and may cancel', (
      tester,
    ) async {
      final repo = await _pumpSheet(
        tester,
        pkRematchFixture(now: now, offerBy: 'room-0'),
      );
      expect(find.byKey(LivePkSheet.rematchKey), findsNothing);
      expect(find.textContaining('بانتظار'), findsOneWidget);
      await tester.tap(find.byKey(LivePkSheet.rematchCancelKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('rematch:cancel'));
    });

    testWidgets('the sheet: the other host accepts or refuses', (tester) async {
      final repo = await _pumpSheet(
        tester,
        pkRematchFixture(now: now, offerBy: 'room-b'),
      );
      expect(find.byKey(LivePkSheet.rematchAcceptKey), findsOneWidget);
      expect(find.byKey(LivePkSheet.rematchDeclineKey), findsOneWidget);
      await tester.tap(find.byKey(LivePkSheet.rematchAcceptKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('rematch:accept'));
    });

    testWidgets('the sheet: disabled with a note while the dare runs', (
      tester,
    ) async {
      await _pumpSheet(
        tester,
        pkRematchFixture(
          now: now,
          dare: pkDareFixture(now: now),
        ),
      );
      final button = find.byKey(LivePkSheet.rematchKey);
      expect(button, findsOneWidget);
      expect(find.text('جولة أخرى بعد انتهاء الحكم'), findsOneWidget);
      await tester.tap(button, warnIfMissed: false);
      await tester.pumpAndSettle();
    });

    testWidgets('the sheet: nothing during the battle or past the limit', (
      tester,
    ) async {
      await _pumpSheet(tester, pkMatchFixture(now: now));
      expect(find.byKey(LivePkSheet.rematchKey), findsNothing);
      expect(find.byKey(LivePkSheet.muteKey), findsOneWidget);
    });

    testWidgets('the sheet: past the limit in a row, nothing', (tester) async {
      await _pumpSheet(tester, pkRematchFixture(now: now, rematchesLeft: 0));
      expect(find.byKey(LivePkSheet.rematchKey), findsNothing);
    });
  });

  testWidgets('«إنهاء التحدي» in «PK أحكام» says withdrawing costs 3', (
    tester,
  ) async {
    final repo = await _pumpSheet(
      tester,
      pkMatchFixture(
        now: DateTime.now(),
        forfeitPoints: -3,
        type: PkType.dares,
      ),
    );
    await tester.tap(find.byKey(LivePkSheet.endKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('الانسحاب يخصم 3 نقاط PK'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pk.end.confirm')));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('end'));
  });

  testWidgets('«إنهاء التحدي» in a normal PK: no −3 line (a plain loss)', (
    tester,
  ) async {
    await _pumpSheet(tester, pkMatchFixture(now: DateTime.now()));
    await tester.tap(find.byKey(LivePkSheet.endKey));
    await tester.pumpAndSettle();
    expect(find.text('إنهاء التحدي الآن؟'), findsOneWidget);
    expect(find.textContaining('الانسحاب يخصم'), findsNothing);
  });
}
