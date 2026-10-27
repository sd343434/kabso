import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/home_banners_provider.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/domain/home_banner.dart';
import 'package:kabso_live/features/live/domain/home_banner_link.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/domain/live_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_sheet.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D136/D137/D141: where the floating cards of a video live sit: one
/// column at the reading start (ref 158 §2 measured the wish list 16.2 pt
/// from the edge at 393 pt). D141 (owner): the promo box sits right above
/// the wish note, centred on it, 8 pt apart; the note's top is 212 pt under
/// the top inset so the promo (109 pt) clears the top rows and the chips.
abstract final class KLiveSideCards {
  static const double wishTop = 212;
  static const double wishStart = 12;
  static const double gap = 8;
  static const double promoTop = wishTop - gap - LiveRoomPromoBox.height;
  static const double promoStart =
      wishStart + (LiveWishCard.width - LiveRoomPromoBox.width) / 2;
}

/// D136 (owner, ref 158 R5): the host's wish list. D141 (owner: «not rows
/// per gift — one card like a sticky note»): one see-through notepaper
/// card, slightly turned, with a strip of tape, faint ruled lines and a
/// folded corner (all drawn in code), the title «أمنيات» / "Wishes" and up
/// to 4 gifts in compact lines — picture, name and how many of it the host
/// received in this live. Dark ink on warm paper stays legible over any
/// video. Viewers tap a line to open the gift panel with that gift
/// ([onWish]); the host taps the note to change it ([onEdit]). Nothing when
/// the list is empty.
class LiveWishCard extends StatelessWidget {
  const new({required this.wishes, super.key, this.onWish, this.onEdit});

  final List<LiveWishGift> wishes;
  final ValueChanged<LiveWishGift>? onWish;
  final VoidCallback? onEdit;

  /// The note: 104 pt wide, 24 pt lines, a 20 pt picture.
  static const double width = 104;
  static const double row = 24;
  static const double picture = 20;
  static const double radius = 4;

  /// Turned a little (≈ −2°), the reading start lower.
  static const double tilt = -0.035;

  /// Warm paper, a little see-through (the live shows faintly behind).
  static const paper = [Color(0xEBFFF6CF), Color(0xE6FFE9A3)];
  static const ink = Color(0xFF3A2A12);
  static const rule = Color(0x338A6A2A);
  static const received = Color(0xFFB4231C);

