import 'package:kabso_live/l10n/gen/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// v1.71-live (D283, CONVENTIONS §10.96.11): a staff region — a fixed group
/// of countries (the server's `staff-regions.ts`), in the catalogue's order.
enum StaffRegion {
  arabWorld('ARAB_WORLD'),
  greaterChina('GREATER_CHINA'),
  turkey('TURKEY'),
  iran('IRAN'),
  southAsia('SOUTH_ASIA'),
  southeastAsia('SOUTHEAST_ASIA'),
  eastAsia('EAST_ASIA'),
  europe('EUROPE'),
  northAmerica('NORTH_AMERICA'),
  latinAmerica('LATIN_AMERICA'),
  subSaharanAfrica('SUB_SAHARAN_AFRICA'),
  russiaCentralAsia('RUSSIA_CENTRAL_ASIA'),
  oceania('OCEANIA');

  new(this.wire);

  final String wire;

  static StaffRegion? fromWire(Object? v) {
    for (final r in values) {
      if (r.wire == v) return r;
    }
    return null;
  }

  /// The region's name in the app's language.
  String nameIn(AppLocalizations l10n) => switch (this) {
    arabWorld => l10n.staffRegionArabWorld,
    greaterChina => l10n.staffRegionGreaterChina,
    turkey => l10n.staffRegionTurkey,
    iran => l10n.staffRegionIran,
    southAsia => l10n.staffRegionSouthAsia,
    southeastAsia => l10n.staffRegionSoutheastAsia,
    eastAsia => l10n.staffRegionEastAsia,
    europe => l10n.staffRegionEurope,
    northAmerica => l10n.staffRegionNorthAmerica,
    latinAmerica => l10n.staffRegionLatinAmerica,
    subSaharanAfrica => l10n.staffRegionSubSaharanAfrica,
    russiaCentralAsia => l10n.staffRegionRussiaCentralAsia,
    oceania => l10n.staffRegionOceania,
  };
}

/// The role a limited staff account's line names (D283).
enum StaffLineRole {
  moderation('MODERATION'),
  support('SUPPORT'),
  finance('FINANCE');

  new(this.wire);

  final String wire;

  static StaffLineRole? fromWire(Object? v) {
    for (final r in values) {
      if (r.wire == v) return r;
    }
    return null;
  }
}

/// v1.71-live (D283, §10.96.10–11) `KabsoStaffIdentity`: a limited Kabso
/// Team account (MODERATION / SUPPORT / FINANCE, not OWNER) — `Me.staff` /
/// `PublicProfile.staff`. The app then shows the team badge, the locked team
/// frame, picture and region cover, the region line and no levels, and the
/// staff-only Me tab.
@immutable
class KabsoStaffIdentity {
  const new({required this.role, this.regions = const []});

  final StaffLineRole role;
  final List<StaffRegion> regions;

  /// The cover's region: the first one (none → the international cover).
  StaffRegion? get primaryRegion => regions.isEmpty ? null : regions.first;

  /// «مشرف للوطن العربي» / "Moderator — Arab World", «دعم — الصين الكبرى»,
  /// two regions joined, three or more «… وأكثر»; the role alone without
  /// regions; FINANCE «المالية».
  String line(AppLocalizations l10n) {
    if (role == StaffLineRole.finance) return l10n.staffLineFinance;
    final names = [for (final r in regions) r.nameIn(l10n)];
    final ar = l10n.localeName.startsWith('ar');
    final String places;
    if (names.isEmpty) {
      return role == StaffLineRole.moderation
          ? l10n.staffRoleModeration
          : l10n.staffRoleSupport;
    } else if (names.length == 1) {
      places = names.first;
    } else if (names.length == 2) {
      places = l10n.staffRegionsTwo(names[0], names[1]);
    } else {
      places = l10n.staffRegionsMore(names[0], names[1]);
    }
    if (role == StaffLineRole.moderation) {
      // Arabic: «مشرف لـ» joined to the name — «للوطن العربي», «لتركيا».
      if (ar) return 'مشرف ${_arabicFor(places)}';
      return l10n.staffLineModeration(places);
    }
    return l10n.staffLineSupport(places);
  }

  /// «ل» + the name, «ال» → «لل» (للوطن العربي, لأوروبا, لتركيا).
  static String _arabicFor(String name) =>
      name.startsWith('ال') ? 'لل${name.substring(2)}' : 'ل$name';

  @override
  bool operator ==(Object other) =>
      other is KabsoStaffIdentity &&
      other.role == role &&
      other.regions.length == regions.length &&
      [for (var i = 0; i < regions.length; i++) other.regions[i] == regions[i]]
          .every((e) => e);

  @override
  int get hashCode => Object.hash(role, Object.hashAll(regions));
}

KabsoStaffIdentity? staffIdentityFromJson(Object? json) {
  if (json is! Map) return null;
  final role = StaffLineRole.fromWire(json['role']);
  if (role == null) return null;
  final raw = json['regions'];
  return KabsoStaffIdentity(
    role: role,
    regions: [
      if (raw is List)
        for (final r in raw) ?StaffRegion.fromWire(r),
    ],
  );
}

Map<String, dynamic>? staffIdentityToJson(KabsoStaffIdentity? s) => s == null
    ? null
    : {
        'role': s.role.wire,
        'regions': [for (final r in s.regions) r.wire],
      };
