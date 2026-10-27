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
import 'package:kabso_live/features/emoji/emoji_panel.dart';
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

Finder _emoji(KabsoEmoji e, {double? size}) => find.byWidgetPredicate(
  (w) => w is KabiEmoji && w.emoji == e && (size == null || w.size == size),
);

Future<void> _pick(WidgetTester tester, Key button, KabsoEmoji e) async {
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
    test('every emoji has its Lottie file, and every file an emoji: one '
        'folder per pack (D102)', () {
      final files = Directory('assets/emojis')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.substring('assets/emojis/'.length))
          .where((n) => n.endsWith('.json'))
          .toSet();
      expect(files, {
        for (final e in KabsoEmoji.values) '${e.pack.name}/${e.key}.json',
      });
      expect(EmojiPack.values.map((p) => p.ids.length), [
        24,
        18,
        12,
        12,
        12,
        12,
        12,
        22,
        18,
      ]);
    });

    test('512×512, 60 fps, 2 s; Kabi with the sticker outline (D66)', () {
      for (final e in KabsoEmoji.values) {
        final raw = File(e.asset).readAsStringSync();
        final json = jsonDecode(raw) as Map<String, Object?>;
        expect(json['w'], 512, reason: e.key);
        expect(json['h'], 512, reason: e.key);
        expect(json['fr'], 60, reason: e.key);
        expect((json['op']! as num) - (json['ip']! as num), 120, reason: e.key);
        if (e.pack != EmojiPack.kabi) continue;
        expect(
          RegExp('"nm":"outline"').allMatches(raw).length,
          greaterThanOrEqualTo(4),
          reason: '${e.key}: body outline, two antenna halos, feet halo',
        );
      }
    });

    test('every pack keeps its icon among its emojis', () {
      for (final p in EmojiPack.values) {
        expect(p.emojis, contains(p.icon), reason: p.name);
      }
    });
  });

  group('tokens', () {
    test('only emojis (up to three) show big; anything else is inline', () {
      expect(KabiEmojiText.onlyEmojis(':kabi_love:'), [
        KabsoEmoji.kabi('love'),
      ]);
      expect(KabiEmojiText.onlyEmojis(' :kabi_hi::kabi_lol: '), [
        KabsoEmoji.kabi('hi'),
        KabsoEmoji.kabi('lol'),
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
          _emoji(KabsoEmoji.kabi('love'), size: 16 * KKabiEmoji.inlineScale),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp(l10n.emojiKabiLove)),
          findsOneWidget,
        );
        expect(
          find.textContaining(':kabi_nope:', findRichText: true),
          findsOneWidget,
        );
        handle.dispose();
      });
    }
  });

  testWidgets('the picker has one tab per pack (D102): each tab offers its '
      'emojis as labelled buttons and returns the chosen one', (tester) async {
    final handle = tester.ensureSemantics();
    final l10n = l10nFor(AppLanguage.en);
    KabsoEmoji? chosen;
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
    expect(
      [for (final p in EmojiPack.values) p.label(l10n)],
      ['Kabi', 'Kiki', 'Boo', 'Pipo', 'Dubi', 'Gogo', 'Lulu', 'Neno', 'Flags'],
    );
    for (final pack in EmojiPack.values) {
      await tester.ensureVisible(find.byKey(KabiEmojiPicker.tabKey(pack)));
      await tester.tap(find.byKey(KabiEmojiPicker.tabKey(pack)));
      await tester.pumpAndSettle();
      for (final e in pack.emojis) {
        await tester.ensureVisible(find.byKey(KabiEmojiPicker.itemKey(e)));
        expect(
          tester.getSemantics(find.byKey(KabiEmojiPicker.itemKey(e))),
          isSemantics(label: e.label(l10n), isButton: true),
        );
      }
    }
    // Back to Kiki: picking returns the Kiki emoji, not Kabi's.
    await tester.tap(find.byKey(KabiEmojiPicker.tabKey(EmojiPack.kiki)));
    await tester.pumpAndSettle();
    final clap = EmojiPack.kiki.emojis.firstWhere((e) => e.id == 'clap');
    await tester.tap(find.byKey(KabiEmojiPicker.itemKey(clap)));
    await tester.pumpAndSettle();
    expect(chosen, clap);
    expect(chosen!.token, ':kiki_clap:');
    handle.dispose();
  });

  test('every emoji and every pack has a name in Arabic and English', () {
    for (final language in AppLanguage.values) {
      final l10n = l10nFor(language);
      for (final e in KabsoEmoji.values) {
        expect(e.label(l10n), isNotEmpty, reason: '${language.name} ${e.key}');
      }
      for (final p in EmojiPack.values) {
        expect(p.label(l10n), isNotEmpty, reason: '${language.name} ${p.name}');
      }
    }
    expect(KabsoEmoji.kabi('crown').label(l10nFor(AppLanguage.ar)), 'VIP');
    expect(
      EmojiPack.lulu.emojis
          .firstWhere((e) => e.id == 'rainbow')
          .label(l10nFor(AppLanguage.ar)),
      'قوس قزح',
    );
  });

  test('tokens of every pack; unknown packs and ids stay text', () {
    final boo = EmojiPack.boo.emojis.firstWhere((e) => e.id == 'peek');
    expect(KabiEmojiText.onlyEmojis(':boo_peek::kabi_love:'), [
      boo,
      KabsoEmoji.kabi('love'),
    ]);
    expect(KabiEmojiText.onlyEmojis(':boo_nope:'), isNull);
    // The owner's own character is the Neno pack; the old name is not a pack.
    expect(KabiEmojiText.onlyEmojis(':amin_hi:'), isNull);
    expect(KabiEmojiText.onlyEmojis(':neno_iloveu::flags_jo:'), [
      EmojiPack.neno.emojis.firstWhere((e) => e.id == 'iloveu'),
      EmojiPack.flags.emojis.firstWhere((e) => e.id == 'jo'),
    ]);
    expect(kabiSpokenText(':flags_ps:', l10nFor(AppLanguage.ar)), 'فلسطين');
    expect(
      kabiSpokenText('hi :dubi_hug: there', l10nFor(AppLanguage.en)),
      'hi Hug there',
    );
  });

  testWidgets('reduced motion: emojis stay on their first frame', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpScreen(tester, Scaffold(body: KabiEmoji(KabsoEmoji.kabi('lol'))));
    await tester.pump();
    expect(tester.widget<Lottie>(find.byType(Lottie)).animate, isFalse);
  });

  testWidgets('chat preview (D138): an emoji from the panel, sent alone, '
      'shows big without a bubble', (tester) async {
    _phone(tester);
    await pumpScreen(tester, const MessagesPreviewScreen());
    await tester.tap(find.byKey(MessagesPreviewScreen.emojiKey));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(EmojiPanel.packKey(KabsoEmoji.kabi('love'))));
    await tester.pump();
    await tester.tap(find.byKey(MessagesPreviewScreen.sendKey));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(
      _emoji(KabsoEmoji.kabi('love'), size: KKabiEmoji.big),
      findsOneWidget,
    );
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
    await _pick(tester, FeedCommentsSheet.emojiKey, KabsoEmoji.kabi('lol'));
    expect(
      _emoji(KabsoEmoji.kabi('lol'), size: KKabiEmoji.big),
      findsOneWidget,
    );
    expect(find.text(l10n.commentsSheetTitle(5)), findsOneWidget);
  });

  testWidgets('the real chat shows the emoji button disabled with the '
      'composer (no messaging API, CP-003)', (tester) async {
    await pumpScreen(tester, const ChatScreen(username: 'nour'));
    final button = tester.widget<IconButton>(find.byKey(ChatScreen.emojiKey));
    expect(button.onPressed, isNull);
  });
}
