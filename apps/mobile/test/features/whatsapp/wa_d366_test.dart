// D366 (CONVENTIONS §10.159; owner «نعم موافق»): WhatsApp departments and
// the transfer on the phone — the header's «تحويل» button (REPLY+, open
// conversations; never VIEW or closed; no longer in the ⋮ menu), the transfer
// sheet (department chips, «أول متاح في القسم» first, the department's
// agents with the on-shift dot and their open conversations, the note, the
// confirm), the toast and the department chip after it, the inbox's
// department filter and chips, the wire shapes and an older server (no
// department → GENERAL).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/config/app_config.dart';
import 'package:kabso_live/core/network/auth_tokens.dart';
import 'package:kabso_live/core/network/network_providers.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/core/storage/secure_token_store.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart';
import 'package:kabso_live/features/whatsapp/presentation/wa_screens.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/contract_fixtures.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_whatsapp.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';
import 'wa_d360_test.dart'
    show FixedStaffStatus, d360Reply, d360Status, d360View;

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  FakeWaRepository repo, {
  List<String> capabilities = d360Reply,
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
    overrides: [
      waRepositoryProvider.overrideWithValue(repo),
      staffStatusProvider.overrideWith(
        () => FixedStaffStatus(d360Status(capabilities)),
      ),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(WaChatScreen.transferKey));
  await tester.pumpAndSettle();
  expect(find.byType(WaTransferSheet), findsOneWidget);
}

