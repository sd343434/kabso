// D279 (owner): the profile's «في بث الآن» card, directly under the cover
// while the profile's owner is live (v1.70-live, CONVENTIONS §10.5.1). The
// layout follows the owner's reference (a section title, then one card:
// how long the person has been live, the viewers and the score, and a
// «انضم» button at the end); colours and type are Kabso's own.

import 'package:clock/clock.dart';
import 'package:go_router/go_router.dart';
import 'package:kabso_live/app/router/routes.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/icons/app_icons.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/profile/domain/profile_models.dart';
import 'package:kabso_live/features/profile/profile_screen.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D279: «في بث الآن» (own profile: «أنت في بث الآن») with how long the
/// person has been live («مباشر منذ 1س 17د»), the viewers now, the live's
/// score when it has one, the title (or «غرفة صوتية» for a voice room) and
/// «انضم» in Kabso red («عودة للبث» on your own profile). A tap on the card
/// or the button opens the room through the same route as the photo's live
/// ring. The time is read when the card is built (pull to refresh updates
/// it; a live that ended is gone on refresh).
class ProfileLiveCard extends StatelessWidget {
  const new({required this.live, required this.self, super.key});

  final ProfileLive live;

  /// The own profile («أنت في بث الآن», «عودة للبث»).
  final bool self;

  static const cardKey = Key('profile.live.card');
  static const joinKey = Key('profile.live.join');
  static const titleKey = Key('profile.live.title');
  static const durationKey = Key('profile.live.duration');
  static const detailsKey = Key('profile.live.details');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final dark = Theme.of(context).brightness == Brightness.dark;
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
    final subtitle = live.mode.isVoice
        ? [
            l10n.profileLiveVoice,
            if (live.title.isNotEmpty) KFormat.bidiIsolate(live.title),
          ].join(' · ')
        : live.title.isEmpty
        ? null
        : KFormat.bidiIsolate(live.title);
    final heading = self
        ? l10n.profileLiveNowSelfTitle
        : l10n.profileLiveNowTitle;
    void open() => context.push(AppRoutes.liveRoom(live.roomId));
    final radius = BorderRadius.circular(KRadius.md);
    final tint = KBrandColors.red500.withValues(alpha: dark ? 0.14 : 0.06);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        KProfile.inset,
        KSpacing.md,
        KProfile.inset,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            heading,
            key: titleKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.title.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: KSpacing.sm),
          Semantics(
            button: true,
            label: l10n.profileLiveCardSemantics(heading, duration, details),
            excludeSemantics: true,
            onTap: open,
            child: Material(
              color: p.surface,
              borderRadius: radius,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: tint,
                  border: Border.all(
                    color: KBrandColors.red500.withValues(alpha: 0.28),
                  ),
                ),
                child: InkWell(
                  key: cardKey,
                  borderRadius: radius,
                  onTap: open,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      KSpacing.md,
                      KSpacing.md,
                      KSpacing.md,
                      KSpacing.md,
                    ),
                    child: Row(
                      children: [
                        _LiveBadge(voice: live.mode.isVoice),
                        const SizedBox(width: KSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                duration,
                                key: durationKey,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodyStrong.copyWith(
                                  color: p.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                details,
                                key: detailsKey,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: t.caption.copyWith(
                                  color: p.textSecondary,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.caption.copyWith(
                                    color: p.textTertiary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: KSpacing.sm),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 132),
                          child: SizedBox(
                            height: KProfile.buttonHeight,
                            child: FilledButton.icon(
                              key: joinKey,
                              style: FilledButton.styleFrom(
                                backgroundColor: KBrandColors.red500,
                                foregroundColor: p.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: KSpacing.md,
                                ),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    KRadius.sm,
                                  ),
                                ),
                                textStyle: t.bodyStrong,
                              ),
                              onPressed: open,
                              icon: AppIcon(
                                AppIcons.play,
                                size: 14,
                                color: p.onPrimary,
                              ),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  self
                                      ? l10n.profileLiveReturn
                                      : l10n.profileLiveJoin,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

/// The red round mark at the card's start: a camera live or (voice rooms) a
/// microphone.
class _LiveBadge extends StatelessWidget {
  const new({required this.voice});

  final bool voice;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: KBrandColors.gradientLive,
      ),
    ),
    child: AppIcon(
      voice ? AppIcons.mic : AppIcons.liveTv,
      size: 20,
      color: context.palette.onPrimary,
    ),
  );
}
