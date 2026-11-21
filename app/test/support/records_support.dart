import 'dart:typed_data';

import 'package:el3yada/features/auth/data/auth_repository.dart';
import 'package:el3yada/features/clinic/data/clinic_repository.dart';
import 'package:el3yada/features/clinic/domain/clinic_context.dart';
import 'package:el3yada/features/patients/data/fake_clinic_records.dart';
import 'package:el3yada/features/records/data/fake_records_repository.dart';
import 'package:el3yada/features/records/data/file_actions.dart';
import 'package:el3yada/features/records/data/file_prep.dart';
import 'package:el3yada/features/records/data/file_sources.dart';
import 'package:el3yada/features/records/domain/record_models.dart';
import 'package:file_selector/file_selector.dart' show XFile;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'admin_support.dart' show appContainer;

/// Picker, camera, gallery and scanner results the test sets up.
class FakeFileSources implements FileSources {
  List<UploadSource> files = const [];
  UploadSource? photo;
  List<UploadSource> photos = const [];
  List<List<Uint8List>?> scans = [];
  int scanCalls = 0;

  @override
  Future<List<UploadSource>> pickFiles() async => files;

  @override
  Future<UploadSource?> camera() async => photo;

  @override
  Future<List<UploadSource>> gallery() async => photos;

  @override
  Future<List<Uint8List>?> scan() async {
    scanCalls++;
    return scans.isEmpty ? null : scans.removeAt(0);
  }

  @override
  Future<List<UploadSource>> fromXFiles(List<XFile> files) async => [
    for (final file in files)
      UploadSource(
        name: file.name,
        bytes: await file.readAsBytes(),
        sizeBytes: await file.length(),
      ),
  ];
}

/// No isolates and no system PDF renderer in widget tests: files go up as
/// they are, and a scan becomes a small stand-in PDF.
class PassThroughUploadPrep extends UploadPrep {
  const PassThroughUploadPrep();

  @override
  Future<UploadSource> prepare(UploadSource file) async => file;

  @override
  Future<ScanPdf> scanPdf(List<Uint8List> pages) async => ScanPdf(
    pdf: Uint8List.fromList('%PDF-1.4 scan of ${pages.length} pages'.codeUnits),
    thumbnail: pages.first,
    pageCount: pages.length,
  );

  @override
  Future<Uint8List?> pdfThumbnail(Uint8List pdf) async => null;

  @override
  Stream<Uint8List> pdfPages(Uint8List pdf, {double dpi = 110}) =>
      const Stream.empty();
}

/// Records Open with, Download and Share.
class RecordingFileActions implements FileActions {
  final calls = <String>[];

  @override
  Future<bool> openWith(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) async {
    calls.add('open $fileName');
    return true;
  }

  @override
  Future<bool> save(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) async {
    calls.add('save $fileName');
    return true;
  }

  @override
  Future<void> share(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) async {
    calls.add('share $fileName');
  }
}

/// The offline medical files with no delay (or [delay]), plus the picker,
/// prep and file actions above.
List<Override> recordsOverrides({
  FakeFileSources? sources,
  RecordingFileActions? actions,
  Duration delay = Duration.zero,
  void Function(FakeRecordsRepository repository)? configure,
}) => [
  fakeRecordsRepositoryProvider.overrideWith((ref) {
    final repository = FakeRecordsRepository(
      caller: () => fakeCallerOf(ref),
      clinic: ref.watch(fakeClinicRecordsProvider),
      delay: delay,
    );
    configure?.call(repository);
    return repository;
  }),
  uploadPrepProvider.overrideWithValue(const PassThroughUploadPrep()),
  fileSourcesProvider.overrideWithValue(sources ?? FakeFileSources()),
  fileActionsProvider.overrideWithValue(actions ?? RecordingFileActions()),
];

/// The medical files behind the running app.
FakeRecordsRepository recordsRepoOf(WidgetTester tester) =>
    appContainer(tester).read(fakeRecordsRepositoryProvider);

/// The offline clinic, with [remove] taken away from the assistant's
/// permissions (an assistant without `filesManage`, AS6).
class LimitedClinicRepository implements ClinicRepository {
  LimitedClinicRepository(this.phone, {required this.remove});

  final String phone;
  final Set<String> remove;

  @override
  Future<ClinicContext> me() async {
    final session = FakeAuthRepository.accounts[phone]!.session(phone);
    final clinic = FakeClinicRepository.contextFor(session);
    return ClinicContext(
      role: clinic.role,
      doctor: clinic.doctor,
      assistant: clinic.assistant,
      permissions: clinic.permissions.difference(remove),
      branches: clinic.branches,
      defaultBranchId: clinic.defaultBranchId,
      fees: clinic.fees,
      limits: clinic.limits,
      trial: clinic.trial,
    );
  }
}

/// A small real image (a PNG).
Uint8List tinyPng({int size = 8}) =>
    img.encodePng(img.Image(width: size, height: size));
