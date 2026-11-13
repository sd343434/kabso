// D388 x D387: the «واتساب» circle in «الرسائل» (waEntryProvider) while
// the staff member's WhatsApp level is still unknown keeps the roles that
// answer the official number — the D355 roles and D387's VIP_CARE («دعم
// كابسو», WhatsApp level REPLY by default, CONVENTIONS §10.176.1).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/owner_profile/data/owner_profile_repository.dart'
    show isKabsoOwnerProvider;
import 'package:kabso_live/features/staff/domain/staff_identity.dart';
import 'package:kabso_live/features/whatsapp/application/wa_providers.dart';

import '../../helpers/fakes.dart';

bool _entry(StaffLineRole role, {WaAccess? access}) {
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(
        testUser().copyWith(
          kabsoTeam: true,
          staff: KabsoStaffIdentity(role: role),
        ),
      ),
      isKabsoOwnerProvider.overrideWithValue(false),
      waAccessProvider.overrideWithValue(access),
    ],
  );
  addTearDown(container.dispose);
  return container.read(waEntryProvider);
}

void main() {
  test('level unknown: MODERATION, SUPPORT and VIP_CARE get the entry', () {
    expect(_entry(StaffLineRole.moderation), isTrue);
    expect(_entry(StaffLineRole.support), isTrue);
    expect(_entry(StaffLineRole.vipCare), isTrue);
  });

  test('level unknown: the other roles do not', () {
    for (final role in [
      StaffLineRole.finance,
      StaffLineRole.bd,
      StaffLineRole.liveOps,
      StaffLineRole.talent,
      StaffLineRole.community,
    ]) {
      expect(_entry(role), isFalse, reason: role.name);
    }
  });

  test('level known: the level decides, VIP_CARE included', () {
    expect(_entry(StaffLineRole.vipCare, access: WaAccess.none), isFalse);
    expect(_entry(StaffLineRole.vipCare, access: WaAccess.reply), isTrue);
    expect(_entry(StaffLineRole.finance, access: WaAccess.view), isTrue);
  });
}
