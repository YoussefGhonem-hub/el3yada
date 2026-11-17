import 'dart:io';
import 'dart:typed_data';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/record_models.dart';

/// Where D10 and D11 get files from: the file picker (several at once), the
/// camera, the photos, the document scanner, and dropped files. Tests
/// override [fileSourcesProvider].
abstract interface class FileSources {
  /// The system file picker, any type (BR-F4), several files.
  Future<List<UploadSource>> pickFiles();

  /// One photo from the camera, or null when cancelled.
  Future<UploadSource?> camera();

  /// Photos from the gallery.
  Future<List<UploadSource>> gallery();

  /// D10: the native document scanner (edge detection, crop, filters, several
  /// pages). The pages' bytes, or null when cancelled. Throws [ScanException].
  Future<List<Uint8List>?> scan();

  /// Files dropped on the window (desktop).
  Future<List<UploadSource>> fromXFiles(List<XFile> files);
}

/// Why the scanner didn't open.
class ScanException implements Exception {
  const ScanException({this.denied = false});

  /// The camera permission was refused.
  final bool denied;
}

final fileSourcesProvider = Provider<FileSources>((ref) => const SystemFileSources());

class SystemFileSources implements FileSources {
  const SystemFileSources();

  @override
  Future<List<UploadSource>> pickFiles() async => fromXFiles(await openFiles());

  @override
  Future<UploadSource?> camera() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera);
    return photo == null ? null : (await fromXFiles([photo])).first;
  }

  @override
  Future<List<UploadSource>> gallery() async => fromXFiles(await ImagePicker().pickMultiImage());

  @override
  Future<List<Uint8List>?> scan() async {
    try {
      final result = await CunningDocumentScanner.scanDocuments(noOfPages: 50);
      if (result == null || result.images.isEmpty) return null;
      final pages = [for (final path in result.images) await File(path).readAsBytes()];
      await CunningDocumentScanner.cleanCache().catchError((_) {});
      return pages;
    } on CunningDocumentScannerException catch (error) {
      throw ScanException(denied: error.code == 'permission_denied');
    }
  }

  @override
  Future<List<UploadSource>> fromXFiles(List<XFile> files) async => [
        for (final file in files)
          UploadSource(
            name: file.name.isEmpty ? file.path.split(RegExp(r'[\\/]')).last : file.name,
            path: file.path,
            sizeBytes: await file.length(),
            mimeType: file.mimeType,
          ),
      ];
}
