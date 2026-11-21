import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/admin/data/license_opener.dart';
import 'package:el3yada/features/admin/domain/admin_models.dart';
import 'package:el3yada/features/admin/presentation/signups/license_viewer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/admin_support.dart';
import '../support/app_overrides.dart';

/// Remembers what the system viewer was asked to open.
class _RecordingOpener implements LicenseOpener {
  final opened = <String>[];

  @override
  Future<bool> open(LicenseFile file, {required String name}) async {
    opened.add(name);
    return true;
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// Signs in as the dev admin and opens AD3 for the doctor whose license is
/// a PDF (منى حسن الشريف in the offline data).
Future<_RecordingOpener> _openMona(WidgetTester tester, {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opener = _RecordingOpener();
  await tester.pumpWidget(
    ProviderScope(
      overrides: await appOverrides(
        platform: size.width >= 1024 ? AppPlatform.desktop : AppPlatform.mobile,
        extra: [
          fakeAdminOverride(),
          licenseOpenerProvider.overrideWithValue(opener),
          // Drawing PDF pages needs the platform's renderer.
          licensePdfViewProvider.overrideWithValue((pdf, name) => Center(child: Text('PDF ${pdf.length} bytes · $name'))),
        ],
      ),
      child: const El3yadaApp(),
    ),
  );
  await _settle(tester);
  await tester.enterText(find.byType(TextFormField).at(0), 'admin@el3yada.dev');
  await tester.enterText(find.byType(TextFormField).at(1), 'dev');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await _settle(tester);
  goTo(tester, '/admin/signups/doc-mona');
  await _settle(tester);
  return opener;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  testWidgets('phone: a PDF license opens in the app, full screen, and closes', (tester) async {
    final opener = await _openMona(tester, size: const Size(400, 860));
    expect(find.text('Syndicate card (PDF)'), findsOneWidget);
    expect(find.text('Open in another app'), findsNothing, reason: 'phones have no system viewer for it');

    await _tap(tester, find.widgetWithText(FilledButton, 'Open'));
    expect(find.byType(LicensePdfViewer), findsOneWidget);
    expect(find.text('Syndicate card of Dr. منى حسن الشريف'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^PDF \d+ bytes')), findsOneWidget);
    expect(opener.opened, isEmpty);

    await tester.tap(find.byTooltip('Close'));
    await _settle(tester);
    expect(find.byType(LicensePdfViewer), findsNothing);
    expect(find.text('Syndicate card (PDF)'), findsOneWidget);
  });

  testWidgets('desktop: in the app too, or in another app; Escape closes the viewer', (tester) async {
    final opener = await _openMona(tester, size: const Size(1400, 900));

    await _tap(tester, find.text('Open in another app'));
    expect(opener.opened, hasLength(1));
    expect(find.byType(LicensePdfViewer), findsNothing);

    await _tap(tester, find.widgetWithText(FilledButton, 'Open'));
    expect(find.byType(LicensePdfViewer), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);
    expect(find.byType(LicensePdfViewer), findsNothing);
  });
}
