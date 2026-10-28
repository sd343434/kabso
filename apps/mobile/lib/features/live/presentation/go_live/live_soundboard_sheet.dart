import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/application/live_gift_providers.dart';
import 'package:kabso_live/features/live/application/live_quips.dart';
import 'package:kabso_live/features/live/data/live_gift_repository.dart';
import 'package:kabso_live/features/live/domain/live_gift_models.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_quip_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D154 (owner: «host and moderators keep a free soundboard, 1 per 2 s»):
/// the free quips of the catalogue as big buttons; a tap plays the sound
/// for the whole room (`playLiveSound`), in the room's one queue of quips.
/// The sheet stays open (several sounds in a row); the server says when the
/// next may go (one every 2 s) and the sheet shows it. The sheet also holds
/// the phone's quips mute, and says when Sound effects are off in Settings.
Future<void> showLiveSoundboard(
  BuildContext context, {
  required String roomId,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: const Color(0xFF1F1D24),
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
  ),
  builder: (_) => LiveSoundboardSheet(roomId: roomId),
);

class LiveSoundboardSheet extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const sheetKey = Key('soundboard.sheet');
  static const muteKey = Key('soundboard.mute');
  static const emptyKey = Key('soundboard.empty');
  static const messageKey = Key('soundboard.message');
  static Key soundKey(String code) => Key('soundboard.sound.$code');

  @override
  ConsumerState<LiveSoundboardSheet> createState() =>
      _LiveSoundboardSheetState();
}

class _LiveSoundboardSheetState extends ConsumerState<LiveSoundboardSheet> {
  String? _busy;
  String? _message;
  bool _error = false;

  Future<void> _play(Gift gift) async {
    if (_busy != null) return;
    setState(() {
      _busy = gift.code;
      _message = null;
    });
    final l10n = context.l10n;
    try {
      final quip = await ref
          .read(liveGiftRepositoryProvider)
          .playSound(widget.roomId, soundCode: gift.code);
      ref.read(liveQuipsProvider(widget.roomId).notifier).receive(quip);
      if (!mounted) return;
      final seconds = (quip.delayMs / 1000).ceil();
      setState(() {
        _error = false;
        _message = seconds > 0 ? l10n.liveQuipQueued(seconds) : null;
      });
    } on Object catch (e) {
      final failure = toAppFailure(e);
      if (!mounted) return;
      if (failure.code == ErrorCode.giftUnavailable) {
        unawaited(ref.read(giftCatalogueProvider.notifier).reload());
      }
      setState(() {
        _error = true;
        _message = failureMessage(l10n, failure);
      });
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    final catalogue = ref.watch(giftCatalogueProvider).value;
    final sounds = [
      for (final g in catalogue?.of(GiftCategory.quips) ?? const <Gift>[])
        if (g.priceCoins == 0 && g.quip != null) g,
    ];
    final muted = ref.watch(quipsMutedProvider);
    final effectsOn = ref.watch(soundEffectsProvider);
    const ink = Color(0xFFFFFFFF);
    const muteInk = Color(0xFFB9B6C2);
    return SafeArea(
      top: false,
      child: Semantics(
        key: LiveSoundboardSheet.sheetKey,
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: l10n.liveQuipSoundboardTitle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KSpacing.md,
            14,
            KSpacing.md,
            KSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.liveQuipSoundboardTitle,
                        style: t.title.copyWith(color: ink),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    toggled: muted,
                    label: muted ? l10n.liveQuipUnmute : l10n.liveQuipMute,
                    excludeSemantics: true,
                    child: IconButton(
                      key: LiveSoundboardSheet.muteKey,
                      onPressed: () =>
                          ref.read(quipsMutedProvider.notifier).toggle(),
                      icon: Icon(
                        muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        color: muteInk,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                effectsOn
                    ? l10n.liveQuipSoundboardHint
                    : l10n.liveQuipSoundEffectsOff,
                style: t.caption.copyWith(color: muteInk),
              ),
              const SizedBox(height: KSpacing.md),
              if (sounds.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: KSpacing.lg),
                  child: Text(
                    l10n.liveQuipSoundboardEmpty,
                    key: LiveSoundboardSheet.emptyKey,
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(color: muteInk),
                  ),
                )
              else
                Wrap(
                  spacing: KSpacing.sm,
                  runSpacing: KSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final g in sounds)
                      _SoundButton(
                        key: LiveSoundboardSheet.soundKey(g.code),
                        gift: g,
                        busy: _busy == g.code,
                        onTap: _busy == null ? () => unawaited(_play(g)) : null,
                      ),
                  ],
                ),
              if (_message case final message?) ...[
                const SizedBox(height: KSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    key: LiveSoundboardSheet.messageKey,
                    textAlign: TextAlign.center,
                    style: t.caption.copyWith(
                      color: _error ? const Color(0xFFFF8A8A) : muteInk,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SoundButton extends StatelessWidget {
  const new({
    required this.gift,
    required this.busy,
    required this.onTap,
    super.key,
  });

  final Gift gift;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: gift.name,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 74,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                opacity: onTap == null && !busy ? 0.5 : 1,
                duration: const Duration(milliseconds: 150),
                child: LiveQuipBadge(assetKey: gift.assetKey, size: 52),
              ),
              const SizedBox(height: 4),
              Text(
                gift.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: t.caption.copyWith(color: const Color(0xFFE9E7EE)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
