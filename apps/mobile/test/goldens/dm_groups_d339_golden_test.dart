// D339 (CONVENTIONS §10.132, §10.133): the Messages tab with a group mixed
// into «الدردشات» and the boxes panel open on «المؤرشفة»; «مجموعة جديدة»;
// a group conversation; «معلومات المجموعة». Labelled test data from the
// fakes (no third-party art: a group without a photo shows Kabso's people
// disc). ar and en, dark and light at 393×852, the tab also at 360×800, @3x.
//
// Regenerate on Linux with the pinned Flutter:
//   flutter test --update-goldens test/goldens/dm_groups_d339_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/messages/data/dm_groups_repository.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/group_chat_screen.dart';
import 'package:kabso_live/features/messages/group_info_screen.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/messages/new_group_screen.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_dm_groups_repository.dart';
import '../helpers/fake_dm_repository.dart';
import '../helpers/fake_stories_repository.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

final DateTime _now = DateTime.utc(2026, 11, 9, 12);

FakeDmRepository _dm() {
  final dm = FakeDmRepository()..now = _now;
  final omar = dmPerson('omar.k', name: 'Omar');
  dm
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
      dmPerson('sara_2026', name: 'Sara'),
      unread: 1,
      messages: [
        dm.message(
          'c-sara_2026',
          mine: false,
          text: 'are you live tonight?',
          at: _now.subtract(const Duration(hours: 2)),
        ),
      ],
    )
    ..addGroup(
      'Family',
      id: 'g-family',
      muted: true,
      at: _now.subtract(const Duration(days: 1)),
    )
    ..addConversation(
      dmPerson('huda', name: 'Huda'),
      messages: [
        dm.message(
          'c-huda',
          mine: true,
          text: 'thanks!',
          at: _now.subtract(const Duration(days: 2)),
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
    ..candidatesList.addAll([
      omar,
      huda,
      dmPerson('nour', name: 'Nour'),
      dmPerson('sara_2026', name: 'Sara'),
    ])
    ..addGroup(
      'g-uni',
      'Uni friends',
      members: [
        omar,
        huda,
        dmPerson('nour', name: 'Nour'),
      ],
      messages: [
        g.message(
          'g-uni',
          mine: false,
          sender: huda,
          text: 'me too',
          at: _now.subtract(const Duration(minutes: 3)),
        ),
        g.message(
          'g-uni',
          mine: false,
          sender: omar,
          text: 'see you at 8',
          at: _now.subtract(const Duration(minutes: 5)),
        ),
        g.message(
          'g-uni',
          mine: true,
          text: 'who is coming tonight?',
          readCount: 3,
          at: _now.subtract(const Duration(minutes: 9)),
        ),
      ],
    );
  return g;
}

Future<void> _golden(
  WidgetTester tester,
  Widget screen,
  String name, {
  required AppLanguage language,
  Brightness brightness = Brightness.dark,
  GoldenViewport viewport = GoldenViewport.phone,
  Future<void> Function()? then,
}) async {
  final prefs = await testPrefs(language: language.name);
  await withClock(Clock.fixed(_now), () async {
    await pumpGolden(
      tester,
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          dmRepositoryProvider.overrideWithValue(_dm()),
          dmGroupsRepositoryProvider.overrideWithValue(_groups()),
          storiesRepositoryProvider.overrideWithValue(FakeStoriesRepository()),
          currentUserProvider.overrideWithValue(testUser()),
        ],
        child: screen,
      ),
      language: language,
      brightness: brightness,
      viewport: viewport,
      bare: true,
    );
    await then?.call();
    await expectScreenGolden(name, language: language, viewport: viewport);
  });
}

void main() {
  forEachLanguage((language) {
    group(language.name, () {
      for (final brightness in Brightness.values) {
        final suffix = brightness == Brightness.light ? '_light' : '';
        testWidgets('dm_d339_chats$suffix (phone)', (tester) async {
          await _golden(
            tester,
            const MessagesTab(),
            'dm_d339_chats$suffix',
            language: language,
            brightness: brightness,
            then: () async {
              await tester.tap(find.byKey(DmInboxScreen.boxesToggleKey));
              await tester.pumpAndSettle();
            },
          );
        });
        testWidgets('dm_d339_group_chat$suffix (phone)', (tester) async {
          await _golden(
            tester,
            const GroupChatScreen(groupId: 'g-uni', name: 'Uni friends'),
            'dm_d339_group_chat$suffix',
            language: language,
            brightness: brightness,
          );
        });
      }
      testWidgets('dm_d339_chats (android)', (tester) async {
        await _golden(
          tester,
          const MessagesTab(),
          'dm_d339_chats',
          language: language,
          viewport: GoldenViewport.android,
        );
      });
      testWidgets('dm_d339_new_group (phone)', (tester) async {
        await _golden(
          tester,
          const NewGroupScreen(),
          'dm_d339_new_group',
          language: language,
          then: () async {
            await tester.tap(find.byKey(NewGroupScreen.personKey('omar.k')));
            await tester.tap(find.byKey(NewGroupScreen.personKey('huda')));
            await tester.pumpAndSettle();
          },
        );
      });
      testWidgets('dm_d339_group_info (phone)', (tester) async {
        await _golden(
          tester,
          const GroupInfoScreen(groupId: 'g-uni'),
          'dm_d339_group_info',
          language: language,
        );
      });
    });
  });
}
