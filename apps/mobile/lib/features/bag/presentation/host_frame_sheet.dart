import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/bag/data/bag_repository.dart';
import 'package:kabso_live/features/bag/domain/bag_models.dart';
import 'package:kabso_live/features/bag/presentation/avatar_frame_art.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D186 (owner): a host without a stated gender («أفضّل عدم الذكر», or none)
/// picks the colour of their active-host frame — once, changeable later —
/// from the bag: the two frames side by side, the current one marked.
/// Returns the server's `HostFrame` after the choice, or null when closed.
Future<HostFrame?> showHostFrameStyleSheet(
  BuildContext context, {
  HostFrameStyle? current,
}) => showModalBottomSheet<HostFrame>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => HostFrameStyleSheet(current: current),
);

class HostFrameStyleSheet extends ConsumerStatefulWidget {
  const new({super.key, this.current});

  final HostFrameStyle? current;

  static Key optionKey(HostFrameStyle style) =>
      Key('hostFrame.option.${style.wire}');
  static const saveKey = Key('hostFrame.save');
  static const errorKey = Key('hostFrame.error');

  @override
  ConsumerState<HostFrameStyleSheet> createState() =>
      _HostFrameStyleSheetState();
}

class _HostFrameStyleSheetState extends ConsumerState<HostFrameStyleSheet> {
  late HostFrameStyle? _picked = widget.current;
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    final picked = _picked;
    if (picked == null || _busy) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(bagRepositoryProvider)
          .setHostFrameStyle(picked);
      if (mounted) Navigator.of(context).pop(result);
    } on Object catch (e) {
      if (mounted) {
        setState(() => _error = failureMessage(l10n, toAppFailure(e)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final error = _error;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          0,
          KSpacing.lg,
          KSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.hostFrameChooseTitle,
              textAlign: TextAlign.center,
              style: t.title.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: KSpacing.xs),
            Text(
              l10n.hostFrameChooseBody,
              textAlign: TextAlign.center,
              style: t.body.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: KSpacing.lg),
            Row(
              children: [
                for (final style in HostFrameStyle.values) ...[
                  if (style != HostFrameStyle.values.first)
                    const SizedBox(width: KSpacing.md),
                  Expanded(
                    child: _Option(
                      key: HostFrameStyleSheet.optionKey(style),
                      style: style,
                      selected: _picked == style,
                      onTap: _busy
                          ? null
                          : () => setState(() => _picked = style),
                    ),
                  ),
                ],
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: KSpacing.md),
              Text(
                error,
                key: HostFrameStyleSheet.errorKey,
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: p.error),
              ),
            ],
            const SizedBox(height: KSpacing.lg),
            FilledButton(
              key: HostFrameStyleSheet.saveKey,
              onPressed: _picked == null || _busy ? null : _save,
              child: _busy
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.onPrimary,
                      ),
                    )
                  : Text(l10n.hostFrameChoose),
            ),
          ],
        ),
      ),
    );
  }
}

/// One colour: the frame around a neutral picture, its name, a ring when
/// picked.
class _Option extends StatelessWidget {
  const new({
    required this.style,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final HostFrameStyle style;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final name = switch (style) {
      HostFrameStyle.blue => l10n.hostFrameBlue,
      HostFrameStyle.pink => l10n.hostFramePink,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KRadius.md),
        child: Container(
          padding: const EdgeInsets.all(KSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KRadius.md),
            border: Border.all(
              color: selected ? p.primary : p.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, c) => HostFramePreview(
                  style: style,
                  width: c.maxWidth.clamp(0, 140).toDouble(),
                ),
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyStrong.copyWith(color: p.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The active-host frame of [style] around a neutral picture, [width] wide.
class HostFramePreview extends StatelessWidget {
  const new({required this.style, required this.width, super.key});

  final HostFrameStyle style;
  final double width;

  @override
  Widget build(BuildContext context) {
    final art = AvatarFrameArt.byAssetKey(style.assetKey)!;
    return AvatarFramePreview(art: art, width: width);
  }
}

/// A frame's art around a neutral grey picture (no person), [width] wide.
class AvatarFramePreview extends StatelessWidget {
  const new({required this.art, required this.width, super.key});

  final AvatarFrameArt art;
  final double width;

  @override
  Widget build(BuildContext context) {
    final picture = art.pictureForWidth(width);
    return FramedAvatar(
      art: art,
      picture: picture,
      layout: true,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFE6E6EA),
        ),
        child: Icon(
          Icons.person_rounded,
          size: picture * 0.6,
          color: const Color(0xFFB4B5BD),
        ),
      ),
    );
  }
}
