import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../records/data/file_prep.dart' show FilePrep;
import '../domain/billing_models.dart';

/// Picks the transfer screenshots for D20 (1 to 3 images). Behind an interface
/// so tests choose files without the system dialog.
abstract interface class ScreenshotPicker {
  /// Up to [max] images from the gallery or the file system; empty when cancelled.
  Future<List<ScreenshotFile>> pick({required int max});
}

class FilePickerScreenshotPicker implements ScreenshotPicker {
  const FilePickerScreenshotPicker();

  @override
  Future<List<ScreenshotFile>> pick({required int max}) async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    final out = <ScreenshotFile>[];
    for (final file in files.take(max)) {
      final bytes = await file.readAsBytes();
      // Smaller uploads on a slow connection, and no EXIF or GPS in the file.
      final small = await Isolate.run(() => FilePrep.compressImage(bytes));
      out.add(
        ScreenshotFile(
          name: small == null ? file.name : _jpgName(file.name),
          bytes: small ?? bytes,
        ),
      );
    }
    return out;
  }
}

String _jpgName(String name) {
  final dot = name.lastIndexOf('.');
  return '${dot < 0 ? name : name.substring(0, dot)}.jpg';
}

final screenshotPickerProvider = Provider<ScreenshotPicker>(
  (ref) => const FilePickerScreenshotPicker(),
);
