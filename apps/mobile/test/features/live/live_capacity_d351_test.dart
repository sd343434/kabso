// D351 (v1.113-live, CONVENTIONS §10.148): the capacity guard «حد الامتلاء».
// A go-live refused with LIVE_CAPACITY_FULL shows «البث مزدحم الآن، حاول بعد
// قليل» in a sheet — never an error toast — on every go-live path (video,
// PK host, multi-guest, audio, podcast, streamer); «حاول مجددًا» waits out
// `Retry-After` (60 s without the header) and then starts again the same way;
// the setup is kept. Plus the mapping (error_mapper / failure_messages).

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_background.dart';
import 'package:kabso_live/features/live/application/live_host_controller.dart';
import 'package:kabso_live/features/live/application/live_streamer_host.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/data/streamer/live_streamer_platform.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/live_capacity_sheet.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fake_streamer_platform.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

final _categories = [const LiveCategory(slug: 'chat', name: 'Chat')];

ServerFailure _full([int? seconds = 45]) => ServerFailure(
  code: ErrorCode.liveCapacityFull,
  rawCode: 'LIVE_CAPACITY_FULL',
  debugMessage: 'Live is busy right now, please try again shortly.',
  statusCode: 503,
  retryAfter: seconds == null ? null : Duration(seconds: seconds),
);

Future<FakeLiveRepository> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  List<Override> overrides = const [],
}) async {
  final live = FakeLiveRepository(categories: _categories);
  setViewport(tester, GoldenViewport.phone);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    language: language,
    liveMediaEngine: FakeLiveMediaEngine(),
    overrides: [
      liveRepositoryProvider.overrideWithValue(live),
      currentUserProvider.overrideWithValue(testUser().copyWith(canHost: true)),
      liveBlockedWordsRepositoryProvider.overrideWithValue(
        FakeLiveBlockedWordsRepository(),
      ),
      liveScheduleRepositoryProvider.overrideWithValue(
        FakeLiveScheduleRepository(),
      ),
      profileRepositoryProvider.overrideWithValue(
        FakeProfileRepository(apiProfile()),
      ),
      ...overrides,
    ],
  );
  await tester.pumpAndSettle();
  return live;
}

LiveHostController _host(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GoLiveScreen)))
        .read(liveHostControllerProvider.notifier);

GoLiveState _state(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(GoLiveScreen)))
        .read(liveHostControllerProvider);

