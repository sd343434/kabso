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

/// `/bag` (CP-019, D107; D171, CONVENTIONS §10.43): only the items the user
/// owns now — bought, given by Kabso or sent by someone — grouped by
/// category (a category the app does not know yet still shows, as «other
/// items»). Each item: a preview, its name, where it came from, the time
/// left («متبقٍ …», «ينتهي اليوم», «دائم»), «ارتداء» / «إزالة» and «إرسال».
/// The time line follows the clock (a minute tick); an item that runs out
/// on screen leaves it and the bag reloads.
class BagScreen extends ConsumerStatefulWidget {
  const new({super.key});

  static const emptyKey = Key('bag.empty');

  static Key sectionKey(String category) => Key('bag.section.$category');
  static Key itemKey(String code) => Key('bag.item.$code');
  static Key wearKey(String code) => Key('bag.wear.$code');
  static Key takeOffKey(String code) => Key('bag.takeOff.$code');
  static Key wornKey(String code) => Key('bag.worn.$code');
  static Key sendKey(String code) => Key('bag.send.$code');
  static Key timeKey(String code) => Key('bag.time.$code');
  static Key sourceKey(String code) => Key('bag.source.$code');
  static Key noSendKey(String code) => Key('bag.noSend.$code');

  @override
  ConsumerState<BagScreen> createState() => _BagScreenState();
}

class _BagScreenState extends ConsumerState<BagScreen> {
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

