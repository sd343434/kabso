// D215 (owner, two Android phones on staging):
// 1. «لا يظهر صديق في بيكيه فقط بالعشوائي» — the PK sheet's «الأصدقاء» list
//    was read once, when the sheet opened, and a failed read was shown as
//    «لا يوجد أصدقاء»; the server (v1.48-live) now also lists a friend who
//    waits for a random match.
// 2. «وعندما صعود معه بالعشوائي يقوم النظام باخراجي من التطبيق» — the app
//    closed when a random PK started. These tests drive the exact path on
//    the host's real go-live screen — solo live → PK sheet → «مطابقة
//    عشوائية» → MATCHED → battle — with the API's own JSON (captured from
//    `joinLivePkRandom` in the D215 e2e, nulls included) through the real
//    `LivePkRepositoryImpl`, and the other room's connection failing first:
//    the live stays up, the failure is handled and tried again, and a
//    half-made connection is never kept.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_pk_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_host_parts.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_stage.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_pk.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _base = '/api/v1';
const _opponentRoom = '01a195fb-849e-73f2-a228-17fcf15d112a';
const _opponentHost = '01a195fb-8370-7469-97f4-da5ce1d95851';
final _categories = [const LiveCategory(slug: 'chat', name: 'Chat')];

/// `joinLivePkRandom` → MATCHED, as the API sent it in the D215 e2e (only
/// this room's id and its host are put in side B).
Map<String, Object?> _matchedJson({
  required String roomId,
  required String hostId,
  required DateTime now,
  int seq = 1,
  String status = 'BATTLE',
  int scoreA = 0,
}) {
  Map<String, Object?> side(String room, String id, String username, int s) => {
    'roomId': room,
    'host': {
      'id': id,
      'username': username,
      'displayName': 'Test User',
      'avatarUrl': null,
    },
    'score': s,
    'totalScore': s,
    'roundsWon': 0,
    'boost': null,
    'boosterUses': {
      'DOUBLE': 0,
      'DOUBLE_TURBO': 0,
      'TRIPLE': 0,
      'TRIPLE_TURBO': 0,
    },
    'supporters': <Object>[],
    'guests': <Object>[],
    'mutesOpponent': false,
  };
  Map<String, Object?> rule(String kind, int x, int d, int last) => {
    'kind': kind,
    'multiplier': x,
    'durationSeconds': d,
    'lastSeconds': last,
    'limitPerMatch': 2,
    'giftCode': null,
  };
  return {
    'id': '01a195fb-85b7-7455-91b6-bd7a51719727',
    'source': 'RANDOM',
    'status': status,
    'startedAt': now.toUtc().toIso8601String(),
    'battleEndsAt': now
        .add(const Duration(minutes: 5))
        .toUtc()
        .toIso8601String(),
    'endedAt': null,
    'resultEndsAt': null,
    'endReason': null,
    'winnerRoomId': null,
    'loserCauseRoomId': null,
    'seq': seq,
    'serverTime': now.toUtc().toIso8601String(),
    'sides': [
      side(_opponentRoom, _opponentHost, 'usermvxi3o3w2', scoreA),
      side(roomId, hostId, 'usermvxi3nn61', 0),
    ],
    'boosters': [
      rule('DOUBLE', 2, 30, 0),
      rule('DOUBLE_TURBO', 3, 20, 120),
      rule('TRIPLE', 5, 20, 60),
      rule('TRIPLE_TURBO', 10, 10, 60),
    ],
    'mode': 'SINGLE',
    'roundSeconds': 300,
    'round': 1,
    'rounds': 1,
    'connectedAt': null,
    'settingsFromRoomId': null,
    'effective': null,
  };
}

/// The PK calls of these tests through the real repository and its JSON
/// parsing (HTTP answered by [http]); the rest stays the in-memory fake.
class _HttpPkRepository extends FakeLivePkRepository {
  new(this.http)
    : _real = LivePkRepositoryImpl(
        Dio(BaseOptions(baseUrl: 'http://test$_base'))
          ..httpClientAdapter = http,
      );

  final FakeHttpAdapter http;
  final LivePkRepository _real;

  @override
  Future<PkState> state(String roomId) => _real.state(roomId);

  @override
  Future<List<PkCandidate>> candidates(
    String roomId, {
    String? query,
    bool friends = false,
  }) {
    calls.add('candidates:${friends ? 'friends:' : ''}${query ?? ''}');
    return _real.candidates(roomId, query: query, friends: friends);
  }

  @override
  Future<({DateTime? waitingUntil, PkMatch? match})> joinRandom(String roomId) {
    calls.add('random');
    return _real.joinRandom(roomId);
  }

  @override
  Future<PkMediaAccess> mediaToken(String roomId, {String? guestId}) {
    calls.add('token');
    return _real.mediaToken(roomId, guestId: guestId);
  }
}

