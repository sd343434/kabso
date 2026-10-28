import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/medals/application/medals_providers.dart';
import 'package:kabso_live/features/medals/presentation/medal_icon.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/medals` (CP-018, §10.21): every medal of the catalogue, earned ones in
/// colour and locked ones greyed, with "Choose medals to show" (the
/// showcase picker). `/users/:username/medals` ([username]): that user's
/// earned medals, newest first.
class MedalsScreen extends ConsumerWidget {
  const new({super.key, this.username});

  /// Another user; null = the caller.
  final String? username;

  static const chooseKey = Key('medals.choose');
  static const gridKey = Key('medals.grid');

  static Key medalKey(String code) => Key('medals.medal.$code');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final username = this.username;
    final Widget body;
    if (username == null) {
      final load = ref.watch(medalCatalogueProvider);
      body = switch (load) {
        AsyncValue(:final value?) => _Grid(
          owned: value.owned,
          total: value.total,
          cells: [
            for (final m in value.data)
              (
                code: m.code,
                name: m.name,
                description: m.description,
                iconKey: m.iconKey,
                awardedAt: m.awardedAt,
              ),
          ],
          action: KButton(
            key: chooseKey,
            label: l10n.medalsChoose,
            variant: KButtonVariant.secondary,
            icon: Icons.push_pin_outlined,
            onPressed: () => context.push(AppRoutes.medalShowcase),
          ),
          onRefresh: () => ref.refresh(medalCatalogueProvider.future),
        ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.medalsLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(medalCatalogueProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      };
    } else {
      final load = ref.watch(userMedalsProvider(username));
      body = switch (load) {
        AsyncValue(:final value?) when value.data.isEmpty => Center(
          child: KEmptyState(
            icon: Icons.military_tech_outlined,
            title: l10n.medalsEmptyTitle,
            message: l10n.medalsEmptyBody,
          ),
        ),
        AsyncValue(:final value?) => _Grid(
          owned: value.owned,
          total: value.total,
          cells: [
            for (final m in value.data)
              (
                code: m.code,
                name: m.name,
                description: m.description,
                iconKey: m.iconKey,
                awardedAt: m.awardedAt,
              ),
          ],
          onRefresh: () => ref.refresh(userMedalsProvider(username).future),
        ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.medalsLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(userMedalsProvider(username)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      };
    }
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.medalsTitle),
      ),
      body: body,
    );
  }
}

typedef _Cell = ({
  String code,
  String name,
  String description,
  String iconKey,
  DateTime? awardedAt,
});

class _Grid extends StatelessWidget {
  const new({
    required this.owned,
    required this.total,
    required this.cells,
    required this.onRefresh,
    this.action,
  });

  final int owned;
  final int total;
  final List<_Cell> cells;
  final Widget? action;
  final Future<Object?> Function() onRefresh;

  void _open(BuildContext context, _Cell m) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) {
        final p = sheet.palette;
        final t = sheet.textStyles;
        final at = m.awardedAt;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MedalIcon(iconKey: m.iconKey, size: 88, locked: at == null),
                const SizedBox(height: KSpacing.md),
                Text(
                  m.name,
                  textAlign: TextAlign.center,
                  style: t.title.copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  m.description,
                  textAlign: TextAlign.center,
                  style: t.body.copyWith(color: p.textSecondary),
                ),
                const SizedBox(height: KSpacing.sm),
                Text(
                  at == null
                      ? l10n.medalsLocked
                      : l10n.medalsEarnedOn(KFormat.date(at, locale)),
                  style: t.caption.copyWith(color: p.textTertiary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.md,
              KSpacing.lg,
              KSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.medalsOwned(owned, total),
                    textAlign: TextAlign.center,
                    style: t.title.copyWith(color: p.textPrimary),
                  ),
                  if (action case final action?) ...[
                    const SizedBox(height: KSpacing.md),
                    action,
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(KSpacing.lg),
            sliver: SliverGrid(
              key: MedalsScreen.gridKey,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 120,
                mainAxisSpacing: KSpacing.md,
                crossAxisSpacing: KSpacing.md,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(childCount: cells.length, (
                context,
                i,
              ) {
                final m = cells[i];
                final locked = m.awardedAt == null;
                return Semantics(
                  button: true,
                  label: locked ? '${m.name}, ${l10n.medalsLocked}' : m.name,
                  excludeSemantics: true,
                  child: InkWell(
                    key: MedalsScreen.medalKey(m.code),
                    borderRadius: BorderRadius.circular(KRadius.md),
                    onTap: () => _open(context, m),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            MedalIcon(
                              iconKey: m.iconKey,
                              size: 64,
                              locked: locked,
                            ),
                            if (locked)
                              PositionedDirectional(
                                end: 0,
                                bottom: 0,
                                child: Icon(
                                  Icons.lock_rounded,
                                  size: 18,
                                  color: p.textTertiary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: KSpacing.xs),
                        Flexible(
                          child: Text(
                            m.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: t.caption.copyWith(
                              color: locked ? p.textTertiary : p.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
