// KL-056: comments sheet of the feed preview (labelled test data).

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/feed_comments_sheet.dart';
import 'package:kabso_live/features/debug/feed_preview_screen.dart';
import 'package:kabso_live/features/posts/presentation/comments_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void _phone(WidgetTester tester, {double width = 414, double height = 896}) {
  tester.view
    ..physicalSize = Size(width * 3, height * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _open(
  WidgetTester tester, {
  AppLanguage language = AppLanguage.en,
}) async {
  await pumpScreen(tester, const FeedPreviewScreen(), language: language);
  final l10n = l10nFor(language);
  await tester.tap(
    find.descendant(
      of: find.byKey(FeedPreviewScreen.railKey),
      matching: find.bySemanticsLabel(RegExp('^${l10n.feedActionComment}, ')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the comment button opens the sheet with test comments', (
    tester,
  ) async {
    _phone(tester);
    await _open(tester);
    final l10n = l10nFor(AppLanguage.en);
    expect(find.byKey(FeedCommentsSheet.sheetKey), findsOneWidget);
    // Three comments and one reply.
    expect(find.text(l10n.commentsSheetTitle(4)), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(FeedCommentsSheet.sheetKey),
        matching: find.text('Nour (test)'),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.commentsCreator), findsOneWidget);
    expect(find.text(l10n.commentsViewReplies(1)), findsOneWidget);

    await tester.tap(find.byKey(FeedCommentsSheet.closeKey));
    await tester.pumpAndSettle();
    expect(find.byKey(FeedCommentsSheet.sheetKey), findsNothing);
  });

  testWidgets('sheet height is 653/896 of the screen', (tester) async {
    _phone(tester);
    await _open(tester);
    expect(
      tester.getSize(find.byKey(FeedCommentsSheet.sheetKey)).height,
      closeTo(896 * KCommentsSheet.heightFactor, 0.5),
    );
  });

  testWidgets('like toggles locally; replies expand and collapse', (
    tester,
  ) async {
    _phone(tester);
    await _open(tester);
    final l10n = l10nFor(AppLanguage.en);
    await tester.tap(find.bySemanticsLabel(l10n.commentsLike('86')));
    await tester.pump();
    expect(find.bySemanticsLabel(l10n.commentsLike('87')), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(l10n.commentsLike('87')));
    await tester.pump();
    expect(find.bySemanticsLabel(l10n.commentsLike('86')), findsOneWidget);

    expect(find.text('A test reply'), findsNothing);
    await tester.tap(find.text(l10n.commentsViewReplies(1)));
    await tester.pump();
    expect(find.text('A test reply'), findsOneWidget);
    await tester.tap(find.text(l10n.commentsHideReplies));
    await tester.pump();
    expect(find.text('A test reply'), findsNothing);
  });

  testWidgets('posting adds the comment on top; reply prefills a mention', (
    tester,
  ) async {
    _phone(tester);
    await _open(tester);
    final l10n = l10nFor(AppLanguage.en);
    await tester.enterText(find.byKey(FeedCommentsSheet.inputKey), 'Nice');
    await tester.tap(find.byKey(FeedCommentsSheet.postKey));
    await tester.pump();
    expect(find.text('Nice'), findsOneWidget);
    // The viewer's own comment is labelled "You", posted "just now".
    expect(find.text(l10n.commentsYou), findsOneWidget);
    expect(find.text(l10n.feedPostJustNow), findsOneWidget);
    expect(find.text(l10n.commentsSheetTitle(5)), findsOneWidget);

    await tester.tap(find.text(l10n.commentsReply).at(1));
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(FeedCommentsSheet.inputKey),
    );
    expect(field.controller!.text, '@Nour (test) ');
  });

  testWidgets('RTL: avatars at the right, like buttons at the left', (
    tester,
  ) async {
    _phone(tester);
    await _open(tester, language: AppLanguage.ar);
    final name = tester.getCenter(find.text('هند (تجربة)'));
    final like = tester.getCenter(
      find.bySemanticsLabel(l10nFor(AppLanguage.ar).commentsLike('86')),
    );
    expect(like.dx, lessThan(name.dx));
    expect(like.dx, lessThan(414 / 2));
    // A four-digit count stays clear of the comment text.
    final count = tester.getRect(find.text('1,240'));
    final body = tester.getRect(find.textContaining('شكرًا لكل من شاهد'));
    expect(count.overlaps(body), isFalse);
  });

  for (final language in AppLanguage.values) {
    testWidgets('360x800 at text scale 1.3 does not overflow '
        '(${language.name})', (tester) async {
      _phone(tester, width: 360, height: 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _open(tester, language: language);
      expect(tester.takeException(), isNull);
    });
  }
}
