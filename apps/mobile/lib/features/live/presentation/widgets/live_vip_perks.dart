// v1.132-social (D379, CONVENTIONS §10.169): the VIP perks inside live
// rooms, as the room draws them — the pin bar (PINNED_MESSAGE), the host's
// greeting card (HOST_GREETING), the crown over a seat (SEAT_CROWN), the
// uploaded rain effect (BIG_GIFT_RAIN), the VIP room's lock (VIP_ROOM) and a kept seat
// (SEAT_RESERVE).

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_viewer_prefs.dart';
import 'package:kabso_live/features/live/application/live_vip_room.dart';
import 'package:kabso_live/features/live/domain/live_vip.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/application/vip_providers.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D379: the gold of the VIP live perks (pin bar edge, greeting card, lock).
const kVipGold = Color(0xFFF5C451);
const _vipInk = Color(0xFF2B1A00);
const _panel = Color(0xE61A1426);

/// D379: the caller's own effective VIP perks now (their tier and the lower
/// ones, D258), by code — only the built ones (`available`). Empty without
/// an active VIP or while unreadable.
final FutureProvider<Map<String, VipPerk>> myVipLivePerksProvider =
    FutureProvider.autoDispose<Map<String, VipPerk>>((ref) async {
      try {
        final mine = await ref.watch(myVipProvider.future);
        if (mine == null || !mine.expiresAt.isAfter(clock.now())) return {};
        final catalog = await ref.watch(vipCatalogProvider.future);
        final tier = catalog?.tiers
            .where((t) => t.code == mine.tierCode)
            .firstOrNull;
        if (tier == null) return {};
        return {
          for (final p in tier.effectivePerks)
            if (p.available) p.code: p,
        };
      } on Object {
        return {};
      }
    });

/// D379 (§10.169.2): the pinned message at the top of the chat — the
/// author, the text and a bar running out over [left]; «إزالة» for those
/// who may take it down ([onRemove] null: no button).
class LiveVipPinBar extends StatefulWidget {
  const new({required this.pin, required this.left, super.key, this.onRemove});

  final LiveChatPin pin;
  final Duration left;
  final VoidCallback? onRemove;

  static const removeKey = Key('vipPin.remove');

  @override
  State<LiveVipPinBar> createState() => _LiveVipPinBarState();
}

