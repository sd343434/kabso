// D355 (CONVENTIONS §10.151): «واتساب» for the staff on the phone — the inbox
// (rows, unread, who has it, tabs, the off state), the chat (bubbles, ticks,
// media states, the composer inside the 24-hour window; outside it only
// «إرسال قالب» with the template's variables; another agent's conversation;
// a closed one), the server's WhatsApp codes in words and the push route.
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/push/push_payload.dart';
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart';
import 'package:kabso_live/features/whatsapp/presentation/wa_screens.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_whatsapp.dart';
import '../../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  FakeWaRepository repo, {
  AppLanguage language = AppLanguage.ar,
}) async {
  // D365: a tall phone, so the whole sample thread (two days, grouped
  // bubbles) is built at once.
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

/// The screens poll with periodic timers: dispose them before the test ends.
Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets('the inbox: rows with unread, who has it; tabs ask the server', (
    tester,
  ) async {
    final repo = FakeWaRepository(
      list: [
        waConversation(),
        waConversation(
          id: 'c2',
          name: null,
          unread: 0,
          assignedTo: waMe,
          assignedToMe: true,
        ),
        waConversation(id: 'c3', name: 'ليلى', unread: 1, assignedTo: waMona),
        waConversation(id: 'c4', name: 'Omar', open: false, unread: 0),
      ],
    );
    await _pump(tester, const WaInboxScreen(), repo);
    expect(find.text('سارة'), findsOneWidget);
    expect(find.text('معي'), findsOneWidget);
    expect(find.text('مع منى'), findsOneWidget);
    expect(find.text('مغلقة'), findsWidgets);
    expect(find.byKey(WaCountBadge.badgeKey), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byKey(WaInboxScreen.row('c1')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(repo.filters, [WaFilter.unassigned]);
    await tester.tap(find.text('محادثاتي'));
    await tester.pumpAndSettle();
    expect(repo.filters.last, WaFilter.mine);
    await _end(tester);
  });

  testWidgets('WhatsApp off on the server: an honest empty state', (
    tester,
  ) async {
    await _pump(
      tester,
      const WaInboxScreen(),
      FakeWaRepository(enabled: false),
      language: AppLanguage.en,
    );
    expect(find.text('WhatsApp is not on yet'), findsOneWidget);
    await _end(tester);
  });

  testWidgets(
    'the chat: bubbles, ticks, media states; marks read; a text reply',
    (tester) async {
      final repo = FakeWaRepository();
      await _pump(tester, const WaChatScreen(conversationId: 'c1'), repo);
      expect(find.text('السلام عليكم'), findsOneWidget);
      // D365: Meta's English title never shows; the failure in words.
      expect(find.text('Message undeliverable'), findsNothing);
      expect(find.text('تعذّر الإرسال'), findsOneWidget);
      expect(find.text('نوع الملف غير مسموح ولم يُحفظ.'), findsOneWidget);
      expect(find.text('رسالة صوتية'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is WaTicks && w.tick == WaTick.read),
        findsOneWidget,
      );
      expect(find.text('👍'), findsOneWidget);
      expect(repo.reads, 1);
      expect(find.byKey(WaChatScreen.windowClosedKey), findsNothing);
      await tester.enterText(
        find.byKey(WaChatScreen.composerKey),
        'وصل الشحن الآن',
      );
      await tester.pump();
      await tester.tap(find.byKey(WaChatScreen.sendKey));
      await tester.pumpAndSettle();
      expect(repo.sentTexts, ['وصل الشحن الآن']);
      await _end(tester);
    },
  );

  testWidgets('D365: day separators, the window countdown, a formatted number, '
      'a failed send in words with «إعادة الإرسال»', (tester) async {
    final repo = FakeWaRepository(
      conversation: waConversation(
        assignedTo: waMe,
        assignedToMe: true,
        unread: 0,
      ),
    );
    await withClock(Clock.fixed(d355Now), () async {
      await _pump(tester, const WaChatScreen(conversationId: 'c1'), repo);
      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('أمس'), findsOneWidget);
      expect(find.text('نافذة الرد: 20 س متبقية'), findsOneWidget);
      expect(find.text('معي'), findsOneWidget);
      expect(find.text('\u2066+966 50 000 1001\u2069'), findsOneWidget);
      // The staff name once for the run of هدى's two messages.
      expect(find.text('هدى'), findsOneWidget);
      expect(find.byKey(WaBubble.failedKey), findsOneWidget);
      await tester.tap(find.byKey(WaBubble.retryKey));
      await tester.pumpAndSettle();
      expect(repo.sentTexts, ['لحظة من فضلك']);
      await _end(tester);
    });
  });

  testWidgets('D365: the «+» sheet offers a photo and a template', (
    tester,
  ) async {
    final repo = FakeWaRepository();
    await _pump(tester, const WaChatScreen(conversationId: 'c1'), repo);
    expect(find.byKey(WaComposer.quickKey), findsOneWidget);
    await tester.tap(find.byKey(WaComposer.attachKey));
    await tester.pumpAndSettle();
    expect(find.byKey(WaComposer.attachPhotoKey), findsOneWidget);
    await tester.tap(find.byKey(WaComposer.attachTemplateKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('wa.param.0')), 'سارة');
    await tester.enterText(find.byKey(const Key('wa.param.1')), '#42');
    await tester.pump();
    await tester.tap(find.text('إرسال').last);
    await tester.pumpAndSettle();
    expect(repo.sentTemplates.single.$1, 'kabso_followup');
    await _end(tester);
  });

  test('D365: numbers in their groups; Meta codes in words', () async {
    expect(waPhoneGroups('+966500001001'), '+966 50 000 1001');
    expect(waPhoneGroups('+97455512345'), '+974 5551 2345');
    expect(waPhoneGroups('+201001234567'), '+20 10 0123 4567');
    expect(waPhoneGroups('+12025550143'), '+1 202 555 0143');
    expect(waPhoneGroups('+4930123456'), '+493 012 345 6');
    expect(waPhoneGroups('abc'), 'abc');
    final ar = await AppLocalizations.delegate.load(const Locale('ar'));
    expect(waFailReason(ar, 131047), ar.waErrWindow);
    expect(waFailReason(ar, 131026), ar.waFailUndeliverable);
    expect(waFailReason(ar, 130429), ar.waFailRate);
    expect(waFailReason(ar, null), ar.waErrSend);
  });

  testWidgets(
    'the window closed: only «إرسال قالب», then the template is sent',
    (tester) async {
      final repo = FakeWaRepository(
        conversation: waConversation(
          windowOpen: false,
          assignedTo: waMe,
          assignedToMe: true,
          unread: 0,
        ),
      );
      await _pump(tester, const WaChatScreen(conversationId: 'c1'), repo);
      expect(find.byKey(WaChatScreen.windowClosedKey), findsOneWidget);
      expect(find.byKey(WaChatScreen.composerKey), findsNothing);
      await tester.tap(find.byKey(WaChatScreen.templateKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('wa.param.0')), 'سارة');
      await tester.enterText(find.byKey(const Key('wa.param.1')), '#42');
      await tester.pump();
      await tester.tap(find.text('إرسال').last);
      await tester.pumpAndSettle();
      expect(repo.sentTemplates, hasLength(1));
      expect(repo.sentTemplates.single.$1, 'kabso_followup');
      expect(repo.sentTemplates.single.$2, ['سارة', '#42']);
      await _end(tester);
    },
  );

  testWidgets(
    "another agent's conversation: no composer; a closed one: «إعادة فتح»",
    (tester) async {
      final repo = FakeWaRepository(
        conversation: waConversation(assignedTo: waMona, unread: 0),
      );
      await _pump(tester, const WaChatScreen(conversationId: 'c1'), repo);
      expect(find.byKey(WaChatScreen.composerKey), findsNothing);
      expect(find.text('المحادثة مع موظف آخر.'), findsOneWidget);
      await _end(tester);
      final closed = FakeWaRepository(
        conversation: waConversation(open: false, unread: 0),
      );
      await _pump(tester, const WaChatScreen(conversationId: 'c1'), closed);
      await tester.tap(find.text('إعادة فتح'));
      await tester.pumpAndSettle();
      expect(closed.actions, ['reopen']);
      await _end(tester);
    },
  );

  testWidgets('a refused send is worded (the 24-hour window)', (tester) async {
    final repo = FakeWaRepository(
      sendError: const ServerFailure(
        code: ErrorCode.whatsappWindowClosed,
        rawCode: 'WHATSAPP_WINDOW_CLOSED',
        debugMessage: 'closed',
        statusCode: 409,
      ),
    );
    await _pump(
      tester,
      const WaChatScreen(conversationId: 'c1'),
      repo,
      language: AppLanguage.en,
    );
    await tester.enterText(find.byKey(WaChatScreen.composerKey), 'hello');
    await tester.pump();
    await tester.tap(find.byKey(WaChatScreen.sendKey));
    await tester.pumpAndSettle();
    expect(
      find.text('The 24-hour window is over: send an approved template.'),
      findsOneWidget,
    );
    await _end(tester);
  });

  test('a whatsapp push opens its conversation (or the inbox)', () {
    const push = PushPayload({
      'kind': 'whatsapp',
      'channel': 'staff',
      'conversationId': 'c 1',
    });
    expect(push.isWhatsApp, isTrue);
    expect(push.route(), AppRoutes.staffWhatsAppChat('c 1'));
    expect(push.route(), '/me/staff/whatsapp/c%201');
    expect(
      const PushPayload({'kind': 'whatsapp'}).route(),
      AppRoutes.staffWhatsApp,
    );
    expect(WaCountBadge.text(0), isNull);
    expect(WaCountBadge.text(120), '99+');
  });

  test('the models read the contract shapes', () {
    final c = WaConversation.fromJson({
      'id': 'c1',
      'phone': '+966500001001',
      'name': null,
      'status': 'CLOSED',
      'assignedTo': {'userId': 'u', 'displayName': null, 'staffId': 'Kabso02'},
      'assignedToMe': false,
      'unreadCount': 0,
      'lastMessageAt': '2026-11-10T09:00:00.000Z',
      'lastPreview': null,
      'lastDirection': 'INBOUND',
      'window': {'open': false, 'closesAt': null},
      'linkedAccount': null,
      'closedAt': '2026-11-10T09:00:00.000Z',
      'createdAt': '2026-11-10T08:00:00.000Z',
    });
    expect(c.open, isFalse);
    expect(c.title, '+966500001001');
    expect(c.assignedTo?.label, 'Kabso02');
    expect(c.takenByOther, isTrue);
    final m = WaMessage.fromJson({
      'id': 'm',
      'direction': 'OUTBOUND',
      'type': 'IMAGE',
      'text': null,
      'media': {
        'state': 'TOO_LARGE',
        'mime': 'video/mp4',
        'size': 1,
        'filename': null,
        'voice': false,
      },
      'location': null,
      'reaction': null,
      'template': null,
      'status': 'DELIVERED',
      'error': null,
      'sentBy': null,
      'at': '2026-11-10T09:00:00.000Z',
      'statusAt': null,
    });
    expect(m.media?.state, WaMediaState.tooLarge);
    expect(m.tick, WaTick.delivered);
    final failed = WaMessage.fromJson({
      'id': 'f',
      'direction': 'OUTBOUND',
      'type': 'TEXT',
      'text': 'x',
      'status': 'FAILED',
      'error': {'code': 131026, 'title': 'Message undeliverable'},
      'at': '2026-11-10T09:00:00.000Z',
    });
    expect(failed.errorCode, 131026);
    expect(failed.tick, WaTick.failed);
  });

  test('the WhatsApp texts exist in both languages', () async {
    final ar = await AppLocalizations.delegate.load(const Locale('ar'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(ar.waRow, 'واتساب');
    expect(en.waRowBadge(3), '3 conversations waiting');
    expect(ar.waWindowClosed, isNot(en.waWindowClosed));
  });
}
