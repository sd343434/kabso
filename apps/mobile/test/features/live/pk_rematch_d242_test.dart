// D242 (owner: «لا يحتوي pk زر إعادة pk أو لعب جولة أخرى»): «جولة أخرى» in
// the PK's result — the hosts' white docked card (D238 style): the offer,
// the waiting host with cancel, the other host's prompt with «قبول» /
// «رفض» and the ring; nothing for viewers, during the battle, while the
// dare runs or past the limit; the «جولة أخرى!» banner on the stage; the
// controller's toast and banner. ar and en, 393×852 and 360×800 ×1.3.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_rematch.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_scaffold.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_pk.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

class _Calls {
  final List<String> list = [];
  PkRematchActions get actions => PkRematchActions(
    onOffer: () async => list.add('offer'),
    onAccept: () async => list.add('accept'),
    onDecline: () async => list.add('decline'),
    onCancel: () async => list.add('cancel'),
  );
}

const _barKey = Key('test.bar');

Future<void> _pump(
  WidgetTester tester,
  PkMatch match, {
  required DateTime now,
  PkRematchActions? rematch,
  AppLanguage language = AppLanguage.ar,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
  bool banner = false,
}) async {
  setViewport(tester, viewport);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await pumpScreen(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: viewport.logicalSize,
        disableAnimations: true,
        textScaler: TextScaler.linear(textScale),
        padding: viewport == GoldenViewport.phone
            ? const EdgeInsets.only(top: 59, bottom: 34)
            : const EdgeInsets.only(top: 24),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: KLiveRoomScaffold(
          header: const SizedBox(height: 48),
          stage: LivePkStage(
            match: match,
            roomId: 'room-0',
            ownVideo: null,
            opponentVideo: null,
            now: () => now,
            rematchBanner: banner,
          ),
          stageEdgeToEdge: true,
          chat: const SizedBox(height: 120),
          dock: LivePkStage.dareDock(
            match: match,
            roomId: 'room-0',
            now: () => now,
            isHost: rematch != null,
            rematch: rematch,
          ),
          actionBar: const SizedBox(key: _barKey, height: 76),
        ),
      ),
    ),
    language: language,
  );
  await tester.pump();
}

