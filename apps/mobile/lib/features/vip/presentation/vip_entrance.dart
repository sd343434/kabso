import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/core/svga/svga_engine.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/vip/application/vip_entrance_plays.dart';
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
/// then has its own length (D331: the whole file, at most [carLimit], an
/// MP4 too; full screen, [carFitFor] — or, D373, in the half-screen band
/// [halfBand] when the panel set the car HALF_SCREEN); its SVGA's own sound
/// plays with it while «المؤثرات الصوتية» is on (the banner's, when there
/// is no car); one entrance's sound at a time, none with reduced motion.
class LiveVipEntranceLayer extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key, this.self});

  final String roomId;

  /// D265 (owner: the VIP1 host saw no entry car): the host is never a
  /// viewer, so no `join` names them — their own entrance (banner and car)
  /// plays once on their screen when the live goes on air. D280: once per
  /// live ([VipEntrancePlays]), not again when the minimized live is opened
  /// again. Null on a viewer's screen (their own `join` brings theirs).
  final UserSummary? self;

  /// Tests and captures turn the slide off.
  static bool animate = true;

  static const bannerKey = Key('live.vipEntrance.banner');
  static const nameKey = Key('live.vipEntrance.name');
  static const carKey = Key('live.vipEntrance.car');

  /// D331: the layer's own key in the live screen's stack, so a sibling
  /// layer coming or going (the host's hint, diagnostics, the tap layer)
  /// never builds it anew — that dropped the car mid-way, and it was not
  /// played again.
  static const layerKey = Key('live.vipEntrance.layer');

  /// v1.72-live (D283, owner: «سيارة دخولية للمشرفين والإدارة»): the Kabso
  /// Team's own entry car (assets/staff/PROVENANCE.md), the only entrance a
  /// limited staff account ever has (no VIP or store car, banner or effect).
  static const teamCarAsset = 'assets/staff/kabso_team_entry.svga';
  static const teamCarSource = '${SvgaDocs.assetPrefix}$teamCarAsset';

  /// The agents' bar timing (D185).
  static const duration = Duration(milliseconds: 3200);
  static const stillDuration = Duration(milliseconds: 2200);

  /// D331 (owner: «سيارة الدخلة … يتم اقتصاص من وقتها»): the car plays
  /// its file's own length; this is only the safety cap — the panel's
  /// upload limit for an animated entrance (an MP4 ≤ 15 s plus its 0.5 s
  /// tolerance, §10.98.5), so no file the panel accepts is ever cut (was
  /// 10 s, which cut every car longer than that, and an MP4 car counted
  /// it from its download).
  static const carLimit = Duration(milliseconds: 15500);

  /// D331: a moment after the file's own end before the layer takes the
  /// car away itself (the player ends it at its length).
  static const carGrace = Duration(seconds: 1);

  /// D272: how long the car may take to be ready (download, read, the
  /// first second decoded; an MP4 too, D331) before it is skipped. It
  /// never counts against the car's own length.
  static const carWait = Duration(seconds: 8);

  /// Entrances waiting behind the one playing: each plays whole after the
  /// one before (never cut short by the next); a burst beyond this drops
  /// the newest (D331: a full queue already holds over a minute of cars).
  static const maxQueued = 5;

  /// D331 (owner: «سيارة الدخلة لا تُعرض بشاشة كاملة»): a portrait or
  /// square car **covers the whole live screen** like a full-screen gift
  /// (D317), its aspect kept: equal strips cut at the two sides, or its top
  /// cut — never a band of the room left. D280 stays: its drawn bottom on
  /// the screen's bottom (the rows it never draws left out). What the art
  /// leaves transparent stays transparent.
  static const BoxFit carFit = BoxFit.cover;
  static const Alignment carAlignment = Alignment.bottomCenter;

  /// D331: the fit for a car's canvas: [carFit] for a portrait or square
  /// one; a landscape (banner-shaped) one keeps D280's full width at the
  /// bottom — covering would cut most of its art away.
  static BoxFit carFitFor(Size canvas) =>
      canvas.isEmpty || canvas.width <= canvas.height
      ? carFit
      : BoxFit.fitWidth;

  /// v1.128-social (D373, §10.165; owner: «سيارات الدخول ستكون اما بشاشة
  /// كاملة او نصف الشاشة … من لوحة الادمن انت تحدد»): how a car plays is
  /// the server's value for that car ([VipPerk.entryDisplay]: the VIP
  /// ENTRY_EFFECT perk's, or the worn store car's); none (an older server)
  /// is [EntryDisplay.fullScreen], today's look (D331).
  static EntryDisplay displayOf(VipPerk car) =>
      car.entryDisplay ?? EntryDisplay.fullScreen;

  /// D373: a HALF_SCREEN car's band is at most this part of the screen's
  /// height.
  static const double halfBandHeightFactor = 0.5;

  /// D373: in its band the car is drawn whole (its aspect kept, centred):
  /// the band's full width for a car wider than the band, its full height
  /// for a taller one. Nothing it draws leaves the band.
  static const BoxFit halfFit = BoxFit.contain;
  static const Alignment halfAlignment = Alignment.center;

  /// D373: the half-screen band on a [screen] with the system [padding] —
  /// the screen's full width, from under the room's header row (the status
  /// bar inset, the header gap and its 48 dp row) down to the top of the
  /// chat's space (the bottom bar's 48 dp row over the bottom inset and the
  /// chat's cap, [KMetrics.chatMaxHeightFactor]), at most
  /// [halfBandHeightFactor] of the screen high (its top moves down to keep
  /// it so). About half the screen on a phone: 397 of 852 at 393 × 852
  /// with insets 59 / 34. The banner (above the chat, D185's place) is
  /// inside the band and drawn over the car.
  static Rect halfBand(Size screen, EdgeInsets padding) {
    final headerBottom =
        padding.top + KMetrics.liveHeaderGap + KSizes.minTouchTarget;
    final chatTop =
        screen.height -
        padding.bottom -
        KSizes.minTouchTarget -
        screen.height * KMetrics.chatMaxHeightFactor;
    final top = math.max(
      headerBottom,
      chatTop - screen.height * halfBandHeightFactor,
    );
    return Rect.fromLTRB(0, top, screen.width, math.max(top, chatTop));
  }

  /// D331: how long after it starts the layer lets a car of [length] play
  /// (its length and [carGrace], at most [carLimit]).
  static Duration carTimeout(Duration length) {
    final timeout = length + carGrace;
    return timeout < carLimit ? timeout : carLimit;
  }

  @override
  ConsumerState<LiveVipEntranceLayer> createState() =>
      _LiveVipEntranceLayerState();
}

