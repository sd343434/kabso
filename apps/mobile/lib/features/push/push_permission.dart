import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_camera_fx/kabso_camera_fx.dart';
import 'package:kabso_live/core/storage/preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/push/push_messaging.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D152: Android 13+'s notification permission (POST_NOTIFICATIONS) on the
/// D144a permission channel (`com.kabso/permissions`).
abstract interface class PushPermissions {
  /// Where it stands, without asking.
  Future<KabsoPermissionStatus> check();

  /// Asks the system (once); where it stands after.
  Future<KabsoPermissionStatus> request();

  /// Opens this app's page in the system settings; false when it could not.
  Future<bool> openSettings();
}

class DevicePushPermissions implements PushPermissions {
  new([KabsoPermissions? plugin]) : _plugin = plugin ?? KabsoPermissions();

  final KabsoPermissions _plugin;

  /// Off in widget tests (no channel handler; tests override the provider).
  static bool enabled = true;

  static const Set<KabsoPermission> _kind = {KabsoPermission.notifications};

  @override
  Future<KabsoPermissionStatus> check() async =>
      (await _plugin.status(_kind))[KabsoPermission.notifications] ??
      KabsoPermissionStatus.unknown;

  @override
  Future<KabsoPermissionStatus> request() async =>
      (await _plugin.request(_kind))[KabsoPermission.notifications] ??
      KabsoPermissionStatus.unknown;

  @override
  Future<bool> openSettings() => _plugin.openSettings();
}

/// Where the platform cannot tell (iOS, web, tests): nothing to ask.
class UnknownPushPermissions implements PushPermissions {
  const new();

  @override
  Future<KabsoPermissionStatus> check() async => KabsoPermissionStatus.unknown;

  @override
  Future<KabsoPermissionStatus> request() async =>
      KabsoPermissionStatus.unknown;

  @override
  Future<bool> openSettings() async => false;
}

final pushPermissionsProvider = Provider<PushPermissions>(
  (ref) => DevicePushPermissions.enabled && pushPlatformSupported
      ? DevicePushPermissions()
      : const UnknownPushPermissions(),
);

/// Keys for tests.
abstract final class PushPermissionKeys {
  static const sheet = Key('pushPermission.sheet');
  static const allow = Key('pushPermission.allow');
  static const notNow = Key('pushPermission.notNow');
  static const banner = Key('pushPermission.banner');
  static const bannerAction = Key('pushPermission.bannerAction');
}

/// D152: the rationale shown **before** the system's notification prompt
/// (D144a pattern). True when the person tapped «السماح بالإشعارات».
Future<bool> showPushPermissionSheet(BuildContext context) async {
  final answer = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final l10n = sheet.l10n;
      final p = sheet.palette;
      final text = sheet.textStyles;
      return SafeArea(
        top: false,
        child: Padding(
          key: PushPermissionKeys.sheet,
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            0,
            KSpacing.lg,
            KSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: ExcludeSemantics(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: p.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.notifications_active_rounded,
                      color: p.primary,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: KSpacing.md),
              Semantics(
                header: true,
                child: Text(
                  l10n.pushPermissionTitle,
                  textAlign: TextAlign.center,
                  style: text.title,
                ),
              ),
              const SizedBox(height: KSpacing.sm),
              Text(
                l10n.pushPermissionBody,
                textAlign: TextAlign.center,
                style: text.body.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: KSpacing.lg),
              KButton(
                key: PushPermissionKeys.allow,
                label: l10n.pushPermissionAllow,
                onPressed: () => Navigator.of(sheet).pop(true),
              ),
              const SizedBox(height: KSpacing.sm),
              KButton(
                key: PushPermissionKeys.notNow,
                label: l10n.pushPermissionNotNow,
                variant: KButtonVariant.ghost,
                onPressed: () => Navigator.of(sheet).pop(false),
              ),
            ],
          ),
        ),
      );
    },
  );
  return answer ?? false;
}

