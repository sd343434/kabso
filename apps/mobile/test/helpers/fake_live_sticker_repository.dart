// In-memory live stickers (D154h, tests only): `set` answers as the server
// does (new stickers get an id) and records the lists.

import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/live/data/live_sticker_repository.dart';
import 'package:kabso_live/features/live/domain/live_sticker.dart';

class FakeLiveStickerRepository implements LiveStickerRepository {
  new({Map<String, List<LiveSticker>>? stickers, List<String>? art})
    : stickers = stickers ?? {},
      art = art ?? const ['kabi_hi', 'kabi_love', 'kabi_fire', 'acme_unknown'];

  final Map<String, List<LiveSticker>> stickers;
  final List<String> art;
  AppFailure? failure;
  final saved = <List<LiveSticker>>[];
  var _next = 0;

  @override
  Future<List<String>> catalogue() async => art;

  @override
  Future<LiveStickers> get(String roomId) async {
    if (failure case final f?) throw f;
    return LiveStickers(roomId: roomId, items: stickers[roomId] ?? const []);
  }

  @override
  Future<LiveStickers> set(String roomId, List<LiveSticker> items) async {
    if (failure case final f?) throw f;
    saved.add(items);
    final list = [
      for (final s in items)
        if (s.id == LiveSticker.newId)
          LiveSticker(
            id: 'sticker-${_next++}',
            artKey: s.artKey,
            text: s.text,
            x: s.x,
            y: s.y,
            scale: s.scale,
            rotation: s.rotation,
          )
        else
          s,
    ];
    stickers[roomId] = list;
    return LiveStickers(roomId: roomId, items: list);
  }
}
