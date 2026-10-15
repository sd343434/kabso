import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/domain/entities.dart';
import 'package:kabso_live/features/auth/presentation/auth_controller.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The signed-in user's own profile, from `GET /me`.
class ProfileScreen extends ConsumerWidget {
  const new({super.key});

  static const settingsButtonKey = Key('profile.settings');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final me = ref.watch(meProvider);

    return Scaffold(
      appBar: AppBar(
        // PHASE1_1_SCREENS §5.4: the TopBar shows @username ("Profile" stays
        // the tab label).
        title: Text(
          l10n.profileUsername(
            me.value?.username ??
                ref.watch(currentUserProvider)?.username ??
                '',
          ),
          key: const Key('profile.title'),
          textDirection: TextDirection.ltr,
        ),
        actions: [
          IconButton(
            key: settingsButtonKey,
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: switch (me) {
        // Keep showing the user while a pull-to-refresh is running.
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async {
            try {
              ref.invalidate(meProvider);
              await ref.read(meProvider.future);
            } on Object catch (e) {
              if (context.mounted) {
                KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
              }
            }
          },
          child: _ProfileBody(user: value),
        ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.errorTitle,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(meProvider),
        ),
        _ => const _ProfileSkeleton(),
      },
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const new({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return ListView(
      padding: const EdgeInsetsDirectional.all(KSpacing.xl),
      children: [
        Center(
          child: KAvatar(
            name: user.displayName,
            imageUrl: user.avatarUrl,
            size: KSizes.avatarLg,
          ),
        ),
        const SizedBox(height: KSpacing.lg),
        Text(
          user.displayName,
          key: const Key('profile.displayName'),
          style: t.headline,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: KSpacing.xs),
        Text(
          l10n.profileUsername(user.username),
          key: const Key('profile.username'),
          style: t.body.copyWith(color: p.textSecondary),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        ),
        if (user.bio != null && user.bio!.isNotEmpty) ...[
          const SizedBox(height: KSpacing.md),
          Text(user.bio!, style: t.body, textAlign: TextAlign.center),
        ],
        const SizedBox(height: KSpacing.xl),
        Container(
          padding: const EdgeInsetsDirectional.all(KSpacing.lg),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(KRadius.lg),
            border: Border.all(color: p.border),
          ),
          child: Column(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.grid_view_rounded, color: p.textTertiary),
              ),
              const SizedBox(height: KSpacing.sm),
              Text(
                l10n.profileContentComingTitle,
                style: t.bodyStrong,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                l10n.profileContentComingBody,
                style: t.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.loading,
      child: const Padding(
        padding: EdgeInsetsDirectional.all(KSpacing.xl),
        child: Column(
          children: [
            KSkeleton(height: KSizes.avatarLg, circle: true),
            SizedBox(height: KSpacing.lg),
            KSkeleton(width: 180, height: 24),
            SizedBox(height: KSpacing.sm),
            KSkeleton(width: 120),
            SizedBox(height: KSpacing.xl),
            KSkeleton(height: 72, radius: KRadius.lg),
          ],
        ),
      ),
    );
  }
}
