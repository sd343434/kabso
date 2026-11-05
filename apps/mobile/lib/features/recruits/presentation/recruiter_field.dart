import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/widgets/kabso_team_badge.dart'
    show KabsoTeamColors;
import 'package:kabso_live/features/recruits/data/recruits_repository.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Where the recruiter field stands.
enum RecruiterCheckState { empty, checking, found, notFound }

/// The field's value and its live check. [ok] when it may be sent: empty (no
/// recruiter) or a recruiter found.
@immutable
final class RecruiterCheck {
  const new(this.state, {this.text = '', this.recruiter});

  static const empty = RecruiterCheck(RecruiterCheckState.empty);

  final RecruiterCheckState state;
  final String text;
  final StaffRecruiter? recruiter;

  bool get ok =>
      state == RecruiterCheckState.empty || state == RecruiterCheckState.found;

  /// What the form sends (`recruiter`): null when empty.
  String? get value => state == RecruiterCheckState.empty ? null : text;
}

/// v1.75-live (D285, owner): the optional field «إن كنت تابعاً لمشرف، ضع
/// معرّفه هنا» on the agency, recharge-agent, host and creator forms — a
/// staff ID («Kabso01», «kabso1», «@Kabso01») or the staff member's username,
/// checked live (`lookupStaffRecruiter`, 400 ms after the last keystroke):
/// the recruiter's name and «فريق كابسو» badge with the role, or «غير
/// موجود». The form blocks sending while the text names nobody.
class RecruiterField extends ConsumerStatefulWidget {
  const new({
    required this.onChanged,
    this.showError = false,
    this.debounce = const Duration(milliseconds: 400),
    super.key,
  });

  final ValueChanged<RecruiterCheck> onChanged;

  /// After a send attempt: a text naming nobody shows the fix-it error.
  final bool showError;
  final Duration debounce;

  static const fieldKey = Key('recruiter.field');
  static const foundKey = Key('recruiter.found');
  static const notFoundKey = Key('recruiter.notFound');
  static const checkingKey = Key('recruiter.checking');

  @override
  ConsumerState<RecruiterField> createState() => _RecruiterFieldState();
}

class _RecruiterFieldState extends ConsumerState<RecruiterField> {
  final _controller = TextEditingController();
  Timer? _timer;
  RecruiterCheck _check = RecruiterCheck.empty;
  int _seq = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _set(RecruiterCheck c) {
    if (!mounted) return;
    setState(() => _check = c);
    widget.onChanged(c);
  }

  void _changed(String raw) {
    _timer?.cancel();
    final text = raw.trim();
    final seq = ++_seq;
    if (text.isEmpty) {
      _set(RecruiterCheck.empty);
      return;
    }
    _set(RecruiterCheck(RecruiterCheckState.checking, text: text));
    _timer = Timer(widget.debounce, () => unawaited(_lookup(text, seq)));
  }

  Future<void> _lookup(String text, int seq) async {
    StaffRecruiter? found;
    try {
      found = await ref.read(recruitsRepositoryProvider).lookup(text);
    } on Object {
      found = null;
    }
    if (seq != _seq) return;
    _set(
      found == null
          ? RecruiterCheck(RecruiterCheckState.notFound, text: text)
          : RecruiterCheck(
              RecruiterCheckState.found,
              text: text,
              recruiter: found,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final r = _check.recruiter;
    final Widget? status = switch (_check.state) {
      RecruiterCheckState.empty => null,
      RecruiterCheckState.checking => Row(
        key: RecruiterField.checkingKey,
        children: [
          const SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: KSpacing.xs),
          Text(
            l10n.recruiterChecking,
            style: t.caption.copyWith(color: p.textSecondary),
          ),
        ],
      ),
      RecruiterCheckState.found when r != null => Semantics(
        label: l10n.recruiterFoundSemantics(r.displayName),
        child: Row(
          key: RecruiterField.foundKey,
          children: [
            const Icon(
              Icons.verified_rounded,
              size: 16,
              color: KabsoTeamColors.end,
            ),
            const SizedBox(width: KSpacing.xs),
            Flexible(
              child: Text(
                r.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.caption.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: KSpacing.xs),
            _Badge(
              text: [
                ?r.staffId,
                if (r.bd) l10n.staffRoleBd else l10n.staffRoleModeration,
              ].join(' · '),
            ),
          ],
        ),
      ),
      _ => Row(
        key: RecruiterField.notFoundKey,
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: p.error),
          const SizedBox(width: KSpacing.xs),
          Text(
            l10n.recruiterNotFound,
            style: t.caption.copyWith(color: p.error),
          ),
        ],
      ),
    };
    return KTextField(
      fieldKey: RecruiterField.fieldKey,
      label: l10n.recruiterFieldLabel,
      helperText: l10n.recruiterFieldHint,
      controller: _controller,
      maxLength: 64,
      textDirection: TextDirection.ltr,
      status: status,
      errorText: widget.showError && !_check.ok ? l10n.recruiterFixError : null,
      onChanged: _changed,
    );
  }
}

class _Badge extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.textStyles;
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [KabsoTeamColors.start, KabsoTeamColors.end],
          ),
          borderRadius: BorderRadius.circular(KRadius.pill),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
