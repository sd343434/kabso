import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';

/// D280 (owner's device: «تصغير البث والعودة الى حجمه الطبيعي تعاد تشغيل
/// سيارة الدخول»): the VIP entrances already played in each room, for the
/// whole visit — not the screen's. Minimizing the live disposes the room's
/// screen (and its entrance layer and chat); opening it again builds them
/// anew, and the layer used to play the host's own entrance (D265) again.
///
/// Kept while the app runs; [forget] ends a room's visit (the viewer left
/// it), so the next visit plays its entrances again. A host's go-live is a
/// new room each time.
class VipEntrancePlays {
  /// The same person's entrance again within this time plays nothing (their
  /// media reconnecting, e.g. their minimized live opened again, announces
  /// them a second time).
  static const rejoinQuiet = Duration(seconds: 60);

  final _self = <String>{};
  final _lastJoin = <String, LiveChatJoinLine>{};
  final _lastStaffJoin = <String, LiveChatJoinLine>{};

  /// D283: like [takeJoin], for the room's newest Kabso Team entry.
  bool takeStaffJoin(String roomId, LiveChatJoinLine line) {
    if (identical(_lastStaffJoin[roomId], line)) return false;
    _lastStaffJoin[roomId] = line;
    return true;
  }

  final _users = <String, Map<String, DateTime>>{};

  /// Whether the host's own entrance in [roomId] may play now (once per
  /// room: the first call says yes).
  bool takeSelf(String roomId) => _self.add(roomId);

  /// Whether [line] (the room chat's newest join) is new to [roomId]'s
  /// entrances; it is handled from now on. The chat keeps its newest join,
  /// so a layer built again sees the same line, never a new one.
  bool takeJoin(String roomId, LiveChatJoinLine line) {
    if (identical(_lastJoin[roomId], line)) return false;
    _lastJoin[roomId] = line;
    return true;
  }

  /// Whether [userId]'s entrance may play in [roomId] now: not when it
  /// played less than [rejoinQuiet] ago.
  bool takeUser(String roomId, String userId) {
    final now = clock.now();
    final users = _users.putIfAbsent(roomId, () => {});
    final last = users[userId];
    if (last != null && now.difference(last) < rejoinQuiet) return false;
    users[userId] = now;
    return true;
  }

  /// The visit to [roomId] ended (the viewer left the room).
  void forget(String roomId) {
    _self.remove(roomId);
    _lastJoin.remove(roomId);
    _lastStaffJoin.remove(roomId);
    _users.remove(roomId);
  }
}

final Provider<VipEntrancePlays> vipEntrancePlaysProvider =
    Provider<VipEntrancePlays>((ref) => VipEntrancePlays());
