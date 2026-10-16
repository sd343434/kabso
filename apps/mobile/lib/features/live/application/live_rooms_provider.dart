import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/core/state/feed_load.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';

/// Live rooms for one Live hub tab.
///
/// There is no live list API yet (Phase 6) and contracts are frozen for the
/// design sprint (D34/D35), so production returns [FeedUnavailable] for
/// every tab — never sample rooms. Tests and the debug gallery supply
/// fixtures by overriding this provider (or by rendering `LiveHubBody`
/// directly).
final FutureProviderFamily<FeedLoad<LiveRoomCardData>, FeedTab>
liveRoomsProvider = FutureProvider.family(
  (ref, tab) => const FeedUnavailable<LiveRoomCardData>(),
);
