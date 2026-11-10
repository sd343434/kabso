import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/features/whatsapp/data/wa_repository.dart';
import 'package:kabso_live/features/whatsapp/domain/wa_models.dart';

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
