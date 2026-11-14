import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_room_swipe.dart';
import 'package:material_ui/material_ui.dart';

/// D124: inside a live room opened from the hub grid, a quick vertical
/// swipe opens the next room of the same list (swipe up) or the previous
/// one (swipe down), replacing this room (it is left as on Back). The
/// list is the hub tab's rooms when the card was tapped
/// ([liveRoomSwipeListProvider]); at either end nothing happens.
///
/// Off (the room as is) when the room is not in the list, and in the
/// caller's own live (a host never swipes away from it). Scrollable parts of
/// the room (the chat) keep their own vertical drags: they win the gesture
/// where they are.
class LiveRoomSwipe extends ConsumerWidget {
  const new({required this.roomId, required this.child, super.key});

  final String roomId;
  final Widget child;

  /// A fling at least this fast (logical px / s) changes the room.
  static const minVelocity = 700.0;

  static const swipeKey = Key('liveRoom.swipe');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(liveRoomSwipeListProvider);
    final me = ref.watch(currentUserProvider.select((u) => u?.id));
    final index = rooms.indexWhere((r) => r.roomId == roomId);
    if (index < 0 || rooms.length < 2) return child;
    if (me != null && rooms[index].hostId == me) return child;
    void open(int i) {
      if (i < 0 || i >= rooms.length) return;
      context.pushReplacement(AppRoutes.liveRoom(rooms[i].roomId));
    }

    return GestureDetector(
      key: swipeKey,
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v <= -minVelocity) open(index + 1);
        if (v >= minVelocity) open(index - 1);
      },
      child: child,
    );
  }
}
