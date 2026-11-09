// D339 (owner: «الدردشات، طلبات المراسلة، المؤرشفة، رسائل جماعية»): archived
// chats and group messages in the Messages tab (CONVENTIONS §10.132,
// §10.133) — groups mixed into «الدردشات» by recency, the «المؤرشفة» box,
// archive from the long press and by swiping (mirrored in Arabic), the
// «+» new-group entry, the new-group screen, the group conversation and
// its info screen. English LTR and Arabic RTL; 360×800 at text scale 1.3.
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/app.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/messages/data/dm_groups_repository.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/group_chat_screen.dart';
import 'package:kabso_live/features/messages/group_info_screen.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/messages/new_group_screen.dart';
import 'package:kabso_live/features/messages/widgets/dm_group_row.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_dm_groups_repository.dart';
import '../../helpers/fake_dm_repository.dart';
import '../../helpers/fake_stories_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

final DateTime _now = DateTime.utc(2026, 11, 9, 12);

/// Every location the screen went to (other than the start).
final List<String> _visited = [];

FakeDmRepository _dm() {
  final dm = FakeDmRepository()..now = _now;
  final omar = dmPerson('omar.k', name: 'Omar');
  dm
    ..addConversation(
      dmPerson('sara_2026', name: 'Sara'),
      unread: 1,
      messages: [
        dm.message(
          'c-sara_2026',
          mine: false,
          text: 'are you live?',
          at: _now.subtract(const Duration(hours: 2)),
        ),
      ],
    )
    ..addGroup(
      'Uni friends',
      id: 'g-uni',
      unread: 3,
      last: DmGroupMessage(
        id: 'gm-1',
        groupId: 'g-uni',
        sender: omar,
        mine: false,
        kind: DmMessageKind.text,
        text: 'see you at 8',
        createdAt: _now.subtract(const Duration(minutes: 5)),
        expiresAt: _now.add(const Duration(hours: 23)),
      ),
    )
    ..addConversation(
      dmPerson('lina', name: 'Lina'),
      archived: true,
      messages: [
        dm.message(
          'c-lina',
          mine: false,
          text: 'archived hello',
          at: _now.subtract(const Duration(days: 1)),
        ),
      ],
    );
  return dm;
}

