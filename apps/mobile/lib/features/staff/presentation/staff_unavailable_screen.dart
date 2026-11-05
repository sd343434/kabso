import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.71-live (D283, §10.96.10): what a Kabso Team account sees instead of a
/// user, host or agency page (go live, levels, VIP, family, store, wallet,
/// bag, …) — reached only by a deep link or an old entry, since its Me tab
/// does not offer them.
class StaffUnavailableScreen extends StatelessWidget {
  const new({super.key});

  static const noteKey = Key('staff.unavailable');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.liveKabsoTeam)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const KabsoTeamBadge(height: 40),
              const SizedBox(height: KSpacing.lg),
              Text(
                l10n.staffFeatureUnavailable,
                key: noteKey,
                textAlign: TextAlign.center,
                style: context.textStyles.body.copyWith(color: p.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
