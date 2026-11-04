import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/data/vip_repository.dart';
import 'package:kabso_live/features/vip/presentation/vip_parts.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D258 (§10.94): a VIP's entrance. When a `join` data message's `user`
/// carries `vip`, the room shows the member's ENTRY_BANNER (the owner's
/// banner art with «دخل سارة البث» on a dark plate, sliding in like the
/// agents' bars) and plays their ENTRY_EFFECT once (the entry car, centred,
/// downloaded once and kept on the device). An agent's own bar wins over the
/// banner (the car still plays). Several arrive one after another (at most
/// [maxQueued] waiting). Never takes taps.
///
/// D272 (owner: the car stutters, freezes, has no sound): each entrance's
/// art is read ahead as it is queued ([VipSvgaCache.warm], off the UI
/// isolate); the car starts only when it can play ([carWait] to get
/// there, else it is skipped — its file stays read for the next time) and
/// then has its own length (at most [carLimit]); its SVGA's own sound
/// plays with it while «المؤثرات الصوتية» is on (the banner's, when there
/// is no car); one entrance's sound at a time, none with reduced motion.
class LiveVipEntranceLayer extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key, this.self});

  final String roomId;

  /// D265 (owner: the VIP1 host saw no entry car): the host is never a
  /// viewer, so no `join` names them — their own entrance (banner and car)
  /// plays once on their screen when the layer starts (the live goes on
  /// air, or the host comes back to it). Null on a viewer's screen (their
  /// own `join` brings theirs).
  final UserSummary? self;

  /// Tests and captures turn the slide off.
  static bool animate = true;

  static const bannerKey = Key('live.vipEntrance.banner');
  static const nameKey = Key('live.vipEntrance.name');
  static const carKey = Key('live.vipEntrance.car');

  /// The agents' bar timing (D185).
  static const duration = Duration(milliseconds: 3200);
  static const stillDuration = Duration(milliseconds: 2200);

  /// The car never plays longer than this.
  static const carLimit = Duration(seconds: 10);

  /// D272: how long the car may take to be ready (download, read, the
  /// first second decoded) before it is skipped.
  static const carWait = Duration(seconds: 8);
  static const maxQueued = 5;

  @override
  ConsumerState<LiveVipEntranceLayer> createState() =>
      _LiveVipEntranceLayerState();
}

class _Entry {
  new(this.line, this.look, {required this.banner, required this.car});

  final LiveChatJoinLine line;
  final VipLook look;
  final VipPerk? banner;
  final VipPerk? car;
}