class _Entry {
  new(this.line, this.look, {required this.banner, required this.car});

  final LiveChatJoinLine line;

  /// Null for the Kabso Team's entrance (D283: the car only).
  final VipLook? look;
  final VipPerk? banner;
  final VipPerk? car;
}

class _LiveVipEntranceLayerState extends ConsumerState<LiveVipEntranceLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;

  /// D280: what this room's visit already played (outlives this layer).
  late final VipEntrancePlays _plays;
  final _queue = Queue<_Entry>();
  _Entry? _current;
  bool _bannerDone = true;
  bool _carDone = true;
  Timer? _carLimit;

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
    _plays = ref.read(vipEntrancePlaysProvider);
    // D280: a join already in the chat (before this layer was built: the
    // live minimized and opened again) is never played now.
    final chat = ref.read(liveChatProvider(widget.roomId));
    final latest = chat.latestJoin;
    if (latest != null) _plays.takeJoin(widget.roomId, latest);
    // D283: the same for a Kabso Team entry.
    final staff = chat.latestStaffJoin;
    if (staff != null) _plays.takeStaffJoin(widget.roomId, staff);
    _selfPending = widget.self?.vip != null;
  }

  /// D265: the host's own entrance waits for the catalogue.
  bool _selfPending = false;

  void _maybeSelf(VipTierList? catalog) {
    final self = widget.self;
    if (!_selfPending || self == null || catalog == null) return;
    _selfPending = false;
    // D280: once per live, not each time its screen is built again.
    if (!_plays.takeSelf(widget.roomId)) return;
    // After this build (it sets the state).
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
    // v1.72-live (D283): a Kabso Team account's visible entry plays the
    // team's entry car — once per join, never again after minimize/restore.
    final staff = next.latestStaffJoin;
    if (staff != null && _plays.takeStaffJoin(widget.roomId, staff)) {
      if (_plays.takeUser(widget.roomId, staff.user.id)) _enqueueTeam(staff);
    }
    final line = next.latestJoin;
    if (line == null || !_plays.takeJoin(widget.roomId, line)) return;
    // D283: a Kabso Team account joining as a viewer (FINANCE): its fixed
    // picture marks it; the team's car, never a VIP or store one.
    if (isTeamAvatarUrl(line.user.avatarUrl)) {
      if (_plays.takeUser(widget.roomId, line.user.id)) _enqueueTeam(line);
      return;
    }
    final catalog = ref.read(vipCatalogProvider).value;
    // Only an entrance that would play counts as played (D280).
    if (vipLookOf(line.user.vip, catalog) == null) return;
    if (!_plays.takeUser(widget.roomId, line.user.id)) return;
    _enqueue(line, catalog);
  }

  /// D283: the Kabso Team's entrance — the bundled entry car only.
  void _enqueueTeam(LiveChatJoinLine line) {
    const car = VipPerk(
      code: VipPerks.entryEffect,
      title: '',
      available: true,
      animation: LiveVipEntranceLayer.teamCarSource,
    );
    if (VipSvga.enabled && VipAnimatedArt.animationsEnabled) {
      unawaited(VipSvgaCache.warm(LiveVipEntranceLayer.teamCarSource));
    }
    final entry = _Entry(line, null, banner: null, car: car);
    if (_current == null) {
      _show(entry);
    } else if (_queue.length < LiveVipEntranceLayer.maxQueued) {
      _queue.add(entry);
    }
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
      for (final perk in [car, banner]) {
        final url = perk?.animation;
        // (An MP4, D270, plays on the gifts' video path.)
        if (perk?.video == null && url != null && url.startsWith('http')) {
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
      // The car says when it starts (then has its own length). D331: an
      // MP4 (D270) too — its download no longer eats into its length.
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
    _carLimit = Timer(LiveVipEntranceLayer.carTimeout(length), _onCarDone);
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
    final half =
        car != null &&
        LiveVipEntranceLayer.displayOf(car) == EntryDisplay.halfScreen;
    return IgnorePointer(
      child: Stack(
        children: [
          if (car != null && !_carDone && half)
            // D373 (owner: «نصف الشاشة»): the car in its band, whole; the
            // room's header and chat stay clear. Never takes taps (the
            // layer ignores them), and plays once like a full-screen car.
            LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Positioned.fromRect(
                    key: LiveVipEntranceLayer.carKey,
                    rect: LiveVipEntranceLayer.halfBand(
                      box.biggest,
                      MediaQuery.paddingOf(context),
                    ),
                    child: ClipRect(
                      child: VipAnimatedArt(
                        key: ValueKey('vipCar.${identityHashCode(current)}'),
                        animation: car.animation,
                        still: car.still,
                        video: car.video,
                        // [LiveVipEntranceLayer.halfFit] and
                        // [LiveVipEntranceLayer.halfAlignment] are the art's
                        // defaults (contain, centred); the file's own canvas
                        // keeps them.
                        fitFor: (_) => LiveVipEntranceLayer.halfFit,
                        once: true,
                        onDone: _onCarDone,
                        onStarted: _onCarStarted,
                        sound: soundOn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (car != null && !_carDone && !half)
            // D280 (owner: «تبدأ من اسفل الشاشة بحيث لا يظهر فراغ من
            // اسفل»): its art's bottom (the rows it never draws left out)
            // on the screen's bottom edge. D331 (owner: «لا تُعرض بشاشة
            // كاملة»): over the whole live screen (this layer is above the
            // room's header, chat and gifts), a portrait or square car
            // covering it ([LiveVipEntranceLayer.carFitFor]).
            Positioned.fill(
              key: LiveVipEntranceLayer.carKey,
              child: ClipRect(
                child: VipAnimatedArt(
                  key: ValueKey('vipCar.${identityHashCode(current)}'),
                  animation: car.animation,
                  still: car.still,
                  video: car.video,
                  // The still's (and an unread file's) fit by the art's
                  // size from the panel; the file's own canvas decides
                  // once it is read.
                  fit: LiveVipEntranceLayer.carFitFor(_artSize(car)),
                  fitFor: LiveVipEntranceLayer.carFitFor,
                  alignment: LiveVipEntranceLayer.carAlignment,
                  trimBottom: true,
                  once: true,
                  onDone: _onCarDone,
                  onStarted: _onCarStarted,
                  sound: soundOn,
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
                    key: ValueKey('vipBanner.${identityHashCode(current)}'),
                    name: name,
                    look: current.look!,
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

/// The art's size from the panel (empty when unknown).
Size _artSize(VipPerk perk) {
  final w = perk.artWidth;
  final h = perk.artHeight;
  return w != null && h != null && w > 0 && h > 0
      ? Size(w.toDouble(), h.toDouble())
      : Size.zero;
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
