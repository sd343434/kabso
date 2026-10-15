import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Circular avatar: network image when [imageUrl] is set, otherwise the
/// first letter of [name] on a surface circle.
class KAvatar extends StatelessWidget {
  const new({
    required this.name,
    super.key,
    this.imageUrl,
    this.size = KSizes.avatarMd,
    this.semanticLabel,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final String? semanticLabel;

  String get _initial {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return String.fromCharCode(trimmed.runes.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fallback = Container(
      width: size,
      height: size,
      alignment: AlignmentDirectional.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: p.surfaceOverlay,
        border: Border.all(color: p.border),
      ),
      child: Text(
        _initial,
        style: context.textStyles.title.copyWith(
          fontSize: size * 0.4,
          color: p.textPrimary,
        ),
      ),
    );

    final url = imageUrl;
    final content = url == null || url.isEmpty
        ? fallback
        : ClipOval(
            child: Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
          );

    return Semantics(
      image: true,
      label: semanticLabel ?? name,
      child: ExcludeSemantics(child: content),
    );
  }
}
