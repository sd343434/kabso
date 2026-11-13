// D71: the live preview's PK layouts (owner's references, labelled test
// data, debug only): 1 v 1 and 2 v 2.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/live_preview_pk.dart';
import 'package:kabso_live/features/debug/live_preview_screen.dart';
import 'package:kabso_live/features/live/presentation/widgets/battle_emoji.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void _phone(WidgetTester tester, {double width = 430, double height = 932}) {
  tester.view
    ..physicalSize = Size(width * 3, height * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester,
  LivePreviewMode mode, {
  AppLanguage language = AppLanguage.en,
}) async {
  await pumpScreen(tester, LivePreviewScreen(mode: mode), language: language);
  // The WIN burst and the PK Kabis play once; chat emojis loop, so pump
  // past the burst instead of settling.
  await tester.pump(const Duration(seconds: 3));
}

Finder _pane(String name) => find.byKey(LivePreviewPkStage.paneKey(name));

/// The chat's Kabi emoji loops, so nothing settles: run a sheet's
/// transition frame by frame instead.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

KabsoBattle? _battle(WidgetTester tester) {
  final f = find.byType(KabsoBattleEmoji);
  return f.evaluate().isEmpty
      ? null
      : tester.widget<KabsoBattleEmoji>(f).battle;
}

void main() {
  testWidgets('1 v 1: two panes, the score bar, the final-round timer, the '
      'WIN burst and three supporters a side', (tester) async {
    final handle = tester.ensureSemantics();
    _phone(tester);
    final l10n = l10nFor(AppLanguage.en);
    await _pump(tester, LivePreviewMode.pk2);
    expect(find.byKey(LivePreviewScreen.testDataKey), findsOneWidget);
    expect(_pane('Sara (test)'), findsOneWidget);
    expect(_pane('Karim (test)'), findsOneWidget);
    expect(
      tester.getSize(_pane('Sara (test)')).height,
      KLivePreviewPk.pk2Height,
    );
    expect(
      find.bySemanticsLabel(l10n.pkScoreSemantics('7,976', '2,020')),
      findsOneWidget,
    );
    expect(find.text(l10n.pkFinalRound('0:06')), findsOneWidget);
    // The round is won: the owner's win animation plays in the middle.
    expect(_battle(tester), KabsoBattle.win);
    expect(
      tester.getCenter(find.byKey(LivePreviewPkStage.battleKey)).dx,
      closeTo(215, 1),
    );
    expect(
      find.bySemanticsLabel(RegExp('^${l10n.pkSupporters('')}')),
      findsNWidgets(2),
    );
    // The host's pane carries no name pill or follow; the guest's does.
    expect(
      find.descendant(
        of: _pane('Karim (test)'),
        matching: find.text('Karim (test)'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _pane('Sara (test)'),
        matching: find.text('Sara (test)'),
      ),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('2 v 2: four panes in a grid with scores and a gift banner', (
    tester,
  ) async {
    _phone(tester);
    final l10n = l10nFor(AppLanguage.en);
    await _pump(tester, LivePreviewMode.pk4);
    final names = [
      'Sara (test)',
      'Layla (test)',
      'Karim (test)',
      'Ziad (test)',
    ];
    for (final n in names) {
      expect(_pane(n), findsOneWidget, reason: n);
    }
    final sara = tester.getRect(_pane('Sara (test)'));
    final layla = tester.getRect(_pane('Layla (test)'));
    final karim = tester.getRect(_pane('Karim (test)'));
    // A team per column, two rows.
    expect(layla.top, greaterThan(sara.bottom));
    expect(karim.left, greaterThan(sara.right));
    expect(sara.height + layla.height, closeTo(KLivePreviewPk.pk4Height, 3));
    // Each pane shows its score; the bar sums each team.
    expect(find.text('532.7K'), findsOneWidget);
    expect(
      find.text(l10n.livePreviewGiftSent('Omar (test)', l10n.giftNameCrown)),
      findsOneWidget,
    );
    // A new round: the start animation.
    expect(_battle(tester), KabsoBattle.start);
    expect(find.text(l10n.pkFinalRound('2:45')), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('the host team sits on the start side (${language.name})', (
      tester,
    ) async {
      _phone(tester);
      await _pump(tester, LivePreviewMode.pk2, language: language);
      final ar = language == AppLanguage.ar;
      final host = tester.getCenter(_pane(ar ? 'سارة (تجربة)' : 'Sara (test)'));
      final guest = tester.getCenter(
        _pane(ar ? 'كريم (تجربة)' : 'Karim (test)'),
      );
      expect(ar ? host.dx > guest.dx : host.dx < guest.dx, isTrue);
    });
  }

  for (final mode in [LivePreviewMode.pk2, LivePreviewMode.pk4]) {
    for (final language in AppLanguage.values) {
      testWidgets('${mode.name} at 360x800, text scale 1.3, does not '
          'overflow (${language.name})', (tester) async {
        _phone(tester, width: 360, height: 800);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(tester, mode, language: language);
        expect(tester.takeException(), isNull);
        expect(find.byKey(LivePreviewScreen.bottomBarKey), findsOneWidget);
      });
    }
  }

  testWidgets('reduced motion: the WIN burst and Kabi stay still', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    _phone(tester);
    await pumpScreen(
      tester,
      const LivePreviewScreen(mode: LivePreviewMode.pk2),
    );
    await tester.pump();
    // Every Kabi on a still frame (the battle animation holds one frame,
    // see battle_emoji_test).
    final lotties = tester.widgetList<Lottie>(find.byType(Lottie));
    expect(lotties, isNotEmpty);
    expect(lotties.every((l) => !l.animate), isTrue);
  });

  testWidgets('the test-data label replays any battle animation', (
    tester,
  ) async {
    _phone(tester);
    final l10n = l10nFor(AppLanguage.en);
    await _pump(tester, LivePreviewMode.pk4);
    await tester.tap(find.byKey(LivePreviewScreen.testDataKey));
    await _frames(tester);
    for (final b in KabsoBattle.values) {
      expect(find.text(b.label(l10n)), findsOneWidget, reason: b.id);
    }
    await tester.tap(
      find.byKey(LivePreviewScreen.battleOptionKey(KabsoBattle.draw)),
    );
    await _frames(tester);
    expect(_battle(tester), KabsoBattle.draw);
  });

  testWidgets('the solo room has no battle picker', (tester) async {
    _phone(tester);
    await _pump(tester, LivePreviewMode.solo);
    await tester.tap(find.byKey(LivePreviewScreen.testDataKey));
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.byKey(LivePreviewScreen.battleOptionKey(KabsoBattle.win)),
      findsNothing,
    );
    expect(_battle(tester), isNull);
  });

  test('the route picks the mode from ?mode=', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(router, contains("state.uri.queryParameters['mode']"));
  });
}
