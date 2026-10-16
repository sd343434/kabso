import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;
import 'package:kabso_live/features/live/data/live_repository.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';

/// One live room from `GET /live/rooms/{roomId}` (v1.3.1), including ended
/// rooms: a stale LIVE room comes back as ENDED / HEARTBEAT_TIMEOUT
/// (§10.2), and a missing room or inactive host fails with `NOT_FOUND`.
///
/// Errors are `AppFailure`s. "Try again" invalidates the provider, which
/// re-requests the room. Disposed when the room screen closes.
final FutureProviderFamily<LiveRoom, String> liveRoomProvider = FutureProvider
    .autoDispose
    .family<LiveRoom, String>(
      (ref, roomId) => ref.watch(liveRepositoryProvider).getRoom(roomId),
    );
