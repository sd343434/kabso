import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/application/live_quips.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D154: the emoji of a quip by its `assetKey` (`quips/<sound>` for the
/// free sounds, `quips/<group>` for the Kabi lines) — Unicode emoji, the
/// owner's sounds have no picture of their own.
String quipEmoji(String assetKey) => switch (assetKey) {
  'quips/clap' => '👏',
  'quips/laugh' => '😂',
  'quips/welcome' => '👋',
  'quips/wow' => '😮',
  'quips/tada' => '🥁',
  'quips/ya_salam' => '❤️',
  'quips/bell' => '🔔',
  'quips/sad' => '😢',
  'quips/ghazal' => '😍',
  'quips/funny' => '🤣',
  'quips/tease' => '😏',
  _ => '🎙️',
};

/// The quip art key of a sound when the catalogue is not loaded yet:
/// `room/clap` → `quips/clap`, `kabi/ghazal_01` → `quips/ghazal`.
String quipAssetOf(String soundKey) {
  final name = soundKey.split('/').last;
  return soundKey.startsWith('kabi/')
      ? 'quips/${name.split('_').first}'
      : 'quips/$name';
}

/// D216: Kabso's own art for a quip by its `assetKey` — the owner's Kabi
/// (and Kiki's clap) Lottie emojis, crisp at any size; [quipEmoji] stays the
/// text form (screen readers, chat).
KabsoEmoji quipArt(String assetKey) => switch (assetKey) {
  'quips/clap' => KabsoEmoji.byKey('kiki_clap')!,
  'quips/laugh' => KabsoEmoji.kabi('lol'),
  'quips/welcome' => KabsoEmoji.kabi('hi'),
  'quips/wow' => KabsoEmoji.kabi('wow'),
  'quips/tada' => KabsoEmoji.kabi('party'),
  'quips/ya_salam' => KabsoEmoji.kabi('love'),
  'quips/bell' => KabsoEmoji.kabi('star'),
  'quips/sad' => KabsoEmoji.kabi('sad'),
  'quips/ghazal' => KabsoEmoji.kabi('kiss'),
  'quips/funny' => KabsoEmoji.kabi('silly'),
  'quips/tease' => KabsoEmoji.kabi('wink'),
  _ => KabsoEmoji.kabi('sing'),
};

/// A quip's art (D216: its Kabi emoji) in a soft round badge with a warm
/// glow. [play] loops the art (off: its first frame).
class LiveQuipBadge extends StatelessWidget {
  const new({
    required this.assetKey,
    super.key,
    this.size = 40,
    this.play = false,
  });

  final String assetKey;
  final double size;
  final bool play;

  /// Off in widget tests (the Lottie loops forever;
  /// `test/flutter_test_config.dart`).
  static bool animate = true;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [Color(0x40FF3B47), Color(0x14FFFFFF)]),
      border: Border.fromBorderSide(BorderSide(color: Color(0x1FFFFFFF))),
    ),
    // The Lottie canvas has a wide margin around the character.
    child: OverflowBox(
      maxWidth: size * 1.3,
      maxHeight: size * 1.3,
      child: KabiEmoji(
        quipArt(assetKey),
        size: size * 1.3,
        animate: play && animate,
      ),
    ),
  );
}

/// D154 («إفيهات», owner: «the line's text shows as a chat bubble while it
/// plays»): the quip playing in this live. D216 (owner: «اجعل عرضها بطريقة
/// احترافية لتكون اكثر بهجة»): a banner on the live glass with the quip's
/// Kabi art standing out of its start edge, the sender's picture and name,
/// the words, a speaker to mute quips on this phone and a thin brand line
/// running out with the quip's time. It pops in (a soft bounce, a red glow
/// and a few sparks round the art) and lifts away; the next quip in the
/// room's queue pops in as it leaves. With reduced motion it simply
/// appears and goes. Readable when muted or with Sound effects off (then the
/// speaker shows as off). Nothing when no quip plays. It sits under the
/// room's header, centred, at most [maxWidth] wide.
class LiveQuipBubble extends ConsumerWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const bubbleKey = Key('quip.bubble');
  static const muteKey = Key('quip.bubble.mute');
  static const double maxWidth = 340;

  /// Under the header rows and the lucky ticker.
  static const double top = 140;

  /// The Kabi art's size; it stands [artRise] above the banner.
  static const double art = 76;
  static const double artRise = 14;

  static const Duration enter = Duration(milliseconds: 620);
  static const Duration exit = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quip = ref.watch(liveQuipsProvider(roomId));
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : enter,
      reverseDuration: still ? Duration.zero : exit,
      // The leaving banner lifts away over the one popping in.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [...previous, ?current],
      ),
      transitionBuilder: _leave,
      child: quip == null
          ? const SizedBox.shrink()
          : _Bubble(key: ValueKey(quip.id), quip: quip),
    );
  }
}

