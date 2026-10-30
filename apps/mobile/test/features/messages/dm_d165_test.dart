// D165 (owner 2026-10-29: «الوكيل الثاني يعمل على زر الرسائل»): every
// button of the Messages tab works — search the conversations, «رسالة جديدة»,
// the row's long-press menu (mark read / unread, mute, delete, block), the
// unread mark cleared when the conversation opens, copy a text message, the
// header opens the profile, the composer's honest tooltips. English LTR and
// Arabic RTL; 360×800 at text scale 1.3.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/chat_screen.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/messages/widgets/chat_composer.dart';
import 'package:kabso_live/features/messages/widgets/dm_message_view.dart';
import 'package:kabso_live/features/messages/widgets/dm_new_message_sheet.dart';
import 'package:kabso_live/features/posts/data/posts_repository.dart';
import 'package:kabso_live/features/safety/safety_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_dm_repository.dart';
import '../../helpers/fake_posts_repository.dart';
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

/// Sara (accepted, 2 unread), Lina (the caller's request to her, read) and
/// Omar (a request to the caller, 1 unread).
FakeDmRepository _world() {
  final dm = FakeDmRepository();
  final sara = dmPerson('sara_2026', name: 'Sara');
  dm
    ..addConversation(
      sara,
      unread: 2,
      messages: [
        dm.message('c-sara_2026', mine: false, text: 'are you live?'),
        dm.message('c-sara_2026', mine: true, text: 'hi Sara', read: true),
      ],
    )
    ..addConversation(
      dmPerson('lina', name: 'Lina'),
      status: DmConversationStatus.requestSent,
      requestLeft: 2,
      messages: [dm.message('c-lina', mine: true, text: 'hey Lina')],
    )
    ..addConversation(
      dmPerson('omar.k', name: 'Omar'),
      status: DmConversationStatus.requestReceived,
      unread: 1,
      messages: [dm.message('c-omar.k', mine: false, text: 'hello there')],
    );
  return dm;
}

Finder _row(String id) => find.byKey(DmInboxScreen.rowKey(id));

