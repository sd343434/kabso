import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_role_tag.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_text.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_room_chat.dart';
import 'package:kabso_live/features/vip/application/vip_look.dart';
import 'package:kabso_live/features/vip/presentation/vip_svga.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:material_ui/material_ui.dart';

/// D253 (owner: the host's screen «مثل التصميم ١٠٠٪», ref 2026-11-03,
/// 393 × 852 pt): the host's chat lines as the reference draws them — a
/// translucent black box hugging each line (D234's 44 %, 12 pt corners;
/// the second reference shows it over a bright picture), white bold text
/// with a shadow, one flowing line per message:
/// the role tag (D269: the host's red «المضيف», before the name), the name
/// (teal), the charm badge, «:» and the text, wrapping under the start.
abstract final class KFlatChat {
  /// Ref: 14.5 pt lines of bold text. D269 (owner): the text size is the
  /// one chat size of every live, [KChat.textSize].
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
    Widget? vipArt,
  }) => KeyedSubtree(
    key: key,
    child: _box(child, cp: cp, vip: vip, vipArt: vipArt),
  );

  /// D258: a member's VIP bubble (CHAT_BUBBLE), unless a CP bubble is worn.
  static const vipBubbleKey = Key('liveChat.flat.vipBubble');

  static Widget _box(
    Widget child, {
    required bool cp,
    BoxDecoration? vip,
    Widget? vipArt,
  }) => !cp && vip != null
      ? ConstrainedBox(
          key: vipBubbleKey,
          // D265: never narrower than the owner's bubble art's fixed parts.
          constraints: BoxConstraints(
            minWidth: vipArt == null ? 0 : VipSvgaNine.bubble.minWidth,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The opaque bubble under the text (and under the owner's
              // animated bubble, whose ornaments overflow the line). D265:
              // under the art, only its fill, inside the art's edge (no
              // edge of ours beside the owner's).
              Positioned.fill(
                child: vipArt == null
                    ? DecoratedBox(decoration: vip)
                    : Padding(
                        // Inside the art's edge (its inner corners ≈ 3 pt).
                        padding: const EdgeInsets.all(3),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: vip.gradient,
                            image: vip.image,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
              ),
              if (vipArt != null)
                Positioned.fill(child: IgnorePointer(child: vipArt)),
              Padding(padding: LiveChatFlatLine.vipPadding, child: child),
            ],
          ),
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

  /// The role tag's height (D269: a [LiveChatRoleTag] before the name —
  /// host red, moderator orange, Kabso Team blue; 16 pt at the 14.5 text).
  static const double tagHeight = 16;

  /// The text stays readable over a bright picture.
  static const List<Shadow> shadow = [
    Shadow(color: Color(0x99000000), blurRadius: 3),
    Shadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 1),
  ];

  static TextStyle style(BuildContext context) =>
      context.textStyles.body.copyWith(
        fontSize: KChat.textSize,
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
    this.textSize = KChat.textSize,
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

  /// The message's size: the host's flat chat [KChat.textSize]; D265:
  /// a VIP line in another chat keeps that chat's message size.
  final double textSize;

  /// D265: whether [vip]'s line takes the VIP layout (D269: the name, the
  /// VIP badge, the tags and the levels on line 1; up to 5 medals on line 2;
  /// the message alone in the VIP bubble) — in every chat, not only the host's
  /// flat one: the member holds the CHAT_BUBBLE perk and no CP bubble is
  /// worn.
  static bool takesVipBubble(WidgetRef ref, UserVip? vip, {bool cp = false}) =>
      !cp &&
      vip != null &&
      vipBubbleDecoration(
            ref.watch(vipLookProvider(vip)),
            radius: KFlatChat.radius,
          ) !=
          null;

  /// Why a pending line failed (under it).
  final String? failed;
  final VoidCallback? onProfile;
  final VoidCallback? onActions;

  static const tagKey = Key('liveChat.flat.tag');
  static const nameKey = Key('liveChat.flat.name');

  /// D258 (owner's ref 18 and revisions), D269 (owner: «اجعل الميداليات
  /// حدها ٥ وفي اسطر اسفل الاسم وثم سطر اسفله لتكست»): line 1 — the name,
  /// the VIP badge after it (D268), the tags and the levels, every emblem
  /// the name's line height (1.6 × the name = [LiveChatInlineRow.badgeHeight]);
  /// line 2 — up to 5 medals (none: no line); line 3 — the message alone in
  /// the VIP bubble, hugging one text line.
  /// The VIP badge's and the medals' height: what the level emblems show
  /// (≈ 22 of their 24 pt box; measured).
  /// D269: 21 (was 22), with the 1 pt smaller text (measured: within
  /// 1 pt of the 23 pt row's emblems).
  static const double vipEmblemHeight = 21;

  /// The room above the VIP bubble: its ornaments rise ≈ 8 pt above it
  /// (the owner's template at one text line), plus a clear 4 pt gap from
  /// line 1.
  static const double vipBubbleGap = 12;
  static const EdgeInsetsDirectional vipPadding =
      EdgeInsetsDirectional.fromSTEB(12, 7, 14, 7);

  /// D258: the name and badges above a VIP bubble.
  static const vipHeaderKey = Key('liveChat.flat.vipHeader');

  /// D258 (owner, ref 18): a VIP-bubble message's first line, as the
  /// three-line chat row (D234b). D268: the name, the VIP badge right after
  /// it, then the tags and levels, all at the same height (D269: the medals
  /// on a line of their own under it).
  Widget _vipNameRow(TextScaler scaler, VipLook? look) {
    final levels = LiveChatBadgeRow(
      role: null,
      tagLed: true,
      badges: badges,
      agentCode: agentCode,
      hostAgentCode: hostAgentCode,
      rechargeBadge: rechargeBadge,
      // The emblems at the row's height (D234), hugging their width.
      fullEmblems: true,
      height: LiveChatInlineRow.badgeHeight,
      agentBadgeHeight: LiveChatInlineRow.badgeHeight,
    );
    // D268 (owner: «ايقونة vip دائماً تأتي بعد الاسم»): the name, then
    // the VIP badge, then the tags and levels (all one height); the name
    // keeps its least room, the levels give way (fade) first.
    final roleTag = LiveChatTagKind.ofLine(role, badges);
    return LiveChatNameRow(
      // D269 (owner): the role tag before the name.
      lead: roleTag == null
          ? null
          : LiveChatRoleTag(
              key: LiveChatBadgeRow.roleKey,
              kind: roleTag,
              height: LiveChatBadgeRow.pillHeight(
                LiveChatInlineRow.badgeHeight,
              ),
            ),
      nameBadge: VipNameBadge(vip: vip, height: vipEmblemHeight),
      name: GestureDetector(
        key: nameKey,
        behavior: HitTestBehavior.opaque,
        onTap: onProfile,
        child: Builder(
          builder: (context) => VipNameShimmer(
            vip: vip,
            child: Text(
              KFormat.bidiIsolate(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: scaler,
              style: KFlatChat.style(context).copyWith(
                fontSize: KChat.nameSize,
                // Owner: the special colour at the chat's weight.
                fontWeight: FontWeight.w600,
                shadows: const [],
                color: look?.nameColor ?? LiveChatInlineRow.nameColor,
              ),
            ),
          ),
        ),
      ),
      // A long line fades at its end instead of wrapping.
      badges: levels.isNotEmpty ? LiveChatFadeOverflow(child: levels) : null,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = KFlatChat.style(context).copyWith(fontSize: textSize);
    final look = ref.watch(vipLookProvider(vip));
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final badgeRow = LiveChatBadgeRow(
      role: null,
      tagLed: true,
      badges: badges,
      agentCode: agentCode,
      hostAgentCode: hostAgentCode,
      rechargeBadge: rechargeBadge,
      height: KFlatChat.tagHeight,
      fadeOverflow: true,
    );
    final bubble = cp
        ? null
        : vipBubbleDecoration(look, radius: KFlatChat.radius);
    final vipBubble = bubble != null;
    final special = vipBubble ? VipNameShimmer.colorOf(ref, vip) : null;
    final Widget header = Row(
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
        // D269 (owner): the role tag (host red, moderator orange) before the
        // name.
        if (LiveChatTagKind.ofLine(role, badges) case final kind?) ...[
          LiveChatRoleTag(key: tagKey, kind: kind, height: KFlatChat.tagHeight),
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
                // D258: the VIP name colour. D269: the name 0.5 pt under
                // the message (12 / 12.5 in the host's chat).
                style: base.copyWith(
                  fontSize: textSize - 0.5,
                  color: look?.nameColor ?? KFlatChat.name,
                ),
              ),
            ),
          ),
        ),
        // D268 (owner): the VIP badge right after the name, never before.
        if (vip.isMember) ...[
          const SizedBox(width: 4),
          VipNameBadge(vip: vip, height: KFlatChat.tagHeight),
        ],
        if (badgeRow.isNotEmpty) ...[
          const SizedBox(width: 4),
          // Many badges fade out at the end (D230).
          Flexible(child: badgeRow),
        ],
        if (!vipBubble) Text(KFlatChat.colon, textScaler: scaler, style: base),
      ],
    );
    final line = KFlatChat.boxed(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // D258: the message in the VIP's special colour (owner).
          Text.rich(
            TextSpan(
              style: vipBubble && special != null
                  ? base.copyWith(color: special)
                  : base,
              children: [
                // D257: the heart (CP), the role tag, the name and the
                // badges in one row in the reading direction (inline
                // placeholders alone would be ordered as neutrals).
                // D258: with the VIP bubble the name and badges sit
                // above it; the bubble holds only the message.
                if (!vipBubble) ...[
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: header,
                  ),
                  const TextSpan(text: ' '),
                ],
                // Kabi emoji tokens (D66) show as the emoji, inline.
                ...kabiIsolatedSpans(
                  text,
                  size: textSize * KKabiEmoji.inlineScale,
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
      vip: bubble,
      vipArt: vipBubble ? vipBubbleArt(look) : null,
    );
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onActions,
        onLongPress: onActions,
        child: vipBubble
            // D258 (owner): the name and badges on their own line at the
            // reading start, the bubble under them with only the message.
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. The name, the VIP badge, the tags and the levels.
                  Padding(
                    key: vipHeaderKey,
                    padding: const EdgeInsetsDirectional.only(start: 4),
                    child: _vipNameRow(scaler, look),
                  ),
                  // 2. D269: up to 5 medals on their own line (none: none).
                  if (badges?.medals case final medals?
                      when medals.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4),
                      child: LiveChatMedalRow(medals: medals),
                    ),
                  ],
                  // 3. The message, alone in the VIP bubble (its ornaments
                  // never touch the medals).
                  SizedBox(
                    height: vipBubbleArt(look) == null ? 4 : vipBubbleGap,
                  ),
                  line,
                ],
              )
            : line,
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
