import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/ids/client_id.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/cp/application/cp_providers.dart';
import 'package:kabso_live/features/cp/data/cp_repository.dart';
import 'package:kabso_live/features/families/application/families_providers.dart';
import 'package:kabso_live/features/families/presentation/bond_widgets.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Sends a CP request to [username] ([name] shown) after a confirmation
/// with the price from `GET /cp/config` (99 coins, given back if declined,
/// cancelled or unanswered). One `clientId` for this request: a retry is
/// never charged twice. Returns true when sent.
Future<bool> sendCpRequest(
  BuildContext context,
  WidgetRef ref, {
  required String username,
  required String name,
}) async {
  final l10n = context.l10n;
  final int cost;
  final int days;
  try {
    final config = await ref.read(cpConfigProvider.future);
    cost = config.requestCost;
    days = config.requestTtlDays;
  } on Object catch (e) {
    if (context.mounted) {
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
    return false;
  }
  if (!context.mounted) return false;
  final ok = await confirmBond(
    context,
    title: l10n.cpSendTitle(name),
    body: l10n.cpSendBody(l10n.bondsCoins(cost), l10n.bondsDays(days)),
    confirm: l10n.cpSendRequest,
  );
  if (!ok || !context.mounted) return false;
  final clientId = newClientId();
  try {
    final result = await ref
        .read(cpRepositoryProvider)
        .sendRequest(username: username, clientId: clientId);
    if (!context.mounted) return true;
    showCoins(ref, result.coins);
    refreshCp(ref);
    KSnack.success(context, l10n.cpSent(name));
    return true;
  } on Object catch (e) {
    if (!context.mounted) return false;
    if (isErrorCode(e, ErrorCode.insufficientCoins)) {
      reloadCoins(ref);
      KSnack.error(context, l10n.cpSendNotEnough(l10n.bondsCoins(cost)));
    } else {
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
    return false;
  }
}
