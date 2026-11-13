// D385 (CONVENTIONS §10.174): «دعم كابسو» — the person's in-app support
// chat. The first message of a new ticket needs a topic (one of the five
// departments); the person's message says «تم الاستلام» (then «تمت
// القراءة»); a reply shows the staff member's first name under the «فريق
// كابسو» badge and nothing of their account; a closed ticket asks for a new
// topic; the replies are marked read. No overflow at 360 / 393, ×1.0 / ×1.3.
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/support/domain/support_models.dart';
import 'package:kabso_live/features/support/presentation/support_chat_screen.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_support_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

/// No poll timers left behind: a backoff far in the future.
class _SlowBackoff extends DmPollBackoff {
  @override
  Duration get next => const Duration(days: 1);
}

Future<void> _pump(
  WidgetTester tester,
  FakeSupportRepository repo, {
  AppLanguage language = AppLanguage.ar,
  Size size = const Size(393, 852),
  double textScale = 1,
}) async {
  SupportChatScreen.newBackoff = _SlowBackoff.new;
  addTearDown(() => SupportChatScreen.newBackoff = DmPollBackoff.new);
  tester.view
    ..physicalSize = size * 3
    ..devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await pumpScreen(
    tester,
    const SupportChatScreen(),
    language: language,
    supportRepository: repo,
    overrides: [currentUserProvider.overrideWithValue(testUser())],
  );
  await tester.pumpAndSettle();
}

Future<void> _end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  final ar = l10nFor(AppLanguage.ar);
  final en = l10nFor(AppLanguage.en);

  testWidgets('a new ticket: the topic first, then «تم الاستلام»', (
    tester,
  ) async {
    final repo = FakeSupportRepository();
    await _pump(tester, repo);
    expect(find.byKey(SupportChatScreen.introKey), findsOneWidget);
    expect(find.text(ar.supportChatName), findsWidgets);
    expect(find.byType(KabsoTeamBadge), findsOneWidget);
    expect(find.byKey(SupportChatScreen.topicsKey), findsOneWidget);
    for (final d in WaDepartment.values) {
      expect(find.byKey(SupportChatScreen.topicKey(d)), findsOneWidget);
    }
    expect(find.text(ar.supportPickTopic), findsOneWidget);
    // Without a topic: asked for one, nothing sent.
    await tester.enterText(
      find.byKey(SupportChatScreen.composerKey),
      'لم يصلني الشحن',
    );
    await tester.pump();
    await tester.tap(find.byKey(SupportChatScreen.sendKey));
    await tester.pumpAndSettle();
    expect(find.text(ar.supportPickTopicFirst), findsOneWidget);
    expect(repo.calls.where((c) => c.startsWith('send')), isEmpty);
    // The message goes away (it covers the composer for a moment).
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    // With one: sent with it; the picker goes, the topic shows.
    await tester.tap(
      find.byKey(SupportChatScreen.topicKey(WaDepartment.payments)),
    );
    await tester.pump();
    await tester.tap(find.byKey(SupportChatScreen.sendKey));
    await tester.pumpAndSettle();
    expect(repo.calls, contains('send:PAYMENTS'));
    expect(repo.lastTopic, WaDepartment.payments);
    expect(find.byKey(SupportChatScreen.topicsKey), findsNothing);
    expect(find.byKey(SupportChatScreen.topicChipKey), findsOneWidget);
    expect(find.text(ar.supportTopicOf(ar.waDeptPAYMENTS)), findsOneWidget);
    expect(find.text('لم يصلني الشحن'), findsOneWidget);
    expect(find.byKey(SupportChatScreen.receiptKey), findsOneWidget);
    expect(find.text(ar.supportReceiptReceived), findsOneWidget);
    // The next message needs no topic.
    await tester.enterText(find.byKey(SupportChatScreen.composerKey), 'شكرا');
    await tester.pump();
    await tester.tap(find.byKey(SupportChatScreen.sendKey));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'send:-');
    await _end(tester);
  });

  testWidgets('a reply: the badge and the first name only; marked read', (
    tester,
  ) async {
    final repo = FakeSupportRepository(
      thread: const SupportThread(
        id: 't1',
        status: SupportThreadStatus.open,
        department: WaDepartment.technical,
      ),
      messages: [
        SupportMessage(
          id: 'm1',
          mine: true,
          kind: DmMessageKind.text,
          text: 'التطبيق يغلق وحده',
          receipt: SupportReceipt.read,
          createdAt: DateTime.utc(2026, 11, 12, 9),
        ),
      ],
    )..reply('نعتذر، جرّب التحديث الأخير', firstName: 'سارة');
    await _pump(tester, repo, language: AppLanguage.en);
    expect(find.byKey(SupportChatScreen.staffKey('r1')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(SupportChatScreen.staffKey('r1')),
        matching: find.byType(KabsoTeamBadge),
      ),
      findsOneWidget,
    );
    expect(find.text('سارة'), findsOneWidget);
    expect(find.text(en.supportReceiptRead), findsOneWidget);
    expect(find.byKey(SupportChatScreen.topicsKey), findsNothing);
    // The reply was unread: the screen marks it read.
    expect(repo.calls, contains('read'));
    await _end(tester);
  });

  testWidgets('a closed ticket asks for the topic of a new one', (
    tester,
  ) async {
    final repo = FakeSupportRepository(
      thread: const SupportThread(
        id: 't1',
        status: SupportThreadStatus.closed,
        department: WaDepartment.general,
      ),
      messages: [
        SupportMessage(
          id: 'm1',
          mine: true,
          kind: DmMessageKind.text,
          text: 'hello',
          receipt: SupportReceipt.read,
          createdAt: DateTime.utc(2026, 11, 12, 9),
        ),
      ],
    );
    await _pump(tester, repo);
    expect(find.text(ar.supportNewTicket), findsOneWidget);
    expect(find.byKey(SupportChatScreen.topicsKey), findsOneWidget);
    await _end(tester);
  });

  group('no overflow', () {
    for (final language in AppLanguage.values) {
      for (final size in const [Size(360, 800), Size(393, 852)]) {
        for (final scale in const [1.0, 1.3]) {
          testWidgets('${language.name} ${size.width.toInt()} ×$scale', (
            tester,
          ) async {
            final repo = FakeSupportRepository()
              ..reply('A long answer from the team about the top-up ' * 3);
            await _pump(
              tester,
              repo,
              language: language,
              size: size,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
            // The topic picker (a new ticket is not open in this fake).
            final fresh = FakeSupportRepository();
            await _end(tester);
            await _pump(
              tester,
              fresh,
              language: language,
              size: size,
              textScale: scale,
            );
            expect(find.byKey(SupportChatScreen.topicsKey), findsOneWidget);
            expect(tester.takeException(), isNull);
            await _end(tester);
          });
        }
      }
    }
  });
}
