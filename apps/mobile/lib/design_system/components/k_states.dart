import 'package:kabso_live/design_system/components/k_button.dart';
import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Centered illustration-less empty state: icon, title, message and an
/// optional action. Only pass an action that really does something.
class KEmptyState extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.actionLabel,
    this.onAction,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Selectable secondary line (e.g. "Error ID: …").
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(KSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: KSizes.avatarLg,
                height: KSizes.avatarLg,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: p.surfaceRaised,
                  border: Border.all(color: p.border),
                ),
                child: ExcludeSemantics(
                  child: Icon(icon, size: 40, color: p.primary),
                ),
              ),
              const SizedBox(height: KSpacing.xl),
              Semantics(
                header: true,
                child: Text(title, style: t.title, textAlign: TextAlign.center),
              ),
              const SizedBox(height: KSpacing.sm),
              Text(
                message,
                style: t.body.copyWith(color: p.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (detail != null) ...[
                const SizedBox(height: KSpacing.sm),
                SelectableText(
                  detail!,
                  style: t.caption,
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: KSpacing.xl),
                KButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  variant: KButtonVariant.secondary,
                  expand: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state with a retry action.
class KErrorState extends StatelessWidget {
  const new({
    required this.title,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    super.key,
    this.detail,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  /// Selectable secondary line (e.g. "Error ID: …").
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return KEmptyState(
      icon: Icons.error_outline_rounded,
      title: title,
      message: message,
      actionLabel: retryLabel,
      onAction: onRetry,
      detail: detail,
    );
  }
}

/// Inline banner for form-level errors and notices.
class KInlineMessage extends StatelessWidget {
  const new({
    required this.message,
    super.key,
    this.isError = true,
    this.detail,
  });

  final String message;
  final bool isError;

  /// Selectable secondary line (e.g. "Error ID: …").
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = isError ? p.error : p.info;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.all(KSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(KRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                isError ? Icons.error_outline_rounded : Icons.info_outline,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: KSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: context.textStyles.body.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: KSpacing.xs),
                    SelectableText(detail!, style: context.textStyles.caption),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
