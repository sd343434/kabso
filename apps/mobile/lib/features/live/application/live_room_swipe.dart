import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One room of the list a room was opened from (D124).
typedef LiveSwipeRoom = ({String roomId, String? hostId});

/// D124: the live hub tab's rooms, in order, as they were when a card was
/// tapped. Inside a room a vertical swipe opens the next or previous one
/// from this list (`LiveRoomSwipe`). Empty when the room was opened from
/// anywhere else (a link, a notification, a profile): no swipe then.
class LiveRoomSwipeList extends Notifier<List<LiveSwipeRoom>> {
  @override
  List<LiveSwipeRoom> build() => const [];

  void set(List<LiveSwipeRoom> rooms) => state = List.unmodifiable(rooms);
}

final NotifierProvider<LiveRoomSwipeList, List<LiveSwipeRoom>>
liveRoomSwipeListProvider = NotifierProvider(LiveRoomSwipeList.new);
