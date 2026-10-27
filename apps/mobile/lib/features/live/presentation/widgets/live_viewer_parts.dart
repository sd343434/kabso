import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_rankings_sheet.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D131: the video live's pieces measured on the owner's references
/// 158–160 (393 pt wide).
abstract final class KViewerRoom {
  /// Ref 158 §4.9: the "Say Hi…" pill (210.3 × 34.9 pt) and the round
  /// buttons (34.8 pt, 42.1 pt apart), black ≈ 25 %.
  static const double pillWidth = 210.3;
  static const double barHeight = 34.9;
  static const double button = 34.8;
  static const double buttonGap = 7.2;
  static const Color fill = Color(0x40000000);

  /// The hint (cap 8.5 pt → 12.5 sp, white 85 %), 15.8 pt in.
  static const double hintSize = 12.5;
  static const double hintStart = 15.8;

  /// Ref 158 §4.3: the second row's chips (20.4 pt) 8.1 pt under the pill;
  /// the room number at the end (≈ 8 sp, white 65 %).
  static const double chipHeight = 20.4;
  static const double rowGap = 8.1;
}

/// The second row (ref 158 §4.3): at the reading start the board chip and
/// (D135) the level chip — the host's charm level badge and, when known
/// (the host's own screen), their charm points against the next level
/// ("3.51K/5K") over a gold progress fill; at the end the [elapsed] LIVE
/// timer (host) and the room ID. The charm level shows only here.
class KRoomChipsRow extends StatelessWidget {
  const new({
    super.key,
    this.level,
    this.roomNumber,
    this.points,
    this.target,
    this.elapsed,
  });

  final int? level;
  final int? roomNumber;

  /// D135: the host's charm points and the next level's requirement (null
  /// at the top level or when unknown, e.g. to viewers).
  final int? points;
  final int? target;

  /// D135: the host's LIVE timer, before the room ID.
  final Widget? elapsed;