Future<void> _longPress(WidgetTester tester, String id) async {
  await tester.longPress(
    find.descendant(of: _row(id), matching: find.byType(InkWell)),
  );
  await tester.pumpAndSettle();
}

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  setUp(() => ChatScreen.newBackoff = DmPollBackoff.new);

  group('search', () {
    testWidgets('the search button filters the box by name or username, '
        'says when nothing matches and closes back to the whole box', (
      tester,
    ) async {
      final dm = _world();
      await _pump(tester, const MessagesTab(), dm: dm);
      expect(find.byKey(DmInboxScreen.searchFieldKey), findsNothing);
      expect(
        tester.widget<IconButton>(find.byKey(DmInboxScreen.searchKey)).tooltip,
        en.dmSearch,
      );

      await tester.tap(find.byKey(DmInboxScreen.searchKey));
      await tester.pumpAndSettle();
      expect(find.byKey(DmInboxScreen.searchFieldKey), findsOneWidget);
      expect(find.text(en.dmSearchHint), findsOneWidget);

      await tester.enterText(find.byKey(DmInboxScreen.searchFieldKey), '@Sa');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(dm.calls, contains('conversations:inbox:q=Sa'));
      expect(_row('c-sara_2026'), findsOneWidget);
      expect(_row('c-lina'), findsNothing);

      await tester.enterText(find.byKey(DmInboxScreen.searchFieldKey), 'zz');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byKey(DmInboxScreen.searchEmptyKey), findsOneWidget);
      expect(_row('c-sara_2026'), findsNothing);

      // The requests box is searched on its own.
      await tester.tap(find.byKey(DmInboxScreen.requestsTabKey));
      await tester.pumpAndSettle();
      expect(dm.calls, contains('conversations:requests:q=zz'));

      await tester.tap(find.byKey(DmInboxScreen.searchCloseKey));
      await tester.pumpAndSettle();
      expect(find.byKey(DmInboxScreen.searchFieldKey), findsNothing);
      expect(_row('c-omar.k'), findsOneWidget);
      await tester.tap(find.byKey(DmInboxScreen.inboxTabKey));
      await tester.pumpAndSettle();
      expect(_row('c-sara_2026'), findsOneWidget);
      expect(_row('c-lina'), findsOneWidget);
    });

    testWidgets('Arabic RTL: the search field reads right to left', (
      tester,
    ) async {
      final dm = _world();
      await _pump(
        tester,
        const MessagesTab(),
        dm: dm,
        language: AppLanguage.ar,
        size: const Size(360, 800),
        textScale: 1.3,
      );
      await tester.tap(find.byKey(DmInboxScreen.searchKey));
      await tester.pumpAndSettle();
      expect(find.text(ar.dmSearchHint), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(DmInboxScreen.searchFieldKey)),
        ),
        TextDirection.rtl,
      );
      await tester.enterText(find.byKey(DmInboxScreen.searchFieldKey), 'lin');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(_row('c-lina'), findsOneWidget);
      expect(_row('c-sara_2026'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('row actions', () {
    testWidgets('mark read reads up to the newest message; mark unread puts '
        'a dot; mute; the badge is read again', (tester) async {
      final dm = _world();
      await _pump(tester, const MessagesTab(), dm: dm);
      expect(find.text('2'), findsOneWidget);

      await _longPress(tester, 'c-sara_2026');
      expect(find.byKey(DmInboxScreen.actionUnreadKey), findsNothing);
      await tester.tap(find.byKey(DmInboxScreen.actionReadKey));
      await tester.pumpAndSettle();
      final newest = dm.byPeer['sara_2026']!.lastMessage!.id;
      expect(dm.calls, contains('markRead:c-sara_2026:$newest'));
      expect(find.text('2'), findsNothing);

      await _longPress(tester, 'c-sara_2026');
      expect(find.byKey(DmInboxScreen.actionReadKey), findsNothing);
      await tester.tap(find.byKey(DmInboxScreen.actionUnreadKey));
      await tester.pumpAndSettle();
      expect(dm.calls, contains('markUnread:c-sara_2026:true'));
      expect(
        find.descendant(
          of: _row('c-sara_2026'),
          matching: find.byKey(DmConversationRow.markedDotKey),
        ),
        findsOneWidget,
      );

      // Marked: "mark read" clears the mark.
      await _longPress(tester, 'c-sara_2026');
      await tester.tap(find.byKey(DmInboxScreen.actionReadKey));
      await tester.pumpAndSettle();
      expect(find.byKey(DmConversationRow.markedDotKey), findsNothing);

      await _longPress(tester, 'c-lina');
      expect(find.text(en.dmMute), findsOneWidget);
      await tester.tap(find.byKey(DmInboxScreen.actionMuteKey));
      await tester.pumpAndSettle();
      expect(dm.calls, contains('mute:c-lina:true'));
      expect(find.text(en.dmMuted), findsOneWidget);
      expect(
        find.descendant(
          of: _row('c-lina'),
          matching: find.byIcon(Icons.volume_off_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a request is never read from the list (the sender would '
        'know); it can be marked unread', (tester) async {
      final dm = _world();
      await _pump(tester, const MessagesTab(), dm: dm);
      await tester.tap(find.byKey(DmInboxScreen.requestsTabKey));
      await tester.pumpAndSettle();
      await _longPress(tester, 'c-omar.k');
      // Unread messages: neither read nor unread is offered.
      expect(find.byKey(DmInboxScreen.actionReadKey), findsNothing);
      expect(find.byKey(DmInboxScreen.actionUnreadKey), findsNothing);
      expect(find.byKey(DmInboxScreen.actionDeleteKey), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(dm.calls.where((c) => c.startsWith('markRead')), isEmpty);
    });

    testWidgets('delete asks first and removes the row; block blocks the '
        'person and removes the row (Arabic RTL)', (tester) async {
      final dm = _world();
      final safety = FakeSafetyRepository();
      await _pump(
        tester,
        const MessagesTab(),
        dm: dm,
        language: AppLanguage.ar,
        overrides: [safetyRepositoryProvider.overrideWithValue(safety)],
      );
      await _longPress(tester, 'c-lina');
      expect(find.text(ar.dmDeleteConversation), findsOneWidget);
      expect(find.text(ar.dmMarkUnread), findsOneWidget);
      await tester.tap(find.byKey(DmInboxScreen.actionDeleteKey));
      await tester.pumpAndSettle();
      expect(find.text(ar.dmDeleteConversationTitle), findsOneWidget);
      await tester.tap(find.byKey(DmInboxScreen.confirmDeleteKey));
      await tester.pumpAndSettle();
      expect(dm.calls, contains('deleteConversation:c-lina'));
      expect(_row('c-lina'), findsNothing);

      await _longPress(tester, 'c-sara_2026');
      await tester.tap(find.byKey(DmInboxScreen.actionBlockKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety.block.confirm')));
      await tester.pumpAndSettle();
      expect(safety.calls, contains('block:sara_2026:true'));
      expect(_row('c-sara_2026'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failure is said in words and changes nothing', (
      tester,
    ) async {
      final dm = _world();
      await _pump(tester, const MessagesTab(), dm: dm);
      dm.failNext['markUnread'] = dm.failure(ErrorCode.notFound, status: 404);
      await _longPress(tester, 'c-lina');
      await tester.tap(find.byKey(DmInboxScreen.actionUnreadKey));
      await tester.pumpAndSettle();
      expect(find.byKey(DmConversationRow.markedDotKey), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('new message', () {
    testWidgets('the pen finds someone and opens the conversation', (
      tester,
    ) async {
      final me = testUser();
      final posts = FakePostsRepository()
        ..people = [
          dmPerson('nour', name: 'Nour'),
          dmPerson('nadia', name: 'Nadia'),
          // The caller is never offered.
          UserSummary(
            id: me.id,
            username: 'nme_${me.username}',
            displayName: 'N me',
            avatarUrl: null,
          ),
        ];
      await _pump(
        tester,
        const MessagesTab(),
        dm: _world(),
        overrides: [postsRepositoryProvider.overrideWithValue(posts)],
      );
      await tester.tap(find.byKey(DmInboxScreen.newMessageKey));
      await tester.pumpAndSettle();
      expect(find.byKey(DmNewMessageSheet.startKey), findsOneWidget);

      await tester.enterText(find.byKey(DmNewMessageSheet.fieldKey), 'xq');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byKey(DmNewMessageSheet.emptyKey), findsOneWidget);

      await tester.enterText(find.byKey(DmNewMessageSheet.fieldKey), '@N');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byKey(DmNewMessageSheet.personKey('nour')), findsOneWidget);
      expect(find.byKey(DmNewMessageSheet.personKey('nadia')), findsOneWidget);

      await tester.tap(find.byKey(DmNewMessageSheet.personKey('nour')));
      await tester.pumpAndSettle();
      expect(_visited, [AppRoutes.chat('nour')]);
    });

    testWidgets('Arabic RTL at 360×800 and text scale 1.3', (tester) async {
      final posts = FakePostsRepository()
        ..people = [dmPerson('nour', name: 'نور')];
      await _pump(
        tester,
        const MessagesTab(),
        dm: _world(),
        language: AppLanguage.ar,
        size: const Size(360, 800),
        textScale: 1.3,
        overrides: [postsRepositoryProvider.overrideWithValue(posts)],
      );
      await tester.tap(find.byKey(DmInboxScreen.newMessageKey));
      await tester.pumpAndSettle();
      expect(find.text(ar.conversationsNewMessage), findsWidgets);
      expect(find.text(ar.dmNewMessageStart), findsOneWidget);
      await tester.enterText(find.byKey(DmNewMessageSheet.fieldKey), 'no');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('نور'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('the conversation', () {
    testWidgets('opening a conversation marked unread clears the mark', (
      tester,
    ) async {
      final dm = FakeDmRepository();
      dm.addConversation(
        dmPerson('lina', name: 'Lina'),
        markedUnread: true,
        messages: [dm.message('c-lina', mine: true, text: 'hey')],
      );
      await _pump(tester, const ChatScreen(username: 'lina'), dm: dm);
      expect(dm.calls, contains('markUnread:c-lina:false'));
      expect(dm.byPeer['lina']!.markedUnread, isFalse);
    });

    testWidgets('…and with messages received it reads them', (tester) async {
      final dm = FakeDmRepository();
      final m = dm.message('c-sara', mine: false, text: 'hi');
      dm.addConversation(
        dmPerson('sara', name: 'Sara'),
        markedUnread: true,
        unread: 1,
        messages: [m],
      );
      await _pump(tester, const ChatScreen(username: 'sara'), dm: dm);
      expect(dm.calls, contains('markRead:c-sara:${m.id}'));
      expect(dm.calls.where((c) => c.startsWith('markUnread:c-sara')), isEmpty);
    });

    testWidgets('…but a request marked unread only loses the mark: nothing is '
        'read before it is accepted', (tester) async {
      final dm = FakeDmRepository();
      dm.addConversation(
        dmPerson('omar', name: 'Omar'),
        status: DmConversationStatus.requestReceived,
        markedUnread: true,
        unread: 1,
        messages: [dm.message('c-omar', mine: false)],
      );
      await _pump(tester, const ChatScreen(username: 'omar'), dm: dm);
      expect(dm.calls, contains('markUnread:c-omar:false'));
      expect(dm.calls.where((c) => c.startsWith('markRead')), isEmpty);
      expect(find.byKey(ChatScreen.requestBannerKey), findsOneWidget);
    });

    testWidgets('long press copies a text message; the header opens the '
        'profile', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final dm = FakeDmRepository();
      dm.addConversation(
        dmPerson('sara', name: 'Sara'),
        messages: [dm.message('c-sara', mine: false, text: 'copy me')],
      );
      await _pump(tester, const ChatScreen(username: 'sara'), dm: dm);
      await tester.longPress(find.text('copy me'));
      await tester.pumpAndSettle();
      expect(find.byKey(ChatScreen.copyMessageKey), findsOneWidget);
      await tester.tap(find.byKey(ChatScreen.copyMessageKey));
      await tester.pumpAndSettle();
      expect(copied, ['copy me']);
      expect(find.text(en.dmCopied), findsOneWidget);

      await tester.tap(find.byKey(ChatScreen.headerKey));
      await tester.pumpAndSettle();
      expect(_visited, [AppRoutes.userProfile('sara')]);
    });

    testWidgets('a gift or voice message offers no copy', (tester) async {
      final dm = FakeDmRepository();
      dm.addConversation(
        dmPerson('sara', name: 'Sara'),
        messages: [
          dm.message('c-sara', mine: false, kind: DmMessageKind.voice),
        ],
      );
      await _pump(tester, const ChatScreen(username: 'sara'), dm: dm);
      await tester.longPress(find.byType(DmMessageView).first);
      await tester.pumpAndSettle();
      expect(find.byKey(ChatScreen.copyMessageKey), findsNothing);
      expect(find.byKey(ChatScreen.reportMessageKey), findsOneWidget);
    });
  });

  group('composer tooltips', () {
    Future<void> pumpComposer(
      WidgetTester tester, {
      VoidCallback? onSend,
      VoidCallback? onGift,
      ChatVoiceControl? voice,
      AppLanguage language = AppLanguage.en,
    }) => pumpScreen(
      tester,
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ChatComposer(
            controller: TextEditingController(),
            onSend: onSend,
            onGift: onGift,
            voice: voice,
            giftKey: const Key('gift'),
            sendKey: const Key('send'),
          ),
        ),
      ),
      language: language,
    );

    IconButton button(WidgetTester tester, String key) =>
        tester.widget<IconButton>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(IconButton),
            matchRoot: true,
          ),
        );

    ChatVoiceControl voice({bool recording = false}) => ChatVoiceControl(
      recording: recording,
      elapsed: Duration.zero,
      onToggle: () {},
      onCancel: () {},
    );

    testWidgets('busy (sending): the gift and the microphone wait but still '
        'say what they do — never «not yet»', (tester) async {
      await pumpComposer(tester, onGift: () {}, voice: voice());
      final gift = button(tester, 'gift');
      expect(gift.onPressed, isNull);
      expect(gift.tooltip, en.chatGiftButton);
      final mic = button(tester, 'send');
      expect(mic.onPressed, isNull);
      expect(mic.tooltip, en.liveVoiceRecord);
    });

    testWidgets('ready: both work', (tester) async {
      await pumpComposer(tester, onSend: () {}, onGift: () {}, voice: voice());
      expect(button(tester, 'gift').onPressed, isNotNull);
      expect(button(tester, 'send').onPressed, isNotNull);
    });

    testWidgets('a recording can always be stopped and sent', (tester) async {
      await pumpComposer(tester, voice: voice(recording: true));
      final mic = button(tester, 'send');
      expect(mic.onPressed, isNotNull);
      expect(mic.tooltip, en.liveVoiceSend);
    });

    testWidgets('no recorder here: the microphone says so (Arabic)', (
      tester,
    ) async {
      await pumpComposer(tester, onSend: () {}, language: AppLanguage.ar);
      final mic = button(tester, 'send');
      expect(mic.onPressed, isNull);
      expect(mic.tooltip, ar.chatVoiceUnavailable);
    });
  });
}
