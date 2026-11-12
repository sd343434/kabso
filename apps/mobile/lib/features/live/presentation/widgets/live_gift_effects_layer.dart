import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/item_badge.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/live/application/live_gift_effects.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/application/live_lucky_ticker.dart';
import 'package:kabso_live/features/live/application/live_viewer_prefs.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/gift_panel.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_anonymous_gift_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_global_strip_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_level_ticker_bar.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_program_card.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_quip_art.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_side_cards.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_win_banner.dart';
import 'package:kabso_live/features/vip/presentation/vip_anonymous.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The gifts sent in a live, over the room (CP-020, §10.23): a strip per
/// combo (sender → recipients, the gift, ×N) and the full-screen effect of
/// an animated gift. Names come from the cached catalogue by `giftCode`.
///
/// D145c (owner, device: «no strip at all» after his own gift in his audio
/// room): the strips are drawn here, **over** the full-screen effect, in
/// audio rooms and video lives alike — vertically centred at the reading
/// start ([LiveGiftStripsSlot]), the same place in both; beside the
/// wish / promo column when a video live shows it ([stripsStart]); and
/// above the gift panel while it is open (normal gifts keep it open, so
/// the sender sees their own strip). D145a had moved the audio strips into
/// the room's layout, under the effect and under the open panel. A tap on
/// a strip opens the sender's card ([onSender]); nothing else takes taps.
class LiveGiftEffectsLayer extends ConsumerWidget {
  const new({
    required this.roomId,
    super.key,
    this.onSender,
    this.stripsStart = KSpacing.sm,
    this.onOpenRoom,
  });

  final String roomId;

  /// D148: opens the live of a gold ticker's win (a viewer moves there);
  /// null: the ticker takes no taps (the host on air stays in their live).
  final ValueChanged<String>? onOpenRoom;

  /// Opens the sender's card (D145); null: the strips take no taps.
  final ValueChanged<UserSummary>? onSender;

  /// The strips' distance from the reading-start edge.
  final double stripsStart;

  /// D145a/D145c: a video live's strips start beside the wish / promo
  /// column when it shows ([sideColumn]), so they never hide it.
  static double videoStripsStart({required bool sideColumn}) => sideColumn
      ? KLiveSideCards.wishStart + LiveWishCard.width + KSpacing.xs
      : KSpacing.sm;

  static Key bannerKey(String comboId) => Key('gift.banner.$comboId');

  /// D224: a quip's strip.
  static Key quipKey(String quipId) => Key('gift.quip.$quipId');
  static const effectKey = Key('gift.effect');