FakeDmGroupsRepository _groups() {
  final g = FakeDmGroupsRepository()..now = _now;
  final omar = dmPerson('omar.k', name: 'Omar');
  final huda = dmPerson('huda', name: 'Huda');
  g
    ..candidatesList.addAll([omar, huda, dmPerson('nour', name: 'Nour')])
    ..addGroup(
      'g-uni',
      'Uni friends',
      members: [omar, huda],
      messages: [
        g.message('g-uni', mine: false, sender: huda, text: 'me too'),
        g.message('g-uni', mine: false, sender: omar, text: 'see you at 8'),
        g.message('g-uni', mine: true, text: 'who is coming?', readCount: 2),
      ],
    );
  return g;
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  FakeDmRepository? dm,
  FakeDmGroupsRepository? groups,
  AppLanguage language = AppLanguage.en,
  Size size = const Size(393, 852),
  double textScale = 1,
  Brightness brightness = Brightness.light,
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
    routes: [GoRoute(path: '/', builder: (_, _) => home)],
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
        dmRepositoryProvider.overrideWithValue(dm ?? _dm()),
        dmGroupsRepositoryProvider.overrideWithValue(groups ?? _groups()),
        storiesRepositoryProvider.overrideWithValue(FakeStoriesRepository()),
        currentUserProvider.overrideWithValue(testUser()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        locale: language.locale,
        supportedLocales: KabsoApp.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        theme: buildAppTheme(brightness: brightness, locale: language.locale),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openBox(WidgetTester tester, Key box) async {
  await tester.tap(find.byKey(DmInboxScreen.boxesToggleKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(box));
  await tester.pumpAndSettle();
}

void main() {
  final en = l10nFor(AppLanguage.en);
  final ar = l10nFor(AppLanguage.ar);

  group('«Chats» with groups', () {
    for (final language in AppLanguage.values) {
      testWidgets('a group sits among the conversations by recency with its '
          'sender, unread count and a tap opens it (${language.name})', (
        tester,
      ) async {
        final l10n = language == AppLanguage.ar ? ar : en;
        await withClock(Clock.fixed(_now), () async {
          final dm = _dm();
          await _pump(tester, const MessagesTab(), dm: dm, language: language);
          expect(dm.calls, contains('chats:chats'));
          final group = find.byKey(DmGroupRow.rowKey('g-uni'));
          final sara = find.byKey(DmInboxScreen.rowKey('c-sara_2026'));
          expect(group, findsOneWidget);
          expect(sara, findsOneWidget);
          // Newest first: the group (5 minutes) above Sara (2 hours).
          expect(
            tester.getTopLeft(group).dy,
            lessThan(tester.getTopLeft(sara).dy),
          );
          // The archived conversation is not in «Chats».
          expect(find.byKey(DmInboxScreen.rowKey('c-lina')), findsNothing);
          expect(find.text('Uni friends'), findsOneWidget);
          expect(
            find.text(
              l10n.dmPreviewSender(KFormat.bidiIsolate('Omar'), 'see you at 8'),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(of: group, matching: find.text('3')),
            findsOneWidget,
          );
          await tester.tap(group);
          await tester.pumpAndSettle();
          expect(_visited, [AppRoutes.groupChat('g-uni')]);
        });
      });
    }

    testWidgets('«+» opens «New group»', (tester) async {
      await _pump(tester, const MessagesTab());
      // One entry only (owner: «ال+ في الاعلى … يجب ان يكون هذا الزر + زر عمل
      // مجموعة»): the header's «+» disc, no separate group button.
      expect(find.byKey(DmInboxScreen.newGroupKey), findsOneWidget);
      expect(find.byIcon(Icons.group_add_outlined), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(DmInboxScreen.newGroupKey),
          matching: find.byIcon(Icons.add_rounded),
        ),
        findsOneWidget,
      );
      final button = tester.widget<IconButton>(
        find.byKey(DmInboxScreen.newGroupKey),
      );
      expect(button.tooltip, en.dmNewGroup);
      await tester.tap(find.byKey(DmInboxScreen.newGroupKey));
      await tester.pumpAndSettle();
      expect(_visited, [AppRoutes.newGroup]);
    });
  });

  group('«Archived»', () {
    testWidgets('the boxes panel has «Archived»: its rows, the hint, and an '
        'empty state when nothing is archived', (tester) async {
      final dm = _dm();
      await _pump(tester, const MessagesTab(), dm: dm);
      await _openBox(tester, DmInboxScreen.archivedTabKey);
      expect(dm.calls, contains('chats:archived'));
      expect(find.text(en.dmTabArchived), findsOneWidget);
      expect(find.byKey(DmInboxScreen.archivedHintKey), findsOneWidget);
      expect(find.byKey(DmInboxScreen.rowKey('c-lina')), findsOneWidget);
      expect(find.byKey(DmGroupRow.rowKey('g-uni')), findsNothing);

      await _pump(tester, const MessagesTab(), dm: FakeDmRepository());
      await _openBox(tester, DmInboxScreen.archivedTabKey);
      expect(find.text(en.dmArchivedEmptyTitle), findsOneWidget);
    });

    testWidgets('the long press archives a conversation: it leaves «Chats» '
        'and is told', (tester) async {
      final dm = _dm();
      await _pump(tester, const MessagesTab(), dm: dm);
      await tester.longPress(find.byKey(DmInboxScreen.rowKey('c-sara_2026')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DmInboxScreen.actionArchiveKey));
      await tester.pumpAndSettle();
      expect(dm.calls, contains('archive:c-sara_2026:true'));
      expect(find.byKey(DmInboxScreen.rowKey('c-sara_2026')), findsNothing);
      expect(find.text(en.dmArchivedDone), findsOneWidget);
      // In «Archived» now; there the long press moves it back.
      await _openBox(tester, DmInboxScreen.archivedTabKey);
      expect(find.byKey(DmInboxScreen.rowKey('c-sara_2026')), findsOneWidget);
      await tester.longPress(find.byKey(DmInboxScreen.rowKey('c-sara_2026')));
      await tester.pumpAndSettle();
      expect(find.text(en.dmUnarchive), findsOneWidget);
      await tester.tap(find.byKey(DmInboxScreen.actionArchiveKey));
      await tester.pumpAndSettle();
      expect(dm.calls, contains('archive:c-sara_2026:false'));
    });

    for (final language in AppLanguage.values) {
      testWidgets('a swipe towards the reading start archives '
          '(${language.name}, mirrored)', (tester) async {
        final dm = _dm();
        await _pump(tester, const MessagesTab(), dm: dm, language: language);
        final row = find.byKey(DmInboxScreen.rowKey('c-sara_2026'));
        // English: right to left; Arabic: left to right.
        final dx = language == AppLanguage.ar ? 300.0 : -300.0;
        await tester.drag(row, Offset(dx, 0));
        await tester.pumpAndSettle();
        expect(dm.calls, contains('archive:c-sara_2026:true'));
        expect(row, findsNothing);
      });
    }

    testWidgets('a message request is never archived: no swipe, no action', (
      tester,
    ) async {
      final dm = _dm()
        ..addConversation(
          dmPerson('stranger', name: 'Stranger'),
          status: DmConversationStatus.requestReceived,
          messages: [FakeDmRepository().message('c-stranger', mine: false)],
        );
      await _pump(tester, const MessagesTab(), dm: dm);
      await _openBox(tester, DmInboxScreen.requestsTabKey);
      final row = find.byKey(DmInboxScreen.rowKey('c-stranger'));
      expect(find.byKey(DmInboxScreen.swipeKey('c-stranger')), findsNothing);
      await tester.longPress(row);
      await tester.pumpAndSettle();
      expect(find.byKey(DmInboxScreen.actionArchiveKey), findsNothing);
    });

    testWidgets('a group archives from its long press too', (tester) async {
      final dm = _dm();
      final groups = _groups()..dm = dm;
      await _pump(tester, const MessagesTab(), dm: dm, groups: groups);
      await tester.longPress(find.byKey(DmGroupRow.rowKey('g-uni')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DmInboxScreen.actionArchiveKey));
      await tester.pumpAndSettle();
      expect(groups.calls, contains('archive:g-uni:true'));
      expect(find.byKey(DmGroupRow.rowKey('g-uni')), findsNothing);
    });
  });

  group('«New group»', () {
    testWidgets('the people come from the candidates; a name is needed; '
        '«Create» sends the chosen people and opens the group', (tester) async {
      final groups = _groups();
      await _pump(tester, const NewGroupScreen(), groups: groups);
      expect(groups.calls, contains('candidates'));
      expect(find.text(en.dmGroupPickHint), findsOneWidget);
      expect(find.byKey(NewGroupScreen.personKey('omar.k')), findsOneWidget);
      // Nothing chosen, no name.
      await tester.tap(find.byKey(NewGroupScreen.submitKey));
      await tester.pumpAndSettle();
      expect(find.text(en.dmGroupNameRequired), findsOneWidget);
      await tester.enterText(find.byKey(NewGroupScreen.nameKey), 'Weekend');
      await tester.tap(find.byKey(NewGroupScreen.submitKey));
      await tester.pumpAndSettle();
      expect(find.text(en.dmGroupPickAtLeastOne), findsOneWidget);
      await tester.tap(find.byKey(NewGroupScreen.personKey('omar.k')));
      await tester.tap(find.byKey(NewGroupScreen.personKey('huda')));
      await tester.pumpAndSettle();
      expect(find.text(en.dmGroupSelected('2')), findsOneWidget);
      await tester.tap(find.byKey(NewGroupScreen.submitKey));
      await tester.pumpAndSettle();
      expect(groups.calls, contains('create:Weekend:omar.k,huda:-'));
      expect(_visited, [AppRoutes.groupChat('g-new')]);
    });

    testWidgets('search narrows the people; nobody to add says so', (
      tester,
    ) async {
      final groups = _groups();
      await _pump(tester, const NewGroupScreen(), groups: groups);
      await tester.enterText(find.byKey(NewGroupScreen.searchKey), 'hu');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(groups.calls, contains('candidates:q=hu'));
      expect(find.byKey(NewGroupScreen.personKey('huda')), findsOneWidget);
      expect(find.byKey(NewGroupScreen.personKey('omar.k')), findsNothing);

      await _pump(
        tester,
        const NewGroupScreen(),
        groups: FakeDmGroupsRepository(),
      );
      expect(find.byKey(NewGroupScreen.emptyKey), findsOneWidget);
      expect(find.text(en.dmGroupCandidatesEmpty), findsOneWidget);
    });

    testWidgets('a refusal from the server is said (members not allowed)', (
      tester,
    ) async {
      final groups = _groups()
        ..failNext['create'] = FakeDmRepository().failure(
          ErrorCode.dmGroupMemberNotAllowed,
        );
      await _pump(tester, const NewGroupScreen(), groups: groups);
      await tester.enterText(find.byKey(NewGroupScreen.nameKey), 'Weekend');
      await tester.tap(find.byKey(NewGroupScreen.personKey('nour')));
      await tester.tap(find.byKey(NewGroupScreen.submitKey));
      await tester.pumpAndSettle();
      expect(find.text(en.errorDmGroupMemberNotAllowed), findsOneWidget);
      expect(_visited, isEmpty);
    });
  });

  group('the daily limit (owner: 2 new groups a day)', () {
    testWidgets('a 3rd group the same day is refused by the server (429): '
        'the screen says so, stays, and creates nothing', (tester) async {
      final groups = _groups()
        ..failNext['create'] = FakeDmRepository().failure(
          ErrorCode.rateLimited,
          status: 429,
        );
      await _pump(tester, const NewGroupScreen(), groups: groups);
      await tester.enterText(find.byKey(NewGroupScreen.nameKey), 'Third');
      await tester.tap(find.byKey(NewGroupScreen.personKey('nour')));
      await tester.tap(find.byKey(NewGroupScreen.submitKey));
      await tester.pumpAndSettle();
      expect(groups.calls, contains('create:Third:nour:-'));
      expect(find.text(en.errorRateLimited), findsOneWidget);
      expect(_visited, isEmpty);
      expect(find.byType(NewGroupScreen), findsOneWidget);
    });
  });

  group('a group conversation', () {
    for (final language in AppLanguage.values) {
      testWidgets("the name and member count, the sender over the others' "
          'messages, and sending (${language.name})', (tester) async {
        final l10n = language == AppLanguage.ar ? ar : en;
        final groups = _groups();
        await _pump(
          tester,
          const GroupChatScreen(groupId: 'g-uni', name: 'Uni friends'),
          groups: groups,
          language: language,
        );
        expect(find.text('Uni friends'), findsOneWidget);
        expect(find.text(l10n.dmGroupMembersCount('3')), findsOneWidget);
        expect(find.text('Omar'), findsOneWidget);
        expect(find.text('Huda'), findsOneWidget);
        // Nothing unread: the read pointer is not moved.
        expect(groups.calls.where((c) => c.startsWith('read:g-uni')), isEmpty);
        await tester.enterText(
          find.byKey(GroupChatScreen.composerKey),
          'on my way',
        );
        await tester.pump();
        await tester.tap(find.byKey(GroupChatScreen.sendKey));
        await tester.pumpAndSettle();
        expect(groups.calls, contains('send:g-uni:on my way'));
        expect(find.text('on my way'), findsOneWidget);
      });
    }

    testWidgets('the menu leaves after a confirmation', (tester) async {
      final groups = _groups();
      await _pump(
        tester,
        const GroupChatScreen(groupId: 'g-uni'),
        groups: groups,
      );
      await tester.tap(find.byKey(GroupChatScreen.menuKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GroupChatScreen.leaveKey));
      await tester.pumpAndSettle();
      expect(find.text(en.dmGroupLeaveTitle), findsOneWidget);
      await tester.tap(find.byKey(GroupChatScreen.confirmLeaveKey));
      await tester.pumpAndSettle();
      expect(groups.calls, contains('leave:g-uni'));
    });

    testWidgets('a group the caller is no longer in says so', (tester) async {
      await _pump(
        tester,
        const GroupChatScreen(groupId: 'g-gone'),
        groups: _groups(),
      );
      expect(find.byKey(GroupChatScreen.unavailableKey), findsOneWidget);
      expect(find.text(en.dmGroupUnavailable), findsOneWidget);
    });
  });

  group('group info', () {
    testWidgets('admins see the creator, add members and member actions', (
      tester,
    ) async {
      final groups = _groups();
      await _pump(
        tester,
        const GroupInfoScreen(groupId: 'g-uni'),
        groups: groups,
      );
      expect(find.text(en.dmGroupCreator), findsOneWidget);
      expect(find.byKey(GroupInfoScreen.addKey), findsOneWidget);
      expect(find.byKey(GroupInfoScreen.renameKey), findsOneWidget);
      await tester.tap(find.byKey(GroupInfoScreen.memberKey('omar.k')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(GroupInfoScreen.makeAdminKey));
      await tester.pumpAndSettle();
      expect(groups.calls, contains('role:g-uni:omar.k:ADMIN'));
      await tester.tap(find.byKey(GroupInfoScreen.addKey));
      await tester.pumpAndSettle();
      expect(_visited, [AppRoutes.groupAdd('g-uni')]);
    });

    testWidgets('a member has no admin tools', (tester) async {
      final groups = FakeDmGroupsRepository()
        ..addGroup(
          'g-m',
          'Family',
          role: DmGroupRole.member,
          members: [dmPerson('omar.k', name: 'Omar')],
        );
      await _pump(
        tester,
        const GroupInfoScreen(groupId: 'g-m'),
        groups: groups,
      );
      expect(find.byKey(GroupInfoScreen.addKey), findsNothing);
      expect(find.byKey(GroupInfoScreen.renameKey), findsNothing);
      expect(find.byKey(GroupInfoScreen.leaveKey), findsOneWidget);
    });
  });

  group('360×800 at text scale 1.3', () {
    for (final language in AppLanguage.values) {
      testWidgets('the tab with a group, the new-group screen and the group '
          'fit without overflow (${language.name})', (tester) async {
        await _pump(
          tester,
          const MessagesTab(),
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(DmGroupRow.rowKey('g-uni')), findsOneWidget);
        await _pump(
          tester,
          const NewGroupScreen(),
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        await _pump(
          tester,
          const GroupChatScreen(groupId: 'g-uni'),
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
        await _pump(
          tester,
          const GroupInfoScreen(groupId: 'g-uni'),
          language: language,
          size: const Size(360, 800),
          textScale: 1.3,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
