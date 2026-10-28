import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// D141: rich text whose inline widgets ([WidgetSpan]s) sit where the text
/// puts them in **both** directions.
///
/// Flutter's [RenderParagraph] gives its inline children the paragraph's
/// placeholder boxes in screen order, left to right, while the children are
/// in reading order: with two or more inline widgets in a right-to-left line
/// (the badges and a pack emoji in an Arabic chat row) they trade places —
/// the owner's device showed the badges at the line's end and the emoji at
/// its start. Here each child is placed on the box of its own placeholder
/// character (found by its offset in the text), so the order is the
/// reading order whatever the direction.
///
/// It behaves like [Text.rich] (the ambient [DefaultTextStyle] is the base
/// style) with the parameters the chat needs.
class KBidiRichText extends StatelessWidget {
  const new(this.span, {super.key, this.textScaler, this.textAlign});

  final InlineSpan span;
  final TextScaler? textScaler;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context);
    return KBidiRichTextRaw(
      text: TextSpan(style: style.style, children: [span]),
      textAlign: textAlign ?? style.textAlign ?? TextAlign.start,
      textDirection: Directionality.of(context),
      textScaler: textScaler ?? MediaQuery.textScalerOf(context),
      softWrap: style.softWrap,
      overflow: style.overflow,
      maxLines: style.maxLines,
      textWidthBasis: style.textWidthBasis,
      textHeightBehavior:
          style.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
    );
  }
}

/// The [RichText] behind [KBidiRichText].
class KBidiRichTextRaw extends RichText {
  new({
    required super.text,
    super.key,
    super.textAlign,
    super.textDirection,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.textWidthBasis,
    super.textHeightBehavior,
  });

  @override
  RenderParagraph createRenderObject(BuildContext context) => _BidiParagraph(
    text,
    textAlign: textAlign,
    textDirection: textDirection ?? Directionality.of(context),
    softWrap: softWrap,
    overflow: overflow,
    textScaler: textScaler,
    maxLines: maxLines,
    strutStyle: strutStyle,
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    locale: locale ?? Localizations.maybeLocaleOf(context),
    registrar: selectionRegistrar,
    selectionColor: selectionColor,
  );
}

class _BidiParagraph extends RenderParagraph {
  new(
    super.text, {
    required super.textDirection,
    super.textAlign,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.strutStyle,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.locale,
    super.registrar,
    super.selectionColor,
  });

  /// The paragraph's slot `k` (screen order) belongs to child `_order[k]`.
  List<int>? _order;

  @override
  List<PlaceholderDimensions> layoutInlineChildren(
    double maxWidth,
    ChildLayouter layoutChild,
    ChildBaselineGetter getChildBaseline,
  ) {
    final dimensions = super.layoutInlineChildren(
      maxWidth,
      layoutChild,
      getChildBaseline,
    );
    _order = null;
    if (dimensions.length < 2) return dimensions;
    final order = screenOrder(
      text: text,
      widths: [for (final d in dimensions) d.size.width],
      maxWidth: softWrap || overflow == TextOverflow.ellipsis
          ? maxWidth
          : double.infinity,
      textDirection: textDirection,
      textAlign: textAlign,
      textScaler: textScaler,
      locale: locale,
    );
    if (order == null) return dimensions;
    _order = order;
    return [for (final i in order) dimensions[i]];
  }

  @override
  void positionInlineChildren(List<TextBox> boxes) {
    final order = _order;
    if (order == null || boxes.length != order.length) {
      super.positionInlineChildren(boxes);
      return;
    }
    final byChild = List<TextBox>.filled(order.length, boxes.first);
    for (var k = 0; k < order.length; k++) {
      byChild[order[k]] = boxes[k];
    }
    super.positionInlineChildren(byChild);
  }
}

/// D141: the children of [text]'s placeholders in screen order (lines top
/// to bottom, each left to right) — the order in which the paragraph
/// engine hands out placeholder sizes and boxes (it should be reading
/// order). Found by laying out the same text with each placeholder as a
/// neutral character (`*`, like U+FFFC an "other neutral" for the bidi
/// algorithm) about as wide as it. Null when it is already reading order.
@visibleForTesting
List<int>? screenOrder({
  required InlineSpan text,
  required List<double> widths,
  required double maxWidth,
  required TextDirection textDirection,
  required TextAlign textAlign,
  required TextScaler textScaler,
  Locale? locale,
}) {
  var index = 0;
  InlineSpan stand(InlineSpan span) => switch (span) {
    PlaceholderSpan() => _star(widths[index++]),
    TextSpan(:final children?) => TextSpan(
      text: span.text,
      style: span.style,
      children: [for (final c in children) stand(c)],
    ),
    _ => span,
  };
  final probe = stand(text);
  if (index != widths.length) return null;
  final painter = TextPainter(
    text: probe,
    textDirection: textDirection,
    textAlign: textAlign,
    textScaler: textScaler,
    locale: locale,
  )..layout(maxWidth: maxWidth);
  final offsets = <int>[];
  var at = 0;
  probe.visitChildren((span) {
    if (span is TextSpan) {
      if (span.style?.debugLabel == _starLabel) offsets.add(at);
      at += span.text?.length ?? 0;
    }
    return true;
  });
  // Each star's line (by the line's vertical span: a star can sit lower
  // than the line's top) and its left edge.
  final lines = painter.computeLineMetrics();
  int lineOf(TextBox box) {
    final mid = (box.top + box.bottom) / 2;
    for (final line in lines) {
      if (mid <= line.baseline + line.descent) return line.lineNumber;
    }
    return lines.isEmpty ? 0 : lines.last.lineNumber;
  }

  final places = <(int, double, int)>[];
  for (final (i, offset) in offsets.indexed) {
    final box = painter.getBoxesForSelection(
      TextSelection(baseOffset: offset, extentOffset: offset + 1),
    );
    if (box.isEmpty) {
      painter.dispose();
      return null;
    }
    places.add((lineOf(box.first), box.first.left, i));
  }
  painter.dispose();
  places.sort((a, b) {
    final line = a.$1.compareTo(b.$1);
    return line != 0 ? line : a.$2.compareTo(b.$2);
  });
  final order = [for (final p in places) p.$3];
  for (var k = 0; k < order.length; k++) {
    if (order[k] != k) return order;
  }
  return null;
}

const _starLabel = 'kBidiStar';

/// A neutral character about [width] wide (its glyph plus spacing).
TextSpan _star(double width) => TextSpan(
  text: '*',
  style: TextStyle(
    debugLabel: _starLabel,
    letterSpacing: math.max(0, width - 6),
  ),
);
