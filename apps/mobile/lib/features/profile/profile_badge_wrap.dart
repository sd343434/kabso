// D299: the badges under the name on the profile cover (VIP, Kabso Team,
// the crests, the levels) wrap like a [Wrap] but onto at most [maxLines]
// lines; a badge that would start a further line is not shown (not
// painted, not hit, not read), so the name block never overflows the
// picture beside the photo.

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// A [Wrap] (horizontal, the reading direction, runs centred on their
/// line) of at most [maxLines] lines.
class ProfileBadgeWrap extends MultiChildRenderObjectWidget {
  const new({
    required super.children,
    required this.maxLines,
    super.key,
    this.spacing = 0,
    this.runSpacing = 0,
    this.centre = false,
  }) : assert(maxLines > 0, 'at least one line');

  final int maxLines;
  final double spacing;
  final double runSpacing;

  /// D316: each line centred in the box (the centred profile header).
  final bool centre;

  @override
  RenderProfileBadgeWrap createRenderObject(BuildContext context) =>
      RenderProfileBadgeWrap(
        maxLines: maxLines,
        spacing: spacing,
        runSpacing: runSpacing,
        textDirection: Directionality.of(context),
        centre: centre,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderProfileBadgeWrap renderObject,
  ) {
    renderObject
      ..maxLines = maxLines
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..centre = centre
      ..textDirection = Directionality.of(context);
  }
}

/// The parent data of [RenderProfileBadgeWrap]'s children.
class ProfileBadgeWrapParentData extends ContainerBoxParentData<RenderBox> {
  /// Past [ProfileBadgeWrap.maxLines]: laid out but not shown.
  bool hidden = false;
}

/// The render object of [ProfileBadgeWrap].
class RenderProfileBadgeWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, ProfileBadgeWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, ProfileBadgeWrapParentData> {
  new({
    required this._maxLines,
    required this._spacing,
    required this._runSpacing,
    required this._textDirection,
    this._centre = false,
  });

  bool _centre;
  bool get centre => _centre;
  set centre(bool value) {
    if (value == _centre) return;
    _centre = value;
    markNeedsLayout();
  }

  int _maxLines;
  int get maxLines => _maxLines;
  set maxLines(int value) {
    if (value == _maxLines) return;
    _maxLines = value;
    markNeedsLayout();
  }

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _runSpacing;
  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (value == _runSpacing) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  TextDirection get textDirection => _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  /// How many children the last layout left out.
  int get hiddenCount {
    var n = 0;
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as ProfileBadgeWrapParentData;
      if (data.hidden) n++;
      child = data.nextSibling;
    }
    return n;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ProfileBadgeWrapParentData) {
      child.parentData = ProfileBadgeWrapParentData();
    }
  }

  List<RenderBox> get _children {
    final out = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      out.add(child);
      child = childAfter(child);
    }
    return out;
  }

  /// Splits [sizes] into lines no wider than [maxWidth]: the lines' child
  /// counts, at most [maxLines] of them.
  List<int> _lines(List<Size> sizes, double maxWidth) {
    final lines = <int>[];
    var x = 0.0;
    var count = 0;
    for (final s in sizes) {
      final next = count == 0 ? s.width : x + spacing + s.width;
      if (count > 0 && next > maxWidth) {
        lines.add(count);
        if (lines.length == maxLines) return lines;
        x = s.width;
        count = 1;
      } else {
        x = next;
        count++;
      }
    }
    if (count > 0) lines.add(count);
    return lines;
  }

  Size _measure(
    BoxConstraints constraints,
    Size Function(RenderBox, BoxConstraints) sizeOf, {
    void Function(List<RenderBox>, List<Size>, List<int>, Size)? place,
  }) {
    final children = _children;
    final inner = BoxConstraints(maxWidth: constraints.maxWidth);
    final sizes = [for (final c in children) sizeOf(c, inner)];
    final lines = _lines(sizes, constraints.maxWidth);
    var width = 0.0;
    var height = 0.0;
    var i = 0;
    for (final (n, count) in lines.indexed) {
      var w = 0.0;
      var h = 0.0;
      for (var k = 0; k < count; k++) {
        w += sizes[i + k].width + (k > 0 ? spacing : 0);
        h = math.max(h, sizes[i + k].height);
      }
      i += count;
      width = math.max(width, w);
      height += h + (n > 0 ? runSpacing : 0);
    }
    final size = constraints.constrain(Size(width, height));
    place?.call(children, sizes, lines, size);
    return size;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _measure(constraints, (c, b) => c.getDryLayout(b));

  @override
  void performLayout() {
    size = _measure(
      constraints,
      (c, b) {
        c.layout(b, parentUsesSize: true);
        return c.size;
      },
      place: (children, sizes, lines, size) {
        final rtl = textDirection == TextDirection.rtl;
        var i = 0;
        var y = 0.0;
        for (final count in lines) {
          var h = 0.0;
          for (var k = 0; k < count; k++) {
            h = math.max(h, sizes[i + k].height);
          }
          var lineWidth = 0.0;
          for (var k = 0; k < count; k++) {
            lineWidth += sizes[i + k].width + (k > 0 ? spacing : 0);
          }
          var x = centre ? (size.width - lineWidth) / 2 : 0.0;
          for (var k = 0; k < count; k++) {
            final s = sizes[i + k];
            children[i + k].parentData! as ProfileBadgeWrapParentData
              ..hidden = false
              ..offset = Offset(
                rtl ? size.width - x - s.width : x,
                y + (h - s.height) / 2,
              );
            x += s.width + spacing;
          }
          i += count;
          y += h + runSpacing;
        }
        for (; i < children.length; i++) {
          (children[i].parentData! as ProfileBadgeWrapParentData)
            ..hidden = true
            ..offset = Offset.zero;
        }
      },
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    var w = 0.0;
    for (final c in _children) {
      w = math.max(w, c.getMinIntrinsicWidth(double.infinity));
    }
    return w;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final children = _children;
    var w = 0.0;
    for (final c in children) {
      w += c.getMaxIntrinsicWidth(double.infinity);
    }
    return w + math.max(0, children.length - 1) * spacing;
  }

  @override
  double computeMinIntrinsicHeight(double width) => _measure(
    BoxConstraints(maxWidth: width),
    (c, b) => c.getDryLayout(b),
  ).height;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      computeMinIntrinsicHeight(width);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToHighestActualBaseline(baseline);

  bool _shown(RenderBox child) =>
      !(child.parentData! as ProfileBadgeWrapParentData).hidden;

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as ProfileBadgeWrapParentData;
      if (!data.hidden) context.paintChild(child, data.offset + offset);
      child = data.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final data = child.parentData! as ProfileBadgeWrapParentData;
      final box = child;
      if (!data.hidden) {
        final hit = result.addWithPaintOffset(
          offset: data.offset,
          position: position,
          hitTest: (result, transformed) =>
              box.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    for (final c in _children) {
      if (_shown(c)) visitor(c);
    }
  }
}