  Future<void> _setWorn(BagItem item, String? code) async {
    if (_busy != null) return;
    final l10n = context.l10n;
    setState(() => _busy = item.code);
    try {
      final result = await ref
          .read(bagRepositoryProvider)
          .setEquipped(item.category, code);
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
    _worn.remove(item.category);
    _refreshEverywhere();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final mine = ref.watch(myBagItemsProvider);
    ref.listen(myBagItemsProvider, (_, next) {
      if (next.hasValue && !next.isLoading) {
        if (_worn.isNotEmpty) setState(_worn.clear);
      }
    });
    return Scaffold(
      backgroundColor: p.background,
      appBar: KAppBar(
        backgroundColor: p.background,
        centerTitle: true,
        title: Text(l10n.bagTitle),
      ),
      body: switch (mine) {
        AsyncValue(value: final items?) => RefreshIndicator(
          onRefresh: () async {
            try {
              await Future.wait([ref.refresh(myBagItemsProvider.future)]);
            } on Object catch (e) {
              if (context.mounted) {
                KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
              }
            }
          },
          child: _content(items),
        ),
        AsyncValue(:final error?, isLoading: false) => FailureErrorState(
          title: l10n.bagLoadError,
          failure: toAppFailure(error),
          onRetry: () => ref.invalidate(myBagItemsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _content(List<BagItem> all) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final now = clock.now();
    // An item that ran out while the screen was open leaves it (the
    // server no longer lists it either).
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
    // Known categories first, in the app's order; then any other.
    final order = <String>{
      for (final c in BagCategory.values)
        if (items.any((i) => i.category == c.wire)) c.wire,
      for (final i in items)
        if (BagCategory.fromWire(i.category) == null) i.category,
    }.toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        KSpacing.lg,
        KSpacing.sm,
        KSpacing.lg,
        KSpacing.xl,
      ),
      children: [
        if (items.isEmpty)
          KEmptyState(
            key: BagScreen.emptyKey,
            icon: Icons.backpack_outlined,
            title: l10n.bagEmptyTitle,
            message: l10n.bagEmptyMessage,
            compact: true,
          ),
        for (final category in order) ...[
          Padding(
            key: BagScreen.sectionKey(category),
            padding: const EdgeInsets.only(
              top: KSpacing.md,
              bottom: KSpacing.sm,
            ),
            child: Text(
              bagCategoryTitle(l10n, category),
              style: t.bodyStrong.copyWith(color: p.textPrimary),
            ),
          ),
          for (final item in items.where((i) => i.category == category))
            Padding(
              padding: const EdgeInsets.only(bottom: KSpacing.md),
              child: BagItemCard(
                key: BagScreen.itemKey(item.code),
                item: item,
                now: now,
                worn: _worn.containsKey(category)
                    ? _worn[category] == item.code
                    : item.equipped,
                busy: _busy == item.code,
                onWear: _busy != null
                    ? null
                    : ({required worn}) =>
                          unawaited(_setWorn(item, worn ? null : item.code)),
                onSend: _busy != null || !item.transferable
                    ? null
                    : () => unawaited(_send(item)),
              ),
            ),
        ],
      ],
    );
  }
}

/// One owned item (D171): the preview on the reading start; the name,
/// where it came from, the time left, the worn mark, and «ارتداء» /
/// «إزالة» beside «إرسال» (off, with the reason, for an item that cannot
/// be sent).
class BagItemCard extends StatelessWidget {
  const new({
    required this.item,
    required this.now,
    required this.worn,
    super.key,
    this.busy = false,
    this.onWear,
    this.onSend,
  });

  final BagItem item;
  final DateTime now;
  final bool worn;
  final bool busy;

  /// Called with whether the item is worn now (true → take it off).
  final void Function({required bool worn})? onWear;
  final VoidCallback? onSend;

  /// The preview's width.
  static const double previewWidth = 104;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final code = item.code;
    final source = bagSourceLine(l10n, item);
    final noSend = bagNoSendReason(l10n, item);
    final time = bagTimeLeft(l10n, item.expiresAt, now);
    final endsSoon =
        item.expiresAt != null &&
        item.expiresAt!.difference(now) < const Duration(days: 1);
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(KSizes.minTouchTarget, KSizes.minTouchTarget),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: KSpacing.sm),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(KRadius.sm)),
      ),
      textStyle: WidgetStatePropertyAll(t.bodyStrong),
    );
    Widget label(String text) => busy
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
    final wear = worn
        ? OutlinedButton(
            key: BagScreen.takeOffKey(code),
            style: buttonStyle.copyWith(
              foregroundColor: WidgetStatePropertyAll(p.textPrimary),
              side: WidgetStatePropertyAll(BorderSide(color: p.border)),
            ),
            onPressed: onWear == null ? null : () => onWear!(worn: true),
            child: label(l10n.bagTakeOff),
          )
        : FilledButton(
            key: BagScreen.wearKey(code),
            style: buttonStyle.copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled)
                    ? p.primary.withValues(alpha: 0.4)
                    : p.primary,
              ),
              foregroundColor: WidgetStatePropertyAll(p.onPrimary),
            ),
            onPressed: onWear == null ? null : () => onWear!(worn: false),
            child: label(l10n.bagWear),
          );
    final send = OutlinedButton(
      key: BagScreen.sendKey(code),
      style: buttonStyle.copyWith(
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? p.textTertiary : p.primary,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: p.border)),
      ),
      onPressed: onSend,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.send_rounded, size: 16),
          const SizedBox(width: KSpacing.xs),
          Flexible(
            child: Text(
              l10n.bagSend,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      container: true,
      selected: worn,
      child: Container(
        padding: const EdgeInsets.all(KSpacing.sm),
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(KRadius.md),
          border: Border.all(
            color: worn ? p.primary : const Color(0x00000000),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BagItemPreview(item: item, width: previewWidth),
            const SizedBox(width: KSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyStrong.copyWith(color: p.textPrimary),
                        ),
                      ),
                      if (worn) ...[
                        const SizedBox(width: KSpacing.xs),
                        Flexible(
                          child: _WornMark(key: BagScreen.wornKey(code)),
                        ),
                      ],
                    ],
                  ),
                  if (source != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      source,
                      key: BagScreen.sourceKey(code),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: p.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        item.expiresAt == null
                            ? Icons.all_inclusive_rounded
                            : Icons.schedule_rounded,
                        size: 14,
                        color: endsSoon ? p.error : p.textSecondary,
                      ),
                      const SizedBox(width: KSpacing.xs),
                      Expanded(
                        child: Text(
                          time,
                          key: BagScreen.timeKey(code),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            color: endsSoon ? p.error : p.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.sm),
                  Row(
                    children: [
                      Expanded(child: wear),
                      const SizedBox(width: KSpacing.sm),
                      Expanded(child: send),
                    ],
                  ),
                  if (noSend != null) ...[
                    const SizedBox(height: KSpacing.xs),
                    Text(
                      noSend,
                      key: BagScreen.noSendKey(code),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: t.caption.copyWith(color: p.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WornMark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm, vertical: 2),
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
              context.l10n.bagWorn,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(color: p.onPrimary),
            ),
          ),
        ],
      ),
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
        Icons.auto_awesome_rounded,
        color: p.textTertiary,
        size: width * 0.25,
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
