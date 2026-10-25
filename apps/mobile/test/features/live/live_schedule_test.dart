// CP-016 C (D99): the host's live schedule sheet — the upcoming lives with
// n/10, scheduling one (title, date and time through the pickers), cancelling,
// the 10-slot limit and a refused save.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_schedule_repository.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_schedule_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_schedule_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

LiveScheduleSlot _slot(String id, String title, Duration ahead) =>
    LiveScheduleSlot(id: id, title: title, startsAt: DateTime.now().add(ahead));

Future<FakeLiveScheduleRepository> _open(
  WidgetTester tester,
  FakeLiveScheduleRepository repo,
) async {
  await pumpScreen(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showLiveSchedule(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
    overrides: [
      liveScheduleRepositoryProvider.overrideWithValue(repo),
      currentUserProvider.overrideWithValue(testUser().copyWith(canHost: true)),
    ],
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return repo;
}

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byKey(LiveScheduleKeys.count)));

String _count(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(LiveScheduleKeys.count)).data!;

Future<void> _okPicker(WidgetTester tester) async {
  final ok = MaterialLocalizations.of(tester.element(find.byType(Dialog).last))
      .okButtonLabel;
  await tester.tap(find.text(ok).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists, schedules through the pickers and cancels', (
    tester,
  ) async {
    final repo = await _open(
      tester,
      FakeLiveScheduleRepository([
        _slot('a', 'Morning chat', const Duration(hours: 2)),
      ]),
    );
    final l10n = _l10n(tester);
    expect(_count(tester), '1/$maxLiveScheduleSlots');
    expect(find.text(KFormat.bidiIsolate('Morning chat')), findsOneWidget);

    await tester.tap(find.byKey(LiveScheduleKeys.add));
    await tester.pumpAndSettle();
    FilledButton save() =>
        tester.widget<FilledButton>(find.byKey(LiveScheduleKeys.save));
    expect(save().onPressed, isNull);
    await tester.enterText(find.byKey(LiveScheduleKeys.title), 'Evening songs');
    await tester.tap(find.byKey(LiveScheduleKeys.pick));
    await tester.pumpAndSettle();
    await _okPicker(tester); // the date (default: about 20 minutes ahead)
    await _okPicker(tester); // the time
    expect(find.text(l10n.liveSchedulePickTime), findsNothing);
    expect(save().onPressed, isNotNull);
    await tester.tap(find.byKey(LiveScheduleKeys.save));
    await tester.pumpAndSettle();

    expect(repo.created.single.title, 'Evening songs');
    final lead = repo.created.single.startsAt.difference(DateTime.now());
    expect(lead, greaterThan(liveScheduleMinLead));
    expect(_count(tester), '2/$maxLiveScheduleSlots');
    expect(find.byKey(LiveScheduleKeys.save), findsNothing);
    expect(find.text(KFormat.bidiIsolate('Evening songs')), findsOneWidget);

    await tester.tap(find.byKey(LiveScheduleKeys.remove('a')));
    await tester.pumpAndSettle();
    expect(repo.removed, ['a']);
    expect(_count(tester), '1/$maxLiveScheduleSlots');
  });

  testWidgets('ten upcoming: no more; empty says so; a refused save says '
      'why', (tester) async {
    final repo = await _open(
      tester,
      FakeLiveScheduleRepository([
        for (var i = 0; i < maxLiveScheduleSlots; i += 1)
          _slot('s$i', 'Live $i', Duration(hours: i + 1)),
      ]),
    );
    final l10n = _l10n(tester);
    final add = tester.widget<FilledButton>(find.byKey(LiveScheduleKeys.add));
    expect(add.onPressed, isNull);
    expect(find.text(l10n.errorLiveScheduleFull), findsOneWidget);

    // The server is the authority: its refusal is shown.
    repo
      ..slots = []
      ..failure = const ServerFailure(
        code: ErrorCode.liveScheduleFull,
        rawCode: 'LIVE_SCHEDULE_FULL',
        debugMessage: 'x',
        statusCode: 409,
      );
    await tester.tap(find.byKey(LiveScheduleKeys.remove('s0')));
    await tester.pumpAndSettle();
    expect(
      find.text(failureMessage(l10n, repo.failure!)),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('no upcoming lives: says so', (tester) async {
    await _open(tester, FakeLiveScheduleRepository());
    expect(find.text(_l10n(tester).liveScheduleEmpty), findsOneWidget);
    expect(_count(tester), '0/$maxLiveScheduleSlots');
  });
}
