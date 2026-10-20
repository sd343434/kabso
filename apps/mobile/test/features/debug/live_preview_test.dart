// KL-056: full-screen live room preview (labelled test data, debug only).

import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/feed_share_sheet.dart';
import 'package:kabso_live/features/debug/live_leaderboard.dart';
import 'package:kabso_live/features/debug/live_preview_screen.dart';
import 'package:kabso_live/features/debug/live_viewers_sheet.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/golden.dart';
import '../../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
  bool host = false,
}) => pumpScreen(tester, LivePreviewScreen(host: host), language: language);

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
    expect(find.text(l10n.liveRankingList), findsOneWidget);
    expect(find.text('Khalid (test)'), findsOneWidget);
    expect(find.text(l10n.livePreviewJoinedLine), findsNWidgets(2));
    expect(find.text(l10n.liveCommentHint), findsOneWidget);
    expect(find.byKey(LivePreviewScreen.moreKey), findsOneWidget);
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
    // D79: smaller, hugging its label within the measured 74.
    expect(follow.height, KLivePreview.followHeight);
    expect(follow.width, lessThanOrEqualTo(KLivePreview.followMaxWidth));
    expect(find.text('Follow'), findsOneWidget);
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

  testWidgets('bottom bar (owner, D77/D78): field, link, menu, gift box at '
      'the end; no share button', (tester) async {
    _phone(tester);
    await _pump(tester, language: AppLanguage.ar, host: true);
    final l10n = l10nFor(AppLanguage.ar);
    double x(String label) => tester.getCenter(find.bySemanticsLabel(label)).dx;
    final input = tester.getCenter(find.byKey(LivePreviewScreen.inputKey)).dx;
    final order = [
      input,
      x(l10n.livePreviewGuests),
      x(l10n.livePreviewHostSettings),
      x(l10n.liveGifts),
    ];
    // RTL: the field at the start (right), the gift box at the end (left).
    for (var i = 1; i < order.length; i++) {
      expect(order[i], lessThan(order[i - 1]), reason: 'position $i');
    }
    final bar = find.byKey(LivePreviewScreen.bottomBarKey);
    expect(
      find.descendant(of: bar, matching: find.byType(KabsoArtIcon)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bar,
        matching: find.bySemanticsLabel(RegExp('^${l10n.liveShare}')),
      ),
      findsNothing,
    );
  });

  testWidgets('⋯ beside close (D78): share opens the share sheet; report '
      'is coming soon', (tester) async {
    _phone(tester);
    await _pump(tester, language: AppLanguage.ar);
    final l10n = l10nFor(AppLanguage.ar);
    final more = tester.getCenter(find.byKey(LivePreviewScreen.moreKey));
    final close = tester.getCenter(find.byKey(LivePreviewScreen.closeKey));
    // Next to the close button, on its start side (RTL: to its right).
    expect(more.dy, closeTo(close.dy, 1));
    expect(more.dx - close.dx, inInclusiveRange(20, 60));
    await tester.tap(find.byKey(LivePreviewScreen.moreKey));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(l10n.liveShare), findsOneWidget);
    final report = tester.widget<ListTile>(
      find.byKey(LivePreviewScreen.reportOptionKey),
    );
    expect(report.enabled, isFalse);
    expect(find.text(l10n.profileEditSoon), findsOneWidget);
    await tester.tap(find.byKey(LivePreviewScreen.shareOptionKey));
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(FeedShareSheet.sheetKey), findsOneWidget);
  });

  testWidgets('chat lines (D76): a photo, the four levels by the name, '
      'smaller text', (tester) async {
    _phone(tester);
    await _pump(tester, language: AppLanguage.ar);
    final chat = find.byKey(LivePreviewScreen.chatKey);
    final badges = tester
        .widgetList<KLevelBadge>(
          find.descendant(of: chat, matching: find.byType(KLevelBadge)),
        )
        .toList();
    // Four people, four systems each, in the systems' order.
    expect(badges, hasLength(16));
    expect(badges.take(4).map((b) => b.category), LevelCategory.values);
    expect(badges.first.levelNumber, 12);
    // Badges sit beside the name: same line, toward the reading end (RTL:
    // left of the name).
    final name = tester.getRect(find.text('عمر (تجربة)'));
    final first = tester.getRect(find.byWidget(badges.first));
    expect(first.center.dy, closeTo(name.center.dy, 4));
    expect(first.right, lessThan(name.left));
    final text = tester.widget<RichText>(
      find.descendant(
        of: chat,
        matching: find.byWidgetPredicate(
          (w) =>
              w is RichText && w.text.toPlainText().startsWith('رسالة اختبار'),
        ),
      ),
    );
    expect(text.text.style?.fontSize, LiveChatTextSize.medium.text);
  });

  testWidgets('Host settings (D79, ≡): the chat text size', (tester) async {
    _phone(tester);
    await _pump(tester, language: AppLanguage.ar, host: true);
    final l10n = l10nFor(AppLanguage.ar);
    double size() => tester
        .widget<RichText>(
          find.descendant(
            of: find.byKey(LivePreviewScreen.chatKey),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is RichText &&
                  w.text.toPlainText().startsWith('رسالة اختبار'),
            ),
          ),
        )
        .text
        .style!
        .fontSize!;
    expect(size(), LiveChatTextSize.medium.text);
    await tester.tap(find.bySemanticsLabel(l10n.livePreviewHostSettings));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(l10n.livePreviewChatTextSize), findsOneWidget);
    await tester.tap(find.text(l10n.livePreviewTextLarge));
    await tester.pump();
    expect(size(), LiveChatTextSize.large.text);
    await tester.tap(find.text(l10n.livePreviewTextSmall));
    await tester.pump();
    expect(size(), LiveChatTextSize.small.text);
  });

  testWidgets('viewers (D80) never see Host settings', (tester) async {
    _phone(tester);
    await _pump(tester, language: AppLanguage.ar);
    final l10n = l10nFor(AppLanguage.ar);
    expect(find.bySemanticsLabel(l10n.livePreviewHostSettings), findsNothing);
  });

  testWidgets('the viewer count (D80): top three supporters, and a box '
      'ranked by Support or Luck with each share', (tester) async {
    _phone(tester);
    await _pump(tester, language: AppLanguage.ar);
    final l10n = l10nFor(AppLanguage.ar);
    final cluster = find.byKey(LivePreviewScreen.viewersKey);
    expect(
      find.descendant(of: cluster, matching: find.byType(KAvatar)),
      findsNWidgets(3),
    );
    await tester.tap(find.bySemanticsLabel(RegExp('^284')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(LiveViewersSheet.sheetKey), findsOneWidget);
    // D82: two tabs; the ranking is open, with periods and my own place.
    expect(find.text(l10n.liveViewersTab('284')), findsOneWidget);
    expect(find.text(l10n.liveRankingTab), findsOneWidget);
    // D84: the four periods, the hour selected; the two gift systems.
    for (final period in LiveRankingPeriod.viewerPeriods) {
      expect(find.byKey(LiveViewersSheet.periodKey(period)), findsOneWidget);
    }
    expect(find.text(l10n.livePeriodHourly), findsOneWidget);
    expect(find.text(l10n.liveGiftsAttraction), findsOneWidget);
    expect(find.text(l10n.liveGiftsWizard), findsOneWidget);
    expect(find.byKey(LeaderboardCountdown.valueKey), findsOneWidget);
    expect(find.byKey(LiveViewersSheet.meKey), findsOneWidget);
    expect(find.text(l10n.liveGetRanked), findsOneWidget);
    // Attractiveness: Huda first, on the podium, with her score.
    expect(find.bySemanticsLabel('1. هدى (تجربة)'), findsOneWidget);
    expect(find.text(KFormat.compact(2500000, l10n)), findsOneWidget);
    // D81: no percentages.
    expect(find.textContaining('%'), findsNothing);
    // Ranks 4–10 in rows; the first one is highlighted.
    for (var rank = 4; rank <= 10; rank++) {
      expect(find.byKey(LiveViewersSheet.rowKey(rank)), findsOneWidget);
    }
    expect(
      tester.widget<LeaderboardRow>(find.byKey(LiveViewersSheet.rowKey(4))),
      isA<LeaderboardRow>()
          .having((r) => r.highlight, 'highlight', isTrue)
          .having((r) => r.viewer.name, 'name', 'عمر (تجربة)'),
    );
    // Wizard reorders: Karim first; row 4 shows Layla's Wizard emblem.
    await tester.tap(
      find.byKey(LiveViewersSheet.filterKey(LiveViewersFilter.wizard)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.bySemanticsLabel('1. كريم (تجربة)'), findsOneWidget);
    expect(find.text(KFormat.compact(520000, l10n)), findsOneWidget);
    final emblem = tester.widget<KLevelEmblem>(
      find.descendant(
        of: find.byKey(LiveViewersSheet.rowKey(4)),
        matching: find.byType(KLevelEmblem),
      ),
    );
    expect(emblem.category, LevelCategory.wizard);
    expect(emblem.tier, KLevelArt.tier(18));
    // A longer period adds up more (test values): Karim's week.
    await tester.tap(
      find.byKey(LiveViewersSheet.periodKey(LiveRankingPeriod.weekly)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(KFormat.compact(520000 * 30, l10n)), findsOneWidget);
    // The chevrons step through the periods.
    await tester.tap(find.byKey(LeaderboardCountdown.nextKey));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(KFormat.compact(520000 * 110, l10n)), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(LeaderboardCountdown.nextKey))
          .onPressed,
      isNull,
    );
    // The gift filter button picks the system in a small sheet.
    await tester.tap(find.byKey(LeaderboardGiftFilters.filterButtonKey));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(LiveViewersSheet.filterSheetKey), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byKey(LiveViewersSheet.filterSheetKey),
        matching: find.text(l10n.liveGiftsAttraction),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(LiveViewersSheet.filterSheetKey), findsNothing);
    expect(find.bySemanticsLabel('1. هدى (تجربة)'), findsOneWidget);
    // The (i) explains the ranking.
    await tester.tap(find.byKey(LeaderboardCountdown.infoKey));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.liveRankingHelpBody), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(l10n.actionContinue),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    // The Viewers tab: everyone, with their levels, no amounts.
    await tester.tap(find.byKey(LiveViewersSheet.viewersTabKey));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(LiveViewersSheet.meKey), findsNothing);
    expect(find.text('سامي (تجربة)'), findsOneWidget);
    expect(find.textContaining(KFormat.compact(2500000, l10n)), findsNothing);
  });

  testWidgets('the gift gallery chip sits at the end of the chip row', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    // Real fonts: the test font's square glyphs are far wider.
    await loadAppFonts();
    _phone(tester);
    await _pump(tester);
    final l10n = l10nFor(AppLanguage.en);
    final gallery = tester.getRect(find.byKey(LivePreviewScreen.galleryKey));
    final rank = tester.getRect(find.byKey(LivePreviewScreen.rankKey));
    expect(gallery.left, greaterThan(rank.right));
    expect((gallery.center.dy - rank.center.dy).abs(), lessThan(1));
    expect(
      find.bySemanticsLabel(l10n.livePreviewGalleryProgress('9', '23')),
      findsOneWidget,
    );
    // The rank is never cut short at 430 wide.
    expect(find.text(l10n.liveRankingList), findsOneWidget);
    final text = tester.renderObject<RenderParagraph>(
      find.text(l10n.liveRankingList),
    );
    expect(text.didExceedMaxLines, isFalse);
    handle.dispose();
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
      // The debug-only hub links to every preview.
      'lib/features/debug/previews_hub_screen.dart',
    });
  });
}