void main() {
  final now = DateTime.utc(2026, 11, 2, 10);

  setUp(() => PkRematchDock.debugSeconds = 12);
  tearDown(() => PkRematchDock.debugSeconds = null);

  test('the model: offer, chain and when it may be offered', () {
    final m = PkMatch.fromJson({
      'id': 'm2',
      'status': 'RESULT',
      'startedAt': '2026-11-02T10:00:00Z',
      'battleEndsAt': '2026-11-02T10:05:00Z',
      'seq': 3,
      'serverTime': '2026-11-02T10:05:10Z',
      'sides': [
        for (final r in ['room-0', 'room-b'])
          {
            'roomId': r,
            'host': {
              'id': 'h-$r',
              'username': 'u$r',
              'displayName': 'H',
              'avatarUrl': null,
            },
            'score': 0,
          },
      ],
      'rematch': const {
        'byRoomId': 'room-b',
        'expiresAt': '2026-11-02T10:05:25Z',
      },
      'rematchOf': 'm1',
      'rematchCount': 1,
      'rematchesLeft': 4,
    });
    expect(m.rematch?.byRoomId, 'room-b');
    expect((m.rematchOf, m.rematchCount, m.rematchesLeft), ('m1', 1, 4));
    expect(m.canOfferRematch, isFalse); // an offer is open
    expect(pkRematchFixture(now: now).canOfferRematch, isTrue);
    expect(
      pkRematchFixture(now: now, rematchesLeft: 0).canOfferRematch,
      isFalse,
    );
    expect(
      pkRematchFixture(now: now, status: PkMatchStatus.battle).canOfferRematch,
      isFalse,
    );
    // A running dare: not yet.
    final dare = pkDareMatchFixture(
      now: now,
      dare: pkDareFixture(now: now),
    );
    expect(dare.canOfferRematch, isFalse);
  });

  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    final l10n = l10nFor(language);
    group(language.name, () {
      testWidgets('nothing asked: «جولة أخرى» (red) on the white card', (
        tester,
      ) async {
        final calls = _Calls();
        await _pump(
          tester,
          pkRematchFixture(now: now, ar: ar),
          now: now,
          rematch: calls.actions,
          language: language,
        );
        final card = find.byKey(PkRematchDock.cardKey);
        expect(tester.widget<KLiveDialogCard>(card).dense, isTrue);
        expect(Theme.of(tester.element(card)).brightness, Brightness.light);
        expect(find.text(l10n.pkRematch), findsOneWidget);
        expect(find.textContaining('@host_b'), findsOneWidget);
        // At the bottom, over the bar.
        expect(
          tester.getRect(card).bottom,
          lessThanOrEqualTo(tester.getRect(find.byKey(_barKey)).top + 0.5),
        );
        await tester.tap(find.byKey(PkRematchDock.offerKey));
        await tester.pump();
        expect(calls.list, ['offer']);
      });

      testWidgets('the asking host waits «بانتظار @B…» with the ring and '
          'cancel', (tester) async {
        final calls = _Calls();
        await _pump(
          tester,
          pkRematchFixture(now: now, ar: ar, offerBy: 'room-0'),
          now: now,
          rematch: calls.actions,
          language: language,
        );
        expect(find.byKey(PkRematchDock.waitingKey), findsOneWidget);
        expect(find.textContaining('@host_b'), findsOneWidget);
        expect(
          find.textContaining(
            l10n.pkRematchWaiting('').split('…').first.trim(),
          ),
          findsOneWidget,
        );
        expect(find.text('12'), findsOneWidget);
        await tester.tap(find.byKey(PkRematchDock.cancelKey));
        await tester.pump();
        expect(calls.list, ['cancel']);
      });

      testWidgets('the other host is asked: «@B يريد جولة أخرى», «قبول» '
          '(primary, reading start) beside «رفض»', (tester) async {
        final calls = _Calls();
        await _pump(
          tester,
          pkRematchFixture(now: now, ar: ar, offerBy: 'room-b'),
          now: now,
          rematch: calls.actions,
          language: language,
        );
        expect(find.byKey(PkRematchDock.promptKey), findsOneWidget);
        final accept = tester.getRect(find.byKey(PkRematchDock.acceptKey));
        final decline = tester.getRect(find.byKey(PkRematchDock.declineKey));
        expect(accept.top, closeTo(decline.top, 0.5));
        if (ar) {
          expect(accept.left, greaterThan(decline.right - 0.5));
        } else {
          expect(accept.right, lessThan(decline.left + 0.5));
        }
        await tester.tap(find.byKey(PkRematchDock.acceptKey));
        await tester.pump();
        await tester.tap(find.byKey(PkRematchDock.declineKey));
        await tester.pump();
        expect(calls.list, ['accept', 'decline']);
      });
    });
  }

  testWidgets('viewers, the battle and the limit: no card', (tester) async {
    await _pump(
      tester,
      pkRematchFixture(now: now, offerBy: 'room-b'),
      now: now,
    );
    expect(find.byType(PkRematchDock), findsNothing);
    await _pump(
      tester,
      pkRematchFixture(now: now, status: PkMatchStatus.battle),
      now: now,
      rematch: _Calls().actions,
    );
    expect(find.byKey(PkRematchDock.cardKey), findsNothing);
    await _pump(
      tester,
      pkRematchFixture(now: now, rematchesLeft: 0),
      now: now,
      rematch: _Calls().actions,
    );
    expect(find.byKey(PkRematchDock.cardKey), findsNothing);
  });

  testWidgets('the «جولة أخرى!» banner over the stage', (tester) async {
    await _pump(
      tester,
      pkRematchFixture(now: now, status: PkMatchStatus.battle, rematchOf: 'm1'),
      now: now,
      banner: true,
    );
    expect(find.byKey(PkRematchBanner.bannerKey), findsOneWidget);
    expect(find.text(l10nFor(AppLanguage.ar).pkRematchBanner), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    for (final (viewport, scale) in [
      (GoldenViewport.phone, 1.0),
      (GoldenViewport.android, 1.3),
    ]) {
      for (final offerBy in [null, 'room-0', 'room-b']) {
        testWidgets('no overflow: ${language.name} ${viewport.name} ×$scale '
            'offer by $offerBy', (tester) async {
          await _pump(
            tester,
            pkRematchFixture(
              now: now,
              ar: language == AppLanguage.ar,
              offerBy: offerBy,
            ),
            now: now,
            rematch: _Calls().actions,
            language: language,
            viewport: viewport,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
          expect(find.byType(KLiveDialogCard), findsOneWidget);
        });
      }
    }
  }

  group('the controller', () {
    ProviderContainer make(FakeLivePkRepository repo) {
      // Keeps the auto-dispose controller alive between reads.
      return ProviderContainer.test(
        overrides: [
          ...pkOverrides(repo),
          ...liveOverrides(FakeLiveRepository()),
          currentUserProvider.overrideWithValue(testUser()),
        ],
      )..listen(livePkProvider('room-0'), (_, _) {});
    }

    test('a declined own offer says so once; `rematch` shows the banner and '
        'the new battle', () async {
      final asked = pkRematchFixture(now: now, offerBy: 'room-0');
      final repo = FakeLivePkRepository(snapshot: PkState(match: asked));
      final c = make(repo);
      final events = StreamController<PkEvent>();
      addTearDown(events.close);
      c
          .read(livePkProvider('room-0').notifier)
          .attach(events.stream, host: true);
      await pumpEventQueue();
      events.add(
        PkMatchEvent(
          event: 'rematch-declined',
          match: pkRematchFixture(now: now),
        ),
      );
      await pumpEventQueue();
      expect(c.read(livePkProvider('room-0')).notice, PkNotice.rematchDeclined);
      final next = pkRematchFixture(
        now: now,
        status: PkMatchStatus.battle,
        rematchOf: asked.id,
      );
      events.add(PkMatchEvent(event: 'rematch', match: next));
      await pumpEventQueue();
      final state = c.read(livePkProvider('room-0'));
      expect(state.match?.id, next.id);
      expect(state.rematchBanner, isNotNull);
    });

    test('accept and decline call the server', () async {
      final next = pkRematchFixture(
        now: now,
        status: PkMatchStatus.battle,
        rematchOf: 'm1',
      );
      final repo = FakeLivePkRepository(
        snapshot: PkState(
          match: pkRematchFixture(now: now, offerBy: 'room-b'),
        ),
      )..matchOnRematch = next;
      final c = make(repo);
      final pk = c.read(livePkProvider('room-0').notifier);
      await pk.acceptRematch();
      expect(c.read(livePkProvider('room-0')).match?.id, next.id);
      await pk.declineRematch();
      expect(c.read(livePkProvider('room-0')).match, isNull);
      expect(repo.calls, containsAll(['rematch:accept', 'rematch:decline']));
    });
  });
}
