// D360 (CONVENTIONS §10.155): the WhatsApp level per staff member on the
// phone — the level from `StaffStatus.capabilities` (an older server: reply),
// and VIEW «مشاهدة فقط»: the chat with the label instead of the actions menu,
// no composer (the note instead), never a read receipt, and the customer
// details without link / unlink / note; REPLY keeps D355's chat.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/features/whatsapp/application/wa_providers.dart';
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
import 'package:kabso_live/features/whatsapp/presentation/wa_screens.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_whatsapp.dart';
import '../../helpers/pump_app.dart';

/// A staff status with these capabilities (the rest as for any staff member).
StaffStatus d360Status(List<String> capabilities) => StaffStatus(
  isStaff: true,
  roles: const ['SUPPORT'],
  capabilities: capabilities,
  authenticatorEnrolled: true,
  onShift: false,
);

const List<String> d360View = [WaCapability.view];
const List<String> d360Reply = [WaCapability.view, WaCapability.reply];

class FixedStaffStatus extends StaffStatusController {
  new(this.status);

  final StaffStatus status;

  @override
  Future<StaffStatus> build() async => status;
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen,
  FakeWaRepository repo,
  List<String> capabilities, {
  AppLanguage language = AppLanguage.ar,
}) async {
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

void main() {
  test('the level from the capabilities; a server before D360 reads reply', () {
    expect(waAccessOf(d360Status(const [])), WaAccess.none);
    expect(waAccessOf(d360Status(d360View)), WaAccess.view);
    expect(waAccessOf(d360Status(d360Reply)), WaAccess.reply);
    expect(
      waAccessOf(
        d360Status(const [
          WaCapability.view,
          WaCapability.reply,
          WaCapability.manage,
        ]),
      ),
      WaAccess.reply,
    );
    // D355's server: `support.whatsapp` without `.view`.
    expect(waAccessOf(d360Status(const [WaCapability.reply])), WaAccess.reply);
  });

  testWidgets(
    'VIEW: «مشاهدة فقط», no actions menu, no composer, never marks read',
    (tester) async {
      final repo = FakeWaRepository();
      await _pump(
        tester,
        const WaChatScreen(conversationId: 'c1'),
        repo,
        d360View,
      );
      expect(find.text('السلام عليكم'), findsOneWidget);
      expect(find.byKey(WaViewOnlyLabel.labelKey), findsOneWidget);
      expect(find.text('مشاهدة فقط'), findsOneWidget);
      expect(find.byKey(WaChatScreen.menuKey), findsNothing);
      expect(find.byKey(WaChatScreen.composerKey), findsNothing);
      expect(find.byKey(WaChatScreen.sendKey), findsNothing);
      expect(find.byKey(WaChatBody.viewOnlyKey), findsOneWidget);
      expect(find.textContaining('لا يمكنك الرد'), findsOneWidget);
      expect(repo.reads, 0);
      // The customer details read only.
      await tester.tap(find.byKey(WaChatScreen.detailsKey));
      await tester.pumpAndSettle();
      expect(find.text('ربط بحساب'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await _end(tester);
    },
  );

  testWidgets('VIEW on a closed conversation: no «إعادة فتح»', (tester) async {
    final repo = FakeWaRepository(
      conversation: waConversation(open: false, unread: 0),
    );
    await _pump(
      tester,
      const WaChatScreen(conversationId: 'c1'),
      repo,
      d360View,
      language: AppLanguage.en,
    );
    expect(find.text('Reopen'), findsNothing);
    expect(find.text('View only'), findsOneWidget);
    expect(repo.actions, isEmpty);
    await _end(tester);
  });

  testWidgets('REPLY: the D355 chat — the menu, the composer, marks read', (
    tester,
  ) async {
    final repo = FakeWaRepository();
    await _pump(
      tester,
      const WaChatScreen(conversationId: 'c1'),
      repo,
      d360Reply,
    );
    expect(find.byKey(WaViewOnlyLabel.labelKey), findsNothing);
    expect(find.byKey(WaChatScreen.menuKey), findsOneWidget);
    expect(find.byKey(WaChatScreen.composerKey), findsOneWidget);
    expect(find.byKey(WaChatBody.viewOnlyKey), findsNothing);
    expect(repo.reads, 1);
    await tester.tap(find.byKey(WaChatScreen.detailsKey));
    await tester.pumpAndSettle();
    expect(find.text('ربط بحساب'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    await _end(tester);
  });
}
