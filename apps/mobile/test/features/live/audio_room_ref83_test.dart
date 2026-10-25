// Owner refs 83/84: the audio room's seats on a circle around the host
// (6 and 9 seats; seat 1 at the top, clockwise, mirrored in Arabic), owner
// D100: 15, 20 and 25 seats in rows of 5 with the host as the first tile,
// and the room tools sheet with the tools that have no server greyed "Soon".

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
  for (final count in [6, 9]) {
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

  for (final count in [15, 20, 25]) {
    testWidgets('$count seats (D100): rows of 5, the host the first tile, '
        'in reading order', (tester) async {
      await _ring(tester, count);
      final host = tester.getCenter(find.text('Layla'));
      final guests = count - 1;
      for (var i = 1; i <= guests; i++) {
        expect(find.byKey(AudioSeatRing.seatKey(i)), findsOneWidget);
      }
      Offset at(int i) =>
          tester.getCenter(find.byKey(AudioSeatRing.seatKey(i)));
      // The first row: the host, then seats 1-4, start to end.
      expect(host.dx, lessThan(at(1).dx));
      for (var i = 2; i <= 4; i++) {
        expect(at(i).dy, closeTo(at(1).dy, 0.5));
        expect(at(i).dx, greaterThan(at(i - 1).dx));
      }
      // Seat 5 starts the second row, under the host.
      expect(at(5).dy, greaterThan(at(1).dy));
      expect(at(5).dx, lessThan(at(1).dx));
      // Owner request: the same spacing between every pair of rows, the
      // first row (with the host's name and points) included.
      final pitch = at(6).dy - at(1).dy;
      for (var row = 2; row * 5 + 1 <= guests; row++) {
        expect(at(row * 5 + 1).dy - at(row * 5 - 4).dy, closeTo(pitch, 0.5));
      }
      // Every seat stays on the phone's width.
      for (var i = 1; i <= guests; i++) {
        expect(at(i).dx, inInclusiveRange(0, 430));
      }
    });
  }

  testWidgets('Arabic mirrors the rows: the host at the right, then seat 1', (
    tester,
  ) async {
    await _ring(tester, 15, language: AppLanguage.ar);
    final host = tester.getCenter(find.text('Layla'));
    final one = tester.getCenter(find.byKey(AudioSeatRing.seatKey(1)));
    final two = tester.getCenter(find.byKey(AudioSeatRing.seatKey(2)));
    expect(host.dx, greaterThan(one.dx));
    expect(one.dx, greaterThan(two.dx));
  });

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