/// D152: asks for the notification permission **once per install**, at a
/// moment that explains itself (after signing in, on first opening the
/// notifications or a family chat — never at a cold start): granted or
/// nothing to ask → nothing; never asked or refused → the rationale, then
/// the system prompt (Not now asks nothing); refused for good → nothing here
/// (the notification settings offer «فتح الإعدادات»). Push off on this
/// device (no Firebase) → nothing.
Future<void> maybeAskPushPermission(BuildContext context, WidgetRef ref) async {
  final prefs = ref.read(sharedPreferencesProvider);
  if (prefs.getBool(PreferenceKeys.pushPermissionAsked) ?? false) return;
  if (!await ref.read(pushMessagingProvider).init()) return;
  final permissions = ref.read(pushPermissionsProvider);
  final status = await permissions.check();
  switch (status) {
    case KabsoPermissionStatus.granted:
    case KabsoPermissionStatus.unknown:
      return;
    case KabsoPermissionStatus.blocked:
      await prefs.setBool(PreferenceKeys.pushPermissionAsked, true);
      return;
    case KabsoPermissionStatus.notAsked:
    case KabsoPermissionStatus.denied:
      if (!context.mounted) return;
      await prefs.setBool(PreferenceKeys.pushPermissionAsked, true);
      if (!context.mounted) return;
      if (await showPushPermissionSheet(context)) await permissions.request();
  }
}

/// D152: on the notification settings, while pushes cannot show on this
/// phone: why, and «تفعيل» (the system asks) or — refused for good —
/// «فتح الإعدادات». Hidden when granted or where the platform cannot tell.
class PushPermissionBanner extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PushPermissionBanner> createState() =>
      _PushPermissionBannerState();
}

class _PushPermissionBannerState extends ConsumerState<PushPermissionBanner>
    with WidgetsBindingObserver {
  KabsoPermissionStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system settings.
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final status = await ref.read(pushPermissionsProvider).check();
    if (mounted) setState(() => _status = status);
  }

  Future<void> _act() async {
    final permissions = ref.read(pushPermissionsProvider);
    if (_status == KabsoPermissionStatus.blocked) {
      await permissions.openSettings();
      return;
    }
    await ref
        .read(sharedPreferencesProvider)
        .setBool(PreferenceKeys.pushPermissionAsked, true);
    final after = await permissions.request();
    if (mounted) setState(() => _status = after);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null ||
        status == KabsoPermissionStatus.granted ||
        status == KabsoPermissionStatus.unknown) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final p = context.palette;
    final blocked = status == KabsoPermissionStatus.blocked;
    return Container(
      key: PushPermissionKeys.banner,
      margin: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.md,
        KSpacing.lg,
        KSpacing.sm,
      ),
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_off_rounded, color: p.primary),
              const SizedBox(width: KSpacing.sm),
              Expanded(
                child: Text(
                  l10n.pushOffTitle,
                  style: context.textStyles.bodyStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.xs),
          Text(
            blocked ? l10n.pushOffBlockedBody : l10n.pushOffBody,
            style: context.textStyles.caption.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: KSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: KButton(
              key: PushPermissionKeys.bannerAction,
              label: blocked ? l10n.pushOpenSettings : l10n.pushTurnOn,
              icon: blocked ? Icons.settings_rounded : null,
              expand: false,
              onPressed: _act,
            ),
          ),
        ],
      ),
    );
  }
}

/// D152: a sign-in just happened, so the shell may explain and ask for the
/// notification permission (once per install, [maybeAskPushPermission]).
class PushPromptDue extends Notifier<bool> {
  @override
  bool build() => false;

  void due() => state = true;

  /// True once per [due].
  bool consume() {
    if (!state) return false;
    state = false;
    return true;
  }
}

final pushPromptDueProvider = NotifierProvider<PushPromptDue, bool>(
  PushPromptDue.new,
);

/// D152: asks for the notification permission (once per install,
/// [maybeAskPushPermission]) when [child] first shows — the notifications
/// screen and a family chat, where the reason is obvious.
class PushPermissionTrigger extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PushPermissionTrigger> createState() =>
      _PushPermissionTriggerState();
}

class _PushPermissionTriggerState extends ConsumerState<PushPermissionTrigger> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(maybeAskPushPermission(context, ref));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
