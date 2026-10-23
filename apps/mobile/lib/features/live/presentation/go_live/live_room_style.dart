import 'dart:math' as math;

import 'package:kabso_live/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// The live rooms' look (owner D94, after their audio-room reference):
/// calm dark navy, navy cards with a thin edge, and a glowing cyan accent.
abstract final class KLiveStyle {
  static const background = Color(0xFF0A1220);
  static const backgroundTop = Color(0xFF0E1A2E);
  static const card = Color(0xFF13203A);
  static const cardRaised = Color(0xFF182844);
  static const edge = Color(0xFF243656);
  static const accent = Color(0xFF22C7F0);
  static const accentDeep = Color(0xFF1E88E5);
  static const text = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9FB0CC);
  static const micOn = Color(0xFF2F9BFF);
  static const micMuted = Color(0xFFFF4D7A);

  /// The rings of seated guests, in seat order.
  static const rings = [
    [Color(0xFFFF5FA2), Color(0xFFFF9A5F)],
    [Color(0xFF3FA9FF), Color(0xFF6C7BFF)],
    [Color(0xFFB65CFF), Color(0xFFFF5FA2)],
    [Color(0xFF22C7F0), Color(0xFF3FA9FF)],
  ];

  static BoxDecoration cardDecoration({bool selected = false}) => BoxDecoration(
    color: selected ? const Color(0xFF12304F) : card,
    borderRadius: BorderRadius.circular(KRadius.lg),
    border: Border.all(
      color: selected ? accent : edge,
      width: selected ? 1.6 : 1,
    ),
    boxShadow: selected
        ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 14)]
        : null,
  );
}

/// The navy background with a few faint sound-wave lines low on the screen.
class LiveNavyBackground extends StatelessWidget {
  const new({super.key, this.waves = true});

  final bool waves;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [KLiveStyle.backgroundTop, KLiveStyle.background],
      ),
    ),
    child: waves
        ? const CustomPaint(painter: _FaintWaves(), child: SizedBox.expand())
        : const SizedBox.expand(),
  );
}

class _FaintWaves extends CustomPainter {
  const new();

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 4; i++) {
      final y0 = size.height * (0.72 + i * 0.06);
      final a = size.height * 0.018 * (1 + i * 0.3);
      final path = Path();
      for (var x = 0.0; x <= size.width; x += 4) {
        final y =
            y0 +
            math.sin(x / size.width * 2 * math.pi * (1.1 + i * 0.2) + i) * a;
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = KLiveStyle.accent.withValues(alpha: 0.07 + i * 0.02),
      );
    }
  }

  @override
  bool shouldRepaint(_FaintWaves old) => false;
}

/// A section heading, with an optional trailing link ("View all").
class LiveSectionTitle extends StatelessWidget {
  const new(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = context.textStyles;
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.only(top: KSpacing.xl, bottom: KSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: text.title.copyWith(
                  color: KLiveStyle.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action,
                style: text.label.copyWith(color: KLiveStyle.accent),
              ),
            ),
        ],
      ),
    );
  }
}

/// The big glowing cyan button (go live).
class LiveGlowButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon = Icons.graphic_eq_rounded,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('goLive.start'),
        onTap: onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled || busy ? 1 : 0.5,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KRadius.pill),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF4FDCFF),
                  KLiveStyle.accent,
                  Color(0xFF0FA3D8),
                ],
              ),
              border: Border.all(color: const Color(0x66FFFFFF)),
              boxShadow: [
                BoxShadow(
                  color: KLiveStyle.accent.withValues(alpha: 0.55),
                  blurRadius: 24,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: busy
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(KLiveStyle.text),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: KLiveStyle.text, size: 26),
                        const SizedBox(width: KSpacing.sm),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyles.title.copyWith(
                              color: KLiveStyle.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
