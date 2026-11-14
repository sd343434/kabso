// D154e («قائمة البرامج», CONVENTIONS §10.37): the live's program — the
// card everyone sees (loaded on joining, the segment on now, «بدأت الفقرة»
// when the server announces one, the host's changes live), the whole list,
// the host's editor (save, order, the 10-segment limit) and the data
// messages — Arabic RTL and English LTR at 360×800.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_program.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_program.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_program_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_program_card.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_media_engine.dart';
import '../../helpers/fake_live_program_repository.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

const _room = 'room-0';
final _start = DateTime.utc(2026, 10, 28, 20);

LiveProgram _program({int? current = 0}) => LiveProgram(
  roomId: _room,
  items: [
    LiveProgramItem(position: 0, startsAt: _start, title: 'Opening'),
    LiveProgramItem(
      position: 1,
      startsAt: _start.add(const Duration(minutes: 30)),
      title: 'أسئلة وأجوبة',
    ),
    LiveProgramItem(
      position: 2,
      startsAt: _start.add(const Duration(hours: 1)),
      title: 'Songs',
    ),
  ],
  current: current,
);

/// The room's layer as a live shows it: the card at the reading end,
/// attached to [engine] (as the room screens do).
class _Room extends ConsumerStatefulWidget {
  const new(this.engine);

  final FakeLiveMediaEngine engine;

  @override
  ConsumerState<_Room> createState() => _RoomState();
}

