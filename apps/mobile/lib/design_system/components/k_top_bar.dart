import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:kabso_live/design_system/tokens/component_metrics.dart';
import 'package:material_ui/material_ui.dart';

/// D142 (owner: "put a gap between the top bar and the phone's status
/// info"): every top bar starts [KMetrics.statusBarGap] under the status
/// bar / notch inset — app bars ([KAppBar]), custom headers
/// ([KTopSafeArea], [KTopInset.of]) and the live rooms (D141's
/// [KMetrics.liveHeaderGap] is the same value).
abstract final class KTopInset {
  /// Where a top bar's row starts: the top inset plus the gap.
  static double of(BuildContext context) =>
      MediaQuery.paddingOf(context).top + KMetrics.statusBarGap;
}

/// `SafeArea(bottom: false)` for a custom header whose row must start
/// [KTopInset.of] from the top: the status bar inset plus the gap. The
/// child sees no top padding (as under [SafeArea]).
class KTopSafeArea extends StatelessWidget {
  const new({required this.child, this.bottom = false, super.key});

  final Widget child;

  /// Also keep the bottom inset (as [SafeArea.bottom]).
  final bool bottom;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: KMetrics.statusBarGap),
    child: SafeArea(bottom: bottom, child: child),
  );
}

/// An [AppBar] that starts [KMetrics.statusBarGap] under the status bar
/// (D142). Its background still runs up under the status bar and the gap,
/// so scroll-under tint and colours are unchanged; only the toolbar row
/// (leading, title, actions) moves down by the gap.
class KAppBar extends StatelessWidget implements PreferredSizeWidget {
  const new({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
    this.centerTitle,
    this.titleSpacing,
    this.shape,
    this.elevation,
    this.scrolledUnderElevation,
    this.systemOverlayStyle,
    this.toolbarHeight,
  });

  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool? centerTitle;
  final double? titleSpacing;
  final ShapeBorder? shape;
  final double? elevation;
  final double? scrolledUnderElevation;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final double? toolbarHeight;

  /// The bar's own height (toolbar + [bottom]) plus the gap; the scaffold
  /// adds the status bar inset on top.
  @override
  Size get preferredSize => Size.fromHeight(
    (toolbarHeight ?? kToolbarHeight) +
        (bottom?.preferredSize.height ?? 0) +
        KMetrics.statusBarGap,
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // The bar sees the gap as part of its top inset, so its background
    // fills the inset and the gap and the toolbar row starts below both.
    return MediaQuery(
      data: media.copyWith(
        padding: media.padding.copyWith(
          top: media.padding.top + KMetrics.statusBarGap,
        ),
      ),
      child: AppBar(
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        title: title,
        actions: actions,
        bottom: bottom,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        centerTitle: centerTitle,
        titleSpacing: titleSpacing,
        shape: shape,
        elevation: elevation,
        scrolledUnderElevation: scrolledUnderElevation,
        systemOverlayStyle: systemOverlayStyle,
        toolbarHeight: toolbarHeight,
      ),
    );
  }
}
