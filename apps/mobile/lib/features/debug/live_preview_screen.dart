import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/core/icons/kabso_art.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/debug/feed_glyphs.dart';
import 'package:kabso_live/features/debug/feed_share_sheet.dart';
import 'package:kabso_live/features/debug/live_host_ranking_sheet.dart';
import 'package:kabso_live/features/debug/live_preview_pk.dart';
import 'package:kabso_live/features/debug/live_viewers_sheet.dart';
import 'package:kabso_live/features/debug/preview_photo.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/battle_emoji.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// KL-056 preview of a full-screen live room in the owner's reference
/// layout (kept outside the repo, D40), in Kabso's identity.
/// `!kReleaseMode` only.
///
/// No live video or chat API exists yet (D37), so the host, viewers, chat
/// and counts are labelled test fixtures over generated art. TikTok's own
/// marks (pink follow, LIVE leagues, coin promo, promote button) are not
/// reproduced: Kabso red, a test weekly-rank chip and a More button take
/// their places.
class LivePreviewScreen extends StatefulWidget {
  const new({
    super.key,
    this.mode = LivePreviewMode.solo,
    this.simulate = false,
    this.host = false,
  });

  /// D71: one host, a 1-v-1 PK or a 2-v-2 PK (owner's references).
  final LivePreviewMode mode;

  /// D73: start the simulated PK round on open (`?simulate=1`), for
  /// captures.
  final bool simulate;

  /// D80: the host's own view (`?host=1`): only the host gets Host settings
  /// (≡); viewers never see the chat-size control.
  final bool host;

  static const testDataKey = Key('livePreview.testData');
  static const hostPillKey = Key('livePreview.host');
  static const followKey = Key('livePreview.follow');
  static const rankKey = Key('livePreview.rank');
  static const galleryKey = Key('livePreview.gallery');
  static const viewersKey = Key('livePreview.viewers');
  static const closeKey = Key('livePreview.close');
  static const moreKey = Key('livePreview.more');
  static const chatSizeKey = Key('livePreview.chatSize');
  static const shareOptionKey = Key('livePreview.more.share');
  static const reportOptionKey = Key('livePreview.more.report');
  static const chatKey = Key('livePreview.chat');
  static const bottomBarKey = Key('livePreview.bottomBar');
  static const inputKey = Key('livePreview.input');
  static const stageKey = Key('livePreview.stage');
  static Key battleOptionKey(KabsoBattle b) =>
      Key('livePreview.battle.${b.id}');
  static const simulateKey = Key('livePreview.simulateRound');

  @override
  State<LivePreviewScreen> createState() => _LivePreviewScreenState();
}

class _LivePreviewScreenState extends State<LivePreviewScreen> {
  KabsoBattle? _battle;
  var _battleRun = 0;
  var _opened = false;

  /// D73, debug only: a simulated round replacing the fixture's scores.
  PkPreview? _round;
  var _showOutcome = false;

