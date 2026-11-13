import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_permissions.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Keys for tests.
abstract final class LivePermissionKeys {
  static const sheet = Key('livePermission.sheet');
  static const go = Key('livePermission.continue');
  static const notNow = Key('livePermission.notNow');
  static const settings = Key('livePermission.settings');
}

/// D144a: the rationale shown **before** the system's camera/microphone
/// prompt (the system asks once, after «متابعة»), or — [blocked] — why the
/// system will not ask again, with «فتح الإعدادات». [camera] false: an audio
/// room or seat, the microphone only.
///
/// True when the person tapped Continue (or Open settings).
Future<bool> showLivePermissionSheet(
  BuildContext context, {
  required bool camera,
  bool blocked = false,
}) async {
  final answer = await showModalBottomSheet<bool>(
    context: context,
    // Taller than the default 9/16 cap when the text is large (360 × 800
    // at 1.3 text scale).
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (sheet) {
      final l10n = sheet.l10n;
      final text = sheet.textStyles;
      final body = blocked
          ? (camera
                ? l10n.livePermissionBlockedVideo
                : l10n.livePermissionBlockedAudio)
          : (camera
                ? l10n.livePermissionBodyVideo
                : l10n.livePermissionBodyAudio);
      return LiveSheetFrame(
        key: LivePermissionKeys.sheet,
        title: camera
            ? l10n.livePermissionTitleVideo
            : l10n.livePermissionTitleAudio,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (camera) ...[
                    const _PermissionIcon(Icons.videocam_rounded),
                    const SizedBox(width: KSpacing.md),
                  ],
                  const _PermissionIcon(Icons.mic_rounded),
                ],
              ),
              const SizedBox(height: KSpacing.md),
              Text(
                body,
                textAlign: TextAlign.center,
                style: text.body.copyWith(color: const Color(0xE6FFFFFF)),
              ),
              const SizedBox(height: KSpacing.lg),
              KButton(
                key: blocked
                    ? LivePermissionKeys.settings
                    : LivePermissionKeys.go,
                label: blocked
                    ? l10n.livePermissionOpenSettings
                    : l10n.livePermissionContinue,
                icon: blocked ? Icons.settings_rounded : null,
                onPressed: () => Navigator.of(sheet).pop(true),
              ),
              const SizedBox(height: KSpacing.sm),
              KButton(
                key: LivePermissionKeys.notNow,
                label: l10n.livePermissionNotNow,
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

class _PermissionIcon extends StatelessWidget {
  const new(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0x33FFFFFF),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: const Color(0xFFFFFFFF), size: 28),
    ),
  );
}

/// D144a: for a seat (a viewer about to publish): explains, asks the system
/// once, or — refused for good — offers the settings. True when the capture
/// may start. [camera] false: an audio seat, the microphone only.
Future<bool> ensureSeatCapturePermission(
  BuildContext context,
  LivePermissions permissions, {
  required bool camera,
}) async {
  var permission = await permissions.check(camera: camera);
  if (permission.canStart) return true;
  if (!context.mounted) return false;
  if (permission == LivePermission.blocked) {
    if (await showLivePermissionSheet(context, camera: camera, blocked: true)) {
      await permissions.openSettings();
    }
    return false;
  }
  if (!await showLivePermissionSheet(context, camera: camera)) return false;
  permission = await permissions.request(camera: camera);
  return permission.canStart;
}
