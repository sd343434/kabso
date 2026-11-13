import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/features/live/data/live_media_engine.dart';
import 'package:kabso_live/features/live/data/live_sticker_repository.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/domain/live_sticker.dart';

/// D154h («ملصقات», CONVENTIONS §10.38): the stickers on one live. Loaded
/// when the room attaches (late joiners see them), replaced by the server's
/// `stickers` messages; on the host's phone [preview] moves them while a
/// finger is down and [save] sends the whole list (`PUT …/stickers`),
/// going back to the last saved list when it fails.
class LiveStickersController extends Notifier<List<LiveSticker>> {
  new(this.roomId);

  final String roomId;

  StreamSubscription<LiveChatEvent>? _events;
  List<LiveSticker> _saved = const [];
  int _saving = 0;

  @override
  List<LiveSticker> build() {
    ref.onDispose(() => unawaited(_events?.cancel()));
    return const [];
  }

  /// Loads the stickers and follows the [engine]'s sticker messages (once).
  void attach(LiveMediaEngine engine) {
    if (_events != null) return;
    _events = engine.chatEvents.listen((event) {
      if (event is LiveStickersChanged) _apply(event.stickers);
    });
    unawaited(load());
  }

  Future<void> load() async {
    try {
      _apply(await ref.read(liveStickerRepositoryProvider).get(roomId));
    } on Object {
      // None rather than wrong ones.
    }
  }

  void _apply(LiveStickers stickers) {
    if (!ref.mounted || stickers.roomId != roomId) return;
    _saved = stickers.items;
    // The host's own change is on its way: keep what the finger did.
    if (_saving == 0) state = stickers.items;
  }

  /// The host's gesture in progress (this phone only).
  void preview(List<LiveSticker> items) {
    if (ref.mounted) state = items;
  }

  /// Sends [items] (the host); null when saved, else why (the stickers go
  /// back to the last saved ones).
  Future<AppFailure?> save(List<LiveSticker> items) async {
    if (!ref.mounted) return null;
    state = items;
    _saving++;
    try {
      final saved = await ref
          .read(liveStickerRepositoryProvider)
          .set(roomId, items);
      _saving--;
      if (ref.mounted) {
        _saved = saved.items;
        if (_saving == 0) state = saved.items;
      }
      return null;
    } on Object catch (e) {
      _saving--;
      if (ref.mounted && _saving == 0) state = _saved;
      return toAppFailure(e);
    }
  }
}

final NotifierProviderFamily<LiveStickersController, List<LiveSticker>, String>
liveStickersProvider =
    NotifierProvider.family<LiveStickersController, List<LiveSticker>, String>(
      LiveStickersController.new,
    );

/// The art keys a host may place (the server's catalogue).
final FutureProvider<List<String>> liveStickerArtProvider =
    FutureProvider<List<String>>(
      (ref) => ref.watch(liveStickerRepositoryProvider).catalogue(),
    );
