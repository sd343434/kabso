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

  /// Time of day, e.g. en "10:02 AM", ar "10:02 ص" (Latin digits).
  static String time(DateTime value, String localeTag) =>
      _latin(DateFormat.jm(localeTag)).format(value.toLocal());

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

  /// Exact count with `,` grouping and Latin digits, e.g. "12,345".
  /// Used for screen-reader labels, coins and prices (never compacted).
  static String grouped(int value) {
    final digits = value.abs().toString();
    final out = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }

  /// Compact counter (DESIGN_SYSTEM §3.3): exact with grouping below 10,000;
  /// above that one decimal, **floored** (never overstated), trailing ".0"
  /// dropped, suffix from the ARB (`K`/`M`/`B`, `ألف`/`مليون`/`مليار` after a
  /// no-break space). Negative values are shown as 0.
  static String compact(int value, AppLocalizations l10n) {
    if (value < 10000) return grouped(value < 0 ? 0 : value);
    final (divisor, suffix) = switch (value) {
      >= 1000000000 => (1000000000, l10n.compactBillion),
      >= 1000000 => (1000000, l10n.compactMillion),
      _ => (1000, l10n.compactThousand),
    };
    final tenths = value * 10 ~/ divisor;
    final whole = grouped(tenths ~/ 10);
    final decimal = tenths % 10;
    return suffix(decimal == 0 ? whole : '$whole.$decimal');
  }

  /// Wraps user-generated text in first-strong isolates (U+2068 … U+2069)
  /// so a name in the other script does not reorder the sentence around it
  /// (DESIGN_SYSTEM §3.4).
  static String bidiIsolate(String value) => '\u2068$value\u2069';

  static DateFormat _latin(DateFormat format) =>
      format..useNativeDigits = false;
}
