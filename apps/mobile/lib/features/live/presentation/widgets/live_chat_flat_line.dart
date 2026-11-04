import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D253 (owner: the host's screen «مثل التصميم ١٠٠٪», ref 2026-11-03,
/// 393 × 852 pt): the host's chat lines as the reference draws them — a
/// translucent black box hugging each line (D234's 44 %, 12 pt corners;
/// the second reference shows it over a bright picture), white bold text
/// with a shadow, one flowing line per message:
/// the role tag (the host's orange «المضيف»), the name (teal), the charm
/// badge, «:» and the text, wrapping under the start.
abstract final class KFlatChat {
  /// Ref: 14.5 pt lines of ≈ 13.5 pt bold text.
  static const double textSize = 13.5;
  static const double lineHeight = 1.07;

  /// Ref: the boxes 3 pt apart, the text 4 pt inside them.
  static const double gap = 3;
  static const EdgeInsetsDirectional padding = EdgeInsetsDirectional.fromSTEB(
    10,
    4,
    12,
    4,
  );
  static const Color box = Color(0x70000000);
  static const double radius = 12;

  /// The box around a line.
  static Widget boxed(
    Widget child, {
    Key? key,
    bool cp = false,
    BoxDecoration? vip,
  }) => KeyedSubtree(
    key: key,
    child: _box(child, cp: cp, vip: vip),
  );

  /// D258: a member's VIP bubble (CHAT_BUBBLE), unless a CP bubble is worn.
  static const vipBubbleKey = Key('liveChat.flat.vipBubble');

  static Widget _box(Widget child, {required bool cp, BoxDecoration? vip}) =>
      !cp && vip != null
      ? Container(
          key: vipBubbleKey,
          padding: padding,
          decoration: vip,
          child: child,
        )
      : Container(
          // The CP edge (1 pt) sits inside the padding: both lines keep one
          // height.
          padding: cp
              ? const EdgeInsetsDirectional.fromSTEB(9, 3, 11, 3)
              : padding,
          decoration: cp
              // D257: a worn CP bubble (CP-021) keeps its colours and edge.
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    colors: LiveCpChatBubble.colors,
                  ),
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: LiveCpChatBubble.edge),
                )
              : BoxDecoration(
                  color: box,
                  borderRadius: BorderRadius.circular(radius),
                ),
          child: child,
        );

  /// Ref: the name `#A4E8E0`.
  static const Color name = Color(0xFFA4E8E0);

  /// The separator after the name and badges (not a word: no translation).
  static const String colon = ':';

  /// D257: a name's widest (one line).
  static const double nameMaxWidth = 150;

  /// Ref: the host tag `#FC7800`, 15 pt tall, white bold text.
  static const Color hostTag = Color(0xFFFC7800);
  static const double tagHeight = 15;

  static const Color moderatorTag = Color(0xFFFFB13B);

  /// The text stays readable over a bright picture.
  static const List<Shadow> shadow = [
    Shadow(color: Color(0x99000000), blurRadius: 3),
    Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 1),
  ];

  static TextStyle style(BuildContext context) =>
      context.textStyles.body.copyWith(
        fontSize: textSize,
        height: lineHeight,
        color: const Color(0xFFFFFFFF),
        // D255 (owner: Bigo's semi-bold).
        fontWeight: FontWeight.w600,
        shadows: shadow,
      );
}

/// D253: one message of the host's flat chat.
class LiveChatFlatLine extends ConsumerWidget {
  const new({
    required this.name,
    required this.text,
    required this.label,
    super.key,
    this.vip,
    this.role,
    this.badges,
    this.agentCode,
    this.hostAgentCode,
    this.rechargeBadge,
    this.cp = false,
    this.failed,
    this.onProfile,
    this.onActions,
  });

  final String name;
  final String text;
  final String label;
  final LiveChatRole? role;

  /// D257: the author's badges, as the other chat rows draw them (charm,
  /// support, family, «جديد»; the agent and recharge badges), after the
  /// name — the role tag is this line's own orange pill.
  final LiveChatAuthorBadges? badges;
  final String? agentCode;
  final String? hostAgentCode;
  final RechargeBadge? rechargeBadge;

  /// D257: the author's couple wears the Exclusive Chat Bubble.
  final bool cp;

