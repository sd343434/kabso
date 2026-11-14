import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/data/live_pk_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.43-live (D195): a host's PK record on their profile — «PK: 5 فوز ·
/// 2 خسارة · 1 تعادل». Nothing while unknown or before their first PK.
class LivePkRecordLine extends ConsumerWidget {
  const new({required this.username, super.key});

  final String username;

  static const lineKey = Key('profile.pkRecord');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(livePkRecordProvider(username)).value;
    if (record == null || record.total == 0) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      key: lineKey,
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE50914), Color(0xFFFF7A00)],
                ),
                borderRadius: BorderRadius.circular(KRadius.pill),
              ),
              child: Text(
                l10n.pkRecord(
                  '${record.wins}',
                  '${record.losses}',
                  '${record.draws}',
                ),
                textAlign: TextAlign.center,
                style: context.textStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
