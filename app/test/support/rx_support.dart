import 'dart:typed_data';

import 'package:el3yada/features/catalog/application/catalog_search_provider.dart';
import 'package:el3yada/features/catalog/domain/catalog_search.dart';
import 'package:el3yada/features/prescriptions/application/rx_printer.dart';
import 'package:el3yada/features/prescriptions/data/fake_prescriptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'admin_support.dart' show appContainer;

/// Records what would print or be shared (the platform's print dialog can't
/// run in tests).
class RecordingPrinter implements RxPrinter {
  final printed = <String>[];
  final shared = <String>[];
  final printedAll = <int>[];

  @override
  Future<bool> print(Uint8List pdf, {required String name}) async {
    printed.add(name);
    return true;
  }

  @override
  Future<bool> share(Uint8List pdf, {required String fileName}) async {
    shared.add(fileName);
    return true;
  }

  @override
  Future<bool> printAll(List<Uint8List> pdfs, {required String name}) async {
    printedAll.add(pdfs.length);
    return true;
  }
}

/// A catalog with one hit in each BR-CAT4 section, recording the searches.
class FakeCatalogSearch implements CatalogSearch {
  final calls = <({String query, bool mySpecialtyOnly})>[];

  @override
  Future<CatalogHits<DrugHit>> drugs(String query, {bool mySpecialtyOnly = false, int limit = 30}) async {
    calls.add((query: query, mySpecialtyOnly: mySpecialtyOnly));
    return CatalogHits(
      usedBefore: const [
        DrugHit(name: 'Atorstat 20', catalogId: 'drug:1', strengthHint: '20 mg', formHint: 'tablet', activeIngredient: 'atorvastatin'),
      ],
      mySpecialty: const [
        DrugHit(name: 'Lipitor 40', catalogId: 'drug:2', activeIngredient: 'atorvastatin', route: 'oral', manufacturer: 'Pfizer'),
      ],
      others: mySpecialtyOnly ? const [] : const [DrugHit(name: 'Ator 10', catalogId: 'drug:3')],
      catalogReady: true,
    );
  }

  @override
  Future<CatalogHits<TestHit>> tests(String query, {String? category, bool mySpecialtyOnly = false, int limit = 30}) async {
    calls.add((query: query, mySpecialtyOnly: mySpecialtyOnly));
    final radiology = category == 'radiology';
    return CatalogHits(
      mySpecialty: [
        radiology
            ? const TestHit(name: 'XR Chest PA', code: '36643-5', category: 'radiology', modality: 'XR', region: 'Chest')
            : const TestHit(name: 'CBC panel', code: '58410-2', category: 'lab', nameAr: 'صورة دم كاملة', aliases: ['CBC']),
      ],
      catalogReady: true,
    );
  }
}

/// The overrides of the prescription tests: printing recorded, a fake
/// catalog, and the PDF shown as its size (drawing pages needs the
/// platform's PDF renderer).
List<Override> rxOverrides({required RecordingPrinter printer, required FakeCatalogSearch search}) => [
      rxPrinterProvider.overrideWithValue(printer),
      catalogSearchProvider.overrideWithValue(search),
      rxPdfViewProvider.overrideWithValue((pdf, {maxPageWidth}) => Center(child: Text('PDF ${pdf.length} bytes'))),
    ];

/// The offline prescriptions behind the running app.
FakePrescriptions prescriptionsOf(WidgetTester tester) => appContainer(tester).read(fakePrescriptionsProvider);
