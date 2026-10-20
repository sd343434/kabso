// D69: the gift box inside a conversation. The preview sends locally; the
// real chat keeps the button disabled (no gift catalogue, wallet or send
// API: B5).

import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/debug/messages_preview_screen.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/messages/widgets/chat_gift_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(414 * 3, 896 * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _openBox(WidgetTester tester) async {
  await tester.tap(find.byKey(MessagesPreviewScreen.giftKey));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the test conversation holds a received gift', (tester) async {
    _phone(tester);
    final l10n = l10nFor(AppLanguage.en);
    await pumpScreen(tester, const MessagesPreviewScreen());
    await tester.scrollUntilVisible(
      find.byType(ChatGiftCard),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final card = tester.widget<ChatGiftCard>(find.byType(ChatGiftCard));
    expect(card.mine, isFalse);
    expect(card.gift.count, 5);
    expect(find.text(l10n.chatGiftFromCaption('Nour (test)')), findsOneWidget);
  });

  testWidgets('the box lists the gifts; send waits for a choice; the gift '
      'appears with its count', (tester) async {
    _phone(tester);
    final l10n = l10nFor(AppLanguage.en);
    await pumpScreen(tester, const MessagesPreviewScreen(initialMessages: []));
    await tester.tap(find.byKey(MessagesPreviewScreen.greetingCloseKey));
    await tester.pumpAndSettle();
    await _openBox(tester);
    expect(find.text(l10n.chatGiftTitle('Nour (test)')), findsOneWidget);
    for (final id in ['heart', 'star', 'diamond', 'crown']) {
      expect(find.byKey(ChatGiftSheet.giftKey(id)), findsOneWidget);
    }
    final send = find.descendant(
      of: find.byKey(ChatGiftSheet.sendKey),
      matching: find.text(l10n.chatGiftPick),
    );
    expect(send, findsOneWidget);
    // Nothing chosen: sending does nothing.
    await tester.tap(find.byKey(ChatGiftSheet.sendKey));
    await tester.pumpAndSettle();
    expect(find.byType(ChatGiftSheet), findsOneWidget);

    await tester.tap(find.byKey(ChatGiftSheet.giftKey('crown')));
    await tester.tap(find.byKey(ChatGiftSheet.countKey(10)));
    await tester.pump();
    expect(
      find.text(l10n.chatGiftSendNamed(l10n.giftNameCrown)),
      findsOneWidget,
    );
    await tester.tap(find.byKey(ChatGiftSheet.sendKey));
    await tester.pumpAndSettle();

    expect(find.byType(ChatGiftSheet), findsNothing);
    final card = tester.widget<ChatGiftCard>(find.byType(ChatGiftCard));
    expect(card.mine, isTrue);
    expect(card.gift.gift.id, 'crown');
    expect(card.gift.count, 10);
    expect(find.text(l10n.giftCombo(10)), findsOneWidget);
    expect(find.text(l10n.chatGiftYoursCaption), findsOneWidget);
  });

  testWidgets('closing the box sends nothing', (tester) async {
    _phone(tester);
    await pumpScreen(tester, const MessagesPreviewScreen(initialMessages: []));
    await tester.tap(find.byKey(MessagesPreviewScreen.greetingCloseKey));
    await tester.pumpAndSettle();
    await _openBox(tester);
    await tester.tap(find.byKey(ChatGiftSheet.giftKey('heart')));
    await tester.pump();
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.byType(ChatGiftCard), findsNothing);
  });

  for (final language in AppLanguage.values) {
    testWidgets('the box fits at 360x800, text scale 1.3 (${language.name})', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(360 * 3, 800 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpScreen(
        tester,
        const MessagesPreviewScreen(),
        language: language,
      );
      await tester.pumpAndSettle();
      await _openBox(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the real chat shows the gift button disabled', (tester) async {
    await pumpScreen(tester, const ChatScreen(username: 'nour'));
    final tip = l10nFor(AppLanguage.en).giftSendComingSoon;
    final gift = find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == tip,
    );
    expect(gift, findsOneWidget);
    expect(tester.widget<IconButton>(gift).onPressed, isNull);
    // D75: next to "+", outside the text field.
    expect(
      find.descendant(of: find.byType(TextField), matching: gift),
      findsNothing,
    );
  });
}
