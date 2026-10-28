import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_gift_art.dart';
import 'package:kabso_live/features/messages/domain/dm_models.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Bubble geometry of a direct conversation (D68/D69 look, measured on the
/// owner's chat reference; colours are Kabso's).
abstract final class KDmBubble {
  static const double maxWidth = 282;
  static const double paddingH = 14;
  static const double paddingV = 10;
  static const double radius = 18;
  static const double tailRadius = 4;
  static const double textSize = 16;
  static const double textHeight = 1.3;
  static const double metaSize = 11;
  static const double tickSize = 15;
  static const Size picture = Size(180, 238);
  static const double rowGap = 6;
  static const double giftArt = 56;
}

/// One message of a direct conversation: text (pack emojis animated), a
/// pack emoji alone (big, no bubble), a picture, a voice note, a gift, with
/// the time and — on the caller's own messages — ✓ sent / ✓✓ read.
class DmMessageView extends StatelessWidget {
  const new({
    required this.message,
    required this.peerName,
    super.key,
    this.onLongPress,
  });

  final DmMessage message;
  final String peerName;
  final VoidCallback? onLongPress;

  static Key keyFor(String id) => Key('dm.message.$id');

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final child = switch (message.kind) {
      DmMessageKind.text
          when KabiEmojiText.onlyEmojis(message.text ?? '') != null =>
        _Plain(message: message),
      DmMessageKind.emoji => _Plain(message: message),
      DmMessageKind.image => _Picture(message: message),
      DmMessageKind.voice => _Bubble(
        message: message,
        child: DmVoiceNote(message: message),
      ),
      DmMessageKind.gift => _GiftCard(message: message, peerName: peerName),
      DmMessageKind.text => _Bubble(
        message: message,
        child: KabiEmojiText(
          message.text ?? '',
          style: context.textStyles.body.copyWith(
            fontSize: KDmBubble.textSize,
            height: KDmBubble.textHeight,
            color: mine
                ? context.palette.onPrimary
                : context.palette.textPrimary,
          ),
        ),
      ),
      DmMessageKind.unknown => _Bubble(
        message: message,
        child: Text(
          context.l10n.dmPreviewUnsupported,
          style: context.textStyles.body.copyWith(fontStyle: FontStyle.italic),
        ),
      ),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KDmBubble.rowGap / 2,
      ),
      child: Align(
        alignment: mine
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: GestureDetector(
          key: keyFor(message.id),
          onLongPress: onLongPress,
          child: child,
        ),
      ),
    );
  }
}

/// The time and, on the caller's messages, the ticks.
class DmMeta extends StatelessWidget {
  const new({required this.message, required this.color, super.key});

  final DmMessage message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          KFormat.time(
            message.createdAt.toLocal(),
            Localizations.localeOf(context).toLanguageTag(),
          ),
          style: context.textStyles.caption.copyWith(
            fontSize: KDmBubble.metaSize,
            color: color,
          ),
        ),
        if (message.mine) ...[
          const SizedBox(width: KSpacing.xxs),
          Semantics(
            label: message.read ? l10n.chatStatusRead : l10n.chatStatusSent,
            child: Icon(
              message.read ? Icons.done_all_rounded : Icons.done_rounded,
              size: KDmBubble.tickSize,
              color: message.read ? color.withValues(alpha: 1) : color,
            ),
          ),
        ],
      ],
    );
  }
}

BorderRadiusDirectional _corners({required bool mine}) {
  const round = Radius.circular(KDmBubble.radius);
  const tail = Radius.circular(KDmBubble.tailRadius);
  return BorderRadiusDirectional.only(
    topStart: round,
    topEnd: round,
    bottomStart: mine ? round : tail,
    bottomEnd: mine ? tail : round,
  );
}

class _Bubble extends StatelessWidget {
  const new({required this.message, required this.child});

