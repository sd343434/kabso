import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/format/k_handle.dart';
import 'package:kabso_live/core/models/premium_tier.dart';
import 'package:kabso_live/core/models/shared_models.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/levels/domain/level_models.dart';
import 'package:kabso_live/features/levels/presentation/level_badge.dart';
import 'package:kabso_live/features/live/application/live_chat_controller.dart';
import 'package:kabso_live/features/live/domain/live_chat.dart';
import 'package:kabso_live/features/live/presentation/go_live/live_audio_room.dart';
import 'package:kabso_live/features/live/presentation/widgets/charm_level_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_flat_line.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_gift_line.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_chat_media.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_public_message.dart';
import 'package:kabso_live/features/medals/presentation/medal_icon.dart';
import 'package:kabso_live/features/posts/presentation/report_sheet.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_badge.dart';
import 'package:kabso_live/features/recharge/presentation/recharge_perks.dart';
import 'package:kabso_live/features/vip/presentation/vip_wear.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// The caller's role in the room, for what a chat line offers.
enum LiveChatViewerRole { host, moderator, member, guest }

/// The room chat (CP-013): the newest lines at the bottom of a bounded box
/// at the start side. Tapping a message opens its actions; a line that
/// failed to send offers a retry.
class LiveRoomChatLines extends ConsumerWidget {
  const new({
    required this.roomId,
    required this.role,
    required this.onProfile,
    super.key,
    this.bubble = KAudioRoom.bubble,
    this.inline = false,
    this.video = false,
    this.brightNotice = false,
    this.compact = false,
    this.flat = false,
  });

  /// D253 (owner, the host's screen «مثل التصميم ١٠٠٪»): the messages and the
  /// rules line as plain flowing text ([LiveChatFlatLine]) — no box, the
  /// host's tag orange, the names teal. Joins and gifts keep their rows.
  final bool flat;

  /// D212: the podcast's lower chat box (the mockup's four lines under the
  /// listeners): at most [compactShare] of the screen, so the stage above
  /// it keeps the listeners row whole.
  final bool compact;
  static const double compactShare = 0.22;

  /// D135: the room's theme is bright (the rules line's fill is a little
  /// darker).
  final bool brightNotice;

  final String roomId;
  final LiveChatViewerRole role;

  /// D131 (owner, ref 158): the video live's rows — one see-through pill
  /// per message with the badges and the name inline before the text
  /// ([LiveChatInlineRow]), joins as rows. Off: D119's boxes with the
  /// picture (the audio room) and the pinned join strip.
  final bool inline;

  /// Opens a user's profile card.
  final void Function(String username) onProfile;

  /// The bubble colour (the audio room's purple, or the video scrim) of
  /// the join, gift and quip lines. D224: never a message's — a message is
  /// plain text on no background ([plain]) unless its author wears a
  /// bubble (the CP Exclusive Chat Bubble).
  final Color bubble;

  /// D224 (owner: «اطار التكست للاشخاص بدون ان يكون يرتدي فقاعة دردشة عادي
  /// بدون اي شيء خلفية بشفافية كما كان قبل»): a message line's background
  /// in every live category (video, audio, podcast, multi) — none.
  static const plain = Color(0x00000000);

  /// D234 (owner: «أسود شفاف»; supersedes D224's [plain] for messages): a
  /// message of someone who wears no chat bubble sits on translucent black
  /// (44 %) in 12–14 pt rounded corners, no border, in every category; a
  /// worn bubble (CP) draws instead. The white text keeps the live glass's
  /// shadow on it, so it still reads over a white frame.
  static const messageBox = Color(0x70000000);

  /// The video live's chat (solo and multi, host and viewer): D199's
  /// rule that the rules line steps aside while typing, and D230's taller
  /// area for the three-line rows. D230 (owner's device): the lines sit at
  /// the bottom of the area in every room (D199's top start is gone).
  final bool video;

  /// D230: the video live's chat area — at most this share of the screen
  /// and [videoMaxHeight] pt.
  static const double videoShare = 0.4;
  static const double videoMaxHeight = 340;

  static const listKey = Key('liveChat.lines');

  static Key lineKey(String key) => Key('liveChat.line.$key');

  /// D118: the room's rules line.
  static const noticeKey = Key('liveChat.notice');

  /// D265: a VIP member's line (the VIP layout) in the audio room or the
  /// video live.
  static const vipLineKey = Key('liveChat.vipLine');

