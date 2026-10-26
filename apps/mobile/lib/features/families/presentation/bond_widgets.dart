import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Shared pieces of the CP-018 screens (families, CP, medals).

/// The key of the confirm button of [confirmBond].
const Key bondConfirmKey = Key('bonds.confirm');

/// Asks before a family or CP action; true when confirmed.
Future<bool> confirmBond(
  BuildContext context, {
  required String title,
  required String confirm,
  String? body,
  bool destructive = false,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(l10n.bondsCancel),
        ),
        TextButton(
          key: bondConfirmKey,
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(
            confirm,
            style: destructive ? TextStyle(color: dialog.palette.error) : null,
          ),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Whether [error] is the server's [code].
bool isErrorCode(Object error, ErrorCode code) =>
    toAppFailure(error).code == code;

/// A family's emblem: its picture, or the gold shield of the family box.
class FamilyEmblem extends StatelessWidget {
  const new({required this.url, super.key, this.size = 44});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fallback = Padding(
      padding: EdgeInsets.all(size * 0.14),
      child: Image.asset(
        'assets/leaderboard/rank_shield_1.webp',
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      ),
    );
    final url = this.url;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFF4DA),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

/// A slim progress bar (0–1).
class BondProgress extends StatelessWidget {
  const new({required this.value, super.key, this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(KRadius.pill),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 6,
        backgroundColor: p.surfaceRaised,
        color: color ?? p.primary,
      ),
    );
  }
}

/// A section title inside a CP-018 screen.
class BondSectionTitle extends StatelessWidget {
  const new(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      KSpacing.lg,
      KSpacing.lg,
      KSpacing.lg,
      KSpacing.xs,
    ),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: context.textStyles.bodyStrong.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
          ),
        ),
        if (trailing case final trailing?) Flexible(child: trailing),
      ],
    ),
  );
}

/// Points and coins with Latin digits and grouping (DESIGN_SYSTEM §3.3).
String formatBondPoints(int value) => KFormat.grouped(value);
