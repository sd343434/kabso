import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/ambassadors/data/ambassador_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.141-social (D390, §10.179.9): «برنامج سفراء Kabso» on the invite page —
/// shown only while the programme is on (or to an ambassador), so nothing
/// changes for anyone before the owner switches it on; Kabso Team accounts
/// never reach the invite page (D283).
class AmbassadorEntryCard extends ConsumerWidget {
  const new({super.key});

  static const cardKey = Key('ambassador.entry');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programme = ref.watch(ambassadorProgrammeProvider).value;
    if (programme == null || !(programme.enabled || programme.isAmbassador)) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.md,
        KSpacing.lg,
        0,
      ),
      child: Material(
        color: p.surfaceRaised,
        borderRadius: BorderRadius.circular(KRadius.xl),
        child: InkWell(
          key: cardKey,
          borderRadius: BorderRadius.circular(KRadius.xl),
          onTap: () => unawaited(
            context.push(
              programme.isAmbassador
                  ? AppRoutes.ambassadorDashboard
                  : AppRoutes.ambassadors,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(KSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.xl),
              border: Border.all(color: p.primary.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.primary.withValues(alpha: 0.12),
                  ),
                  child: Icon(Icons.public_rounded, color: p.primary),
                ),
                const SizedBox(width: KSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        programme.isAmbassador
                            ? l10n.ambOpenDashboard
                            : l10n.ambProgrammeEntry,
                        style: t.bodyStrong,
                      ),
                      Text(
                        l10n.ambProgrammeEntryHint,
                        style: t.caption.copyWith(color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: p.textTertiary,
                  textDirection: Directionality.of(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
