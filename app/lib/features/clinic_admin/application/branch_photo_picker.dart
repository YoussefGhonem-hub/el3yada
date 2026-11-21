import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../records/data/file_prep.dart' show FilePrep;

/// One picked photo, ready to upload.
typedef PickedPhoto = ({String name, Uint8List bytes});

/// Picks branch photos for D29's Info tab. Behind an interface so tests
/// choose files without the system dialog.
abstract interface class BranchPhotoPicker {
  /// Up to [max] images from the gallery or the file system; empty when cancelled.
  Future<List<PickedPhoto>> pick({required int max});
}

class FilePickerBranchPhotoPicker implements BranchPhotoPicker {
  const FilePickerBranchPhotoPicker();

  @override
  Future<List<PickedPhoto>> pick({required int max}) async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    final out = <PickedPhoto>[];
    for (final file in files.take(max)) {
      final bytes = await file.readAsBytes();
      // A smaller upload on a slow connection, and no EXIF or GPS leaves the phone. The server
      // re-encodes it anyway (at most 1600 px).
      final small = await Isolate.run(() => FilePrep.compressImage(bytes));
      out.add((name: file.name, bytes: small ?? bytes));
    }
    return out;
  }
}

final branchPhotoPickerProvider = Provider<BranchPhotoPicker>((ref) => const FilePickerBranchPhotoPicker());
