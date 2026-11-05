// D279b (owner: «في بث الان هكذا ظاهرة بشكل كبير ومزعجة، ضعها في الجهة
// الاخرى المقابلة للإطار ايقونة صغيرة»): the profile's «في بث الآن» is a
// small red «مباشر» pill on the cover, at the bottom-end corner opposite the
// photo, in place of D279's card under the cover. The facts still come from
// `PublicProfile.live` (v1.70-live, CONVENTIONS §10.5.1).

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D279b: the camera (or, a voice room, the microphone) mark, «مباشر» and
/// the viewers now, in a 28 dp Kabso-red pill. A tap opens the room through
/// the photo's live-ring route (your own room on your own profile). Its
/// dot pulses a few times when it appears (still with reduced motion). The
/// screen reader hears the whole fact: «في بث الآن، مباشر منذ 1س 17د، 93
/// مشاهدًا · 41.9K نقطة».
class ProfileLivePill extends StatefulWidget {
  const new({required this.live, required this.self, super.key});

  final ProfileLive live;

  /// The own profile («أنت في بث الآن»).
  final bool self;

  static const pillKey = Key('profile.live.pill');
  static const viewersKey = Key('profile.live.viewers');
  static const dotKey = Key('profile.live.dot');

  /// The pill's height at text scale 1.
  static const double height = 28;

  /// The larger text scale the pill follows (it is a mark on the picture;
  /// the screen reader carries the facts).
  static const double maxTextScale = 1.3;

  @override
  State<ProfileLivePill> createState() => _ProfileLivePillState();
}

class _ProfileLivePillState extends State<ProfileLivePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  /// The pulses when the pill appears (a few; never forever).
  static const _pulses = 3;
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 0;
    } else if (!_started) {
      _started = true;
      unawaited(_run());
    }
  }

  Future<void> _run() async {
    for (var i = 0; i < _pulses && mounted; i++) {
      try {
        await _pulse.forward(from: 0).orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (mounted) _pulse.value = 0;
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final live = widget.live;
    final fg = context.palette.onPrimary;
    final duration = l10n.profileLiveFor(
      KFormat.hoursMinutes(clock.now().difference(live.startedAt), l10n),
    );
    final details = [
      l10n.liveViewers(
        live.viewerCount,
        KFormat.compactLatin(live.viewerCount),
      ),
      if (live.score > 0)
        l10n.liveScore(live.score, KFormat.compactLatin(live.score)),
    ].join(' · ');
    final heading = widget.self
        ? l10n.profileLiveNowSelfTitle
        : l10n.profileLiveNowTitle;
    final media = MediaQuery.of(context);
    final style = t.caption.copyWith(
      color: fg,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );
    final pill = Container(
      key: ProfileLivePill.pillKey,
      constraints: const BoxConstraints(minHeight: ProfileLivePill.height),
      padding: const EdgeInsetsDirectional.fromSTEB(
        KSpacing.sm,
        KSpacing.xxs,
        KSpacing.sm + KSpacing.xxs,
        KSpacing.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [KBrandColors.red400, KBrandColors.red600],
        ),
        border: Border.all(color: fg.withValues(alpha: 0.85), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(pulse: _pulse),
          const SizedBox(width: KSpacing.xs + KSpacing.xxs),
          AppIcon(
            live.mode.isVoice ? AppIcons.mic : AppIcons.liveTv,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: KSpacing.xs),
          Text(l10n.liveBadge, maxLines: 1, style: style),
          Container(
            width: 1,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: KSpacing.xs + 2),
            color: fg.withValues(alpha: 0.5),
          ),
          AppIcon(AppIcons.viewers, size: 12, color: fg),
          const SizedBox(width: KSpacing.xxs),
          Text(
            KFormat.compactLatin(live.viewerCount),
            key: ProfileLivePill.viewersKey,
            maxLines: 1,
            textDirection: TextDirection.ltr,
            style: style,
          ),
        ],
      ),
    );
    return Semantics(
      button: true,
      label: l10n.profileLiveCardSemantics(heading, duration, details),
      excludeSemantics: true,
      onTap: _open,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        // A 48 dp tall touch area around the small pill.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                maxScaleFactor: ProfileLivePill.maxTextScale,
              ),
            ),
            child: pill,
          ),
        ),
      ),
    );
  }

  void _open() => context.push(AppRoutes.liveRoom(widget.live.roomId));
}

/// The white live dot; it grows a soft halo while [pulse] runs.
class _Dot extends StatelessWidget {
  const new({required this.pulse});

  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: ProfileLivePill.dotKey,
    width: 8,
    height: 8,
    child: AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final v = pulse.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.palette.onPrimary,
            boxShadow: [
              if (v > 0)
                BoxShadow(
                  color: context.palette.onPrimary.withValues(
                    alpha: 0.6 * (1 - v),
                  ),
                  spreadRadius: 4 * v,
                ),
            ],
          ),
        );
      },
    ),
  );
}