  /// D79: the chat type size from Host settings.
  LiveChatTextSize _chatSize = LiveChatTextSize.medium;
  var _simulation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_opened || widget.mode == LivePreviewMode.solo) return;
    _opened = true;
    if (widget.simulate) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_simulateRound()),
      );
      return;
    }
    _battle = pkPreviewFixture(
      mode: widget.mode,
      ar: Directionality.of(context) == TextDirection.rtl,
    ).opening;
  }

  /// D71, debug only: the test-data label replays any battle animation.
  Future<void> _pickBattle() async {
    final l10n = context.l10n;
    final picked = await showModalBottomSheet<KabsoBattle>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
              child: Text(
                l10n.livePreviewPlayBattle,
                style: context.textStyles.title,
              ),
            ),
            const SizedBox(height: KSpacing.sm),
            ListTile(
              key: LivePreviewScreen.simulateKey,
              leading: const Icon(Icons.sports_mma_rounded),
              title: Text(l10n.livePreviewSimulateRound),
              onTap: () {
                Navigator.pop(context);
                unawaited(_simulateRound());
              },
            ),
            for (final b in KabsoBattle.values)
              ListTile(
                key: LivePreviewScreen.battleOptionKey(b),
                leading: const Icon(Icons.play_circle_outline_rounded),
                title: Text(b.label(l10n)),
                onTap: () => Navigator.pop(context, b),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _battle = picked;
      _battleRun++;
    });
  }

  /// D73, debug only: plays a whole round on the score bar so every state
  /// of Kabi can be checked — waiting at 0–0, the opening gifts (a big
  /// burst: fire), small gains for the host's team (push), a big gain for
  /// the opponents (fire on their side), small gains for the opponents
  /// (push the other way), the last ten seconds (tense), then the result
  /// (win toward the winner) and, 600 ms later, win / lose on each side.
  Future<void> _simulateRound() async {
    final run = ++_simulation;
    final base = pkPreviewFixture(
      mode: widget.mode,
      ar: Directionality.of(context) == TextDirection.rtl,
    );
    var start = 0;
    var end = 0;
    var left = const Duration(seconds: 30);
    bool alive() => mounted && run == _simulation;
    void show([PkOutcome? outcome]) => setState(
      () => _round = base.at(
        startScore: start,
        endScore: end,
        timeLeft: left,
        outcome: outcome,
      ),
    );
    Future<bool> wait(int ms) async {
      await Future<void>.delayed(Duration(milliseconds: ms));
      if (!alive()) return false;
      left -= Duration(milliseconds: ms);
      if (left.isNegative) left = Duration.zero;
      return true;
    }

    setState(() {
      _showOutcome = false;
      _battle = KabsoBattle.start;
      _battleRun++;
    });
    show();
    if (!await wait(3000)) return;
    start += 5000;
    end += 4800;
    show();
    if (!await wait(3000)) return;
    for (var i = 0; i < 5; i++) {
      start += 60;
      show();
      if (!await wait(400)) return;
    }
    if (!await wait(1500)) return;
    end += (start + end) * 8 ~/ 100;
    show();
    if (!await wait(3000)) return;
    for (var i = 0; i < 4; i++) {
      end += 50;
      show();
      if (!await wait(400)) return;
    }
    if (!await wait(1500)) return;
    while (left > Duration.zero) {
      show();
      if (!await wait(1000)) return;
    }
    show(
      start == end
          ? PkOutcome.draw
          : start > end
          ? PkOutcome.startWins
          : PkOutcome.endWins,
    );
    if (!await wait(600)) return;
    setState(() => _showOutcome = true);
  }

  /// D79 (owner): Host settings from the ≡ button. For now one setting:
  /// the chat's type size. Preview only: it applies here, locally; for
  /// viewers it would need a live room settings API.
  Future<void> _openHostSettings() async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              0,
              KSpacing.lg,
              KSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.livePreviewHostSettings,
                  style: sheet.textStyles.title,
                ),
                const SizedBox(height: KSpacing.lg),
                Text(
                  l10n.livePreviewChatTextSize,
                  style: sheet.textStyles.bodyStrong,
                ),
                const SizedBox(height: KSpacing.sm),
                SegmentedButton<LiveChatTextSize>(
                  key: LivePreviewScreen.chatSizeKey,
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: LiveChatTextSize.small,
                      label: Text(l10n.livePreviewTextSmall),
                    ),
                    ButtonSegment(
                      value: LiveChatTextSize.medium,
                      label: Text(l10n.livePreviewTextMedium),
                    ),
                    ButtonSegment(
                      value: LiveChatTextSize.large,
                      label: Text(l10n.livePreviewTextLarge),
                    ),
                  ],
                  selected: {_chatSize},
                  onSelectionChanged: (v) {
                    setState(() => _chatSize = v.first);
                    setSheet(() {});
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final ar = Directionality.of(context) == TextDirection.rtl;
    final room = livePreviewFixture(ar: ar);
    final pk = mode == LivePreviewMode.solo
        ? null
        : _round ?? pkPreviewFixture(mode: mode, ar: ar);
    final header = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: KLivePreview.edge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // On narrow screens or large text the host pill gives way
              // (its name truncates); the viewer cluster and Close keep
              // their size.
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _HostPill(room: room),
                ),
              ),
              const SizedBox(width: KSpacing.sm),
              _ViewerCluster(room: room),
            ],
          ),
          const SizedBox(height: KLivePreview.pillToChip),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // On narrow screens the test-data label gives way
                    // before the rank.
                    Flexible(flex: 3, child: _RankChip(room: room)),
                    const SizedBox(width: KSpacing.xs),
                    Flexible(
                      flex: 2,
                      child: _TestDataLabel(
                        onTap: pk == null ? null : _pickBattle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: KSpacing.xs),
              _GalleryChip(have: room.galleryHave, total: room.galleryTotal),
            ],
          ),
        ],
      ),
    );
    final footer = Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: KLivePreview.edge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Chat(room: room, size: _chatSize),
          const SizedBox(height: KLivePreview.chatToBar),
          _BottomBar(
            room: room,
            onMenu: widget.host ? _openHostSettings : null,
          ),
          const SizedBox(height: KSpacing.xs),
        ],
      ),
    );
    return Theme(
      data: buildAppTheme(
        brightness: Brightness.dark,
        locale: Localizations.localeOf(context),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: pk == null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Semantics(
                    image: true,
                    label: context.l10n.liveVideoPlaceholder,
                    child: const PreviewPhoto(4, photoSeed: 0),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0, 0.18, 0.55, 1],
                        colors: [
                          Color(0x59000000),
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0x8C000000),
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [header, const Spacer(), footer],
                    ),
                  ),
                ],
              )
            // PK (D71): a black room; the stage under the header, the chat
            // under the stage.
            : SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: KLivePreview.headerToStage),
                    LivePreviewPkStage(
                      key: LivePreviewScreen.stageKey,
                      pk: pk,
                      battle: _battle,
                      battleRun: _battleRun,
                      onBattleDone: () => setState(() => _battle = null),
                      showOutcome: _showOutcome,
                    ),
                    // The newest chat lines sit on the bar; older ones fade
                    // out under the supporters when space runs short.
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: KSpacing.sm),
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (r) => LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: [0, (28 / r.height).clamp(0, 1)],
                            colors: const [
                              Color(0x00000000),
                              Color(0xFF000000),
                            ],
                          ).createShader(r),
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.bottomCenter,
                              maxHeight: double.infinity,
                              child: footer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Layout values measured on the owner's reference (923×2000 px at
