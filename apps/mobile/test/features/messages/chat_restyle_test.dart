// D68: the chat layout after the owner's reference — shared composer,
// conversation header, day chip, ticks, typing indicator, and the
// conversation list's search, "active now" row and filter chips.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/conversations_preview_screen.dart';
import 'package:kabso_live/features/debug/messages_preview_screen.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/pump_app.dart';

void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(414 * 3, 896 * 3)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

IconButton _button(WidgetTester tester, Key key) =>
    tester.widget<IconButton>(find.byKey(key));

Future<void> _list(WidgetTester tester) => withClock(
  Clock.fixed(DateTime(2026, 10, 18, 12)),
  () => pumpScreen(tester, const ConversationsPreviewScreen()),
);

Finder _row(String peer) => find.byKey(ConversationsPreviewScreen.rowKey(peer));

void main() {
  group('composer', () {
    testWidgets('empty: a disabled microphone (voice needs an API); typed: '
        'a red send button', (tester) async {
      _phone(tester);
      final l10n = l10nFor(AppLanguage.en);
      await pumpScreen(tester, const MessagesPreviewScreen());
      var send = _button(tester, MessagesPreviewScreen.sendKey);
      expect(send.onPressed, isNull);
      expect(send.tooltip, l10n.chatVoiceSoon);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

      await tester.enterText(find.byKey(MessagesPreviewScreen.inputKey), 'Hi');
      await tester.pump();
      send = _button(tester, MessagesPreviewScreen.sendKey);
      expect(send.onPressed, isNotNull);
      expect(send.tooltip, l10n.messagesPreviewSend);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);

      // Only spaces count as empty.
      await tester.enterText(find.byKey(MessagesPreviewScreen.inputKey), '  ');
      await tester.pump();
      expect(_button(tester, MessagesPreviewScreen.sendKey).onPressed, isNull);
    });

    testWidgets('the real chat shows the same composer, all disabled', (
      tester,
    ) async {
      await pumpScreen(tester, const ChatScreen(username: 'nour'));
      for (final key in [
        ChatScreen.sendKey,
        ChatScreen.emojiKey,
        ChatScreen.attachKey,
      ]) {
        final button = find.descendant(
          of: find.byKey(key),
          matching: find.byType(IconButton),
          matchRoot: true,
        );
        expect(
          tester.widget<IconButton>(button.first).onPressed,
          isNull,
          reason: '$key',
        );
      }
      expect(
        tester.widget<TextField>(find.byKey(ChatScreen.composerKey)).enabled,
        isFalse,
      );
    });

    for (final language in AppLanguage.values) {
      testWidgets('attach at the start, send at the end (${language.name})', (
        tester,
      ) async {
        _phone(tester);
        await pumpScreen(
          tester,
          const MessagesPreviewScreen(),
          language: language,
        );
        final attach = tester.getCenter(
          find.byKey(MessagesPreviewScreen.attachKey),
        );
        final send = tester.getCenter(
          find.byKey(MessagesPreviewScreen.sendKey),
        );
        if (language == AppLanguage.ar) {
          expect(attach.dx, greaterThan(send.dx));
        } else {
          expect(attach.dx, lessThan(send.dx));
        }
      });
    }
  });

  group('conversation', () {
    testWidgets('header status, day chip, times, ticks and typing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      _phone(tester);
      final l10n = l10nFor(AppLanguage.en);
      await pumpScreen(tester, const MessagesPreviewScreen());
      expect(find.text(l10n.chatOnline), findsOneWidget);
      expect(find.byKey(MessagesPreviewScreen.dayKey), findsOneWidget);
      expect(find.text(l10n.chatToday), findsOneWidget);
      // intl separates AM with a narrow no-break space.
      expect(find.textContaining(RegExp(r'^10:02\sAM$')), findsOneWidget);
      // Read: two ticks, announced.
      expect(find.bySemanticsLabel(RegExp(l10n.chatStatusRead)), findsWidgets);
      await tester.scrollUntilVisible(
        find.byKey(MessagesPreviewScreen.typingKey),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.bySemanticsLabel(RegExp(l10n.chatTyping('.*'))),
        findsOneWidget,
      );
      handle.dispose();
    });

    for (final language in AppLanguage.values) {
      testWidgets('the sender picture sits by the last of their messages '
          'in a row (${language.name})', (tester) async {
        _phone(tester);
        await pumpScreen(
          tester,
          const MessagesPreviewScreen(),
          language: language,
        );
        final ar = language == AppLanguage.ar;
        final list = find.byKey(MessagesPreviewScreen.listKey);
        List<Rect> avatars() => tester
            .widgetList<KAvatar>(
              find.descendant(of: list, matching: find.byType(KAvatar)),
            )
            .where((a) => a.size == KMessagePreview.avatar)
            .map((a) => tester.getRect(find.byWidget(a)))
            .toList();
        // Level with the bubble's bottom: at or below the text's last line
        // (the time may wrap under it), on the start side.
        bool besideBottom(Rect text) => avatars().any(
          (a) =>
              a.bottom >= text.bottom - 4 &&
              a.top <= text.bottom + 24 &&
              (ar ? a.left >= text.right : a.right <= text.left),
        );

        final first = tester.getRect(
          find.text(
            ar ? 'مرحبًا! هذه رسالة تجريبية' : 'Hi! This is a test message',
          ),
        );
        expect(besideBottom(first), isTrue);
        // Sent messages carry none.
        final sent = tester.getRect(
          find.text(ar ? 'أهلًا، وصلت' : 'Hey, got it'),
        );
        expect(
          avatars().any((a) => (a.center.dy - sent.center.dy).abs() < 20),
          isFalse,
        );
        // "Looks great" is followed by Nour's gift: the picture moves down.
        await tester.scrollUntilVisible(
          find.text(ar ? 'جميل جدًا' : 'Looks great'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        final looks = tester.getRect(
          find.text(ar ? 'جميل جدًا' : 'Looks great'),
        );
        expect(besideBottom(looks), isFalse);
      });
    }

    testWidgets('the typing dots stop moving (bounded motion)', (tester) async {
      _phone(tester);
      await pumpScreen(tester, const MessagesPreviewScreen());
      // Settles: no endless animation is left running.
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('a message just sent carries one tick', (tester) async {
      final handle = tester.ensureSemantics();
      _phone(tester);
      final l10n = l10nFor(AppLanguage.en);
      await pumpScreen(
        tester,
        const MessagesPreviewScreen(initialMessages: []),
      );
      await tester.tap(find.byKey(MessagesPreviewScreen.greetingCloseKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(MessagesPreviewScreen.inputKey), 'Hi');
      await tester.pump();
      await tester.tap(find.byKey(MessagesPreviewScreen.sendKey));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(l10n.chatStatusSent)), findsWidgets);
      // A thread without the test fixture shows no invented status.
      expect(find.text(l10n.chatOnline), findsNothing);
      expect(find.byKey(MessagesPreviewScreen.typingKey), findsNothing);
      handle.dispose();
    });
  });

  group('conversation list', () {
    testWidgets('search filters by name and message', (tester) async {
      _phone(tester);
      await _list(tester);
      // The field shows from the header's search icon.
      expect(find.byKey(ConversationsPreviewScreen.searchKey), findsNothing);
      await tester.tap(find.byKey(ConversationsPreviewScreen.searchToggleKey));
      await tester.pump();
      await tester.enterText(
        find.byKey(ConversationsPreviewScreen.searchKey),
        'sami',
      );
      await tester.pump();
      expect(_row('Sami (test)'), findsOneWidget);
      expect(_row('Nour (test)'), findsNothing);

      await tester.enterText(
        find.byKey(ConversationsPreviewScreen.searchKey),
        'group message',
      );
      await tester.pump();
      expect(_row('Friends group (test)'), findsOneWidget);
      expect(_row('Sami (test)'), findsNothing);

      await tester.enterText(
        find.byKey(ConversationsPreviewScreen.searchKey),
        'nobody',
      );
      await tester.pump();
      expect(find.byKey(ConversationsPreviewScreen.noMatchKey), findsOneWidget);

      // Closing the search clears it.
      await tester.tap(find.byKey(ConversationsPreviewScreen.searchToggleKey));
      await tester.pump();
      expect(find.byKey(ConversationsPreviewScreen.searchKey), findsNothing);
      expect(_row('Sami (test)'), findsOneWidget);
    });

    for (final language in AppLanguage.values) {
      testWidgets('header: search at the start, title centred, "+" at the '
          'end (${language.name})', (tester) async {
        _phone(tester);
        final l10n = l10nFor(language);
        await withClock(
          Clock.fixed(DateTime(2026, 10, 18, 12)),
          () => pumpScreen(
            tester,
            const ConversationsPreviewScreen(),
            language: language,
          ),
        );
        final search = tester.getCenter(
          find.byKey(ConversationsPreviewScreen.searchToggleKey),
        );
        final add = tester.getCenter(
          find.byKey(ConversationsPreviewScreen.newMessageKey),
        );
        final title = tester.getCenter(find.text(l10n.conversationsTitle));
        expect(title.dx, moreOrLessEquals(414 / 2, epsilon: 1));
        if (language == AppLanguage.ar) {
          expect(search.dx, greaterThan(add.dx));
        } else {
          expect(search.dx, lessThan(add.dx));
        }
      });
    }

    testWidgets('"+" picks someone to message and opens their thread', (
      tester,
    ) async {
      _phone(tester);
      await _list(tester);
      await tester.tap(find.byKey(ConversationsPreviewScreen.newMessageKey));
      await tester.pumpAndSettle();
      // Groups are not people.
      expect(
        find.byKey(
          ConversationsPreviewScreen.personKey('Friends group (test)'),
        ),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(ConversationsPreviewScreen.newMessageSearchKey),
        'hin',
      );
      await tester.pump();
      expect(
        find.byKey(ConversationsPreviewScreen.personKey('Nour (test)')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(ConversationsPreviewScreen.personKey('Hind (test)')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MessagesPreviewScreen), findsOneWidget);
      // No conversation yet: the first-time greeting.
      expect(find.byKey(MessagesPreviewScreen.greetingKey), findsOneWidget);
    });

    testWidgets('filter chips: unread, groups, favourites, all', (
      tester,
    ) async {
      _phone(tester);
      await _list(tester);
      Future<Set<String>> shown(ConversationsFilter f) async {
        await tester.tap(find.byKey(ConversationsPreviewScreen.filterKey(f)));
        await tester.pump();
        return {
          for (final peer in [
            'Nour (test)',
            'Friends group (test)',
            'Sami (test)',
            'Hind (test)',
            'Omar (test)',
            'Layla (test)',
          ])
            if (_row(peer).evaluate().isNotEmpty) peer,
        };
      }

      expect(await shown(ConversationsFilter.unread), {
        'Nour (test)',
        'Friends group (test)',
      });
      expect(await shown(ConversationsFilter.groups), {'Friends group (test)'});
      expect(await shown(ConversationsFilter.favorites), {
        'Nour (test)',
        'Omar (test)',
      });
      expect(await shown(ConversationsFilter.all), hasLength(6));
    });

    testWidgets('rows announce the unread count, presence and mute', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      _phone(tester);
      final l10n = l10nFor(AppLanguage.en);
      await _list(tester);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(
        tester.getSemantics(_row('Nour (test)')).value,
        allOf(
          contains(l10n.conversationsUnreadCount(2)),
          contains(l10n.chatOnline),
        ),
      );
      expect(
        tester.getSemantics(_row('Friends group (test)')).value,
        contains(l10n.conversationsMuted),
      );
      handle.dispose();
    });

    testWidgets('"active now" lists the online people and opens their '
        'thread, online', (tester) async {
      _phone(tester);
      final l10n = l10nFor(AppLanguage.en);
      await _list(tester);
      final active = find.byKey(ConversationsPreviewScreen.activeKey);
      expect(
        find.descendant(of: active, matching: find.text('Nour')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: active, matching: find.text('Sami')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: active, matching: find.text('Omar')),
        findsNothing,
      );
      await tester.tap(
        find.descendant(of: active, matching: find.text('Sami')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MessagesPreviewScreen), findsOneWidget);
      expect(find.text(l10n.chatOnline), findsOneWidget);
    });
  });
}