  /// CP-021: the heart at the start of a CP bubble line.
  static const cpHeartKey = Key('liveChat.cpHeart');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(liveChatProvider(roomId));
    // D135 (owner, final): the rules line is simply the first line of
    // this visit — it shows at the bottom on entering and rises with the
    // messages. No "no messages yet" line.
    // D236 (owner: the rules line behaves like any chat message; supersedes
    // D212/D230's «gone once a message is written» and D199's «steps aside
    // while typing»): it stays in the bottom-anchored list where it was
    // put and scrolls up and away as new lines arrive — never pinned,
    // never removed by a new message or the keyboard.
    final items = chat.items;
    // D119: taller lines (picture, name, badges, bubble), so a little more
    // room than the 240 pt of one-line bubbles: about three messages.
    // D230: the video live's rows are three lines tall now (name, badges,
    // message): a little more room there.
    final maxHeight = math
        .min(
          video ? videoMaxHeight : 300,
          MediaQuery.sizeOf(context).height *
              (compact
                  ? compactShare
                  : video
                  ? videoShare
                  : 0.35),
        )
        .toDouble();
    // D119's join strip is gone (D212): joins are lines in every room.
    const strip = SizedBox.shrink();
    // D230 (owner's device: «تظهر رسالته في الاعلى نصفها مختفي» and «لا
    // يمكن إرجاع الرسائل بإصبعي»): the lines are anchored at the BOTTOM of
    // the area in every room — the newest just above the quick replies /
    // composer, older ones rising — and a finger drags back through every
    // line this visit keeps ([LiveChatScroll]). Only once they overflow does
    // the top edge fade; a short chat is never faded or cut. Not a lazy
    // list: the audio room measures the chat's height.
    final lines = items.isEmpty
        ? null
        : ConstrainedBox(
            key: listKey,
            // D119: wider than before (300 pt) for the picture, name and
            // badges.
            constraints: BoxConstraints(
              maxHeight: maxHeight,
              maxWidth: inline
                  ? LiveChatInlineRow.chatMaxWidth(context)
                  : LiveChatAuthoredLine.chatMaxWidth(context),
            ),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: LiveChatScroll(
                newest: items.last.key,
                children: [
                  for (final item in items)
                    Padding(
                      key: lineKey(item.key),
                      // D119: messages 8 pt apart (the reference's ~7 pt
                      // at this scale); system lines stay compact.
                      padding: EdgeInsets.only(
                        top: flat
                            ? KFlatChat.gap
                            : inline
                            ? LiveChatInlineRow.gap
                            : item is LiveChatPosted || item is LiveChatPending
                            ? 8
                            : 4,
                      ),
                      child: _line(context, ref, item),
                    ),
                ],
              ),
            ),
          );
    // The strip keeps its room: when the place is bounded (the video live)
    // the lines give way; in the audio room's scroll view they do not need
    // to.
    return LayoutBuilder(
      builder: (context, box) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lines != null)
            if (box.hasBoundedHeight) Flexible(child: lines) else lines,
          strip,
        ],
      ),
    );
  }

  Widget _line(BuildContext context, WidgetRef ref, LiveChatItem item) {
    if (flat) {
      if (_flatLine(context, ref, item) case final row?) return row;
    }
    if (inline) {
      if (_inlineLine(context, ref, item) case final row?) return row;
    }
    final l10n = context.l10n;
    final boxMax = LiveChatAuthoredLine.chatMaxWidth(context);
    return switch (item) {
      // D212: a join is a line in the audio room too.
      LiveChatJoinItem(:final join) => LiveChatJoinBubble(
        join: join,
        color: bubble,
        maxWidth: boxMax,
        onProfile: () => onProfile(join.user.username),
      ),
      // CP-017: a voice clip or a picture (the controller drops them at
      // `expiresAt` and when the media is gone).
      LiveChatPosted(:final entry)
          when entry.kind != LiveChatKind.text && entry.media != null =>
        _mediaLine(context, ref, entry, entry.media!, boxMax),
      // D265: a VIP member's line in the VIP layout.
      LiveChatPosted(:final entry)
          when LiveChatFlatLine.takesVipBubble(
            ref,
            entry.author.vip,
            cp: entry.cpBubble,
          ) =>
        _vipPosted(
          context,
          ref,
          entry,
          maxWidth: boxMax,
          textSize: LiveChatAuthoredLine.textSize,
          picture: true,
        ),
      LiveChatPosted(:final entry) => LiveChatAuthoredLine(
        name: entry.author.displayName,
        vip: entry.author.vip,
        username: entry.author.username,
        premiumTier: entry.author.premiumTier,
        agentCode: entry.author.rechargeAgentCode,
        hostAgentCode: entry.author.hostAgentCode,
        rechargeBadge: entry.author.rechargeBadge,
        avatarUrl: entry.author.avatarUrl,
        role: entry.authorRole,
        badges: entry.authorBadges,
        maxWidth: boxMax,
        label: l10n.liveChatLineLabel(
          entry.author.displayName,
          kabiSpokenText(entry.text, l10n),
        ),
        onProfile: () => onProfile(entry.author.username),
        onActions: () => unawaited(
          showLiveChatActions(
            context,
            ref,
            roomId: roomId,
            entry: entry,
            role: role,
            onProfile: onProfile,
          ),
        ),
        color: _messageBubble,
        cp: entry.cpBubble,
        message: _message(context, entry.text, cp: entry.cpBubble),
      ),
      // This person's own line on its way: their picture and name, no
      // badges until the server stored it (D119: no badge without data).
      LiveChatPending(
        :final failed,
        :final text,
        :final authorName,
        :final tooFast,
      ) =>
        Opacity(
          opacity: failed ? 1 : 0.6,
          child: LiveChatAuthoredLine(
            name: authorName,
            username: ref.watch(currentUserProvider)?.username,
            premiumTier: ref.watch(currentUserProvider)?.premiumTier,
            avatarUrl: ref.watch(currentUserProvider)?.avatarUrl,
            maxWidth: boxMax,
            color: _messageBubble,
            label: [
              l10n.liveChatLineLabel(authorName, kabiSpokenText(text, l10n)),
              if (failed && tooFast)
                l10n.liveChatTooFast
              else if (failed)
                l10n.liveChatFailed,
            ].join('. '),
            onActions: failed
                ? () => unawaited(_failedActions(context, ref, item))
                : null,
            message: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _message(context, text),
                if (failed)
                  Text(
                    tooFast ? l10n.liveChatTooFast : l10n.liveChatFailed,
                    style: context.textStyles.caption.copyWith(
                      color: const Color(0xFFFF8A9A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      // CP-017 (owner, 2026-10-26): a public message, in a box of its own.
      // D141: the owner's public message card, with the sender's badges
      // when this room's chat knows them.
      LiveChatBulletLine(:final bullet) => _publicMessage(
        context,
        ref,
        bullet,
        inline ? LiveChatInlineRow.chatMaxWidth(context) : boxMax,
      ),
      // D118/D135: the room's rules, a see-through system line (not
      // tappable), the first line of this visit.
      // D178: a gift or a lucky win of this live.
      // D224: a quip's line, the same way.
      LiveChatGiftLine() ||
      LiveChatLuckyLine() ||
      LiveChatQuipLine() => LiveChatGiftLineView(
        item: item,
        color: bubble,
        maxWidth: boxMax,
        onProfile: onProfile,
      ),
      LiveChatNoticeLine() => LiveRoomRulesNotice(
        key: LiveRoomChatLines.noticeKey,
        text: l10n.liveRoomRulesNotice,
        label: l10n.liveRoomRulesLabel,
        bright: brightNotice,
      ),
    };
  }

  /// D253: [entry]'s flat line. D265: also a VIP member's line in the other
  /// chats (the D258 VIP layout, the message at that chat's [textSize]).
  Widget _flatPosted(
    BuildContext context,
    WidgetRef ref,
    LiveChatEntry entry, {
    double textSize = KFlatChat.textSize,
  }) {
    final l10n = context.l10n;
    return LiveChatFlatLine(
      textSize: textSize,
      name: entry.author.displayName,
      text: entry.text,
      role: entry.authorRole,
      badges: entry.authorBadges,
      agentCode: entry.author.rechargeAgentCode,
      hostAgentCode: entry.author.hostAgentCode,
      rechargeBadge: entry.author.rechargeBadge,
      // D258: the author's VIP (badge, name colour, bubble).
      vip: entry.author.vip,
      // D257: a worn CP bubble draws in its colours (CP-021).
      cp: entry.cpBubble,
      label: l10n.liveChatLineLabel(
        entry.author.displayName,
        kabiSpokenText(entry.text, l10n),
      ),
      onProfile: () => onProfile(entry.author.username),
      onActions: () => unawaited(
        showLiveChatActions(
          context,
          ref,
          roomId: roomId,
          entry: entry,
          role: role,
          onProfile: onProfile,
        ),
      ),
    );
  }

  /// D265 (owner: the VIP1 host's lines showed no VIP bubble nor badge in
  /// the audio room): a VIP member's text line in the audio room and the
  /// video live — the D258 VIP layout (badge → name → levels → up to 3
  /// medals; the message alone in the VIP bubble) at that chat's sizes,
  /// with the author's picture at the reading start where the chat shows
  /// pictures ([picture]).
  Widget _vipPosted(
    BuildContext context,
    WidgetRef ref,
    LiveChatEntry entry, {
    required double maxWidth,
    required double textSize,
    required bool picture,
  }) {
    final line = _flatPosted(context, ref, entry, textSize: textSize);
    return ConstrainedBox(
      key: LiveRoomChatLines.vipLineKey,
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: !picture
          ? line
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onProfile(entry.author.username),
                    child: KAvatar(
                      key: LiveChatAuthoredLine.avatarKey,
                      name: entry.author.displayName,
                      imageUrl: entry.author.avatarUrl,
                      size: LiveChatAuthoredLine.avatar,
                    ),
                  ),
                ),
                const SizedBox(width: LiveChatAuthoredLine.gap),
                Flexible(child: line),
              ],
            ),
    );
  }

  /// D253: the flat line for [item] (null: the item keeps its row — media,
  /// joins, gifts, bullets).
  Widget? _flatLine(BuildContext context, WidgetRef ref, LiveChatItem item) {
    final l10n = context.l10n;
    switch (item) {
      case LiveChatPosted(:final entry)
          when entry.kind == LiveChatKind.text || entry.media == null:
        return _flatPosted(context, ref, entry);
      case LiveChatPending(
        :final failed,
        :final text,
        :final authorName,
        :final tooFast,
      ):
        return Opacity(
          opacity: failed ? 1 : 0.6,
          child: LiveChatFlatLine(
            name: authorName,
            text: text,
            label: l10n.liveChatLineLabel(
              authorName,
              kabiSpokenText(text, l10n),
            ),
            failed: !failed
                ? null
                : tooFast
                ? l10n.liveChatTooFast
                : l10n.liveChatFailed,
            onActions: failed
                ? () => unawaited(_failedActions(context, ref, item))
                : null,
          ),
        );
      case LiveChatNoticeLine():
        return LiveChatFlatNotice(
          key: LiveRoomChatLines.noticeKey,
          text: l10n.liveRoomRulesNotice,
          label: l10n.liveRoomRulesLabel,
        );
      default:
        return null;
    }
  }

  /// D131: the video live's row for [item] (null: the item keeps its own
  /// widget — a bullet or the rules line).
  Widget? _inlineLine(BuildContext context, WidgetRef ref, LiveChatItem item) {
    final l10n = context.l10n;
    final max = LiveChatInlineRow.chatMaxWidth(context);
    Future<void> actions(LiveChatEntry entry) => showLiveChatActions(
      context,
      ref,
      roomId: roomId,
      entry: entry,
      role: role,
      onProfile: onProfile,
    );
    switch (item) {
      case LiveChatPosted(:final entry)
          when entry.kind != LiveChatKind.text && entry.media != null:
        final media = entry.media!;
        final voice = entry.kind == LiveChatKind.voice;
        final name = entry.author.displayName;
        return LiveChatInlineRow(
          name: name,
          role: entry.authorRole,
          badges: entry.authorBadges,
          agentCode: entry.author.rechargeAgentCode,
          hostAgentCode: entry.author.hostAgentCode,
          rechargeBadge: entry.author.rechargeBadge,
          maxWidth: max,
          color: messageBox,
          cp: entry.cpBubble,
          mediaInside: true,
          label: voice
              ? l10n.liveChatVoiceLine(
                  name,
                  KFormat.countdown(
                    Duration(milliseconds: media.durationMs ?? 0),
                  ),
                )
              : l10n.liveChatPictureLine(name),
          onProfile: () => onProfile(entry.author.username),
          onActions: () => unawaited(actions(entry)),
          media: voice
              ? LiveVoiceClipPill(key: ValueKey(media.id), media: media)
              : LiveChatPictureThumb(media: media),
        );
      // D265: a VIP member's line in the VIP layout.
      case LiveChatPosted(:final entry)
          when LiveChatFlatLine.takesVipBubble(
            ref,
            entry.author.vip,
            cp: entry.cpBubble,
          ):
        return _vipPosted(
          context,
          ref,
          entry,
          maxWidth: max,
          textSize: LiveChatInlineRow.textSize,
          picture: false,
        );
      case LiveChatPosted(:final entry):
        return LiveChatInlineRow(
          name: entry.author.displayName,
          vip: entry.author.vip,
          role: entry.authorRole,
          badges: entry.authorBadges,
          agentCode: entry.author.rechargeAgentCode,
          hostAgentCode: entry.author.hostAgentCode,
          rechargeBadge: entry.author.rechargeBadge,
          maxWidth: max,
          color: messageBox,
          cp: entry.cpBubble,
          label: l10n.liveChatLineLabel(
            entry.author.displayName,
            kabiSpokenText(entry.text, l10n),
          ),
          onProfile: () => onProfile(entry.author.username),
          onActions: () => unawaited(actions(entry)),
          text: entry.text,
        );
      case LiveChatPending(
        :final failed,
        :final text,
        :final authorName,
        :final tooFast,
      ):
        return Opacity(
          opacity: failed ? 1 : 0.6,
          child: LiveChatInlineRow(
            name: authorName,
            maxWidth: max,
            color: messageBox,
            label: [
              l10n.liveChatLineLabel(authorName, kabiSpokenText(text, l10n)),
              if (failed && tooFast)
                l10n.liveChatTooFast
              else if (failed)
                l10n.liveChatFailed,
            ].join('. '),
            onActions: failed
                ? () => unawaited(_failedActions(context, ref, item))
                : null,
            text: text,
            failed: failed
                ? (tooFast ? l10n.liveChatTooFast : l10n.liveChatFailed)
                : null,
          ),
        );
      // D212: the podcast's join lines are the mockup's bubbles (the name in
      // light blue).
      case LiveChatJoinItem(:final join) when compact:
        return LiveChatJoinBubble(
          join: join,
          color: bubble,
          maxWidth: max,
          onProfile: () => onProfile(join.user.username),
        );
      case LiveChatJoinItem(:final join):
        return LiveChatInlineRow(
          maxWidth: max,
          color: bubble,
          label: liveJoinText(l10n, join, isolate: false),
          onProfile: () => onProfile(join.user.username),
          onActions: () => onProfile(join.user.username),
          join: liveJoinText(l10n, join),
          agentCode: join.user.rechargeAgentCode,
          hostAgentCode: join.user.hostAgentCode,
          rechargeBadge: join.user.rechargeBadge,
        );
      case LiveChatGiftLine() || LiveChatLuckyLine() || LiveChatQuipLine():
        // D178: a gift or a lucky win of this live, as a row (D224: and a
        // quip).
        return LiveChatGiftLineView(
          item: item,
          color: bubble,
          maxWidth: max,
          onProfile: onProfile,
        );
      case LiveChatBulletLine() || LiveChatNoticeLine():
        return null;
    }
  }

  /// D141: a public message (bullet) in the owner's card. Its sender's
  /// badges come from their latest message in this chat (the bullet itself
  /// carries none) — nothing is shown when unknown; D145c: never their
  /// role in this room.
  Widget _publicMessage(
    BuildContext context,
    WidgetRef ref,
    LiveBullet bullet,
    double maxWidth,
  ) {
    LiveChatEntry? latest;
    for (final it in ref.read(liveChatProvider(roomId)).items) {
      if (it is LiveChatPosted && it.entry.author.id == bullet.sender.id) {
        latest = it.entry;
      }
    }
    return LivePublicMessage(
      bullet: bullet,
      badges: latest?.authorBadges,
      maxWidth: maxWidth,
      onTap: () => onProfile(bullet.sender.username),
    );
  }

  /// D234 (owner: «أسود شفاف»): a message's default box in every room is
  /// translucent black ([messageBox]); a worn bubble (CP) draws instead.
  static const Color _messageBubble = messageBox;

  Widget _mediaLine(
    BuildContext context,
    WidgetRef ref,
    LiveChatEntry entry,
    LiveChatMedia media,
    double boxMax,
  ) {
    final l10n = context.l10n;
    final name = entry.author.displayName;
    final voice = entry.kind == LiveChatKind.voice;
    return LiveChatAuthoredLine(
      name: name,
      username: entry.author.username,
      premiumTier: entry.author.premiumTier,
      agentCode: entry.author.rechargeAgentCode,
      hostAgentCode: entry.author.hostAgentCode,
      rechargeBadge: entry.author.rechargeBadge,
      avatarUrl: entry.author.avatarUrl,
      role: entry.authorRole,
      badges: entry.authorBadges,
      maxWidth: boxMax,
      // The clip plays (or the picture opens) on a tap; a long press opens
      // the message's actions.
      mediaInside: true,
      label: voice
          ? l10n.liveChatVoiceLine(
              name,
              KFormat.countdown(Duration(milliseconds: media.durationMs ?? 0)),
            )
          : l10n.liveChatPictureLine(name),
      onProfile: () => onProfile(entry.author.username),
      onActions: () => unawaited(
        showLiveChatActions(
          context,
          ref,
          roomId: roomId,
          entry: entry,
          role: role,
          onProfile: onProfile,
        ),
      ),
      color: _messageBubble,
      cp: entry.cpBubble,
      message: voice
          ? LiveVoiceClipPill(key: ValueKey(media.id), media: media)
          : LiveChatPictureThumb(media: media),
    );
  }

  /// The message text in its line's box (D119: the name and badges sit
  /// above it).
  Widget _message(BuildContext context, String text, {bool cp = false}) {
    final styles = context.textStyles;
    const size = LiveChatAuthoredLine.textSize;
    return KBidiRichText(
      TextSpan(
        children: [
          // CP-021: the Exclusive Chat Bubble starts with a small heart.
          if (cp)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              // Placed no taller than the text, so the line keeps its
              // height; the heart overflows its slot a little.
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: SizedBox(
                  key: LiveRoomChatLines.cpHeartKey,
                  width: 15,
                  height: 11,
                  child: OverflowBox(
                    maxWidth: 15,
                    maxHeight: 15,
                    child: Image.asset(
                      LiveCpChatBubble.heart,
                      width: 15,
                      height: 15,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
            ),
          // Kabi emoji tokens (D66) show as the animated emoji, inline; the
          // text is isolated so a mixed-direction message keeps its order.
          TextSpan(
            style: styles.body.copyWith(
              fontSize: size,
              height: 1.3,
              color: KAudioRoom.text,
              fontWeight: FontWeight.w500,
              // D224: no box behind it (unless a worn bubble).
              shadows: cp ? null : KLiveColors.glassShadow,
            ),
            children: [
              ...kabiIsolatedSpans(text, size: size * KKabiEmoji.inlineScale),
            ],
          ),
        ],
      ),
      textScaler: MediaQuery.textScalerOf(context)
          .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
    );
  }

  Future<void> _failedActions(
    BuildContext context,
    WidgetRef ref,
    LiveChatPending line,
  ) async {
    final l10n = context.l10n;
    final chat = ref.read(liveChatProvider(roomId).notifier);
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('liveChat.retry'),
              leading: const Icon(Icons.refresh_rounded),
              title: Text(l10n.liveChatRetry),
              onTap: () => Navigator.of(sheet).pop(true),
            ),
            ListTile(
              key: const Key('liveChat.discard'),
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.liveChatDiscard),
              onTap: () => Navigator.of(sheet).pop(false),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (!choice) {
      chat.discard(line);
      return;
    }
    final failure = await chat.retry(line);
    if (failure != null && context.mounted) {
      KSnack.error(context, failureMessage(l10n, failure));
    }
  }
}

/// The Exclusive Chat Bubble (CP-021, D112, §10.24; `LiveChatMessage.
/// cpBubble`): a pink box with a gold edge in the mood of the owner's
/// privilege art (`assets/cp_space/privilege_bubble.webp`). D119: it is the
/// whole line's box (picture, name, badges and message), the same size as
/// a plain line's glass so the chat never jumps; the text starts with a
/// small glossy heart (`assets/cp_space/heart.webp`).
class LiveCpChatBubble extends StatelessWidget {
  const new({required this.child, super.key, this.padding, this.radius});

  final Widget child;

  /// D131: the inline video row's padding and corners (the same as a plain
  /// row, so the chat never jumps); D119's box by default.
  final EdgeInsetsGeometry? padding;
  final double? radius;

  static const bubbleKey = Key('liveChat.cpBubble');
  static const heart = 'assets/cp_space/heart.webp';

  /// The author's name on the pink (a warm cream, like the art's gold).
  static const name = Color(0xFFFFF0B8);

  /// Pink to violet, sampled from the bubble art's deeper tones so white
  /// text stays readable (≥ 4.5 : 1 at 14 pt).
  static const colors = [Color(0xFFD62F7E), Color(0xFFA22BB0)];
  static const edge = Color(0xFFFFC96B);

  @override
  Widget build(BuildContext context) => Container(
    key: bubbleKey,
    // The 1 pt edge sits inside the plain box's padding.
    padding: (padding ?? LiveChatAuthoredLine.boxPadding).subtract(
      const EdgeInsetsDirectional.all(1),
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: colors,
      ),
      borderRadius: BorderRadius.all(
        Radius.circular(radius ?? LiveChatAuthoredLine.radius),
      ),
      border: const Border.fromBorderSide(BorderSide(color: edge)),
      boxShadow: const [BoxShadow(color: Color(0x55FF4FA0), blurRadius: 6)],
    ),
    child: child,
  );
}

