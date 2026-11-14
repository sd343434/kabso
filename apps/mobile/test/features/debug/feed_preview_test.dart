// KL-056: full-screen vertical feed preview (labelled test data, debug only).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/feed_glyphs.dart';
import 'package:kabso_live/features/debug/feed_preview_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
}) => pumpScreen(tester, const FeedPreviewScreen(), language: language);

double _width(WidgetTester tester) =>
    tester.view.physicalSize.width / tester.view.devicePixelRatio;

void main() {
  testWidgets('every page is labelled test data', (tester) async {
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    expect(find.byKey(FeedPreviewScreen.testDataKey), findsOneWidget);
    expect(find.text(l10n.feedPreviewTestData), findsOneWidget);
    expect(find.text('Nour (test)'), findsOneWidget);
    expect(find.byKey(FeedPreviewScreen.railKey), findsOneWidget);
    expect(find.byKey(FeedPreviewScreen.captionKey), findsOneWidget);
    expect(find.byKey(FeedPreviewScreen.navKey), findsOneWidget);
    // Counts use the compact format.
    expect(find.text('10.1K'), findsOneWidget);
    expect(find.text('1,945'), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('rail at the end, caption at the start (${language.name})', (
      tester,
    ) async {
      await _pump(tester, language: language);
      final half = _width(tester) / 2;
      final rail = tester.getCenter(find.byKey(FeedPreviewScreen.railKey));
      final caption = tester.getCenter(
        find.byKey(FeedPreviewScreen.captionKey),
      );
      final live = tester.getCenter(find.byKey(FeedPreviewScreen.liveEntryKey));
      final search = tester.getCenter(find.byKey(FeedPreviewScreen.searchKey));
      if (language == AppLanguage.ar) {
        // RTL, as in the reference: rail and search on the left, caption and
        // the live entry on the right.
        expect(rail.dx, lessThan(half));
        expect(caption.dx, greaterThan(half));
        expect(live.dx, greaterThan(half));
        expect(search.dx, lessThan(half));
      } else {
        expect(rail.dx, greaterThan(half));
        expect(caption.dx, lessThan(half));
        expect(live.dx, lessThan(half));
        expect(search.dx, greaterThan(half));
      }
    });
  }

  testWidgets('the selected tab sits at the end of the tab row', (
    tester,
  ) async {
    await _pump(tester, language: AppLanguage.ar);
    final l10n = l10nFor(AppLanguage.ar);
    final popular = tester.getCenter(find.text(l10n.feedTabPopular));
    final following = tester.getCenter(find.text(l10n.feedTabFollowing));
    final latest = tester.getCenter(find.text(l10n.feedTabNew));
    // RTL: start = right, so the end (selected) tab is the leftmost.
    expect(popular.dx, lessThan(following.dx));
    expect(following.dx, lessThan(latest.dx));
    bool selected(String label) => tester
        .getSemantics(find.text(label))
        .flagsCollection
        .isSelected
        .toBoolOrNull()!;
    expect(selected(l10n.feedTabPopular), isTrue);

    await tester.tap(find.text(l10n.feedTabFollowing));
    await tester.pump();
    expect(selected(l10n.feedTabFollowing), isTrue);
    expect(selected(l10n.feedTabPopular), isFalse);
  });

  testWidgets('rail, top bar and navigation use the feed glyph set', (
    tester,
  ) async {
    await _pump(tester, language: AppLanguage.ar);
    List<FeedGlyph> glyphsIn(Finder scope) => tester
        .widgetList<FeedGlyphIcon>(
          find.descendant(of: scope, matching: find.byType(FeedGlyphIcon)),
        )
        .map((g) => g.glyph)
        .toList();
    expect(glyphsIn(find.byKey(FeedPreviewScreen.railKey)), [
      FeedGlyph.heart,
      FeedGlyph.comment,
      FeedGlyph.bookmark,
      FeedGlyph.share,
    ]);
    // D48: Home (live hub) · Discover · [Create] · Reels (app icon set,
    // selected) · Profile.
    expect(glyphsIn(find.byKey(FeedPreviewScreen.navKey)), [
      FeedGlyph.home,
      FeedGlyph.discover,
      FeedGlyph.profile,
    ]);
    expect(glyphsIn(find.byKey(FeedPreviewScreen.searchKey)), [
      FeedGlyph.search,
    ]);
    expect(glyphsIn(find.byKey(FeedPreviewScreen.liveEntryKey)), [
      FeedGlyph.live,
    ]);
    // No Material glyphs remain: the "+" marks use the app icon set too.
    expect(find.byType(Icon), findsNothing);
    expect(
      tester
          .widgetList<AppIcon>(find.byType(AppIcon))
          .where((i) => i.asset == AppIcons.plus),
      hasLength(2),
    );
  });

  testWidgets('swiping up shows the next post full screen', (tester) async {
    await _pump(tester);
    expect(find.text('Nour (test)'), findsOneWidget);
    await tester.fling(
      find.byKey(FeedPreviewScreen.pagerKey),
      const Offset(0, -200),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Nour (test)'), findsNothing);
    expect(find.text('Sami (test)'), findsOneWidget);
    expect(find.text('482K'), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('360x800 at text scale 1.3 does not overflow '
        '(${language.name})', (tester) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 800 * 3)
        ..devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, language: language);
      expect(tester.takeException(), isNull);
      // The long caption is cut at two lines, never under the rail.
      await tester.fling(
        find.byKey(FeedPreviewScreen.pagerKey),
        const Offset(0, -200),
        1000,
      );
      await tester.pumpAndSettle();
      await tester.fling(
        find.byKey(FeedPreviewScreen.pagerKey),
        const Offset(0, -200),
        1000,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final caption = tester.getRect(find.byKey(FeedPreviewScreen.captionKey));
      final rail = tester.getRect(find.byKey(FeedPreviewScreen.railKey));
      expect(caption.overlaps(rail), isFalse);
    });
  }

  test('the preview route is only registered outside release mode', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(
      router,
      contains(
        'if (!kReleaseMode)\n'
        '        GoRoute(\n'
        '          path: AppRoutes.debugFeedPreview,',
      ),
    );
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) =>
              f.readAsStringSync().contains('FeedPreviewScreen') ||
              f.readAsStringSync().contains('AppRoutes.debugFeedPreview'),
        )
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toSet();
    expect(users, {
      'lib/app/router/app_router.dart',
      'lib/features/debug/feed_preview_screen.dart',
      // The debug-only hub links to every preview.
      'lib/features/debug/previews_hub_screen.dart',
      // Discover covers open the feed preview.
      'lib/features/debug/discover_preview_screen.dart',
    });
  });
}
