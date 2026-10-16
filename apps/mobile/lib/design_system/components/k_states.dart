import 'package:kabso_live/design_system/components/k_button.dart';
import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/component_metrics.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Illustration-less empty state: icon, title, message and up to two
/// actions. Only pass an action that really does something.
///
/// Three placements share one anatomy:
///
/// - default: centred on its area with an 88 dp icon disc, scrolls when it
///   does not fit (full-screen states);
/// - [compact] (VG-03): the small in-place state (48 dp icon with no
///   container, top-aligned with an `xxxl` top inset); it does not scroll by
///   itself, so put it in the region's scroll view;
/// - [embedded] (KL-047): the default's visuals (88 dp disc) without its own
///   centring or scrolling, for a parent that places it deliberately (feed
///   regions fill the space under their header and put the block at the
///   optical centre instead of leaving it in a void).
///
/// The main action is a [KButton] in [actionVariant] (secondary by default;
/// pass `primary` when it is the one thing to do here) with an optional
/// [actionIcon]. The optional second action is a ghost button below it.
class KEmptyState extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.actionLabel,
    this.onAction,
    this.actionVariant = KButtonVariant.secondary,
    this.actionIcon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.detail,
    this.compact = false,
    this.embedded = false,
    this.iconColor,
  }) : assert(!(compact && embedded), 'compact and embedded are exclusive');

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final KButtonVariant actionVariant;
  final IconData? actionIcon;

  /// Optional second action (ghost button under the main one).
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// Selectable secondary line (e.g. "Error ID: …").
  final String? detail;

  final bool compact;
  final bool embedded;

  /// Icon tint; defaults to `primaryText` (default, embedded) or
  /// `textSecondary` (compact).
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: _buildFull(context),
    );
    if (embedded) {
      return Padding(
        padding: const EdgeInsetsDirectional.all(KSpacing.xl),
        child: Center(heightFactor: 1, child: content),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(KSpacing.xl),
        child: content,
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Column(
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
            child: Icon(icon, size: 40, color: iconColor ?? p.primaryText),
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
        ..._actions(KSpacing.xl),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    final p = context.palette;
    final t = context.textStyles;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        KSpacing.xl,
        KSpacing.xxxl,
        KSpacing.xl,
        KSpacing.xl,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: KMetrics.compactStateIcon,
                  color: iconColor ?? p.textSecondary,
                ),
              ),
              const SizedBox(height: KSpacing.md),
              Semantics(
                header: true,
                child: Text(title, style: t.title, textAlign: TextAlign.center),
              ),
              const SizedBox(height: KSpacing.xs),
              Text(
                message,
                style: t.body.copyWith(color: p.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (detail != null) ...[
                const SizedBox(height: KSpacing.xs),
                SelectableText(
                  detail!,
                  style: t.caption,
                  textAlign: TextAlign.center,
                ),
              ],
              ..._actions(KSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(double gap) => [
    if (actionLabel != null && onAction != null) ...[
      SizedBox(height: gap),
      KButton(
        label: actionLabel!,
        onPressed: onAction,
        variant: actionVariant,
        icon: actionIcon,
        expand: false,
      ),
    ],
    if (secondaryActionLabel != null && onSecondaryAction != null) ...[
      const SizedBox(height: KSpacing.xs),
      KButton(
        label: secondaryActionLabel!,
        onPressed: onSecondaryAction,
        variant: KButtonVariant.ghost,
        expand: false,
      ),
    ],
  ];
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
    this.compact = false,
    this.embedded = false,
    this.retryVariant = KButtonVariant.secondary,
  });

  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  /// Selectable secondary line (e.g. "Error ID: …").
  final String? detail;

  /// In-place variant (see [KEmptyState.compact]); the icon takes the
  /// `error` tint.
  final bool compact;

  /// See [KEmptyState.embedded]; the icon takes the `error` tint.
  final bool embedded;

  final KButtonVariant retryVariant;

  @override
  Widget build(BuildContext context) {
    return KEmptyState(
      icon: Icons.error_outline_rounded,
      title: title,
      message: message,
      actionLabel: retryLabel,
      onAction: onRetry,
      actionVariant: retryVariant,
      detail: detail,
      compact: compact,
      embedded: embedded,
      iconColor: compact || embedded ? context.palette.error : null,
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
