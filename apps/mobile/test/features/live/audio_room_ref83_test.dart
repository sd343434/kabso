// Owner refs 83/84 and D118: the audio room's seats in rows of 5 for every
// size (5, 10, 15, 20, 25; no circle any more) with the host as the first
// tile, mirrored in Arabic; empty seats readable on every theme; and the
// room tools sheet with the tools that have no server greyed "Soon".

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
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
          host: const KAvatar(name: 'Layla', size: AudioSeatRing.picture),
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
  testWidgets('D118: an empty seat is a dark glass circle with a light '
      'ring and a white seat; a locked one shows a lock', (tester) async {
    setViewport(tester, GoldenViewport.phone);
    await pumpScreen(
      tester,
      Scaffold(
        body: AudioSeatRing(
          count: 5,
          host: const KAvatar(name: 'Layla', size: AudioSeatRing.picture),
          hostName: 'Layla',
          seats: const [
            LiveSeat(index: 1, state: LiveSeatState.empty, user: null),
            LiveSeat(index: 2, state: LiveSeatState.locked, user: null),
          ],
          onSeat: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    BoxDecoration glass(int i) =>
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byKey(AudioSeatRing.seatKey(i)),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
    for (final i in [1, 2, 3, 4]) {
      final d = glass(i);
      expect(d.shape, BoxShape.circle);
      expect(d.gradient, isNotNull);
      // The fill stays dark and mostly opaque, the ring light.
      final colors = (d.gradient! as LinearGradient).colors;
      for (final c in colors) {
        expect(c.a, greaterThan(0.5));
        expect(c.computeLuminance(), lessThan(0.05));
      }
      expect((d.border! as Border).top.color.computeLuminance(), 1);
      expect(d.boxShadow, isNotEmpty);
      expect(
        tester.getSize(find.byKey(AudioSeatRing.seatKey(i))).width,
        greaterThanOrEqualTo(AudioSeatRing.picture),
      );
    }
    expect(
      find.descendant(
        of: find.byKey(AudioSeatRing.seatKey(2)),
        matching: find.byIcon(Icons.lock_rounded),
      ),
      findsOneWidget,
    );
    // The seat's number under it.
    expect(
      find.descendant(
        of: find.byKey(AudioSeatRing.seatKey(3)),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('25 seats with the chat on a 360 × 800 phone: every row shows '
      'above the chat (they hid under it, owner 2026-10-26)', (tester) async {
    setViewport(tester, GoldenViewport.android);
    await pumpScreen(
      tester,
      Scaffold(
        body: LiveAudioRoomLayout(
          header: const SizedBox(height: 48),
          chips: const SizedBox(height: 32),
          stage: AudioSeatRing(
            count: 25,
            host: const KAvatar(name: 'Layla', size: AudioSeatRing.picture),
            hostName: 'Layla',
            hostPoints: '0',
            onSeat: (_) {},
          ),
          chat: [
            for (var i = 0; i < 6; i++)
              SizedBox(key: ValueKey('chat$i'), height: 36),
          ],
          barStart: const [SizedBox.square(dimension: 44)],
          barEnd: const [SizedBox.square(dimension: 44)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chatTop = tester.getTopLeft(find.byKey(const ValueKey('chat0'))).dy;
    for (var i = 1; i <= 24; i++) {
      final seat = tester.getRect(find.byKey(AudioSeatRing.seatKey(i)));
      expect(seat.bottom, lessThanOrEqualTo(chatTop), reason: 'seat $i');
    }
  });

  for (final count in [5, 10, 15, 20, 25]) {
    testWidgets('$count seats (D100, D118): rows of 5, the host the first '
        'tile, in reading order', (tester) async {
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
      expect(find.byKey(AudioSeatRing.seatKey(count)), findsNothing);
      if (count > 5) {
        // Seat 5 starts the second row, under the host.
        expect(at(5).dy, greaterThan(at(1).dy));
        expect(at(5).dx, lessThan(at(1).dx));
      }
      if (count > 10) {
        // Owner request: the same spacing between every pair of rows, the
        // first row (with the host's name and points) included.
        final pitch = at(6).dy - at(1).dy;
        for (var row = 2; row * 5 + 1 <= guests; row++) {
          expect(at(row * 5 + 1).dy - at(row * 5 - 4).dy, closeTo(pitch, 0.5));
        }
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
    for (final count in [5, 10, 15]) {
      await _ring(tester, count, language: AppLanguage.ar);
      final host = tester.getCenter(find.text('Layla'));
      final one = tester.getCenter(find.byKey(AudioSeatRing.seatKey(1)));
      final two = tester.getCenter(find.byKey(AudioSeatRing.seatKey(2)));
      expect(host.dx, greaterThan(one.dx), reason: '$count');
      expect(one.dx, greaterThan(two.dx), reason: '$count');
      // One row: the tiles start at the same height.
      expect(
        tester.getRect(find.byKey(AudioSeatRing.seatKey(1))).top,
        closeTo(tester.getRect(find.byKey(AudioSeatRing.seatKey(0))).top, 0.5),
        reason: '$count: one row',
      );
    }
    await _ring(tester, 15, language: AppLanguage.ar);
    final host = tester.getCenter(find.text('Layla'));
    final one = tester.getCenter(find.byKey(AudioSeatRing.seatKey(1)));
    final two = tester.getCenter(find.byKey(AudioSeatRing.seatKey(2)));
    expect(host.dx, greaterThan(one.dx));
    expect(one.dx, greaterThan(two.dx));
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