  static const cardKey = Key('live.wishCard');
  static const titleKey = Key('live.wishCard.title');
  static Key rowKey(String code) => Key('live.wishCard.$code');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (wishes.isEmpty) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final styles = context.textStyles;
    final rows = <Widget>[
      for (final w in wishes.take(4))
        Semantics(
          button: onWish != null,
          label: l10n.liveWishRowLabel(w.name, KFormat.grouped(w.received)),
          excludeSemantics: true,
          child: GestureDetector(
            key: rowKey(w.giftCode),
            behavior: HitTestBehavior.opaque,
            onTap: onWish == null ? null : () => onWish!(w),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: row),
              child: Row(
                children: [
                  KGiftImage(w.assetKey, imageUrl: w.imageUrl, size: picture),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      w.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: scaler,
                      style: styles.caption.copyWith(
                        fontSize: 11,
                        height: 1.2,
                        color: ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (w.received > 0) ...[
                    const SizedBox(width: 3),
                    Text(
                      '×${KFormat.compact(w.received, l10n)}',
                      textDirection: TextDirection.ltr,
                      textScaler: scaler,
                      style: styles.caption.copyWith(
                        fontSize: 10,
                        height: 1.2,
                        color: received,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
    ];
    final note = Container(
      key: cardKey,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: paper,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x59000000),
            blurRadius: 8,
            offset: Offset(1, 3),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _NotePaperPainter(
          firstRule: 22,
          pitch: row,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(7, 6, 7, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, size: 11, color: received),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      l10n.liveWishNoteTitle,
                      key: titleKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: scaler,
                      style: styles.caption.copyWith(
                        fontSize: 12,
                        height: 1.25,
                        color: ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              ...rows,
            ],
          ),
        ),
      ),
    );
    // A strip of tape over the top edge.
    final card = Transform.rotate(
      angle: tilt,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          note,
          PositionedDirectional(
            top: -5,
            start: width / 2 - 17,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: 0.08,
                child: Container(
                  width: 34,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0x8CFFFFFF),
                    borderRadius: BorderRadius.circular(1.5),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
}

/// The note's paper: faint ruled lines under the title and each line, a
/// thin margin line at the reading start and a folded bottom-end corner.
class _NotePaperPainter extends CustomPainter {
  const new({required this.firstRule, required this.pitch, required this.rtl});

  final double firstRule;
  final double pitch;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final rule = Paint()
      ..color = LiveWishCard.rule
      ..strokeWidth = 0.6;
    for (var y = firstRule + 6; y < size.height - 4; y += pitch) {
      canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), rule);
    }
    final marginX = rtl ? size.width - 4 : 4.0;
    canvas.drawLine(
      Offset(marginX, 3),
      Offset(marginX, size.height - 3),
      Paint()
        ..color = const Color(0x40C2413A)
        ..strokeWidth = 0.7,
    );
    // The folded corner at the bottom end.
    const fold = 9.0;
    final endX = rtl ? 0.0 : size.width;
    final dir = rtl ? 1.0 : -1.0;
    final corner = Path()
      ..moveTo(endX + dir * fold, size.height)
      ..lineTo(endX, size.height - fold)
      ..lineTo(endX + dir * fold, size.height - fold)
      ..close();
    canvas.drawPath(corner, Paint()..color = const Color(0x40A07A2A));
  }

  @override
  bool shouldRepaint(_NotePaperPainter old) =>
      old.firstRule != firstRule || old.pitch != pitch || old.rtl != rtl;
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

  /// D141: how many are chosen ("2/4"), shown whatever the tab.
  static const count = Key('live.wishSheet.count');
}

class _WishSheetState extends ConsumerState<_WishSheet> {
  late final List<String> _chosen = [...widget.initial.take(4)];
  bool _saving = false;

  /// D141: the open category tab (the gift panel's tabs); null: the first.
  String? _tab;

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
    // D141 (owner: "one long list is slow to choose from"): the gift
    // panel's category tabs; the chosen gifts stay chosen on every tab.
    final tabs = LiveGiftTabs.categoriesOf(catalogue);
    final tab = tabs.contains(_tab) ? _tab! : tabs.firstOrNull;
    final category = tab == null ? null : GiftCategory.fromWire(tab);
    final gifts = catalogue == null || category == null
        ? const <Gift>[]
        : catalogue.of(category);
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
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.liveWishTitle,
                        style: text.title.copyWith(
                          color: const Color(0xFFFFFFFF),
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    label: l10n.liveWishChosenCount(_chosen.length),
                    excludeSemantics: true,
                    child: Container(
                      key: LiveWishSheetKeys.count,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _chosen.length >= 4 ? _accent : _cell,
                        borderRadius: BorderRadius.circular(KRadius.pill),
                      ),
                      child: Text(
                        '${_chosen.length}/4',
                        textDirection: TextDirection.ltr,
                        style: text.caption.copyWith(
                          color: _chosen.length >= 4
                              ? const Color(0xFF0B2B2A)
                              : const Color(0xFFFFFFFF),
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
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
              const SizedBox(height: 8),
              if (tab != null && tabs.length > 1)
                LiveGiftTabs(
                  tabs: tabs,
                  selected: tab,
                  hasTags: (_) => false,
                  onTap: (id) => setState(() => _tab = id),
                ),
              const SizedBox(height: 4),
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

/// D137 (owner, ref 158 R4): the in-room promo box at the top end — the
/// active ROOM banners (3:4) in a see-through frame, one every 4 s (not
/// with reduced motion), page dots when there are several. A tap opens an
/// in-app link (an https link or a hub tab is not tappable here); "–"
/// hides the box for the rest of this live on this device. Nothing when
/// there is no ROOM banner.
class LiveRoomPromoBox extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  /// Ref 158 R4's card: 81.7 pt wide; the picture is 3:4.
  static const double width = 82;
  static const double height = width * 4 / 3;
  static const Duration interval = Duration(seconds: 4);

  static const boxKey = Key('live.promoBox');
  static const closeKey = Key('live.promoBox.close');
  static Key pageKey(String id) => Key('live.promoBox.page.$id');

  @override
  ConsumerState<LiveRoomPromoBox> createState() => _LiveRoomPromoBoxState();
}

class _LiveRoomPromoBoxState extends ConsumerState<LiveRoomPromoBox> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _schedule(int count) {
    if (_timer != null || count < 2) return;
    _timer = Timer.periodic(LiveRoomPromoBox.interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      if (MediaQuery.disableAnimationsOf(context)) return;
      final next = (_page + 1) % count;
      _controller.animateToPage(
        next,
        duration: KMotion.of(context, KMotion.base),
        curve: Curves.easeInOut,
      );
    });
  }

  void _open(HomeBanner banner) {
    if (HomeBannerTarget.parse(banner.link) case final HomeBannerRoute r) {
      unawaited(context.push(r.location));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final closed = ref.watch(closedRoomPromosProvider);
    if (closed.contains(widget.roomId)) return const SizedBox.shrink();
    final banners = ref.watch(roomBannersProvider).value ?? const [];
    if (banners.isEmpty) return const SizedBox.shrink();
    _schedule(banners.length);
    final count = banners.length;
    return SizedBox(
      key: LiveRoomPromoBox.boxKey,
      width: LiveRoomPromoBox.width,
      height: LiveRoomPromoBox.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: KLiveColors.glass,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x4DFFFFFF)),
              ),
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: PageView.builder(
                  controller: _controller,
                  itemCount: count,
                  onPageChanged: (p) => setState(() => _page = p),
                  itemBuilder: (context, i) {
                    final b = banners[i];
                    final can =
                        HomeBannerTarget.parse(b.link) is HomeBannerRoute;
                    final title = b.title;
                    return Semantics(
                      key: LiveRoomPromoBox.pageKey(b.id),
                      button: can,
                      label: title == null || title.trim().isEmpty
                          ? l10n.homeBannerSemantics(i + 1, count)
                          : l10n.homeBannerTitledSemantics(title, i + 1, count),
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: can ? () => _open(b) : null,
                        child: Image.network(
                          b.imageUrl,
                          fit: BoxFit.cover,
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Color(0x33000000)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (count > 1)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 5,
              child: ExcludeSemantics(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < count; i++)
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _page
                              ? const Color(0xFFFFFFFF)
                              : const Color(0x80FFFFFF),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // Ref 158: a small "–" at the top end hides the box.
          PositionedDirectional(
            top: -8,
            end: -8,
            child: Semantics(
              button: true,
              label: l10n.livePromoClose,
              excludeSemantics: true,
              child: GestureDetector(
                key: LiveRoomPromoBox.closeKey,
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref.read(closedRoomPromosProvider).add(widget.roomId);
                  setState(() {});
                },
                child: SizedBox.square(
                  dimension: 28,
                  child: Center(
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: const Color(0x99000000),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x80FFFFFF)),
                      ),
                      child: const Icon(
                        Icons.remove_rounded,
                        size: 11,
                        color: Color(0xFFFFFFFF),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
