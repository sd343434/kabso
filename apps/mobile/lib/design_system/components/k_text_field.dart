import 'package:flutter/services.dart';
import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Labelled text field with error text, optional obscure toggle and an
/// optional status line (e.g. username availability) under the field.
///
/// Text direction follows the ambient [Directionality] unless
/// [textDirection] is given (use `TextDirection.ltr` for emails, usernames
/// and passwords, which are always Latin).
class KTextField extends StatefulWidget {
  const new({
    required this.label,
    super.key,
    this.controller,
    this.errorText,
    this.helperText,
    this.status,
    this.obscure = false,
    this.showPasswordLabel,
    this.hidePasswordLabel,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.textDirection,
    this.enabled = true,
    this.maxLength,
    this.fieldKey,
    this.counterText,
    this.counterIsError = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final String? helperText;

  /// Replaces the helper line when not null.
  final Widget? status;
  final bool obscure;

  /// Semantics labels for the visibility toggle (required when [obscure]).
  final String? showPasswordLabel;
  final String? hidePasswordLabel;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextDirection? textDirection;
  final bool enabled;
  final int? maxLength;

  /// Key of the inner [TextFormField] (tests, focus).
  final Key? fieldKey;

  /// Shown at the end of the helper line (e.g. "12/50").
  final String? counterText;

  /// Renders [counterText] in the error colour.
  final bool counterIsError;

  @override
  State<KTextField> createState() => _KTextFieldState();
}

class _KTextFieldState extends State<KTextField> {
  late bool _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final toggleLabel = _obscured
        ? widget.showPasswordLabel
        : widget.hidePasswordLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          key: widget.fieldKey,
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _obscured,
          enableSuggestions: !widget.obscure,
          autocorrect: false,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          inputFormatters: [
            if (widget.maxLength != null)
              LengthLimitingTextInputFormatter(widget.maxLength),
            ...?widget.inputFormatters,
          ],
          textDirection: widget.textDirection,
          style: context.textStyles.body,
          decoration: InputDecoration(
            labelText: widget.label,
            errorText: widget.errorText,
            helperText: widget.status == null ? widget.helperText : null,
            counterText: widget.counterText,
            counterStyle: widget.counterText == null
                ? null
                : context.textStyles.caption.copyWith(
                    color: widget.counterIsError ? p.error : null,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: toggleLabel,
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: p.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
          ),
        ),
        if (widget.status != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: KSpacing.lg,
              end: KSpacing.lg,
              top: KSpacing.xs,
            ),
            child: widget.status,
          ),
      ],
    );
  }
}
