// D138 (owner: «وأيضاً ستظهر في الرسائل الخاصة»): the shared emoji panel in
// the private-message composer — the owner's nine packs first, then the
// Unicode groups, in the app theme; pack tokens animate in the bubbles.

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/emoji/unicode_emoji.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/messages_preview_screen.dart';
import 'package:kabso_live/features/emoji/emoji_panel.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/messages/widgets/chat_composer.dart';
import 'package:lottie/lottie.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_dm_repository.dart';
import '../../helpers/pump_app.dart';

void _phone(WidgetTester tester, {Size size = const Size(393, 852)}) {
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The packs loop in the grid: pump, never settle.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(MessagesPreviewScreen.emojiKey));
  await _frames(tester);
  expect(find.byKey(ChatComposer.emojiPanelKey), findsOneWidget);
}

TextField _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(MessagesPreviewScreen.inputKey));

void main() {
  final en = l10nFor(AppLanguage.en);

  testWidgets('the emoji button opens the shared panel under the field, no '
      "keyboard: the owner's packs first, then the Unicode groups", (
    tester,
  ) async {
    _phone(tester);
    await pumpScreen(tester, const MessagesPreviewScreen());
    await _open(tester);
    expect(_field(tester).focusNode!.hasFocus, isFalse);
    final panel = find.byKey(ChatComposer.emojiPanelKey);
    expect(
      tester.widget(panel),
      isA<EmojiPanel>(),
      reason: 'one panel widget shared with the live chat box',
    );
    final strip =
        tester
                .widget<ListView>(
                  find
                      .descendant(of: panel, matching: find.byType(ListView))
                      .first,
                )
                .childrenDelegate
            as SliverChildListDelegate;
    expect(
      [for (final c in strip.children) (c as Semantics).child!.key],
      [for (final t in EmojiPanelTab.all()) EmojiPanel.tabKey(t)],
    );
    expect(EmojiPanelTab.all().take(9), [
      for (final p in EmojiPack.values) EmojiPackTab(p),
    ]);
    // The first pack is open; its emojis play and are named.
    final cell = find.byKey(EmojiPanel.packKey(KabsoEmoji.kabi('hi')));
    expect(
      tester
          .widget<KabiEmoji>(
            find.descendant(of: cell, matching: find.byType(KabiEmoji)),
          )
          .animate,
      isTrue,
    );
    expect(
      tester.getSemantics(cell),
      matchesSemantics(
        label: KabsoEmoji.kabi('hi').label(en),
        isButton: true,
        hasTapAction: true,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pack emoji goes in as its token and the bubble plays it '
      '(big when alone); a Unicode one goes in as itself; the keyboard key '
      'brings the keyboard back', (tester) async {
    _phone(tester);
    await pumpScreen(tester, const MessagesPreviewScreen());
    await _open(tester);
    await tester.tap(
      find.byKey(EmojiPanel.tabKey(const EmojiPackTab(EmojiPack.neno))),
    );
    await _frames(tester);
    final rose = KabsoEmoji.byKey('neno_rose')!;
    await tester.dragUntilVisible(
      find.byKey(EmojiPanel.packKey(rose)),
      find.byType(GridView),
      const Offset(0, -60),
    );
    await tester.pump();
    await tester.tap(find.byKey(EmojiPanel.packKey(rose)));
    await tester.pump();
    expect(_field(tester).controller!.text, ':neno_rose:');
    await tester.tap(find.byKey(MessagesPreviewScreen.sendKey));
    await _frames(tester);
    final big = find.byWidgetPredicate(
      (w) => w is KabiEmoji && w.emoji == rose && w.size == KKabiEmoji.big,
    );
    expect(big, findsOneWidget);
    expect(
      tester
          .widget<Lottie>(
            find.descendant(of: big, matching: find.byType(Lottie)),
          )
          .animate,
      isTrue,
    );

    // Mixed with text: inline, animated, and read by name.
    await tester.enterText(find.byKey(MessagesPreviewScreen.inputKey), 'hi ');
    await _open(tester);
    await tester.tap(find.byKey(EmojiPanel.packKey(KabsoEmoji.kabi('love'))));
    await tester.scrollUntilVisible(
      find.byKey(
        EmojiPanel.tabKey(const UnicodeEmojiTab(UnicodeEmojiGroup.love)),
      ),
      60,
      scrollable: find
          .descendant(
            of: find.byKey(ChatComposer.emojiPanelKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(
      find.byKey(
        EmojiPanel.tabKey(const UnicodeEmojiTab(UnicodeEmojiGroup.love)),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(
        EmojiPanel.tabKey(const UnicodeEmojiTab(UnicodeEmojiGroup.love)),
      ),
    );
    await _frames(tester);
    await tester.tap(find.byKey(EmojiPanel.unicodeKey('❤️')));
    await tester.pump();
    expect(_field(tester).controller!.text, 'hi :kabi_love:❤️');
    await tester.tap(find.byKey(MessagesPreviewScreen.sendKey));
    await _frames(tester);
    final inline = find.descendant(
      of: find.byKey(MessagesPreviewScreen.listKey),
      matching: find.byWidgetPredicate(
        (w) =>
            w is KabiEmoji &&
            w.emoji == KabsoEmoji.kabi('love') &&
            w.size < KKabiEmoji.big,
      ),
    );
    expect(inline, findsOneWidget);
    expect(tester.widget<KabiEmoji>(inline).animate, isTrue);
    expect(
      find.descendant(
        of: find.byKey(MessagesPreviewScreen.listKey),
        matching: find.text('hi :kabi_love:❤️', findRichText: true),
      ),
      findsNothing,
    );
    // Back to the keyboard (the panel stayed open after sending).
    expect(find.byKey(ChatComposer.emojiPanelKey), findsOneWidget);
    await tester.tap(find.byKey(MessagesPreviewScreen.emojiKey));
    await _frames(tester);
    expect(find.byKey(ChatComposer.emojiPanelKey), findsNothing);
    expect(_field(tester).focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the panel follows the app theme (light and dark)', (
    tester,
  ) async {
    _phone(tester);
    for (final brightness in Brightness.values) {
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => Theme(
            data: buildAppTheme(
              brightness: brightness,
              locale: AppLanguage.en.locale,
            ),
            child: const MessagesPreviewScreen(),
          ),
        ),
      );
      await _open(tester);
      final p = brightness == Brightness.dark ? KPalette.dark : KPalette.light;
      final selected = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(
                EmojiPanel.tabKey(const EmojiPackTab(EmojiPack.kabi)),
              ),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((selected.decoration! as BoxDecoration).color, p.surfaceOverlay);
      await tester.tap(
        find.byKey(EmojiPanel.tabKey(const EmojiPackTab(EmojiPack.flags))),
      );
      await _frames(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('reduced motion: the pack emojis show their first frame', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    _phone(tester);
    await pumpScreen(tester, const MessagesPreviewScreen());
    await tester.tap(find.byKey(MessagesPreviewScreen.emojiKey));
    await tester.pumpAndSettle();
    final lotties = tester.widgetList<Lottie>(
      find.descendant(
        of: find.byKey(ChatComposer.emojiPanelKey),
        matching: find.byType(Lottie),
      ),
    );
    expect(lotties, isNotEmpty);
    expect(lotties.where((l) => l.animate), isEmpty);
  });

  testWidgets('Arabic RTL at 360 × 800, text scale 1.3: the first pack at '
      'the right, no overflow', (tester) async {
    _phone(tester, size: const Size(360, 800));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpScreen(
      tester,
      const MessagesPreviewScreen(),
      language: AppLanguage.ar,
    );
    await _open(tester);
    expect(
      tester
          .getCenter(
            find.byKey(EmojiPanel.tabKey(const EmojiPackTab(EmojiPack.kabi))),
          )
          .dx,
      greaterThan(
        tester
            .getCenter(
              find.byKey(EmojiPanel.tabKey(const EmojiPackTab(EmojiPack.kiki))),
            )
            .dx,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('D155: the real conversation opens the emoji panel under '
      'its field', (tester) async {
    await pumpScreen(
      tester,
      const ChatScreen(username: 'nour'),
      dmRepository: FakeDmRepository(),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(ChatComposer.emojiPanelKey), findsNothing);
    await tester.tap(find.byKey(ChatScreen.emojiKey));
    // The panel's pack emojis are animations: pump, never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(ChatComposer.emojiPanelKey), findsOneWidget);
  });
}
