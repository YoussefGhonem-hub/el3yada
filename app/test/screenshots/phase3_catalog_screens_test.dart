import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/catalog/application/admin_catalog_providers.dart';
import 'package:el3yada/features/catalog/application/catalog_providers.dart';
import 'package:el3yada/features/catalog/data/admin_catalog_repository.dart';
import 'package:el3yada/features/catalog/data/catalog_files.dart';
import 'package:el3yada/features/catalog/data/fake_catalog_backend.dart';
import 'package:el3yada/features/catalog/data/sample_catalog.dart';
import 'package:el3yada/features/catalog/domain/catalog_models.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_overrides.dart';
import '../support/catalog_support.dart';
import 'capture.dart';

/// Phase 3 catalog screens (D0, AD19, AD20, the sources screen) in Arabic,
/// light and dark, at phone and desktop width. See capture.dart.
void main() {
  setUpAll(() async {
    if (screenshotsEnabled) await loadRealFonts();
  });
  tearDownAll(deleteTestCatalogs);

  const phone = Size(390, 844);
  const desktop = Size(1366, 860);

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    Future<void> signedIn(
      WidgetTester tester,
      Size size,
      String identifier, {
      CatalogController Function()? controller,
      CatalogFilePicker? picker,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: await appOverrides(
            prefs: {'settings.locale': 'ar', 'settings.themeMode': theme},
            platform: size.width > 900
                ? AppPlatform.desktop
                : AppPlatform.mobile,
            extra: [
              fakeAdminOverride(),
              ...catalogOverrides(
                backend: FakeCatalogBackend(
                  delay: Duration.zero,
                  chunkDelay: Duration.zero,
                ),
                controller: controller,
              ),
              if (picker != null)
                catalogFilePickerProvider.overrideWithValue(picker),
            ],
          ),
          child: RepaintBoundary(key: screenshotKey, child: const El3yadaApp()),
        ),
      );
      await settle(tester);
      await tester.enterText(find.byType(TextFormField).at(0), identifier);
      await tester.enterText(find.byType(TextFormField).at(1), 'dev');
      await tester.tap(find.byType(FilledButton).first);
      await settle(tester);
    }

    Future<void> open(WidgetTester tester, String path) async {
      goTo(tester, path);
      await settle(tester);
    }

    testWidgets(
      'D0 downloading, failed and ready (phone, $theme)',
      skip: !screenshotsEnabled,
      (tester) async {
        final controller = FixedCatalogController();
        await signedIn(
          tester,
          phone,
          'doctor@el3yada.dev',
          controller: () => controller,
        );
        const target = CatalogVersionInfo(
          version: 1,
          schemaVersion: 1,
          sha256: '',
          sizeBytes: 7242557,
        );
        controller.set(
          const CatalogState(
            phase: CatalogPhase.downloading,
            target: target,
            received: 3100000,
            total: 7242557,
          ),
        );
        await settle(tester);
        await capture(tester, 'd0_downloading_phone_ar_$theme');
        controller.set(
          const CatalogState(
            phase: CatalogPhase.failed,
            target: target,
            failure: CatalogFailure.network,
          ),
        );
        await settle(tester);
        await capture(tester, 'd0_failed_phone_ar_$theme');
        controller.set(
          const CatalogState(phase: CatalogPhase.ready, installed: target),
        );
        await settle(tester);
        await capture(tester, 'd0_ready_phone_ar_$theme');
      },
    );

    for (final (width, size) in [('phone', phone), ('desktop', desktop)]) {
      testWidgets('AD20 catalogs ($width, $theme)', skip: !screenshotsEnabled, (
        tester,
      ) async {
        await signedIn(tester, size, 'admin@el3yada.dev');
        await open(tester, '/admin/catalogs');
        await capture(tester, 'ad20_versions_${width}_ar_$theme');
        await _tapVisible(tester, find.text('عناصر مضافة'));
        await settle(tester);
        await capture(tester, 'ad20_custom_${width}_ar_$theme');
        await _tapVisible(tester, find.text('بلاغات الأطباء'));
        await settle(tester);
        await capture(tester, 'ad20_reports_${width}_ar_$theme');
      });

      testWidgets(
        'AD19 specialty profiles ($width, $theme)',
        skip: !screenshotsEnabled,
        (tester) async {
          await signedIn(tester, size, 'admin@el3yada.dev');
          await open(tester, '/admin/specialties');
          await capture(tester, 'ad19_list_${width}_ar_$theme');
          await open(tester, '/admin/specialties/sp-cardio');
          await capture(tester, 'ad19_editor_${width}_ar_$theme');
          final preview = find.widgetWithText(
            TextField,
            'جرّب: ator أو omep أو بنادول',
          );
          await tester.ensureVisible(preview);
          await tester.enterText(preview, 'ator');
          await tester.pump(const Duration(milliseconds: 200));
          await settle(tester);
          await tester.ensureVisible(find.text('معاينة البحث'));
          await settle(tester);
          await capture(tester, 'ad19_preview_${width}_ar_$theme');
        },
      );
    }

    testWidgets(
      'AD20 publish with a count drop (desktop, $theme)',
      skip: !screenshotsEnabled,
      (tester) async {
        final path = writeTestCatalog(
          catalog: SampleCatalog(
            catalogVersion: 2,
            drugs: sampleDrugs.take(10).toList(),
          ),
          name: 'publish.sqlite',
        );
        final gz = Uint8List.fromList(
          gzip.encode(File(path).readAsBytesSync()),
        );
        final picker = _Picker([
          PickedCatalogFile(
            name: 'catalog-v2.sqlite.gz',
            sizeBytes: gz.length,
            bytes: gz,
          ),
          PickedCatalogFile(
            name: 'catalog-v2.json',
            sizeBytes: 80,
            bytes: Uint8List.fromList(
              '{"sha256": "${crypto.sha256.convert(gz)}"}'.codeUnits,
            ),
          ),
        ]);
        await signedIn(tester, desktop, 'admin@el3yada.dev', picker: picker);
        await open(tester, '/admin/catalogs');
        await tester.tap(find.text('نشر إصدار جديد').first);
        await settle(tester);
        await tester.tap(find.text('اختيار الملف'));
        await settle(tester);
        await capture(tester, 'ad20_publish_checked_desktop_ar_$theme');
        await tester.tap(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('نشر إصدار جديد'),
          ),
        );
        await settle(tester);
        await capture(tester, 'ad20_publish_drop_desktop_ar_$theme');
      },
    );

    testWidgets(
      'About: data sources and licences (phone, $theme)',
      skip: !screenshotsEnabled,
      (tester) async {
        await signedIn(tester, phone, 'doctor@el3yada.dev');
        await open(tester, '/legal/sources');
        await capture(tester, 'about_sources_phone_ar_$theme');
      },
    );
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

class _Picker implements CatalogFilePicker {
  _Picker(this.files);

  final List<PickedCatalogFile> files;

  @override
  Future<List<PickedCatalogFile>> pickCatalog() async => files;

  @override
  Future<PickedCatalogFile?> pickManifest() async => null;

  @override
  Future<String?> readSibling(PickedCatalogFile file, String name) async =>
      null;

  @override
  Future<String> readText(PickedCatalogFile file) async =>
      String.fromCharCodes(file.bytes ?? const []);
}
