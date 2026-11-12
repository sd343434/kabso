// D385 (CONVENTIONS §10.174.6): the staff inbox lists the in-app «دعم كابسو»
// threads beside the WhatsApp ones, marked «داخل التطبيق»; it stays on while
// WhatsApp itself is off; an in-app thread has no 24-hour window, no
// templates, no attachments and no account link.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart';
import 'package:kabso_live/features/whatsapp/presentation/wa_screens.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_whatsapp.dart';
import '../../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  FakeWaRepository repo, {
  AppLanguage language = AppLanguage.ar,
}) async {
  tester.view
    ..physicalSize = const Size(800, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpScreen(
    tester,
    screen,
    language: language,
    overrides: [waRepositoryProvider.overrideWithValue(repo)],
  );
  await tester.pumpAndSettle();
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  final ar = l10nFor(AppLanguage.ar);

  testWidgets('WhatsApp off, in-app on: the inbox lists «داخل التطبيق»', (
    tester,
  ) async {
    final repo = FakeWaRepository(
      enabled: false,
      inApp: true,
      list: [
        waConversation(
          id: 'a1',
          name: 'ليلى',
          channel: WaChannel.inApp,
          department: WaDepartment.payments,
        ),
        waConversation(id: 'w1'),
      ],
    );
    await _pump(tester, const WaInboxScreen(), repo);
    expect(find.text(ar.waOff), findsNothing);
    expect(find.byKey(WaInboxScreen.inAppKey('a1')), findsOneWidget);
    expect(find.byKey(WaInboxScreen.inAppKey('w1')), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(WaInboxScreen.row('a1')),
        matching: find.text(ar.waInApp),
      ),
      findsOneWidget,
    );
    await _end(tester);
  });

  testWidgets('both off: the inbox says WhatsApp is off (as before)', (
    tester,
  ) async {
    final repo = FakeWaRepository(enabled: false);
    await _pump(tester, const WaInboxScreen(), repo);
    expect(find.text(ar.waOff), findsOneWidget);
    await _end(tester);
  });

  testWidgets('an in-app thread: no window, no attachments or templates', (
    tester,
  ) async {
    final repo = FakeWaRepository(
      enabled: false,
      inApp: true,
      conversation: waConversation(
        id: 'a1',
        name: 'ليلى',
        channel: WaChannel.inApp,
        assignedTo: waMe,
        assignedToMe: true,
      ),
    );
    await _pump(tester, const WaChatScreen(conversationId: 'a1'), repo);
    expect(find.text(ar.waInApp), findsWidgets);
    expect(find.byKey(WaComposer.attachKey), findsNothing);
    expect(find.byKey(WaChatScreen.templateKey), findsNothing);
    expect(find.byKey(WaChatScreen.windowClosedKey), findsNothing);
    expect(find.byKey(WaChatScreen.composerKey), findsOneWidget);
    await tester.enterText(find.byKey(WaChatScreen.composerKey), 'أهلًا');
    await tester.pump();
    await tester.tap(find.byKey(WaChatScreen.sendKey));
    await tester.pumpAndSettle();
    expect(repo.sentTexts, ['أهلًا']);
    await _end(tester);
  });

  test('a «دعم كابسو» push opens the support chat', () {
    const push = PushPayload({
      'kind': 'support',
      'channel': 'messages',
      'conversationId': 't1',
    });
    expect(push.isMessage, isTrue);
    expect(push.isDirectMessage, isTrue);
    expect(push.conversation, 'support:t1');
    expect(push.route(), AppRoutes.supportChat);
  });

  test('the summary: in-app keeps the inbox served without WhatsApp', () {
    final s = WaSummary.fromJson(const {
      'enabled': false,
      'inApp': true,
      'badge': 1,
      'mine': 0,
      'unassigned': 1,
    });
    expect(s.served, isTrue);
    expect(WaSummary.off.served, isFalse);
    final c = WaConversation.fromJson(const {
      'id': 'a1',
      'phone': null,
      'name': 'Layla',
      'status': 'OPEN',
      'channel': 'IN_APP',
      'window': {'open': true, 'closesAt': null},
      'lastMessageAt': '2026-11-12T10:00:00Z',
    });
    expect(c.inApp, isTrue);
    expect(c.phone, isNull);
    expect(c.title, 'Layla');
  });
}