  /// D132: the lucky win announcement (D159: the owner's tier banner).
  static const luckyKey = Key('gift.lucky');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effects = ref.watch(liveGiftEffectsProvider(roomId));
    final catalogue = ref.watch(giftCatalogueProvider).value;
    // D225: «إخفاء مؤثرات الهدايا» on this phone — the big animation is
    // skipped (marked done so the queue goes on); the strips still show.
    final prefs = ref.watch(liveViewerPrefsProvider);
    final effect = effects.big;
    if (effect != null && prefs.giftEffectsHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(liveGiftEffectsProvider(roomId).notifier).bigDone(effect.id);
      });
    }
    final big = prefs.giftEffectsHidden ? null : effect;
    final safeTop = MediaQuery.paddingOf(context).top;
    final bannerWidth = LiveWinBanner.widthOn(MediaQuery.sizeOf(context).width);
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (effects.lucky case final win?)
                // D159: the owner's tier frame under the header, above an
                // audio room's first seats; it slides across the width.
                Positioned(
                  key: luckyKey,
                  top: safeTop + LiveWinBanner.top,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: LiveWinBanner(
                      key: ValueKey('lucky.${win.giftId}'),
                      win: win,
                      giftName: catalogue?.byCode(win.giftCode)?.name,
                      width: bannerWidth,
                    ),
                  ),
                ),
              if (big != null)
                Positioned.fill(
                  key: effectKey,
                  child: KGiftEffect(
                    key: ValueKey(big.id),
                    animationKey:
                        big.animationKey ?? _art(catalogue, big)?.animationKey,
                    animationUrl:
                        big.animationUrl ?? _art(catalogue, big)?.animationUrl,
                    // v1.46-live (D207): the format and transparency go with
                    // the URL they describe; the MP3 likewise.
                    animationFormat: big.animationUrl != null
                        ? big.animationFormat
                        : _art(catalogue, big)?.animationFormat,
                    animationAlpha: big.animationUrl != null
                        ? big.animationAlpha
                        : _art(catalogue, big)?.animationAlpha,
                    // D317: «شاشة كاملة» (D289) covers the whole screen.
                    fullScreen:
                        _art(catalogue, big)?.badges.any(
                          (b) =>
                              b.code == ItemBadgeCode.fullscreen &&
                              b.runningAt(DateTime.now()),
                        ) ??
                        false,
                    audioUrl: big.audioUrl ?? _art(catalogue, big)?.audioUrl,
                    audioDurationMs: big.audioUrl != null
                        ? big.audioDurationMs
                        : _art(catalogue, big)?.audioDurationMs,
                    // D225: the gifts' own switch («كتم أصوات الهدايا»).
                    soundOn:
                        ref.watch(soundEffectsProvider) &&
                        !prefs.giftSoundsMuted,
                    onHold: () => ref
                        .read(liveGiftEffectsProvider(roomId).notifier)
                        .bigHold(big.id),
                    onDone: () => ref
                        .read(liveGiftEffectsProvider(roomId).notifier)
                        .bigDone(big.id),
                  ),
                ),
            ],
          ),
        ),
        // Over the effect: a full-screen animation never hides them.
        LiveGiftStripsSlot(
          start: stripsStart,
          floor: ref.watch(liveChatTopProvider(roomId)),
          child: LiveGiftStrips(roomId: roomId, onSender: onSender),
        ),
        // D148: «لحظة الحظ» — a big win in another live, under the header.
        // D159: it steps aside (fades, no taps) while this live's own win
        // banner shows in the same place, and comes back after it.
        Positioned(
          top: safeTop + LiveGiftStripsSlot.top,
          left: KSpacing.md,
          right: KSpacing.md,
          child: IgnorePointer(
            ignoring: effects.lucky != null,
            child: ExcludeSemantics(
              excluding: effects.lucky != null,
              child: AnimatedOpacity(
                opacity: effects.lucky == null ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LiveLuckyTickerBar(
                        roomId: roomId,
                        onOpenRoom: onOpenRoom,
                      ),
                      // D178 / D305: the global strips (the owner's art),
                      // under the lucky one: from the reading start to the
                      // middle, 2 s, out by the other side. D305b: the games
                      // lane above the gifts lane, each on its own.
                      LiveGlobalStripLanes(
                        roomId: roomId,
                        onOpenRoom: onOpenRoom,
                        // D380: «مجهول» opens no card.
                        onPerson: onSender == null
                            ? null
                            : (u) {
                                if (!u.anonymous) onSender!(u);
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // D254: the level banner — a high support or charm level reached in
        // any live (this one too) — right under the header row, over the
        // second row; it steps aside like the tickers for this live's own
        // win banner.
        PositionedDirectional(
          top: LiveLevelTickerBar.topFor(safeTop),
          start: LiveLevelTickerBar.start,
          end: LiveLevelTickerBar.end,
          child: IgnorePointer(
            ignoring: effects.lucky != null,
            child: ExcludeSemantics(
              excluding: effects.lucky != null,
              child: AnimatedOpacity(
                opacity: effects.lucky == null ? 1 : 0,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: LiveLevelTickerBar(
                  roomId: roomId,
                  onOpenRoom: onOpenRoom,
                ),
              ),
            ),
          ),
        ),
        // D154e: the live's program, at the reading end under the header.
        PositionedDirectional(
          top: MediaQuery.paddingOf(context).top + LiveProgramCard.top,
          end: KSpacing.sm,
          child: LiveProgramCard(roomId: roomId),
        ),
        // D224: the quip playing now is a strip in the gifts' column
        // (LiveGiftEffects.showQuip); D216's quip banner is gone.
      ],
    );
  }
}

/// D148 («لحظة الحظ», owner) and D347 (owner: «شريط المردود يظهر في كل
/// لايفات للشريط x250 / x500 / x1000», CONVENTIONS §10.146): the global lucky
/// banner — a ×250 / ×500 / ×1000 win in another live — drawn as the room's
/// own win banner «شريط المردود» ([LiveWinBanner], the same frames and
/// timeline) with a tag under it: the winner, «في {room}» and the gift. A tap
/// opens that live ([onOpenRoom]; the caller checks it is still live and
/// asks a seated guest first); none (a host on air): it takes no taps. With
/// reduced motion it shows still. Hidden while [luckyTickerHiddenProvider]
/// says so (the viewer's switch comes in D151).
class LiveLuckyTickerBar extends ConsumerWidget {
  const new({required this.roomId, super.key, this.onOpenRoom});

  final String roomId;
  final ValueChanged<String>? onOpenRoom;

  static const tickerKey = Key('gift.lucky.ticker');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always watched (the controller keeps its subscription while hidden).
    final current = ref.watch(liveLuckyTickersProvider(roomId));
    final banner = ref.watch(luckyTickerHiddenProvider) ? null : current;
    if (banner == null) return const SizedBox.shrink();
    final win = banner.win;
    final catalogue = ref.watch(giftCatalogueProvider).value;
    final known = catalogue?.byCode(win.giftCode);
    final art =
        banner.gift ??
        (known == null
            ? null
            : LuckyTickerGift(
                code: known.code,
                assetKey: known.assetKey,
                imageUrl: known.imageUrl,
              ));
    final open = onOpenRoom;
    return KeyedSubtree(
      key: tickerKey,
      child: LiveWinBanner(
        // A new banner restarts the timeline.
        key: ValueKey('ticker.${win.giftId}'),
        win: win,
        giftName: known?.name,
        width: LiveWinBanner.widthOn(MediaQuery.sizeOf(context).width),
        roomTitle: banner.room.title,
        gift: art,
        onTap: open == null
            ? null
            : () {
                ref.read(liveLuckyTickersProvider(roomId).notifier).dismiss();
                open(banner.room.id);
              },
      ),
    );
  }
}

/// D145c (owner): where the gift strips sit, the same in every live — at
/// the reading start ([start] from the edge), the column's middle on the
/// screen's middle; it moves up just enough to end [gap] above the chat
/// text ([floor], the chat's top on the screen) and above the gift panel
/// while it is open ([liveGiftPanelHeightProvider]: normal gifts keep it
/// open), never above the header rows ([top] under the status bar). Fills
/// the room; only the strips take taps.
class LiveGiftStripsSlot extends ConsumerWidget {
  const new({
    required this.child,
    super.key,
    this.start = KSpacing.sm,
    this.floor,
  });

  final Widget child;
  final double start;

  /// The chat's top on the screen, or null.
  final double? floor;

  /// The strips keep this far under the status bar (the header rows).
  static const double top = 96;

  /// …and this far above the open gift panel.
  static const double gap = KSpacing.sm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(liveGiftPanelHeightProvider);
    return CustomSingleChildLayout(
      delegate: _StripsLayout(
        start: start,
        end: KSpacing.sm,
        rtl: Directionality.of(context) == TextDirection.rtl,
        ceiling: MediaQuery.paddingOf(context).top + top,
        panel: panel,
        floor: floor,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _StripsLayout extends SingleChildLayoutDelegate {
  new({
    required this.start,
    required this.end,
    required this.rtl,
    required this.ceiling,
    required this.panel,
    required this.floor,
    required this.gap,
  });

  final double start;
  final double end;
  final bool rtl;
  final double ceiling;

  /// The open panel's height, or null.
  final double? panel;

  /// The chat's top (from the screen's top), or null.
  final double? floor;
  final double gap;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.max(0, constraints.maxWidth - start - end),
        maxHeight: constraints.maxHeight,
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    var y = (size.height - child.height) / 2;
    if (panel case final p?) {
      y = math.min(y, size.height - p - gap - child.height);
    }
    if (floor case final f?) y = math.min(y, f - gap - child.height);
    y = math.max(y, ceiling);
    return Offset(rtl ? size.width - start - child.width : start, y);
  }

  @override
  bool shouldRelayout(_StripsLayout old) =>
      old.start != start ||
      old.end != end ||
      old.rtl != rtl ||
      old.ceiling != ceiling ||
      old.panel != panel ||
      old.floor != floor ||
      old.gap != gap;
}

/// D145/D145a: the gift strips of a live — up to
/// [LiveGiftEffects.maxBanners], the newest on top, each a [LiveGiftBanner]
/// that opens the sender's card on a tap ([onSender]); D224: a quip that
/// plays is one of them. Nothing while no gift is being shown; the column
/// grows and shrinks smoothly.
class LiveGiftStrips extends ConsumerWidget {
  const new({required this.roomId, super.key, this.onSender});

  final String roomId;
  final ValueChanged<UserSummary>? onSender;

  static const stripsKey = Key('gift.strips');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(
      liveGiftEffectsProvider(roomId).select((e) => e.banners),
    );
    final catalogue = ref.watch(giftCatalogueProvider).value;
    final onSender = this.onSender;
    final me = ref.watch(currentUserProvider.select((u) => u?.id));
    // v1.133-social (D380, §10.170.5): an anonymous gift's strip opens no
    // card; its recipients get «إبلاغ» / «رفض الهدايا المجهولة» instead.
    VoidCallback? tapOf(LiveStrip strip) => switch (strip) {
      LiveGiftStrip(:final gift) when gift.anonymous =>
        me != null && gift.recipients.any((r) => r.id == me)
            ? () => openAnonymousGiftActions(context, ref, gift)
            : null,
      _ when strip.sender.anonymous => null,
      _ => onSender == null ? null : () => onSender(strip.sender),
    };
    final column = Column(
      key: stripsKey,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The newest on top.
        for (final strip in banners.reversed)
          Padding(
            key: ValueKey('strip.${strip.key}'),
            padding: const EdgeInsets.only(bottom: KSpacing.xxs),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: tapOf(strip),
              child: switch (strip) {
                LiveGiftStrip(:final gift) => LiveGiftBanner(
                  key: LiveGiftEffectsLayer.bannerKey(gift.combo.id),
                  gift: gift,
                  name: catalogue?.byCode(gift.giftCode)?.name,
                  imageUrl: gift.imageUrl ?? _art(catalogue, gift)?.imageUrl,
                ),
                LiveQuipStrip(:final quip) => LiveGiftBanner.quip(
                  key: LiveGiftEffectsLayer.quipKey(quip.id),
                  quip: quip,
                  gift: catalogue?.byCode(quip.giftCode),
                ),
              },
            ),
          ),
      ],
    );
    final duration = KMotion.of(context, KMotion.base);
    // D199: reduced motion gives a zero duration; an AnimatedSize would then
    // finish inside its own layout (a framework assertion) — no animation.
    final strips = duration == Duration.zero
        ? column
        : AnimatedSize(
            duration: duration,
            curve: KMotion.standard,
            alignment: AlignmentDirectional.centerStart.resolve(
              Directionality.of(context),
            ),
            child: column,
          );
    final anonymousForMe =
        me != null &&
        banners.any(
          (b) =>
              b is LiveGiftStrip &&
              b.gift.anonymous &&
              b.gift.recipients.any((r) => r.id == me),
        );
    return onSender == null && !anonymousForMe
        ? IgnorePointer(child: strips)
        : strips;
  }
}

