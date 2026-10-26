import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/families/application/families_providers.dart';
import 'package:kabso_live/features/families/data/families_repository.dart';
import 'package:kabso_live/features/families/domain/family_models.dart';
import 'package:kabso_live/features/families/presentation/bond_widgets.dart';
import 'package:kabso_live/features/profile/profile_screen.dart'
    show PostGridLoadMore;
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/families` (CP-018, §10.21): your family (or Create a family and your
/// pending join request), then the families by points; the search matches
/// a name or the 8-digit number (submitting a full number opens that
/// family directly, `GET /family-numbers/{number}`).
class FamiliesScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const searchKey = Key('families.search');
  static const createKey = Key('families.create');
  static const mineKey = Key('families.mine');
  static const cancelRequestKey = Key('families.cancelRequest');
  static const emptyKey = Key('families.empty');

  static Key tileKey(String id) => Key('families.tile.$id');

  @override
  ConsumerState<FamiliesScreen> createState() => _FamiliesScreenState();
}

class _FamiliesScreenState extends ConsumerState<FamiliesScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  static final RegExp _number = RegExp(r'^\d{8}$');

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  Future<void> _submitted(String value) async {
    final q = value.trim();
    _debounce?.cancel();
    setState(() => _query = q);
    if (!_number.hasMatch(q)) return;
    final l10n = context.l10n;
    try {
      final family = await ref.read(familiesRepositoryProvider).byNumber(q);
      if (mounted) unawaited(context.push(AppRoutes.family(family.id)));
    } on Object catch (e) {
      if (!mounted) return;
      KSnack.error(
        context,
        isErrorCode(e, ErrorCode.notFound)
            ? l10n.familiesNumberNotFound
            : failureMessage(l10n, toAppFailure(e)),
      );
    }
  }

  Future<void> _cancelRequest() async {
    final l10n = context.l10n;
    try {
      await ref.read(familiesRepositoryProvider).cancelMyRequest();
      if (!mounted) return;
      refreshFamilies(ref);
      KSnack.success(context, l10n.familyRequestCancelled);
    } on Object catch (e) {
      if (mounted) {
        KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final mine = ref.watch(myFamilyProvider);
    final request = ref.watch(myFamilyRequestProvider).value;
    final list = ref.watch(familySearchProvider(_query));

    final header = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.sm,
          KSpacing.lg,
          KSpacing.xs,
        ),
        child: TextField(
          key: FamiliesScreen.searchKey,
          controller: _search,
          onChanged: _changed,
          onSubmitted: _submitted,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.familiesSearchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(KRadius.md),
            ),
          ),
        ),
      ),
      if (_query.isEmpty) ...[
        switch (mine) {
          AsyncValue(value: final Family family) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BondSectionTitle(l10n.familiesMine),
              FamilyTile(
                key: FamiliesScreen.mineKey,
                name: family.name,
                number: family.number,
                emblemUrl: family.emblemUrl,
                level: family.level,
                memberCount: family.memberCount,
                capacity: family.capacity,
                onTap: () => context.push(AppRoutes.family(family.id)),
              ),
            ],
          ),
          AsyncValue(hasValue: true) => Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.md,
              KSpacing.lg,
              0,
            ),
            child: KButton(
              key: FamiliesScreen.createKey,
              label: l10n.familiesCreate,
              icon: Icons.add_rounded,
              onPressed: () => context.push(AppRoutes.newFamily),
            ),
          ),
          _ => const SizedBox.shrink(),
        },
        if (request != null && mine.value == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.md,
              KSpacing.lg,
              0,
            ),
            child: Container(
              padding: const EdgeInsets.all(KSpacing.md),
              decoration: BoxDecoration(
                color: p.surfaceRaised,
                borderRadius: BorderRadius.circular(KRadius.md),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.familyPendingRequest(request.family.name),
                      style: t.body.copyWith(color: p.textPrimary),
                    ),
                  ),
                  TextButton(
                    key: FamiliesScreen.cancelRequestKey,
                    onPressed: _cancelRequest,
                    child: Text(l10n.familyCancelRequest),
                  ),
                ],
              ),
            ),
          ),
      ],
      BondSectionTitle(
        _query.isEmpty ? l10n.familiesTop : l10n.familiesResults,
      ),
    ];

    final Widget body = switch (list) {
      AsyncValue(:final value?) => ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: KSpacing.xl),
        itemCount:
            header.length +
            (value.items.isEmpty ? 1 : value.items.length) +
            (value.hasMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i < header.length) return header[i];
          final j = i - header.length;
          if (value.items.isEmpty && j == 0) {
            return Padding(
              key: FamiliesScreen.emptyKey,
              padding: const EdgeInsets.symmetric(vertical: KSpacing.xl),
              child: KEmptyState(
                icon: Icons.groups_2_outlined,
                title: _query.isEmpty
                    ? l10n.familiesEmpty
                    : l10n.familiesNoMatch,
                message: _query.isEmpty
                    ? l10n.familiesEmptyBody
                    : l10n.familiesNoMatchBody,
                compact: true,
              ),
            );
          }
          if (j < value.items.length) {
            final f = value.items[j];
            return FamilyTile(
              key: FamiliesScreen.tileKey(f.id),
              name: f.name,
              number: f.number,
              emblemUrl: f.emblemUrl,
              level: f.level,
              memberCount: f.memberCount,
              capacity: f.capacity,
              onTap: () => context.push(AppRoutes.family(f.id)),
            );
          }
          final notifier = ref.read(familySearchProvider(_query).notifier);
          return value.loadMoreError == null
              ? PostGridLoadMore(
                  key: ValueKey(value.items.length),
                  onVisible: () => unawaited(notifier.loadMore()),
                )
              : Center(
                  child: TextButton(
                    onPressed: () => unawaited(notifier.loadMore()),
                    child: Text(l10n.actionRetry),
                  ),
                );
        },
      ),
      AsyncValue(:final error?, isLoading: false) => ListView(
        children: [
          ...header,
          FailureErrorState(
            title: l10n.familiesLoadError,
            failure: toAppFailure(error),
            onRetry: () => ref.invalidate(familySearchProvider(_query)),
            compact: true,
          ),
        ],
      ),
      _ => ListView(
        children: [
          ...header,
          const Padding(
            padding: EdgeInsets.all(KSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    };

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.familiesTitle),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshFamilies(ref);
          await ref.read(familySearchProvider(_query).future);
        },
        child: body,
      ),
    );
  }
}

/// One family in a list: emblem, name, number, level and members.
class FamilyTile extends StatelessWidget {
  const new({
    required this.name,
    required this.number,
    required this.emblemUrl,
    required this.level,
    required this.memberCount,
    required this.capacity,
    required this.onTap,
    super.key,
  });

  final String name;
  final int number;
  final String? emblemUrl;
  final int level;
  final int memberCount;
  final int capacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.lg,
          vertical: KSpacing.sm,
        ),
        child: Row(
          children: [
            FamilyEmblem(url: emblemUrl),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(color: p.textPrimary),
                  ),
                  Text(
                    '${l10n.familyNumber('$number')} · '
                    '${l10n.familyMembersCount(memberCount, capacity)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.caption.copyWith(color: p.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            FamilyLevelChip(level: level),
          ],
        ),
      ),
    );
  }
}

/// A family's level on a gold pill.
class FamilyLevelChip extends StatelessWidget {
  const new({required this.level, super.key});

  final int level;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(KRadius.pill),
      gradient: const LinearGradient(
        colors: [Color(0xFFF2B84B), Color(0xFFD9922E)],
      ),
    ),
    child: Text(
      context.l10n.familyLevel(level),
      style: context.textStyles.caption.copyWith(
        color: const Color(0xFFFFFFFF),
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