Future<void> _tapStart(WidgetTester tester, String title) async {
  await tester.enterText(find.byKey(GoLiveScreen.titleKey), title);
  await tester.tap(find.byKey(GoLiveScreen.startKey));
  // An audio / podcast live counts 3, 2, 1 before the room is asked for.
  if (_state(tester).mode.isVoice) {
    await tester.pump(const Duration(seconds: 4));
  }
  await tester.pumpAndSettle();
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Finder get _retry => find.byKey(LiveCapacityKeys.retry);

bool _enabled(WidgetTester tester) =>
    tester.widget<KButton>(find.byKey(LiveCapacityKeys.retry)).onPressed !=
    null;

void main() {
  group('LIVE_CAPACITY_FULL mapping (D351)', () {
    test('the wire code, its message (ar / en) and its wait', () {
      expect(
        ErrorCode.fromWire('LIVE_CAPACITY_FULL'),
        ErrorCode.liveCapacityFull,
      );
      final ar = l10nFor(AppLanguage.ar);
      final en = l10nFor(AppLanguage.en);
      expect(
        errorCodeMessage(ar, ErrorCode.liveCapacityFull),
        'البث مزدحم الآن، حاول بعد قليل',
      );
      expect(
        errorCodeMessage(en, ErrorCode.liveCapacityFull),
        'Live is busy right now, please try again shortly.',
      );
      // Not the generic «service busy» countdown text: its own words.
      expect(failureMessage(en, _full()), en.errorLiveCapacityFull);
      expect(isLiveCapacityFull(_full()), isTrue);
      expect(isLiveCapacityFull(const NetworkFailure.offline()), isFalse);
      expect(liveCapacityWait(_full()), const Duration(seconds: 45));
      expect(liveCapacityWait(_full(null)), const Duration(seconds: 60));
      expect(liveCapacityWait(_full(0)), const Duration(seconds: 60));
    });

    test('the 503 with Retry-After maps to it', () {
      final failure = mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/live/rooms'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/live/rooms'),
            statusCode: 503,
            data: {
              'error': {
                'code': 'LIVE_CAPACITY_FULL',
                'message': 'Live is busy right now.',
                'requestId': 'rid-351',
              },
            },
            headers: Headers.fromMap({
              'retry-after': ['60'],
            }),
          ),
        ),
      ) as ServerFailure;
      expect(failure.code, ErrorCode.liveCapacityFull);
      expect(failure.statusCode, 503);
      expect(failure.retryAfter, const Duration(seconds: 60));
    });
  });

  group('go-live refused by the capacity guard (D351)', () {
    testWidgets('video: the sheet, the countdown, then «Try again» goes live', (
      tester,
    ) async {
      final repo = await _pump(tester);
      repo.startFailure = _full();
      await _tapStart(tester, 'Evening chat');

      expect(find.byKey(LiveCapacityKeys.sheet), findsOneWidget);
      expect(
        find.text('Live is busy right now, please try again shortly.'),
        findsOneWidget,
      );
      // No error toast, no D210 failure line: a busy server, not an error.
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(GoLiveScreen.failureDetailsKey), findsNothing);
      // The setup is kept.
      expect(_state(tester).phase, GoLivePhase.preview);
      expect(repo.startRequests, hasLength(1));

      // «Try again» waits out Retry-After.
      expect(_enabled(tester), isFalse);
      expect(find.text('Try again in 0:45'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Try again in 0:15'), findsOneWidget);
      await tester.tap(_retry, warnIfMissed: false);
      await tester.pump();
      expect(repo.startRequests, hasLength(1));
      await tester.pump(const Duration(seconds: 15));
      expect(_enabled(tester), isTrue);
      expect(find.text('Try again'), findsOneWidget);

      // Room again: this time it fits.
      repo.startFailure = null;
      await tester.tap(_retry);
      await tester.pumpAndSettle();
      expect(find.byKey(LiveCapacityKeys.sheet), findsNothing);
      expect(repo.startRequests, hasLength(2));
      expect(repo.startRequests.last.title, 'Evening chat');
      expect(_state(tester).phase, GoLivePhase.live);
      await _host(tester).end();
      await _leave(tester);
    });

    testWidgets('«Later» closes it and keeps the setup (Arabic)', (
      tester,
    ) async {
      final repo = await _pump(tester, language: AppLanguage.ar);
      repo.startFailure = _full(null);
      await _tapStart(tester, 'سهرة');
      expect(find.text('البث مزدحم الآن، حاول بعد قليل'), findsOneWidget);
      expect(find.text('حاول مجددًا بعد 1:00'), findsOneWidget);
      await tester.tap(find.byKey(LiveCapacityKeys.close));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveCapacityKeys.sheet), findsNothing);
      expect(repo.startRequests, hasLength(1));
      expect(_state(tester).phase, GoLivePhase.preview);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        'سهرة',
      );
      await _leave(tester);
    });

    for (final mode in [
      LiveRoomMode.pk,
      LiveRoomMode.multi,
      LiveRoomMode.audio,
      LiveRoomMode.podcast,
    ]) {
      testWidgets('${mode.name}: the same sheet', (tester) async {
        final repo = await _pump(tester);
        await _host(tester).setMode(mode);
        await tester.pumpAndSettle();
        repo.startFailure = _full();
        await _tapStart(tester, 'Busy night');
        expect(repo.startRequests.single.mode, mode);
        expect(find.byKey(LiveCapacityKeys.sheet), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(_state(tester).phase, GoLivePhase.preview);
        await _leave(tester);
      });
    }

    testWidgets('streamer: the same sheet, no «problem report»', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        overrides: [
          streamerPlatformProvider.overrideWithValue(FakeStreamerPlatform()),
          liveBackgroundServiceProvider.overrideWithValue(FakeBackground()),
        ],
      );
      await _host(tester).setMode(LiveRoomMode.streamer);
      await tester.pumpAndSettle();
      repo.startFailure = _full();
      await _tapStart(tester, 'Playing now');
      expect(repo.startRequests.single.mode, LiveRoomMode.streamer);
      expect(find.byKey(LiveCapacityKeys.sheet), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GoLiveScreen)),
      );
      expect(container.read(liveStreamerHostProvider).failure, isNull);
      await _leave(tester);
    });
  });
}
