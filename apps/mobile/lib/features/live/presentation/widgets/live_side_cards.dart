import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D136/D137: where the two floating cards of a video live sit (ref 158 §2,
/// measured at 393 pt on a 59 pt inset): the wish list at the reading
/// start, its top 207.5 pt under the top inset, 16.2 pt from the edge; the
/// promo box at the end, 9.8 pt from the edge, its top 72 pt under the
/// inset (ref 62.3 pt; D135 moved the top rows below the status bar, so it
/// starts under the chips row).
abstract final class KLiveSideCards {
  static const double wishTop = 207.5;
  static const double wishStart = 16.2;
  static const double promoTop = 72;
  static const double promoEnd = 9.8;
}

/// D136 (owner, ref 158 R5): the host's wish list — a see-through card of
/// up to 4 rows, each the gift's picture, its name and how many of it the
/// host received in this live. Viewers tap a row to open the gift panel
/// with that gift ([onWish]); the host taps the card to change it
/// ([onEdit]). Nothing when the list is empty.
class LiveWishCard extends StatelessWidget {
  const new({required this.wishes, super.key, this.onWish, this.onEdit});

  final List<LiveWishGift> wishes;
  final ValueChanged<LiveWishGift>? onWish;
  final VoidCallback? onEdit;

  /// Ref 158 R5: 94.5 pt wide, rows 33 pt apart, a 22 pt picture.
  static const double width = 94.5;
  static const double row = 33;
  static const double picture = 22;
  static const double radius = 8;

  static const cardKey = Key('live.wishCard');
  static Key rowKey(String code) => Key('live.wishCard.$code');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (wishes.isEmpty) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final rows = <Widget>[
      for (final (i, w) in wishes.take(4).indexed) ...[
        if (i > 0) const Divider(height: 0.5, thickness: 0.5, color: _divider),
        Semantics(
          button: onWish != null,
          label: l10n.liveWishRowLabel(w.name, KFormat.grouped(w.received)),
          excludeSemantics: true,
          child: GestureDetector(
            key: rowKey(w.giftCode),
            behavior: HitTestBehavior.opaque,
            onTap: onWish == null ? null : () => onWish!(w),
            child: SizedBox(
              height: row,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 5, end: 6),
                child: Row(
                  children: [
                    KGiftImage(w.assetKey, imageUrl: w.imageUrl, size: picture),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        w.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: scaler,
                        style: context.textStyles.caption.copyWith(
                          fontSize: 11,
                          height: 1.2,
                          color: const Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w700,
                          shadows: KLiveColors.glassShadow,
                        ),
                      ),
                    ),
                    if (w.received > 0)
                      Text(
                        '×${KFormat.compact(w.received, l10n)}',
                        textDirection: TextDirection.ltr,
                        textScaler: scaler,
                        style: context.textStyles.caption.copyWith(
                          fontSize: 9.5,
                          height: 1.2,
                          color: const Color(0xFFFFD66B),
                          fontWeight: FontWeight.w800,
                          shadows: KLiveColors.glassShadow,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ];
    final card = Container(
      key: cardKey,
      width: width,
      decoration: BoxDecoration(
        color: KLiveColors.glass,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
    final onEdit = this.onEdit;
    if (onEdit == null) {
      return Semantics(
        container: true,
        label: l10n.liveWishCardLabel,
        child: card,
      );
    }
    return Semantics(
      button: true,
      label: '${l10n.liveWishCardLabel}. ${l10n.liveWishEditLabel}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onEdit,
        child: AbsorbPointer(child: card),
      ),
    );
  }

  static const _divider = Color(0x26FFFFFF);
}

/// D136: the host chooses up to 4 gifts of the catalogue for the wish list,
/// orders and removes them, then saves ([onSave] throws an `AppFailure`).
Future<void> showLiveWishSheet(
  BuildContext context, {
  required List<String> initial,
  required Future<void> Function(List<String> codes) onSave,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0x00000000),
  builder: (_) => _WishSheet(initial: initial, onSave: onSave),
);

class _WishSheet extends ConsumerStatefulWidget {
  const new({required this.initial, required this.onSave});

  final List<String> initial;
  final Future<void> Function(List<String> codes) onSave;

  @override
  ConsumerState<_WishSheet> createState() => _WishSheetState();
}

abstract final class LiveWishSheetKeys {
  static const sheet = Key('live.wishSheet');
  static const save = Key('live.wishSheet.save');
  static Key gift(String code) => Key('live.wishSheet.gift.$code');
  static Key remove(String code) => Key('live.wishSheet.remove.$code');
  static Key earlier(String code) => Key('live.wishSheet.earlier.$code');
}

class _WishSheetState extends ConsumerState<_WishSheet> {
  late final List<String> _chosen = [...widget.initial.take(4)];
  bool _saving = false;

  static const _bg = Color(0xFF242226);
  static const _cell = Color(0xFF35393A);
  static const _soft = Color(0xFFAFAEB1);
  static const _accent = Color(0xFF26E4DA);

  void _toggle(String code) {
    final l10n = context.l10n;
    setState(() {
      if (!_chosen.remove(code)) {
        if (_chosen.length >= 4) {
          KSnack.info(context, l10n.liveWishFull);
          return;
        }
        _chosen.add(code);
      }
    });
  }

  void _earlier(String code) => setState(() {
    final i = _chosen.indexOf(code);
    if (i <= 0) return;
    _chosen
      ..removeAt(i)
      ..insert(i - 1, code);
  });

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave([..._chosen]);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      KSnack.error(context, failureMessage(context.l10n, toAppFailure(e)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final catalogue = ref.watch(giftCatalogueProvider).value;
    final gifts = catalogue?.data ?? const <Gift>[];
    Gift? byCode(String code) => catalogue?.byCode(code);
    final height = MediaQuery.sizeOf(context).height * 0.62;
    return Container(
      key: LiveWishSheetKeys.sheet,
      height: height,
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.liveWishTitle,
                  style: text.title.copyWith(
                    color: const Color(0xFFFFFFFF),
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.liveWishHint,
                style: text.caption.copyWith(color: _soft),
              ),
              const SizedBox(height: 12),
              // The chosen gifts, in order (the first is the top row).
              SizedBox(
                height: 72,
                child: Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      Expanded(
                        child: i < _chosen.length
                            ? _chosenSlot(i, byCode(_chosen[i]))
                            : _emptySlot(i),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: gifts.isEmpty
                    ? Center(
                        child: Text(
                          l10n.liveGiftEmptyTitle,
                          style: text.body.copyWith(color: _soft),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisExtent: 92,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                            ),
                        itemCount: gifts.length,
                        itemBuilder: (context, i) => _giftCell(gifts[i]),
                      ),
              ),
              const SizedBox(height: 8),
              KButton(
                key: LiveWishSheetKeys.save,
                label: l10n.liveWishSave,
                loading: _saving,
                onPressed: _saving ? null : () => unawaited(_save()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _giftCell(Gift gift) {
    final l10n = context.l10n;
    final order = _chosen.indexOf(gift.code);
    final chosen = order >= 0;
    return Semantics(
      button: true,
      selected: chosen,
      label: gift.name,
      excludeSemantics: true,
      child: GestureDetector(
        key: LiveWishSheetKeys.gift(gift.code),
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggle(gift.code),
        child: Container(
          decoration: BoxDecoration(
            color: chosen ? _cell : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: chosen ? _accent : const Color(0x00000000),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    KGiftImage(gift.assetKey, imageUrl: gift.imageUrl),
                    const SizedBox(height: 4),
                    Text(
                      gift.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.caption.copyWith(
                        color: const Color(0xFFFFFFFF),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (chosen)
                PositionedDirectional(
                  top: 4,
                  start: 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      KFormat.grouped(order + 1),
                      style: context.textStyles.caption.copyWith(
                        fontSize: 10,
                        height: 1,
                        color: const Color(0xFF0B2B2A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              if (!chosen && _chosen.length >= 4)
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: ColoredBox(
                      color: const Color(0x66242226),
                      child: Semantics(label: l10n.liveWishFull),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptySlot(int i) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Center(
        child: Text(
          KFormat.grouped(i + 1),
          style: context.textStyles.caption.copyWith(color: _soft),
        ),
      ),
    ),
  );

  Widget _chosenSlot(int i, Gift? gift) {
    final l10n = context.l10n;
    final code = _chosen[i];
    final name = gift?.name ?? code;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Container(
        decoration: BoxDecoration(
          color: _cell,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Center(
              child: KGiftImage(
                gift?.assetKey ?? 'gift_$code',
                imageUrl: gift?.imageUrl,
                size: 40,
              ),
            ),
            PositionedDirectional(
              top: 0,
              end: 0,
              child: _SmallButton(
                key: LiveWishSheetKeys.remove(code),
                icon: Icons.close_rounded,
                label: l10n.liveWishRemove(name),
                onTap: () => setState(() => _chosen.removeAt(i)),
              ),
            ),
            if (i > 0)
              PositionedDirectional(
                bottom: 0,
                start: 0,
                child: _SmallButton(
                  key: LiveWishSheetKeys.earlier(code),
                  icon: Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  label: l10n.liveWishMoveEarlier(name),
                  onTap: () => _earlier(code),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        dimension: 28,
        child: Center(
          child: Container(
            width: 18,
            height: 18,
            decoration: const BoxDecoration(
              color: Color(0x99000000),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 13, color: const Color(0xFFFFFFFF)),
          ),
        ),
      ),
    ),
  );
}
