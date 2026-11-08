import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_global_strips.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_settings_sheet.dart';
import 'package:kabso_live/features/notifications/application/notifications_controller.dart';
import 'package:kabso_live/features/notifications/domain/notification_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D305 (owner: «يمكن للمستخدم الغاء شريط الهدايا من اعدادات اي غرفة وايضاً
/// الغاء شريط الألعاب»): «إظهار شريط الهدايا» / «إظهار شريط الألعاب» in
/// every live's settings sheet (viewer and host). They are the account's
/// `NotificationSettings.giftStrip` / `gameStrip` (every live, every phone;
/// also in the app's notification settings). None for a guest (no account:
/// the strips always show).
List<LiveSettingsItem> liveStripSwitches(BuildContext context, WidgetRef ref) {
  if (ref.watch(currentUserProvider) == null) return const [];
  final l10n = context.l10n;
  final prefs = ref.watch(globalStripPrefsProvider);
  final loaded = ref.watch(notificationSettingsProvider).hasValue;
  void change(NotificationSetting setting, {required bool on}) {
    unawaited(() async {
      try {
        await ref
            .read(notificationSettingsProvider.notifier)
            .change(setting, on: on);
      } on Object catch (e) {
        if (context.mounted) {
          KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
        }
      }
    }());
  }

  return [
    LiveSettingsSwitch(
      id: 'giftStrip',
      icon: Icons.card_giftcard_rounded,
      label: l10n.liveStripShowGifts,
      hint: l10n.liveStripSwitchHint,
      value: prefs.gifts,
      onChanged: loaded
          ? (on) => change(NotificationSetting.giftStrip, on: on)
          : null,
    ),
    LiveSettingsSwitch(
      id: 'gameStrip',
      icon: Icons.sports_esports_rounded,
      label: l10n.liveStripShowGames,
      hint: l10n.liveStripSwitchHint,
      value: prefs.games,
      onChanged: loaded
          ? (on) => change(NotificationSetting.gameStrip, on: on)
          : null,
    ),
  ];
}
