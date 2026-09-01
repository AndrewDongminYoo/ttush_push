import 'package:flutter/widgets.dart';
import 'package:ttush_push/l10n/gen/app_localizations.dart';

export 'package:ttush_push/l10n/gen/app_localizations.dart';

/// The strings for [context], falling back to English outside a
/// [Localizations] scope.
///
/// [AppLocalizations.of] asserts instead, which turns a widget lifted into a
/// bare test harness into a crash rather than readable English.
AppLocalizations localizationsOf(BuildContext context) {
  return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      lookupAppLocalizations(const Locale('en'));
}
