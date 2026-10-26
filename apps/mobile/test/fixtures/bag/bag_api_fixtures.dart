// CP-019 payloads shaped exactly like docs/contracts/openapi.yaml
// v1.22-live (tag `bag`; the examples where given).

/// The catalogue's four profile cards (the contract's example), Arabic or
/// English names.
const bagCatalogueCodes = [
  'bunny_royal',
  'kabi_royal',
  'golden_stags',
  'emerald_wings',
];

const _namesAr = {
  'bunny_royal': 'الأرنب الملكي',
  'kabi_royal': 'كابي الملكي',
  'golden_stags': 'الغزلان الذهبية',
  'emerald_wings': 'الأجنحة الزمردية',
};

const _namesEn = {
  'bunny_royal': 'Royal Bunny',
  'kabi_royal': 'Royal Kabi',
  'golden_stags': 'Golden Stags',
  'emerald_wings': 'Emerald Wings',
};

/// The name of [code] as the server sends it.
String bagItemName(String code, {bool ar = true}) =>
    (ar ? _namesAr : _namesEn)[code] ?? code;

/// `BagCatalogueItem`.
Map<String, Object?> bagCatalogueItemJson(
  String code, {
  String category = 'PROFILE_CARD',
  bool ar = true,
  int? sortOrder,
  bool? free,
}) => {
  'code': code,
  'category': category,
  'name': bagItemName(code, ar: ar),
  'assetKey': 'header_$code',
  'sortOrder': sortOrder ?? (bagCatalogueCodes.indexOf(code) + 1) * 10,
  'free': free ?? code == 'bunny_royal',
};

/// `BagItem`.
Map<String, Object?> bagItemJson(
  String code, {
  String category = 'PROFILE_CARD',
  bool ar = true,
  bool equipped = false,
  String source = 'ADMIN',
}) => {
  'code': code,
  'category': category,
  'name': bagItemName(code, ar: ar),
  'assetKey': 'header_$code',
  'acquiredAt': '2026-10-26T18:30:00.000Z',
  'source': source,
  'equipped': equipped,
};

/// `BagEquipped`: [code] worn, or nothing.
Map<String, Object?> bagEquippedJson(String? code, {bool ar = true}) => {
  'category': 'PROFILE_CARD',
  'equipped': code == null
      ? null
      : {
          'code': code,
          'name': bagItemName(code, ar: ar),
          'assetKey': 'header_$code',
        },
};
