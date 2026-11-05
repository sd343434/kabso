import 'package:kabso_live/features/staff/domain/staff_identity.dart';
import 'package:material_ui/material_ui.dart';

/// v1.72-live (D283, §10.96.10; owner: «وهذا غلاف الادارة والمشرفين العرب» /
/// «… الاجانب، لا يمكن تغييره»): the locked team cover of a staff profile,
/// by its first region — the Arab World's own art; every other region (and
/// none) the international art until the owner sends one for it: add the
/// region to [byRegion], nothing else changes.
abstract final class StaffCovers {
  static const Map<StaffRegion, String> byRegion = {
    StaffRegion.arabWorld: 'assets/staff/covers/arab_world.webp',
  };
  static const fallback = 'assets/staff/covers/international.webp';

  static String assetFor(StaffRegion? region) => byRegion[region] ?? fallback;

  /// The owner's cover-sized art (≈ 1.09 : 1) matches the profile's 42 % box
  /// (≈ 1.1 : 1 on a 393 × 852 phone), so it is centred and little is cut.
  static const Alignment alignment = Alignment.center;
}
