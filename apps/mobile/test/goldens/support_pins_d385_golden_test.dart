// D385 (owner: «اجعل شات الإدارة مثبت في الاعلى بنفس هذه الطريقة بالإضافة
// يمكن للشخص تثبيت ٥ محادثات في الاعلى», CONVENTIONS §10.174):
//
//   support_pins_d385.messages   the top of «الرسائل»: «دعم كابسو» first with
//                                its unread count, then the pinned chats in
//                                pin order (a peer online, an unread one, a
//                                group), the chats below
//   support_pins_d385.chat       «دعم كابسو» after a closed ticket: the
//                                person's message «تمت القراءة», a reply
//                                under the «فريق كابسو» badge with the
//                                first name, and the topic picker of a new
//                                ticket above the composer
//   support_pins_d385.inbox      the staff inbox with an «داخل التطبيق»
//                                thread beside a WhatsApp one (Arabic)
//
// Arabic and English, dark and light, on the phone (393 × 852 with the
// status bar 59 and the home indicator 34). A fixed clock; synthetic people
// and initials only (no third-party art). Regenerate on Linux with the
// pinned Flutter:
//   flutter test --update-goldens test/goldens/support_pins_d385_golden_test.dart
@Tags(['golden'])
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/data/dm_groups_repository.dart';
import 'package:kabso_live/features/messages/data/dm_repository.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/messages_tab.dart';
import 'package:kabso_live/features/stories/data/stories_repository.dart';
import 'package:kabso_live/features/support/data/support_repository.dart';
import 'package:kabso_live/features/support/domain/support_models.dart';
import 'package:kabso_live/features/support/presentation/support_chat_screen.dart';
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart';
import 'package:kabso_live/features/whatsapp/presentation/wa_screens.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/fake_dm_groups_repository.dart';
import '../helpers/fake_dm_repository.dart';
import '../helpers/fake_stories_repository.dart';
import '../helpers/fake_support_repository.dart';
import '../helpers/fake_whatsapp.dart';
import '../helpers/fakes.dart';
import '../helpers/golden.dart';
import '../helpers/pump_app.dart';

final DateTime _now = DateTime.utc(2026, 11, 12, 12);

class _SlowBackoff extends DmPollBackoff {
  @override
  Duration get next => const Duration(days: 1);
}

FakeDmRepository _dm(bool ar) {
  final dm = FakeDmRepository()..now = _now;
  final people = ar
      ? const ['سارة', 'عمر', 'ليلى', 'نور', 'خالد']
      : const ['Sara', 'Omar', 'Layla', 'Nour', 'Khalid'];
  final texts = ar
      ? const [
          'هل أنت في البث؟',
          'أراك لاحقاً',
          'شكراً على الهدية',
          'تمام',
          'أين أنت؟',
        ]
      : const [
          'are you live?',
          'see you',
          'thanks for the gift',
          'ok',
          'where are you?',
        ];
  for (var i = 0; i < people.length; i++) {
    final u = 'user_$i';
    dm.addConversation(
      dmPerson(u, name: people[i]),
      unread: i == 1 ? 2 : 0,
      messages: [
        dm.message(
          'c-$u',
          mine: i == 3,
          text: texts[i],
          at: _now.subtract(Duration(minutes: 4 + i * 37)),
        ),
      ],
    );
  }
  dm.addGroup(
    ar ? 'أصدقاء الجامعة' : 'Uni friends',
    id: 'g-uni',
    at: _now.subtract(const Duration(hours: 5)),
  );
  return dm;
}

FakeDmPinsRepository _pins(FakeDmRepository dm) {
  DmPin direct(String u) =>
      DmPin(chat: DmChat.direct(dm.byPeer[u]!), pinnedAt: _now);
  return FakeDmPinsRepository([
    direct('user_0'),
    direct('user_1'),
    DmPin(chat: DmChat.group(dm.groups['g-uni']!), pinnedAt: _now),
    direct('user_2'),
  ])..online['c-user_0'] = true;
}

