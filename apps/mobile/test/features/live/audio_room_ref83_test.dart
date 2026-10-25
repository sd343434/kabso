// Owner refs 83/84: the audio room's seats on a circle around the host
// (5, 9 and 13 seats; seat 1 at the top, clockwise, mirrored in Arabic) and
// the room tools sheet with the tools that have no server greyed "Soon".

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_room_tools.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_seat_tiles.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Future<void> _ring(
  WidgetTester tester,
  int count, {
  AppLanguage language = AppLanguage.en,
}) async {
  setViewport(tester, GoldenViewport.phone);
  await pumpScreen(
    tester,
    Scaffold(
      body: SingleChildScrollView(
        child: AudioSeatRing(
          count: count,
          host: const KAvatar(name: 'Layla', size: AudioSeatRing.hostSize),
          hostName: 'Layla',
          hostPoints: '0',
          onSeat: (_) {},
        ),
      ),
    ),
    language: language,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final count in [5, 9, 13]) {
    testWidgets('$count seats: ${count - 1} chairs on a circle around the '
        'host', (tester) async {
      await _ring(tester, count);
      final host = tester.getCenter(find.text('Layla'));
      for (var i = 1; i < count; i++) {
        expect(find.byKey(AudioSeatRing.seatKey(i)), findsOneWidget);
      }
      // Seat 1 is at the top, just after 12 o'clock (to the right in LTR).
      final first = tester.getCenter(find.byKey(AudioSeatRing.seatKey(1)));
      expect(first.dx, greaterThan(host.dx));
      expect(first.dy, lessThan(host.dy));
    });
  }

  testWidgets('Arabic mirrors the circle: seat 1 to the left of the top', (
    tester,
  ) async {
    await _ring(tester, 9, language: AppLanguage.ar);
    final host = tester.getCenter(find.text('Layla'));
    final first = tester.getCenter(find.byKey(AudioSeatRing.seatKey(1)));
    expect(first.dx, lessThan(host.dx));
    expect(first.dy, lessThan(host.dy));
  });

  testWidgets('tools without a server are greyed "Soon" and do nothing', (
    tester,
  ) async {
    var opened = 0;
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showLiveRoomTools(
                context,
                room: [
                  GoLiveTool(
                    id: 'topic',
                    icon: Icons.forum_outlined,
                    label: 'Topic',
                    onTap: () => opened++,
                  ),
                  const GoLiveTool.soon(
                    id: 'music',
                    icon: Icons.music_note_rounded,
                    label: 'Music',
                  ),
                ],
                other: const [],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final l10n = l10nFor(AppLanguage.en);
    expect(find.bySemanticsLabel('Music, ${l10n.liveSoon}'), findsOneWidget);
    expect(find.text(l10n.liveSoon), findsOneWidget);
    await tester.tap(find.byKey(GoLiveKeys.tool('music')));
    await tester.pumpAndSettle();
    expect(opened, 0);
    await tester.tap(find.byKey(GoLiveKeys.tool('topic')));
    await tester.pumpAndSettle();
    expect(opened, 1);
  });
}
