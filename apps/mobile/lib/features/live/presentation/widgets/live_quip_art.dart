import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
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

/// A quip's emoji in a soft round badge.
class LiveQuipBadge extends StatelessWidget {
  const new({required this.assetKey, super.key, this.size = 40});

  final String assetKey;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x33FFFFFF), Color(0x14FFFFFF)],
      ),
    ),
    child: Text(
      quipEmoji(assetKey),
      textScaler: TextScaler.noScaling,
      style: TextStyle(fontSize: size * 0.52, height: 1),
    ),
  );
}

/// D154 («إفيهات», owner: «the line's text shows as a chat bubble while it
/// plays»): the quip playing in this live — the sender's picture and name,
/// the words (or the sound's emoji and name), and a speaker to mute quips
/// on this phone. Readable when muted or with Sound effects off (then the
/// speaker shows as off). Nothing when no quip plays. It sits under the
/// room's header, centred, at most [maxWidth] wide.
class LiveQuipBubble extends ConsumerWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const bubbleKey = Key('quip.bubble');
  static const muteKey = Key('quip.bubble.mute');
  static const double maxWidth = 320;

  /// Under the header rows and the lucky ticker.
  static const double top = 140;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quip = ref.watch(liveQuipsProvider(roomId));
    final still = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: still ? Duration.zero : const Duration(milliseconds: 220),
      child: quip == null
          ? const SizedBox.shrink()
          : _Bubble(key: ValueKey(quip.id), quip: quip),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const new({required this.quip, super.key});

  final LiveQuip quip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final gift = ref.watch(giftCatalogueProvider).value?.byCode(quip.giftCode);
    final muted = ref.watch(quipsMutedProvider);
    final soundOn = ref.watch(soundEffectsProvider) && !muted;
    final assetKey = gift?.assetKey ?? quipAssetOf(quip.soundKey);
    final words = quip.text;
    final name = KFormat.bidiIsolate(quip.sender.displayName);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: LiveQuipBubble.maxWidth),
      child: Semantics(
        key: LiveQuipBubble.bubbleKey,
        liveRegion: true,
        label: l10n.liveQuipBubbleSemantics(
          name,
          words ?? gift?.name ?? quipEmoji(assetKey),
        ),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 4, 6),
          decoration: BoxDecoration(
            color: const Color(0xCC1B1A22),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x40FFD36E)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: KAvatar(
                  name: quip.sender.displayName,
                  imageUrl: quip.sender.avatarUrl,
                  size: 28,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.caption.copyWith(
                          color: const Color(0xFFFFD36E),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        words == null
                            ? '${quipEmoji(assetKey)} ${gift?.name ?? ''}'
                            : '${quipEmoji(assetKey)} $words',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        // The Kabi lines are Egyptian Arabic in every
                        // language.
                        textDirection: words == null ? null : TextDirection.rtl,
                        style: text.body.copyWith(
                          color: const Color(0xFFFFFFFF),
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 2),
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
                    width: 32,
                    height: 32,
                    child: Icon(
                      soundOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      size: 18,
                      color: const Color(0xB3FFFFFF),
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
