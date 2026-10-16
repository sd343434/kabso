import 'dart:async';

import 'package:clock/clock.dart';
import 'package:kabso_live/core/error/app_failure.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// Runs the `Retry-After` countdown of [failure] (RATE_LIMITED or
/// SERVICE_UNAVAILABLE) and rebuilds every second until it reaches zero.
///
/// [builder] receives the remaining time (zero when there is nothing to wait
/// for), so a screen can both show the countdown and disable its CTA. Give it
/// a new key per failed submission to restart the countdown.
class RetryCountdown extends StatefulWidget {
  const new({required this.failure, required this.builder, super.key});

  final AppFailure? failure;
  final Widget Function(BuildContext context, Duration remaining) builder;

  @override
  State<RetryCountdown> createState() => _RetryCountdownState();
}

class _RetryCountdownState extends State<RetryCountdown> {
  DateTime? _until;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(RetryCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.failure, widget.failure)) _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = null;
    _until = null;
    final failure = widget.failure;
    if (failure is ServerFailure && hasRetryCountdown(failure)) {
      _until = clock.now().add(failure.retryAfter!);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remaining() <= Duration.zero) {
          _timer?.cancel();
          _timer = null;
        }
        setState(() {});
      });
    }
  }

  Duration _remaining() {
    final until = _until;
    if (until == null) return Duration.zero;
    final left = until.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining());
}

/// Rebuilds every second until [until] (e.g. a resend cooldown), passing the
/// remaining time (zero once passed or when [until] is `null`).
class DeadlineCountdown extends StatefulWidget {
  const new({required this.until, required this.builder, super.key});

  final DateTime? until;
  final Widget Function(BuildContext context, Duration remaining) builder;

  @override
  State<DeadlineCountdown> createState() => _DeadlineCountdownState();
}

class _DeadlineCountdownState extends State<DeadlineCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(DeadlineCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.until != widget.until) _arm();
  }

  void _arm() {
    _timer?.cancel();
    _timer = null;
    if (_remaining() > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remaining() <= Duration.zero) {
          _timer?.cancel();
          _timer = null;
        }
        setState(() {});
      });
    }
  }

  Duration _remaining() {
    final until = widget.until;
    if (until == null) return Duration.zero;
    final left = until.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining());
}

/// Form-level error banner (PHASE1_SCREENS §1/§10): localized message, live
/// `Retry-After` countdown and a selectable Error ID where the spec asks for
/// one.
class FailureBanner extends StatelessWidget {
  const new({required this.failure, super.key, this.remaining});

  final AppFailure failure;

  /// Live countdown from [RetryCountdown]; `null` shows the full wait.
  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = failureErrorId(failure);
    return KInlineMessage(
      key: const Key('failure.banner'),
      message: failureMessage(l10n, failure, remaining: remaining),
      detail: id == null ? null : l10n.errorIdLabel(id),
    );
  }
}

/// Error state for [failure] with retry and Error ID: full-screen, or
/// in place with [compact].
class FailureErrorState extends StatelessWidget {
  const new({
    required this.title,
    required this.failure,
    required this.onRetry,
    super.key,
    this.compact = false,
  });

  final String title;
  final AppFailure failure;
  final VoidCallback onRetry;

  /// In-place variant inside a screen's structure (VG-03).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = failureErrorId(failure);
    return KErrorState(
      title: title,
      message: failureMessage(l10n, failure),
      retryLabel: l10n.actionRetry,
      onRetry: onRetry,
      detail: id == null ? null : l10n.errorIdLabel(id),
      compact: compact,
    );
  }
}
