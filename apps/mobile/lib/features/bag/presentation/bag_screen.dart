import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/bag/application/bag_providers.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';
import 'package:kabso_live/features/bag/presentation/bag_labels.dart';
import 'package:kabso_live/features/bag/presentation/bag_send_sheet.dart';
import 'package:kabso_live/features/profile/application/profile_grid_provider.dart';
import 'package:kabso_live/features/profile/application/public_profile_controller.dart';
import 'package:kabso_live/features/profile_card/kabso_profile_header.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Geometry of the bag (D180, owner «أريد الحقيبة بنفس التصميم ١٠٠٪»:
/// the layout of the owner's reference, measured in logical pixels).
abstract final class KBagMetrics {
  /// The top bar: the reference's 44-lp navigation bar.
  static const double toolbar = 44;

  /// The grey section bands («قيد الاستخدام», «كل الأدوات»).
  static const double band = 43;
  static const double bandStart = 17;

  /// The «قيد الاستخدام» row: a column per category.
  static const double inUseHeight = 159;
  static const double inUseColumn = 120;
  static const double inUsePreview = 59;

  /// A category title of «كل الأدوات»: the accent bar and the text start.
  static const double titleHeight = 66;
  static const double accentStart = 14;
  static const double accentWidth = 3.3;
  static const double accentHeight = 17;
  static const double titleStart = 25.6;

  /// A tile: four per row; the picture, its glyph badge, two lines.
  static const int columns = 4;
  static const double tilePreview = 56;
  static const double tileBadge = 12;
  static const double tileHeight = 98;

  /// The bottom bar and its pills.
  static const double bar = 47.5;
  static const double pillWidth = 81.5;
  static const double pillHeight = 28;

  /// The tab indicator: a short rounded bar under the label.
  static const Size indicator = Size(7.5, 2.5);
}

