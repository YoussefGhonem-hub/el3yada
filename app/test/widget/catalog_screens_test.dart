import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:el3yada/app/app.dart';
import 'package:el3yada/core/platform/app_platform.dart';
import 'package:el3yada/features/catalog/application/admin_catalog_providers.dart';
import 'package:el3yada/features/catalog/application/catalog_providers.dart';
import 'package:el3yada/features/catalog/application/catalog_search_provider.dart';
import 'package:el3yada/features/catalog/data/admin_catalog_repository.dart';
import 'package:el3yada/features/catalog/data/catalog_files.dart';
import 'package:el3yada/features/catalog/data/fake_catalog_backend.dart';
import 'package:el3yada/features/catalog/data/history_catalog_search.dart';
import 'package:el3yada/features/catalog/data/local_catalog_search.dart';
import 'package:el3yada/features/catalog/data/sample_catalog.dart';
import 'package:el3yada/features/catalog/domain/catalog_models.dart';
import 'package:el3yada/features/catalog/domain/catalog_search.dart';
import 'package:el3yada/features/catalog/presentation/catalog_setup_screen.dart';
import 'package:el3yada/features/catalog/presentation/catalog_sources_screen.dart';
import 'package:el3yada/features/catalog/presentation/widgets/catalog_hits_view.dart';
import 'package:el3yada/features/doctor_registration/presentation/registration_text.dart'
    show ltrIsolate;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/admin_support.dart';
import '../support/app_flow.dart' show settle, signIn;
import '../support/app_overrides.dart';
import '../support/catalog_support.dart';
import '../support/clinic_records_support.dart';
import '../support/harness.dart';

const _desktop = Size(1400, 900);
const _phone = Size(400, 860);