class _RoomState extends ConsumerState<_Room> {
  @override
  void initState() {
    super.initState();
    ref.read(liveProgramProvider(_room).notifier).attach(widget.engine);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF333344),
    body: Stack(
      children: [
        const PositionedDirectional(
          top: LiveProgramCard.top,
          end: 8,
          child: LiveProgramCard(roomId: _room),
        ),
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Builder(
              builder: (context) => TextButton(
                key: const Key('test.edit'),
                onPressed: () => showLiveProgramEditor(
                  context,
                  roomId: _room,
                  startedAt: _start,
                ),
                child: const SizedBox.square(dimension: 40),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<(FakeLiveProgramRepository, FakeLiveMediaEngine)> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  LiveProgram? program,
}) async {
  setViewport(tester, GoldenViewport.android);
  final repo = FakeLiveProgramRepository(
    programs: {_room: ?program},
    now: () => _start.add(const Duration(minutes: 5)),
  );
  final engine = FakeLiveMediaEngine();
  await pumpScreen(
    tester,
    _Room(engine),
    language: language,
    liveProgramRepository: repo,
    liveMediaEngine: engine,
  );
  await tester.pumpAndSettle();
  return (repo, engine);
}

void main() {
  for (final language in AppLanguage.values) {
    testWidgets('a late joiner sees the segment on now; an announced one '
        'shows «بدأت الفقرة» and becomes current (${language.name})', (
      tester,
    ) async {
      final (repo, engine) = await _pump(
        tester,
        language: language,
        program: _program(),
      );
      final ar = language == AppLanguage.ar;
      expect(repo.reads, 1);
      expect(find.byKey(LiveProgramCard.cardKey), findsOneWidget);
      expect(find.text(ar ? 'الآن' : 'Now'), findsOneWidget);
      expect(find.text('Opening'), findsOneWidget);
      // At the reading end: right in English, left in Arabic.
      final box = tester.getRect(find.byKey(LiveProgramCard.cardKey));
      if (ar) {
        expect(box.left, 8);
      } else {
        expect(box.right, 360 - 8);
      }
      expect(box.width, lessThanOrEqualTo(LiveProgramCard.maxWidth));

      engine.chat.add(LiveProgramSegmentStarted(_program().items[1]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(ar ? 'بدأت الفقرة' : 'Starting now'), findsOneWidget);
      expect(find.text('أسئلة وأجوبة'), findsOneWidget);
      await tester.pump(LivePrograms.announceTime);
      await tester.pumpAndSettle();
      expect(find.text(ar ? 'الآن' : 'Now'), findsOneWidget);
      expect(find.text('أسئلة وأجوبة'), findsOneWidget);

      // The whole list, the current segment marked.
      await tester.tap(find.byKey(LiveProgramCard.cardKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveProgramList.listKey), findsOneWidget);
      for (final p in [0, 1, 2]) {
        expect(find.byKey(LiveProgramList.itemKey(p)), findsOneWidget);
      }
      expect(
        tester.getSemantics(find.byKey(LiveProgramList.itemKey(1))),
        isSemantics(isSelected: true),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('before the first segment the card shows the next one; the '
      "host's change arrives live; an empty program hides it", (tester) async {
    final (_, engine) = await _pump(tester, program: _program(current: null));
    expect(find.textContaining('Next at'), findsOneWidget);
    expect(find.text('Opening'), findsOneWidget);
    engine.chat.add(
      LiveProgramChanged(
        LiveProgram(
          roomId: _room,
          items: [
            LiveProgramItem(position: 0, startsAt: _start, title: 'Intro'),
          ],
          current: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Intro'), findsOneWidget);
    engine.chat.add(
      const LiveProgramChanged(LiveProgram(roomId: _room, items: [])),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(LiveProgramCard.cardKey), findsNothing);
    // Another room's message changes nothing.
    engine.chat.add(LiveProgramChanged(_program().withRoom('room-9')));
    await tester.pumpAndSettle();
    expect(find.byKey(LiveProgramCard.cardKey), findsNothing);
  });

  testWidgets('no program: no card', (tester) async {
    await _pump(tester);
    expect(find.byKey(LiveProgramCard.cardKey), findsNothing);
  });

  for (final language in AppLanguage.values) {
    testWidgets("the host's editor: edit, add, save; the card follows "
        '(${language.name})', (tester) async {
      final (repo, _) = await _pump(
        tester,
        language: language,
        program: _program(),
      );
      await tester.tap(find.byKey(const Key('test.edit')));
      await tester.pumpAndSettle();
      expect(find.byKey(LiveProgramEditor.titleKey(2)), findsOneWidget);
      await tester.enterText(find.byKey(LiveProgramEditor.titleKey(0)), 'Hi');
      await tester.tap(find.byKey(LiveProgramEditor.addKey));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(LiveProgramEditor.titleKey(3)),
        'Goodbye',
      );
      await tester.ensureVisible(find.byKey(LiveProgramEditor.saveKey));
      await tester.tap(find.byKey(LiveProgramEditor.saveKey));
      await tester.pumpAndSettle();
      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.map((d) => d.title), [
        'Hi',
        'أسئلة وأجوبة',
        'Songs',
        'Goodbye',
      ]);
      // The new segment is 15 minutes after the last one.
      expect(
        repo.saved.single.last.startsAt.toUtc(),
        _start.add(const Duration(minutes: 75)),
      );
      expect(find.byKey(LiveProgramEditor.saveKey), findsNothing);
      expect(find.text('Hi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the editor refuses starts out of order and stops at 10', (
    tester,
  ) async {
    final (repo, _) = await _pump(
      tester,
      program: LiveProgram(
        roomId: _room,
        items: [
          for (var i = 0; i < 9; i++)
            LiveProgramItem(
              position: i,
              startsAt: _start.add(Duration(minutes: 10 * (9 - i))),
              title: 'S$i',
            ),
        ],
      ),
    );
    await tester.tap(find.byKey(const Key('test.edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(LiveProgramEditor.addKey));
    await tester.pumpAndSettle();
    expect(find.byKey(LiveProgramEditor.addKey), findsNothing);
    await tester.tap(find.byKey(LiveProgramEditor.saveKey));
    await tester.pumpAndSettle();
    expect(
      find.text('Put the segments in order of their start times'),
      findsOneWidget,
    );
    expect(repo.saved, isEmpty);
  });

  test('a picked time is placed on or after the live start', () {
    final start = DateTime(2026, 10, 28, 23, 40);
    expect(
      LiveProgramEditor.placeTime(const TimeOfDay(hour: 23, minute: 50), start),
      DateTime(2026, 10, 28, 23, 50),
    );
    expect(
      LiveProgramEditor.placeTime(const TimeOfDay(hour: 0, minute: 30), start),
      DateTime(2026, 10, 29, 0, 30),
    );
  });

  test('the data messages', () {
    final changed = LiveChatEvent.parse({
      'type': 'program',
      'program': {
        'roomId': _room,
        'items': [
          {
            'position': 0,
            'startsAt': '2026-10-28T20:00:00.000Z',
            'title': 'Opening',
          },
        ],
        'current': null,
      },
    });
    expect(changed, isA<LiveProgramChanged>());
    expect(
      (changed! as LiveProgramChanged).program.items.single.title,
      'Opening',
    );
    final segment = LiveChatEvent.parse({
      'type': 'program-segment',
      'item': {
        'position': 1,
        'startsAt': '2026-10-28T20:30:00.000Z',
        'title': 'Q&A',
      },
    });
    expect((segment! as LiveProgramSegmentStarted).item.position, 1);
    expect(LiveChatEvent.parse({'type': 'program'}), isNull);
  });
}
