import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kabso_live/core/countries/countries.dart';
import 'package:kabso_live/core/preferences/app_preferences.dart';
import 'package:kabso_live/design_system/design_system.dart';
import 'package:kabso_live/features/auth/presentation/country_picker.dart';
import 'package:kabso_live/features/live/application/live_rooms_provider.dart';
import 'package:kabso_live/l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';

/// D240: opens the «القريبة» country picker (a local choice; the profile
/// is not touched) and keeps the choice on this device.
Future<void> openLiveNearbyCountryPicker(
  BuildContext context,
  WidgetRef ref,
) async {
  await showLiveCountryPicker(
    context,
    selected: ref.read(liveCountryProvider),
    onChoose: ref.read(liveNearbyChoiceProvider.notifier).choose,
  );
}

/// D240 (owner: «عند الضغط على القريبة يظهر لايفات التي في نفس بلدي
/// واسفله يمكن تغيير البلد»): under the filter row while «القريبة» is
/// selected, in the live hub and the party page — «🇯🇴 الأردن ▾»; a tap
/// opens the searchable country picker. No country yet: «اختر بلداً ▾».
class LiveNearbyCountryRow extends ConsumerWidget {
  const new({super.key});

  static const rowKey = Key('liveHub.nearbyCountry');

  /// The row's height (a 36 lp line; the touch target is the whole row).
  static const double height = 36;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = context.palette;
    final arabic = ref.watch(languageControllerProvider) == AppLanguage.ar;
    final country = KCountries.byCode(ref.watch(liveCountryProvider));
    final name = country == null
        ? l10n.liveNearbyChooseCountry
        : KCountries.name(country, arabic: arabic);
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: KMetrics.topBarMaxTextScale);
    return Semantics(
      button: true,
      label: country == null
          ? l10n.liveNearbyChooseCountry
          : l10n.liveNearbyCountryRow(name),
      excludeSemantics: true,
      onTap: () => unawaited(openLiveNearbyCountryPicker(context, ref)),
      child: InkWell(
        key: rowKey,
        onTap: () => unawaited(openLiveNearbyCountryPicker(context, ref)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: KSpacing.lg,
              vertical: KSpacing.xxs,
            ),
            child: Row(
              children: [
                if (country != null) ...[
                  Text(
                    KCountries.flag(country.code),
                    textScaler: scaler,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: KSpacing.xs),
                ] else ...[
                  Icon(Icons.place_outlined, size: 18, color: p.textSecondary),
                  const SizedBox(width: KSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textScaler: scaler,
                    style: context.textStyles.body.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: KSpacing.xxs),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: p.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
