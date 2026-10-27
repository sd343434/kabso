// D120 (owner): the host taps their own live and it counts like a viewer's
// tap; every tap pops one of all ten tap characters. A tap on an empty part
// of the stage cheers; seats, the bar and the chat keep their own taps.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_host_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:kabso_live/features/live/presentation/go_live/seat_controls.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_tools.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_tap_layer.dart';
import 'package:kabso_live/features/profile/data/profile_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../fixtures/live/live_api_fixtures.dart';
import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fake_profile_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Future<FakeLiveRepository> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
}) async {
  final repo = FakeLiveRepository();
  setViewport(tester, GoldenViewport.phone);
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    language: language,
    liveMediaEngine: FakeLiveMediaEngine(),
    overrides: [
      liveRepositoryProvider.overrideWithValue(repo),
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
    ],
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Audio: Go LIVE, the 3-2-1 countdown, then the room.
Future<void> _audioLive(WidgetTester tester) async {
  await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Voices');
  await tester.tap(find.byKey(GoLiveScreen.startKey));
  await tester.pump();
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pumpAndSettle();
}

Future<void> _soloLive(WidgetTester tester) async {
  await tester.enterText(find.byKey(GoLiveScreen.titleKey), 'Evening chat');
  await tester.tap(find.byKey(GoLiveScreen.startKey));
  await tester.pumpAndSettle();
}

/// An empty part of the audio stage: between the seats and the bar, at the
/// screen's end edge (no seat, no chat line, no button there).
Offset _emptyStage(WidgetTester tester) {
  final layer = tester.getRect(find.byKey(LiveTapLayer.tapKey));
  final lastSeat = tester.getRect(find.byKey(AudioSeatRing.seatKey(9)));
  return Offset(layer.right - 12, lastSeat.bottom + 40);
}

List<String> _characters(WidgetTester tester) => [
  for (final image in tester.widgetList<Image>(
    find.descendant(
      of: find.byType(LiveTapCharacter),
      matching: find.byType(Image),
    ),
  ))
    (image.image as AssetImage).assetName,
];

void main() {
  testWidgets('no tap layer before the live starts', (tester) async {
    await _pump(tester);
    expect(find.byKey(LiveTapLayer.tapKey), findsNothing);
    await _leave(tester);
  });

  testWidgets('audio: the host taps an empty part of the stage — characters '
      'pop, one batch a second is sent and the score shows', (tester) async {
    final repo = await _pump(tester);
    await _audioLive(tester);
    expect(find.byKey(LiveTapLayer.tapKey), findsOneWidget);
    final at = _emptyStage(tester);
    for (var i = 0; i < 6; i++) {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 60));
    }
    final shown = _characters(tester);
    expect(shown, hasLength(6));
    // D120: they rise in the right-hand lane just above the audio bar, not
    // where the finger was.
    final layer = tester.getRect(find.byKey(LiveTapLayer.tapKey));
    final lane = LiveTapLayer.lane(layer.size, 56).shift(layer.topLeft);
    for (final e
        in find
            .descendant(
              of: find.byType(LiveTapCharacter),
              matching: find.byType(Image),
            )
            .evaluate()) {
      final r = tester.getRect(find.byWidget(e.widget));
      expect(lane.inflate(0.5).contains(r.center), isTrue);
    }
    expect(
      lane.bottom,
      lessThanOrEqualTo(
        tester.getRect(find.byKey(GoLiveScreen.audioChatKey)).top,
      ),
    );
    expect(shown.every(CharmTier.values.map((t) => t.tap).contains), isTrue);
    // D120: never the same character twice in a row.
    for (var i = 1; i < shown.length; i++) {
      expect(shown[i], isNot(shown[i - 1]));
    }
    expect(repo.tapBatches, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(repo.tapBatches.single.count, 6);
    await tester.pumpAndSettle();
    expect(find.byType(LiveTapCharacter), findsNothing);
    // The answer's score shows in the host's room bar.
    expect(find.byType(LiveScoreChip), findsOneWidget);
    await _leave(tester);
  });

  testWidgets('audio: a tap on a seat still opens its menu and does not '
      'cheer; the chat button still opens the chat', (tester) async {
    final repo = await _pump(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(GoLiveScreen)));
    await _audioLive(tester);
    await tester.tap(find.byKey(AudioSeatRing.seatKey(1)));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(LiveTapCharacter), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text(l10n.liveSeatLock), findsOneWidget);
    await tester.tap(find.byKey(SeatControlKeys.cancel));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(GoLiveScreen.audioChatKey));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(LiveTapCharacter), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(LiveRoomComposer), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(repo.tapBatches, isEmpty);
    await _leave(tester);
  });

  testWidgets('solo: the host taps their own video and it counts', (
    tester,
  ) async {
    final repo = await _pump(tester);
    await _soloLive(tester);
    final layer = tester.getRect(find.byKey(LiveTapLayer.tapKey));
    await tester.tapAt(Offset(layer.center.dx, layer.top + layer.height * 0.4));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(LiveTapCharacter), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(repo.tapBatches.single.count, 1);
    // The host bar keeps its taps (D131).
    await tester.tap(find.byKey(KHostBar.pkKey));
    await tester.pump(const Duration(seconds: 2));
    expect(repo.tapBatches, hasLength(1));
    await tester.pumpAndSettle();
    await _leave(tester);
  });
}
