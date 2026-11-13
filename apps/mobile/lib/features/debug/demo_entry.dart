import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/demo/demo_mode.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D86: "Try with demo data" on the welcome and login screens — test
/// builds only (nothing in release builds). Turns Demo data on and signs
/// in as the demo account, so a phone without a server can walk the app.
class DemoEntryButton extends ConsumerWidget {
  const new({super.key, this.color});

  /// The label colour (the screens' own muted text).
  final Color? color;

  static const buttonKey = Key('demo.try');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDemoAvailable) return const SizedBox.shrink();
    return TextButton.icon(
      key: buttonKey,
      onPressed: () => ref.read(sessionControllerProvider.notifier).enterDemo(),
      icon: Icon(
        Icons.science_outlined,
        size: 18,
        color: color ?? context.palette.textSecondary,
      ),
      label: Text(
        context.l10n.demoDataTry,
        style: context.textStyles.bodyStrong.copyWith(
          color: color ?? context.palette.textSecondary,
        ),
      ),
    );
  }
}

/// D86: the Settings switch for Demo data (test builds only).
class DemoDataTile extends ConsumerWidget {
  const new({super.key});

  static const tileKey = Key('settings.demoData');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDemoAvailable) return const SizedBox.shrink();
    final l10n = context.l10n;
    final on = ref.watch(demoModeProvider);
    final session = ref.read(sessionControllerProvider.notifier);
    return SwitchListTile(
      key: tileKey,
      secondary: const Icon(Icons.science_outlined),
      title: Text(l10n.demoDataTitle),
      subtitle: Text(l10n.demoDataBody),
      value: on,
      onChanged: (v) => v
          ? ref.read(demoModeProvider.notifier).set(enabled: true)
          : session.exitDemo(),
    );
  }
}