void main() {
  group('the chat header', () {
    testWidgets('REPLY, open: «تحويل» beside the customer button, not in ⋮', (
      tester,
    ) async {
      final repo = FakeWaRepository();
      await _pump(tester, const WaChatScreen(conversationId: 'c1'), repo);
      final button = find.byKey(WaChatScreen.transferKey);
      expect(button, findsOneWidget);
      expect(tester.widget<IconButton>(button).tooltip, 'تحويل');
      // Next to the customer button (same row, adjacent).
      final details = tester.getCenter(find.byKey(WaChatScreen.detailsKey));
      final transfer = tester.getCenter(button);
      expect(transfer.dy, details.dy);
      expect((transfer.dx - details.dx).abs(), lessThan(60));
      // Not a second time in the actions menu.
      await tester.tap(find.byKey(WaChatScreen.menuKey));
      await tester.pumpAndSettle();
      expect(find.byType(PopupMenuItem<String>), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(PopupMenuItem<String>),
          matching: find.text('تحويل'),
        ),
        findsNothing,
      );
      await _end(tester);
    });

    testWidgets('hidden for VIEW and for a closed conversation', (
      tester,
    ) async {
      await _pump(
        tester,
        const WaChatScreen(conversationId: 'c1'),
        FakeWaRepository(),
        capabilities: d360View,
      );
      expect(find.byKey(WaChatScreen.transferKey), findsNothing);
      await _end(tester);
      await _pump(
        tester,
        const WaChatScreen(conversationId: 'c1'),
        FakeWaRepository(conversation: waConversation(open: false)),
      );
      expect(find.byKey(WaChatScreen.transferKey), findsNothing);
      expect(find.byKey(WaChatScreen.menuKey), findsOneWidget);
      await _end(tester);
    });
  });

  group('the transfer sheet', () {
    testWidgets(
      'department chips, «أول متاح» first, the agents with shift and load',
      (tester) async {
        final repo = FakeWaRepository();
        await _pump(tester, const WaChatScreen(conversationId: 'c1'), repo);
        await _openSheet(tester);
        expect(find.text('تحويل المحادثة'), findsOneWidget);
        for (final d in WaDepartment.values) {
          expect(find.byKey(WaTransferSheet.departmentKey(d)), findsOneWidget);
        }
        // The conversation's own department is picked first (GENERAL).
        expect(
          tester
              .widget<KChip>(
                find.byKey(WaTransferSheet.departmentKey(WaDepartment.general)),
              )
              .selected,
          isTrue,
        );
        expect(find.byKey(WaTransferSheet.agentKey('s2')), findsOneWidget);
        await tester.tap(
          find.byKey(WaTransferSheet.departmentKey(WaDepartment.payments)),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(WaTransferSheet.agentKey('s2')), findsNothing);
        final first = find.byKey(WaTransferSheet.firstKey);
        final khalid = find.byKey(WaTransferSheet.agentKey('s3'));
        final rana = find.byKey(WaTransferSheet.agentKey('s4'));
        expect(first, findsOneWidget);
        expect(find.text('أول متاح في القسم'), findsOneWidget);
        expect(
          tester.getTopLeft(first).dy,
          lessThan(tester.getTopLeft(khalid).dy),
        );
        expect(
          tester.getTopLeft(khalid).dy,
          lessThan(tester.getTopLeft(rana).dy),
        );
        expect(
          find.descendant(of: khalid, matching: find.textContaining('مناوب')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: khalid,
            matching: find.textContaining('محادثة مفتوحة'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: rana,
            matching: find.textContaining('خارج المناوبة'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: rana,
            matching: find.textContaining('3 محادثات مفتوحة'),
          ),
          findsOneWidget,
        );
        // «أول متاح» is the default choice.
        expect(
          find.descendant(
            of: first,
            matching: find.byIcon(Icons.radio_button_checked_rounded),
          ),
          findsOneWidget,
        );
        await _end(tester);
      },
    );

    testWidgets(
      'a person, a note → transferred; the toast and the department chip',
      (tester) async {
        final repo = FakeWaRepository(
          conversation: waConversation(assignedTo: waMe, assignedToMe: true),
        );
        await _pump(tester, const WaChatScreen(conversationId: 'c1'), repo);
        expect(find.byKey(WaDepartmentPill.pillKey), findsOneWidget);
        expect(find.text('عام'), findsOneWidget);
        await _openSheet(tester);
        await tester.tap(
          find.byKey(WaTransferSheet.departmentKey(WaDepartment.payments)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(WaTransferSheet.agentKey('s4')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(WaTransferSheet.noteKey),
          '  دفع للوكيل ولم يصل  ',
        );
        await tester.ensureVisible(find.byKey(WaTransferSheet.confirmKey));
        await tester.tap(find.byKey(WaTransferSheet.confirmKey));
        await tester.pumpAndSettle();
        expect(repo.transfers, [
          (WaDepartment.payments, 's4', 'دفع للوكيل ولم يصل'),
        ]);
        expect(find.byType(WaTransferSheet), findsNothing);
        expect(find.text('حُوّلت المحادثة إلى رنا'), findsOneWidget);
        // The strip: the new assignee and the department.
        expect(find.text('مع رنا'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(WaWindowBanner),
            matching: find.text('الشحن والمدفوعات'),
          ),
          findsOneWidget,
        );
        await _end(tester);
      },
    );

    testWidgets('«أول متاح» with nobody on shift: the department queue', (
      tester,
    ) async {
      final repo = FakeWaRepository()
        ..afterTransfer = (d, to) => waConversation(department: d);
      await _pump(tester, const WaChatScreen(conversationId: 'c1'), repo);
      await _openSheet(tester);
      await tester.tap(
        find.byKey(WaTransferSheet.departmentKey(WaDepartment.technical)),
      );
      await tester.pumpAndSettle();
      expect(find.text('لا يوجد موظفون في هذا القسم بعد.'), findsOneWidget);
      await tester.ensureVisible(find.byKey(WaTransferSheet.confirmKey));
      await tester.tap(find.byKey(WaTransferSheet.confirmKey));
      await tester.pumpAndSettle();
      expect(repo.transfers, [(WaDepartment.technical, null, null)]);
      expect(
        find.text('حُوّلت المحادثة إلى قائمة المشاكل التقنية'),
        findsOneWidget,
      );
      expect(find.text('قائمة المشاكل التقنية'), findsOneWidget);
      await _end(tester);
    });
  });

  group('the inbox', () {
    testWidgets('department chips on rows and a department filter', (
      tester,
    ) async {
      final repo = FakeWaRepository(
        list: [
          waConversation(),
          waConversation(
            id: 'c2',
            name: 'Omar',
            department: WaDepartment.payments,
          ),
        ],
      );
      await _pump(tester, const WaInboxScreen(), repo);
      expect(find.byKey(WaInboxScreen.departmentsKey), findsOneWidget);
      expect(
        tester
            .widget<KChip>(find.byKey(WaInboxScreen.departmentChip(null)))
            .selected,
        isTrue,
      );
      expect(repo.departments.last, isNull);
      // Each row carries its department; an unassigned non-GENERAL one
      // reads as that department's queue.
      final row2 = find.byKey(WaInboxScreen.row('c2'));
      expect(
        find.descendant(of: row2, matching: find.text('الشحن والمدفوعات')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row2,
          matching: find.text('قائمة الشحن والمدفوعات'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(WaInboxScreen.row('c1')),
          matching: find.text('عام'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(WaInboxScreen.departmentChip(WaDepartment.payments)),
      );
      await tester.pumpAndSettle();
      expect(repo.departments.last, WaDepartment.payments);
      expect(find.byKey(WaInboxScreen.row('c1')), findsNothing);
      expect(find.byKey(WaInboxScreen.row('c2')), findsOneWidget);
      await _end(tester);
    });
  });

  group('the wire', () {
    test('an older server: no department → GENERAL, agents GENERAL', () {
      final c = WaConversation.fromJson({
        'id': 'c1',
        'phone': '+966500001001',
        'status': 'OPEN',
        'window': {'open': true},
      });
      expect(c.department, WaDepartment.general);
      expect(
        WaConversation.fromJson({
          'id': 'c1',
          'phone': '+966500001001',
          'status': 'OPEN',
          'department': 'REPORTS',
        }).department,
        WaDepartment.reports,
      );
      expect(WaDepartment.fromWire('SALES'), WaDepartment.general);
      final a = WaAgent.fromJson({'userId': 'u', 'onShift': true});
      expect(a.departments, [WaDepartment.general]);
      expect(a.openCount, 0);
      final b = WaAgent.fromJson({
        'userId': 'u',
        'onShift': false,
        'departments': ['PAYMENTS', 'TECHNICAL'],
        'openCount': 4,
      });
      expect(b.departments, [WaDepartment.payments, WaDepartment.technical]);
      expect(b.openCount, 4);
    });

    test('transfer, agents and the list send the D366 fields', () async {
      final http = FakeHttpAdapter();
      final prefs = await testPrefs(language: 'ar');
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: 'http://test', appVersion: '1.2.3'),
          ),
          httpClientAdapterProvider.overrideWithValue(http),
          secureTokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      await container
          .read(tokenManagerProvider)
          .saveTokens(AuthTokens.fromJson(tokenPairJson(accessToken: 'acc')));
      const base = '/api/v1/staff/whatsapp';
      final conv = {
        'id': 'c1',
        'phone': '+966500001001',
        'status': 'OPEN',
        'department': 'PAYMENTS',
        'window': {'open': true},
      };
      http
        ..on(
          'POST',
          '$base/conversations/c1/transfer',
          (_) => FakeResponse(200, body: conv),
        )
        ..on(
          'GET',
          '$base/agents',
          (_) => const FakeResponse(200, body: {'data': <Object>[]}),
        )
        ..on(
          'GET',
          '$base/conversations',
          (_) => FakeResponse(
            200,
            body: {
              'data': [conv],
              'page': {'nextCursor': null, 'hasMore': false},
            },
          ),
        );
      final repo = container.read(waRepositoryProvider);
      final out = await repo.transfer(
        'c1',
        department: WaDepartment.payments,
        toUserId: 'u2',
        note: '  ملاحظة ',
      );
      expect(out.department, WaDepartment.payments);
      await repo.transfer('c1', department: WaDepartment.reports, note: '  ');
      final sent = http.requestsTo('POST', '$base/conversations/c1/transfer');
      expect(sent[0].data, {
        'department': 'PAYMENTS',
        'toUserId': 'u2',
        'note': 'ملاحظة',
      });
      expect(sent[1].data, {'department': 'REPORTS'});
      await repo.agents(department: WaDepartment.technical);
      await repo.agents();
      final agents = http.requestsTo('GET', '$base/agents');
      expect(agents[0].queryParameters, {'department': 'TECHNICAL'});
      expect(agents[1].queryParameters, isEmpty);
      await repo.conversations(
        WaFilter.unassigned,
        department: WaDepartment.payments,
      );
      expect(
        http.requestsTo('GET', '$base/conversations').single.queryParameters,
        containsPair('department', 'PAYMENTS'),
      );
      container.dispose();
    });
  });
}