/// 2.1465 px/lp → 430×932 lp) with measure.py and colour masks (M), or read
/// from zoomed crops (E).
/// D79 (owner): the chat's type size, chosen by the host in Host settings
/// (preview: local only). Medium is the default, a step smaller than D76.
enum LiveChatTextSize {
  small(name: 10.5, text: 11, badge: 11),
  medium(name: 11, text: 12, badge: 12),
  large(name: 12, text: 14, badge: 13);

  new({required this.name, required this.text, required this.badge});

  final double name;
  final double text;
  final double badge;
}

abstract final class KLivePreview {
  static const double edge = 11; // M: 23–24 px side margins
  static const double hostPillHeight = 35; // M: 75 px
  static const double hostAvatar = 35; // M
  static const double followHeight = 24; // D79: smaller than M 27
  static const double followMaxWidth = 74; // M: 159 px
  static const double pillToChip = 6.5; // M: 14 px
  static const double chipHeight = 24; // M: 51 px

  /// D71 PK references: second chip row → score bar (M: 268 → 388 px).
  static const double headerToStage = 54;
  static const double viewerAvatar = 24; // D80: top supporters' photos
  static const double viewerOverlap = 9; // D80: stacked photos
  static const double viewerTrioMinWidth = 380; // D80
  static const double collapseIcon = 20; // E: ~38 px circle
  static const double closeIcon = 18; // E
  /// D78: three header buttons (minimise, ⋯, close) share the room the
  /// two had: 32 wide, 44 tall.
  static final ButtonStyle headerButton = IconButton.styleFrom(
    fixedSize: const Size(32, 44),
    minimumSize: const Size(32, 44),
    padding: EdgeInsets.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
  static const double chatAvatar = 28; // M: 61 px
  static const double chatGap = 6.5; // M: 14 px avatar → text
  static const double chatRowGap = 6; // D77: bubbles stack closer

  static const double chatBadgeGap = 3;
  static const double chatMaxWidthFraction = 0.82; // D77: room for bubbles
  static const double chatToBar = 20; // M: 42 px
  static const double barHeight = 38; // D77 reference: 114 px @3x
  static const double barGap = 8; // D77 reference: 24 px
  static const double barIcon = 22; // E

  /// D77: the gift box art fills most of its circle; the red dot.
  static const double barArt = 30;
  static const double barDot = 9;
  static const Color dotColor = Color(0xFFFF2D55);

  /// D77: the field and the round buttons share one grey glass, visible
  /// on dark and light video alike (the reference's grey).
  static const Color barGlass = Color(0x66808080);

  /// D77: chat lines sit in a bubble of the same grey, lighter.
  static const Color chatBubble = Color(0x4D6E6E6E);
  static const double chatBubbleRadius = 18;

  /// Translucent fill of the pill, chips and round buttons over video.
  static const Color glass = Color(0x47000000);
  static const Color inputGlass = Color(0x24FFFFFF);
  static const Color coin = Color(0xFFF5C518);

  static const List<Shadow> textShadow = [
    Shadow(color: Color(0x80000000), blurRadius: 3, offset: Offset(0, 1)),
  ];
}

class _HostPill extends StatelessWidget {
  const new({required this.room});

