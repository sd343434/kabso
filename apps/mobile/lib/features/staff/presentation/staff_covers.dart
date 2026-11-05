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

  /// The art is 2:1 and the profile's 42 % box is about square, so the sides
  /// are cropped: a slight bias to the right keeps the title «إدارة التطبيق
  /// والمشرفون» / "App Administration & Moderation" whole and the mascot's
  /// face in (the box shows the art's full height).
  static const alignment = Alignment(0.12, 0);
}
