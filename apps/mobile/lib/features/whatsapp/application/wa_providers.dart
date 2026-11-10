import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart';

/// v1.120-social (D360, §10.155): the three WhatsApp capabilities in
/// `StaffStatus.capabilities` — the staff member's WhatsApp level.
abstract final class WaCapability {
  static const view = 'support.whatsapp.view';
  static const reply = 'support.whatsapp';
  static const manage = 'support.whatsapp.manage';
}

/// D360: what the caller may do in «واتساب» — nothing (NONE: no row), read
/// only (VIEW: «مشاهدة فقط», no composer or actions) or answer (REPLY and
/// MANAGE). A server before D360 sends only `support.whatsapp`: answer.
enum WaAccess { none, view, reply }

WaAccess waAccessOf(StaffStatus s) {
  if (s.can(WaCapability.reply)) return WaAccess.reply;
  if (s.can(WaCapability.view)) return WaAccess.view;
  return WaAccess.none;
}

/// D360: the caller's [WaAccess]; null while the staff status is unknown
/// (loading or failed — the screens then keep the D355 behaviour and the
/// server still refuses what the level does not allow).
final Provider<WaAccess?> waAccessProvider = Provider<WaAccess?>((ref) {
  final s = ref.watch(staffStatusProvider).value;
  return s == null ? null : waAccessOf(s);
});

/// D360: the caller reads only (the WhatsApp level VIEW).
final Provider<bool> waViewOnlyProvider = Provider<bool>(
  (ref) => ref.watch(waAccessProvider) == WaAccess.view,
);

/// v1.116-social (D355, §10.151.5): the «واتساب» row's badge — my and the
/// unassigned open conversations with unread messages. Read when the Me tab
/// shows the row, every [refreshEvery] while it is on screen, after an
/// action and when a `whatsapp` push arrives. An error reads as the last
/// value (or off): never a flicker, never an error on the Me tab.
class WaSummaryController extends AsyncNotifier<WaSummary> {
  static const refreshEvery = Duration(seconds: 60);

  Timer? _timer;

  @override
  Future<WaSummary> build() {
    _timer?.cancel();
    _timer = Timer.periodic(refreshEvery, (_) => unawaited(refresh()));
    ref.onDispose(() => _timer?.cancel());
    return ref.watch(waRepositoryProvider).summary();
  }

  Future<void> refresh() async {
    final next = await AsyncValue.guard(ref.read(waRepositoryProvider).summary);
    if (next.hasValue || !state.hasValue) state = next;
  }
}

final AsyncNotifierProvider<WaSummaryController, WaSummary> waSummaryProvider =
    AsyncNotifierProvider.autoDispose<WaSummaryController, WaSummary>(
      WaSummaryController.new,
    );

/// One tab of the inbox (with the search text).
typedef WaListKey = ({WaFilter filter, String q});

final FutureProviderFamily<List<WaConversation>, WaListKey>
waConversationsProvider = FutureProvider.autoDispose
    .family<List<WaConversation>, WaListKey>(
      (ref, key) =>
          ref.watch(waRepositoryProvider).conversations(key.filter, q: key.q),
    );

/// The open conversation: the conversation, its messages and notes.
final FutureProviderFamily<WaThread, String> waThreadProvider = FutureProvider
    .autoDispose
    .family<WaThread, String>((ref, id) async {
      final repo = ref.watch(waRepositoryProvider);
      final results = await Future.wait<Object>([
        repo.conversation(id),
        repo.messages(id),
        repo.notes(id),
      ]);
      return WaThread(
        conversation: results[0] as WaConversation,
        messages: results[1] as List<WaMessage>,
        notes: results[2] as List<WaNote>,
      );
    });

/// The bytes of a stored media file (kept while the bubble is on screen).
final FutureProviderFamily<List<int>, String> waMediaProvider = FutureProvider
    .autoDispose
    .family<List<int>, String>(
      (ref, messageId) => ref.watch(waRepositoryProvider).media(messageId),
    );