/// D0, AD19, AD20, the sources screen and the search sections, offline.
void main() {
  tearDownAll(deleteTestCatalogs);

  Future<FakeCatalogBackend> pumpSignedIn(
    WidgetTester tester,
    String identifier, {
    Size size = _desktop,
    FakeCatalogBackend? backend,
    CatalogController Function()? controller,
    CatalogFilePicker? picker,
  }) async {
    final server =
        backend ??
        FakeCatalogBackend(delay: Duration.zero, chunkDelay: Duration.zero);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: await appOverrides(
          platform: size.width >= 1024
              ? AppPlatform.desktop
              : AppPlatform.mobile,
          extra: [
            fakeAdminOverride(),
            ...catalogOverrides(backend: server, controller: controller),
            if (picker != null)
              catalogFilePickerProvider.overrideWithValue(picker),
            fakeRecordsOverride(),
          ],
        ),
        child: const El3yadaApp(),
      ),
    );
    await settle(tester);
    await signIn(tester, identifier);
    return server;
  }

  Future<void> open(WidgetTester tester, String path) async {
    goTo(tester, path);
    await settle(tester);
  }

  group('D0 preparing the catalog', () {
    testWidgets(
      'progress, size, Wi-Fi, then Retry after a failure and Done when ready',
      (tester) async {
        final controller = FixedCatalogController();
        await pumpSignedIn(
          tester,
          'doctor@el3yada.dev',
          size: _phone,
          controller: () => controller,
        );
        const target = CatalogVersionInfo(
          version: 3,
          schemaVersion: 1,
          sha256: '',
          sizeBytes: 7242557,
          uncompressedSizeBytes: 20332544,
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
        // The first download opens D0 over the doctor's area.
        expect(find.byType(CatalogSetupScreen), findsOneWidget);
        expect(
          find.text('Getting the medicines and tests guide ready'),
          findsOneWidget,
        );
        expect(find.text('Downloading… 42%'), findsOneWidget);
        expect(find.text('Version 3 · 6.9 MB'), findsOneWidget);
        expect(find.text('Wi-Fi recommended'), findsOneWidget);
        // The download and the unpacked database side by side (spec D0).
        expect(find.text('Needs 26.3 MB of free space'), findsOneWidget);
        expect(find.text('3 MB of 6.9 MB'), findsOneWidget);

        controller.set(
          const CatalogState(
            phase: CatalogPhase.failed,
            target: target,
            failure: CatalogFailure.network,
          ),
        );
        await settle(tester);
        expect(
          find.text(
            'No internet connection. Try again picks up where it stopped.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Try again'));
        await settle(tester);
        expect(controller.retries, 1);

        controller.set(
          const CatalogState(phase: CatalogPhase.ready, installed: target),
        );
        await settle(tester);
        expect(find.text('The guide is ready on your device'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Done'));
        await settle(tester);
        expect(find.byType(CatalogSetupScreen), findsNothing);
      },
    );

    testWidgets(
      'the app stays usable: "Keep using the app" leaves the download running',
      (tester) async {
        final controller = FixedCatalogController();
        await pumpSignedIn(
          tester,
          'admin@el3yada.dev',
          controller: () => controller,
        );
        controller.set(
          const CatalogState(
            phase: CatalogPhase.downloading,
            target: CatalogVersionInfo(
              version: 1,
              schemaVersion: 1,
              sha256: '',
              sizeBytes: 1000,
            ),
            received: 100,
            total: 1000,
          ),
        );
        await settle(tester);
        expect(find.byType(CatalogSetupScreen), findsOneWidget);
        await tester.tap(find.text('Keep using the app'));
        await settle(tester);
        expect(find.byType(CatalogSetupScreen), findsNothing);
        // Once per run: more progress doesn't open it again.
        controller.set(controller.state.copyWith(received: 500));
        await settle(tester);
        expect(find.byType(CatalogSetupScreen), findsNothing);
      },
    );

    testWidgets('patients never get the catalog', (tester) async {
      await pumpSignedIn(tester, '01000000002', size: _phone);
      final container = appContainer(tester);
      expect(container.read(catalogEligibleProvider), isFalse);
      expect(
        container.read(catalogControllerProvider).phase,
        CatalogPhase.idle,
      );
    });

    testWidgets(
      'with the catalog on the device, a doctor\'s search is ready and offline',
      (tester) async {
        final backend = await pumpSignedIn(
          tester,
          'doctor@el3yada.dev',
          size: _phone,
        );
        final container = appContainer(tester);
        expect(
          container.read(catalogControllerProvider).phase,
          CatalogPhase.ready,
        );
        expect(find.byType(CatalogSetupScreen), findsNothing);
        // The doctor (Internal Medicine + General) finds omeprazole under "Your specialty".
        final search = LocalCatalogSearch(
          history: const NoHistorySearch(),
          database: () =>
              container.read(catalogControllerProvider.notifier).database,
          profile: () => container.read(myCatalogProfileProvider),
          customItems: () => container.read(customItemsProvider).values,
        );
        late CatalogHits<DrugHit> hits;
        await tester.runAsync(() async => hits = await search.drugs('omep'));
        expect(hits.catalogReady, isTrue);
        expect(hits.mySpecialty.map((h) => h.activeIngredient).toSet(), {
          'OMEPRAZOLE',
        });
        // The admin's custom item came with the sync.
        await tester.runAsync(() async => hits = await search.drugs('newcil'));
        expect(hits.mySpecialty.single.custom, isTrue);
        expect(backend.calls['customItems'], greaterThanOrEqualTo(1));
        expect(backend.calls['myProfile'], greaterThanOrEqualTo(1));
      },
    );
  });

  group('AD20 catalogs', () {
    testWidgets('the current version, this device, and every version', (
      tester,
    ) async {
      await pumpSignedIn(tester, 'admin@el3yada.dev');
      await open(tester, '/admin/catalogs');
      expect(find.text('Current version'), findsOneWidget);
      expect(find.text('v1'), findsWidgets);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('Medicines'), findsWidgets);
      // Dates and releases read left to right inside Arabic (Unicode isolates).
      expect(
        find.text(
          'Drug data of ${ltrIsolate('2026-06-20')} · LOINC ${ltrIsolate('sample')}',
        ),
        findsOneWidget,
      );
      expect(find.text('On this device'), findsOneWidget);
      expect(find.text('Version 1 · ready'), findsOneWidget);
      expect(find.text('All versions'), findsOneWidget);
    });

    testWidgets(
      'publish: local sha check, the 5% drop asks first, then version 2',
      (tester) async {
        final smaller = _gz(
          const SampleCatalog(
            catalogVersion: 2,
            drugs: [...sampleDrugs],
          ).copyWithDrugs(10),
        );
        final picker = _Picker([
          PickedCatalogFile(
            name: 'catalog-v2.sqlite.gz',
            sizeBytes: smaller.length,
            bytes: smaller,
          ),
          PickedCatalogFile(
            name: 'catalog-v2.json',
            sizeBytes: 10,
            bytes: Uint8List.fromList(
              '{"sha256": "${crypto.sha256.convert(smaller)}"}'.codeUnits,
            ),
          ),
        ]);
        final backend = await pumpSignedIn(
          tester,
          'admin@el3yada.dev',
          picker: picker,
        );
        await open(tester, '/admin/catalogs');
        await tester.tap(find.text('Publish new version').first);
        await settle(tester);
        await tester.tap(find.widgetWithText(OutlinedButton, 'Choose file'));
        await settle(tester);
        expect(
          find.text('The file matches its manifest (sha256)'),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('Publish new version'),
          ),
        );
        await settle(tester);
        expect(
          find.text('This version has far fewer items than the current one:'),
          findsOneWidget,
        );
        expect(find.text('Medicines: 24 → 10'), findsOneWidget);
        await tester.tap(find.text('Publish anyway'));
        await settle(tester);
        expect(find.text('Version 2 published'), findsOneWidget);
        expect(backend.calls['publish'], 2);
        await tester.tap(find.widgetWithText(FilledButton, 'Done'));
        await settle(tester);
        expect(find.text('v2'), findsWidgets);
      },
    );

    testWidgets('a manifest that does not match is caught before uploading', (
      tester,
    ) async {
      final file = _gz(const SampleCatalog());
      final picker = _Picker([
        PickedCatalogFile(
          name: 'catalog-v2.sqlite.gz',
          sizeBytes: file.length,
          bytes: file,
        ),
        PickedCatalogFile(
          name: 'catalog-v2.json',
          sizeBytes: 10,
          bytes: Uint8List.fromList('{"sha256": "${'a' * 64}"}'.codeUnits),
        ),
      ]);
      await pumpSignedIn(tester, 'admin@el3yada.dev', picker: picker);
      await open(tester, '/admin/catalogs');
      await tester.tap(find.text('Publish new version').first);
      await settle(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Choose file'));
      await settle(tester);
      expect(
        find.text(
          "The file doesn't match its manifest (sha256). Choose the pair the builder made together.",
        ),
        findsOneWidget,
      );
      final publish = tester.widget<ButtonStyleButton>(
        find
            .ancestor(
              of: find.descendant(
                of: find.byType(Dialog),
                matching: find.text('Publish new version'),
              ),
              matching: find.byWidgetPredicate(
                (widget) => widget is ButtonStyleButton,
              ),
            )
            .first,
      );
      expect(publish.onPressed, isNull);
    });

    testWidgets(
      'custom items: add a medicine, disable one; doctors\' sync sees both',
      (tester) async {
        final backend = await pumpSignedIn(tester, 'admin@el3yada.dev');
        await open(tester, '/admin/catalogs');
        await tapVisible(tester, find.text('Custom items'));
        await settle(tester);
        expect(find.text('NEWCILLIN 500 MG 12 CAPS.'), findsOneWidget);
        expect(find.text('Panoramic dental X-ray'), findsNothing);

        await tester.tap(find.text('Add item'));
        await settle(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Trade name'),
          'KETOFAN 50 MG 20 CAPS.',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Active ingredient'),
          'KETOPROFEN',
        );
        await tester.tap(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.widgetWithText(FilledButton, 'Save'),
          ),
        );
        await settle(tester);
        expect(find.text('KETOFAN 50 MG 20 CAPS.'), findsOneWidget);
        expect(
          backend.customItems.values.where(
            (i) => i.nameEn == 'KETOFAN 50 MG 20 CAPS.',
          ),
          hasLength(1),
        );

        await tester.tap(
          find.byTooltip('Actions for NEWCILLIN 500 MG 12 CAPS.'),
        );
        await settle(tester);
        await tester.tap(find.text('Disable'));
        await settle(tester);
        expect(
          backend.customItems.values
              .firstWhere((i) => i.nameEn.startsWith('NEWCILLIN'))
              .active,
          isFalse,
        );
        expect(find.text('NEWCILLIN 500 MG 12 CAPS.'), findsNothing);
        await tester.tap(find.text('Show disabled'));
        await settle(tester);
        expect(find.text('NEWCILLIN 500 MG 12 CAPS.'), findsOneWidget);
        // The device's own copy dropped it at the sync.
        final custom = appContainer(tester).read(customItemsProvider);
        expect(
          custom.values.map((i) => i.nameEn),
          isNot(contains('NEWCILLIN 500 MG 12 CAPS.')),
        );
        expect(
          custom.values.map((i) => i.nameEn),
          contains('KETOFAN 50 MG 20 CAPS.'),
        );
      },
    );

    testWidgets('doctor reports: open ones, marked done', (tester) async {
      final backend = await pumpSignedIn(
        tester,
        'admin@el3yada.dev',
        size: _phone,
      );
      await open(tester, '/admin/catalogs');
      await tapVisible(tester, find.text('Doctor reports'));
      await settle(tester);
      expect(find.text('مش لاقي «Ketofan 50 mg» في البحث'), findsOneWidget);
      expect(
        find.text('ياريت يبقى فيه اسم عربي لتحليل فيتامين ب12'),
        findsNothing,
      );
      await tester.tap(find.text('Mark as done').first);
      await settle(tester);
      expect(backend.reports.values.where((r) => !r.done), hasLength(1));
      expect(find.text('Marked as done'), findsOneWidget);
    });
  });

  group('AD19 specialty profiles', () {
    testWidgets('the list: General first, doctors and profile sizes', (
      tester,
    ) async {
      await pumpSignedIn(tester, 'admin@el3yada.dev');
      await open(tester, '/admin/specialties');
      expect(find.text('General'), findsOneWidget);
      expect(find.text('Added to every specialty'), findsOneWidget);
      expect(find.text('Cardiology'), findsOneWidget);
      expect(find.text('23 doctors'), findsOneWidget);
      expect(
        find.text('3 medicine groups · 3 lab tests · 5 radiology'),
        findsOneWidget,
      );
    });

    testWidgets(
      'the editor: counted groups, save, and the preview of a doctor\'s search',
      (tester) async {
        final backend = await pumpSignedIn(tester, 'admin@el3yada.dev');
        await open(tester, '/admin/specialties/sp-cardio');
        expect(find.text('Medicine groups'), findsOneWidget);
        // Product counts from the catalog on this device.
        expect(find.text('Lipid-lowering drugs · 5'), findsOneWidget);
        expect(find.text('Include the General profile'), findsOneWidget);
        // Recommended lab tests are named from the local catalog.
        expect(find.text('Cardiac troponin T - Serum'), findsOneWidget);

        await tapVisible(tester, find.text('Oral antidiabetics · 1'));
        await settle(tester);
        expect(find.text('1 change not saved'), findsOneWidget);

        // Preview: a cardiologist typing "ator" sees atorvastatin under "Your specialty".
        await tester.ensureVisible(
          find.widgetWithText(TextField, 'Try: ator, omep, panadol'),
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Try: ator, omep, panadol'),
          'ator',
        );
        await tester.pump(const Duration(milliseconds: 200));
        await settle(tester);
        final preview = find.byType(CatalogHitsView<Object>);
        expect(
          find.descendant(
            of: preview,
            matching: find.text('Your specialty · 4'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: preview,
            matching: find.text('LIPITOR 20 MG 30 F.C.TABS.'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: preview,
            matching: find.text('May not be available'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);
        expect(
          backend.profiles['sp-cardio']!.drugGroups,
          contains('antidiabetics_oral'),
        );
      },
    );

    testWidgets(
      'add a recommended lab test from the local catalog, and copy from another specialty',
      (tester) async {
        final backend = await pumpSignedIn(tester, 'admin@el3yada.dev');
        await open(tester, '/admin/specialties/sp-derma');
        await tester.ensureVisible(
          find.widgetWithText(
            TextField,
            'Search the catalog to add a lab test',
          ),
        );
        await tester.enterText(
          find.widgetWithText(
            TextField,
            'Search the catalog to add a lab test',
          ),
          'hba1c',
        );
        await tester.pump(const Duration(milliseconds: 200));
        await settle(tester);
        await tapVisible(tester, find.text('Glycated hemoglobin - Blood'));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Save'));
        await settle(tester);
        expect(backend.profiles['sp-derma']!.labCodes, contains('99003-6'));

        await tapVisible(tester, find.text('Copy from another specialty'));
        await settle(tester);
        await tester.tap(find.text('Cardiology'));
        await settle(tester);
        await tester.tap(find.widgetWithText(FilledButton, 'Copy'));
        await settle(tester);
        expect(
          backend.profiles['sp-derma']!.drugGroups,
          backend.profiles['sp-cardio']!.drugGroups,
        );
        expect(find.text('Copied from Cardiology'), findsOneWidget);
      },
    );
  });

  group('the editors\' search (D13, D14) over the local catalog', () {
    testWidgets(
      'catalogSearchProvider: history only until the catalog is open, and for patients',
      (tester) async {
        final controller = FixedCatalogController();
        await pumpSignedIn(
          tester,
          'doctor@el3yada.dev',
          size: _phone,
          controller: () => controller,
        );
        final container = appContainer(tester);
        expect(
          container.read(catalogSearchProvider),
          isA<HistoryOnlyCatalogSearch>(),
        );
        late CatalogHits<DrugHit> hits;
        await tester.runAsync(
          () async =>
              hits = await container.read(catalogSearchProvider).drugs('ator'),
        );
        expect(hits.catalogReady, isFalse);

        controller.set(
          const CatalogState(
            phase: CatalogPhase.ready,
            installed: CatalogVersionInfo(
              version: 1,
              schemaVersion: 1,
              sha256: '',
              sizeBytes: 1,
            ),
          ),
        );
        await settle(tester);
        expect(
          container.read(catalogSearchProvider),
          isA<LocalCatalogSearch>(),
        );
      },
    );

    testWidgets('patients keep the history-only search', (tester) async {
      await pumpSignedIn(tester, '01000000002', size: _phone);
      expect(
        appContainer(tester).read(catalogSearchProvider),
        isA<HistoryOnlyCatalogSearch>(),
      );
    });

    testWidgets('D13: sections from the catalog, the chip, and the N/A line', (
      tester,
    ) async {
      await pumpSignedIn(tester, 'doctor@el3yada.dev');
      final records = recordsOf(tester);
      final patient = records.patientIdByName(SeedPatients.mona);
      await open(
        tester,
        '/doctor/patients/$patient/sessions/${records.sessionIdsOf(patient).first}',
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'New prescription'),
      );
      await settle(tester);
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Add medicine'),
      );
      await settle(tester);
      await tester.enterText(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(TextField),
            )
            .first,
        'ator',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      // The offline doctor is Internal Medicine (lipid-lowering) + General.
      expect(find.text('Your specialty'), findsOneWidget);
      expect(find.text('LIPITOR 20 MG 30 F.C.TABS.'), findsOneWidget);
      expect(
        find.text('ATORVASTATIN · Oral (tablets, capsules) · Pfizer'),
        findsOneWidget,
      );
      expect(find.text('May not be available'), findsOneWidget);
      expect(
        find.text(
          'The catalog is still downloading: only your own history is searched. You can type any name.',
        ),
        findsNothing,
      );

      await tester.enterText(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(TextField),
            )
            .first,
        'aspocid',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      expect(find.text('From other specialties'), findsOneWidget);
      await tapVisible(
        tester,
        find.widgetWithText(FilterChip, 'My specialty only'),
      );
      await settle(tester);
      expect(find.text('From other specialties'), findsNothing);
      expect(find.text('ASPOCID 75 MG 30 TABS.'), findsNothing);
    });

    testWidgets('D13 before the catalog is ready: the "still downloading" line', (
      tester,
    ) async {
      await pumpSignedIn(
        tester,
        'doctor@el3yada.dev',
        controller: FixedCatalogController.new,
      );
      final records = recordsOf(tester);
      final patient = records.patientIdByName(SeedPatients.mona);
      await open(
        tester,
        '/doctor/patients/$patient/sessions/${records.sessionIdsOf(patient).first}',
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'New prescription'),
      );
      await settle(tester);
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Add medicine'),
      );
      await settle(tester);
      await tester.enterText(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(TextField),
            )
            .first,
        'ator',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      expect(
        find.text(
          'The catalog is still downloading: only your own history is searched. You can type any name.',
        ),
        findsOneWidget,
      );
      expect(find.text('LIPITOR 20 MG 30 F.C.TABS.'), findsNothing);
    });
  });

  group('search sections', () {
    testWidgets('three headed sections; N/A muted; custom tagged; no price', (
      tester,
    ) async {
      const hits = CatalogHits<DrugHit>(
        usedBefore: [
          DrugHit(name: 'PANADOL 500 MG 24 TABS.', catalogId: 'drug:1'),
        ],
        mySpecialty: [
          DrugHit(name: 'ATORLIFE 10 MG', catalogId: 'custom:c2', custom: true),
          CatalogDrugHit(
            name: 'LIPITOR 20 MG 30 F.C.TABS.',
            activeIngredient: 'ATORVASTATIN',
            route: 'ORAL.SOLID',
          ),
          CatalogDrugHit(
            name: 'ATORSTAT 40 MG 10 TABS.',
            mayBeUnavailable: true,
          ),
        ],
        others: [CatalogDrugHit(name: 'CONCOR 5 MG 30 F.C.TABS.')],
        catalogReady: true,
      );
      for (final rtl in [false, true]) {
        await pumpHarness(
          tester,
          const Scaffold(
            body: SingleChildScrollView(child: CatalogHitsView(hits: hits)),
          ),
          rtl: rtl,
        );
        await tester.pumpAndSettle();
        if (!rtl) {
          expect(find.text('Used before · 1'), findsOneWidget);
          expect(find.text('Your specialty · 3'), findsOneWidget);
          expect(find.text('From other specialties · 1'), findsOneWidget);
          expect(find.text('May not be available'), findsOneWidget);
          expect(find.text('Added'), findsOneWidget);
          expect(
            find.text('ATORVASTATIN · Oral (tablets, capsules)'),
            findsOneWidget,
          );
        } else {
          expect(find.text('من تخصصات أخرى · 1'), findsOneWidget);
          expect(find.text('قد لا يكون متوفرًا'), findsOneWidget);
        }
      }
    });
  });

  testWidgets(
    'BR-CAT14: the sources screen has the exact LOINC notice and the credits',
    (tester) async {
      await pumpHarness(
        tester,
        const ProviderScope(child: CatalogSourcesScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text(CatalogNotices.loinc), findsOneWidget);
      await tester.ensureVisible(find.text(CatalogNotices.radlex));
      expect(find.text(CatalogNotices.radlex), findsOneWidget);
      expect(find.text(CatalogNotices.drugs), findsOneWidget);
      expect(
        CatalogNotices.loinc,
        'This material contains content from LOINC (http://loinc.org). LOINC is copyright © Regenstrief Institute, '
        'Inc. and the Logical Observation Identifiers Names and Codes (LOINC) Committee and is available at no cost '
        'under the license at http://loinc.org/license. LOINC® is a registered United States trademark of '
        'Regenstrief Institute, Inc.',
      );
    },
  );

  testWidgets('Settings has the catalog and the sources (D24)', (tester) async {
    await pumpSignedIn(tester, 'doctor@el3yada.dev', size: _phone);
    await open(tester, '/doctor/settings');
    await tester.ensureVisible(find.text('Data sources and licences'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
    await settle(tester);
    expect(find.text('Medicines and tests guide'), findsOneWidget);
    expect(find.text('Version 1 · ready'), findsOneWidget);
    await tapVisible(tester, find.text('Data sources and licences'));
    await settle(tester);
    expect(find.byType(CatalogSourcesScreen), findsOneWidget);
  });
}

/// The `.gz` of [catalog].
Uint8List _gz(SampleCatalog catalog) {
  final path = writeTestCatalog(catalog: catalog, name: 'publish.sqlite');
  return Uint8List.fromList(gzip.encode(File(path).readAsBytesSync()));
}

extension on SampleCatalog {
  SampleCatalog copyWithDrugs(int count) => SampleCatalog(
    catalogVersion: catalogVersion,
    drugs: drugs.take(count).toList(),
  );
}

class _Picker implements CatalogFilePicker {
  _Picker(this.files);

  final List<PickedCatalogFile> files;

  @override
  Future<List<PickedCatalogFile>> pickCatalog() async => files;

  @override
  Future<PickedCatalogFile?> pickManifest() async =>
      files.where((f) => f.name.endsWith('.json')).firstOrNull;

  @override
  Future<String?> readSibling(PickedCatalogFile file, String name) async =>
      null;

  @override
  Future<String> readText(PickedCatalogFile file) async =>
      String.fromCharCodes(file.bytes ?? const []);
}

/// Scrolls [finder] into view (tabs, long editors), then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}
