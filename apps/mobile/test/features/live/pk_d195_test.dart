// D195 (v1.43-live, CONVENTIONS §10.58): PK 1 v 1 — the split screen with
// both hosts, the score bar and its updates from the `pk` data messages, the
// booster chip and announcement, the result, the guests' circles, the host's
// invite / random / accept flow and the gift panel's «PK» tab, through the
// real viewer and host screens, in Arabic (RTL) and English (LTR), also at
// 360×800 with text ×1.3.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/live_room_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_guest_tiles.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_boost_fx.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_pk.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Future<(FakeLivePkRepository, FakeLiveMediaEngine, FakePkOpponentMedia)>
_pumpViewer(
  WidgetTester tester, {
  PkMatch? match,
  AppLanguage language = AppLanguage.ar,
  GoldenViewport viewport = GoldenViewport.phone,
  double textScale = 1,
}) async {
  setViewport(tester, viewport);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final repo = FakeLivePkRepository(snapshot: PkState(match: match));
  final engine = FakeLiveMediaEngine()..present.add('user-0');
  final opponent = FakePkOpponentMedia()..present.add('host-b');
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const LiveRoomScreen(roomId: 'room-0'),
    language: language,
    liveMediaEngine: engine,
    livePkRepository: repo,
    pkOpponent: opponent,
    overrides: [
      liveRepositoryProvider.overrideWithValue(
        FakeLiveRepository(room: (id) => apiRoom(id: id, ar: true)),
      ),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
      currentUserProvider.overrideWithValue(testUser()),
    ],
  );
  await tester.pumpAndSettle();
  return (repo, engine, opponent);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

LivePkController _pk(WidgetTester tester) {
  final element = tester.element(find.byType(LiveRoomScreen));
  return ProviderScope.containerOf(element)
      .read(livePkProvider('room-0').notifier);
}

