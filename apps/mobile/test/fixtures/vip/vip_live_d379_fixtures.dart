// D379 (v1.132-social, CONVENTIONS §10.169): the VIP perks inside live rooms
// — the test data (shaped like openapi.yaml) and the stand-in art (drawn for
// these tests; never the owner's art).

import 'dart:io';
import 'dart:typed_data';

import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/features/live/domain/live_vip.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';

final DateTime d379Now = DateTime.utc(2026, 11, 12, 9, 30);

const d379CrownUrl = 'https://cdn.k.test/vip/d379_crown.png';
const d379CoinUrl = 'https://cdn.k.test/vip/d379_coin.png';
const d379EmojiUrl = 'https://cdn.k.test/vip/d379_emoji.png';

final Uint8List d379CrownBytes = File(
  'test/fixtures/vip/d379_crown_standin.png',
).readAsBytesSync();
final Uint8List d379CoinBytes = File('test/fixtures/vip/d379_coin_standin.png')
    .readAsBytesSync();
final Uint8List d379EmojiBytes = File(
  'test/fixtures/vip/d379_emoji_standin.png',
).readAsBytesSync();

/// The stand-in art for a URL of these fixtures.
Uint8List d379ArtFor(String src) => switch (src) {
  d379CrownUrl => d379CrownBytes,
  d379CoinUrl => d379CoinBytes,
  _ => d379EmojiBytes,
};

const d379Vip1 = UserVip(tier: 'VIP_1', rank: 1, color: 0xFF2E8B3D);
const d379Vip2 = UserVip(tier: 'VIP_2', rank: 2, color: 0xFF1E6FD9);

/// VIP 1 holds every D379 perk (the art and values); VIP 2 inherits them.
const d379Catalog = VipTierList(
  maxAheadDays: 400,
  tiers: [
    VipTier(
      id: 'id-VIP_1',
      code: 'VIP_1',
      name: 'VIP 1',
      level: 1,
      color: 0xFF2E8B3D,
      priceCoins: 1000000,
      durationDays: 30,
      perks: [
        VipPerk(
          code: VipLivePerks.seatCrown,
          title: 'crown',
          available: true,
          still: d379CrownUrl,
          artWidth: 300,
          artHeight: 200,
        ),
        VipPerk(
          code: VipLivePerks.seatEmoji,
          title: 'emoji',
          available: true,
          value: [d379EmojiUrl, d379EmojiUrl],
        ),
        VipPerk(
          code: VipLivePerks.pinnedMessage,
          title: 'pin',
          available: true,
          value: {'count': 3, 'seconds': 30},
        ),
        VipPerk(
          code: VipLivePerks.vipRoom,
          title: 'room',
          available: true,
          value: 'VIP_2',
        ),
        VipPerk(
          code: VipLivePerks.seatReserve,
          title: 'reserve',
          available: true,
          value: 10,
        ),
      ],
    ),
    VipTier(
      id: 'id-VIP_2',
      code: 'VIP_2',
      name: 'VIP 2',
      level: 2,
      color: 0xFF1E6FD9,
      priceCoins: 2000000,
      durationDays: 30,
      perks: [VipPerk(code: VipPerks.badge, title: 'badge', available: true)],
    ),
  ],
);

/// The caller's own effective perks (a VIP 2 member: VIP 1's inherited).
final Map<String, VipPerk> d379MyPerks = {
  for (final p in d379Catalog.tiers.first.perks) p.code: p,
};

UserSummary d379User(String id, String name, {UserVip? vip}) => UserSummary(
  id: id,
  username: id,
  displayName: name,
  avatarUrl: null,
  vip: vip,
);

Map<String, Object?> d379UserJson(String id, String name) => {
  'id': id,
  'username': id,
  'displayName': name,
  'avatarUrl': null,
};

Map<String, Object?> d379PinJson({
  String id = 'pin-1',
  String room = 'room-a',
  String message = 'm-1',
  String text = 'أهلاً بالجميع',
}) => {
  'id': id,
  'roomId': room,
  'messageId': message,
  'author': d379UserJson('u-sara', 'Sara'),
  'text': text,
  'pinnedAt': '2026-11-12T09:30:00.000Z',
  'until': '2026-11-12T09:30:30.000Z',
};

Map<String, Object?> d379RainJson({String gift = 'g-1', String? still}) => {
  'giftId': gift,
  'roomId': 'room-a',
  'sender': d379UserJson('u-sara', 'Sara'),
  'totalCoins': 5000,
  'animation': null,
  'still': still,
  'video': null,
  'artWidth': null,
  'artHeight': null,
  'durationMs': 4000,
  'createdAt': '2026-11-12T09:30:00.000Z',
};
