import 'package:clock/clock.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/error/failure_widgets.dart';
import 'package:kabso_live/core/format/k_format.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/live/presentation/go_live/go_live_parts.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Keys for tests.
abstract final class LiveCapacityKeys {
  static const sheet = Key('liveCapacity.sheet');
  static const retry = Key('liveCapacity.retry');
  static const close = Key('liveCapacity.close');
}

/// v1.113-live (D351, CONVENTIONS §10.148): the go-live was refused by the
/// capacity guard «حد الامتلاء» (`LIVE_CAPACITY_FULL`). Says «البث مزدحم
/// الآن، حاول بعد قليل»; «حاول مجددًا» stays disabled with a countdown until
/// the server's `Retry-After` has passed (60 s without it). The setup is kept.
///
/// True when the person tapped «حاول مجددًا» (after the wait).
Future<bool> showLiveCapacitySheet(
  BuildContext context,
  ServerFailure failure,
) async {
  final until = clock.now().add(liveCapacityWait(failure));
  final answer = await showModalBottomSheet<bool>(
    context: context,
    // Taller than the default 9/16 cap when the text is large.
    isScrollControlled: true,
    backgroundColor: const Color(0x00000000),
    builder: (sheet) => LiveCapacitySheet(
      until: until,
      onRetry: () => Navigator.of(sheet).pop(true),
      onClose: () => Navigator.of(sheet).pop(false),
    ),
  );
  return answer ?? false;
}

/// The body of [showLiveCapacitySheet] (also pumped alone by the goldens).
class LiveCapacitySheet extends StatelessWidget {
  const new({
    required this.until,
    required this.onRetry,
    required this.onClose,
    super.key,
  });

  /// When «حاول مجددًا» becomes available.
  final DateTime until;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = context.textStyles;
    return LiveSheetFrame(
      key: LiveCapacityKeys.sheet,
      title: l10n.liveCapacityTitle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
        child: DeadlineCountdown(
          until: until,
          builder: (context, remaining) {
            final waiting = remaining > Duration.zero;
            // Whole seconds, rounded up (0:01 until it is really over).
            final wait = Duration(
              seconds: (remaining.inMilliseconds / 1000).ceil(),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: _BusyIcon()),
                const SizedBox(height: KSpacing.md),
                Text(
                  l10n.errorLiveCapacityFull,
                  textAlign: TextAlign.center,
                  style: text.bodyStrong.copyWith(
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
                const SizedBox(height: KSpacing.xs),
                Text(
                  l10n.liveCapacityHint,
                  textAlign: TextAlign.center,
                  style: text.caption.copyWith(color: const Color(0xB3FFFFFF)),
                ),
                const SizedBox(height: KSpacing.lg),
                KButton(
                  key: LiveCapacityKeys.retry,
                  label: waiting
                      ? l10n.liveCapacityRetryIn(KFormat.countdown(wait))
                      : l10n.liveCapacityRetry,
                  icon: Icons.refresh_rounded,
                  onPressed: waiting ? null : onRetry,
                ),
                const SizedBox(height: KSpacing.sm),
                KButton(
                  key: LiveCapacityKeys.close,
                  label: l10n.liveCapacityClose,
                  variant: KButtonVariant.ghost,
                  onPressed: onClose,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BusyIcon extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0x33FFFFFF),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.hourglass_top_rounded,
        color: Color(0xFFFFFFFF),
        size: 28,
      ),
    ),
  );
}
