import 'package:kabso_live/core/countries/country_data.dart';

export 'package:kabso_live/core/countries/country_data.dart';

/// D133: lookups over [kCountries] (the person's own country, `Me
/// .country`).
abstract final class KCountries {
  static final Map<String, KCountry> _byCode = {
    for (final c in kCountries) c.code: c,
  };

  /// The country of an ISO 3166-1 alpha-2 [code] (any case), or `null`.
  static KCountry? byCode(String? code) =>
      code == null ? null : _byCode[code.toUpperCase()];

  /// [country]'s name in Arabic ([arabic]) or English.
  static String name(KCountry country, {required bool arabic}) =>
      arabic ? country.ar : country.en;

  /// The regional-indicator flag of [code] (rendered by the platform's
  /// emoji font).
  static String flag(String code) => String.fromCharCodes([
    for (final unit in code.toUpperCase().codeUnits) 0x1F1E6 + unit - 0x41,
  ]);

  /// Every country sorted by its name in the reading language, filtered by
  /// [query] (a name in either language or the code, case-insensitive).
  static List<KCountry> search(String query, {required bool arabic}) {
    final q = query.trim().toLowerCase();
    final list =
        [
          for (final c in kCountries)
            if (q.isEmpty ||
                c.en.toLowerCase().contains(q) ||
                c.ar.contains(q) ||
                c.code.toLowerCase() == q)
              c,
        ]..sort(
          (a, b) => name(a, arabic: arabic).compareTo(name(b, arabic: arabic)),
        );
    return list;
  }
}
