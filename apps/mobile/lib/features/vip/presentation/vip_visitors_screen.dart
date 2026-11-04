import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/vip/application/vip_providers.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D258 (PROFILE_VISITORS, §10.94.9): «من زار ملفي» — who opened the
/// member's profile in the last 30 days, the latest first: the picture (and
/// VIP frame), the name with the VIP badge, when, and how many visits. A tap
/// opens their profile. Without the perk the server refuses: the page says
/// so and leads to «شراء VIP».
class VipVisitorsScreen extends ConsumerWidget {
  const new({super.key});

  static const listKey = Key('vip.visitors.list');
  static const noPerkKey = Key('vip.visitors.noPerk');
  static const emptyKey = Key('vip.visitors.empty');
  static const totalKey = Key('vip.visitors.total');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final visitors = ref.watch(profileVisitorsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.vipVisitorsTitle)),
      body: SafeArea(
        child: switch (visitors) {
          AsyncData(:final value) when value.data.isEmpty => KEmptyState(
            key: emptyKey,
            icon: Icons.visibility_outlined,
            title: l10n.vipVisitorsEmptyTitle,
            message: l10n.vipVisitorsEmptyMessage,
          ),
          AsyncData(:final value) => _List(list: value),
          AsyncError(:final error) => _error(context, ref, toAppFailure(error)),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _error(BuildContext context, WidgetRef ref, AppFailure failure) {
    final l10n = context.l10n;
    if (failure.code == ErrorCode.vipUnavailable) {
      return KEmptyState(
        key: noPerkKey,
        icon: Icons.workspace_premium_outlined,
        title: l10n.vipVisitorsNoPerkTitle,
        message: l10n.vipVisitorsNoPerkMessage,
        actionLabel: l10n.vipVisitorsNoPerkAction,
        onAction: () => context.push(AppRoutes.vip),
      );
    }
    return KErrorState(
      title: l10n.vipVisitorsTitle,
      message: failureMessage(l10n, failure),
      retryLabel: l10n.actionRetry,
      onRetry: () => ref.invalidate(profileVisitorsProvider),
    );
  }
}

class _List extends StatelessWidget {
  const new({required this.list});

  final ProfileVisitorList list;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final p = context.palette;
    return ListView.separated(
      key: VipVisitorsScreen.listKey,
      padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
      itemCount: list.data.length + 1,
      separatorBuilder: (_, i) =>
          i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.xs,
              KSpacing.lg,
              KSpacing.sm,
            ),
            child: Text(
              l10n.vipVisitorsTotal('${list.total}'),
              key: VipVisitorsScreen.totalKey,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          );
        }
        final v = list.data[i - 1];
        final when = v.lastVisitedAt.toLocal();
        final name = v.user.displayName.trim().isEmpty
            ? v.user.username
            : v.user.displayName;
        return ListTile(
          key: ValueKey('vip.visitor.${v.user.id}'),
          onTap: () => context.push(AppRoutes.userProfile(v.user.username)),
          leading: VipAvatarFrame(
            vip: v.user.vip,
            size: 44,
            child: KAvatar(name: name, imageUrl: v.user.avatarUrl, size: 44),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  KFormat.bidiIsolate(name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              // D268 (owner): the VIP badge right after the name.
              if (v.user.vip != null) ...[
                const SizedBox(width: KSpacing.xs),
                VipNameBadge(vip: v.user.vip, height: 18),
              ],
            ],
          ),
          subtitle: Text(
            '${KFormat.date(when, l10n.localeName)} · '
            '${KFormat.time(when, l10n.localeName)}',
            style: t.caption.copyWith(color: p.textSecondary),
          ),
          trailing: v.visits > 1
              ? Text(
                  l10n.vipVisitorsVisits('${v.visits}'),
                  style: t.caption.copyWith(color: p.textSecondary),
                )
              : null,
        );
      },
    );
  }
}