  final LivePreviewRoom room;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final white = KPalette.dark.textPrimary;
    return Container(
      key: LivePreviewScreen.hostPillKey,
      // The measured height; large text may grow it instead of clipping.
      constraints: const BoxConstraints(minHeight: KLivePreview.hostPillHeight),
      decoration: BoxDecoration(
        color: KLivePreview.glass,
        borderRadius: BorderRadius.circular(KLivePreview.hostPillHeight / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KAvatar(name: room.hostName, size: KLivePreview.hostAvatar),
          const SizedBox(width: KSpacing.xs),
          Flexible(
            child: ConstrainedBox(
              // D79: a little more room for the name, smaller type.
              constraints: const BoxConstraints(maxWidth: 104),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.hostName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(
                      fontSize: 13,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: white,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          KFormat.compact(room.hostLikes, l10n),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      const SizedBox(width: KSpacing.xxs),
                      FeedGlyphIcon(
                        FeedGlyph.heart,
                        size: 11,
                        color: white.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: KSpacing.sm),
          Semantics(
            button: true,
            label: l10n.liveFollow,
            excludeSemantics: true,
            child: InkWell(
              key: LivePreviewScreen.followKey,
              onTap: () {},
              borderRadius: BorderRadius.circular(
                KLivePreview.followHeight / 2,
              ),
              child: Container(
                height: KLivePreview.followHeight,
                // D79: hugs "+ Follow" (at most 74 wide; large text
                // ellipsizes) instead of a fixed 74.
                constraints: const BoxConstraints(
                  maxWidth: KLivePreview.followMaxWidth,
                ),
                padding: const EdgeInsetsDirectional.only(start: 4, end: 9),
                decoration: BoxDecoration(
                  color: p.primary,
                  borderRadius: BorderRadius.circular(
                    KLivePreview.followHeight / 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(AppIcons.plus, size: 14, color: p.onPrimary),
                    Flexible(
                      child: Text(
                        l10n.liveFollow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyStrong.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: KSpacing.xxs),
        ],
      ),
    );
  }
}

class _ViewerCluster extends StatelessWidget {
  const new({required this.room});

  final LivePreviewRoom room;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = KPalette.dark.textPrimary;
    const avatar = KLivePreview.viewerAvatar;
    final ar = Directionality.of(context) == TextDirection.rtl;
    final viewers = liveViewersFixture(ar: ar);
    // D80: the room's top three supporters, gold, silver and bronze.
    // On narrow phones (360 dp) only the first fits beside the count, and
    // none with large text (the count stays).
    final narrow =
        MediaQuery.sizeOf(context).width < KLivePreview.viewerTrioMinWidth;
    final largeText = MediaQuery.textScalerOf(context).scale(10) > 11.5;
    final shown = !narrow ? 3 : (largeText ? 0 : 1);
    final top = ([
      ...viewers,
    ]..sort((a, b) => b.support.compareTo(a.support))).take(shown).toList();
    const step = avatar - KLivePreview.viewerOverlap;
    return Row(
      key: LivePreviewScreen.viewersKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: l10n.liveViewers(
            room.viewers,
            KFormat.compact(room.viewers, l10n),
          ),
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => LiveViewersSheet.show(
              context,
              viewers: viewers,
              total: room.viewers,
              // The app's profile route (test users show its not-found
              // state: they do not exist on the server).
              onOpenProfile: (v) =>
                  GoRouter.maybeOf(context)
                      ?.push(AppRoutes.userProfile(v.username)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (top.isNotEmpty) ...[
                  SizedBox(
                    width: avatar + step * (top.length - 1),
                    height: avatar,
                    child: Stack(
                      children: [
                        // The first supporter on top, nearest the count.
                        for (var i = top.length - 1; i >= 0; i--)
                          PositionedDirectional(
                            end: i * step,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: KLiveRanks.rings[i],
                                  width: 2,
                                ),
                              ),
                              // The ring shows around the photo.
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: KAvatar(
                                  name: top[i].name,
                                  image: PreviewPhotos.asset(top[i].photo),
                                  size: avatar - 4,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 3),
                ],
                // D80: the count in a glass pill with a person mark.
                Container(
                  height: avatar,
                  padding: const EdgeInsetsDirectional.only(start: 5, end: 7),
                  decoration: BoxDecoration(
                    color: KLivePreview.glass,
                    borderRadius: BorderRadius.circular(avatar / 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 12,
                        color: white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        KFormat.compact(room.viewers, l10n),
                        textScaler: MediaQuery.textScalerOf(
                          context,
                        ).clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
                        style: context.textStyles.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          tooltip: l10n.livePreviewMinimize,
          onPressed: () {},
          style: KLivePreview.headerButton,
          icon: FeedGlyphIcon(
            FeedGlyph.collapse,
            size: KLivePreview.collapseIcon,
            color: white,
            shadow: true,
          ),
        ),
        // D78 (owner): ⋯ beside the close button: share or report.
        IconButton(
          key: LivePreviewScreen.moreKey,
          tooltip: l10n.livePreviewMore,
          onPressed: () => _openRoomMenu(context),
          style: KLivePreview.headerButton,
          icon: FeedGlyphIcon(
            FeedGlyph.more,
            size: KLivePreview.closeIcon + 2,
            color: white,
            shadow: true,
          ),
        ),
        IconButton(
          key: LivePreviewScreen.closeKey,
          tooltip: l10n.liveClose,
          onPressed: () => Navigator.maybePop(context),
          style: KLivePreview.headerButton,
          icon: FeedGlyphIcon(
            FeedGlyph.close,
            size: KLivePreview.closeIcon,
            color: white,
            shadow: true,
          ),
        ),
      ],
    );
  }
}

/// D78: the room's ⋯ sheet. Share opens the share sheet; reporting waits
/// for a report API, so it is shown as "Coming soon" and is not a button
/// (as on profiles, D62).
Future<void> _openRoomMenu(BuildContext context) async {
  final l10n = context.l10n;
  final share = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheet) {
      final p = sheet.palette;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: LivePreviewScreen.shareOptionKey,
              leading: Icon(Icons.share_outlined, color: p.textPrimary),
              title: Text(l10n.liveShare),
              onTap: () => Navigator.of(sheet).pop(true),
            ),
            ListTile(
              key: LivePreviewScreen.reportOptionKey,
              enabled: false,
              leading: Icon(Icons.flag_outlined, color: p.textTertiary),
              title: Text(
                l10n.profileReport,
                style: TextStyle(color: p.error.withValues(alpha: 0.6)),
              ),
              trailing: Text(
                l10n.profileEditSoon,
                style: sheet.textStyles.caption.copyWith(color: p.textTertiary),
              ),
            ),
          ],
        ),
      );
    },
  );
  if ((share ?? false) && context.mounted) {
    await FeedShareSheet.show(context);
  }
}

/// D85: the "Ranking list" chip; it opens the hosts' ranking (the room's
/// host among all hosts by hour, day, month and all time).
class _RankChip extends StatelessWidget {
  const new({required this.room});

  final LivePreviewRoom room;

  @override
  Widget build(BuildContext context) {
    final white = KPalette.dark.textPrimary;
    final ar = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => LiveHostRankingSheet.show(
          context,
          hosts: liveHostsFixture(
            ar: ar,
            hostName: room.hostName,
            hostUsername: room.hostUsername,
          ),
          hostUsername: room.hostUsername,
          onOpenProfile: (v) =>
              GoRouter.maybeOf(context)
                  ?.push(AppRoutes.userProfile(v.username)),
        ),
        child: _chip(context, white),
      ),
    );
  }

  Widget _chip(BuildContext context, Color white) {
    return Container(
      key: LivePreviewScreen.rankKey,
      height: KLivePreview.chipHeight,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: KSpacing.sm),
      decoration: BoxDecoration(
        color: KLivePreview.glass,
        borderRadius: BorderRadius.circular(KLivePreview.chipHeight / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              context.l10n.liveRankingList,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: white,
              ),
            ),
          ),
          const SizedBox(width: KSpacing.xxs),
          const FeedGlyphIcon(
            FeedGlyph.rank,
            size: 14,
            color: KLivePreview.coin,
          ),
        ],
      ),
    );
  }
}

/// The gift gallery's progress (D71): gifts this room has collected of
/// the gallery's total (test data).
class _GalleryChip extends StatelessWidget {
  const new({required this.have, required this.total});