class _LiveVipEntranceLayerState extends ConsumerState<LiveVipEntranceLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;
  final _queue = Queue<_Entry>();
  _Entry? _current;
  bool _bannerDone = true;
  bool _carDone = true;
  Timer? _carLimit;
  int _seen = -1;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _bannerDone = true;
          _maybeNext();
        }
      });
    _seen = ref.read(liveChatProvider(widget.roomId)).latestJoin?.serial ?? -1;
    _selfPending = widget.self?.vip != null;
  }

  /// D265: the host's own entrance waits for the catalogue.
  bool _selfPending = false;

  void _maybeSelf(VipTierList? catalog) {
    final self = widget.self;
    if (!_selfPending || self == null || catalog == null) return;
    _selfPending = false;
    // After this build (it sets the state); a serial no join of this
    // visit has (joins count up from 0).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _enqueue(LiveChatJoinLine(self, -1), catalog);
    });
  }

  @override
  void dispose() {
    _carLimit?.cancel();
    _clock.dispose();
    super.dispose();
  }

  static bool _hasArt(VipPerk? p) =>
      p != null && (p.still != null || p.animation != null);

  void _onChat(LiveChatState next) {
    final line = next.latestJoin;
    if (line == null || line.serial <= _seen) return;
    _seen = line.serial;
    _enqueue(line, ref.read(vipCatalogProvider).value);
  }

  void _enqueue(LiveChatJoinLine line, VipTierList? catalog) {
    final look = vipLookOf(line.user.vip, catalog);
    if (look == null) return;
    // An agent's bar (D185 / D189) wins over the banner.
    final agent =
        line.user.rechargeAgentCode != null || line.user.hostAgentCode != null;
    final bannerPerk = look.perk(VipPerks.entryBanner);
    final carPerk = look.perk(VipPerks.entryEffect);
    final banner = !agent && bannerPerk != null ? bannerPerk : null;
    final car = _hasArt(carPerk) ? carPerk : null;
    if (banner == null && car == null) return;
    final entry = _Entry(line, look, banner: banner, car: car);
    // D272: read the art now (while the banner, or an earlier entrance,
    // plays), so the car starts at once.
    if (VipSvga.enabled && VipAnimatedArt.animationsEnabled) {
      for (final url in [car?.animation, banner?.animation]) {
        if (url != null && url.startsWith('http')) {
          unawaited(VipSvgaCache.warm(url));
        }
      }
    }
    if (_current == null) {
      _show(entry);
    } else if (_queue.length < LiveVipEntranceLayer.maxQueued) {
      _queue.add(entry);
    }
  }

  void _show(_Entry entry) {
    final still =
        !LiveVipEntranceLayer.animate ||
        MediaQuery.disableAnimationsOf(context);
    _bannerDone = entry.banner == null;
    _carDone = entry.car == null;
    _carLimit?.cancel();
    if (!_carDone) {
      _carLimit = Timer(LiveVipEntranceLayer.carWait, _onCarDone);
    }
    setState(() => _current = entry);
    if (!_bannerDone) {
      _clock.duration = still
          ? LiveVipEntranceLayer.stillDuration
          : LiveVipEntranceLayer.duration;
      _clock.forward(from: 0);
    }
  }

  /// D272: the car plays now: it has its own length from here.
  void _onCarStarted(Duration length) {
    if (_carDone) return;
    _carLimit?.cancel();
    final limit = length + const Duration(seconds: 1);
    _carLimit = Timer(
      limit < LiveVipEntranceLayer.carLimit
          ? limit
          : LiveVipEntranceLayer.carLimit,
      _onCarDone,
    );
  }

  void _onCarDone() {
    if (_carDone) return;
    _carDone = true;
    _carLimit?.cancel();
    if (mounted) setState(() {}); // the car leaves.
    _maybeNext();
  }

  void _maybeNext() {
    if (!mounted || !_bannerDone || !_carDone) return;
    if (_queue.isEmpty) {
      setState(() => _current = null);
    } else {
      _show(_queue.removeFirst());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(liveChatProvider(widget.roomId), (_, next) => _onChat(next))
      // The catalogue is needed by the time someone joins.
      ..watch(vipCatalogProvider);
    // D265: the host's own entrance once the catalogue is read.
    _maybeSelf(ref.read(vipCatalogProvider).value);
    final current = _current;
    if (current == null) return const SizedBox.shrink();
    final displayName = current.line.user.displayName.trim();
    final name = displayName.isEmpty ? current.line.user.username : displayName;
    final banner = current.banner;
    final car = current.car;
    // D272: the SVGA's own sound, while the app's sound effects are on.
    final soundOn = ref.watch(soundEffectsProvider);
    return IgnorePointer(
      child: Stack(
        children: [
          if (car != null && !_carDone)
            Positioned.fill(
              key: LiveVipEntranceLayer.carKey,
              child: Center(
                child: FractionallySizedBox(
                  widthFactor: 1,
                  child: AspectRatio(
                    aspectRatio: _aspect(car, 1),
                    child: VipAnimatedArt(
                      key: ValueKey('vipCar.${current.line.serial}'),
                      animation: car.animation,
                      still: car.still,
                      video: car.video,
                      once: true,
                      onDone: _onCarDone,
                      onStarted: _onCarStarted,
                      sound: soundOn,
                    ),
                  ),
                ),
              ),
            ),
          if (banner != null && !_bannerDone)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: VipEntranceBanner.sideMargin,
              ),
              child: Align(
                // The agents' bar place (D185), above the chat.
                alignment: const AlignmentDirectional(-1, 0.08),
                child: _slide(
                  VipEntranceBanner(
                    key: ValueKey('vipBanner.${current.line.serial}'),
                    name: name,
                    look: current.look,
                    perk: banner,
                    // The car's sound wins over the banner's.
                    sound: soundOn && car == null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slide(Widget bar) {
    final moving =
        LiveVipEntranceLayer.animate &&
        !MediaQuery.disableAnimationsOf(context);
    if (!moving) return bar;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, child) {
        final t = _clock.value;
        final double dx;
        if (t < 0.14) {
          dx = -1.2 * (1 - Curves.easeOutCubic.transform(t / 0.14));
        } else if (t > 0.86) {
          dx = 2.4 * Curves.easeInCubic.transform((t - 0.86) / 0.14);
        } else {
          dx = 0;
        }
        return FractionalTranslation(
          translation: Offset(rtl ? -dx : dx, 0),
          child: child,
        );
      },
      child: bar,
    );
  }
}

double _aspect(VipPerk perk, double fallback) {
  final w = perk.artWidth;
  final h = perk.artHeight;
  return w != null && h != null && w > 0 && h > 0 ? w / h : fallback;
}

/// D258: the ENTRY_BANNER — the owner's banner art (its own proportions,
/// [widthFactor] of the screen) with «دخل سارة البث» on a dark plate in its
/// middle (white text ≥ 7:1 whatever the art). Without art: a bar in deep
/// shades of the tier's colour with the VIP badge.
class VipEntranceBanner extends StatelessWidget {
  const new({
    required this.name,
    required this.look,
    required this.perk,
    super.key,
    this.sound = false,
  });

  final String name;

  /// D272: the banner's SVGA plays its own sound.
  final bool sound;

  final VipLook look;
  final VipPerk perk;

  static const widthFactor = 0.62;
  static const sideMargin = 16.0;

  /// The plate under the text: black at 70 %, so white text is ≥ 7:1 on
  /// any art.
  static const plate = Color(0xB3000000);

  /// The owner's banner template (`svip_name`, 660 × 150): its own emblem
  /// at the start (no picture, owner), the line in its bar (x 132 – 554,
  /// y 40 – 111).
  static const double slotTemplate = 660 / 150;

  static const slot = Rect.fromLTRB(0.2, 0.27, 0.84, 0.74);

  /// The line's colour (owner): plain near-black on the light green bar
  /// (≈ 10:1 on its middle) — the special yellow stays on names.
  static const textColor = Color(0xFF102010);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final screen = MediaQuery.sizeOf(context).width;
    final hasArt = perk.still != null || perk.animation != null;
    return LayoutBuilder(
      builder: (context, box) {
        final room = box.maxWidth.isFinite ? box.maxWidth : screen;
        final width = math.min(screen * widthFactor, room);
        final plays = vipPlays(perk);
        final height = width / _aspect(perk, plays ? slotTemplate : 4);
        if (plays) {
          // The owner's banner: the name in its bar (the template's slot),
          // dark or white by the bar's own brightness.
          return Semantics(
            liveRegion: true,
            label: l10n.agentEntranceJoined(name),
            excludeSemantics: true,
            child: SizedBox(
              key: LiveVipEntranceLayer.bannerKey,
              width: width,
              height: height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: VipSvga(
                      url: perk.animation!,
                      fit: BoxFit.fill,
                      sound: sound,
                      still: perk.still == null
                          ? null
                          : Image(
                              image: vipArtImage(perk.still!),
                              fit: BoxFit.fill,
                            ),
                    ),
                  ),
                  // «سارة دخل الغرفة» in plain near-black on the art's bar
                  // (owner), no plate.
                  Positioned.directional(
                    textDirection: TextDirection.ltr,
                    start: width * slot.left,
                    top: height * slot.top,
                    width: width * slot.width,
                    height: height * slot.height,
                    child: Center(
                      // The tier's gold (CHAT_NAME_COLOR, owner).
                      child: _NameLine(
                        vip: look.vip,
                        name: name,
                        size: math.max(10, height * 0.27),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        final text = Container(
          padding: EdgeInsets.symmetric(
            horizontal: height * 0.16,
            vertical: height * 0.05,
          ),
          decoration: BoxDecoration(
            color: plate,
            borderRadius: BorderRadius.circular(height),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  l10n.agentEntranceJoined(KFormat.bidiIsolate(name)),
                  key: LiveVipEntranceLayer.nameKey,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: context.textStyles.title.copyWith(
                    fontSize: math.max(10, height * 0.26),
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
              // D268 (owner): the VIP badge after the name, never before.
              if (!hasArt) ...[
                SizedBox(width: height * 0.08),
                VipNameBadge(vip: look.vip, height: height * 0.34),
              ],
            ],
          ),
        );
        return Semantics(
          liveRegion: true,
          label: l10n.agentEntranceJoined(name),
          excludeSemantics: true,
          child: SizedBox(
            key: LiveVipEntranceLayer.bannerKey,
            width: width,
            height: height,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: hasArt
                      ? VipAnimatedArt(
                          animation: perk.animation,
                          still: perk.still,
                          video: perk.video,
                          fit: BoxFit.fill,
                          sound: sound,
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(height / 2),
                            gradient: LinearGradient(
                              colors: [
                                look.bubbleShades.$1,
                                look.bubbleShades.$2,
                              ],
                            ),
                            border: Border.all(color: const Color(0xCCFFE08A)),
                          ),
                        ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: width * 0.12),
                  child: text,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// «{name} دخل الغرفة» on the owner's banner: near-black, semi-bold, one
/// line; only the name ellipsizes (the phrase stays
/// whole).
class _NameLine extends StatelessWidget {
  const new({required this.vip, required this.name, required this.size});

  final UserVip vip;
  final String name;
  final double size;

  /// The name's slot in the localized phrase (split around it).
  static const _slot = '\u0000';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parts = l10n.vipEntranceJoined(_slot).split(_slot);
    final style = context.textStyles.title.copyWith(
      fontSize: size,
      height: 1.1,
      // The chat's weight (semi-bold), not extra bold (owner).
      fontWeight: FontWeight.w600,
      color: VipEntranceBanner.textColor,
    );
    Text piece(String t) =>
        Text(t, maxLines: 1, textScaler: TextScaler.noScaling, style: style);
    final before = parts.first;
    final after = parts.length > 1 ? parts.last : '';
    return Row(
      key: LiveVipEntranceLayer.nameKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (before.isNotEmpty) piece(before),
        Flexible(
          child: Text(
            KFormat.bidiIsolate(name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textScaler: TextScaler.noScaling,
            style: style,
          ),
        ),
        if (after.isNotEmpty) piece(after),
      ],
    );
  }
}