/// D268 (owner: «ايقونة vip دائماً تأتي بعد الاسم»): the author's VIP badge
/// for a chat row's [LiveChatNameRow.nameBadge] — right after the name, as
/// tall as the row's emblems ([height]); null without a VIP.
Widget? liveChatVipBadge({required UserVip? vip, required double height}) =>
    !vip.isMember ? null : VipNameBadge(vip: vip, height: height * 0.92);

/// D265: a chat row's [name] in the author's VIP colour; [name] alone
/// without a VIP.
Widget liveChatVipName({required UserVip? vip, required Widget name}) =>
    vip == null ? name : VipNameShimmer(vip: vip, child: name);

/// D119 (owner: "make the chat text like this", reference look only; then
/// "the box must cover the whole person together with what they sent"):
/// one chat message in one rounded see-through box — the author's round
/// picture at the reading start, then a column with the name (muted, one
/// line), a row of small badges (role, charm and support levels, family —
/// only those the data has) and the message (text, voice clip or picture).
/// The box hugs its content, up to [maxWidth]; a CP line (D112) draws it
/// pink. A tap on the picture or the name opens the person card
/// ([onProfile]); a tap anywhere else in the box, or a long press, opens
/// the message's actions ([onActions]). With [mediaInside] the clip's or
/// picture's own tap plays or opens it.
class LiveChatAuthoredLine extends StatelessWidget {
  const new({
    required this.name,
    required this.avatarUrl,
    required this.label,
    required this.message,
    required this.maxWidth,
    required this.color,
    super.key,
    this.role,
    this.badges,
    this.cp = false,
    this.onProfile,
    this.onActions,
    this.mediaInside = false,
    this.username,
    this.premiumTier,
    this.agentCode,
    this.hostAgentCode,
    this.rechargeBadge,
    this.vip,
  });

