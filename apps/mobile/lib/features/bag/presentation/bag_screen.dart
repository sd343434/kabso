import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/bag/application/bag_providers.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// `/bag` (CP-019, D107, §10.22): the user's bag, one tab per category the
/// app knows (Profile card first). Each tab shows the items the user owns
/// with a preview, the worn one marked, Wear / Take off
/// (`PUT /me/bag/equipped`), then the catalogue's other items greyed as
/// not owned yet (there is no store yet).
class BagScreen extends StatelessWidget {
  const new({super.key});

  static Key tabKey(BagCategory category) => Key('bag.tab.${category.wire}');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    return DefaultTabController(
      length: BagCategory.values.length,
      child: Scaffold(
        backgroundColor: p.background,
        appBar: AppBar(
          backgroundColor: p.background,
          centerTitle: true,
          title: Text(l10n.bagTitle),
          bottom: TabBar(
            tabs: [
              for (final c in BagCategory.values)
                Tab(key: tabKey(c), text: bagCategoryLabel(l10n, c)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final c in BagCategory.values) BagCategoryView(category: c),
          ],
        ),
      ),
    );
  }
}

/// The tab label of [category].
String bagCategoryLabel(AppLocalizations l10n, BagCategory category) =>
    switch (category) {
      BagCategory.profileCard => l10n.bagCategoryProfileCard,
    };

/// One category of the bag: the owned items, then the locked ones.
class BagCategoryView extends ConsumerStatefulWidget {
  const new({required this.category, super.key});

  final BagCategory category;

  static const emptyKey = Key('bag.empty');
  static const ownedKey = Key('bag.owned');
  static const lockedSectionKey = Key('bag.lockedSection');

  static Key itemKey(String code) => Key('bag.item.$code');
  static Key wearKey(String code) => Key('bag.wear.$code');
  static Key takeOffKey(String code) => Key('bag.takeOff.$code');
  static Key wornKey(String code) => Key('bag.worn.$code');
  static Key lockedKey(String code) => Key('bag.locked.$code');

  @override
  ConsumerState<BagCategoryView> createState() => _BagCategoryViewState();
}

class _BagCategoryViewState extends ConsumerState<BagCategoryView> {
  /// The item being worn or taken off.
  String? _busy;

  /// What the server said is worn after the last change, until the bag
  /// reloads; `(code: null)` = nothing.
  ({String? code})? _worn;

