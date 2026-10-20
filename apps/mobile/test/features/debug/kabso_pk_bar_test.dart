// D73: the owner's KabsoPkBar (Kabi on the PK seam) in the live preview —
// team sides and colours in Arabic and English, the result toward the
// right team, a new round, and the debug round simulator.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/live_preview_pk.dart';
import 'package:kabso_live/features/debug/live_preview_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/battle_emoji.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_pk_bar.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(430 * 3, 932 * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

KabsoPkBar _bar(WidgetTester tester) =>
    tester.widget<KabsoPkBar>(find.byType(KabsoPkBar));

Future<void> _stage(
  WidgetTester tester,
  PkPreview pk, {
  AppLanguage language = AppLanguage.en,
}) async {
  _phone(tester);
  await pumpScreen(
    tester,
    Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: LivePreviewPkStage(pk: pk),
      ),
    ),
    language: language,
  );
  await tester.pump();
}

void main() {
  for (final language in AppLanguage.values) {
    final ar = language == AppLanguage.ar;
    testWidgets("${language.name}: the host's team keeps its side and red", (
      tester,
    ) async {
      final pk = pkPreviewFixture(mode: LivePreviewMode.pk2, ar: ar);
      await _stage(tester, pk, language: language);
      final bar = _bar(tester);
      // The bar is drawn left-to-right; the host's team is on the reading
      // start (the right in Arabic).
      expect(bar.left, ar ? pk.endScore : pk.startScore);
      expect(bar.right, ar ? pk.startScore : pk.endScore);
      expect(
        bar.leftColors,
        ar ? KLivePreviewPk.endFill : KLivePreviewPk.startFill,
      );
      expect(bar.formatScore!(7976), '7,976');
      final host = tester.getCenter(find.text('7,976')).dx;
      final guest = tester.getCenter(find.text('2,020')).dx;
      expect(host > guest, ar);
      // Remaining time reaches the bar in whole seconds.
      expect(bar.remaining, const Duration(seconds: 6));
      // Kabi and the flames may rise above the bar: nothing clips it.
      expect(
        find.ancestor(
          of: find.byType(KabsoPkBar),
          matching: find.byType(ClipRect),
        ),
        findsNothing,
      );
    });

    testWidgets('${language.name}: the result jumps toward the winner', (
      tester,
    ) async {
      final base = pkPreviewFixture(mode: LivePreviewMode.pk2, ar: ar);
      PkPreview at(PkOutcome? o) => base.at(
        startScore: 900,
        endScore: 400,
        timeLeft: Duration.zero,
        outcome: o,
      );
      await _stage(tester, at(PkOutcome.startWins), language: language);
      expect(
        _bar(tester).result,
        ar ? KabsoPkResult.rightWins : KabsoPkResult.leftWins,
      );
      await _stage(tester, at(PkOutcome.endWins), language: language);
      expect(
        _bar(tester).result,
        ar ? KabsoPkResult.leftWins : KabsoPkResult.rightWins,
      );
      await _stage(tester, at(PkOutcome.draw), language: language);
      expect(_bar(tester).result, KabsoPkResult.draw);
      // A new round: no result, scores back to zero.
      await _stage(
        tester,
        at(
          null,
        ).at(startScore: 0, endScore: 0, timeLeft: const Duration(minutes: 3)),
        language: language,
      );
      expect(_bar(tester).result, isNull);
      expect((_bar(tester).left, _bar(tester).right), (0, 0));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the simulator plays a whole round, then win and lose on '
      'each side', (tester) async {
    _phone(tester);
    final l10n = l10nFor(AppLanguage.en);
    await pumpScreen(
      tester,
      const LivePreviewScreen(mode: LivePreviewMode.pk2),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byKey(LivePreviewScreen.testDataKey));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(l10n.livePreviewSimulateRound), findsOneWidget);
    await tester.tap(find.byKey(LivePreviewScreen.simulateKey));
    await tester.pump();
    // A new round: 0–0, no result, the start animation.
    expect((_bar(tester).left, _bar(tester).right), (0, 0));
    expect(_bar(tester).result, isNull);
    expect(
      tester
          .widget<KabsoBattleEmoji>(
            find.descendant(
              of: find.byKey(LivePreviewPkStage.battleKey),
              matching: find.byType(KabsoBattleEmoji),
            ),
          )
          .battle,
      KabsoBattle.start,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect((_bar(tester).left, _bar(tester).right), (5000, 4800));
    // The last ten seconds, then the result.
    var sawTense = false;
    for (var i = 0; i < 100 && _bar(tester).result == null; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      final r = _bar(tester).remaining;
      if (r != null && r > Duration.zero && r <= const Duration(seconds: 10)) {
        sawTense = true;
      }
    }
    expect(sawTense, isTrue);
    final bar = _bar(tester);
    expect(bar.result, isNotNull);
    expect(bar.left + bar.right, greaterThan(9800));
    expect(find.byKey(LivePreviewPkStage.startOutcomeKey), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    final startWins = bar.left > bar.right;
    expect(
      tester
          .widget<KabsoBattleEmoji>(
            find.byKey(LivePreviewPkStage.startOutcomeKey),
          )
          .battle,
      startWins ? KabsoBattle.win : KabsoBattle.lose,
    );
    expect(
      tester
          .widget<KabsoBattleEmoji>(
            find.byKey(LivePreviewPkStage.endOutcomeKey),
          )
          .battle,
      startWins ? KabsoBattle.lose : KabsoBattle.win,
    );
  });
}