/// `/bag` (CP-019, D107; D171 behaviour; D180 layout): two tabs.
///
/// The bag holds only the wearable items the user owns (owner: entrances,
/// frames and the like — every bag category; profile cards today), never
/// live gifts. The two tabs split them without repeating content:
///
/// «الأدوات» (Tools): «قيد الاستخدام» — one column per category with the
/// item worn now (or an empty slot); tapping one selects it.
///
/// «الحقيبة» (Item Bag): «كل الأدوات» — every owned item by category as
/// tiles (picture, category glyph, name, time left «31 يوماً» / «دائم»);
/// tapping one selects it.
///
/// The bottom bar (both tabs) names the selection with where it came from
/// and offers «استخدام» / «إزالة» and «إرسال» (D171's send sheet).
class BagScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const toolsTabKey = Key('bag.tab.tools');
  static const itemsTabKey = Key('bag.tab.items');
  static const emptyKey = Key('bag.empty');
  static const inUseKey = Key('bag.inUse');
  static const useKey = Key('bag.use');
  static const takeOffKey = Key('bag.takeOff');
  static const sendKey = Key('bag.send');
  static const selectedNameKey = Key('bag.selected.name');
  static const selectedSourceKey = Key('bag.selected.source');
  static const noSendKey = Key('bag.selected.noSend');

  static Key sectionKey(String category) => Key('bag.section.$category');
  static Key slotKey(String category) => Key('bag.slot.$category');
  static Key emptySlotKey(String category) => Key('bag.slot.empty.$category');
  static Key itemKey(String code) => Key('bag.item.$code');
  static Key wornKey(String code) => Key('bag.worn.$code');
  static Key timeKey(String code) => Key('bag.time.$code');

  @override
  ConsumerState<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends ConsumerState<BagScreen> {
  /// The selected tile.
  String? _selected;

  /// The item being worn, taken off or sent.
  String? _busy;

  /// What the server said is worn after the last change, per category,
  /// until the bag reloads (`null` = nothing).
  final Map<String, String?> _worn = {};

  Timer? _tick;

  /// Items seen running out here; the bag is reloaded once for each.
  final Set<String> _ranOut = {};

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _refreshEverywhere() => ref
    ..invalidate(myBagItemsProvider)
    ..invalidate(profileStatsProvider)
    ..invalidate(publicProfileProvider);

  bool _isWorn(BagItem item) => _worn.containsKey(item.category)
      ? _worn[item.category] == item.code
      : item.equipped;

  Future<void> _setWorn(BagItem item, {required bool wear}) async {
    if (_busy != null) return;
    final l10n = context.l10n;
    setState(() => _busy = item.code);
    try {
      final result = await ref
          .read(bagRepositoryProvider)
          .setEquipped(item.category, wear ? item.code : null);
      if (!mounted) return;
      setState(() => _worn[item.category] = result.equipped?.code);
      _refreshEverywhere();
    } on Object catch (e) {
      if (!mounted) return;
      final failure = toAppFailure(e);
      KSnack.error(context, failureMessage(l10n, failure));
      if (failure is ServerFailure &&
          failure.code == ErrorCode.bagItemNotOwned) {
        ref.invalidate(myBagItemsProvider);
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _send(BagItem item) async {
    if (_busy != null) return;
    final l10n = context.l10n;
    final sent = await showBagSendSheet(context, item);
    if (sent == null || !mounted) return;
    KSnack.success(
      context,
      l10n.bagSendDone(bagRecipientHandle(l10n, sent.recipient)),
    );
    setState(() {
      _worn.remove(item.category);
      if (sent.whole) _selected = null;
    });
    _refreshEverywhere();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final mine = ref.watch(myBagItemsProvider);
    ref.listen(myBagItemsProvider, (_, next) {
      if (next.hasValue && !next.isLoading && _worn.isNotEmpty) {
        setState(_worn.clear);
      }
    });
    final items = _live(mine.value ?? const []);
    final selected = items.where((i) => i.code == _selected).firstOrNull;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: p.background,
        appBar: KAppBar(
          backgroundColor: p.background,
          centerTitle: true,
          toolbarHeight: KBagMetrics.toolbar,
          title: Text(l10n.bagTitle),
          bottom: TabBar(
            labelStyle: t.title.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelStyle: t.title.copyWith(fontWeight: FontWeight.w400),
            labelColor: p.textPrimary,
            unselectedLabelColor: p.textTertiary,
            dividerColor: const Color(0x00000000),
            indicator: _BarIndicator(color: p.textPrimary),
            tabs: [
              Tab(key: BagScreen.toolsTabKey, text: l10n.bagTabTools),
              Tab(key: BagScreen.itemsTabKey, text: l10n.bagTabItems),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [_page(mine, _toolsTab), _page(mine, _bagTab)],
              ),
            ),
            _SelectionBar(
              item: selected,
              worn: selected != null && _isWorn(selected),
              busy: _busy != null,
              onUse: selected == null
                  ? null
                  : () =>
                        unawaited(_setWorn(selected, wear: !_isWorn(selected))),
              onSend: selected == null || !selected.transferable
                  ? null
                  : () => unawaited(_send(selected)),
            ),
          ],
        ),
      ),
    );
  }

  /// One tab's page: the owned items when loaded (pull to refresh), the
  /// error with retry, or the progress.
  Widget _page(
    AsyncValue<List<BagItem>> mine,
    Widget Function(List<BagItem> items) build,
  ) {
    final l10n = context.l10n;
    return switch (mine) {
      AsyncValue(:final value?) => RefreshIndicator(
        onRefresh: () async {
          try {
            await Future.wait([ref.refresh(myBagItemsProvider.future)]);
          } on Object catch (e) {
            if (mounted) {
              KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
            }
          }
        },
        child: build(_live(value)),
      ),
      AsyncValue(:final error?, isLoading: false) => FailureErrorState(
        title: l10n.bagLoadError,
        failure: toAppFailure(error),
        onRetry: () => ref.invalidate(myBagItemsProvider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  /// Known categories first, in the app's order; then any other.
  List<String> _ownedCategories(List<BagItem> items) => <String>{
    for (final c in BagCategory.values)
      if (items.any((i) => i.category == c.wire)) c.wire,
    for (final i in items) i.category,
  }.toList();

  Widget _empty() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(KSpacing.lg),
      child: KEmptyState(
        key: BagScreen.emptyKey,
        icon: Icons.backpack_outlined,
        title: l10n.bagEmptyTitle,
        message: l10n.bagEmptyMessage,
        compact: true,
      ),
    );
  }

  /// [all] without the items that ran out while the screen was open (the
  /// server no longer lists them either); asks for a reload once.
  List<BagItem> _live(List<BagItem> all) {
    final now = clock.now();
    final items = [
      for (final i in all)
        if (i.expiresAt == null || i.expiresAt!.isAfter(now)) i,
    ];
    final gone = {
      for (final i in all)
        if (!items.contains(i)) '${i.code}@${i.expiresAt}',
    };
    if (!_ranOut.containsAll(gone)) {
      _ranOut.addAll(gone);
      scheduleMicrotask(() {
        if (mounted) ref.invalidate(myBagItemsProvider);
      });
    }
    return items;
  }

  /// «الأدوات»: what is worn now, one column per category (tap one to
  /// select it: the bar takes it off or sends it).
  Widget _toolsTab(List<BagItem> items) {
    final l10n = context.l10n;
    final slots = <String>{
      for (final c in BagCategory.values) c.wire,
      ..._ownedCategories(items),
    }.toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _Band(l10n.bagInUse),
        SizedBox(
          key: BagScreen.inUseKey,
          // Taller with larger text (the category and the name grow).
          height:
              KBagMetrics.inUseHeight +
              MediaQuery.textScalerOf(context).scale(44) -
              44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: slots.length,
            separatorBuilder: (context, _) => Padding(
              padding: const EdgeInsets.only(
                top: 50,
                bottom: KBagMetrics.inUseHeight - 50 - KBagMetrics.inUsePreview,
              ),
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: context.palette.border,
              ),
            ),
            itemBuilder: (context, i) {
              final category = slots[i];
              final worn = items
                  .where((x) => x.category == category && _isWorn(x))
                  .firstOrNull;
              return _InUseSlot(
                category: category,
                item: worn,
                onTap: worn == null
                    ? null
                    : () => setState(() => _selected = worn.code),
              );
            },
          ),
        ),
        if (items.isEmpty) _empty(),
      ],
    );
  }

  /// «الحقيبة»: every item the user owns, by category, as tiles (tap one
  /// to select it: the bar wears, takes off or sends it).
  Widget _bagTab(List<BagItem> items) {
    final l10n = context.l10n;
    final now = clock.now();
    final owned = _ownedCategories(items);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        _Band(l10n.bagAllTools),
        if (items.isEmpty) _empty(),
        for (final category in owned) ...[
          _CategoryTitle(
            key: BagScreen.sectionKey(category),
            text: bagCategoryTitle(l10n, category),
          ),
          _TileGrid(
            children: [
              for (final item in items.where((i) => i.category == category))
                _ToolTile(
                  key: BagScreen.itemKey(item.code),
                  item: item,
                  now: now,
                  worn: _isWorn(item),
                  selected: item.code == _selected,
                  onTap: () => setState(
                    () => _selected = _selected == item.code ? null : item.code,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: KSpacing.lg),
      ],
    );
  }
}

/// A grey section band with its bold title at the reading start.
class _Band extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      constraints: const BoxConstraints(minHeight: KBagMetrics.band),
      color: p.surface,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: KBagMetrics.bandStart,
        vertical: KSpacing.xs,
      ),
      child: Text(
        text,
        style: context.textStyles.title.copyWith(
          color: p.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A category title of «كل الأدوات»: a short accent bar, then the name.
class _CategoryTitle extends StatelessWidget {
  const new({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: KBagMetrics.titleHeight),
      child: Row(
        children: [
          const SizedBox(width: KBagMetrics.accentStart),
          Container(
            width: KBagMetrics.accentWidth,
            height: KBagMetrics.accentHeight,
            decoration: BoxDecoration(
              color: p.primary,
              borderRadius: BorderRadius.circular(KBagMetrics.accentWidth),
            ),
          ),
          const SizedBox(
            width:
                KBagMetrics.titleStart -
                KBagMetrics.accentStart -
                KBagMetrics.accentWidth,
          ),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.title.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: KSpacing.lg),
        ],
      ),
    );
  }
}

