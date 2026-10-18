// KL-056: share sheet of the feed and live previews (labelled test data).

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/feed_preview_screen.dart';
import 'package:kabso_live/features/debug/feed_share_sheet.dart';
import 'package:kabso_live/features/debug/live_preview_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void _phone(WidgetTester tester, {double width = 414, double height = 896}) {
  tester.view
    ..physicalSize = Size(width * 3, height * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _openFromFeed(WidgetTester tester, AppLanguage language) async {
  await pumpScreen(tester, const FeedPreviewScreen(), language: language);
  final l10n = l10nFor(language);
  await tester.tap(
    find.descendant(
      of: find.byKey(FeedPreviewScreen.railKey),
      matching: find.bySemanticsLabel(RegExp('^${l10n.liveShare}, ')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the feed share button opens the sheet; close dismisses it', (
    tester,
  ) async {
    _phone(tester);
    await _openFromFeed(tester, AppLanguage.en);
    final l10n = l10nFor(AppLanguage.en);
    expect(find.byKey(FeedShareSheet.sheetKey), findsOneWidget);
    expect(find.text(l10n.shareSheetTitle), findsOneWidget);
    for (final label in [
      l10n.shareRepost,
      l10n.shareCopyLink,
      l10n.shareSend,
      l10n.livePreviewMore,
      l10n.shareSaveVideo,
      l10n.shareReport,
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    // Friends are labelled test data.
    expect(find.bySemanticsLabel('Nour (test)'), findsOneWidget);

    await tester.tap(find.byKey(FeedShareSheet.closeKey));
    await tester.pumpAndSettle();
    expect(find.byKey(FeedShareSheet.sheetKey), findsNothing);
  });

  testWidgets('measured geometry: header 54, rows 125, tiles 60', (
    tester,
  ) async {
    _phone(tester);
    await _openFromFeed(tester, AppLanguage.en);
    expect(
      tester.getSize(find.byKey(FeedShareSheet.friendsKey)).height,
      KShareSheet.rowHeight,
    );
    expect(
      tester.getSize(find.byKey(FeedShareSheet.actionsKey)).height,
      KShareSheet.rowHeight,
    );
    final sheet = tester.getRect(find.byKey(FeedShareSheet.sheetKey));
    final friends = tester.getRect(find.byKey(FeedShareSheet.friendsKey));
    expect(friends.top - sheet.top, KShareSheet.headerHeight);
    // The close button sits at the end edge, clear of the title.
    final close = tester.getRect(find.byKey(FeedShareSheet.closeKey));
    final title = tester.getRect(
      find.text(l10nFor(AppLanguage.en).shareSheetTitle),
    );
    expect(close.overlaps(title), isFalse);
    expect(close.right, greaterThan(sheet.right - 48));
  });

  testWidgets('a destination closes the sheet without sending anything', (
    tester,
  ) async {
    _phone(tester);
    await _openFromFeed(tester, AppLanguage.en);
    await tester.tap(
      find.bySemanticsLabel(l10nFor(AppLanguage.en).shareCopyLink),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(FeedShareSheet.sheetKey), findsNothing);
  });

  testWidgets('RTL: the first friend sits at the right edge', (tester) async {
    _phone(tester);
    await _openFromFeed(tester, AppLanguage.ar);
    final first = tester.getCenter(find.bySemanticsLabel('نور (تجربة)'));
    final second = tester.getCenter(find.bySemanticsLabel('سامي (تجربة)'));
    expect(first.dx, greaterThan(second.dx));
  });

  testWidgets('the live share button opens the same sheet', (tester) async {
    _phone(tester, width: 430, height: 932);
    await pumpScreen(tester, const LivePreviewScreen());
    await tester.tap(
      find.descendant(
        of: find.byKey(LivePreviewScreen.bottomBarKey),
        matching: find.bySemanticsLabel(l10nFor(AppLanguage.en).liveShare),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(FeedShareSheet.sheetKey), findsOneWidget);
  });

  for (final language in AppLanguage.values) {
    testWidgets('360x800 at text scale 1.3 does not overflow '
        '(${language.name})', (tester) async {
      _phone(tester, width: 360, height: 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _openFromFeed(tester, language);
      expect(tester.takeException(), isNull);
      expect(find.byKey(FeedShareSheet.sheetKey), findsOneWidget);
    });
  }
}
