import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/emoji/kabi_emoji.dart';
import 'package:kabso_live/features/live/application/live_stickers.dart';
import 'package:kabso_live/features/live/domain/live_sticker.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D154h («ملصقات», CONVENTIONS §10.38): the live's stickers over the
/// picture, each at its place relative to the picture (so it lands in the
/// same place on every screen), scaled and rotated. On the host's phone
/// ([editable]) one finger moves a sticker and two scale and rotate it;
/// the list is saved when the fingers lift. Viewers' stickers take no
/// touches. A sticker of art this app cannot draw is skipped.
class LiveStickerLayer extends ConsumerWidget {
  const new({required this.roomId, this.editable = false, super.key});

  final String roomId;
  final bool editable;

  /// An art sticker's side at scale 1.
  static const double artSize = 72;

  static Key stickerKey(int index) => Key('sticker.$index');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(liveStickersProvider(roomId));
    if (items.isEmpty) return const SizedBox.shrink();
    final layer = LayoutBuilder(
      builder: (context, box) => Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          for (final (i, s) in items.indexed)
            if (_content(context, s) case final child?)
              Positioned(
                left: s.x * box.maxWidth,
                top: s.y * box.maxHeight,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: Transform.rotate(
                    angle: s.rotation,
                    child: Transform.scale(
                      scale: s.scale,
                      child: editable
                          ? _Handle(
                              key: stickerKey(i),
                              roomId: roomId,
                              index: i,
                              size: box.biggest,
                              child: child,
                            )
                          : KeyedSubtree(key: stickerKey(i), child: child),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
    return editable ? layer : IgnorePointer(child: layer);
  }

  static Widget? _content(BuildContext context, LiveSticker s) {
    if (s.artKey case final key?) {
      final emoji = KabsoEmoji.byKey(key);
      if (emoji == null) return null;
      return KabiEmoji(
        emoji,
        size: artSize,
        semanticLabel: emoji.label(context.l10n),
      );
    }
    final text = s.text;
    if (text == null) return null;
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6)],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.textStyles.bodyStrong.copyWith(
          color: const Color(0xFF1C1B2E),
          fontSize: 16,
          height: 1.25,
        ),
      ),
    );
  }
}

class _Handle extends ConsumerStatefulWidget {
  const new({
    required this.roomId,
    required this.index,
    required this.size,
    required this.child,
    super.key,
  });

  final String roomId;
  final int index;
  final Size size;
  final Widget child;

  @override
  ConsumerState<_Handle> createState() => _HandleState();
}

class _HandleState extends ConsumerState<_Handle> {
  LiveSticker? _start;

  LiveStickersController get _controller =>
      ref.read(liveStickersProvider(widget.roomId).notifier);

  List<LiveSticker> get _items => ref.read(liveStickersProvider(widget.roomId));

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onScaleStart: (_) => _start = _items[widget.index],
    onScaleUpdate: (d) {
      final items = [..._items];
      final start = _start;
      if (start == null || widget.index >= items.length) return;
      final now = items[widget.index];
      items[widget.index] = now.moved(
        x: now.x + d.focalPointDelta.dx / widget.size.width,
        y: now.y + d.focalPointDelta.dy / widget.size.height,
        scale: d.pointerCount > 1 ? start.scale * d.scale : null,
        rotation: d.pointerCount > 1 ? start.rotation + d.rotation : null,
      );
      _controller.preview(items);
    },
    onScaleEnd: (_) {
      _start = null;
      unawaited(_save());
    },
    child: widget.child,
  );

  Future<void> _save() async {
    final l10n = context.l10n;
    final failure = await _controller.save(_items);
    if (failure != null && mounted) {
      KSnack.error(context, failureMessage(l10n, failure));
    }
  }
}
