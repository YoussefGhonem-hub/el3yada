import 'dart:async';

import 'package:el3yada/core/theme/motion.dart';

/// Runs before every test file. Endless decorative loops (the brand
/// backdrop, the logo's heartbeat) would keep `pumpAndSettle` from ever
/// settling, so tests turn them off. Everything else animates as in the app.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Motion.ambientLoops = false;
  await testMain();
}
