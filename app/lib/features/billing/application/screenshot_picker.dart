import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      out.add(ScreenshotFile(name: file.name, bytes: await file.readAsBytes()));
    }
    return out;
  }
}

final screenshotPickerProvider = Provider<ScreenshotPicker>(
  (ref) => const FilePickerScreenshotPicker(),
);