FakeSupportRepository _closedTicket(bool ar) => FakeSupportRepository(
  thread: const SupportThread(
    id: 't1',
    status: SupportThreadStatus.closed,
    department: WaDepartment.payments,
  ),
  messages: [
    SupportMessage(
      id: 'r1',
      mine: false,
      kind: DmMessageKind.text,
      text: ar
          ? 'وصلت الكوينز إلى حسابك الآن. شكراً لصبرك!'
          : 'The coins are in your account now. Thanks for waiting!',
      staffFirstName: ar ? 'سارة' : 'Sara',
      createdAt: _now.subtract(const Duration(minutes: 30)),
    ),
    SupportMessage(
      id: 'm1',
      mine: true,
      kind: DmMessageKind.text,
      text: ar
          ? 'شحنت ٥٠٠٠ كوينز ولم تصل إلى حسابي'
          : 'I topped up 5,000 coins and they did not arrive',
      receipt: SupportReceipt.read,
      createdAt: _now.subtract(const Duration(minutes: 42)),
    ),
  ],
);

Future<void> _phone(WidgetTester tester) async {
  await loadAppFonts();
  setViewport(tester, GoldenViewport.phone);
  tester.view.padding = const FakeViewPadding(
    top: 59 * GoldenViewport.pixelRatio,
    bottom: 34 * GoldenViewport.pixelRatio,
  );
  addTearDown(tester.view.resetPadding);
}

Future<void> _scope(
  WidgetTester tester,
  Widget screen, {
  required AppLanguage language,
  required Brightness brightness,
  List<Override> overrides = const [],
}) async {
  final prefs = await testPrefs(language: language.name);
  await pumpGolden(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        storiesRepositoryProvider.overrideWithValue(FakeStoriesRepository()),
        dmGroupsRepositoryProvider.overrideWithValue(FakeDmGroupsRepository()),
        currentUserProvider.overrideWithValue(testUser()),
        ...overrides,
      ],
      child: screen,
    ),
    language: language,
    brightness: brightness,
    bare: true,
  );
  await tester.pumpAndSettle();
  await precacheImages(tester);
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  setUpAll(loadAppFonts);

  forEachLanguage((language) {
    final ar = language == AppLanguage.ar;
    final name = language.name;
    for (final (label, brightness) in [
      ('phone', Brightness.dark),
      ('phone.light', Brightness.light),
    ]) {
      testWidgets('support_pins_d385.messages $name $label', (tester) async {
        await _phone(tester);
        final dm = _dm(ar);
        final support = FakeSupportRepository()..reply('…');
        await withClock(Clock.fixed(_now), () async {
          await _scope(
            tester,
            const MessagesTab(),
            language: language,
            brightness: brightness,
            overrides: [
              dmRepositoryProvider.overrideWithValue(dm),
              dmPinsRepositoryProvider.overrideWithValue(_pins(dm)),
              supportRepositoryProvider.overrideWithValue(support),
            ],
          );
        });
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/support_pins_d385.messages.$name.$label.png'),
        );
        await _end(tester);
      });

      testWidgets('support_pins_d385.chat $name $label', (tester) async {
        await _phone(tester);
        SupportChatScreen.newBackoff = _SlowBackoff.new;
        addTearDown(() => SupportChatScreen.newBackoff = DmPollBackoff.new);
        await withClock(Clock.fixed(_now), () async {
          await _scope(
            tester,
            const SupportChatScreen(),
            language: language,
            brightness: brightness,
            overrides: [
              supportRepositoryProvider.overrideWithValue(_closedTicket(ar)),
              dmPinsRepositoryProvider.overrideWithValue(
                FakeDmPinsRepository(),
              ),
            ],
          );
          await tester.tap(
            find.byKey(SupportChatScreen.topicKey(WaDepartment.payments)),
          );
          await tester.pumpAndSettle();
        });
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('png/support_pins_d385.chat.$name.$label.png'),
        );
        await _end(tester);
      });
    }
  });

  testWidgets('support_pins_d385.inbox ar phone', (tester) async {
    await _phone(tester);
    final repo = FakeWaRepository(
      enabled: false,
      inApp: true,
      list: [
        waConversation(
          id: 'a1',
          name: 'ليلى',
          preview: 'شحنت ٥٠٠٠ كوينز ولم تصل',
          channel: WaChannel.inApp,
          department: WaDepartment.payments,
        ),
        waConversation(id: 'w1', unread: 0, assignedTo: waMona),
      ],
    );
    await withClock(Clock.fixed(d355Now), () async {
      await _scope(
        tester,
        const WaInboxScreen(),
        language: AppLanguage.ar,
        brightness: Brightness.dark,
        overrides: [waRepositoryProvider.overrideWithValue(repo)],
      );
    });
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('png/support_pins_d385.inbox.ar.phone.png'),
    );
    await _end(tester);
  });
}