/// The catalogue's gift of [gift] (its hosted art when an older server's
/// message has none), or null.
Gift? _art(GiftCatalogue? catalogue, LiveGift gift) =>
    catalogue?.byCode(gift.giftCode);

/// [recipients] as a short phrase: one name, two names, or the first and
/// how many more.
String giftRecipientsText(AppLocalizations l10n, List<UserSummary> recipients) {
  String name(UserSummary u) => KFormat.bidiIsolate(u.displayName);
  return switch (recipients) {
    [] => '',
    [final one] => name(one),
    [final a, final b] => l10n.liveGiftRecipientsTwo(name(a), name(b)),
    [final first, ...final rest] => l10n.liveGiftRecipientsMore(
      name(first),
      rest.length,
    ),
  };
}

/// One gift banner: the sender's picture and name, "sent ‹gift› to ‹who›",
/// the gift and ONE count (D145a): ×N, the gifts each recipient got in this
/// combo so far (`combo.quantity`: 10 roses sent 7 times → ×70), the same
/// number the combo button shows. Compact: 36 pt tall.
///
/// D224 (owner: «الافيهات … ارسالها كشريط الهدايا الاخرى»): the same strip
/// for a quip as it plays ([LiveGiftBanner.quip]) — the sender's picture
/// and name, «أرسل إفيه: ‹its words›» and its Kabi art (D216), no count.
class LiveGiftBanner extends StatelessWidget {
  const new({
    required LiveGift this.gift,
    required this.name,
    super.key,
    this.imageUrl,
  }) : quip = null,
       quipGift = null;

