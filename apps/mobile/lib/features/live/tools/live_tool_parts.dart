import 'package:kabso_live/design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// D201: the colours of the live tools' sheets (white sheets like D154g's
/// quality sheet and D199's Room Tools).
abstract final class LiveToolColors {
  static const ink = Color(0xFF1C1B2E);
  static const soft = Color(0xFF6E6E7A);
  static const surface = Color(0xFFF5F7FB);
  static const accent = Color(0xFF7B5CFF);
  static const warning = Color(0xFFB4560B);
  static const warningSurface = Color(0xFFFFF4E5);
  static const rec = Color(0xFFE5303F);
}

/// A white bottom sheet for a live tool.
Future<T?> showLiveToolSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: const Color(0xFFFFFFFF),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: builder,
);

/// A tool sheet's body: the title, then [children], scrolling when tall
/// (360×800 at 1.3 text).
class LiveToolSheetBody extends StatelessWidget {
  const new({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      LiveToolLightTheme(child: Builder(builder: _body));

  Widget _body(BuildContext context) {
    final t = context.textStyles;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: t.title.copyWith(color: LiveToolColors.ink)),
            const SizedBox(height: KSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// An explanatory line with an icon ([warning]: amber).
class LiveToolNote extends StatelessWidget {
  const new({
    required this.icon,
    required this.text,
    this.warning = false,
    super.key,
  });

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    final color = warning ? LiveToolColors.warning : LiveToolColors.soft;
    final body = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: KSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: t.caption.copyWith(
              color: warning ? LiveToolColors.warning : LiveToolColors.soft,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
    if (!warning) return body;
    return Container(
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: LiveToolColors.warningSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: body,
    );
  }
}

/// `m:ss` (Latin digits, left to right).
String liveToolClock(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// The app's light theme under a white tool sheet or page, so its fields and
/// buttons read on white whatever the app's theme.
class LiveToolLightTheme extends StatelessWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: buildAppTheme(
      brightness: Brightness.light,
      locale: Localizations.localeOf(context),
    ),
    child: child,
  );
}
