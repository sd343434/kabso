// D224 item 4 (owner, 2026-11-01: «عند فتح بث اجعل شريط اختيار نوع البث
// يمكن سحبه يمين ويسار ليسهل التنقل»): the go-live setup's live-type row
// (multi · live · audio · podcast · streamer «قريباً») scrolls sideways under
// a finger, the chosen type is brought to the middle on open and when it
// changes, a tap still chooses, and «ستريمر» stays not selectable. Both
// setups (video: GoLiveModePager; audio / podcast: the audio setup's tabs),
// Arabic RTL and English LTR at 393×852 and 360×800 with text ×1.3.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_blocked_words_repository.dart';
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/go_live_screen.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_audio_setup.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_blocked_words_repository.dart';
import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_repository.dart';
import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  required AppLanguage language,
  required GoldenViewport viewport,
}) async {
  setViewport(tester, viewport);
  tester.platformDispatcher.textScaleFactorTestValue = 1.3;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await pumpScreen(
    tester,
    const GoLiveScreen(),
    language: language,
    liveMediaEngine: FakeLiveMediaEngine(),
    overrides: [
      liveRepositoryProvider.overrideWithValue(FakeLiveRepository()),
      currentUserProvider.overrideWithValue(testUser().copyWith(canHost: true)),
      liveBlockedWordsRepositoryProvider.overrideWithValue(
        FakeLiveBlockedWordsRepository(),
      ),
      liveScheduleRepositoryProvider.overrideWithValue(
        FakeLiveScheduleRepository(),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

/// The live-type row's scroll position.
ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(GoLiveKeys.modeRow),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

/// [mode]'s tab is whole on screen and (within a few points) in the
/// middle of the row.
void _expectCentred(WidgetTester tester, LiveRoomMode mode) {
  final row = tester.getRect(find.byKey(GoLiveKeys.modeRow));
  final tab = tester.getRect(find.byKey(GoLiveKeys.mode(mode)));
  expect(tab.left, greaterThanOrEqualTo(row.left), reason: '$mode');
  expect(tab.right, lessThanOrEqualTo(row.right), reason: '$mode');
  expect((tab.center.dx - row.center.dx).abs(), lessThan(4), reason: '$mode');
}

void main() {
  for (final language in AppLanguage.values) {
    for (final viewport in GoldenViewport.values) {
      final tag = '${language.name}, ${viewport.name}, text ×1.3';

      // D213: Android offers «بث ستريمر» as a real mode (streamer_d213_test);
      // the greyed «قريباً» tab stays on iOS, where this row is checked.
      testWidgets('the type row scrolls sideways, the chosen type comes to '
          'the middle, a tap chooses, «ستريمر» does not on iOS ($tag)', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          await _body(tester, language: language, viewport: viewport);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}

Future<void> _body(
  WidgetTester tester, {
  required AppLanguage language,
  required GoldenViewport viewport,
}) async {
  await _pump(tester, language: language, viewport: viewport);
  // Video setup: «بث مباشر» (solo) chosen and in the middle on open.
  expect(find.byKey(GoLiveKeys.modeRow), findsOneWidget);
  _expectCentred(tester, LiveRoomMode.solo);

  // A finger moves the row both ways; it is a real scroll view.
  final position = _position(tester);
  final start = position.pixels;
  final rtl = language == AppLanguage.ar;
  await tester.drag(
    find.byKey(GoLiveKeys.modeRow),
    Offset(rtl ? 120 : -120, 0),
  );
  await tester.pumpAndSettle();
  expect(position.pixels, greaterThan(start));
  // The streamer tab at the far end is reachable by dragging.
  await tester.drag(
    find.byKey(GoLiveKeys.modeRow),
    Offset(rtl ? 400 : -400, 0),
  );
  await tester.pumpAndSettle();
  final row = tester.getRect(find.byKey(GoLiveKeys.modeRow));
  final streamer = tester.getRect(find.byKey(GoLiveKeys.streamer));
  expect(streamer.left, greaterThanOrEqualTo(row.left));
  expect(streamer.right, lessThanOrEqualTo(row.right));

  // A tap on a type chooses it: the podcast's setup, its row with the
  // podcast in the middle.
  await tester.ensureVisible(find.byKey(GoLiveKeys.mode(LiveRoomMode.podcast)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.podcast)));
  await tester.pumpAndSettle();
  expect(find.byType(GoLiveAudioSetup), findsOneWidget);
  _expectCentred(tester, LiveRoomMode.podcast);
  // …and the audio one (a drag or the next tab away), scrolled to the
  // middle again.
  await tester.ensureVisible(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.audio)));
  await tester.pumpAndSettle();
  _expectCentred(tester, LiveRoomMode.audio);
  // The audio setup's row scrolls too.
  final audio = _position(tester);
  final before = audio.pixels;
  await tester.drag(
    find.byKey(GoLiveKeys.modeRow),
    Offset(rtl ? -150 : 150, 0),
  );
  await tester.pumpAndSettle();
  expect(audio.pixels, lessThan(before));
  // Back to the live: its row centres «بث مباشر» again.
  await tester.ensureVisible(find.byKey(GoLiveKeys.mode(LiveRoomMode.solo)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(GoLiveKeys.mode(LiveRoomMode.solo)));
  await tester.pumpAndSettle();
  expect(find.byType(GoLiveAudioSetup), findsNothing);
  _expectCentred(tester, LiveRoomMode.solo);
  // «ستريمر · قريباً» is not selectable: the setup stays the video one
  // and the row keeps «بث مباشر» chosen.
  await tester.ensureVisible(find.byKey(GoLiveKeys.streamer));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(GoLiveKeys.streamer));
  await tester.pump();
  expect(find.byType(GoLiveAudioSetup), findsNothing);
  expect(
    tester.getSemantics(find.byKey(GoLiveKeys.mode(LiveRoomMode.solo))),
    isSemantics(isSelected: true),
  );
  expect(tester.takeException(), isNull);
  await _leave(tester);
}