class _LiveVipPinBarState extends State<LiveVipPinBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _run = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(LiveVipPinBar old) {
    super.didUpdateWidget(old);
    if (old.pin.id != widget.pin.id) _start();
  }

  void _start() {
    final whole = widget.pin.length.inMilliseconds;
    final left = widget.left.inMilliseconds;
    final from = whole <= 0 ? 0.0 : (left / whole).clamp(0.0, 1.0);
    _run
      ..duration = widget.left
      ..value = from;
    if (widget.left > Duration.zero) _run.animateTo(0);
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final remove = widget.onRemove;
    return Semantics(
      container: true,
      label:
          '${l10n.liveVipPinnedBy(widget.pin.author.displayName)}: '
          '${widget.pin.text}',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kVipGold, width: 1.2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 4, 6),
              child: Row(
                children: [
                  const ExcludeSemantics(
                    child: Icon(Icons.push_pin, size: 16, color: kVipGold),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.liveVipPinnedBy(widget.pin.author.displayName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.caption.copyWith(
                              color: kVipGold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            widget.pin.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.body.copyWith(
                              color: const Color(0xFFFFFFFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (remove != null)
                    TextButton(
                      key: LiveVipPinBar.removeKey,
                      onPressed: remove,
                      style: TextButton.styleFrom(
                        foregroundColor: kVipGold,
                        minimumSize: const Size(48, 40),
                      ),
                      child: Text(l10n.liveVipPinRemove),
                    ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _run,
              builder: (_, _) => LinearProgressIndicator(
                value: _run.value,
                minHeight: 2,
                backgroundColor: const Color(0x33F5C451),
                valueColor: const AlwaysStoppedAnimation(kVipGold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// D379 (§10.169.3): the host-only card «VIP n دخل البث» with «رحّب».
class LiveVipGreetingCard extends ConsumerWidget {
  const new({
    required this.user,
    required this.onGreet,
    required this.onClose,
    super.key,
  });

  final UserSummary user;
  final VoidCallback onGreet;
  final VoidCallback onClose;

  static const greetKey = Key('vipGreeting.greet');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final look = ref.watch(vipLookProvider(user.vip));
    final level = look?.level ?? user.vip?.rank ?? 0;
    final color = look?.color ?? kVipGold;
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 6, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.lerp(color, const Color(0xFF000000), 0.55)!,
            const Color(0xF0140E1E),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kVipGold),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.workspace_premium, color: kVipGold, size: 22),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.liveVipGreetingTitle('$level'),
                  style: t.caption.copyWith(
                    color: kVipGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.body.copyWith(color: const Color(0xFFFFFFFF)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: greetKey,
            onPressed: onGreet,
            style: FilledButton.styleFrom(
              backgroundColor: kVipGold,
              foregroundColor: _vipInk,
              minimumSize: const Size(64, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: Text(l10n.liveVipGreetingAction),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close, size: 18),
            color: const Color(0xB3FFFFFF),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }
}

/// D379 (§10.169.4): the crown over a seated member's picture — the
/// SEAT_CROWN art of their effective perks (an SVGA over its still; the
/// still under reduced motion); nothing without the perk or its art.
class LiveVipSeatCrown extends ConsumerWidget {
  const new({required this.vip, required this.picture, super.key});

  /// The seated member's VIP (null: nothing drawn).
  final UserVip? vip;

  /// The picture's diameter: the crown is as wide, its art's ratio tall.
  final double picture;

  static Key keyFor(int seat) => Key('vipCrown.$seat');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perk = ref.watch(vipLookProvider(vip))?.perk(VipLivePerks.seatCrown);
    if (perk == null || (perk.still == null && perk.animation == null)) {
      return const SizedBox.shrink();
    }
    final w = perk.artWidth ?? 300;
    final h = perk.artHeight ?? 200;
    final width = picture;
    final height = width * (h / w).clamp(0.3, 1.5);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: height,
          child: VipAnimatedArt(
            animation: perk.animation,
            still: perk.still,
            animate: !MediaQuery.disableAnimationsOf(context),
          ),
        ),
      ),
    );
  }
}

/// D379 (§10.169.5): BIG_GIFT_RAIN over the whole room while one plays —
/// only the effect the owner uploaded for the tier (no art: nothing; owner
/// 2026-11-12 «الكوينز المتطاير ازله»), skipped under reduced motion or
/// «إخفاء المؤثرات».
class LiveVipGiftRainLayer extends ConsumerWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rain = ref.watch(liveVipRoomProvider(roomId).select((s) => s.rain));
    final hidden = ref.watch(
      liveViewerPrefsProvider.select((p) => p.giftEffectsHidden),
    );
    if (rain == null ||
        !LiveVipRainArt.hasArt(rain) ||
        hidden ||
        MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: ExcludeSemantics(
        child: LiveVipRainArt(
          key: ValueKey('vipRain.${rain.giftId}'),
          rain: rain,
        ),
      ),
    );
  }
}

/// D379: [rain]'s uploaded effect, full screen, played once (the room's VIP
/// state takes it off after its duration) on the app's VIP art players —
/// the SVGA, else the MP4, else the still as one frame. Nothing without art.
class LiveVipRainArt extends StatelessWidget {
  const new({required this.rain, super.key});

  final VipGiftRain rain;

  /// Whether the tier uploaded anything to play.
  static bool hasArt(VipGiftRain rain) =>
      rain.animation != null || rain.video != null || rain.still != null;

  @override
  Widget build(BuildContext context) {
    final svga = rain.animation;
    final mp4 = rain.video;
    if (svga != null) {
      return VipAnimatedArt(
        animation: svga,
        still: null,
        fit: BoxFit.cover,
        once: true,
      );
    }
    if (mp4 != null) {
      return VipAnimatedArt(
        animation: mp4,
        video: ArtVideo.plain,
        still: null,
        fit: BoxFit.cover,
        once: true,
      );
    }
    final still = rain.still;
    if (still == null) return const SizedBox.shrink();
    return SizedBox.expand(
      child: Image(
        image: vipArtImage(still),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// D379 (§10.169.9): the VIP lock on a room card — «VIP» with the lock, in
/// the tier's colour.
class LiveVipRoomBadge extends StatelessWidget {
  const new({required this.tier, super.key});

  final LiveVipMinTier tier;

  static const badgeKey = Key('vipRoom.badge');

  @override
  Widget build(BuildContext context) {
    final color = Color(vipColorValue(tier.color));
    return Semantics(
      label: context.l10n.liveVipLockBody(tier.name),
      child: Container(
        key: badgeKey,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Color.lerp(color, const Color(0xFF000000), 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kVipGold, width: 0.8),
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 11, color: kVipGold),
              const SizedBox(width: 3),
              Text(
                tier.name,
                style: context.textStyles.caption.copyWith(
                  color: kVipGold,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D379 (§10.169.9): the sheet on `LIVE_VIP_ONLY` — «هذه الغرفة لأعضاء VIP n
/// فما فوق», with «اشترك في VIP» ([onGetVip]) and «حسناً».
Future<void> showLiveVipLockSheet(
  BuildContext context, {
  required String tierName,
  VoidCallback? onGetVip,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(0xFF1A1426),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (sheet) => LiveVipLockSheet(tierName: tierName, onGetVip: onGetVip),
);

/// The content of [showLiveVipLockSheet].
class LiveVipLockSheet extends StatelessWidget {
  const new({required this.tierName, super.key, this.onGetVip});

  final String tierName;
  final VoidCallback? onGetVip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final get = onGetVip;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(
              child: Icon(Icons.lock_rounded, size: 44, color: kVipGold),
            ),
            const SizedBox(height: KSpacing.sm),
            Semantics(
              header: true,
              child: Text(
                l10n.liveVipLockTitle,
                style: t.title.copyWith(color: kVipGold),
              ),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.liveVipLockBody(tierName),
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: const Color(0xFFFFFFFF)),
            ),
            const SizedBox(height: KSpacing.lg),
            if (get != null)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    get();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: kVipGold,
                    foregroundColor: _vipInk,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(l10n.liveVipLockGetVip),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFFFFFF),
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(l10n.liveVipLockClose),
            ),
          ],
        ),
      ),
    );
  }
}

/// D379 (§10.169.9): the audio go-live setup's «غرفة VIP» — shown to a
/// holder only: a switch and, when on, the tiers up to the perk's cap (its
/// value, else the holder's own tier). [value] is the chosen tier code (null:
/// open to all).
class LiveVipRoomPicker extends ConsumerWidget {
  const new({required this.value, required this.onChanged, super.key});

  final String? value;
  final ValueChanged<String?> onChanged;

  static const switchKey = Key('vipRoom.switch');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perks = ref.watch(myVipLivePerksProvider).value ?? const {};
    final perk = perks[VipLivePerks.vipRoom];
    if (perk == null) return const SizedBox.shrink();
    final tiers = [...?ref.watch(vipCatalogProvider).value?.tiers]
      ..sort((a, b) => a.level.compareTo(b.level));
    final mine = ref.watch(myVipProvider).value;
    final capCode = perk.value is String ? perk.value! as String : null;
    final cap =
        tiers.where((t) => t.code == capCode).firstOrNull?.level ??
        tiers.where((t) => t.code == mine?.tierCode).firstOrNull?.level ??
        0;
    final allowed = [
      for (final t in tiers)
        if (t.level <= cap) t,
    ];
    if (allowed.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final t = context.textStyles;
    final on = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile.adaptive(
          key: switchKey,
          contentPadding: EdgeInsets.zero,
          value: on,
          activeThumbColor: kVipGold,
          title: Row(
            children: [
              const Icon(Icons.lock, size: 18, color: kVipGold),
              const SizedBox(width: 6),
              Text(l10n.liveVipRoomToggle),
            ],
          ),
          subtitle: Text(l10n.liveVipRoomHint, style: t.caption),
          onChanged: (v) => onChanged(v ? allowed.first.code : null),
        ),
        if (on)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tier in allowed)
                ChoiceChip(
                  key: Key('vipRoom.tier.${tier.code}'),
                  label: Text(tier.name),
                  selected: tier.code == value,
                  selectedColor: kVipGold,
                  onSelected: (_) => onChanged(tier.code),
                ),
            ],
          ),
      ],
    );
  }
}

/// D379 (§10.169.10): a seat the host keeps for someone — the lock with
/// «محجوز لـ name» under it.
class LiveVipReservedSeat extends StatelessWidget {
  const new({required this.reservation, required this.picture, super.key});

  final LiveSeatReservation reservation;
  final double picture;

  static Key keyFor(int index) => Key('vipReserved.$index');

  @override
  Widget build(BuildContext context) {
    final name = reservation.user.displayName;
    return Semantics(
      label: context.l10n.liveVipReservedFor(name),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: picture,
              height: picture,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x33F5C451),
                border: Border.all(color: kVipGold, width: 1.5),
              ),
              child: Icon(
                Icons.lock_clock,
                color: kVipGold,
                size: picture * 0.45,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              width: picture * 1.4,
              child: Text(
                context.l10n.liveVipReservedFor(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.textStyles.caption.copyWith(
                  color: kVipGold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// D379 (§10.169.10): the host's «قفل المقعد لصديق» sheet — a username;
/// answers it (trimmed, no leading «@») or null.
Future<String?> showLiveVipReserveSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => const _ReserveSheet(),
    );

class _ReserveSheet extends StatefulWidget {
  const new();

  @override
  State<_ReserveSheet> createState() => _ReserveSheetState();
}

class _ReserveSheetState extends State<_ReserveSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    final v = _name.text.trim().replaceFirst(RegExp('^@'), '');
    if (v.isNotEmpty) Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.liveVipReserveTitle,
                  style: context.textStyles.title,
                ),
              ),
              const SizedBox(height: KSpacing.md),
              TextField(
                key: const Key('vipReserve.username'),
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _done(),
                decoration: InputDecoration(
                  labelText: l10n.liveVipReserveHint,
                  prefixText: '@',
                ),
              ),
              const SizedBox(height: KSpacing.md),
              FilledButton(
                key: const Key('vipReserve.confirm'),
                onPressed: _done,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.liveVipReserveConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// D379 (§10.169.1): the holder's own VIP pack row for the seat-emoji sheet
/// — each file of their SEAT_EMOJI art; a tap answers its 1-based number.
class LiveVipSeatEmojiRow extends ConsumerWidget {
  const new({required this.onPick, super.key});

  final void Function(int n, String art) onPick;

  static Key keyFor(int n) => Key('vipSeatEmoji.$n');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perks = ref.watch(myVipLivePerksProvider).value ?? const {};
    final pack = VipLivePerks.artPack(perks[VipLivePerks.seatEmoji]?.value);
    if (pack.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: kVipGold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'VIP',
                  style: context.textStyles.caption.copyWith(
                    color: _vipInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pack.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => InkWell(
                key: keyFor(i + 1),
                borderRadius: BorderRadius.circular(10),
                onTap: () => onPick(i + 1, pack[i]),
                child: Ink(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kVipGold),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: VipSeatEmojiArt(art: pack[i], animate: false),
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

/// D379: one VIP pack file — an SVGA (by its extension) over nothing, else
/// the picture.
class VipSeatEmojiArt extends StatelessWidget {
  const new({required this.art, super.key, this.animate = true});

  final String art;
  final bool animate;

  static bool isSvga(String art) =>
      Uri.tryParse(art)?.path.toLowerCase().endsWith('.svga') ?? false;

  @override
  Widget build(BuildContext context) => isSvga(art)
      ? VipAnimatedArt(
          animation: art,
          still: null,
          animate: animate && !MediaQuery.disableAnimationsOf(context),
          placeholder: const Icon(Icons.auto_awesome, color: kVipGold),
        )
      : Image(
          image: vipArtImage(art),
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) =>
              const Icon(Icons.auto_awesome, color: kVipGold),
        );
}