  final int have;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = KPalette.dark.textPrimary;
    final t = context.textStyles;
    return Semantics(
      label: l10n.livePreviewGalleryProgress(
        KFormat.grouped(have),
        KFormat.grouped(total),
      ),
      excludeSemantics: true,
      child: Container(
        key: LivePreviewScreen.galleryKey,
        height: KLivePreview.chipHeight,
        padding: const EdgeInsetsDirectional.only(start: KSpacing.sm, end: 3),
        decoration: BoxDecoration(
          color: KLivePreview.glass,
          borderRadius: BorderRadius.circular(KLivePreview.chipHeight / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.livePreviewGallery,
              style: t.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(width: KSpacing.xs),
            Container(
              height: KLivePreview.chipHeight - 6,
              padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4B3BFF), Color(0xFF8E3BFF)],
                ),
                borderRadius: BorderRadius.circular(KRadius.pill),
              ),
              alignment: Alignment.center,
              child: Text(
                '${KFormat.grouped(have)}/${KFormat.grouped(total)}',
                textDirection: TextDirection.ltr,
                style: t.caption.copyWith(
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestDataLabel extends StatelessWidget {
  const new({this.onTap});

  /// Debug only: opens the battle-animation picker in the PK layouts.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: DecoratedBox(
      key: LivePreviewScreen.testDataKey,
      decoration: BoxDecoration(
        color: KLiveColors.chatScrim,
        borderRadius: BorderRadius.circular(KRadius.xs),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: KSpacing.xs,
          vertical: KSpacing.xxs,
        ),
        child: Text(
          context.l10n.feedPreviewTestData,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textStyles.caption.copyWith(
            color: KPalette.dark.textPrimary,
          ),
        ),
      ),
    ),
  );
}

class _Chat extends StatelessWidget {
  const new({required this.room, required this.size});

