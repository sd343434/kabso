import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.139-social (D387, CONVENTIONS §10.176.8–9; owner: «اي موظف لدينا لا
/// يمكنه ارسال الهدايا — بالاضافة للموظفين الذين لديهم كرز يسحب من خلالنا
/// فقط»): a staff account — any panel role held now, the OWNER included,
/// which the server shows as `Me.staffId` — sends no gift, and its cherries
/// leave only through a withdrawal request to Kabso (never an agent). The
/// server refuses both (403 `STAFF_GIFT_REFUSED` /
/// `STAFF_WITHDRAWAL_COMPANY_ONLY`); the app hides or disables the way in.
final Provider<bool> isStaffAccountProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider.select((u) => u?.staffId != null)),
);

/// True (after telling the person why) when the caller is a staff account
/// and must not send a gift; false otherwise.
bool refuseStaffGift(BuildContext context, WidgetRef ref) {
  if (!ref.read(isStaffAccountProvider)) return false;
  KSnack.error(context, context.l10n.giftStaffRefused);
  return true;
}
