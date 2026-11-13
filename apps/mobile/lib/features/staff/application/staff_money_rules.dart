import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.139-social (D387, CONVENTIONS §10.176.8–9; owner: «اي موظف لدينا لا
/// يمكنه ارسال الهدايا — بالاضافة للموظفين الذين لديهم كرز يسحب من خلالنا
/// فقط»): a staff account — any panel role held now, which the server shows
/// as `Me.staffId` — has its cherries leave only through a withdrawal
/// request to Kabso (never an agent); an employee (every panel role but
/// OWNER) sends no gift. The server refuses both (403 `STAFF_GIFT_REFUSED` /
/// `STAFF_WITHDRAWAL_COMPANY_ONLY`); the app hides or disables the way in.
final Provider<bool> isStaffAccountProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider.select((u) => u?.staffId != null)),
);

/// The gift rule's staff (owner 2026-11-12: «لا غير ممنوع» — the OWNER is
/// not blocked): an employee, i.e. a limited Kabso Team account (`Me.staff`:
/// a panel role and never OWNER; an OWNER with another role stays the
/// owner).
final Provider<bool> isGiftBlockedStaffProvider = Provider<bool>(
  (ref) => ref.watch(currentUserProvider.select((u) => u?.staff != null)),
);

/// True (after telling the person why) when the caller is an employee and
/// must not send a gift; false otherwise.
bool refuseStaffGift(BuildContext context, WidgetRef ref) {
  if (!ref.read(isGiftBlockedStaffProvider)) return false;
  KSnack.error(context, context.l10n.giftStaffRefused);
  return true;
}
