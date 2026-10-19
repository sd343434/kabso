// KL-056: Discover preview (labelled test data, debug only).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/discover_preview_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void _phone(WidgetTester tester, {double width = 418, double height = 904}) {
  tester.view
    ..physicalSize = Size(width * 3, height * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  DiscoverPreviewState state = DiscoverPreviewState.populated,
}) => pumpScreen(
  tester,
  DiscoverPreviewScreen(key: ValueKey(state), initialState: state),
  language: language,
);

void main() {
  testWidgets('labelled test data: search, banner and hashtag rows', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    expect(find.byKey(DiscoverPreviewScreen.testDataKey), findsOneWidget);
    expect(find.text(l10n.feedSearch), findsOneWidget);
    expect(find.byKey(DiscoverPreviewScreen.bannerKey), findsOneWidget);
    expect(find.text('test_data'), findsOneWidget);
    expect(find.text(l10n.discoverTrendingHashtag), findsWidgets);
    expect(
      find.bySemanticsLabel(l10n.discoverHashtagVideos('test_data', '12.4K')),
      findsOneWidget,
    );
  });

  testWidgets('measured sizes: search 37, banner 202, covers 109x148', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);
    expect(
      tester.getSize(find.byKey(DiscoverPreviewScreen.searchKey)).height,
      KDiscover.searchHeight,
    );
    expect(
      tester.getSize(find.byKey(DiscoverPreviewScreen.bannerKey)).height,
      KDiscover.bannerHeight,
    );
    final cover = tester.getSize(
      find.bySemanticsLabel(
        l10nFor(AppLanguage.en).discoverOpenVideo(1, 'test_data'),
      ),
    );
    expect(cover, KDiscover.cover);
  });

  testWidgets('search filters the hashtags; no match shows an empty state', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    await tester.enterText(find.byKey(DiscoverPreviewScreen.searchKey), 'LIVE');
    await tester.pump();
    expect(find.text('live_test'), findsOneWidget);
    expect(find.text('test_data'), findsNothing);
    // Filtering hides the banner.
    expect(find.byKey(DiscoverPreviewScreen.bannerKey), findsNothing);

    await tester.enterText(find.byKey(DiscoverPreviewScreen.searchKey), 'zzz');
    await tester.pump();
    expect(find.text(l10n.discoverNoResultsTitle), findsOneWidget);
    expect(
      find.text(l10n.discoverNoResultsBody(KFormat.bidiIsolate('zzz'))),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.discoverClearSearch));
    await tester.pump();
    expect(find.text('test_data'), findsOneWidget);
  });

  testWidgets('swiping the banner moves the pagination', (tester) async {
    _phone(tester);
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    expect(find.bySemanticsLabel(l10n.discoverBanner(1, 3)), findsOneWidget);
    await tester.fling(
      find.byKey(DiscoverPreviewScreen.bannerKey),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(l10n.discoverBanner(2, 3)), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('hashtag icon at the start, count at the end '
        '(${language.name})', (tester) async {
      _phone(tester);
      await _pump(tester, language: language);
      final ar = language == AppLanguage.ar;
      final name = tester.getCenter(
        find.text(ar ? 'بيانات_اختبار' : 'test_data'),
      );
      final count = tester.getCenter(find.text(ar ? '12.4 ألف' : '12.4K'));
      if (ar) {
        expect(name.dx, greaterThan(count.dx));
      } else {
        expect(name.dx, lessThan(count.dx));
      }
    });
  }

  testWidgets('loading and unavailable states', (tester) async {
    _phone(tester);
    final l10n = l10nFor(AppLanguage.en);
    await _pump(tester, state: DiscoverPreviewState.loading);
    expect(find.byType(KSkeleton), findsWidgets);
    await _pump(tester, state: DiscoverPreviewState.unavailable);
    expect(find.text(l10n.discoverComingTitle), findsOneWidget);
    // Search is off while there is nothing to search.
    expect(
      tester
          .widget<TextField>(find.byKey(DiscoverPreviewScreen.searchKey))
          .enabled,
      isFalse,
    );
  });

  for (final language in AppLanguage.values) {
    testWidgets('360x800 at text scale 1.3 does not overflow '
        '(${language.name})', (tester) async {
      _phone(tester, width: 360, height: 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, language: language);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(DiscoverPreviewScreen.listKey),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  test('the preview route is only registered outside release mode', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(
      router,
      contains(
        'if (!kReleaseMode)\n'
        '        GoRoute(\n'
        '          path: AppRoutes.debugDiscoverPreview,',
      ),
    );
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) =>
              f.readAsStringSync().contains('DiscoverPreviewScreen') ||
              f.readAsStringSync().contains('AppRoutes.debugDiscoverPreview'),
        )
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toSet();
    expect(users, {
      'lib/app/router/app_router.dart',
      'lib/features/debug/discover_preview_screen.dart',
      'lib/features/debug/previews_hub_screen.dart',
      'lib/features/debug/reels_preview_screen.dart',
    });
  });
}