  Future<void> _set(String busyCode, String? code) async {
    if (_busy != null) return;
    final l10n = context.l10n;
    final category = widget.category;
    setState(() => _busy = busyCode);
    try {
      final result = await ref
          .read(bagRepositoryProvider)
          .setEquipped(category, code);
      if (!mounted) return;
      setState(() => _worn = (code: result.equipped?.code));
      // The user's own card and profile show the change.
      ref
        ..invalidate(myBagProvider(category))
        ..invalidate(profileStatsProvider)
        ..invalidate(publicProfileProvider);
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      KSnack.error(context, failureMessage(l10n, failure));
      // Not owned (any more): the bag on screen is out of date.
      if (failure is ServerFailure &&
          failure.code == ErrorCode.bagItemNotOwned) {
        ref.invalidate(myBagProvider(category));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final category = widget.category;
    final catalogue = ref.watch(bagCatalogueProvider(category));
    final mine = ref.watch(myBagProvider(category));
    // Fresh data from the server replaces the remembered answer.
    ref.listen(myBagProvider(category), (_, next) {
      if (next.hasValue && !next.isLoading && _worn != null) {
        setState(() => _worn = null);
      }
    });
    return switch ((catalogue, mine)) {
      (AsyncValue(value: final c?), AsyncValue(value: final m?)) =>
        RefreshIndicator(
          onRefresh: () async {
            try {
              await Future.wait([
                ref.refresh(bagCatalogueProvider(category).future),
                ref.refresh(myBagProvider(category).future),
              ]);
            } on Object catch (e) {
              if (context.mounted) {
                KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
              }
            }
          },
          child: _content(c, m),
        ),
      (AsyncValue(:final error?, isLoading: false), _) ||
      (_, AsyncValue(:final error?, isLoading: false)) => FailureErrorState(
        title: l10n.bagLoadError,
        failure: toAppFailure(error),
        onRetry: () => ref
          ..invalidate(bagCatalogueProvider(category))
          ..invalidate(myBagProvider(category)),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _content(List<BagCatalogueItem> catalogue, List<BagItem> mine) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final owned = {for (final i in mine) i.code};
    final worn = _worn != null
        ? _worn!.code
        : mine.where((i) => i.equipped).firstOrNull?.code;
    final locked = [
      for (final i in catalogue)
        if (!owned.contains(i.code)) i,
    ];
    Widget heading(String text, {Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.only(top: KSpacing.md, bottom: KSpacing.sm),
      child: Text(text, style: t.bodyStrong.copyWith(color: p.textPrimary)),
    );
    return LayoutBuilder(
      builder: (context, box) {
        const gap = KSpacing.md;
        final inner = box.maxWidth - 2 * KSpacing.lg;
        final columns = inner >= 520 ? 3 : 2;
        final cell = (inner - gap * (columns - 1)) / columns;
        List<Widget> grid(List<Widget> cards) => [
          for (var i = 0; i < cards.length; i += columns)
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var j = 0; j < columns; j++) ...[
                      if (j > 0) const SizedBox(width: gap),
                      SizedBox(
                        width: cell,
                        child: i + j < cards.length
                            ? cards[i + j]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ];
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            KSpacing.lg,
            KSpacing.sm,
            KSpacing.lg,
            KSpacing.xl,
          ),
          children: [
            if (mine.isEmpty)
              KEmptyState(
                key: BagCategoryView.emptyKey,
                icon: Icons.backpack_outlined,
                title: l10n.bagEmptyTitle,
                message: l10n.bagEmptyMessage,
                compact: true,
              )
            else ...[
              heading(l10n.bagOwnedSection, key: BagCategoryView.ownedKey),
              ...grid([
                for (final item in mine)
                  BagItemCard(
                    key: BagCategoryView.itemKey(item.code),
                    code: item.code,
                    name: item.name,
                    width: cell,
                    state: item.code == worn
                        ? BagItemState.worn
                        : BagItemState.owned,
                    busy: _busy == item.code,
                    onPressed: _busy != null
                        ? null
                        : () => unawaited(
                            _set(
                              item.code,
                              item.code == worn ? null : item.code,
                            ),
                          ),
                  ),
              ]),
            ],
            if (locked.isNotEmpty) ...[
              heading(
                l10n.bagLockedSection,
                key: BagCategoryView.lockedSectionKey,
              ),
              ...grid([
                for (final item in locked)
                  BagItemCard(
                    key: BagCategoryView.itemKey(item.code),
                    code: item.code,
                    name: item.name,
                    width: cell,
                    state: BagItemState.locked,
                  ),
              ]),
            ],
          ],
        );
      },
    );
  }
}

/// How an item shows in the bag.
enum BagItemState { worn, owned, locked }

/// One bag item: a preview of the card's top edge with the item on it, the
/// name, and Wear / Take off ([onPressed]); a locked item is greyed with
/// "Not owned yet" and no action.
class BagItemCard extends StatelessWidget {
  const new({
    required this.code,
    required this.name,
    required this.width,
    required this.state,
    super.key,
    this.busy = false,
    this.onPressed,
  });

  final String code;
  final String name;

  /// The card's outer width.
  final double width;
  final BagItemState state;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final worn = state == BagItemState.worn;
    final locked = state == BagItemState.locked;
    const pad = KSpacing.sm;
    Widget preview = ProfileCardPreview(
      header: KabsoProfileHeader.byCode(code),
      width: width - 2 * pad,
    );
    if (locked) {
      preview = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyscale),
        child: Opacity(opacity: 0.5, child: preview),
      );
    }
    final Widget action;
    if (locked) {
      action = Row(
        key: BagCategoryView.lockedKey(code),
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: p.textTertiary),
          const SizedBox(width: KSpacing.xs),
          Expanded(
            child: Text(
              l10n.bagLocked,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: t.caption.copyWith(color: p.textTertiary),
            ),
          ),
        ],
      );
    } else {
      final style = ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(KSizes.minTouchTarget, KSizes.minTouchTarget),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: KSpacing.sm),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KRadius.sm),
          ),
        ),
        textStyle: WidgetStatePropertyAll(t.bodyStrong),
      );
      final label = busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              worn ? l10n.bagTakeOff : l10n.bagWear,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
      action = worn
          ? OutlinedButton(
              key: BagCategoryView.takeOffKey(code),
              style: style.copyWith(
                foregroundColor: WidgetStatePropertyAll(p.textPrimary),
                side: WidgetStatePropertyAll(BorderSide(color: p.border)),
              ),
              onPressed: onPressed,
              child: label,
            )
          : FilledButton(
              key: BagCategoryView.wearKey(code),
              style: style.copyWith(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.disabled)
                      ? p.primary.withValues(alpha: 0.4)
                      : p.primary,
                ),
                foregroundColor: WidgetStatePropertyAll(p.onPrimary),
              ),
              onPressed: onPressed,
              child: label,
            );
    }
    return Semantics(
      container: true,
      selected: worn,
      child: Container(
        padding: const EdgeInsets.all(pad),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(KRadius.md),
          border: Border.all(
            color: worn ? p.primary : const Color(0x00000000),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            preview,
            const SizedBox(height: KSpacing.sm),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.bodyStrong.copyWith(
                color: locked ? p.textSecondary : p.textPrimary,
              ),
            ),
            if (worn) ...[
              const SizedBox(height: KSpacing.xs),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Container(
                  key: BagCategoryView.wornKey(code),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: p.primary,
                    borderRadius: BorderRadius.circular(KRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 14, color: p.onPrimary),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          l10n.bagWorn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(color: p.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const Spacer(),
            const SizedBox(height: KSpacing.sm),
            action,
          ],
        ),
      ),
    );
  }

  static const List<double> _greyscale = [
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// A small mock-up of the person card's top edge (the live card): a white
/// card whose top edge carries [header] (its bar on the edge, as on the
/// real card) or, without one, the plain gold edge; the picture sits on
/// the edge in the middle.
class ProfileCardPreview extends StatelessWidget {
  const new({required this.header, required this.width, super.key});

  final KabsoProfileHeader? header;
  final double width;

  /// The white part under the edge.
  static const double _body = 28;

  /// The person card's gold edge (live_room_screen `_Card.gold`).
  static const _gold = [
    Color(0xFFFFE58A),
    Color(0xFFF2B84B),
    Color(0xFFD9922E),
  ];

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    // The live card's picture: 92 on a card about 360 wide.
    final avatar = width * 92 / 360;
    final edge = header == null
        ? avatar / 2 + 4
        : math.max(avatar / 2, header.overhang(width));
    return ClipRRect(
      borderRadius: BorderRadius.circular(KRadius.sm),
      child: SizedBox(
        width: width,
        height: edge + _body,
        child: Stack(
          children: [
            Positioned(
              top: edge,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(top: header == null ? 2 : 0),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  gradient: LinearGradient(colors: _gold),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                  ),
                ),
              ),
            ),
            if (header != null)
              Positioned(
                top: edge - header.overhang(width),
                left: 0,
                child: KabsoProfileHeaderArt(header, width: width),
              ),
            Positioned(
              top: edge - avatar / 2,
              left: (width - avatar) / 2,
              child: Container(
                width: avatar,
                height: avatar,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: _gold),
                ),
                padding: const EdgeInsets.all(2),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE6E6EA),
                  ),
                  child: Icon(Icons.person_rounded, color: Color(0xFFB4B5BD)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