  /// D224: [quip]'s strip; [gift] is its catalogue entry when loaded.
  const new quip({required LiveQuip this.quip, super.key, Gift? gift})
    : quipGift = gift,
      gift = null,
      name = null,
      imageUrl = null;

  final LiveGift? gift;

  /// D224: the quip of a quip strip.
  final LiveQuip? quip;

  /// D224: the quip's catalogue gift (its art and name), or null.
  final Gift? quipGift;

  /// The gift's hosted image (D126), or null: the bundled one.
  final String? imageUrl;

  /// The gift's name from the catalogue; null: "a gift".
  final String? name;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final gift = this.gift;
    final quip = this.quip;
    final sentBy = gift?.sender ?? quip!.sender;
    // D380: «مجهول» in the reader's language for an anonymous send.
    final sender = KFormat.bidiIsolate(sentBy.shownName(l10n));
    final String line;
    final Widget art;
    final int? count;
    if (gift != null) {
      line = l10n.liveGiftBannerSent(
        KFormat.bidiIsolate(name ?? l10n.liveGiftGeneric),
        giftRecipientsText(l10n, gift.recipients),
      );
      art = KGiftImage(gift.assetKey, imageUrl: imageUrl, size: 32);
      count = gift.combo.quantity;
    } else {
      line = l10n.liveQuipBannerSent(
        KFormat.bidiIsolate(quipWordsOf(l10n, quip!, quipGift)),
      );
      art = LiveQuipArt(assetKey: quipAssetKeyOf(quip, quipGift), size: 32);
      count = null;
    }
    final quantity = count == null ? null : l10n.giftCombo(count);
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final duration = KMotion.of(context, KMotion.base);
    final banner = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsetsDirectional.fromSTEB(
        KSpacing.xxs,
        KSpacing.xxs,
        KSpacing.sm,
        KSpacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [
            KBrandColors.red600.withValues(alpha: 0.85),
            KLiveColors.chatScrim,
            KLiveColors.chatScrim.withValues(alpha: 0),
          ],
          stops: const [0, 0.7, 1],
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          personAvatar(sentBy, size: 30),
          const SizedBox(width: KSpacing.xs),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: scaler,
                  style: text.label.copyWith(color: const Color(0xFFFFFFFF)),
                ),
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: scaler,
                  style: text.caption.copyWith(
                    color: const Color(0xD9FFFFFF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: KSpacing.xs),
          art,
          if (count != null) ...[
            const SizedBox(width: KSpacing.xxs),
            MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: scaler),
              child: KGiftComboCounter(count: count),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      liveRegion: true,
      label: [sender, line, ?quantity].join(' '),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: KMotion.standard,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: FractionalTranslation(
            translation: Offset(
              (Directionality.of(context) == TextDirection.rtl ? 1 : -1) *
                  (1 - t) *
                  0.3,
              0,
            ),
            child: child,
          ),
        ),
        child: banner,
      ),
    );
  }
}
