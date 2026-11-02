import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/error/failure_messages.dart';
import 'package:kabso_live/core/network/error_mapper.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/data/auth_repository_impl.dart';
import 'package:kabso_live/features/auth/presentation/session_controller.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D133: the person's own country (`PATCH /me {country}`), which
/// decides the live hub's Nearby. A searchable list of every ISO 3166-1
/// country with its flag and its name in the app language; the current
/// country is checked and can be removed. Saving updates the session's
/// user; a failure shows the error and keeps the sheet open. Returns
/// `true` when the country changed.
Future<bool> showCountryPicker(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const CountryPickerSheet(),
    ) ??
    false;

/// D240: the country of «القريبة» for this viewer on this device (the
/// same searchable list with flags; it never changes the profile).
/// [selected] is checked; true when a country was chosen.
Future<bool> showLiveCountryPicker(
  BuildContext context, {
  required String? selected,
  required ValueChanged<String> onChoose,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          CountryPickerSheet(selected: selected, onChoose: onChoose),
    ) ??
    false;

/// The sheet of [showCountryPicker] (public for tests and the gallery).
class CountryPickerSheet extends ConsumerStatefulWidget {
  const new({super.key, this.onChoose, this.selected});

  /// D240: a local choice ([showLiveCountryPicker]): the tap calls this and
  /// closes, nothing is saved to the profile and there is no «remove» row.
  final ValueChanged<String>? onChoose;

  /// D240: the checked country of a local choice.
  final String? selected;

  static const searchKey = Key('countryPicker.search');
  static const clearKey = Key('countryPicker.clear');
  static Key rowKey(String code) => Key('countryPicker.$code');

  @override
  ConsumerState<CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends ConsumerState<CountryPickerSheet> {
  String _query = '';

  /// The code being saved ('' while clearing); `null` when idle.
  String? _saving;

  Future<void> _save(String? code) async {
    if (_saving != null) return;
    final choose = widget.onChoose;
    if (choose != null && code != null) {
      choose(code);
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _saving = code ?? '');
    try {
      final user = await ref.read(authRepositoryProvider).updateCountry(code);
      if (!mounted) return;
      ref.read(sessionControllerProvider.notifier).updateUser(user);
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = null);
      final failure = toAppFailure(e);
      KSnack.error(context, failureMessage(context.l10n, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = context.palette;
    final t = context.textStyles;
    final arabic = ref.watch(languageControllerProvider) == AppLanguage.ar;
    final local = widget.onChoose != null;
    final profile = ref.watch(currentUserProvider.select((u) => u?.country));
    final current = local ? widget.selected : profile;
    // D240: a local choice has no «remove my country» row.
    final clearRow = !local && current != null;
    final countries = KCountries.search(_query, arabic: arabic);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KSpacing.lg,
              0,
              KSpacing.lg,
              KSpacing.xs,
            ),
            child: Semantics(
              header: true,
              child: Text(
                local ? l10n.liveCountryPickerTitle : l10n.countryPickerTitle,
                style: t.title.copyWith(color: p.textPrimary),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KSpacing.lg,
              0,
              KSpacing.lg,
              KSpacing.md,
            ),
            child: Text(
              local ? l10n.liveCountryPickerBody : l10n.countryPickerBody,
              style: t.caption.copyWith(color: p.textSecondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.lg),
            child: TextField(
              key: CountryPickerSheet.searchKey,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: l10n.countryPickerSearch,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: KSpacing.sm),
          Expanded(
            child: ListView.builder(
              itemCount: countries.length + (clearRow ? 1 : 0),
              itemBuilder: (context, i) {
                if (clearRow && i == 0) {
                  return ListTile(
                    key: CountryPickerSheet.clearKey,
                    leading: const Icon(Icons.public_off_outlined),
                    title: Text(l10n.countryPickerClear),
                    enabled: _saving == null,
                    trailing: _saving == ''
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: () => unawaited(_save(null)),
                  );
                }
                final c = countries[i - (clearRow ? 1 : 0)];
                final selected = c.code == current;
                return ListTile(
                  key: CountryPickerSheet.rowKey(c.code),
                  selected: selected,
                  enabled: _saving == null,
                  leading: ExcludeSemantics(
                    child: Text(
                      KCountries.flag(c.code),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  title: Text(KCountries.name(c, arabic: arabic)),
                  trailing: _saving == c.code
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : selected
                      ? Icon(Icons.check_rounded, color: p.primary)
                      : null,
                  onTap: selected ? null : () => unawaited(_save(c.code)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
