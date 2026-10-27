// CP-020 payloads shaped exactly like docs/contracts/openapi.yaml
// v1.23-live (tag `gifts`, `sendLiveGift`; the examples where given;
// `Gift.tag` v1.24.3-live, D117). Test
// data only: production starts with an empty catalogue.

/// The test catalogue's gifts, by tab, in catalogue order.
const giftFixtureCodes = [
  'rose',
  'heart_balloon',
  'crown',
  'sports_car',
  'lantern',
  'cake',
  'confetti',
  'kabi_dance',
];

const _gifts = <String, (String, int, String, String?, String, String)>{
  // code: (category, price, badge, animationKey, ar, en)
  'rose': ('POPULAR', 1, 'NONE', null, 'وردة', 'Rose'),
  'heart_balloon': ('POPULAR', 10, 'NEW', null, 'بالون قلب', 'Heart balloon'),
  'crown': ('POPULAR', 299, 'NONE', null, 'تاج', 'Crown'),
  'sports_car': (
    'POPULAR',
    5000,
    'NEW',
    'fx_sports_car',
    'سيارة رياضية',
    'Sports car',
  ),
  'lantern': ('EVENT', 99, 'EVENT', null, 'فانوس', 'Lantern'),
  'cake': ('EVENT', 520, 'EVENT', null, 'كعكة', 'Cake'),
  'confetti': ('FUN', 5, 'NONE', null, 'قصاصات ملونة', 'Confetti'),
  'kabi_dance': ('FUN', 66, 'NEW', null, 'رقصة كابي', 'Kabi dance'),
  // v1.27-live (D132): a lucky gift (not in [giftFixtureCodes]; tests that
  // need it list it and the LUCKY tab).
  'lucky_clover': ('LUCKY', 10, 'NONE', null, 'برسيم الحظ', 'Lucky clover'),
};

/// The test sub-categories (D117): only POPULAR gifts carry one, so the
/// other tabs show no chip row. code: (tagCode, ar, en).
const _tags = <String, (String, String, String)>{
  'rose': ('love', 'حب', 'Love'),
  'heart_balloon': ('love', 'حب', 'Love'),
  'crown': ('luxury', 'فخامة', 'Luxury'),
  'sports_car': ('luxury', 'فخامة', 'Luxury'),
};

/// The name of [code] as the server sends it.
String giftFixtureName(String code, {bool ar = true}) {
  final g = _gifts[code];
  if (g == null) return code;
  return ar ? g.$5 : g.$6;
}

/// The price of [code] in coins.
int giftFixturePrice(String code) => _gifts[code]!.$2;

/// `Gift`.
Map<String, Object?> giftJson(String code, {bool ar = true}) {
  final g = _gifts[code]!;
  return {
    'code': code,
    'category': g.$1,
    'name': ar ? g.$5 : g.$6,
    'priceCoins': g.$2,
    'assetKey': 'gift_$code',
    'animationKey': g.$4,
    'sortOrder': (giftFixtureCodes.indexOf(code) + 1) * 10,
    'badge': g.$3,
    'tag': switch (_tags[code]) {
      final t? => {'code': t.$1, 'name': ar ? t.$2 : t.$3},
      null => null,
    },
    // v1.26.2-live (D126): no hosted art in the test catalogue.
    'imageUrl': null,
    'animationUrl': null,
    'animationBytes': null,
  };
}

/// `GiftCatalogue`: [codes] (default: every test gift).
Map<String, Object?> giftCatalogueJson({
  List<String> codes = giftFixtureCodes,
  bool ar = true,
  String version = '3f2a9c0d81b4e6a7',
  List<int> quantities = const [1, 10, 66, 99, 188, 520, 1314],
  List<String> categories = const ['POPULAR', 'EVENT', 'FUN'],
  List<Map<String, Object?>> extra = const [],
}) => {
  'version': version,
  'categories': categories,
  'quantities': quantities,
  'maxRecipients': 25,
  'comboWindowSeconds': 5,
  'data': [for (final c in codes) giftJson(c, ar: ar), ...extra],
};

/// `GiftBagItem`.
Map<String, Object?> giftBagItemJson(
  String code,
  int quantity, {
  bool ar = true,
}) => {...giftJson(code, ar: ar), 'quantity': quantity};

/// `UserSummary` of a person in a gift.
Map<String, Object?> giftUserJson(String username, String displayName) => {
  'id': 'user-$username',
  'username': username,
  'displayName': displayName,
  'avatarUrl': null,
};

/// `LiveGift` (the contract's example by default).
Map<String, Object?> liveGiftJson({
  String id = '0192f1d0-4444-7000-8000-000000000015',
  String roomId = 'room-0',
  String code = 'rose',
  int quantity = 10,
  String source = 'COINS',
  Map<String, Object?>? sender,
  List<Map<String, Object?>>? recipients,
  String? comboId,
  int comboCount = 1,
  Map<String, Object?> art = const {},
}) {
  final to =
      recipients ?? [giftUserJson('sara', 'سارة'), giftUserJson('omar', 'عمر')];
  final unit = _gifts[code]?.$2 ?? 1;
  return {
    'id': id,
    'roomId': roomId,
    'giftCode': code,
    'assetKey': 'gift_$code',
    'animationKey': _gifts[code]?.$4,
    'unitPrice': unit,
    'quantity': quantity,
    'source': source,
    'totalCoins': unit * quantity * to.length,
    'sender': sender ?? giftUserJson('lina', 'لينا'),
    'recipients': to,
    'combo': {
      'id': comboId ?? id,
      'count': comboCount,
      'quantity': quantity * comboCount,
    },
    'createdAt': '2026-10-26T18:30:00.000Z',
    // v1.26.2-live (D126): the hosted art (none unless given).
    'imageUrl': null,
    'animationUrl': null,
    'animationBytes': null,
    ...art,
  };
}

/// `LiveGiftResult`.
Map<String, Object?> liveGiftResultJson({
  required Map<String, Object?> gift,
  int coins = 80,
  int bagQuantity = 0,
  Map<String, Object?>? luckyResult,
}) => {
  'gift': gift,
  'coins': coins,
  'bagQuantity': bagQuantity,
  'luckyResult': ?luckyResult,
};

/// `LuckyGiftOdds` (the contract's example; [reason] null = eligible).
Map<String, Object?> luckyOddsJson({
  bool enabled = true,
  String? reason,
  bool ageConfirmed = true,
  bool guest = false,
}) => {
  'enabled': enabled,
  'drawsPerGift': 1,
  'returnPercent': 85,
  'hostSharePercent': 10,
  'outcomes': [
    {'multiplier': 5, 'chancePerMillion': 68000, 'probability': 0.068},
    {'multiplier': 10, 'chancePerMillion': 21250, 'probability': 0.02125},
    {'multiplier': 50, 'chancePerMillion': 2550, 'probability': 0.00255},
    {'multiplier': 100, 'chancePerMillion': 850, 'probability': 0.00085},
    {'multiplier': 500, 'chancePerMillion': 34, 'probability': 0.000034},
  ],
  'noWinChancePerMillion': 907316,
  'noWinProbability': 0.907316,
  'bigWinMultiplier': 100,
  'dailyProtection': true,
  'dayTimeZone': 'Asia/Riyadh',
  'minimumAge': 18,
  'caller': guest
      ? null
      : {
          'eligible': reason == null && enabled,
          'reason': reason ?? (enabled ? null : 'DISABLED'),
          'ageConfirmed': ageConfirmed,
        },
};
