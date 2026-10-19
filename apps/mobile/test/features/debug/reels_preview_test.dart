// KL-056: reels and posts preview (labelled test data, debug only).

import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/feed_comments_sheet.dart';
import 'package:kabso_live/features/debug/reels_preview_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void _phone(WidgetTester tester, {double width = 390, double height = 844}) {
  tester.view
    ..physicalSize = Size(width * 3, height * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  ReelsMode mode = ReelsMode.reels,
}) => pumpScreen(
  tester,
  ReelsPreviewScreen(key: ValueKey(mode), initialMode: mode),
  language: language,
);

void main() {
  testWidgets('reels: labelled test data, coins, tabs, info, rail, nav', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    expect(find.byKey(ReelsPreviewScreen.testDataKey), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.reelsCoins('2,133')), findsOneWidget);
    expect(find.text(l10n.reelsTabForYou), findsOneWidget);
    expect(find.text(l10n.reelsTabFriends), findsOneWidget);
    expect(find.text('Nour (test)'), findsOneWidget);
    expect(find.text('Test location'), findsOneWidget);
    expect(find.bySemanticsLabel(l10n.commentsVerified), findsOneWidget);
    expect(find.byKey(ReelsPreviewScreen.railKey), findsOneWidget);
    final nav = find.byKey(ReelsPreviewScreen.navKey);
    for (final label in [
      l10n.navHome,
      l10n.navDiscover,
      l10n.navCreate,
      l10n.navReels,
      l10n.navProfile,
    ]) {
      expect(
        find.descendant(of: nav, matching: find.text(label)),
        findsOneWidget,
      );
    }
  });

  testWidgets('measured geometry: rail and info 20 above the video bottom, '
      'progress 4', (tester) async {
    _phone(tester);
    await _pump(tester);
    final progress = tester.getRect(find.byKey(ReelsPreviewScreen.progressKey));
    expect(progress.height, KReels.progress);
    final videoBottom = progress.bottom;
    expect(
      tester.getRect(find.byKey(ReelsPreviewScreen.railKey)).bottom,
      videoBottom - KReels.contentBottom,
    );
    expect(
      tester.getRect(find.byKey(ReelsPreviewScreen.infoKey)).bottom,
      videoBottom - KReels.contentBottom,
    );
    // Rail end inset 16 (LTR: right edge).
    expect(
      tester.getRect(find.byKey(ReelsPreviewScreen.railKey)).right,
      390 - KReels.edge,
    );
    // Progress sits directly above the bottom bar.
    expect(
      tester.getRect(find.byKey(ReelsPreviewScreen.navKey)).top,
      videoBottom,
    );
  });

  testWidgets('like and save toggle locally; the inactive tab is dimmed', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    final like = find.bySemanticsLabel('${l10n.feedActionLike}, 432K');
    expect(like, findsOneWidget);
    await tester.tap(like);
    await tester.pump();
    // 432,001 still rounds to 432K; the heart turns selected.
    expect(
      tester.getSemantics(like.first).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    await tester.tap(find.bySemanticsLabel(l10n.reelsSave).first);
    await tester.pump();
    expect(find.text(l10n.reelsSaved), findsOneWidget);

    double tabOpacity(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!.a;

    expect(tabOpacity(l10n.reelsTabForYou), 1);
    expect(tabOpacity(l10n.reelsTabFriends), closeTo(0.5, 0.01));
    await tester.tap(find.text(l10n.reelsTabFriends));
    await tester.pump();
    expect(tabOpacity(l10n.reelsTabFriends), 1);
  });

  testWidgets('comment opens the comments sheet', (tester) async {
    _phone(tester);
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    await tester.tap(
      find.bySemanticsLabel(RegExp('^${l10n.feedActionComment}, ')).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(FeedCommentsSheet.sheetKey), findsOneWidget);
  });

  testWidgets('the switch moves between reels and posts', (tester) async {
    _phone(tester);
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    expect(find.byKey(ReelsPreviewScreen.pagerKey), findsOneWidget);
    await tester.tap(find.text(l10n.reelsModePosts));
    await tester.pumpAndSettle();
    expect(find.byKey(ReelsPreviewScreen.pagerKey), findsNothing);
    expect(find.byKey(ReelsPreviewScreen.postsKey), findsOneWidget);
    expect(find.text('Layla (test)'), findsOneWidget);
    expect(find.text(l10n.postsLikes('1,240')), findsOneWidget);
    expect(find.text(l10n.postsViewComments('86')), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(ReelsPreviewScreen.modeKey),
        matching: find.text(l10n.reelsModeReels),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ReelsPreviewScreen.pagerKey), findsOneWidget);
  });

  testWidgets('posts: a text-only post shows its text without media', (
    tester,
  ) async {
    _phone(tester);
    await _pump(tester, mode: ReelsMode.posts);
    await tester.scrollUntilVisible(
      find.textContaining('A text-only test post'),
      300,
      scrollable: find.descendant(
        of: find.byKey(ReelsPreviewScreen.postsKey),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.textContaining('A text-only test post'), findsOneWidget);
    expect(find.text('Omar (test)'), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('rail on the end side, info on the start side '
        '(${language.name})', (tester) async {
      _phone(tester);
      await _pump(tester, language: language);
      final rail = tester.getCenter(find.byKey(ReelsPreviewScreen.railKey));
      final info = tester.getCenter(find.byKey(ReelsPreviewScreen.infoKey));
      if (language == AppLanguage.ar) {
        expect(rail.dx, lessThan(info.dx));
      } else {
        expect(rail.dx, greaterThan(info.dx));
      }
    });
  }

  for (final language in AppLanguage.values) {
    for (final mode in ReelsMode.values) {
      testWidgets('360x800 at text scale 1.3 does not overflow '
          '(${language.name}, ${mode.name})', (tester) async {
        _phone(tester, width: 360, height: 800);
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _pump(tester, language: language, mode: mode);
        expect(tester.takeException(), isNull);
        if (mode == ReelsMode.posts) {
          await tester.drag(
            find.byKey(ReelsPreviewScreen.postsKey),
            const Offset(0, -900),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  test('the preview route is only registered outside release mode', () {
    final router = File('lib/app/router/app_router.dart').readAsStringSync();
    expect(
      router,
      contains(
        'if (!kReleaseMode)\n'
        '        GoRoute(\n'
        '          path: AppRoutes.debugReelsPreview,',
      ),
    );
    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) =>
              f.readAsStringSync().contains('ReelsPreviewScreen') ||
              f.readAsStringSync().contains('AppRoutes.debugReelsPreview'),
        )
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toSet();
    expect(users, {
      'lib/app/router/app_router.dart',
      'lib/features/debug/reels_preview_screen.dart',
      'lib/features/debug/previews_hub_screen.dart',
    });
  });
}
