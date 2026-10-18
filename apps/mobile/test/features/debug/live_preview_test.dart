// KL-056: full-screen live room preview (labelled test data, debug only).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/feed_glyphs.dart';
import 'package:kabso_live/features/debug/live_preview_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
}) => pumpScreen(tester, const LivePreviewScreen(), language: language);

void _phone(WidgetTester tester, {double width = 430, double height = 932}) {
  tester.view
    ..physicalSize = Size(width * 3, height * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('labelled test data with the reference regions', (tester) async {
    _phone(tester);
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    expect(find.byKey(LivePreviewScreen.testDataKey), findsOneWidget);
    expect(find.text('Sara (test)'), findsOneWidget);
    expect(find.text('36.5K'), findsOneWidget);
    expect(find.text('284'), findsOneWidget);
    expect(find.text(l10n.livePreviewRank(7)), findsOneWidget);
    expect(find.text(l10n.livePreviewJoined('Khalid (test)')), findsOneWidget);
    expect(find.text(l10n.liveCommentHint), findsOneWidget);
    expect(find.text('426'), findsOneWidget);
  });

  testWidgets('measured sizes: host pill, Follow and bottom bar', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);
    expect(
      tester.getSize(find.byKey(LivePreviewScreen.hostPillKey)).height,
      KLivePreview.hostPillHeight,
    );
    final follow = tester.getSize(
      find.descendant(
        of: find.byKey(LivePreviewScreen.followKey),
        matching: find.byType(Container),
      ),
    );
    expect(follow, const Size(74, 27));
    expect(
      tester.getSize(find.byKey(LivePreviewScreen.bottomBarKey)).height,
      KLivePreview.barHeight,
    );
    expect(
      tester.getSize(find.byKey(LivePreviewScreen.rankKey)).height,
      KLivePreview.chipHeight,
    );
  });

  for (final language in AppLanguage.values) {
    testWidgets('host and chat at the start; viewers and close at the end '
        '(${language.name})', (tester) async {
      _phone(tester);
      await _pump(tester, language: language);
      const half = 430 / 2;
      final host = tester.getCenter(find.byKey(LivePreviewScreen.hostPillKey));
      final chat = tester.getCenter(find.byKey(LivePreviewScreen.chatKey));
      final close = tester.getCenter(find.byKey(LivePreviewScreen.closeKey));
      final viewers = tester.getCenter(
        find.byKey(LivePreviewScreen.viewersKey),
      );
      if (language == AppLanguage.ar) {
        expect(host.dx, greaterThan(half));
        expect(chat.dx, greaterThan(half));
        expect(viewers.dx, lessThan(half));
        // Close is the outermost control at the end (left) edge.
        expect(close.dx, lessThan(viewers.dx));
      } else {
        expect(host.dx, lessThan(half));
        expect(chat.dx, lessThan(half));
        expect(viewers.dx, greaterThan(half));
        expect(close.dx, greaterThan(viewers.dx));
      }
    });
  }

  testWidgets('bottom bar order: share, gift, balance, input, more', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester, language: AppLanguage.ar);
    final bar = find.byKey(LivePreviewScreen.bottomBarKey);
    final glyphs = tester
        .widgetList<FeedGlyphIcon>(
          find.descendant(of: bar, matching: find.byType(FeedGlyphIcon)),
        )
        .map((g) => g.glyph)
        .toList();
    expect(glyphs, [
      FeedGlyph.share,
      FeedGlyph.gift,
      FeedGlyph.coin,
      FeedGlyph.smiley,
      FeedGlyph.more,
    ]);
    // RTL: share is the rightmost control.
    final share = tester.getCenter(find.bySemanticsLabel('مشاركة'));
    final more = tester.getCenter(find.bySemanticsLabel('المزيد'));
    expect(share.dx, greaterThan(more.dx));
  });

  for (final language in AppLanguage.values) {
    testWidgets('360x800 at text scale 1.3 does not overflow '
        '(${language.name})', (tester) async {
      _phone(tester, width: 360, height: 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, language: language);
      expect(tester.takeException(), isNull);
      final host = tester.getRect(find.byKey(LivePreviewScreen.hostPillKey));
      final viewers = tester.getRect(find.byKey(LivePreviewScreen.viewersKey));
      expect(host.overlaps(viewers), isFalse);
    });
  }

  test('the preview route is only registered outside release mode', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(
      router,
      contains(
        'if (!kReleaseMode)\n'
        '        GoRoute(\n'
        '          path: AppRoutes.debugLivePreview,',
      ),
    );
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) =>
              f.readAsStringSync().contains('LivePreviewScreen') ||
              f.readAsStringSync().contains('AppRoutes.debugLivePreview'),
        )
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toSet();
    expect(users, {
      'lib/app/router/app_router.dart',
      'lib/features/debug/live_preview_screen.dart',
    });
  });
}