/// The other room's connection: the first [failJoins] joins throw (as a
/// media server or WebRTC failure would); every connection is recorded.
class _FlakyOpponent extends FakePkOpponentMedia {
  int failJoins = 1;
  int joins = 0;
  int leaves = 0;

  @override
  Future<void> join(PkMediaAccess access) async {
    joins += 1;
    if (failJoins > 0) {
      failJoins -= 1;
      throw StateError('could not connect');
    }
    await super.join(access);
  }

  @override
  Future<void> leave() async {
    leaves += 1;
    await super.leave();
  }
}

void main() {
  for (final language in [AppLanguage.ar, AppLanguage.en]) {
    group(language.name, () {
      late FakeHttpAdapter http;
      late FakeLiveRepository live;
      late FakeLiveMediaEngine engine;
      late _HttpPkRepository pk;
      late _FlakyOpponent opponent;

      Future<String> goLive(WidgetTester tester) async {
        http = FakeHttpAdapter();
        live = FakeLiveRepository(categories: _categories);
        engine = FakeLiveMediaEngine();
        pk = _HttpPkRepository(http);
        opponent = _FlakyOpponent();
        setViewport(tester, GoldenViewport.phone);
        await pumpScreen(
          tester,
          const GoLiveScreen(),
          language: language,
          liveMediaEngine: engine,
          livePkRepository: pk,
          pkOpponent: opponent,
          overrides: [
            liveRepositoryProvider.overrideWithValue(live),
            currentUserProvider.overrideWithValue(
              testUser().copyWith(canHost: true),
            ),
            liveBlockedWordsRepositoryProvider.overrideWithValue(
              FakeLiveBlockedWordsRepository(),
            ),
            liveScheduleRepositoryProvider.overrideWithValue(
              FakeLiveScheduleRepository(),
            ),
            profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(apiProfile()),
            ),
          ],
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'PK');
        await tester.tap(find.byKey(GoLiveScreen.startKey));
        await tester.pumpAndSettle();
        final roomId = live.hostRoom!.id;
        final path = '$_base/live/rooms/$roomId/pk';
        // The snapshot follows the server: the match once it is made.
        Map<String, Object?>? matched;
        http
          ..on(
            'GET',
            path,
            (_) => FakeResponse(
              200,
              body: {
                'match': matched,
                'invite': null,
                'queue': null,
                'invitesEnabled': true,
              },
            ),
          )
          ..on(
            'GET',
            '$path/candidates',
            (_) => const FakeResponse(200, body: {'data': <Object>[]}),
          )
          ..on(
            'POST',
            '$path/random',
            (_) => FakeResponse(
              200,
              body: {
                'status': 'MATCHED',
                'queue': null,
                'match': matched = _matchedJson(
                  roomId: roomId,
                  hostId: testUser().id,
                  now: DateTime.now(),
                ),
              },
            ),
          )
          ..on(
            'POST',
            '$path/media-token',
            (_) => FakeResponse(
              200,
              body: {
                'url': 'wss://media.test',
                'token': 't',
                'expiresAt': DateTime.now()
                    .add(const Duration(minutes: 10))
                    .toUtc()
                    .toIso8601String(),
                'roomId': _opponentRoom,
                'identity': 'pk:01a195fb-85b7-7455-91b6-bd7a51719727:me',
                'hostIdentity': _opponentHost,
              },
            ),
          );
        return roomId;
      }

      LivePkController controller(WidgetTester tester, String roomId) =>
          ProviderScope.containerOf(tester.element(find.byType(GoLiveScreen)))
              .read(livePkProvider(roomId).notifier);

      testWidgets('solo live → «مطابقة عشوائية» → MATCHED → battle: the '
          'stage shows and the live goes on, while the other room first '
          'fails to connect', (tester) async {
        final roomId = await goLive(tester);
        expect(find.byKey(GoLiveScreen.pkStageKey), findsNothing);
        await tester.tap(find.byKey(KHostBar.pkKey));
        await tester.pumpAndSettle();
        expect(find.byKey(LivePkSheet.emptyKey), findsOneWidget);
        await tester.tap(find.byKey(LivePkSheet.randomKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(pk.calls, containsAllInOrder(<String>['random', 'token']));
        // The battle: the sheet shows its PK actions, the room its stage.
        expect(find.byKey(LivePkSheet.endKey), findsOneWidget);
        await tester.tap(find.byKey(LivePkSheet.closeKey));
        await tester.pumpAndSettle();
        expect(find.byKey(GoLiveScreen.pkStageKey), findsOneWidget);
        expect(find.byKey(LivePkStage.timerKey), findsOneWidget);
        // The other room failed: nothing half-made is kept, still live.
        expect(opponent.joins, 1);
        expect(opponent.leaves, 1);
        expect(controller(tester, roomId).opponent, isNull);
        expect(engine.stops, 0);
        expect(live.endRequests, isEmpty);
        // The next refresh connects it.
        unawaited(controller(tester, roomId).refresh());
        await tester.pumpAndSettle();
        expect(opponent.joins, 2);
        expect(controller(tester, roomId).opponent, same(opponent));
        expect(
          ProviderScope.containerOf(tester.element(find.byType(GoLiveScreen)))
              .read(livePkProvider(roomId))
              .opponentJoined,
          isTrue,
        );
        expect(find.byKey(GoLiveScreen.pkStageKey), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('the score and the end arrive as data messages (the '
          'API JSON): battle → result → solo again, the other room left', (
        tester,
      ) async {
        final roomId = await goLive(tester);
        opponent.failJoins = 0;
        final now = DateTime.now();
        engine.pk.add(
          PkEvent.parse({
            'type': 'pk-match',
            'event': 'started',
            'match': _matchedJson(
              roomId: roomId,
              hostId: testUser().id,
              now: now,
            ),
          })!,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(GoLiveScreen.pkStageKey), findsOneWidget);
        expect(opponent.joined, isTrue);
        engine.pk.add(
          PkEvent.parse({
            'type': 'pk-match',
            'event': 'score',
            'match': _matchedJson(
              roomId: roomId,
              hostId: testUser().id,
              now: now,
              seq: 2,
              scoreA: 1200,
            ),
          })!,
        );
        await tester.pumpAndSettle();
        expect(controller(tester, roomId).state.match!.sides.$1.score, 1200);
        engine.pk.add(
          PkEvent.parse({
            'type': 'pk-match',
            'event': 'closed',
            'match': _matchedJson(
              roomId: roomId,
              hostId: testUser().id,
              now: now,
              seq: 3,
              status: 'CLOSED',
            ),
          })!,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(GoLiveScreen.pkStageKey), findsNothing);
        expect(opponent.joined, isFalse);
        expect(tester.takeException(), isNull);
        expect(live.endRequests, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('D215 «الأصدقاء»: a failed read is an error with «إعادة '
          'المحاولة» (not «لا يوجد أصدقاء»); a retry shows the friend', (
        tester,
      ) async {
        final roomId = await goLive(tester);
        final path = '$_base/live/rooms/$roomId/pk/candidates';
        http.on(
          'GET',
          path,
          (_) =>
              FakeResponse(500, body: errorEnvelope('INTERNAL_ERROR', 'boom')),
        );
        await tester.tap(find.byKey(KHostBar.pkKey));
        await tester.pumpAndSettle();
        expect(find.byKey(LivePkSheet.emptyKey), findsNothing);
        expect(find.byKey(LivePkSheet.errorKey), findsOneWidget);
        http.on(
          'GET',
          path,
          (_) => const FakeResponse(
            200,
            body: {
              'data': [
                {
                  'roomId': _opponentRoom,
                  'title': 'PK',
                  'viewerCount': 0,
                  'host': {
                    'id': _opponentHost,
                    'username': 'usermvxi3o3w2',
                    'displayName': 'Karim',
                    'avatarUrl': null,
                  },
                },
              ],
            },
          ),
        );
        await tester.tap(find.byKey(LivePkSheet.retryKey));
        await tester.pumpAndSettle();
        expect(find.byKey(LivePkSheet.errorKey), findsNothing);
        expect(
          find.byKey(LivePkSheet.candidateKey(_opponentRoom)),
          findsOneWidget,
        );
        final friendsReads = http.requestsTo('GET', path);
        expect(
          friendsReads.every((r) => r.queryParameters['friends'] == 'true'),
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets('D215 «الأصدقاء»: the open sheet reads the list again, so '
          'a friend who goes live appears without reopening it', (
        tester,
      ) async {
        final roomId = await goLive(tester);
        final path = '$_base/live/rooms/$roomId/pk/candidates';
        LivePkStage.ticks = true;
        addTearDown(() => LivePkStage.ticks = false);
        await tester.tap(find.byKey(KHostBar.pkKey));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byKey(LivePkSheet.emptyKey), findsOneWidget);
        http.on(
          'GET',
          path,
          (_) => const FakeResponse(
            200,
            body: {
              'data': [
                {
                  'roomId': _opponentRoom,
                  'title': 'PK',
                  'viewerCount': 0,
                  'host': {
                    'id': _opponentHost,
                    'username': 'usermvxi3o3w2',
                    'displayName': 'Karim',
                    'avatarUrl': null,
                  },
                },
              ],
            },
          ),
        );
        await tester.pump(LivePkSheet.refreshEvery);
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.byKey(LivePkSheet.candidateKey(_opponentRoom)),
          findsOneWidget,
        );
        LivePkStage.ticks = false;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      });
    });
  }
}
