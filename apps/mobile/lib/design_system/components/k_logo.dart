import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Text-only wordmark placeholder ("Kabso Live") until official brand assets
/// exist (blocker B8). Always laid out left-to-right because it is a Latin
/// brand name.
class KLogo extends StatelessWidget {
  const new({
    required this.primary,
    required this.accent,
    required this.semanticLabel,
    super.key,
    this.size = 28,
  });

  final String primary;
  final String accent;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = TextStyle(
      fontFamily: KFonts.latin,
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.1,
      letterSpacing: -0.5,
      color: p.textPrimary,
    );
    return Semantics(
      label: semanticLabel,
      header: true,
      child: ExcludeSemantics(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: primary, style: base),
                const TextSpan(text: ' '),
                TextSpan(
                  text: accent,
                  style: base.copyWith(color: KBrandColors.red500),
                ),
              ],
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
