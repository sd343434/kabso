// D66: the owner's Kabi emojis — assets, text tokens, picker and the
// composers that can use them today (debug previews; the real chat has no
// messaging API yet, CP-003).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/feed_comments_sheet.dart';
import 'package:kabso_live/features/debug/feed_preview_screen.dart';
import 'package:kabso_live/features/debug/messages_preview_screen.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(414 * 3, 896 * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Finder _emoji(KabiEmojis e, {double? size}) => find.byWidgetPredicate(
  (w) => w is KabiEmoji && w.emoji == e && (size == null || w.size == size),
);

Future<void> _pick(WidgetTester tester, Key button, KabiEmojis e) async {
  await tester.tap(find.byKey(button));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(KabiEmojiPicker.itemKey(e)));
  // The sent emoji loops: pump past the sheet's exit and the scroll to
  // the new message, never settle.
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  group('assets', () {
    test('every emoji has its Lottie file, and every file an emoji', () {
      final files = Directory('assets/emojis')
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => n.endsWith('.json'))
          .toSet();
      expect(files, {for (final e in KabiEmojis.values) 'kabi_${e.id}.json'});
    });

    test('512×512, 60 fps, 2 s, with the sticker outline (D66)', () {
      for (final e in KabiEmojis.values) {
        final raw = File(e.asset).readAsStringSync();
        final json = jsonDecode(raw) as Map<String, Object?>;
        expect(json['w'], 512, reason: e.id);
        expect(json['h'], 512, reason: e.id);
        expect(json['fr'], 60, reason: e.id);
        expect((json['op']! as num) - (json['ip']! as num), 120, reason: e.id);
        expect(
          RegExp('"nm":"outline"').allMatches(raw).length,
          greaterThanOrEqualTo(4),
          reason: '${e.id}: body outline, two antenna halos, feet halo',
        );
      }
    });
  });

  group('tokens', () {
    test('only emojis (up to three) show big; anything else is inline', () {
      expect(KabiEmojiText.onlyEmojis(':kabi_love:'), [KabiEmojis.love]);
      expect(KabiEmojiText.onlyEmojis(' :kabi_hi::kabi_lol: '), [
        KabiEmojis.hi,
        KabiEmojis.lol,
      ]);
      expect(KabiEmojiText.onlyEmojis('hey :kabi_hi:'), isNull);
      expect(
        KabiEmojiText.onlyEmojis(':kabi_hi::kabi_hi::kabi_hi::kabi_hi:'),
        isNull,
      );
      expect(KabiEmojiText.onlyEmojis('plain'), isNull);
      // An unknown id is just text.
      expect(KabiEmojiText.onlyEmojis(':kabi_nope:'), isNull);
    });

    for (final language in AppLanguage.values) {
      testWidgets('${language.name}: screen readers hear the emoji name', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final l10n = l10nFor(language);
        await pumpScreen(
          tester,
          const Scaffold(
            body: KabiEmojiText(
              'ok :kabi_love: :kabi_nope:',
              style: TextStyle(fontSize: 16),
            ),
          ),
          language: language,
        );
        await tester.pump();
        expect(
          _emoji(KabiEmojis.love, size: 16 * KKabiEmoji.inlineScale),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp(l10n.kabiEmojiLove)),
          findsOneWidget,
        );
        expect(find.textContaining(':kabi_nope:'), findsOneWidget);
        handle.dispose();
      });
    }
  });

  testWidgets('the picker offers all 18 as labelled buttons and returns the '
      'chosen one', (tester) async {
    final handle = tester.ensureSemantics();
    final l10n = l10nFor(AppLanguage.en);
    KabiEmojis? chosen;
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => chosen = await showKabiEmojiPicker(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    for (final e in KabiEmojis.values) {
      await tester.ensureVisible(find.byKey(KabiEmojiPicker.itemKey(e)));
      expect(
        tester.getSemantics(find.byKey(KabiEmojiPicker.itemKey(e))),
        isSemantics(label: e.label(l10n), isButton: true),
      );
    }
    await tester.tap(find.byKey(KabiEmojiPicker.itemKey(KabiEmojis.party)));
    await tester.pumpAndSettle();
    expect(chosen, KabiEmojis.party);
    handle.dispose();
  });

  testWidgets('reduced motion: emojis stay on their first frame', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpScreen(tester, const Scaffold(body: KabiEmoji(KabiEmojis.lol)));
    await tester.pump();
    expect(tester.widget<Lottie>(find.byType(Lottie)).animate, isFalse);
  });

  testWidgets('chat preview: an emoji goes out at once, big, without a '
      'bubble', (tester) async {
    _phone(tester);
    await pumpScreen(tester, const MessagesPreviewScreen());
    await _pick(tester, MessagesPreviewScreen.emojiKey, KabiEmojis.love);
    expect(_emoji(KabiEmojis.love, size: KKabiEmoji.big), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('comments preview: an emoji posts at once as a comment', (
    tester,
  ) async {
    _phone(tester);
    final l10n = l10nFor(AppLanguage.en);
    await pumpScreen(tester, const FeedPreviewScreen());
    await tester.tap(
      find.descendant(
        of: find.byKey(FeedPreviewScreen.railKey),
        matching: find.bySemanticsLabel(RegExp('^${l10n.feedActionComment}, ')),
      ),
    );
    await tester.pumpAndSettle();
    await _pick(tester, FeedCommentsSheet.emojiKey, KabiEmojis.lol);
    expect(_emoji(KabiEmojis.lol, size: KKabiEmoji.big), findsOneWidget);
    expect(find.text(l10n.commentsSheetTitle(5)), findsOneWidget);
  });

  testWidgets('the real chat shows the emoji button disabled with the '
      'composer (no messaging API, CP-003)', (tester) async {
    await pumpScreen(tester, const ChatScreen(username: 'nour'));
    final button = tester.widget<IconButton>(find.byKey(ChatScreen.emojiKey));
    expect(button.onPressed, isNull);
  });
}
