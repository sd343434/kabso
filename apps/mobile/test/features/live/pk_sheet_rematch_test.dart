// Owner (2026-11-03): «طلب إعادة التحدي» in the PK sheet beside «كتم الخصم»
// and «إنهاء التحدي», once the result shows (D242's rematch): asking, the
// asking host's wait with «إلغاء», the other host's «قبول» / «رفض», and
// nothing during the battle or past the limit.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/live/application/live_pk_controller.dart';
import 'package:kabso_live/features/live/domain/live_pk.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_pk_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_live_pk.dart';
import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Future<FakeLivePkRepository> _sheet(
  WidgetTester tester,
  PkMatch match, {
  PkMatch? afterRematch,
}) async {
  setViewport(tester, GoldenViewport.phone);
  final repo = FakeLivePkRepository(snapshot: PkState(match: match))
    ..matchOnRematch = afterRematch;
  await pumpScreen(
    tester,
    const Scaffold(body: LivePkSheet(roomId: 'room-0')),
    language: AppLanguage.ar,
    livePkRepository: repo,
  );
  ProviderScope.containerOf(tester.element(find.byType(LivePkSheet)))
      .read(livePkProvider('room-0').notifier)
      .debugSetMatch(match);
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime.now();

  testWidgets('result: «طلب إعادة التحدي» beside mute and end asks the '
      'other host', (tester) async {
    final repo = await _sheet(
      tester,
      pkRematchFixture(now: now),
      afterRematch: pkRematchFixture(now: now, offerBy: 'room-0'),
    );
    expect(find.byKey(LivePkSheet.muteKey), findsOneWidget);
    expect(find.byKey(LivePkSheet.endKey), findsOneWidget);
    expect(find.text('طلب إعادة التحدي'), findsOneWidget);
    await _tap(tester, LivePkSheet.rematchKey);
    expect(repo.calls, contains('rematch:offer'));
  });

  testWidgets('the asking host waits and may cancel', (tester) async {
    final repo = await _sheet(
      tester,
      pkRematchFixture(now: now, offerBy: 'room-0'),
    );
    expect(find.byKey(LivePkSheet.rematchKey), findsNothing);
    expect(find.byKey(LivePkSheet.rematchWaitingKey), findsOneWidget);
    await _tap(tester, LivePkSheet.rematchCancelKey);
    expect(repo.calls, contains('rematch:cancel'));
  });

  testWidgets('the other host answers: accept or decline', (tester) async {
    var repo = await _sheet(
      tester,
      pkRematchFixture(now: now, offerBy: 'room-b'),
    );
    expect(find.byKey(LivePkSheet.rematchAcceptKey), findsOneWidget);
    expect(find.byKey(LivePkSheet.rematchDeclineKey), findsOneWidget);
    await _tap(tester, LivePkSheet.rematchAcceptKey);
    expect(repo.calls, contains('rematch:accept'));

    repo = await _sheet(tester, pkRematchFixture(now: now, offerBy: 'room-b'));
    await _tap(tester, LivePkSheet.rematchDeclineKey);
    expect(repo.calls, contains('rematch:decline'));
  });

  testWidgets('nothing during the battle or past the limit', (tester) async {
    await _sheet(
      tester,
      pkRematchFixture(now: now, status: PkMatchStatus.battle),
    );
    expect(find.byKey(LivePkSheet.muteKey), findsOneWidget);
    expect(find.byKey(LivePkSheet.rematchKey), findsNothing);

    await _sheet(tester, pkRematchFixture(now: now, rematchesLeft: 0));
    expect(find.byKey(LivePkSheet.rematchKey), findsNothing);
  });
}