  static const numberKey = Key('room.number');
  static const levelKey = Key('room.levelChip');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final level = this.level;
    final number = roomNumber;
    final elapsed = this.elapsed;
    // The header row's 48 pt target already leaves 8.5 pt under the 31 pt
    // pill (ref: 8.1 pt).
    return SizedBox(
      height: KViewerRoom.chipHeight + 2,
      child: Row(
        children: [
          // The start group keeps its natural width; only a narrow screen
          // shortens the board chip.
          Expanded(
            child: Row(
              children: [
                const Flexible(
                  child: LiveRankChip(icon: Icons.bar_chart_rounded),
                ),
                if (level != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: LiveLevelTargetChip(
                      key: levelKey,
                      level: level,
                      points: points,
                      target: target,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (elapsed != null) ...[
            const SizedBox(width: 6),
            elapsed,
            const SizedBox(width: 6),
          ],
          if (number != null)
            Text(
              l10n.liveRoomNumber(KFormat.bidiIsolate('$number')),
              key: numberKey,
              maxLines: 1,
              style: context.textStyles.caption.copyWith(
                fontSize: 9,
                color: const Color(0xA6FFFFFF),
                fontWeight: FontWeight.w600,
                shadows: const [
                  Shadow(color: Color(0x66000000), blurRadius: 2),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// D135 (ref 158 "★3 ◷ 3.51K/5K"): the charm level badge and, when known,
/// the points against the next level with a translucent gold fill behind
/// the part reached.
class LiveLevelTargetChip extends StatelessWidget {
  const new({required this.level, super.key, this.points, this.target});

  final int level;
  final int? points;
  final int? target;

  static const fill = Color(0x66F5B83D);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final points = this.points;
    final target = this.target;
    final progress = points == null || target == null || target <= 0
        ? null
        : (points / target).clamp(0.0, 1.0);
    final text = points == null
        ? null
        : target == null
        ? KFormat.compact(points, l10n)
        : '${KFormat.compact(points, l10n)}/${KFormat.compact(target, l10n)}';
    return Semantics(
      label: text == null
          ? l10n.liveRoomLevelBadge(level)
          : '${l10n.liveRoomLevelBadge(level)}, $text',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KViewerRoom.chipHeight / 2),
        child: Container(
          height: KViewerRoom.chipHeight,
          color: KLiveColors.glass,
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              if (progress != null)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: progress,
                    child: const ColoredBox(color: fill),
                  ),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 3, end: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // D135 (owner): the same size as in the chat rows.
                    CharmLevelBadge(
                      level: level,
                      height: CharmLevelBadge.lineHeight,
                    ),
                    if (text != null) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          text,
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.caption.copyWith(
                            fontSize: 10.5,
                            height: 1,
                            color: const Color(0xFFFFFFFF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The video live's bottom bar (ref 158 §4.9): the "Say Hi…" pill at the
/// reading start with the emoji button inside its end, then the round
/// buttons at the end ([actions], e.g. the gift box). There is no SALE or
/// quick-gift button: no shop, and the owner has not chosen a quick gift.
class KViewerBar extends StatelessWidget {
  const new({
    required this.hint,
    required this.onChat,
    super.key,
    this.onEmoji,
    this.actions = const [],
    this.pillKey = defaultPillKey,
  });

  final String hint;

  /// The pill's key (the room passes its chat key).
  final Key pillKey;
  final VoidCallback onChat;
  final VoidCallback? onEmoji;
  final List<Widget> actions;

  static const defaultPillKey = Key('viewerBar.pill');
  static const emojiKey = Key('viewerBar.emoji');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final pill = Semantics(
      button: true,
      label: hint,
      onTap: onChat,
      excludeSemantics: true,
      child: GestureDetector(
        key: pillKey,
        behavior: HitTestBehavior.opaque,
        onTap: onChat,
        child: Container(
          height: KViewerRoom.barHeight,
          padding: const EdgeInsetsDirectional.only(
            start: KViewerRoom.hintStart,
          ),
          decoration: BoxDecoration(
            color: KViewerRoom.fill,
            borderRadius: BorderRadius.circular(KRadius.pill),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: scaler,
                  style: context.textStyles.body.copyWith(
                    fontSize: KViewerRoom.hintSize,
                    color: const Color(0xD9FFFFFF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (onEmoji != null)
                Semantics(
                  button: true,
                  label: l10n.livePreviewEmoji,
                  excludeSemantics: true,
                  onTap: onEmoji,
                  child: GestureDetector(
                    key: emojiKey,
                    behavior: HitTestBehavior.opaque,
                    onTap: onEmoji,
                    child: SizedBox(
                      width: 38,
                      height: KViewerRoom.barHeight,
                      child: Center(
                        child: Image.asset(
                          'assets/live_bar/emoji.png',
                          width: 21,
                          height: 21,
                          excludeFromSemantics: true,
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
    return SizedBox(
      // The pill and the buttons keep 48 pt touch targets around them.
      height: KSizes.minTouchTarget,
      child: Row(
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: KViewerRoom.pillWidth,
              ),
              child: pill,
            ),
          ),
          const Spacer(),
          // The circles 42.1 pt apart: 48 pt targets overlap by 5.9.
          for (final (i, a) in actions.indexed) ...[
            if (i > 0) const SizedBox(width: KViewerRoom.buttonGap - 13.2),
            a,
          ],
        ],
      ),
    );
  }
}

/// A round bar button of the video live (ref 158: 34.8 pt, black ≈ 25 %,
/// the icon ≈ 20 pt) in a 48 pt target.
class KViewerBarButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onTap,
    super.key,
    this.asset,
    this.icon,
    this.badge = false,
    this.art = false,
  }) : assert(asset != null || icon != null, 'an asset or an icon');

  /// D135 (owner's colourful PK and gift art): [asset] fills the circle's
  /// place (33 pt) with no dark circle behind it.
  final bool art;

  /// The colourful art's size.
  static const double artSize = 33;

  /// Kabso's bar art; else [icon] in white.
  final String? asset;
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;

  /// A small dot (e.g. beauty on).
  final bool badge;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.square(
        // A 48 pt target around the 34.8 pt circle.
        dimension: KSizes.minTouchTarget,
        child: Center(
          child: Container(
            width: KViewerRoom.button,
            height: KViewerRoom.button,
            decoration: art
                ? null
                : const BoxDecoration(
                    color: KViewerRoom.fill,
                    shape: BoxShape.circle,
                  ),
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (asset case final asset?)
                  Image.asset(
                    asset,
                    width: art ? artSize : 21,
                    height: art ? artSize : 21,
                    excludeFromSemantics: true,
                  )
                else
                  Icon(icon, size: 21, color: const Color(0xFFFFFFFF)),
                if (badge)
                  const PositionedDirectional(
                    top: -6,
                    end: -6,
                    child: SizedBox.square(
                      dimension: 7,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFFFF3B6B),
                          shape: BoxShape.circle,
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
  );
}

/// What the leave prompt chose.
enum LiveLeaveChoice { followAndExit, exit }

/// D131 (owner, ref 160): leaving a live whose host the viewer can follow
/// and does not: a floating white card over a 50 % scrim — the host's
/// picture with a "Host" tag, the question, "Follow and exit" (cyan) and
/// "Exit live room". A tap outside or Back keeps watching (`null`).
Future<LiveLeaveChoice?> showLiveLeavePrompt(
  BuildContext context, {
  required String hostName,
  required ImageProvider? avatar,
}) => showGeneralDialog<LiveLeaveChoice>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  transitionDuration: KMotion.of(context, KMotion.base),
  pageBuilder: (dialog, _, _) =>
      KLeavePrompt(hostName: hostName, avatar: avatar),
  transitionBuilder: (_, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: KMotion.standard),
    child: child,
  ),
);

/// The card of [showLiveLeavePrompt] (ref 160, measured): 356.4 × 271.7
/// pt, 18.3 pt from the sides and the bottom, ≈ 18 pt corners, white with a
/// `#D4FDFF` tint fading out over its top 99 pt; the 72.9 pt picture 23.3
/// pt down; a 38.3 × 16.6 pt `#FF7801` "Host" tag over its lower edge; the
/// question (`#272A29`, 14.5 sp) 26 pt under it; two 43.9 pt buttons 22.1
/// pt in, 7.2 pt apart, 21.7 pt above the card's bottom.
class KLeavePrompt extends StatelessWidget {
  const new({required this.hostName, required this.avatar, super.key});

  final String hostName;
  final ImageProvider? avatar;

  static const scrim = Color(0x80000000);
  static const tint = Color(0xFFD4FDFF);
  static const ink = Color(0xFF272A29);
  static const buttonInk = Color(0xFF252728);
  static const hostTag = Color(0xFFFF7801);
  static const gradient = [Color(0xFF2EE7D6), Color(0xFF03D4E6)];
  static const cardKey = Key('leavePrompt.card');
  static const followKey = Key('leavePrompt.follow');
  static const exitKey = Key('leavePrompt.exit');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    Widget button({
      required Key key,
      required String label,
      required LiveLeaveChoice choice,
      required bool primary,
    }) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => Navigator.of(context).pop(choice),
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(choice),
        child: Container(
          constraints: const BoxConstraints(minHeight: 43.9),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(colors: KLeavePrompt.gradient)
                : null,
            color: primary ? null : const Color(0xFFFFFFFF),
            border: primary
                ? null
                : Border.all(color: const Color(0xFFE9E9E9), width: 0.8),
            borderRadius: BorderRadius.circular(KRadius.pill),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: t.bodyStrong.copyWith(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: primary ? const Color(0xFFFFFFFF) : KLeavePrompt.buttonInk,
            ),
          ),
        ),
      ),
    );
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18.3,
            KSpacing.lg,
            18.3,
            bottom > 18.5 ? bottom - 15 : 18.5,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              key: cardKey,
              type: MaterialType.transparency,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.36],
                    colors: [KLeavePrompt.tint, Color(0xFFFFFFFF)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(22.1, 23.3, 22.1, 21.7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: KAvatar(
                            name: hostName,
                            image: avatar,
                            size: 72.9,
                          ),
                        ),
                        Container(
                          height: 16.6,
                          constraints: const BoxConstraints(minWidth: 38.3),
                          padding: const EdgeInsets.fromLTRB(7, 1.5, 7, 0),
                          decoration: BoxDecoration(
                            color: KLeavePrompt.hostTag,
                            borderRadius: BorderRadius.circular(KRadius.pill),
                            border: Border.all(
                              color: const Color(0xFFFFFFFF),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            l10n.liveChatHostBadge,
                            textScaler: TextScaler.noScaling,
                            style: t.caption.copyWith(
                              fontSize: 10.5,
                              height: 1.1,
                              color: const Color(0xFFFFFFFF),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      l10n.liveLeaveTitle,
                      textAlign: TextAlign.center,
                      style: t.body.copyWith(
                        fontSize: 14.5,
                        color: KLeavePrompt.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 21.9),
                    button(
                      key: followKey,
                      label: l10n.liveLeaveFollow,
                      choice: LiveLeaveChoice.followAndExit,
                      primary: true,
                    ),
                    const SizedBox(height: 7.2),
                    button(
                      key: exitKey,
                      label: l10n.liveLeaveExit,
                      choice: LiveLeaveChoice.exit,
                      primary: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// D131 (owner, ref 158 §4.7): quick replies over the bar — Kabso's own
/// short phrases, each sent as an ordinary text message (the chat's rate
/// limit applies). 20.9 pt glass chips 7.5 pt apart, white bold 12.5 sp.
/// Shown only to someone who may write.
class KQuickReplies extends StatelessWidget {
  const new({required this.onSend, super.key, this.host = false});

  final ValueChanged<String> onSend;

  /// D135: the host's own phrases (a welcome, thanks …) on their live.
  final bool host;

  static Key chipKey(int i) => Key('quickReply.$i');
  static const double height = 20.9;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final phrases = host
        ? [
            l10n.liveQuickHostWelcome,
            l10n.liveQuickHostThanks,
            l10n.liveQuickHostFollow,
            l10n.liveQuickHostShare,
          ]
        : [
            l10n.liveQuickHello,
            l10n.liveQuickFire,
            l10n.liveQuickNiceMood,
            l10n.liveQuickGotMe,
          ];
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    return SizedBox(
      height: KSizes.minTouchTarget - 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: phrases.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7.5),
        itemBuilder: (context, i) => Semantics(
          button: true,
          label: l10n.liveQuickReplyLabel(phrases[i]),
          excludeSemantics: true,
          onTap: () => onSend(phrases[i]),
          child: GestureDetector(
            key: chipKey(i),
            behavior: HitTestBehavior.opaque,
            onTap: () => onSend(phrases[i]),
            child: Center(
              // D135: the chip hugs its text (20.9 pt), not the 40 pt row.
              child: Container(
                constraints: const BoxConstraints(minHeight: height),
                padding: const EdgeInsets.symmetric(
                  horizontal: 9.5,
                  vertical: 3,
                ),
                // D135 (owner: "make their frame transparent"): the live
                // glass with a white hairline, white text with a shadow.
                decoration: BoxDecoration(
                  color: KLiveColors.glass,
                  borderRadius: BorderRadius.circular(KRadius.pill),
                  border: Border.all(
                    color: const Color(0x40FFFFFF),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  phrases[i],
                  textScaler: scaler,
                  style: context.textStyles.label.copyWith(
                    fontSize: 12.5,
                    height: 1.2,
                    color: const Color(0xFFFFFFFF),
                    fontWeight: FontWeight.w700,
                    shadows: KLiveColors.glassShadow,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
