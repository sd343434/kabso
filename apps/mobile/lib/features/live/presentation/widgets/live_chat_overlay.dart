import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/live_view_data.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Live chat overlay (G-09): the newest [maxVisibleLines] lines, bottom
/// aligned at the start side, each on a `live.chatScrim` bubble, with the
/// top of the stack faded out. Text is white (≥ 5.74:1 even over a white
/// frame); usernames are white `bodyStrong` (gold fails over light video,
/// see contrast_test) and gold is used only for the gift icon. Names and
/// messages are bidi-isolated so Arabic and English lines mix cleanly.
class KLiveChatOverlay extends StatelessWidget {
  const new({
    required this.lines,
    super.key,
    this.maxVisibleLines = KMetrics.chatMaxVisibleLines,
  });

  final List<LiveChatLine> lines;
  final int maxVisibleLines;

  @override
  Widget build(BuildContext context) {
    final visible = lines.length > maxVisibleLines
        ? lines.sublist(lines.length - maxVisibleLines)
        : lines;
    final fades = lines.length >= maxVisibleLines;
    // Bottom-anchored: when the lines are taller than the room's chat cap
    // (HL-L5, 30 % of the screen; large text), the oldest are clipped at
    // the top instead of overflowing.
    Widget column = SingleChildScrollView(
      reverse: true,
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final line in visible)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: KSpacing.xs),
              child: KLiveChatBubble(line: line),
            ),
        ],
      ),
    );
    if (fades) {
      column = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xFF000000)],
          stops: [0, KMetrics.chatFadeFraction],
        ).createShader(bounds),
        child: column,
      );
    }
    return Semantics(
      container: true,
      liveRegion: true,
      child: Align(
        alignment: AlignmentDirectional.bottomStart,
        child: FractionallySizedBox(
          widthFactor: KMetrics.chatWidthFactor,
          alignment: AlignmentDirectional.bottomStart,
          child: Align(
            alignment: AlignmentDirectional.bottomStart,
            child: column,
          ),
        ),
      ),
    );
  }
}

/// One chat line on its scrim bubble.
class KLiveChatBubble extends StatelessWidget {
  const new({required this.line, super.key});

  final LiveChatLine line;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    final white = KPalette.dark.textPrimary;
    final body = text.body.copyWith(color: white);
    final strong = text.bodyStrong.copyWith(color: white);
    String iso(String s) => KFormat.bidiIsolate(s);

    final (IconData? icon, Color? iconColor, InlineSpan span) = switch (line) {
      LiveChatMessage(:final name, :final text) => (
        null,
        null,
        TextSpan(
          children: [
            TextSpan(text: iso(name), style: strong),
            TextSpan(text: '  ${iso(text)}', style: body),
          ],
        ),
      ),
      LiveChatJoin(:final name) => (
        Icons.login,
        white,
        TextSpan(text: l10n.chatJoined(iso(name)), style: body),
      ),
      LiveChatGift(:final name, :final giftName, :final count) => (
        Icons.card_giftcard,
        KBrandColors.gold,
        TextSpan(
          text: l10n.chatGiftSent(iso(name), iso(giftName), count),
          style: strong,
        ),
      ),
      LiveChatSystem(:final text) => (
        Icons.info_outline,
        white,
        TextSpan(text: text, style: body),
      ),
    };

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: KSpacing.sm,
        vertical: KSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: KLiveColors.chatScrim,
        borderRadius: BorderRadius.circular(KRadius.md),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            if (icon != null) ...[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: ExcludeSemantics(
                  child: Icon(icon, size: KMetrics.iconSm, color: iconColor),
                ),
              ),
              const TextSpan(text: ' '),
            ],
            span,
          ],
        ),
        textScaler: MediaQuery.textScalerOf(context)
            .clamp(maxScaleFactor: KMetrics.overlayMaxTextScale),
      ),
    );
  }
}