  final LivePreviewRoom room;
  final LiveChatTextSize size;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final white = KPalette.dark.textPrimary;
    final maxWidth =
        MediaQuery.sizeOf(context).width * KLivePreview.chatMaxWidthFraction;

    // D76 (owner): every line shows the person's photo, their level in
    // each system beside the name, and a smaller text.
    Widget avatarFor(LivePreviewMessage m) => KAvatar(
      name: m.name,
      image: PreviewPhotos.asset(m.photo),
      size: KLivePreview.chatAvatar,
    );

    final nameStyle = t.caption.copyWith(
      fontSize: size.name,
      fontWeight: FontWeight.w600,
      color: white.withValues(alpha: 0.75),
      shadows: KLivePreview.textShadow,
    );

    // One line: the name gives way (ellipsis) so the four badges always
    // sit beside it.
    Widget nameRow(LivePreviewMessage m) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            m.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
        ),
        for (final c in LevelCategory.values)
          if (m.levels[c] case final level?) ...[
            const SizedBox(width: KLivePreview.chatBadgeGap),
            KLevelBadge(category: c, levelNumber: level, height: size.badge),
          ],
      ],
    );

    Widget row(LivePreviewMessage m) => Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 12, 5),
        decoration: BoxDecoration(
          color: KLivePreview.chatBubble,
          borderRadius: BorderRadius.circular(KLivePreview.chatBubbleRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            avatarFor(m),
            const SizedBox(width: KLivePreview.chatGap),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  nameRow(m),
                  if (m.joined) ...[
                    const SizedBox(height: 2),
                    Text(
                      l10n.livePreviewJoinedLine,
                      style: t.bodyStrong.copyWith(
                        fontSize: size.text,
                        fontWeight: FontWeight.w600,
                        color: white.withValues(alpha: 0.85),
                        shadows: KLivePreview.textShadow,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 2),
                    // D71: chat lines show Kabi emojis inline.
                    KabiEmojiText(
                      m.text,
                      style: t.bodyStrong.copyWith(
                        fontSize: size.text,
                        fontWeight: FontWeight.w600,
                        color: white,
                        shadows: KLivePreview.textShadow,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          key: LivePreviewScreen.chatKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < room.chat.length; i++) ...[
              if (i > 0) const SizedBox(height: KLivePreview.chatRowGap),
              row(room.chat[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const new({required this.room, this.onMenu});

  final LivePreviewRoom room;

  /// D79/D80: the ≡ button opens Host settings; the host's view only
  /// (null hides it).
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final white = KPalette.dark.textPrimary;

    Widget round(
      String label,
      Widget glyph, {
      String? caption,
      VoidCallback? onTap,
      bool dot = false,
    }) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap ?? () {},
        customBorder: const CircleBorder(),
        child: Container(
          width: KLivePreview.barHeight,
          height: KLivePreview.barHeight,
          decoration: const BoxDecoration(
            color: KLivePreview.barGlass,
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              glyph,
              // D77: something new behind this button (preview only).
              if (dot)
                const PositionedDirectional(
                  top: 0,
                  end: 1,
                  child: SizedBox.square(
                    dimension: KLivePreview.barDot,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: KLivePreview.dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              if (caption != null)
                PositionedDirectional(
                  bottom: 1,
                  child: Text(
                    caption,
                    textDirection: TextDirection.ltr,
                    style: context.textStyles.caption.copyWith(
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: white,
                      shadows: KLivePreview.textShadow,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return SizedBox(
      key: LivePreviewScreen.bottomBarKey,
      height: KLivePreview.barHeight,
      child: Row(
        children: [
          // D71 (owner's reference): the comment field first, then
          // D77 buttons after it (D75: no balance button).
          Expanded(
            child: Container(
              key: LivePreviewScreen.inputKey,
              height: KLivePreview.barHeight,
              padding: const EdgeInsetsDirectional.only(
                start: KSpacing.md,
                end: KSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: KLivePreview.barGlass,
                borderRadius: BorderRadius.circular(KLivePreview.barHeight / 2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.liveCommentHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.body.copyWith(
                        fontSize: 15,
                        color: white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: l10n.livePreviewEmoji,
                    excludeSemantics: true,
                    child: FeedGlyphIcon(
                      FeedGlyph.smiley,
                      size: 24,
                      color: white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // D77 (owner's reference): link (invite a guest), menu and the
          // gift box at the end, the menu and the gifts with a red dot;
          // share moved to the header's ⋯ (D78). The reference's sale and
          // bell art is another app's and is not reproduced.
          const SizedBox(width: KLivePreview.barGap),
          round(
            l10n.livePreviewGuests,
            AppIcon(
              AppIcons.link,
              size: KLivePreview.barIcon,
              color: white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: KLivePreview.barGap),
          if (onMenu != null) ...[
            round(
              l10n.livePreviewHostSettings,
              Icon(
                Icons.menu_rounded,
                size: KLivePreview.barIcon + 2,
                color: white.withValues(alpha: 0.9),
              ),
              dot: true,
              onTap: onMenu,
            ),
            const SizedBox(width: KLivePreview.barGap),
          ],
          round(
            l10n.liveGifts,
            const KabsoArtIcon(KabsoArt.giftBox, size: KLivePreview.barArt),
            dot: true,
          ),
        ],
      ),
    );
  }
}

/// One labelled test chat line ([joined] marks a join notice).
@immutable
class LivePreviewMessage {
  const new({
    required this.name,
    this.text = '',
    this.photo,
    this.levels = const {},
    this.joined = false,
  });

  final String name;
  final String text;

  /// A development headshot (`PreviewPhotos`); initials without one.
  final String? photo;

  /// D76: the sender's level in each system, shown as badges by the name
  /// (test values; there is no levels API in this branch).
  final Map<LevelCategory, int> levels;
  final bool joined;
}

/// A labelled test live room (never shown in production).
@immutable
class LivePreviewRoom {
  const new({
    required this.hostName,
    required this.hostLikes,
    required this.viewers,
    required this.hostUsername,
    required this.chat,
    this.galleryHave = 9,
    this.galleryTotal = 23,
  });

  final String hostName;
  final int hostLikes;
  final int viewers;

  /// The host's test account (D85: their place in the ranking list).
  final String hostUsername;
  final List<LivePreviewMessage> chat;
  final int galleryHave;
  final int galleryTotal;
}

/// Labelled test room: names say they are test accounts (D35/D46).
LivePreviewRoom livePreviewFixture({required bool ar}) => LivePreviewRoom(
  hostName: ar ? 'سارة (تجربة)' : 'Sara (test)',
  hostLikes: 36500,
  viewers: 284,
  hostUsername: 'test_host_sara',
  chat: [
    LivePreviewMessage(
      name: ar ? 'عمر (تجربة)' : 'Omar (test)',
      text: ar ? 'رسالة اختبار للدردشة' : 'A test chat message',
      photo: PreviewPhotos.omar,
      levels: const {
        LevelCategory.attractiveness: 12,
        LevelCategory.support: 37,
        LevelCategory.wizard: 8,
        LevelCategory.gaming: 21,
      },
    ),
    LivePreviewMessage(
      name: ar ? 'هند (تجربة)' : 'Hind (test)',
      text: ar
          ? 'أهلًا بالجميع، هذه بيانات اختبار :kabi_love:'
          : 'Hi all, this is test data :kabi_love:',
      photo: PreviewPhotos.huda,
      levels: const {
        LevelCategory.attractiveness: 64,
        LevelCategory.support: 5,
        LevelCategory.wizard: 100,
        LevelCategory.gaming: 3,
      },
    ),
    LivePreviewMessage(
      name: ar ? 'خالد (تجربة)' : 'Khalid (test)',
      photo: PreviewPhotos.karim,
      levels: const {
        LevelCategory.attractiveness: 2,
        LevelCategory.support: 15,
        LevelCategory.wizard: 1,
        LevelCategory.gaming: 46,
      },
      joined: true,
    ),
    LivePreviewMessage(
      name: ar ? 'نور (تجربة)' : 'Nour (test)',
      photo: PreviewPhotos.rania,
      levels: const {
        LevelCategory.attractiveness: 88,
        LevelCategory.support: 1,
        LevelCategory.wizard: 1,
        LevelCategory.gaming: 1,
      },
      joined: true,
    ),
  ],
);