  final String name;

  /// D265: the author's VIP without the VIP bubble (a member with it takes
  /// the VIP layout): the VIP badge before the name, the name's colour.
  final UserVip? vip;

  /// v1.54-social (D185): the author's recharge-agent code (the badge).
  final String? agentCode;

  /// v1.58-social (D189): the author's host-agent code (the badge).
  final String? hostAgentCode;

  /// v1.56-social (D187): the author's daily recharge badge while it shows.
  final RechargeBadge? rechargeBadge;

  /// D146: the author's username and premium tier; with a tier the line
  /// shows the special-ID badge (still, no sweep) under the name.
  final String? username;
  final PremiumTier? premiumTier;
  final String? avatarUrl;
  final LiveChatRole? role;
  final LiveChatAuthorBadges? badges;

  /// What a screen reader says for the line (badges are added to it).
  final String label;

  /// The text, or the voice clip / picture.
  final Widget message;
  final double maxWidth;

  /// The box's glass (ignored for a [cp] line).
  final Color color;
  final bool cp;
  final VoidCallback? onProfile;
  final VoidCallback? onActions;
  final bool mediaInside;

  /// Geometry from the owner's reference, scaled to a 32 pt picture
  /// (measured 46 px there, so × 0.70), then the owner's one-box change:
  /// the box 14 pt corners and 8 pt padding (12 at the end); the column
  /// 8 pt after the picture; the name 2 pt down (12.5 pt), 18 pt badges and
  /// the message stacked 4 and 5 pt apart; 14 pt text (measured 14.6).
  /// D230 (owner: «الكتابة صغيرة والميداليات والمستوى صغير»): the name
  /// 15 sp bold, the badges 20 pt under it, the message 15.5 sp.
  static const double avatar = 32;
  static const double gap = 8;
  static const double nameTop = 2;
  // D269 (owner): 1 pt smaller (was 15 / 15.5).
  static const double nameSize = 14;
  static const double textSize = 14.5;
  static const double radius = 14;

  /// D234: one height for every emblem of the badges line (as
  /// [LiveChatInlineRow.badgeHeight]) and the medals under it.
  static const double badgeRowHeight = LiveChatInlineRow.badgeHeight;
  static const double medalSize = LiveChatInlineRow.medalSize;
  static const EdgeInsetsDirectional boxPadding =
      EdgeInsetsDirectional.fromSTEB(8, 8, 12, 8);

  /// The name: muted white.
  static const nameColor = Color(0xB3FFFFFF);

  static const boxKey = Key('liveChat.box');
  static const avatarKey = Key('liveChat.avatar');
  static const nameKey = Key('liveChat.name');

  /// D146: the author's special-ID badge.
  static const premiumKey = Key('liveChat.premium');

  /// The message (text, clip or picture) inside the box.
  static const bubbleKey = Key('liveChat.bubble');

  /// The chat's width, and the widest a box gets: 80 % of the screen, at
  /// most 340 pt.
  static double chatMaxWidth(BuildContext context) =>
      math.min(MediaQuery.sizeOf(context).width * 0.8, 340);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final badges = this.badges;
    final spoken = [
      label,
      if (agentCode case final code?)
        l10n.rechargeAgentBadgeLabel(KFormat.bidiIsolate(code)),
      if (hostAgentCode case final code?)
        l10n.hostAgentBadgeLabel(KFormat.bidiIsolate(code)),
      if (rechargeBadge case final badge? when rechargeBadgeShows(badge))
        l10n.rechargeBadgeLabel(badge.tier),
      if (badges?.charmLevel case final level?) l10n.liveChatCharmLabel(level),
      if (badges?.supportLevel case final level?)
        l10n.liveChatSupportLabel(level),
      if (badges?.family case final family?)
        l10n.liveChatFamilyLabel(
          KFormat.bidiIsolate(family.name),
          family.level,
        ),
      if (badges?.newcomer ?? false) l10n.liveNewcomerBadge,
      if (badges?.medals case final medals? when medals.isNotEmpty)
        l10n.liveChatMedalsLabel(math.min(medals.length, LiveChatMedalRow.max)),
    ].join('. ');
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final row = LiveChatBadgeRow(
      role: role,
      badges: badges,
      agentCode: agentCode,
      hostAgentCode: hostAgentCode,
      rechargeBadge: rechargeBadge,
      agentBadgeHeight: badgeRowHeight,
      fadeOverflow: true,
    );
    final profile = onProfile;
    // The picture and the name are in the line's label already.
    Widget tapProfile(Widget child) => ExcludeSemantics(
      child: profile == null
          ? child
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: profile,
              child: child,
            ),
    );
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        tapProfile(
          KAvatar(
            key: avatarKey,
            name: name,
            imageUrl: avatarUrl,
            size: avatar,
          ),
        ),
        const SizedBox(width: gap),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // D234b: the name, then the pills and level emblems beside
              // it at one height; only the name shortens.
              Padding(
                padding: const EdgeInsets.only(top: nameTop),
                child: LiveChatNameRow(
                  nameBadge: liveChatVipBadge(
                    vip: cp ? null : vip,
                    height: badgeRowHeight,
                  ),
                  name: liveChatVipName(
                    vip: cp ? null : vip,
                    name: tapProfile(
                      Text(
                        KFormat.bidiIsolate(name),
                        key: nameKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textScaler: scaler,
                        style: context.textStyles.caption.copyWith(
                          fontSize: nameSize,
                          height: 1.25,
                          color: cp ? LiveCpChatBubble.name : nameColor,
                          fontWeight: FontWeight.w800,
                          shadows: const [
                            Shadow(color: Color(0x66000000), blurRadius: 2),
                          ],
                        ),
                      ),
                    ),
                  ),
                  badges: row.isNotEmpty ? row : null,
                ),
              ),
              if ((premiumTier, username) case (final tier?, final handle?))
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: KSpecialUsername(
                      key: premiumKey,
                      username: handle,
                      tier: tier,
                      height: 15,
                      animate: false,
                    ),
                  ),
                ),
              // D234: the showcased medals (≤ 5) under the name row.
              if (badges?.medals case final medals? when medals.isNotEmpty) ...[
                const SizedBox(height: 4),
                LiveChatMedalRow(medals: medals),
              ],
              const SizedBox(height: 5),
              KeyedSubtree(key: bubbleKey, child: message),
            ],
          ),
        ),
      ],
    );
    final box = ConstrainedBox(
      key: boxKey,
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: cp
          ? LiveCpChatBubble(child: content)
          : Container(
              padding: boxPadding,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: content,
            ),
    );
    final line = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onActions,
      onLongPress: onActions,
      child: box,
    );
    // A media line keeps its player's own button for screen readers.
    return mediaInside
        ? Semantics(
            container: true,
            label: spoken,
            onTap: onActions,
            onLongPress: onActions,
            child: line,
          )
        : Semantics(
            container: true,
            button: onActions != null,
            label: spoken,
            onTap: onActions,
            onLongPress: onActions,
            excludeSemantics: true,
            child: line,
          );
  }
}

/// D119: the small badges under a chat author's name, at the reading start:
/// the host or moderator tag, the charm level (the charm pack's creature,
/// D101), the support level (the level pack's emblem, D72) and the family
/// chip — only what [badges] carries. Fixed-size art: the text scale does
/// not grow it (the line's label says it).
class LiveChatBadgeRow extends StatelessWidget {
  const new({
    required this.role,
    required this.badges,
    super.key,
    this.height = LiveChatAuthoredLine.badgeRowHeight,
    this.agentCode,
    this.hostAgentCode,
    this.rechargeBadge,
    this.agentBadgeHeight,
    this.fadeOverflow = false,
    this.fullEmblems = false,
  });

  final LiveChatRole? role;

  /// D258: the emblems at the row's [height] as in a [fadeOverflow] row,
  /// without its fade (the VIP row, whose VIP badge follows the levels).
  final bool fullEmblems;
  final LiveChatAuthorBadges? badges;

  /// D230 (owner: «الميداليات والمستوى صغير، واجعل الميداليات أسفل الاسم»):
  /// the row on a line of its own under the name — the emblems and pills at
  /// the row's [height] (not the old small ones), one row whose overflow is
  /// clipped with a fade at the reading end (never an overflow error).
  final bool fadeOverflow;

  /// v1.54-social (D185): the author's recharge-agent code while ACTIVE
  /// (`UserSummary.rechargeAgent`): the agent badge leads the row.
  final String? agentCode;

  /// v1.58-social (D189): the author's host-agent code
  /// (`UserSummary.hostAgent`): its badge follows the recharge one.
  final String? hostAgentCode;

