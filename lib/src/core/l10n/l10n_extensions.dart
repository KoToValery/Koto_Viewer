import 'package:flutter/widgets.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
  AppLocalizations? get l10nOrNull => AppLocalizations.of(this);
}

extension AxisNamingLocale on AppLocalizations {
  // Grid letters use the same alphabet as the existing axis naming engine.
  bool get usesCyrillicAxisNames => localeName.split('_').first == 'bg';
}
