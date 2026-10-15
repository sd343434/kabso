import 'package:flutter/widgets.dart';
import 'package:kabso_live/l10n/gen/app_localizations.dart';

export 'package:kabso_live/l10n/gen/app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