  /// v1.56-social (D187): the daily recharge badge while it shows (next to
  /// the name like the level badge); gone once its `until` passes.
  final RechargeBadge? rechargeBadge;

  /// The row's height (D131: 14 pt in the video live's rows).
  final double height;

  /// Owner (after D189): the agent and daily recharge badges' height — the
  /// level badge's in the line ([inlineAgentBadgeHeight] of the author's
  /// name size by default), never the row's full [height].
  final double? agentBadgeHeight;

  static const roleKey = Key('liveChat.badge.role');
  static const charmKey = Key('liveChat.badge.charm');
  static const supportKey = Key('liveChat.badge.support');
  static const familyKey = Key('liveChat.badge.family');

  /// D154c: «جديد 🌱» for a newcomer.
  static const newcomerKey = Key('liveChat.badge.newcomer');

  static const double _space = 5;

  /// D234: the pills' height in a row of [height] (role, «جديد», family).
  static double pillHeight(double height) => height - 2;

  bool get isNotEmpty =>
      (badges?.kabsoTeam ?? false) ||
      agentCode != null ||
      hostAgentCode != null ||
      rechargeBadgeShows(rechargeBadge) ||
      role == LiveChatRole.host ||
      role == LiveChatRole.moderator ||
      badges?.charmLevel != null ||
      badges?.supportLevel != null ||
      badges?.family != null ||
      (badges?.newcomer ?? false);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final badges = this.badges;
    final tag = switch (role) {
      LiveChatRole.host => l10n.liveChatHostBadge,
      LiveChatRole.moderator => l10n.liveChatModeratorBadge,
      _ => null,
    };
    final h = height;
    final agentH = math.min(
      h,
      agentBadgeHeight ?? inlineAgentBadgeHeight(LiveChatAuthoredLine.nameSize),
    );
    final big = fadeOverflow || fullEmblems;
    // D230: the pills' text and the emblems grow with the row. D234 (owner:
    // «أريدهم بنفس الحجم»): in the line under a name every emblem is [h]
    // tall on screen — the charm creature (1.55 × its pill) and the support
    // art (1.5 × its height) both fill [h] (both arts fill their image) —
    // and the pills are [pillHeight].
    final pillH = big ? pillHeight(h) : h - 2;
    final pillText = big ? pillH * 0.6 : 10.5;
    final charmH = big ? h / 1.55 : CharmLevelBadge.lineHeight;
    final supportH = h / 1.5;
    final family = badges?.family;
    final familyChip = family == null
        ? null
        : LiveChatFamilyChip(
            key: familyKey,
            name: family.name,
            level: family.level,
            height: big ? pillH : LiveChatAuthoredLine.badgeRowHeight,
          );
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // D273: «فريق كابسو» instead of every other badge.
        if (badges?.kabsoTeam ?? false) ...[
          KabsoTeamBadge(height: pillH),
          const SizedBox(width: _space),
        ],
        // D185 (owner): the recharge agent's badge next to the name.
        if (agentCode case final code?) ...[
          RechargeAgentBadge(code: code, height: agentH),
          const SizedBox(width: _space),
        ],
        // D189: the host agent's badge, placed as the recharge one.
        if (hostAgentCode case final code?) ...[
          HostAgentBadge(code: code, height: agentH),
          const SizedBox(width: _space),
        ],
        // D187 (owner): the daily recharge badge next to the name.
        if (rechargeBadgeShows(rechargeBadge)) ...[
          RechargeTierBadge(badge: rechargeBadge, height: agentH),
          const SizedBox(width: _space),
        ],
        if (tag != null)
          Container(
            key: roleKey,
            height: pillH,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: role == LiveChatRole.host
                  ? KAudioRoom.hostTag
                  : const Color(0xFFFFB13B),
              borderRadius: BorderRadius.circular(KRadius.pill),
            ),
            child: Text(
              tag,
              style: context.textStyles.caption.copyWith(
                fontSize: pillText,
                height: 1.1,
                color: const Color(0xFF14123A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        if (tag != null) const SizedBox(width: _space),
        // D154c (owner): «جديد 🌱» next to a newcomer's name.
        if (badges?.newcomer ?? false) ...[
          Container(
            key: newcomerKey,
            height: pillH,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF3DDC97),
              borderRadius: BorderRadius.circular(KRadius.pill),
            ),
            child: Text(
              l10n.liveNewcomerBadge,
              style: context.textStyles.caption.copyWith(
                fontSize: pillText,
                height: 1.1,
                color: const Color(0xFF06301F),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: _space),
        ],
        if (badges?.charmLevel case final level?) ...[
          SizedBox(
            key: charmKey,
            height: h,
            child: Center(
              widthFactor: 1,
              // D135 (owner): one size with the other badges and the
              // room's level chip.
              child: CharmLevelBadge(level: level, height: charmH),
            ),
          ),
          const SizedBox(width: _space),
        ],
        if (badges?.supportLevel case final level?) ...[
          SizedBox(
            key: supportKey,
            height: h,
            child: Center(
              widthFactor: 1,
              child: KLevelBadge(
                category: LevelCategory.support,
                levelNumber: level,
                height: supportH,
              ),
            ),
          ),
          const SizedBox(width: _space),
        ],
        if (familyChip != null)
          // D230: in a faded row every badge keeps its width (the row is
          // clipped instead); else the family chip gives way first.
          if (big) familyChip else Flexible(child: familyChip),
      ],
    );
    return ExcludeSemantics(
      // A row (not a wrap): each badge takes its own width.
      child: MediaQuery.withNoTextScaling(
        child: fadeOverflow ? LiveChatFadeOverflow(child: row) : row,
      ),
    );
  }
}

/// D234b (owner: the level emblems BESIDE the name): one line — CP-021's
/// heart ([heart]), the [name] and, after it at the reading end, the
/// [badges] (role pills and level emblems, one height). Only the name
/// shortens (an ellipsis); the badges keep their size and leave the name at
/// least [nameMin] (beyond that their own row fades out at the end).
/// D268: a VIP author's [nameBadge] right after the name, before the
/// badges; it keeps its width (the badges give way first).
class LiveChatNameRow extends StatelessWidget {
  const new({
    super.key,
    this.name,
    this.badges,
    this.heart = false,
    this.nameBadge,
  });

  final Widget? name;
  final Widget? badges;
  final bool heart;
  final Widget? nameBadge;

  static const double gap = 6;

  /// The least room the name keeps beside many badges.
  static const double nameMin = 64;

  @override
  Widget build(BuildContext context) {
    final name = this.name;
    final badges = switch ((nameBadge, this.badges)) {
      (null, final b) => b,
      (final v?, null) => v,
      (final v?, final b?) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          v,
          const SizedBox(width: 4),
          Flexible(child: b),
        ],
      ),
    };
    return LayoutBuilder(
      builder: (context, box) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (heart)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: Image.asset(
                LiveCpChatBubble.heart,
                key: LiveRoomChatLines.cpHeartKey,
                width: 15,
                height: 15,
                excludeFromSemantics: true,
              ),
            ),
          if (name != null) Flexible(child: name),
          if (name != null && badges != null) const SizedBox(width: gap),
          if (badges != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.max(0, box.maxWidth - nameMin - gap),
              ),
              child: badges,
            ),
        ],
      ),
    );
  }
}

/// D234 (owner: «وتحت سطر أيقونات الليفيل تكون الميداليات حتى ٥ ميداليات،
/// وتحتهم النص»): the medals the author chose to show on their profile
/// (`LiveChatAuthorBadges.medals`, §10.82), at most [max], in their order,
/// one row at the reading start — the profile's medal art ([MedalIcon]).
/// Nothing when there are none (no placeholders). Fixed-size art; the line's
/// label says how many.
class LiveChatMedalRow extends StatelessWidget {
  const new({
    required this.medals,
    super.key,
    this.size = LiveChatInlineRow.medalSize,
  });

  final List<LiveChatAuthorMedal> medals;
  final double size;

  /// The most medals a chat line shows.
  static const int max = 5; // D269 (owner «حدها ٥»): 3 in D258.
  static const double gap = 4;

  static const rowKey = Key('liveChat.medals');
  static Key medalKey(String code) => Key('liveChat.medal.$code');

  @override
  Widget build(BuildContext context) {
    final shown = medals.take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: SizedBox(
        key: rowKey,
        height: size,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, m) in shown.indexed) ...[
              if (i > 0) const SizedBox(width: gap),
              MedalIcon(key: medalKey(m.code), iconKey: m.iconKey, size: size),
            ],
          ],
        ),
      ),
    );
  }
}

/// D230: one row of badges at most as wide as its place; what does not fit
/// is clipped, and the reading end fades out (only when something is cut).
class LiveChatFadeOverflow extends SingleChildRenderObjectWidget {
  const new({super.key, super.child});

  /// The faded end, in pt.
  static const double fade = 18;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFadeOverflow(Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) => (renderObject as _RenderFadeOverflow).direction = Directionality.of(
    context,
  );
}

class _RenderFadeOverflow extends RenderProxyBox {
  new(this._direction);

  TextDirection _direction;
  TextDirection get direction => _direction;
  set direction(TextDirection value) {
    if (value == _direction) return;
    _direction = value;
    markNeedsLayout();
  }