void main() {
  group('domain', () {
    test('PkEvent parses a pk-match message (sides, boosts, rules)', () {
      final event = PkEvent.parse({
        'type': 'pk-match',
        'event': 'boost',
        'boost': {'roomId': 'room-0', 'kind': 'TRIPLE', 'multiplier': 5},
        'match': {
          'id': 'm',
          'source': 'INVITE',
          'status': 'BATTLE',
          'startedAt': '2026-11-01T12:00:00.000Z',
          'battleEndsAt': '2026-11-01T12:05:00.000Z',
          'endedAt': null,
          'resultEndsAt': null,
          'endReason': null,
          'winnerRoomId': null,
          'loserCauseRoomId': null,
          'seq': 7,
          'serverTime': '2026-11-01T12:04:10.000Z',
          'sides': [
            for (final (room, host) in [('room-0', 'a'), ('room-b', 'b')])
              {
                'roomId': room,
                'host': {
                  'id': host,
                  'username': host,
                  'displayName': host,
                  'avatarUrl': null,
                },
                'score': room == 'room-0' ? 500 : 300,
                'boost': room == 'room-0'
                    ? {
                        'id': 'b1',
                        'kind': 'TRIPLE',
                        'multiplier': 5,
                        'startsAt': '2026-11-01T12:04:10.000Z',
                        'endsAt': '2026-11-01T12:04:30.000Z',
                        'sender': null,
                      }
                    : null,
                'boosterUses': {
                  'DOUBLE': 0,
                  'DOUBLE_TURBO': 0,
                  'TRIPLE': 1,
                  'TRIPLE_TURBO': 0,
                },
                'supporters': <Object>[],
                'guests': <Object>[],
                'mutesOpponent': false,
              },
          ],
          'boosters': [
            {
              'kind': 'TRIPLE',
              'multiplier': 5,
              'durationSeconds': 20,
              'lastSeconds': 60,
              'limitPerMatch': 2,
              'giftCode': 'pk_triple',
            },
          ],
        },
      });
      expect(event, isA<PkMatchEvent>());
      final m = (event! as PkMatchEvent).match;
      expect(m.seq, 7);
      expect(m.of('room-b').$1.score, 300);
      expect(m.of('room-0').$1.boost?.kind, PkBoosterKind.triple);
      expect(m.rule(PkBoosterKind.triple)?.lastSeconds, 60);
      expect((event as PkMatchEvent).boostKind, PkBoosterKind.triple);
      expect(PkEvent.parse({'type': 'chat'}), isNull);
      expect(PkEvent.parse({'type': 'pk-queue'}), isA<PkQueueExpired>());
    });
  });

  for (final language in [AppLanguage.ar, AppLanguage.en]) {
    group(language.name, () {
      testWidgets('split screen: own host on the reading start, the bar, '
          'the timer and the supporters', (tester) async {
        final match = pkMatchFixture(
          now: DateTime.now(),
          ar: language == AppLanguage.ar,
        );
        final (repo, _, opponent) = await _pumpViewer(
          tester,
          match: match,
          language: language,
        );
        expect(find.byType(LivePkStage), findsOneWidget);
        expect(find.byKey(LivePkStage.barKey), findsOneWidget);
        expect(find.byKey(LivePkStage.timerKey), findsOneWidget);
        // The other room's watch-only connection is up (token, join).
        expect(repo.calls, containsAll(<String>['state', 'token']));
        expect(opponent.joined, isTrue);
        expect(find.byKey(const Key('pk.video.host-b')), findsOneWidget);
        final own = tester.getCenter(find.byKey(LivePkStage.ownPaneKey));
        final other = tester.getCenter(find.byKey(LivePkStage.opponentPaneKey));
        if (language == AppLanguage.ar) {
          expect(
            own.dx,
            greaterThan(other.dx),
            reason: 'RTL: own on the right',
          );
        } else {
          expect(own.dx, lessThan(other.dx), reason: 'LTR: own on the left');
        }
        await _leave(tester);
      });
    });
  }

  testWidgets('score updates from pk-match messages (highest seq wins)', (
    tester,
  ) async {
    final now = DateTime.now();
    final (_, engine, _) = await _pumpViewer(
      tester,
      match: pkMatchFixture(now: now),
    );
    engine.pk.add(
      PkMatchEvent(
        event: 'score',
        match: pkMatchFixture(now: now, ownScore: 20000, seq: 9),
      ),
    );
    await tester.pumpAndSettle();
    expect(_pk(tester).state.match?.of('room-0').$1.score, 20000);
    // An older message is ignored.
    engine.pk.add(
      PkMatchEvent(
        event: 'score',
        match: pkMatchFixture(now: now, ownScore: 1, seq: 8),
      ),
    );
    await tester.pumpAndSettle();
    expect(_pk(tester).state.match?.of('room-0').$1.score, 20000);
    await _leave(tester);
  });

  testWidgets('a booster: the countdown chip on that side and the '
      'announcement «فعّل فريق … تربل ×5!»', (tester) async {
    final now = DateTime.now();
    final (_, engine, _) = await _pumpViewer(
      tester,
      match: pkMatchFixture(now: now),
    );
    engine.pk.add(
      PkMatchEvent(
        event: 'boost',
        match: pkMatchFixture(
          now: now,
          remaining: const Duration(seconds: 50, milliseconds: 500),
          ownBoost: PkBoosterKind.triple,
          seq: 9,
        ),
        boostKind: PkBoosterKind.triple,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(LivePkStage.boostChipKey('room-0')), findsOneWidget);
    expect(find.byKey(LivePkStage.boostChipKey('room-b')), findsNothing);
    expect(find.byKey(LivePkStage.announcementKey), findsOneWidget);
    // D199: the owner's banner (×5, «تربل») for both teams, and the line
    // under it — «فعّل» spelt with its «ع» and shadda in Baloo Bhaijaan 2.
    expect(
      find.descendant(
        of: find.byKey(LivePkStage.bannersKey),
        matching: find.text('x5'),
      ),
      findsWidgets,
    );
    final line = tester.widget<Text>(find.byKey(PkBoostText.lineKey));
    expect(line.data, 'فعّل فريق \u2068سارة\u2069 تربل');
    expect(line.data, contains('فعّل'));
    expect(line.style?.fontFamily, PkBoostText.family);
    // The last minute: the timer reads «الجولة الأخيرة».
    expect(find.textContaining('الجولة الأخيرة'), findsOneWidget);
    // The announcement goes after about 3 s.
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(LivePkStage.announcementKey), findsNothing);
    await _leave(tester);
  });

  testWidgets('the result: win / lose and the reason; closed → solo again', (
    tester,
  ) async {
    final now = DateTime.now();
    final (_, engine, opponent) = await _pumpViewer(
      tester,
      match: pkMatchFixture(
        now: now,
        status: PkMatchStatus.result,
        winner: 'room-0',
        endReason: PkEndReason.forfeit,
      ).copyLoser('room-b'),
    );
    expect(find.byKey(LivePkStage.resultKey), findsOneWidget);
    expect(find.text('فوز'), findsOneWidget);
    expect(find.text('انسحب كريم'), findsOneWidget);
    expect(find.byKey(LivePkStage.timerKey), findsNothing);
    engine.pk.add(
      PkMatchEvent(
        event: 'closed',
        match: pkMatchFixture(
          now: now,
          status: PkMatchStatus.closed,
          winner: 'room-0',
          seq: 20,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LivePkStage), findsNothing);
    expect(opponent.joined, isFalse);
    await _leave(tester);
  });

  testWidgets('PK guests: small circles at the bottom of their host box '
      '(no solo tiles); a speaking guest glows', (tester) async {
    final (_, engine, opponent) = await _pumpViewer(
      tester,
      match: pkMatchFixture(now: DateTime.now(), ownGuests: 3, otherGuests: 2),
    );
    opponent.speakingNow = {'b-guest-0'};
    engine.speakingNow = {'a-guest-1'};
    await tester.pumpAndSettle();
    for (final id in ['a-guest-0', 'a-guest-1', 'a-guest-2', 'b-guest-0']) {
      expect(find.byKey(LivePkStage.guestKey(id)), findsOneWidget);
    }
    expect(find.byType(LiveGuestTiles), findsNothing);
    final ownPane = tester.getRect(find.byKey(LivePkStage.ownPaneKey));
    final circle = tester.getRect(
      find.byKey(LivePkStage.guestKey('a-guest-0')),
    );
    expect(ownPane.contains(circle.center), isTrue);
    // D231: just over the host's chip at the bottom of the half.
    expect(circle.bottom, greaterThan(ownPane.bottom - 100));
    final chip = tester.getRect(find.byKey(LivePkStage.ownHostKey));
    expect(circle.bottom, lessThanOrEqualTo(chip.top));
    await _leave(tester);
  });

  testWidgets('360×800 with text ×1.3, ar and en: no overflow', (tester) async {
    for (final language in [AppLanguage.ar, AppLanguage.en]) {
      await _pumpViewer(
        tester,
        match: pkMatchFixture(
          now: DateTime.now(),
          ar: language == AppLanguage.ar,
          ownBoost: PkBoosterKind.tripleTurbo,
          otherBoost: PkBoosterKind.double,
          ownGuests: 3,
          otherGuests: 3,
        ),
        language: language,
        viewport: GoldenViewport.android,
        textScale: 1.3,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(LivePkStage), findsOneWidget);
      await _leave(tester);
    }
  });

  group('host', () {
    Future<FakeLivePkRepository> sheet(
      WidgetTester tester, {
      PkState snapshot = const PkState(),
    }) async {
      setViewport(tester, GoldenViewport.phone);
      final repo = FakeLivePkRepository(
        snapshot: snapshot,
        list: [
          PkCandidate(
            roomId: 'room-b',
            title: 'سهرة',
            viewerCount: 120,
            host: pkUser('host-b', 'كريم'),
          ),
          PkCandidate(
            roomId: 'room-c',
            title: 'غناء',
            viewerCount: 80,
            host: pkUser('host-c', 'ليلى'),
          ),
        ],
      )..matchOnAccept = pkMatchFixture(now: DateTime.now());
      await pumpScreen(
        tester,
        const Scaffold(body: LivePkSheet(roomId: 'room-0')),
        language: AppLanguage.ar,
        livePkRepository: repo,
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('invite sheet: candidates, search, invite → waiting', (
      tester,
    ) async {
      final repo = await sheet(tester);
      expect(find.byKey(LivePkSheet.candidateKey('room-b')), findsOneWidget);
      expect(find.byKey(LivePkSheet.candidateKey('room-c')), findsOneWidget);
      await tester.enterText(find.byKey(LivePkSheet.searchKey), 'ليلى');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.byKey(LivePkSheet.candidateKey('room-b')), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byKey(LivePkSheet.candidateKey('room-c')),
          matching: find.text('دعوة'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.calls, contains('invite:room-c'));
      expect(find.byKey(LivePkSheet.cancelInviteKey), findsOneWidget);
      expect(find.textContaining('بانتظار رد ليلى'), findsOneWidget);
      await tester.tap(find.byKey(LivePkSheet.cancelInviteKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('cancel:invite-1'));
    });

    testWidgets('random match: waiting, then stop', (tester) async {
      final repo = await sheet(tester);
      await tester.tap(find.byKey(LivePkSheet.randomKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('random'));
      expect(find.byKey(LivePkSheet.stopRandomKey), findsOneWidget);
      await tester.tap(find.byKey(LivePkSheet.stopRandomKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('leaveRandom'));
    });

    testWidgets('incoming invite: accept starts the battle', (tester) async {
      setViewport(tester, GoldenViewport.phone);
      final invite = PkInvite(
        id: 'invite-9',
        status: 'PENDING',
        fromRoomId: 'room-b',
        toRoomId: 'room-0',
        from: pkUser('host-b', 'كريم'),
        to: pkUser('user-0', 'سارة'),
        expiresAt: DateTime.now().add(const Duration(seconds: 15)),
      );
      final repo = FakeLivePkRepository(snapshot: PkState(invite: invite))
        ..matchOnAccept = pkMatchFixture(now: DateTime.now());
      final engine = FakeLiveMediaEngine();
      await pumpScreen(
        tester,
        Consumer(
          builder: (context, ref, _) {
            final pk = ref.watch(livePkProvider('room-0'));
            return Scaffold(
              body: pk.incoming == null
                  ? Text(pk.match == null ? 'none' : 'battle')
                  : LivePkIncomingInvite(roomId: 'room-0', invite: invite),
            );
          },
        ),
        language: AppLanguage.ar,
        livePkRepository: repo,
        liveMediaEngine: engine,
      );
      final element = tester.element(find.byType(Consumer));
      ProviderScope.containerOf(element)
          .read(livePkProvider('room-0').notifier)
          .attach(engine.pk.stream, host: true);
      await tester.pumpAndSettle();
      expect(find.text('كريم يدعوك إلى تحدي PK'), findsOneWidget);
      await tester.tap(find.byKey(LivePkIncomingInvite.acceptKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('accept:invite-9'));
      expect(find.text('battle'), findsOneWidget);
    });

    testWidgets('during a PK: mute opponent and end (forfeit confirmed)', (
      tester,
    ) async {
      final match = pkMatchFixture(now: DateTime.now());
      final repo = await sheet(tester, snapshot: PkState(match: match));
      final element = tester.element(find.byType(LivePkSheet));
      ProviderScope.containerOf(element)
          .read(livePkProvider('room-0').notifier)
          .debugSetMatch(match);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(LivePkSheet.muteKey));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('mute:true'));
      await tester.tap(find.byKey(LivePkSheet.endKey));
      await tester.pumpAndSettle();
      expect(find.text('إنهاء التحدي الآن؟'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pk.end.confirm')));
      await tester.pumpAndSettle();
      expect(repo.calls, contains('end'));
    });
  });

  testWidgets('gift panel: the «PK» tab with the boosters during a battle '
      'only', (tester) async {
    setViewport(tester, GoldenViewport.phone);
    Gift gift(String code, {PkBoosterKind? booster, int price = 10}) => Gift(
      code: code,
      category: GiftCategory.popular,
      name: code,
      priceCoins: price,
      assetKey: 'gift_$code',
      animationKey: null,
      sortOrder: 0,
      badge: GiftBadge.none,
      pkBooster: booster,
    );
    final catalogue = _PkCatalogue(
      GiftCatalogue(
        version: 'v1',
        categories: const [GiftCategory.popular],
        quantities: const [1, 10],
        maxRecipients: 25,
        comboWindowSeconds: 5,
        data: [
          gift('rose'),
          gift('pk_triple', booster: PkBoosterKind.triple, price: 50000),
        ],
      ),
    );
    for (final battle in [true, false]) {
      final match = battle ? pkMatchFixture(now: DateTime.now()) : null;
      await pumpScreen(
        tester,
        Scaffold(
          body: KLiveGiftSheet(
            room: LiveGiftRoom(
              roomId: 'room-0',
              host: pkUser('user-0', 'سارة'),
              seated: (_) => const [],
              pk: (_) => match,
            ),
          ),
        ),
        language: AppLanguage.ar,
        liveGiftRepository: catalogue,
        overrides: [currentUserProvider.overrideWithValue(testUser())],
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(KLiveGiftSheet.tabKey(KLiveGiftSheet.pkTab)),
        battle ? findsOneWidget : findsNothing,
      );
      if (battle) {
        await tester.tap(
          find.byKey(KLiveGiftSheet.tabKey(KLiveGiftSheet.pkTab)),
        );
        await tester.pumpAndSettle();
        expect(find.text('pk_triple'), findsOneWidget);
        expect(find.text('rose'), findsNothing);
      } else {
        // Never in the ordinary tabs.
        expect(find.text('pk_triple'), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

extension on PkMatch {
  PkMatch copyLoser(String roomId) => PkMatch(
    id: id,
    status: status,
    startedAt: startedAt,
    battleEndsAt: battleEndsAt,
    resultEndsAt: resultEndsAt,
    endReason: endReason,
    winnerRoomId: winnerRoomId,
    loserCauseRoomId: roomId,
    seq: seq,
    serverTime: serverTime,
    sides: sides,
    boosters: boosters,
  );
}

class _PkCatalogue extends FakeLiveGiftRepository {
  new(this.value);

  final GiftCatalogue value;

  @override
  Future<GiftCatalogue> catalogue() async => value;
}