  /// D258: the author's VIP (the badge before the name, the name colour and
  /// the VIP bubble).
  final UserVip? vip;

  /// Why a pending line failed (under it).
  final String? failed;
  final VoidCallback? onProfile;
  final VoidCallback? onActions;

  static const tagKey = Key('liveChat.flat.tag');
  static const nameKey = Key('liveChat.flat.name');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final base = KFlatChat.style(context);
    final look = ref.watch(vipLookProvider(vip));
    final tag = switch (role) {
      LiveChatRole.host => l10n.liveChatHostBadge,
      LiveChatRole.moderator => l10n.liveChatModeratorBadge,
      _ => null,
    };
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final badgeRow = LiveChatBadgeRow(
      role: null,
      badges: badges,
      agentCode: agentCode,
      hostAgentCode: hostAgentCode,
      rechargeBadge: rechargeBadge,
      height: KFlatChat.tagHeight,
      fadeOverflow: true,
    );
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onActions,
        onLongPress: onActions,
        child: KFlatChat.boxed(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: base,
                  children: [
                    // D257: the heart (CP), the role tag, the name and the
                    // badges in one row in the reading direction (inline
                    // placeholders alone would be ordered as neutrals).
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cp) ...[
                            Image.asset(
                              LiveCpChatBubble.heart,
                              key: LiveRoomChatLines.cpHeartKey,
                              width: 12,
                              height: 12,
                              excludeFromSemantics: true,
                            ),
                            const SizedBox(width: 3),
                          ],
                          if (tag != null) ...[
                            Container(
                              key: tagKey,
                              height: KFlatChat.tagHeight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: role == LiveChatRole.host
                                    ? KFlatChat.hostTag
                                    : KFlatChat.moderatorTag,
                                borderRadius: BorderRadius.circular(
                                  KRadius.pill,
                                ),
                              ),
                              child: Center(
                                widthFactor: 1,
                                child: Text(
                                  tag,
                                  textScaler: TextScaler.noScaling,
                                  style: base.copyWith(
                                    fontSize: 9.5,
                                    height: 1.1,
                                    fontWeight: FontWeight.w800,
                                    shadows: const [],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (look != null) ...[
                            VipNameBadge(vip: vip, height: KFlatChat.tagHeight),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: GestureDetector(
                              key: nameKey,
                              onTap: onProfile,
                              // D257: one line at most (ends with «…»).
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: KFlatChat.nameMaxWidth,
                                ),
                                child: Text(
                                  // A mixed-direction name keeps its order.
                                  KFormat.bidiIsolate(name),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textScaler: scaler,
                                  // D258: the VIP name colour.
                                  style: base.copyWith(
                                    color: look?.nameColor ?? KFlatChat.name,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (badgeRow.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            // Many badges fade out at the end (D230).
                            Flexible(child: badgeRow),
                          ],
                          Text(
                            KFlatChat.colon,
                            textScaler: scaler,
                            style: base,
                          ),
                        ],
                      ),
                    ),
                    const TextSpan(text: ' '),
                    // Kabi emoji tokens (D66) show as the emoji, inline.
                    ...kabiIsolatedSpans(
                      text,
                      size: KFlatChat.textSize * KKabiEmoji.inlineScale,
                    ),
                  ],
                ),
                textScaler: scaler,
              ),
              if (failed case final why?)
                Text(
                  why,
                  textScaler: scaler,
                  style: base.copyWith(
                    fontSize: 11,
                    color: const Color(0xFFFF8A9A),
                  ),
                ),
            ],
          ),
          key: cp ? LiveCpChatBubble.bubbleKey : LiveChatInlineRow.rowKey,
          cp: cp,
          vip: vipBubbleDecoration(look, radius: KFlatChat.radius),
        ),
      ),
    );
  }
}

/// D253: the rules line of the flat chat — white bold text in the same
/// box, no shield (ref).
class LiveChatFlatNotice extends StatelessWidget {
  const new({required this.text, required this.label, super.key});

  final String text;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label. $text',
    excludeSemantics: true,
    child: KFlatChat.boxed(
      Text(
        text,
        textScaler: MediaQuery.textScalerOf(context)
            .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
        style: KFlatChat.style(context),
      ),
    ),
  );
}
