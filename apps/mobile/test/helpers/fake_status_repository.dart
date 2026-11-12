import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/status/status_repository.dart';

/// D376: an in-memory «الحالة» API for widget tests and goldens.
class FakeStatusRepository implements StatusRepository {
  new({required this.list, this.buyFailure});

  StatusPackList list;

  /// What `buy` throws (e.g. `INSUFFICIENT_COINS`), or null to succeed.
  AppFailure? buyFailure;

  final List<({String packId, int days, int price, String key})> bought = [];
  final List<String?> saved = [];

  @override
  Future<StatusPackList> packs() async => list;

  @override
  Future<StatusPackPurchase> buy({
    required String packId,
    required int days,
    required int priceCoins,
    required String idempotencyKey,
  }) async {
    final failure = buyFailure;
    if (failure != null) throw failure;
    bought.add((
      packId: packId,
      days: days,
      price: priceCoins,
      key: idempotencyKey,
    ));
    final now = DateTime.now().toUtc();
    final held = list.pack(packId)?.expiresAt;
    final from = held != null && held.isAfter(now) ? held : now;
    final until = from.add(Duration(days: days));
    list = StatusPackList(
      packs: [
        for (final p in list.packs)
          if (p.id == packId)
            StatusPackOffer(
              id: p.id,
              emojiIds: p.emojiIds,
              options: p.options,
              expiresAt: until,
            )
          else
            p,
      ],
      coins: list.coins - priceCoins,
    );
    return StatusPackPurchase(
      packId: packId,
      expiresAt: until,
      extended: held != null && held.isAfter(now),
      coins: list.coins,
    );
  }

  @override
  Future<User> setStatus(String? statusEmojiId) async {
    saved.add(statusEmojiId);
    throw UnimplementedError('the picker tests save through the sheet');
  }
}