Widget _leave(Widget child, Animation<double> animation) =>
    _Leave(animation: animation, child: child);

/// The way out: fades, shrinks a little and lifts. On the way in it does
/// nothing (the banner brings its own pop).
class _Leave extends StatelessWidget {
  const new({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final leaving =
          animation.status == AnimationStatus.reverse ||
          animation.status == AnimationStatus.dismissed;
      // One shape either way, so the banner keeps its state.
      final t = leaving ? Curves.easeIn.transform(animation.value) : 1.0;
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, -24 * (1 - t)),
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
        ),
      );
    },
  );
}

class _Bubble extends ConsumerStatefulWidget {
  const new({required this.quip, super.key});

  final LiveQuip quip;

  @override
  ConsumerState<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends ConsumerState<_Bubble>
    with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: LiveQuipBubble.enter,
  );
  late final AnimationController _time = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.quip.durationMs),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _in.value = 1;
    } else {
      _in.forward();
      _time.forward();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quip = widget.quip;
    final l10n = context.l10n;
    final text = context.textStyles;
    final gift = ref.watch(giftCatalogueProvider).value?.byCode(quip.giftCode);
    final muted = ref.watch(quipsMutedProvider);
    final soundOn = ref.watch(soundEffectsProvider) && !muted;
    final assetKey = gift?.assetKey ?? quipAssetOf(quip.soundKey);
    final words = quip.text;
    final name = KFormat.bidiIsolate(quip.sender.displayName);
    final still = MediaQuery.disableAnimationsOf(context);
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    // The banner: up in 0–45 % with a bounce; the art pops a beat later.
    final pop = CurvedAnimation(
      parent: _in,
      curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
    );
    final fade = CurvedAnimation(
      parent: _in,
      curve: const Interval(0, 0.25, curve: Curves.easeOut),
    );
    final artPop = CurvedAnimation(
      parent: _in,
      curve: const Interval(0.15, 1, curve: Curves.elasticOut),
    );
    const shape = BorderRadius.all(Radius.circular(KRadius.xl));
    final banner = Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsetsDirectional.fromSTEB(
        LiveQuipBubble.art + KSpacing.xs,
        KSpacing.sm + KSpacing.xxs,
        KSpacing.xxs,
        KSpacing.sm + KSpacing.xs,
      ),
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: const LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: [Color(0xF2380A10), Color(0xE61A1014), Color(0xE6121216)],
          stops: [0, 0.45, 1],
        ),
        border: Border.all(color: KBrandColors.red400.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ExcludeSemantics(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [KBrandColors.gold, KBrandColors.red500],
                          ),
                        ),
                        child: KAvatar(
                          name: quip.sender.displayName,
                          imageUrl: quip.sender.avatarUrl,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: KSpacing.xs + KSpacing.xxs),
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: scaler,
                          style: text.label.copyWith(
                            color: KBrandColors.gold,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KSpacing.xs),
                  Text(
                    words ?? gift?.name ?? quipArt(assetKey).label(l10n),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textScaler: scaler,
                    // The Kabi lines are Egyptian Arabic in every
                    // language.
                    textDirection: words == null ? null : TextDirection.rtl,
                    style: text.bodyStrong.copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontSize: 14.5,
                      height: 1.35,
                      shadows: KLiveColors.glassShadow,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: KSpacing.xxs),
          Semantics(
            button: true,
            toggled: !muted,
            label: muted ? l10n.liveQuipUnmute : l10n.liveQuipMute,
            excludeSemantics: true,
            child: GestureDetector(
              key: LiveQuipBubble.muteKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(quipsMutedProvider.notifier).toggle(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x1FFFFFFF),
                    ),
                    child: Icon(
                      soundOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      size: 16,
                      color: const Color(0xE6FFFFFF),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final body = Stack(
      clipBehavior: Clip.none,
      children: [
        // The glow under the banner, brightest as it lands.
        Positioned.fill(
          top: LiveQuipBubble.artRise,
          child: AnimatedBuilder(
            animation: _in,
            builder: (context, child) {
              final burst = still ? 0.0 : math.sin(_in.value * math.pi);
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: shape,
                  boxShadow: [
                    BoxShadow(
                      color: KBrandColors.red500.withValues(
                        alpha: 0.28 + 0.32 * burst,
                      ),
                      blurRadius: 18 + 14 * burst,
                      spreadRadius: burst * 2,
                    ),
                    const BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: LiveQuipBubble.artRise),
          child: ClipRRect(
            borderRadius: shape,
            child: Stack(
              children: [
                banner,
                // The quip's time running out, along the bottom edge.
                if (!still)
                  PositionedDirectional(
                    start: LiveQuipBubble.art,
                    end: KSpacing.lg,
                    bottom: 5,
                    child: _TimeLine(time: _time),
                  ),
              ],
            ),
          ),
        ),
        // Kabi stands out of the banner's start edge.
        PositionedDirectional(
          start: -KSpacing.xs,
          top: -KSpacing.xs,
          width: LiveQuipBubble.art + KSpacing.sm,
          height: LiveQuipBubble.art + KSpacing.sm,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (!still) Positioned.fill(child: _Sparks(progress: _in)),
              ScaleTransition(
                scale: artPop,
                child: KabiEmoji(
                  quipArt(assetKey),
                  size: LiveQuipBubble.art + KSpacing.sm,
                  animate: LiveQuipBadge.animate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: LiveQuipBubble.maxWidth),
      child: Semantics(
        key: LiveQuipBubble.bubbleKey,
        liveRegion: true,
        label: l10n.liveQuipBubbleSemantics(
          name,
          words ?? gift?.name ?? quipEmoji(assetKey),
        ),
        child: FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, -0.25),
              end: Offset.zero,
            ).animate(pop),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.72, end: 1).animate(pop),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin brand line that empties as the quip plays.
class _TimeLine extends StatelessWidget {
  const new({required this.time});

  final Animation<double> time;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 2,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(KRadius.pill),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0x1AFFFFFF)),
          AnimatedBuilder(
            animation: time,
            builder: (context, _) => FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1 - time.value,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [KBrandColors.gold, KBrandColors.red400],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A few sparks that fly out of the art as it pops in, then fade.
class _Sparks extends StatelessWidget {
  const new({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: CustomPaint(painter: _SparksPainter(progress)));
}

class _SparksPainter extends CustomPainter {
  new(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  static const List<Color> _colors = [
    KBrandColors.gold,
    KBrandColors.red400,
    Color(0xFFFFFFFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Out between 15 % and 85 % of the entrance.
    final t = ((progress.value - 0.15) / 0.7).clamp(0.0, 1.0);
    if (t <= 0 || t >= 1) return;
    final center = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(t);
    final fade = 1 - Curves.easeIn.transform(t);
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4 + 0.2;
      final distance =
          size.width * (0.32 + 0.38 * eased) * (i.isEven ? 1 : 0.8);
      final at = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: fade);
      final r = (i.isEven ? 3.0 : 2.2) * (1 - 0.4 * eased);
      // A four-point star.
      final path = Path()
        ..moveTo(at.dx, at.dy - r * 2)
        ..quadraticBezierTo(at.dx, at.dy, at.dx + r * 2, at.dy)
        ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + r * 2)
        ..quadraticBezierTo(at.dx, at.dy, at.dx - r * 2, at.dy)
        ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy - r * 2)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SparksPainter oldDelegate) => false;
}