  final DmMessage message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mine = message.mine;
    return Container(
      constraints: const BoxConstraints(maxWidth: KDmBubble.maxWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: KDmBubble.paddingH,
        vertical: KDmBubble.paddingV,
      ),
      decoration: BoxDecoration(
        // Received bubbles are raised cards (D68); sent ones a soft Kabso
        // red gradient (D69).
        color: mine ? null : p.surfaceRaised,
        gradient: mine
            ? LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [
                  Color.lerp(p.primary, KBrandColors.red400, 0.35)!,
                  p.primary,
                ],
              )
            : null,
        borderRadius: _corners(mine: mine),
        boxShadow: [
          BoxShadow(
            color: (mine ? p.primary : p.textPrimary).withValues(
              alpha: mine ? 0.18 : 0.06,
            ),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: KSpacing.sm,
        children: [
          child,
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.xxs),
            child: DmMeta(
              message: message,
              color: mine
                  ? p.onPrimary.withValues(alpha: 0.75)
                  : p.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pack emojis alone: big, without a bubble (D66).
class _Plain extends StatelessWidget {
  const new({required this.message});

  final DmMessage message;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: message.mine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      KabiEmojiText(
        message.token ?? message.text ?? '',
        style: context.textStyles.body,
      ),
      DmMeta(message: message, color: context.palette.textTertiary),
    ],
  );
}

class _Picture extends StatelessWidget {
  const new({required this.message});

  final DmMessage message;

  @override
  Widget build(BuildContext context) {
    final media = message.media;
    final l10n = context.l10n;
    final p = context.palette;
    final w = media?.width ?? 0;
    final h = media?.height ?? 0;
    final aspect = w > 0 && h > 0 ? w / h : 3 / 4;
    final width = KDmBubble.picture.width;
    final height = (width / aspect).clamp(120.0, KDmBubble.picture.height);
    return Semantics(
      image: true,
      label: l10n.dmPhoto,
      child: GestureDetector(
        onTap: media == null
            ? null
            : () => showDialog<void>(
                context: context,
                builder: (ctx) => Dialog(
                  insetPadding: const EdgeInsets.all(KSpacing.md),
                  backgroundColor: Colors.black,
                  child: InteractiveViewer(
                    child: Image.network(media.url, fit: BoxFit.contain),
                  ),
                ),
              ),
        child: ClipRRect(
          borderRadius: _corners(mine: message.mine),
          child: Stack(
            children: [
              Container(
                width: width,
                height: height,
                color: p.surfaceRaised,
                child: media == null
                    ? Icon(
                        Icons.image_not_supported_outlined,
                        color: p.textTertiary,
                      )
                    : Image.network(
                        media.thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.broken_image_outlined,
                          color: p.textTertiary,
                        ),
                      ),
              ),
              PositionedDirectional(
                end: KSpacing.sm,
                bottom: KSpacing.sm,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: KPalette.dark.scrim.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(KRadius.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.sm,
                      vertical: KSpacing.xxs,
                    ),
                    child: DmMeta(
                      message: message,
                      color: KPalette.dark.textPrimary,
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

/// A voice note: play / pause and its length. The player starts on the
/// first tap.
class DmVoiceNote extends StatefulWidget {
  const new({required this.message, super.key});

  final DmMessage message;

  static Key keyFor(String id) => Key('dm.voice.$id');

  /// Makes the player (tests replace it).
  @visibleForTesting
  static AudioPlayer Function() newPlayer = AudioPlayer.new;

  @override
  State<DmVoiceNote> createState() => _DmVoiceNoteState();
}

class _DmVoiceNoteState extends State<DmVoiceNote> {
  AudioPlayer? _player;
  StreamSubscription<void>? _done;
  bool _playing = false;
  bool _started = false;

  @override
  void dispose() {
    unawaited(_done?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    final url = widget.message.media?.url;
    if (url == null) return;
    try {
      final player = _player ??= DmVoiceNote.newPlayer();
      _done ??= player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playing = false;
            _started = false;
          });
        }
      });
      if (_playing) {
        setState(() => _playing = false);
        await player.pause();
      } else {
        setState(() => _playing = true);
        if (_started) {
          await player.resume();
        } else {
          _started = true;
          await player.play(UrlSource(url));
        }
      }
    } on Object {
      if (mounted) {
        setState(() {
          _playing = false;
          _started = false;
        });
        KSnack.error(context, context.l10n.liveVoicePlayFailed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final mine = widget.message.mine;
    final fg = mine ? p.onPrimary : p.textPrimary;
    final length = KFormat.countdown(
      Duration(milliseconds: widget.message.media?.durationMs ?? 0),
    );
    return Semantics(
      button: true,
      label:
          '${_playing ? l10n.liveChatPause : l10n.liveChatPlay}, '
          '${l10n.dmVoiceNote(length)}',
      onTap: () => unawaited(_toggle()),
      excludeSemantics: true,
      child: GestureDetector(
        key: DmVoiceNote.keyFor(widget.message.id),
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_toggle()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              size: 32,
              color: fg,
            ),
            const SizedBox(width: KSpacing.xs),
            Icon(
              Icons.graphic_eq_rounded,
              size: 22,
              color: fg.withValues(alpha: 0.8),
            ),
            const SizedBox(width: KSpacing.xs),
            Text(
              length,
              textDirection: TextDirection.ltr,
              style: context.textStyles.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A gift in the conversation: its picture, name (from the catalogue), ×N
/// and a lucky gift's result.
class _GiftCard extends ConsumerWidget {
  const new({required this.message, required this.peerName});

  final DmMessage message;
  final String peerName;

  static Key keyFor(String id) => Key('dm.gift.$id');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final gift = message.gift;
    final mine = message.mine;
    final name = gift == null
        ? null
        : ref.watch(giftCatalogueProvider).value?.byCode(gift.giftCode)?.name;
    final count = '${gift?.quantity ?? 1}';
    final title = mine
        ? l10n.dmGiftMine(count)
        : l10n.dmGiftTheirs(KFormat.bidiIsolate(peerName), count);
    final fg = mine ? p.onPrimary : p.textPrimary;
    final lucky = gift != null && gift.lucky
        ? ((gift.luckyCoinsWon ?? 0) > 0
              ? l10n.dmLuckyWon(
                  KFormat.compact(gift.luckyCoinsWon!, l10n),
                  '${gift.luckyTopMultiplier ?? ''}',
                )
              : l10n.dmLuckyNoWin)
        : null;
    return Container(
      key: keyFor(message.id),
      constraints: const BoxConstraints(maxWidth: KDmBubble.maxWidth),
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: mine ? p.primary : p.surfaceRaised,
        borderRadius: _corners(mine: mine),
        border: mine ? null : Border.all(color: KBrandColors.gold),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (gift != null)
            KGiftImage(
              gift.assetKey,
              imageUrl: gift.imageUrl,
              size: KDmBubble.giftArt,
            ),
          const SizedBox(width: KSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (name != null)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textStyles.bodyStrong.copyWith(color: fg),
                  ),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.caption.copyWith(color: fg),
                ),
                if (lucky != null)
                  Text(
                    lucky,
                    style: context.textStyles.caption.copyWith(
                      color: mine ? p.onPrimary : KBrandColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: KSpacing.xxs),
                DmMeta(
                  message: message,
                  color: mine
                      ? p.onPrimary.withValues(alpha: 0.75)
                      : p.textTertiary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
