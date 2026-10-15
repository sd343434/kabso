import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Launch screen while the stored session is restored. Navigation away is
/// done by the router's redirect when the auth state settles.
class SplashScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(sessionControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: switch (state) {
          AuthRestoreFailed(:final failure) => FailureErrorState(
            title: l10n.splashRestoreFailed,
            failure: failure,
            onRetry: () =>
                ref.read(sessionControllerProvider.notifier).restore(),
          ),
          _ => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KLogo(
                  primary: l10n.brandWordmarkPrimary,
                  accent: l10n.brandWordmarkAccent,
                  semanticLabel: l10n.brandSemanticLabel,
                  size: 36,
                ),
                const SizedBox(height: KSpacing.xl),
                Semantics(
                  label: l10n.loading,
                  child: const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ],
            ),
          ),
        },
      ),
    );
  }
}
