import 'package:intl/intl.dart';
import 'package:kabso_live/l10n/l10n.dart';

/// The single place that formats numbers, dates and durations for display.
///
/// DESIGN_SYSTEM §3.3: Western digits (0–9) in **both** locales. Never rely
/// on `intl` defaults for `ar`, which use Arabic-Indic digits.
abstract final class KFormat {
  /// Absolute date, e.g. en "15 Oct 2026", ar "15 أكتوبر 2026".
  static String date(DateTime value, String localeTag) =>
      _latin(DateFormat('d MMM y', localeTag)).format(value.toLocal());

  /// Countdown `m:ss` (or `h:mm:ss` from one hour), e.g. "4:05".
  static String countdown(Duration value) {
    final total = value.isNegative ? 0 : value.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }

  /// Relative time for "last active" (PHASE1_SCREENS §9.3): `null` means
  /// "just now" (under a minute); minutes, hours and days up to 7 days; the
  /// absolute [date] beyond that.
  static String? relative(
    DateTime value,
    DateTime now,
    AppLocalizations l10n,
    String localeTag,
  ) {
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return null;
    if (diff.inHours < 1) return l10n.relativeMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.relativeHoursAgo(diff.inHours);
    if (diff.inDays <= 7) return l10n.relativeDaysAgo(diff.inDays);
    return date(value, localeTag);
  }

  static DateFormat _latin(DateFormat format) =>
      format..useNativeDigits = false;
}