  bool _cut = false;
  double _childWidth = 0;
  final _mask = LayerHandle<ShaderMaskLayer>();
  final _clip = LayerHandle<ClipRectLayer>();

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(
      BoxConstraints(maxHeight: constraints.maxHeight),
      parentUsesSize: true,
    );
    _childWidth = child.size.width;
    size = constraints.constrain(child.size);
    final cut = _childWidth > size.width + 0.5;
    if (cut != _cut) {
      _cut = cut;
      markNeedsCompositingBitsUpdate();
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    return constraints.constrain(
      child.getDryLayout(BoxConstraints(maxHeight: constraints.maxHeight)),
    );
  }

  double get _dx =>
      _direction == TextDirection.rtl ? size.width - _childWidth : 0;

  @override
  bool get alwaysNeedsCompositing => _cut;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    if (!_cut) {
      _mask.layer = null;
      _clip.layer = null;
      context.paintChild(child, offset + Offset(_dx, 0));
      return;
    }
    final rtl = _direction == TextDirection.rtl;
    final stop = (1 - LiveChatFadeOverflow.fade / size.width).clamp(0.0, 1.0);
    final mask = (_mask.layer ??= ShaderMaskLayer())
      ..shader = LinearGradient(
        begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
        end: rtl ? Alignment.centerLeft : Alignment.centerRight,
        colors: const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
        stops: [0, stop, 1],
      ).createShader(Offset.zero & size)
      ..maskRect = offset & size
      ..blendMode = BlendMode.dstIn;
    context.pushLayer(mask, (context, offset) {
      _clip.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        (context, offset) => context.paintChild(child, offset + Offset(_dx, 0)),
        oldLayer: _clip.layer,
      );
    }, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null || !size.contains(position)) return false;
    return result.addWithPaintOffset(
      offset: Offset(_dx, 0),
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.translateByDouble(_dx, 0, 0, 1);
  }

  @override
  void dispose() {
    _mask.layer = null;
    _clip.layer = null;
    super.dispose();
  }
}

/// D119: the author's family under their name in the chat — a small blue
/// to violet pill with the family level in a ring and the family's name
/// (Kabso's own look; one line, cut with an ellipsis).
class LiveChatFamilyChip extends StatelessWidget {
  const new({
    required this.name,
    required this.level,
    super.key,
    this.height = LiveChatAuthoredLine.badgeRowHeight,
  });

  final String name;
  final int level;

  /// D230: the row's height (the stacked rows' badges are taller).
  final double height;

  static const colors = [Color(0xFF2E5BFF), Color(0xFF7B5CFF)];

