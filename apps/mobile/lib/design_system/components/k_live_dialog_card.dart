import 'package:kabso_live/design_system/theme/app_theme.dart';
import 'package:kabso_live/design_system/tokens/tokens.dart';
import 'package:material_ui/material_ui.dart';

/// One button of a [KLiveDialogCard].
@immutable
class KLiveDialogAction {
  const new({
    required this.label,
    required this.onPressed,
    this.key,
    this.primary = false,
    this.loading = false,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final Key? key;

  /// The filled brand-red button; the others are outlined.
  final bool primary;

  /// A spinner in place of the label; taps are ignored.
  final bool loading;
}

/// D232 (owner, ref 325 «بهذا الأسلوب لكن الزر أحمر وتمويج أحمر»): the one
/// style of the small cards inside a live (the leave prompt, confirms, PK
/// invitations, small info cards). A floating card with 18 pt corners, a
/// soft brand-red wash over its top that fades into the surface, an
/// optional picture / icon at the top centre, a centred title and text,
/// then full-width pill buttons — the primary filled with the theme's
/// `primary` (white `onPrimary` text: ≥ 4.79:1 dark, ≥ 6.0:1 light), the
/// others outlined. Light: a white card; dark: `surfaceRaised` with a
/// fainter red wash.
class KLiveDialogCard extends StatelessWidget {
  const new({
    super.key,
    this.leading,
    this.title,
    this.message,
    this.body,
    this.actions = const [],
    this.semanticsLabel,
    this.padding = defaultPadding,
    this.dense = false,
  });

  /// At the top centre (a picture with a tag, an icon …).
  final Widget? leading;
  final String? title;
  final String? message;

  /// Free content under the message (a countdown, rows of numbers …).
  final Widget? body;
  final List<KLiveDialogAction> actions;

  /// Names the card for screen readers (defaults to [title]).
  final String? semanticsLabel;

  /// The room inside the card ([defaultPadding]; [compactPadding] for a
  /// card that sits over a small stage, as the PK dare's).
  final EdgeInsetsGeometry padding;

  /// D238 (owner: «اجعل صندوق اصغر ويظهر في الاسفل»): the small card docked
  /// at the bottom of a live (the PK dare): the buttons side by side in one
  /// row ([denseButtonHeight] tall; the first — the primary — at the
  /// reading start), less room above them. Pass [densePadding] with it.
  final bool dense;

  /// Ref 325's padding.
  static const EdgeInsets defaultPadding = EdgeInsets.fromLTRB(
    22.1,
    23.3,
    22.1,
    21.7,
  );

  /// D236: the same card a little tighter (over the PK stage).
  static const EdgeInsets compactPadding = EdgeInsets.fromLTRB(16, 14, 16, 14);

  /// D238: the docked card's padding ([dense]).
  static const EdgeInsets densePadding = EdgeInsets.fromLTRB(12, 10, 12, 12);

  /// Ref 325 (measured on the leave prompt): the wash, the corners and the
  /// buttons.
  static const double radius = 18;
  static const double buttonHeight = 43.9;
  static const double buttonGap = 7.2;

  /// D238: the [dense] card's buttons (side by side, 8 lp apart).
  static const double denseButtonHeight = 40;
  static const double denseButtonGap = 8;
  static const double maxWidth = 420;

  /// The wash's top colour: a pale brand red on white; on the dark surface
  /// brand red at 22 %.
  static const Color washLight = Color(0xFFFFE6E7);
  static const Color washDark = Color(0x38E50914);
  static const Color inkLight = Color(0xFF272A29);
  static const Color buttonInkLight = Color(0xFF252728);
  static const Color outlineLight = Color(0xFFE9E9E9);

  static bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// The card's surface for [context]'s brightness.
  static Color surfaceOf(BuildContext context) =>
      _dark(context) ? KPalette.dark.surfaceRaised : const Color(0xFFFFFFFF);

  /// The text colour on the card.
  static Color inkOf(BuildContext context) =>
      _dark(context) ? KPalette.dark.textPrimary : inkLight;

  /// Secondary text on the card (≥ 4.5:1 on both surfaces).
  static Color softInkOf(BuildContext context) => _dark(context)
      ? KPalette.dark.textSecondary
      : KPalette.light.textSecondary;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final dark = _dark(context);
    final ink = inkOf(context);
    final surface = surfaceOf(context);
    final title = this.title;
    final message = this.message;
    final body = this.body;
    final leading = this.leading;
    return Semantics(
      container: true,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: semanticsLabel ?? title,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: surface,
              border: dark
                  ? Border.all(color: KPalette.dark.border, width: 0.8)
                  : null,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.36],
                colors: [
                  if (dark) Color.alphaBlend(washDark, surface) else washLight,
                  surface,
                ],
              ),
            ),
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading, const SizedBox(height: 22)],
                if (title != null)
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: t.bodyStrong.copyWith(
                      fontSize: 16,
                      color: ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (title != null && message != null)
                  const SizedBox(height: KSpacing.sm),
                if (message != null)
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: t.body.copyWith(
                      fontSize: 14.5,
                      color: title == null ? ink : softInkOf(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (body != null) ...[
                  if (title != null || message != null)
                    const SizedBox(height: KSpacing.md),
                  body,
                ],
                if (actions.isNotEmpty)
                  SizedBox(
                    height: dense
                        ? KSpacing.sm
                        : padding == defaultPadding
                        ? 21.9
                        : KSpacing.md,
                  ),
                if (dense && actions.isNotEmpty)
                  // D238: one row; the Row follows the reading direction, so
                  // the first (primary) button is at the start in Arabic too.
                  Row(
                    children: [
                      for (final (i, a) in actions.indexed) ...[
                        if (i > 0) const SizedBox(width: denseButtonGap),
                        Expanded(child: _Button(action: a, dense: true)),
                      ],
                    ],
                  )
                else
                  for (final (i, a) in actions.indexed) ...[
                    if (i > 0) const SizedBox(height: buttonGap),
                    _Button(action: a),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const new({required this.action, this.dense = false});

  final KLiveDialogAction action;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final a = action;
    final enabled = a.onPressed != null && !a.loading;
    final fg = a.primary
        ? palette.onPrimary
        : dark
        ? KPalette.dark.textPrimary
        : KLiveDialogCard.buttonInkLight;
    return Semantics(
      button: true,
      enabled: enabled,
      label: a.label,
      excludeSemantics: true,
      onTap: enabled ? a.onPressed : null,
      child: GestureDetector(
        key: a.key,
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? a.onPressed : null,
        child: Opacity(
          opacity: a.onPressed == null && !a.loading ? 0.5 : 1,
          child: Container(
            constraints: BoxConstraints(
              minHeight: dense
                  ? KLiveDialogCard.denseButtonHeight
                  : KLiveDialogCard.buttonHeight,
            ),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: dense ? KSpacing.sm : KSpacing.md,
            ),
            decoration: BoxDecoration(
              color: a.primary
                  ? palette.primary
                  : dark
                  ? const Color(0x00000000)
                  : const Color(0xFFFFFFFF),
              border: a.primary
                  ? null
                  : Border.all(
                      color: dark
                          ? KPalette.dark.borderStrong
                          : KLiveDialogCard.outlineLight,
                      width: 0.8,
                    ),
              borderRadius: BorderRadius.circular(KRadius.pill),
            ),
            child: a.loading
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Text(
                    a.label,
                    textAlign: TextAlign.center,
                    maxLines: dense ? 1 : null,
                    overflow: dense ? TextOverflow.ellipsis : null,
                    style: t.bodyStrong.copyWith(
                      fontSize: dense ? 14.5 : 15.5,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// D232: shows [builder]'s card ([KLiveDialogCard]) floating over a 50 %
/// scrim, 18.3 pt from the sides and the bottom (ref 160/325). A tap
/// outside or Back closes it with `null` when [barrierDismissible].
Future<T?> showKLiveDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  transitionDuration: KMotion.of(context, KMotion.base),
  pageBuilder: (dialog, _, _) => KLiveDialogFrame(child: builder(dialog)),
  transitionBuilder: (_, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: KMotion.standard),
    child: child,
  ),
);

/// Places a [KLiveDialogCard] like the leave prompt: at the bottom, 18.3 pt
/// from the sides and the bottom edge (over the home indicator), scrolling
/// when large text makes it taller than the screen.
class KLiveDialogFrame extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            18.3,
            KSpacing.lg,
            18.3,
            bottom > 18.5 ? bottom - 15 : 18.5,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// D232: a yes / no question in the live's card style. True only when
/// [confirmLabel] was tapped.
Future<bool> showKLiveConfirm(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String cancelLabel,
  String? message,
  Widget? leading,
  Key? cardKey,
  Key? confirmKey,
  Key? cancelKey,
  bool barrierDismissible = true,
}) async {
  final ok = await showKLiveDialog<bool>(
    context,
    barrierDismissible: barrierDismissible,
    builder: (dialog) => KLiveDialogCard(
      key: cardKey,
      leading: leading,
      title: title,
      message: message,
      actions: [
        KLiveDialogAction(
          key: confirmKey,
          label: confirmLabel,
          primary: true,
          onPressed: () => Navigator.of(dialog).pop(true),
        ),
        KLiveDialogAction(
          key: cancelKey,
          label: cancelLabel,
          onPressed: () => Navigator.of(dialog).pop(false),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// D232: a short explanation in the live's card style, closed with OK.
Future<void> showKLiveInfo(
  BuildContext context, {
  required String title,
  required String message,
  Widget? leading,
  Key? cardKey,
}) => showKLiveDialog<void>(
  context,
  builder: (dialog) => KLiveDialogCard(
    key: cardKey,
    leading: leading,
    title: title,
    message: message,
    actions: [
      KLiveDialogAction(
        label: MaterialLocalizations.of(dialog).okButtonLabel,
        primary: true,
        onPressed: () => Navigator.of(dialog).pop(),
      ),
    ],
  ),
);

/// A round icon for a card's top centre (brand red on a pale red disc).
class KLiveDialogIcon extends StatelessWidget {
  const new(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dark ? const Color(0x33E50914) : const Color(0xFFFFFFFF),
        border: Border.all(
          color: dark ? const Color(0x66E50914) : const Color(0xFFFFD1D3),
          width: 1.2,
        ),
      ),
      child: Icon(
        icon,
        size: 30,
        color: dark ? KPalette.dark.primaryText : KPalette.light.primary,
      ),
    );
  }
}
