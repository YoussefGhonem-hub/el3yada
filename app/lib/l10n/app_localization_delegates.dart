import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

import 'gen/app_localizations.dart';

/// The app's localization delegates. Use this instead of the generated
/// `AppLocalizations.localizationsDelegates`.
///
/// Since Flutter 3.47, Material and Cupertino live in the `material_ui` and
/// `cupertino_ui` packages, and their widgets look up those packages'
/// localizations. Flutter 3.50's gen-l10n template still lists the old
/// `flutter_localizations` delegates, so with it Arabic gets no Material
/// localizations (dialogs, date pickers, tooltips) and the app shows the
/// "locale is not supported" error.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];
