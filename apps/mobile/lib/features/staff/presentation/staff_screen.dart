import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/staff/application/staff_providers.dart';
import 'package:kabso_live/features/staff/domain/staff_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// v1.68-live (D273, §10.96.6; owner: «المناوبة من الهاتف»): «فريق كابسو» in
/// the Me tab (staff accounts only) — the roles, the shift «في المناوبة» and
/// «بثوثي» (the lives assigned to the staff member, the most reported first),
/// each opening the live straight away as staff. Staff may enter any other
/// live from the live lists too. D286 (v1.76-live): no authenticator code any
/// more, and opening this page (staff work) switches the shift on.
class StaffScreen extends ConsumerWidget {
  const new({super.key});

  static const shiftKey = Key('staff.shift');
  static Key live(String roomId) => Key('staff.live.$roomId');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final status = ref.watch(staffStatusProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.liveKabsoTeam)),
      body: switch (status) {
        AsyncData(:final value) => _Body(status: value),
        AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: Text(
              failureMessage(l10n, toAppFailure(error)),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

String staffRoleLabel(AppLocalizations l10n, String role) => switch (role) {
  'OWNER' => l10n.staffRoleOwner,
  'MODERATION' => l10n.staffRoleModeration,
  'SUPPORT' => l10n.staffRoleSupport,
  'BD' => l10n.staffRoleBd,
  _ => l10n.staffRoleFinance,
};

class _Body extends ConsumerWidget {
  const new({required this.status});

  final StaffStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    final lives = ref.watch(staffLivesProvider);
    // D286 (§10.96.14): opening «بثوثي» is staff work — the server switched
    // the shift on; the switch shows it at once.
    ref.listen(staffLivesProvider, (_, next) {
      if (next.hasValue) ref.read(staffStatusProvider.notifier).staffWorked();
    });

    Future<void> guard(Future<void> Function() call) async {
      try {
        await call();
      } on Object catch (e) {
        if (context.mounted) {
          KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
        }
      }
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(staffStatusProvider.notifier).refresh();
        ref.invalidate(staffLivesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(KSpacing.lg),
        children: [
          Row(
            children: [
              // D282: the Kabso Team badge heads the shift page.
              const KabsoTeamBadge(height: 40),
              const SizedBox(width: KSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.staffToolsTitle, style: text.title),
                    Text(
                      l10n.staffMeIntro,
                      style: text.caption.copyWith(color: p.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.md),
          Wrap(
            spacing: KSpacing.xs,
            children: [
              for (final r in status.roles)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(staffRoleLabel(l10n, r)),
                ),
            ],
          ),
          const SizedBox(height: KSpacing.md),
          // D286: no code — the shift goes on by itself with staff work and
          // off by hand.
          SwitchListTile(
            key: StaffScreen.shiftKey,
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.staffShift, style: text.bodyStrong),
            subtitle: Text(l10n.staffShiftAutoHint),
            value: status.onShift,
            onChanged: (on) => unawaited(
              guard(() async {
                await ref
                    .read(staffStatusProvider.notifier)
                    .setShift(onShift: on);
                // Only when on: reading «بثوثي» is staff work and would
                // switch an «off by hand» back on (D286).
                if (on) ref.invalidate(staffLivesProvider);
              }),
            ),
          ),
          const Divider(),
          Text(l10n.staffMyLives, style: text.title),
          const SizedBox(height: KSpacing.sm),
          switch (lives) {
            // D286: turned off by hand here — no lives (they were handed on),
            // and no new «بثوثي» read that would switch the shift on again.
            AsyncData() when !status.onShift => Text(
              l10n.staffMyLivesOffShift,
              style: text.body.copyWith(color: p.textTertiary),
            ),
            AsyncData(:final value) when value.isEmpty => Text(
              l10n.staffMyLivesEmpty,
              style: text.body.copyWith(color: p.textTertiary),
            ),
            AsyncData(:final value) => Column(
              children: [for (final l in value) _LiveTile(live: l)],
            ),
            AsyncError(:final error) => Text(
              failureMessage(l10n, toAppFailure(error)),
              style: text.body.copyWith(color: p.error),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
          const SizedBox(height: KSpacing.lg),
          Text(
            l10n.staffAnyLive,
            style: text.caption.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LiveTile extends StatelessWidget {
  const new({required this.live});

  final StaffLive live;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final text = context.textStyles;
    return Card(
      key: StaffScreen.live(live.roomId),
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: ListTile(
        leading: KAvatar(
          name: live.hostName,
          imageUrl: live.hostAvatarUrl,
          size: 44,
        ),
        title: Text(
          live.hostName.isEmpty ? '@${live.hostUsername}' : live.hostName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${live.title} · '
          '${l10n.staffViewersCount(KFormat.grouped(live.viewerCount))}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: live.openReports > 0
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.sm,
                  vertical: KSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: p.error,
                  borderRadius: BorderRadius.circular(KRadius.pill),
                ),
                child: Text(
                  l10n.staffReportsCount(KFormat.grouped(live.openReports)),
                  style: text.caption.copyWith(color: p.onPrimary),
                ),
              )
            : const Icon(Icons.chevron_right_rounded),
        onTap: () => unawaited(
          context.push(
            live.openReports > 0
                ? AppRoutes.liveRoomStaffReports(live.roomId)
                : AppRoutes.liveRoom(live.roomId),
          ),
        ),
      ),
    );
  }
}
