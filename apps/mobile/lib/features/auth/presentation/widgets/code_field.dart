import 'package:flutter/services.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Length of the registration code (contract v1.2: `^[0-9]{8}$`).
const kRegistrationCodeLength = 8;

/// Keeps only digits, mapping Arabic-Indic (U+0660–0669) and Extended
/// Arabic-Indic (U+06F0–06F9) digits to 0–9. Spaces, hyphens, NBSP, bidi
/// marks and anything else are dropped (PHASE1_1_SCREENS §1.3).
String normalizeCodeDigits(String input) {
  final out = StringBuffer();
  for (final cp in input.runes) {
    if (cp >= 0x30 && cp <= 0x39) {
      out.writeCharCode(cp);
    } else if (cp >= 0x0660 && cp <= 0x0669) {
      out.writeCharCode(0x30 + cp - 0x0660);
    } else if (cp >= 0x06F0 && cp <= 0x06F9) {
      out.writeCharCode(0x30 + cp - 0x06F0);
    }
  }
  return out.toString();
}

/// Filters the code field: normalized digits only, at most 8. Remembers
/// whether the last edit inserted several characters at once (paste or
/// one-time-code autofill) and whether that insertion held exactly 8 digits.
class CodeInputFormatter extends TextInputFormatter {
  /// The last edit inserted more than one character.
  bool lastEditWasPaste = false;

  /// For a paste: the pasted text contained exactly 8 digits.
  bool lastPasteWasValid = false;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = normalizeCodeDigits(newValue.text);
    final selected =
        oldValue.selection.isValid && !oldValue.selection.isCollapsed
        ? oldValue.selection.end - oldValue.selection.start
        : 0;
    final inserted = newValue.text.length - (oldValue.text.length - selected);
    lastEditWasPaste = inserted > 1;
    lastPasteWasValid =
        lastEditWasPaste && digits.length == kRegistrationCodeLength;
    final kept = digits.length > kRegistrationCodeLength
        ? digits.substring(0, kRegistrationCodeLength)
        : digits;
    return TextEditingValue(
      text: kept,
      selection: TextSelection.collapsed(offset: kept.length),
    );
  }
}

/// The 8-digit code input (PHASE1_1_SCREENS §1.3): one real text field under
/// 8 visual cells (4 + 4), always left-to-right with Western digits. Above
/// text scale 1.3 it becomes a single plain field.
class CodeField extends StatelessWidget {
  const new({
    required this.controller,
    required this.focusNode,
    required this.formatter,
    required this.label,
    required this.hint,
    required this.onChanged,
    super.key,
    this.fieldKey,
    this.error = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final CodeInputFormatter formatter;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;
  final bool error;
  final bool enabled;

  static const double cellWidth = 36;
  static const double cellHeight = 52;

  /// Above this text scale the cells are replaced by one plain field.
  static const double plainFieldTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final plain =
        MediaQuery.textScalerOf(context).scale(1) > plainFieldTextScale;
    // Codes are always LTR, even in Arabic.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: plain ? _plain(context) : _cells(context),
    );
  }

  TextField _textField(BuildContext context, {required bool visible}) {
    final p = context.palette;
    final style = context.textStyles.headline.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      letterSpacing: visible ? 4 : 0,
      color: visible ? null : Colors.transparent,
    );
    return TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.oneTimeCode],
      autocorrect: false,
      enableSuggestions: false,
      textDirection: TextDirection.ltr,
      showCursor: visible,
      cursorColor: visible ? p.focusRing : Colors.transparent,
      style: style,
      inputFormatters: [formatter],
      onChanged: onChanged,
      decoration: visible
          ? InputDecoration(
              labelText: label,
              hintText: hint,
              errorText: error ? '' : null,
              errorStyle: const TextStyle(height: 0, fontSize: 0),
            )
          : const InputDecoration.collapsed(hintText: null).copyWith(
              labelText: label,
              hintText: hint,
              labelStyle: const TextStyle(color: Colors.transparent),
              hintStyle: const TextStyle(color: Colors.transparent),
              floatingLabelBehavior: FloatingLabelBehavior.never,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
            ),
    );
  }

  Widget _plain(BuildContext context) => _textField(context, visible: true);

  Widget _cells(BuildContext context) {
    return SizedBox(
      height: cellHeight,
      child: Stack(
        children: [
          Positioned.fill(child: _textField(context, visible: false)),
          IgnorePointer(
            child: ExcludeSemantics(
              child: ListenableBuilder(
                listenable: Listenable.merge([controller, focusNode]),
                builder: (context, _) => _row(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context) {
    final p = context.palette;
    final value = controller.text;
    final focused = focusNode.hasFocus;
    Widget cell(int i) {
      final digit = i < value.length ? value[i] : '';
      final active = focused && i == value.length.clamp(0, 7);
      final Color border;
      final double width;
      if (error) {
        border = p.error;
        width = 2;
      } else if (active) {
        border = p.focusRing;
        width = 2;
      } else {
        border = p.borderStrong;
        width = 1;
      }
      return Opacity(
        opacity: enabled ? 1 : 0.38,
        child: Container(
          key: Key('code.cell.$i'),
          width: cellWidth,
          height: cellHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(KRadius.sm),
            border: Border.all(color: border, width: width),
          ),
          child: Text(
            digit,
            textScaler: TextScaler.noScaling,
            style: context.textStyles.headline.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }

    List<Widget> group(int start) => [
      for (var i = start; i < start + 4; i++) ...[
        if (i != start) const SizedBox(width: KSpacing.xs),
        cell(i),
      ],
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...group(0),
        const SizedBox(width: KSpacing.md),
        ...group(4),
      ],
    );
  }
}
