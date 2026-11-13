import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/application/live_stickers.dart';
import 'package:kabso_live/features/live/domain/live_sticker.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D154h («ملصقات», CONVENTIONS §10.38): the host adds Kabi art or a short
/// text to the live (at most 3), sees what is on and removes any. A new
/// sticker starts in the picture's middle; the host then moves, scales and
/// rotates it on the live itself.
Future<void> showLiveStickerSheet(
  BuildContext context, {
  required String roomId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: const Color(0xFFFFFFFF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => LiveStickerSheet(roomId: roomId),
);

class LiveStickerSheet extends ConsumerStatefulWidget {
  const new({required this.roomId, super.key});

  final String roomId;

  static const textKey = Key('stickers.text');
  static const addTextKey = Key('stickers.addText');
  static const fullKey = Key('stickers.full');
  static Key artKey(String key) => Key('stickers.art.$key');
  static Key removeKey(int index) => Key('stickers.remove.$index');

  @override
  ConsumerState<LiveStickerSheet> createState() => _LiveStickerSheetState();
}

class _LiveStickerSheetState extends ConsumerState<LiveStickerSheet> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save(List<LiveSticker> items) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    final failure = await ref
        .read(liveStickersProvider(widget.roomId).notifier)
        .save(items);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) KSnack.error(context, failureMessage(l10n, failure));
  }

  Future<void> _add({String? artKey, String? text}) async {
    final items = ref.read(liveStickersProvider(widget.roomId));
    if (items.length >= LiveSticker.max) return;
    // Each new one a little lower, so they do not cover each other.
    final y = 0.35 + 0.1 * items.length;
    await _save([
      ...items,
      LiveSticker(
        id: LiveSticker.newId,
        artKey: artKey,
        text: text,
        x: 0.5,
        y: y,
      ),
    ]);
    if (text != null && mounted) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.textStyles;
    const ink = Color(0xFF1C1B2E);
    const soft = Color(0xFF6E6E7A);
    final items = ref.watch(liveStickersProvider(widget.roomId));
    final full = items.length >= LiveSticker.max;
    final art = ref.watch(liveStickerArtProvider);
    final canAdd = !full && !_busy;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.lg,
              KSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.liveToolSticker, style: t.title.copyWith(color: ink)),
                const SizedBox(height: KSpacing.xs),
                Text(
                  l10n.liveStickersHint,
                  style: t.caption.copyWith(color: soft),
                ),
                const SizedBox(height: KSpacing.md),
                Text(
                  l10n.liveStickersOnLive(items.length, LiveSticker.max),
                  style: t.bodyStrong.copyWith(color: ink),
                ),
                const SizedBox(height: KSpacing.xs),
                if (items.isEmpty)
                  Text(
                    l10n.liveStickersNone,
                    style: t.caption.copyWith(color: soft),
                  )
                else
                  for (final (i, s) in items.indexed)
                    Row(
                      children: [
                        SizedBox.square(
                          dimension: 40,
                          child: switch (KabsoEmoji.byKey(s.artKey ?? '')) {
                            final e? => KabiEmoji(e, size: 36, animate: false),
                            null => const Icon(
                              Icons.text_fields_rounded,
                              color: soft,
                            ),
                          },
                        ),
                        const SizedBox(width: KSpacing.sm),
                        Expanded(
                          child: Text(
                            s.text ??
                                KabsoEmoji.byKey(s.artKey ?? '')?.label(l10n) ??
                                '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.body.copyWith(color: ink),
                          ),
                        ),
                        IconButton(
                          key: LiveStickerSheet.removeKey(i),
                          tooltip: l10n.liveStickersRemove,
                          onPressed: _busy
                              ? null
                              : () => unawaited(_save([...items]..removeAt(i))),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: soft,
                          ),
                        ),
                      ],
                    ),
                if (full)
                  Padding(
                    padding: const EdgeInsets.only(top: KSpacing.xs),
                    child: Text(
                      l10n.liveStickersFull,
                      key: LiveStickerSheet.fullKey,
                      style: t.caption.copyWith(color: const Color(0xFFD93A4A)),
                    ),
                  ),
                const SizedBox(height: KSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: LiveStickerSheet.textKey,
                        controller: _text,
                        enabled: canAdd,
                        maxLength: LiveSticker.textMax,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp('[\n\r]')),
                        ],
                        style: t.body.copyWith(color: ink),
                        decoration: InputDecoration(
                          hintText: l10n.liveStickersTextHint,
                          counterText: '',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF5F7FB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: KSpacing.sm),
                    TextButton(
                      key: LiveStickerSheet.addTextKey,
                      onPressed: canAdd
                          ? () {
                              final text = _text.text.trim();
                              if (text.isNotEmpty) {
                                unawaited(_add(text: text));
                              }
                            }
                          : null,
                      child: Text(l10n.liveStickersAddText),
                    ),
                  ],
                ),
                const SizedBox(height: KSpacing.md),
                switch (art) {
                  AsyncData(:final value) => GridView.count(
                    crossAxisCount: 6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final key in value)
                        if (KabsoEmoji.byKey(key) case final e?)
                          Semantics(
                            button: true,
                            enabled: canAdd,
                            label: e.label(l10n),
                            excludeSemantics: true,
                            child: InkWell(
                              key: LiveStickerSheet.artKey(key),
                              borderRadius: BorderRadius.circular(12),
                              onTap: canAdd
                                  ? () => unawaited(_add(artKey: key))
                                  : null,
                              child: Opacity(
                                opacity: canAdd ? 1 : 0.4,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: KabiEmoji(e, animate: false),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                  AsyncError(:final error) => Text(
                    failureMessage(l10n, toAppFailure(error)),
                    style: t.caption.copyWith(color: soft),
                  ),
                  _ => const Padding(
                    padding: EdgeInsets.all(KSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}