  @override
  Widget build(BuildContext context) {
    final h = height;
    final grow = h / LiveChatAuthoredLine.badgeRowHeight;
    return Container(
      height: h,
      constraints: BoxConstraints(maxWidth: 132 * grow),
      padding: const EdgeInsetsDirectional.only(start: 1.5, end: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(KRadius.pill),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: colors,
        ),
        border: Border.all(color: const Color(0x59FFFFFF), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: h - 3.5,
            height: h - 3.5,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A2F8F),
              border: Border.all(color: const Color(0xFFDDE6FF)),
            ),
            child: Text(
              '$level',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: KFonts.latin,
                fontSize: 9 * grow,
                height: 1,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              KFormat.bidiIsolate(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textStyles.caption.copyWith(
                fontSize: 11 * grow,
                height: 1.1,
                color: const Color(0xFFFFFFFF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a chat message offers to the caller ([role]): the author's profile,
/// delete (the author, the host, a moderator — not on the host's or another
/// moderator's), mute in chat (the host and moderators, same limits), and
/// report (anyone signed in but the author). The server has the last word.
Future<void> showLiveChatActions(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required LiveChatEntry entry,
  required LiveChatViewerRole role,
  required void Function(String username) onProfile,
}) async {
  final l10n = context.l10n;
  final me = ref.read(currentUserProvider);
  final mine = me != null && entry.author.id == me.id;
  final protected =
      entry.authorRole == LiveChatRole.host ||
      (role == LiveChatViewerRole.moderator &&
          entry.authorRole == LiveChatRole.moderator);
  final moderates =
      role == LiveChatViewerRole.host || role == LiveChatViewerRole.moderator;
  final canDelete = mine || (moderates && !protected);
  final canMute = moderates && !mine && !protected;
  final canReport = me != null && !mine;
  final chat = ref.read(liveChatProvider(roomId).notifier);
  final name = entry.author.displayName;
  final handle = KHandle.isolated(
    entry.author.username,
    premiumTier: entry.author.premiumTier,
  );

  // Whether the author is muted now (only the host and moderators ask).
  var muted = false;
  if (canMute) {
    try {
      final mutes = await ref.read(liveChatProvider(roomId).notifier).mutes();
      muted = mutes.any((m) => m.user.id == entry.author.id);
    } on Object {
      // Offer muting; the server answers either way (idempotent).
    }
    if (!context.mounted) return;
  }

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              KFormat.bidiIsolate(switch (entry.kind) {
                LiveChatKind.voice => l10n.liveVoiceRecord,
                LiveChatKind.image => l10n.liveChatPicture,
                LiveChatKind.text => kabiSpokenText(entry.text, l10n),
              }),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(handle),
          ),
          ListTile(
            key: const Key('liveChat.action.profile'),
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(l10n.liveChatViewProfile),
            onTap: () => Navigator.of(sheet).pop('profile'),
          ),
          if (canDelete)
            ListTile(
              key: const Key('liveChat.action.delete'),
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.liveChatDelete),
              onTap: () => Navigator.of(sheet).pop('delete'),
            ),
          if (canMute)
            ListTile(
              key: const Key('liveChat.action.mute'),
              leading: Icon(
                muted ? Icons.chat_bubble_outline : Icons.speaker_notes_off,
              ),
              title: Text(
                muted
                    ? l10n.liveChatUnmuteUser(KFormat.bidiIsolate(name))
                    : l10n.liveChatMuteUser(KFormat.bidiIsolate(name)),
              ),
              onTap: () => Navigator.of(sheet).pop(muted ? 'unmute' : 'mute'),
            ),
          if (canReport)
            ListTile(
              key: const Key('liveChat.action.report'),
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.liveChatReport),
              onTap: () => Navigator.of(sheet).pop('report'),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  try {
    switch (action) {
      case 'profile':
        onProfile(entry.author.username);
      case 'delete':
        await chat.delete(entry);
        if (context.mounted) KSnack.success(context, l10n.liveChatDeleted);
      case 'mute' || 'unmute':
        await chat.setMuted(entry.author.username, muted: action == 'mute');
        if (context.mounted) {
          KSnack.success(
            context,
            action == 'mute'
                ? l10n.liveChatUserMuted(KFormat.bidiIsolate(name))
                : l10n.liveChatUserUnmuted(KFormat.bidiIsolate(name)),
          );
        }
      case 'report':
        final reason = await pickReportReason(
          context,
          l10n.liveChatReportTitle,
        );
        if (reason == null) return;
        await chat.report(entry, reason);
        if (context.mounted) KSnack.success(context, l10n.feedPostReported);
    }
  } on Object catch (e) {
    if (context.mounted) {
      KSnack.error(context, failureMessage(l10n, toAppFailure(e)));
    }
  }
}

/// The composer's state for the caller: who may write and, if not, why.
({bool canWrite, String hint}) liveChatComposerHint(
  AppLocalizations l10n, {
  required LiveChatState chat,
  required LiveChatViewerRole role,
}) {
  if (role == LiveChatViewerRole.guest) {
    return (canWrite: false, hint: l10n.liveChatSignIn);
  }
  // Chat off says more than a mute (and outlives it).
  if (!chat.enabled && role != LiveChatViewerRole.host) {
    return (canWrite: false, hint: l10n.liveChatOff);
  }
  if (chat.muted) return (canWrite: false, hint: l10n.liveChatMutedPill);
  return (canWrite: true, hint: l10n.goLiveChatPill);
}

/// Sends the composer's text; the field empties at once (the line shows
/// as sending). A refusal is said in a snack.
Future<void> sendLiveChatFrom(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required TextEditingController field,
}) async {
  final text = field.text;
  if (text.trim().isEmpty) return;
  field.clear();
  await sendLiveChatText(context, ref, roomId: roomId, text: text);
}

/// Sends [text] (e.g. a Kabi emoji's token); a refusal shows as a snack.
Future<void> sendLiveChatText(
  BuildContext context,
  WidgetRef ref, {
  required String roomId,
  required String text,
}) async {
  final l10n = context.l10n;
  final failure = await ref.read(liveChatProvider(roomId).notifier).send(text);
  if (failure != null && context.mounted) {
    KSnack.error(context, failureMessage(l10n, failure));
  }
}

/// Owner (2026-10-26, D118): the system line with the room's rules when a
/// live opens — a very see-through red pill with red text and a red shield,
/// distinct from every message (Kabso's wording, l10n). [label] names it for
/// screen readers.
class LiveRoomRulesNotice extends StatelessWidget {
  const new({
    required this.text,
    required this.label,
    super.key,
    this.bright = false,
  });

  final String text;
  final String label;

  /// D135: over a bright room theme the fill is a little darker.
  final bool bright;

  /// D135 (owner: "a transparent background and a colour that suits the
  /// live's background"): no box edge — a see-through dark row like the
  /// chat rows (35 % over video and dark themes, 42 % over bright themes),
  /// soft coral-pink text with a shadow and a coral shield. The text keeps
  /// at least 4.5:1 against the fill as rendered over the brightest
  /// backgrounds tested (a bright video frame, the bright themes; tests).
  static const fill = Color(0x59100610);

  /// D230: the rules text's size.
  static const double noticeTextSize = 13;
  static const fillBright = Color(0x6B100610);
  static const icon = Color(0xFFFF9AA5);
  static const textColor = Color(0xFFFFD6D2);

  /// The room themes whose lower half is bright (mean luminance, D135).
  static const brightThemes = {
    'sunset-sky',
    'heart-garden',
    'moon-palace',
    'ocean-depths',
    'golden-hall',
    'ice-palace',
  };

  static bool isBrightTheme(String? slug) => brightThemes.contains(slug);

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$label. $text',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: bright ? fillBright : fill,
        borderRadius: BorderRadius.circular(LiveChatInlineRow.radius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.shield_rounded,
              size: 15,
              color: icon,
              shadows: [Shadow(color: Color(0x99000000), blurRadius: 3)],
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              // D230: a little larger (12 → 13 sp); a paragraph, so not the
              // one-line system lines' 15 sp (it would fill the chat).
              style: context.textStyles.caption.copyWith(
                fontSize: noticeTextSize,
                height: 1.35,
                color: textColor,
                fontWeight: FontWeight.w600,
                shadows: const [
                  Shadow(color: Color(0xB3000000), blurRadius: 3),
                  Shadow(
                    color: Color(0x80000000),
                    offset: Offset(0, 1),
                    blurRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// D131 (owner: "chat rows exactly like the reference", ref 158/159/163;
/// supersedes D119's box with the picture on the video live): one
/// see-through pill per line, hugging its content up to [chatMaxWidth];
/// at the reading start the author's badges (role tag, charm and support
/// levels, family — only what the data has), the name (mint, bold) and a
/// colon, then the text (white), wrapping under the badges. 11.5 pt
/// corners: a one-line row is a stadium, a wrapped one keeps rounded
/// corners. 13 sp text, 1.4 line height.
/// Joins are rows too ([join]). A tap on the name opens the person
/// ([onProfile]); anywhere else, or a long press, the line's actions.
class LiveChatInlineRow extends StatefulWidget {
  const new({
    required this.maxWidth,
    required this.color,
    required this.label,
    super.key,
    this.name,
    this.role,
    this.badges,
    this.text,
    this.media,
    this.join,
    this.agentCode,
    this.hostAgentCode,
    this.rechargeBadge,
    this.failed,
    this.cp = false,
    this.mediaInside = false,
    this.onProfile,
    this.onActions,
    this.vip,
  });

  final String? name;

  /// D265: the author's VIP without the VIP bubble (a member with it takes
  /// the VIP layout): the VIP badge before the name, the name's colour.
  final UserVip? vip;
  final LiveChatRole? role;
  final LiveChatAuthorBadges? badges;

  /// The message (Kabi emoji tokens show as the emoji).
  final String? text;

  /// A voice clip or picture under the name.
  final Widget? media;

  /// A join line's text ("X joined").
  final String? join;

  /// v1.54-social (D185): the person's recharge-agent code (the badge after
  /// the name or the join text).
  final String? agentCode;

  /// v1.58-social (D189): the person's host-agent code (its badge too).
  final String? hostAgentCode;

  /// v1.56-social (D187): the person's daily recharge badge (after the name
  /// or the join text) while it shows.
  final RechargeBadge? rechargeBadge;

  /// Why a pending line failed (shown under it).
  final String? failed;
  final bool cp;
  final bool mediaInside;
  final double maxWidth;
  final Color color;
  final String label;
  final VoidCallback? onProfile;
  final VoidCallback? onActions;

  /// Measured on ref 158/159/163 (393 pt): at most 318.5 pt wide (81 %),
  /// the name mint `#B0F3EF`. D230 (owner: «الكتابة صغيرة والميداليات
  /// والمستوى صغير، واجعل الميداليات أسفل الاسم وأسفلهم الرسالة»): a message
  /// is three lines — the name (15 sp, bold, no colon), the badges under it
  /// (20 pt tall, one row, the overflow faded) and the message (15.5 sp);
  /// joins stay one compact line at the 15 sp base size.
  /// D269 (owner: «واقترح ان نجعل حجم الخط اقل»): 1 pt smaller — the name
  /// 14, the message 14.5, joins 14 (was 15 / 15.5 / 15).
  static const double textSize = 14.5;
  static const double nameSize = 14;
  static const double compactTextSize = 14;
  static const double lineHeight = 1.35;
  static const double gap = 4;
  static const double radius = 12;

  /// D234 (owner: «لماذا الأيقونة التي ليفيلها ٢٧ بحجم مختلف؟ أريدهم بنفس
  /// الحجم»): every emblem of the badges line — the charm creature, the
  /// support art, the agent and recharge badges — is this tall on screen;
  /// the pills (role, «جديد», family) are [LiveChatBadgeRow.pillHeight].
  /// D269: ≈ 1.6 × the 14 sp name (was 24 for 15 sp).
  static const double badgeHeight = 23;

  /// D234: the medals line under the badges (≤ 5), a little smaller.
  /// D269: 21 (was 22), scaled with the text; 5 fit at 360 pt.
  static const double medalSize = 21;

  /// The public message card's small badges (its own design, CP-017).
  static const double cardBadgeHeight = 14;

  /// D234: room inside the translucent black box.
  static const EdgeInsetsDirectional padding = EdgeInsetsDirectional.fromSTEB(
    10,
    6,
    12,
    7,
  );

  /// D230: the badges row under the name.
  static const badgesKey = Key('liveChat.row.badges');

  /// D230: the message text under the badges.
  static const textKey = Key('liveChat.row.text');
  static const nameColor = Color(0xFFB0F3EF);
  static const joinColor = Color(0xD9FFFFFF);
  static const rowKey = Key('liveChat.row');
  static const nameKey = Key('liveChat.row.name');

  static double chatMaxWidth(BuildContext context) =>
      math.min(MediaQuery.sizeOf(context).width * 0.81, 318.5);

  @override
  State<LiveChatInlineRow> createState() => _LiveChatInlineRowState();
}

class _LiveChatInlineRowState extends State<LiveChatInlineRow> {
  /// A join: one compact line (D230: at the 15 sp base size) with the
  /// person's agent and recharge badges after the text.
  Widget _joinLine(TextStyle base) {
    final w = widget;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final style = base.copyWith(fontSize: LiveChatInlineRow.compactTextSize);
    final badgeH = inlineAgentBadgeHeight(LiveChatInlineRow.compactTextSize);
    return KBidiRichText(
      TextSpan(
        children: [
          TextSpan(
            text: w.join,
            style: style.copyWith(color: LiveChatInlineRow.joinColor),
          ),
          if (w.agentCode != null || w.hostAgentCode != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: RechargeAgentInlineBadge(
                code: w.agentCode,
                hostCode: w.hostAgentCode,
                height: badgeH,
              ),
            ),
          // D187: the daily recharge badge after the join text.
          if (rechargeBadgeShows(w.rechargeBadge))
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: RechargeTierBadge(
                badge: w.rechargeBadge,
                height: badgeH,
                gap: 4,
              ),
            ),
        ],
      ),
      key: LiveChatInlineRow.nameKey,
      textScaler: scaler,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final w = widget;
    final styles = context.textStyles;
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale);
    final base = styles.body.copyWith(
      fontSize: LiveChatInlineRow.textSize,
      height: LiveChatInlineRow.lineHeight,
      color: KAudioRoom.text,
      fontWeight: FontWeight.w500,
      // D224/D234: a message reads on bright video with the live glass's
      // text shadow (on no box or on the translucent black one).
      shadows: w.color.a < 0.5 && !w.cp
          ? KLiveColors.glassShadow
          : const [Shadow(color: Color(0x4D000000), blurRadius: 2)],
    );
    final failed = w.failed;
    final Widget content;
    if (w.join != null) {
      content = _joinLine(base);
    } else {
      final badges = LiveChatBadgeRow(
        role: w.role,
        badges: w.badges,
        agentBadgeHeight: LiveChatInlineRow.badgeHeight,
        agentCode: w.agentCode,
        hostAgentCode: w.hostAgentCode,
        rechargeBadge: w.rechargeBadge,
        fadeOverflow: true,
      );
      final name = w.name;
      final text = w.text;
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. D234b (owner: «الليفيلات بجانب الاسم»): the name (bold, no
          // colon; CP-021's heart before it), then the role pills and level
          // emblems in the same row at one height — the name alone shortens
          // with an ellipsis.
          if (name != null || badges.isNotEmpty)
            LiveChatNameRow(
              nameBadge: liveChatVipBadge(
                vip: w.cp || name == null ? null : w.vip,
                height: LiveChatInlineRow.badgeHeight,
              ),
              name: name == null
                  ? null
                  : liveChatVipName(
                      vip: w.cp ? null : w.vip,
                      name: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: w.onProfile,
                        child: Text(
                          KFormat.bidiIsolate(name),
                          key: LiveChatInlineRow.nameKey,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textScaler: scaler,
                          style: base.copyWith(
                            fontSize: LiveChatInlineRow.nameSize,
                            color: w.cp
                                ? LiveCpChatBubble.name
                                : LiveChatInlineRow.nameColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
              heart: w.cp,
              badges: badges.isNotEmpty
                  ? KeyedSubtree(
                      key: LiveChatInlineRow.badgesKey,
                      child: badges,
                    )
                  : null,
            ),
          // 2. D234: the showcased medals (≤ 5) under the name row.
          if (w.badges?.medals case final medals? when medals.isNotEmpty) ...[
            const SizedBox(height: 3),
            LiveChatMedalRow(medals: medals),
          ],
          // 3. The message (D141: Kabi emoji inline, in reading order).
          if (text != null) ...[
            const SizedBox(height: 2),
            KBidiRichText(
              TextSpan(
                style: base,
                children: [
                  ...kabiIsolatedSpans(
                    text,
                    size: LiveChatInlineRow.textSize * KKabiEmoji.inlineScale,
                  ),
                ],
              ),
              key: LiveChatInlineRow.textKey,
              textScaler: scaler,
            ),
          ],
          if (w.media case final media?) ...[
            const SizedBox(height: 4),
            media,
            const SizedBox(height: 2),
          ],
          if (failed != null)
            Text(
              failed,
              textScaler: scaler,
              style: styles.caption.copyWith(
                color: const Color(0xFFFF8A9A),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      );
    }
    final box = ConstrainedBox(
      key: LiveChatInlineRow.rowKey,
      constraints: BoxConstraints(maxWidth: w.maxWidth),
      // Half a one-line row's height: a one-line row is a stadium, a
      // wrapped one gets ≈ 10 pt corners (ref 159).
      child: w.cp
          ? LiveCpChatBubble(
              padding: LiveChatInlineRow.padding,
              radius: LiveChatInlineRow.radius,
              child: content,
            )
          : Container(
              padding: LiveChatInlineRow.padding,
              decoration: BoxDecoration(
                color: w.color,
                borderRadius: BorderRadius.circular(LiveChatInlineRow.radius),
              ),
              child: content,
            ),
    );
    final actions = w.onActions;
    final line = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: actions,
      onLongPress: actions,
      child: box,
    );
    final spoken = [
      w.label,
      if (w.badges?.charmLevel case final level?)
        l10n.liveChatCharmLabel(level),
      if (w.badges?.supportLevel case final level?)
        l10n.liveChatSupportLabel(level),
      if (w.badges?.family case final family?)
        l10n.liveChatFamilyLabel(
          KFormat.bidiIsolate(family.name),
          family.level,
        ),
      if (w.badges?.medals case final medals? when medals.isNotEmpty)
        l10n.liveChatMedalsLabel(math.min(medals.length, LiveChatMedalRow.max)),
    ].join('. ');
    return Semantics(
      container: true,
      button: actions != null && !w.mediaInside,
      label: spoken,
      onTap: actions,
      onLongPress: actions,
      excludeSemantics: !w.mediaInside,
      child: line,
    );
  }
}

/// D230 (owner: «في البث المباشر لا يمكن إرجاع الرسائل بإصبعي، اعمل سحب
/// للأسفل لأرى الرسائل القديمة»): the chat's lines, oldest first, in a
/// list anchored at the bottom (a reversed scroll view: the newest just
/// above the composer) that a finger drags back through every line this
/// visit keeps. While the person reads older lines a new one never pulls
/// them down: the «رسائل جديدة ↓» pill shows and jumps back to the newest.
/// At the newest, new lines come in at the bottom. The top edge fades only
/// while there is more above it (the lines overflow); a short chat is never
/// faded. The list takes its drags and taps, so the stage under it (tap to
/// like, seats) never gets them.
class LiveChatScroll extends StatefulWidget {
  const new({required this.children, required this.newest, super.key});

  /// The lines, oldest first.
  final List<Widget> children;

  /// The newest line's key (a new one arrived when it changes).
  final String newest;

  static const scrollKey = Key('liveChat.scroll');
  static const newMessagesKey = Key('liveChat.newMessages');

  /// Further from the newest than this, the person is reading older lines.
  static const double awayAt = 24;

  /// The faded top edge while there is more above.
  static const double fade = 40;

  /// Whether [state]'s top edge fades now (tests).
  @visibleForTesting
  static bool debugFading(State<LiveChatScroll> state) =>
      (state as _LiveChatScrollState)._more;

  @override
  State<LiveChatScroll> createState() => _LiveChatScrollState();
}

class _LiveChatScrollState extends State<LiveChatScroll> {
  final _scroll = ScrollController();

  /// Reading older lines (away from the newest).
  bool _away = false;

  /// New lines arrived while away: the pill.
  bool _newBelow = false;

  /// More lines above the top edge: it fades.
  bool _more = false;
  bool _checkQueued = false;

  @override
  void didUpdateWidget(covariant LiveChatScroll old) {
    super.didUpdateWidget(old);
    if (old.newest == widget.newest || !_scroll.hasClients) return;
    final position = _scroll.position;
    final pixels = position.pixels;
    if (pixels > LiveChatScroll.awayAt) {
      // Reading older lines: they stay where they are (the new line adds
      // below them), and the pill says there is more.
      final before = position.maxScrollExtent;
      _newBelow = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        final p = _scroll.position;
        p.jumpTo(
          (pixels + p.maxScrollExtent - before).clamp(0.0, p.maxScrollExtent),
        );
      });
    } else if (pixels > 0) {
      // Near the newest: the new line shows whole.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _check() {
    if (_checkQueued) return;
    _checkQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkQueued = false;
      if (!mounted || !_scroll.hasClients) return;
      final p = _scroll.position;
      if (!p.hasContentDimensions) return;
      final away = p.pixels > LiveChatScroll.awayAt;
      final more = p.maxScrollExtent - p.pixels > 0.5;
      final newBelow = _newBelow && away;
      if (away != _away || more != _more || newBelow != _newBelow) {
        setState(() {
          _away = away;
          _more = more;
          _newBelow = newBelow;
        });
      }
    });
  }

  void _toNewest() {
    setState(() => _newBelow = false);
    if (!_scroll.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _check();
    final more = _more;
    final list = NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _check();
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _check();
          return false;
        },
        // The same tree whether or not the edge fades (the scroll position
        // is kept): only the mask changes.
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              if (more) const Color(0x00000000) else const Color(0xFF000000),
              const Color(0xFF000000),
            ],
            stops: [
              0,
              if (rect.height <= 0)
                0
              else
                (LiveChatScroll.fade / rect.height).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: SingleChildScrollView(
            key: LiveChatScroll.scrollKey,
            controller: _scroll,
            reverse: true,
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.children,
            ),
          ),
        ),
      ),
    );
    return Stack(
      children: [
        list,
        if (_newBelow)
          PositionedDirectional(
            start: 0,
            bottom: 4,
            child: _NewMessagesPill(onTap: _toNewest),
          ),
      ],
    );
  }
}

/// D230: «رسائل جديدة ↓» — Kabso's pink pill over the chat while the person
/// reads older lines.
class _NewMessagesPill extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.liveChatNewMessages;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: LiveChatScroll.newMessagesKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: KPalette.dark.primary,
            borderRadius: BorderRadius.circular(KRadius.pill),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), blurRadius: 6),
            ],
          ),
          child: Text(
            label,
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
            style: context.textStyles.caption.copyWith(
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// D212: «فلان دخل البث» / «فلانة دخلت البث» by the joiner's shown gender,
/// else the neutral «انضم فلان».
String liveJoinText(
  AppLocalizations l10n,
  LiveChatJoinLine join, {
  bool isolate = true,
}) {
  final name = isolate
      ? KFormat.bidiIsolate(join.user.displayName)
      : join.user.displayName;
  return switch (join.gender) {
    LiveJoinGender.male => l10n.chatJoinedMale(name),
    LiveJoinGender.female => l10n.chatJoinedFemale(name),
    null => l10n.chatJoined(name),
  };
}

/// D212: a join as its own line in the audio room and the podcast — a
/// small see-through bubble, the name in a light blue, the rest softer
/// (the approved podcast mockup).
class LiveChatJoinBubble extends StatelessWidget {
  const new({
    required this.join,
    required this.color,
    required this.maxWidth,
    super.key,
    this.onProfile,
  });

  final LiveChatJoinLine join;
  final Color color;
  final double maxWidth;
  final VoidCallback? onProfile;

  static const nameColor = Color(0xFF9FE3FF);
  static const textColor = Color(0xCCFFFFFF);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = liveJoinText(l10n, join);
    final name = KFormat.bidiIsolate(join.user.displayName);
    final at = text.indexOf(name);
    // D230: the chat's 15 sp base size.
    final style = context.textStyles.caption.copyWith(
      fontSize: LiveChatInlineRow.compactTextSize,
      height: 1.35,
      color: textColor,
    );
    final nameStyle = style.copyWith(
      color: nameColor,
      fontWeight: FontWeight.w600,
    );
    return Semantics(
      button: onProfile != null,
      label: liveJoinText(l10n, join, isolate: false),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onProfile,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text.rich(
              at < 0
                  ? TextSpan(text: text)
                  : TextSpan(
                      children: [
                        TextSpan(text: text.substring(0, at)),
                        TextSpan(text: name, style: nameStyle),
                        TextSpan(text: text.substring(at + name.length)),
                      ],
                    ),
              style: style,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
