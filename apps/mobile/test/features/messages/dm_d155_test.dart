// D155 (owner 2026-10-28): real direct messages — the list and the
// requests box, a conversation (send, receive by polling, receipts, delete,
// report), message requests (accept / delete / block, the limit), privacy
// («من يستطيع مراسلتك»), voice notes, gifts in a request, the badge, the
// push route, Arabic RTL and 360×800 at text scale 1.3.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/data/live_voice_recorder.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/messages/unread_messages.dart';
import 'package:kabso_live/features/messages/widgets/chat_composer.dart';
import 'package:kabso_live/features/messages/widgets/dm_message_view.dart';
import 'package:kabso_live/features/posts/data/media_repository.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/features/safety/safety_screens.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_dm_repository.dart';
import '../../helpers/fake_live_gift_repository.dart';
import '../../helpers/fake_live_voice_recorder.dart';
import '../../helpers/fake_media_repository.dart';
import '../../helpers/fake_safety_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

/// Every location the screen went to (other than the start).
final List<String> _visited = [];

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  required FakeDmRepository dm,
  AppLanguage language = AppLanguage.en,
  Size size = const Size(393, 852),
  double textScale = 1,
  List<Override> overrides = const [],
}) async {
  _visited.clear();
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final prefs = await testPrefs(language: language.name);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => screen)],
    errorBuilder: (_, state) {
      _visited.add(state.uri.toString());
      return Scaffold(body: Text('at ${state.uri}'));
    },
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        dmRepositoryProvider.overrideWithValue(dm),
        currentUserProvider.overrideWithValue(testUser()),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(
          brightness: Brightness.light,
          locale: language.locale,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A fresh fake with Sara (accepted, 2 unread), Omar (a request to the
/// caller) and Lina (the caller's request to her).
FakeDmRepository _world() {
  final dm = FakeDmRepository();
  final sara = dmPerson('sara_2026', name: 'Sara');
  final hi = dm.message('c-sara_2026', mine: true, text: 'hi Sara', read: true);
  final question = dm.message(
    'c-sara_2026',
    mine: false,
    text: 'are you live tonight?',
  );
  dm.addConversation(sara, unread: 2, messages: [question, hi]);
  final omar = dmPerson('omar.k', name: 'Omar');
  dm.addConversation(
    omar,
    status: DmConversationStatus.requestReceived,
    unread: 1,
    messages: [dm.message('c-omar.k', mine: false, text: 'hello there')],
  );
  final lina = dmPerson('lina', name: 'Lina', premiumTier: PremiumTier.gold);
  dm.addConversation(
    lina,
    status: DmConversationStatus.requestSent,
    requestLeft: 2,
    messages: [dm.message('c-lina', mine: true, text: 'hey Lina')],
  );
  dm.unreadCounts = const DmUnread(messages: 2, conversations: 1, requests: 1);
  return dm;
}

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  // The open conversation polls; tests drive it themselves.
  setUp(() => ChatScreen.newBackoff = DmPollBackoff.new);

  group('the list', () {
    testWidgets('inbox newest first with previews, unread and the requests '
        'box with its count and hint; a row opens the conversation', (
      tester,
    ) async {
      final dm = _world();
      await _pump(tester, const MessagesTab(), dm: dm);
      expect(find.byKey(DmInboxScreen.rowKey('c-sara_2026')), findsOneWidget);
      expect(find.byKey(DmInboxScreen.rowKey('c-lina')), findsOneWidget);
      expect(find.byKey(DmInboxScreen.rowKey('c-omar.k')), findsNothing);
      // Newest message first: Lina's (sent later in the fixture) on top.
      final lina = tester.getTopLeft(
        find.byKey(DmInboxScreen.rowKey('c-lina')),
      );
      final sara = tester.getTopLeft(
        find.byKey(DmInboxScreen.rowKey('c-sara_2026')),
      );
      expect(lina.dy, lessThan(sara.dy));
      expect(find.text('are you live tonight?'), findsOneWidget);
      expect(find.text(en.dmPreviewYou('hey Lina')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text(en.dmTabRequestsCount('1')), findsOneWidget);

      await tester.tap(find.byKey(DmInboxScreen.requestsTabKey));
      await tester.pumpAndSettle();
      expect(find.byKey(DmInboxScreen.requestsHintKey), findsOneWidget);
      expect(find.byKey(DmInboxScreen.rowKey('c-omar.k')), findsOneWidget);
      expect(dm.calls, contains('conversations:requests'));

      await tester.tap(find.byKey(DmInboxScreen.rowKey('c-omar.k')));
      await tester.pumpAndSettle();
      expect(_visited, [AppRoutes.chat('omar.k')]);
    });

    testWidgets('previews of pictures, voice, gifts and expired messages', (
      tester,
    ) async {
      final dm = FakeDmRepository();
      DmMessage m(String id, DmMessageKind kind, {DmGift? gift}) =>
          dm.message('c-$id', mine: false, kind: kind, gift: gift);
      dm
        ..addConversation(
          dmPerson('a1'),
          messages: [m('a1', DmMessageKind.image)],
        )
        ..addConversation(
          dmPerson('a2'),
          messages: [m('a2', DmMessageKind.voice)],
        )
        ..addConversation(
          dmPerson('a3'),
          messages: [
            m(
              'a3',
              DmMessageKind.gift,
              gift: const DmGift(
                giftCode: 'rose',
                assetKey: 'gift_rose',
                quantity: 5,
                unitPrice: 1,
                totalCoins: 5,
              ),
            ),
          ],
        )
        ..addConversation(dmPerson('a4'));
      await _pump(tester, const MessagesTab(), dm: dm);
      expect(find.text(en.dmLastPhoto), findsOneWidget);
      expect(find.text(en.dmPreviewVoice), findsOneWidget);
      expect(find.text(en.dmPreviewGift('5')), findsOneWidget);
      expect(find.text(en.dmPreviewExpired), findsOneWidget);
    });

    testWidgets('empty boxes say so honestly', (tester) async {
      await _pump(tester, const MessagesTab(), dm: FakeDmRepository());
      expect(find.text(en.conversationsEmptyTitle), findsOneWidget);
      await tester.tap(find.byKey(DmInboxScreen.requestsTabKey));
      await tester.pumpAndSettle();
      expect(find.text(en.dmRequestsEmptyTitle), findsOneWidget);
    });
  });

  group('a conversation', () {
    testWidgets('shows messages with ✓/✓✓ and the 24-hour notice, sends, '
        'receives by polling and marks read', (tester) async {
      final dm = _world();
      await _pump(
        tester,
        const ChatScreen(username: 'sara_2026', displayName: 'Sara'),
        dm: dm,
      );
      expect(find.byKey(ChatScreen.noticeKey), findsOneWidget);
      expect(find.text(en.dmRetentionNotice), findsOneWidget);
      expect(find.text('are you live tonight?'), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
      expect(dm.calls.where((c) => c.startsWith('markRead:')), hasLength(1));

      await tester.enterText(find.byKey(ChatScreen.composerKey), ' see you ');
      await tester.pump();
      await tester.tap(find.byKey(ChatScreen.sendKey));
      await tester.pumpAndSettle();
      expect(dm.calls, contains('send:sara_2026:text:see you'));
      expect(find.text('see you'), findsOneWidget);
      expect(find.byIcon(Icons.done_rounded), findsOneWidget);

      // Sara answers; the open conversation reads it within the fastest
      // poll (no manual refresh).
      dm.messagesOf['c-sara_2026']!.insert(
        0,
        dm.message(
          'c-sara_2026',
          mine: false,
          text: 'yes at 9',
          at: dm.now.add(const Duration(minutes: 5)),
        ),
      );
      await tester.pump(DmPollBackoff.fastest);
      await tester.pumpAndSettle();
      expect(find.text('yes at 9'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('long press: delete for me / for everyone, report others', (
      tester,
    ) async {
      final dm = _world();
      final mine = dm.message(
        'c-sara_2026',
        mine: true,
        text: 'oops',
        at: DateTime.now(),
      );
      dm.messagesOf['c-sara_2026']!.insert(0, mine);
      await _pump(tester, const ChatScreen(username: 'sara_2026'), dm: dm);
      await tester.longPress(find.text('oops'));
      await tester.pumpAndSettle();
      expect(find.byKey(ChatScreen.reportMessageKey), findsNothing);
      await tester.tap(find.byKey(ChatScreen.deleteForEveryoneKey));
      await tester.pumpAndSettle();
      expect(dm.calls, contains('deleteMessage:${mine.id}:everyone'));
      expect(find.text('oops'), findsNothing);

      await tester.longPress(find.text('are you live tonight?'));
      await tester.pumpAndSettle();
      // Someone else's: no delete for everyone.
      expect(find.byKey(ChatScreen.deleteForEveryoneKey), findsNothing);
      await tester.tap(find.byKey(ChatScreen.reportMessageKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feed.post.report.spam')));
      await tester.pumpAndSettle();
      expect(dm.calls.where((c) => c.startsWith('report:')), hasLength(1));
      expect(find.text(en.dmReported), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('mute and delete the conversation from the menu', (
      tester,
    ) async {
      final dm = _world();
      await _pump(tester, const ChatScreen(username: 'sara_2026'), dm: dm);
      await tester.tap(find.byKey(ChatScreen.menuKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ChatScreen.muteKey));
      await tester.pumpAndSettle();
      expect(dm.calls, contains('mute:c-sara_2026:true'));
      await tester.tap(find.byKey(ChatScreen.menuKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ChatScreen.deleteConversationKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ChatScreen.confirmDeleteKey));
      await tester.pumpAndSettle();
      expect(dm.calls, contains('deleteConversation:c-sara_2026'));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a voice note: record, stop, upload as DM_VOICE and send', (
      tester,
    ) async {
      final dm = _world();
      final media = FakeMediaRepository();
      final mic = FakeLiveVoiceRecorder();
      await _pump(
        tester,
        const ChatScreen(username: 'sara_2026'),
        dm: dm,
        overrides: [
          mediaRepositoryProvider.overrideWithValue(media),
          liveVoiceRecorderProvider.overrideWithValue(() => mic),
        ],
      );
      await tester.tap(find.byKey(ChatScreen.sendKey));
      await tester.pump();
      expect(find.byKey(ChatVoiceControl.recordingKey), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byKey(ChatScreen.sendKey));
      await tester.pumpAndSettle();
      expect(mic.starts, 1);
      expect(mic.stops, 1);
      expect(media.dmUploads, ['voice:audio/mp4:2048']);
      expect(dm.calls, contains('send:sara_2026:voice:dm1'));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('a gift in the conversation: the panel sends through the DM '
      'API, closes, and the gift shows as a message', (tester) async {
    final dm = _world();
    final gifts = FakeLiveGiftRepository(codes: ['rose']);
    await _pump(
      tester,
      const ChatScreen(username: 'sara_2026'),
      dm: dm,
      overrides: [liveGiftRepositoryProvider.overrideWithValue(gifts)],
    );
    await tester.tap(find.byKey(ChatScreen.giftKey));
    await tester.pumpAndSettle();
    // A friend: no request warning.
    expect(find.text(en.dmGiftRequestTitle), findsNothing);
    expect(find.byKey(KLiveGiftSheet.sheetKey), findsOneWidget);
    final rose = find.byKey(KLiveGiftSheet.cellKey('rose'));
    await tester.ensureVisible(rose);
    await tester.tap(rose);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(KLiveGiftSheet.sendKey));
    await tester.pumpAndSettle();
    expect(dm.calls, contains('sendGift:sara_2026:rose:1'));
    // Nothing went to a live room.
    expect(gifts.sends, isEmpty);
    expect(find.byKey(KLiveGiftSheet.sheetKey), findsNothing);
    expect(find.text(en.dmGiftMine('1')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  group('message requests', () {
    testWidgets('a request to the caller: Accept, Delete or Block; nothing '
        'is marked read before accepting', (tester) async {
      final dm = _world();
      await _pump(tester, const ChatScreen(username: 'omar.k'), dm: dm);
      expect(find.byKey(ChatScreen.requestBannerKey), findsOneWidget);
      expect(dm.calls.where((c) => c.startsWith('markRead:')), isEmpty);
      await tester.tap(find.byKey(ChatScreen.acceptKey));
      await tester.pumpAndSettle();
      expect(dm.calls, contains('accept:c-omar.k'));
      expect(find.byKey(ChatScreen.requestBannerKey), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());

      final again = _world();
      await _pump(tester, const ChatScreen(username: 'omar.k'), dm: again);
      await tester.tap(find.byKey(ChatScreen.declineKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ChatScreen.confirmDeleteKey));
      await tester.pumpAndSettle();
      expect(again.calls, contains('deleteConversation:c-omar.k'));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a request the caller sent: messages left; at the limit or '
        'refused by privacy the composer gives way to a notice', (
      tester,
    ) async {
      final dm = _world();
      await _pump(tester, const ChatScreen(username: 'lina'), dm: dm);
      expect(
        find.text(en.dmRequestLeft('\u2068Lina\u2069', '2')),
        findsOneWidget,
      );
      // A premium name shows without «@» (D158).
      expect(find.textContaining('@lina'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());

      final full = _world()
        ..byPeer['lina'] = _world().byPeer['lina']!
        ..canMessage = false
        ..reason = DmBlockedReason.requestLimit;
      full.byPeer['lina'] = DmConversation(
        id: 'c-lina',
        peer: dmPerson('lina', name: 'Lina'),
        status: DmConversationStatus.requestSent,
        lastActivityAt: full.now,
        canSend: false,
        requestMessagesLeft: 0,
      );
      await _pump(tester, const ChatScreen(username: 'lina'), dm: full);
      expect(find.byKey(ChatScreen.cannotSendKey), findsOneWidget);
      expect(find.text(en.dmRequestLimit('\u2068Lina\u2069')), findsOneWidget);
      expect(find.byKey(ChatScreen.composerKey), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());

      final closed = FakeDmRepository()
        ..people['nour'] = dmPerson('nour', name: 'Nour')
        ..canMessage = false
        ..reason = DmBlockedReason.notAllowed;
      await _pump(tester, const ChatScreen(username: 'nour'), dm: closed);
      expect(find.text(en.dmNotAllowed('\u2068Nour\u2069')), findsOneWidget);
      expect(find.byKey(ChatScreen.composerKey), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a server refusal is said in words', (tester) async {
      final dm = _world();
      dm.failNext['send'] = dm.failure(ErrorCode.dmRequestTextOnly);
      await _pump(tester, const ChatScreen(username: 'lina'), dm: dm);
      await tester.enterText(find.byKey(ChatScreen.composerKey), 'x');
      await tester.pump();
      await tester.tap(find.byKey(ChatScreen.sendKey));
      await tester.pumpAndSettle();
      expect(find.text(en.errorDmRequestTextOnly), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a gift to a stranger warns first: the coins are spent even '
        'if they never accept', (tester) async {
      final dm = FakeDmRepository()
        ..people['nour'] = dmPerson('nour', name: 'Nour')
        ..asRequest = true;
      await _pump(tester, const ChatScreen(username: 'nour'), dm: dm);
      await tester.tap(find.byKey(ChatScreen.giftKey));
      await tester.pumpAndSettle();
      expect(find.text(en.dmGiftRequestTitle), findsOneWidget);
      expect(
        find.text(en.dmGiftRequestBody('\u2068Nour\u2069')),
        findsOneWidget,
      );
      await tester.tap(find.text(en.actionCancel));
      await tester.pumpAndSettle();
      expect(dm.calls.where((c) => c.startsWith('sendGift')), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('privacy and badge', () {
    testWidgets('«who can message you»: saved at once, with the 24-hour hint', (
      tester,
    ) async {
      final safety = FakeSafetyRepository();
      await _pump(
        tester,
        const PrivacyScreen(),
        dm: FakeDmRepository(),
        overrides: [safetyRepositoryProvider.overrideWithValue(safety)],
      );
      final nobody = find.byKey(PrivacyScreen.messageKey(MentionPolicy.nobody));
      await tester.scrollUntilVisible(nobody, 100);
      expect(find.text(en.privacyMessageTitle), findsOneWidget);
      expect(find.byKey(PrivacyScreen.messageHintKey), findsOneWidget);
      await tester.tap(nobody);
      await tester.pumpAndSettle();
      expect(safety.calls, contains('updatePrivacy:::message=NOBODY'));
      expect(safety.privacySettings.whoCanMessage, MentionPolicy.nobody);
    });

    test(
      'the Messages badge is the server unread count; 0 signed out',
      () async {
        final dm = FakeDmRepository()
          ..unreadCounts = const DmUnread(messages: 7, requests: 3);
        final prefs = await testPrefs();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            dmRepositoryProvider.overrideWithValue(dm),
            currentUserProvider.overrideWithValue(testUser()),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(unreadMessagesProvider, (_, _) {});
        addTearDown(sub.close);
        expect(sub.read(), 0);
        await Future<void>.delayed(Duration.zero);
        expect(sub.read(), 7);

        final out = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            dmRepositoryProvider.overrideWithValue(dm),
            currentUserProvider.overrideWithValue(null),
          ],
        );
        addTearDown(out.dispose);
        expect(out.read(unreadMessagesProvider), 0);
      },
    );

    test('pushes of direct messages open the conversation; polling backs '
        'off while quiet', () {
      const push = PushPayload({
        'kind': 'dm',
        'channel': 'messages',
        'conversationId': 'c1',
        'messageId': 'm1',
        'senderUsername': 'sara_2026',
      });
      expect(push.isMessage, isTrue);
      expect(push.conversation, 'dm:c1');
      expect(push.route(), AppRoutes.chat('sara_2026'));
      expect(const PushPayload({'kind': 'dm'}).route(), AppRoutes.messages);

      final b = DmPollBackoff();
      expect(b.next, DmPollBackoff.fastest);
      for (var i = 0; i < 10; i++) {
        b.after(changed: false);
      }
      expect(b.next, DmPollBackoff.slowest);
      expect(b.after(changed: true), DmPollBackoff.fastest);
    });
  });

  group('layout', () {
    for (final language in AppLanguage.values) {
      testWidgets('list and conversation at 360×800, text ×1.3 '
          '(${language.name}) without overflow', (tester) async {
        final l10n = language == AppLanguage.ar ? ar : en;
        final dm = _world();
        await _pump(
          tester,
          const MessagesTab(),
          dm: dm,
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.dmTabChats), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(
          tester,
          const ChatScreen(username: 'omar.k'),
          dm: _world(),
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.dmRetentionNotice), findsOneWidget);
        expect(find.byKey(ChatScreen.requestBannerKey), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('Arabic: received messages start on the right, sent ones '
        'on the left', (tester) async {
      await _pump(
        tester,
        const ChatScreen(username: 'sara_2026'),
        dm: _world(),
        language: AppLanguage.ar,
      );
      expect(
        Directionality.of(tester.element(find.byType(DmMessageView).first)),
        TextDirection.rtl,
      );
      final received = tester.getCenter(find.text('are you live tonight?'));
      final sent = tester.getCenter(find.text('hi Sara'));
      expect(received.dx, greaterThan(sent.dx));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  test('every kind of push body and composer state is localized', () {
    for (final l10n in [en, ar]) {
      expect(l10n.dmRetentionNotice, isNotEmpty);
      expect(l10n.privacyMessageTitle, isNotEmpty);
    }
    expect(ar.privacyMessageTitle, 'من يستطيع مراسلتك');
    expect(ar.dmTabRequests, 'طلبات المراسلة');
    unawaited(Future<void>.value());
  });
}