/// Four tiles per row (each a quarter of the width).
class _TileGrid extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const n = KBagMetrics.columns;
    return Column(
      children: [
        for (var i = 0; i < children.length; i += n)
          Padding(
            padding: const EdgeInsets.only(bottom: KSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var j = i; j < i + n; j++)
                  Expanded(
                    child: j < children.length
                        ? children[j]
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The glyph of a category, on the top-end corner of its tiles.
IconData bagCategoryGlyph(String category) =>
    switch (BagCategory.fromWire(category)) {
      BagCategory.profileCard => Icons.badge_rounded,
      null => Icons.auto_awesome_rounded,
    };

/// A tile's time: «31 يوماً», «5 ساعات», «دائم».
String bagTileTime(AppLocalizations l10n, DateTime? expiresAt, DateTime now) {
  if (expiresAt == null) return l10n.bagPermanent;
  final left = expiresAt.difference(now);
  return left.inDays >= 1
      ? l10n.bagDays(left.inDays)
      : bagDurationText(l10n, left);
}

/// One item of «كل الأدوات».
class _ToolTile extends StatelessWidget {
  const new({
    required this.item,
    required this.now,
    required this.worn,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final BagItem item;
  final DateTime now;
  final bool worn;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final endsSoon =
        item.expiresAt != null &&
        item.expiresAt!.difference(now) < const Duration(days: 1);
    return Semantics(
      button: true,
      selected: selected,
      label: [
        item.name,
        if (worn) l10n.bagWorn,
        bagTileTime(l10n, item.expiresAt, now),
      ].join('، '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KRadius.sm),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
          padding: const EdgeInsets.symmetric(vertical: KSpacing.xs),
          constraints: const BoxConstraints(minHeight: KBagMetrics.tileHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KRadius.sm),
            border: Border.all(
              color: selected ? p.primary : const Color(0x00000000),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              SizedBox(
                height: KBagMetrics.tilePreview,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: SizedBox.square(
                        dimension: KBagMetrics.tilePreview,
                        child: FittedBox(
                          child: BagItemPreview(
                            item: item,
                            width: KBagMetrics.tilePreview,
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: KSpacing.xs,
                      child: Container(
                        width: KBagMetrics.tileBadge,
                        height: KBagMetrics.tileBadge,
                        decoration: BoxDecoration(
                          color: p.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Icon(
                          bagCategoryGlyph(item.category),
                          size: 9,
                          color: p.onPrimary,
                        ),
                      ),
                    ),
                    if (worn)
                      PositionedDirectional(
                        bottom: 0,
                        start: KSpacing.xs,
                        child: Container(
                          key: BagScreen.wornKey(item.code),
                          padding: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: p.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 10,
                            color: p.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: KSpacing.sm),
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: t.caption.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.expiresAt == null
                        ? Icons.all_inclusive_rounded
                        : Icons.schedule_rounded,
                    size: 11,
                    color: endsSoon ? p.error : p.textSecondary,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      bagTileTime(l10n, item.expiresAt, now),
                      key: BagScreen.timeKey(item.code),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(
                        fontSize: (t.caption.fontSize ?? 12) - 1,
                        color: endsSoon ? p.error : p.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One column of «قيد الاستخدام»: the category, the worn item's picture
/// and name — or an empty slot.
class _InUseSlot extends StatelessWidget {
  const new({required this.category, required this.item, this.onTap});

  final String category;
  final BagItem? item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final item = this.item;
    return InkWell(
      key: BagScreen.slotKey(category),
      onTap: onTap,
      child: SizedBox(
        width: KBagMetrics.inUseColumn,
        child: Column(
          children: [
            const SizedBox(height: 16),
            SizedBox(
              height: MediaQuery.textScalerOf(context).scale(22),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  bagCategoryTitle(l10n, category),
                  maxLines: 1,
                  style: t.body.copyWith(color: p.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: KBagMetrics.inUsePreview,
              child: item == null
                  ? Center(
                      child: Container(
                        key: BagScreen.emptySlotKey(category),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(KRadius.sm),
                          border: Border.all(color: p.border),
                        ),
                        child: Icon(
                          bagCategoryGlyph(category),
                          color: p.textTertiary,
                          size: 20,
                        ),
                      ),
                    )
                  : FittedBox(
                      child: BagItemPreview(
                        item: item,
                        width: KBagMetrics.inUseColumn - KSpacing.lg,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.xs),
              child: Text(
                item?.name ?? l10n.bagNothingWorn,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.body.copyWith(color: p.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The bottom bar: the selected item (its name, where it came from, why it
/// cannot be sent) at the reading start; «إرسال» and «استخدام» / «إزالة»
/// at the end, off while nothing is selected.
class _SelectionBar extends StatelessWidget {
  const new({
    required this.item,
    required this.worn,
    required this.busy,
    this.onUse,
    this.onSend,
  });

  final BagItem? item;
  final bool worn;
  final bool busy;
  final VoidCallback? onUse;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final item = this.item;
    final source = item == null ? null : bagSourceLine(l10n, item);
    final noSend = item == null ? null : bagNoSendReason(l10n, item);
    final pillShape = WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadius.pill)),
    );
    const pillSize = WidgetStatePropertyAll(
      Size(KBagMetrics.pillWidth, KBagMetrics.pillHeight),
    );
    const pillPadding = WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: KSpacing.md),
    );
    Widget label(String text) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.bodyStrong,
    );
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KBagMetrics.bar),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: KSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: item == null
                      ? const SizedBox.shrink()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              key: BagScreen.selectedNameKey,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodyStrong.copyWith(
                                color: p.textPrimary,
                              ),
                            ),
                            if (source != null)
                              Text(
                                source,
                                key: BagScreen.selectedSourceKey,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.caption,
                              ),
                            if (noSend != null)
                              Text(
                                noSend,
                                key: BagScreen.noSendKey,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: t.caption.copyWith(
                                  color: p.textTertiary,
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(width: KSpacing.sm),
                Flexible(
                  child: OutlinedButton(
                    key: BagScreen.sendKey,
                    style: ButtonStyle(
                      shape: pillShape,
                      minimumSize: pillSize,
                      padding: pillPadding,
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.disabled)
                            ? p.textTertiary
                            : p.primary,
                      ),
                      side: WidgetStateProperty.resolveWith(
                        (s) => BorderSide(
                          color: s.contains(WidgetState.disabled)
                              ? p.border
                              : p.primary,
                        ),
                      ),
                    ),
                    onPressed: busy ? null : onSend,
                    child: label(l10n.bagSend),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                Flexible(
                  child: FilledButton(
                    key: worn ? BagScreen.takeOffKey : BagScreen.useKey,
                    style: ButtonStyle(
                      shape: pillShape,
                      minimumSize: pillSize,
                      padding: pillPadding,
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.disabled)
                            ? p.primary.withValues(alpha: 0.35)
                            : p.primary,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.disabled)
                            ? p.onPrimary.withValues(alpha: 0.8)
                            : p.onPrimary,
                      ),
                    ),
                    onPressed: busy ? null : onUse,
                    child: busy && item != null
                        ? SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: p.onPrimary,
                            ),
                          )
                        : label(worn ? l10n.bagTakeOff : l10n.bagUse),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The tab indicator: a short rounded bar centred under the label.
class _BarIndicator extends Decoration {
  const new({required this.color});

  final Color color;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _BarPainter(color);
}

class _BarPainter extends BoxPainter {
  new(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    const bar = KBagMetrics.indicator;
    final rect = Rect.fromLTWH(
      offset.dx + (size.width - bar.width) / 2,
      offset.dy + size.height - bar.height - 4,
      bar.width,
      bar.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(bar.height)),
      Paint()..color = color,
    );
  }
}

/// The picture of an item: a profile card shows the card's top edge with
/// it ([ProfileCardPreview]); a category this app does not draw yet shows a
/// neutral tile.
class BagItemPreview extends StatelessWidget {
  const new({required this.item, required this.width, super.key});

  final BagItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (BagCategory.fromWire(item.category) == BagCategory.profileCard) {
      return ProfileCardPreview(
        header: KabsoProfileHeader.byCode(item.code),
        width: width,
      );
    }
    final p = context.palette;
    return Container(
      width: width,
      height: width * 0.6,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(KRadius.sm),
      ),
      child: Icon(
        bagCategoryGlyph(item.category),
        color: p.textTertiary,
        size: width * 0.3,
      ),
    );
  }
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
