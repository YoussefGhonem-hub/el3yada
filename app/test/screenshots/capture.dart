import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screenshots for reviewing screens by eye, written to
/// `build/screenshots/` (git-ignored). Off by default so normal test runs
/// stay fast. Run them with:
///
/// ```
/// EL3YADA_SCREENSHOTS=1 flutter test test/screenshots
/// ```
///
/// (PowerShell: `$env:EL3YADA_SCREENSHOTS=1; flutter test test/screenshots`.)
/// Shadows draw without blur in the test renderer; on a device they're soft.
bool get screenshotsEnabled =>
    Platform.environment['EL3YADA_SCREENSHOTS'] == '1';

final screenshotKey = GlobalKey();

/// Loads the real fonts (Alexandria and Material Icons) instead of the test
/// font, which draws every letter as a box.
Future<void> loadRealFonts() async {
  final alexandria = FontLoader('Alexandria');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    alexandria.addFont(rootBundle.load('assets/fonts/Alexandria-$weight.ttf'));
  }
  await alexandria.load();

  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? _flutterRootFromPath();
  final iconFile = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (iconFile.existsSync()) {
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(iconFile.readAsBytesSync())));
    await icons.load();
  }
}

String _flutterRootFromPath() {
  // flutter_tester runs from <flutter>/bin/cache/artifacts/engine/<platform>/.
  final executable = File(
    Platform.resolvedExecutable,
  ).absolute.path.replaceAll(r'\', '/');
  final index = executable.indexOf('/bin/cache/');
  return index < 0 ? '' : executable.substring(0, index);
}

/// Writes what is inside [screenshotKey] to `build/screenshots/[name].png`.
Future<void> capture(WidgetTester tester, String name) async {
  final boundary =
      screenshotKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
  // Real async work (the engine, files) never completes in the test's fake
  // clock, so all of it runs inside runAsync, and the file is written sync.
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('build/screenshots/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}
