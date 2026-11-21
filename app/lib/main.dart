import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'core/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.checkFlavor();
  final prefs = await SharedPreferences.getInstance();

  // TODO(Phase 5): Firebase.initializeApp() for push (mobile) and the live
  // board mirror (section 9.6), after running `flutterfire configure`.

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const El3yadaApp(),
    ),
  );
}
