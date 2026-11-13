// D385 (owner 2026-11-12: «نعم»): the unread «دعم كابسو» replies count in
// the Messages tab badge (`DmUnread.support`), and reading the thread clears
// them at once.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/messages/application/dm_providers.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/features/messages/unread_messages.dart';
import 'package:kabso_live/features/support/presentation/support_chat_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../helpers/fake_dm_repository.dart';
import '../../helpers/fake_support_repository.dart';
import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

class _SlowBackoff extends DmPollBackoff {
  @override
  Duration get next => const Duration(days: 1);
}

/// The fake server: reading the thread clears its replies from the badge.
class _ReadClears extends FakeSupportRepository {
  new(this.dm);

  final FakeDmRepository dm;

  @override
  Future<void> read() async {
    await super.read();
    dm.unreadCounts = const DmUnread();
  }
}

void main() {
  test('the badge adds the unread «دعم كابسو» replies (capped at 99)', () {
    final u = DmUnread.fromJson(const {
      'messages': 2,
      'conversations': 1,
      'requests': 4,
      'groups': 1,
      'support': 3,
    });
    expect(u.support, 3);
    expect(u.badge, 6);
    expect(const DmUnread(messages: 90, support: 20).badge, 99);
    // An older server (no `support`): as before.
    expect(DmUnread.fromJson(const {'messages': 1, 'groups': 0}).badge, 1);
  });

  testWidgets('reading the thread clears its replies from the badge', (
    tester,
  ) async {
    SupportChatScreen.newBackoff = _SlowBackoff.new;
    addTearDown(() => SupportChatScreen.newBackoff = DmPollBackoff.new);
    final dm = FakeDmRepository()..unreadCounts = const DmUnread(support: 1);
    final support = _ReadClears(dm)..reply('أهلًا');
    var open = false;
    late StateSetter setOpen;
    await pumpScreen(
      tester,
      Consumer(
        builder: (context, ref, _) => StatefulBuilder(
          builder: (context, set) {
            setOpen = set;
            return Column(
              children: [
                Text(
                  'badge ${ref.watch(unreadMessagesProvider)}',
                  key: const Key('badge'),
                ),
                if (open) const Expanded(child: SupportChatScreen()),
              ],
            );
          },
        ),
      ),
      dmRepository: dm,
      supportRepository: support,
      overrides: [currentUserProvider.overrideWithValue(testUser())],
    );
    await tester.pumpAndSettle();
    expect(find.text('badge 1'), findsOneWidget);
    setOpen(() => open = true);
    await tester.pumpAndSettle();
    expect(support.calls, contains('read'));
    expect(find.text('badge 0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
