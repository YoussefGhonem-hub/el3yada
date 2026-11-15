import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/license_file.dart';

/// Where the license comes from. Phones offer all three; desktops only
/// [files] (no camera, and the file dialog shows images too).
enum LicenseSource { camera, gallery, files }

/// A file the user chose, before it is read: [size] comes first so a file
/// over the limit is refused without loading it.
class PickedLicense {
  const PickedLicense({required this.name, required this.size, required this.read});

  final String name;

  /// Null when the platform can't tell without reading the file.
  final int? size;
  final Future<Uint8List> Function() read;
}

/// Opens the camera, the gallery or the file dialog. Overridden in tests.
abstract interface class LicensePicker {
  /// Null when the user cancelled. Throws [LicenseFileException] with
  /// `PICK_FAILED` when the camera or dialog could not open.
  Future<PickedLicense?> pick(LicenseSource source);
}

/// `image_picker` for the camera and gallery, `file_selector` for files.
///
/// Photos are scaled to 2000 px on the long edge and saved as JPEG quality
/// 80 (spec section 12, "Scanned images compressed"), which keeps a phone
/// photo well under the 10 MB limit.
class DeviceLicensePicker implements LicensePicker {
  const DeviceLicensePicker();

  static const _types = XTypeGroup(
    label: 'JPEG, PNG, WebP, PDF',
    extensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    mimeTypes: [LicenseFile.jpeg, LicenseFile.png, LicenseFile.webp, LicenseFile.pdf],
    uniformTypeIdentifiers: ['public.jpeg', 'public.png', 'org.webmproject.webp', 'com.adobe.pdf'],
  );

  @override
  Future<PickedLicense?> pick(LicenseSource source) async {
    try {
      final XFile? file = switch (source) {
        LicenseSource.camera || LicenseSource.gallery => await ImagePicker().pickImage(
            source: source == LicenseSource.camera ? ImageSource.camera : ImageSource.gallery,
            maxWidth: 2000,
            maxHeight: 2000,
            imageQuality: 80,
          ),
        LicenseSource.files => await openFile(acceptedTypeGroups: const [_types]),
      };
      if (file == null) return null;
      return PickedLicense(name: file.name, size: await file.length(), read: file.readAsBytes);
    } on PlatformException {
      throw const LicenseFileException(LicenseFileException.pickFailed);
    }
  }
}

final licensePickerProvider = Provider<LicensePicker>((ref) => const DeviceLicensePicker());

/// Reads [picked] and checks it the way the API will: at most 10 MB and a
/// JPEG, PNG, WebP or PDF by its first bytes. Throws [LicenseFileException].
Future<LicenseFile> loadLicense(PickedLicense picked) async {
  final size = picked.size;
  if (size != null && size > LicenseFile.maxBytes) {
    throw const LicenseFileException(LicenseFileException.tooLarge);
  }
  final Uint8List bytes;
  try {
    bytes = await picked.read();
  } catch (_) {
    throw const LicenseFileException(LicenseFileException.contentInvalid);
  }
  if (bytes.length > LicenseFile.maxBytes) throw const LicenseFileException(LicenseFileException.tooLarge);
  if (bytes.isEmpty) throw const LicenseFileException(LicenseFileException.contentInvalid);
  final type = LicenseFile.detectType(bytes);
  if (type == null) throw const LicenseFileException(LicenseFileException.typeNotAllowed);
  return LicenseFile(bytes: bytes, name: picked.name, contentType: type);
}
