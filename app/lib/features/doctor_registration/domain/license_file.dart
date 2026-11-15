import 'dart:typed_data';

/// The photo of the syndicate card or the license (A4 step 2): one JPEG,
/// PNG, WebP or PDF of at most [maxBytes]. The API reads the type from the
/// file's first bytes, so the app checks the same way before uploading.
class LicenseFile {
  const LicenseFile({required this.bytes, required this.name, required this.contentType});

  /// The API's limit (`DoctorRegistrationController.LicenseMaxBytes`).
  static const maxBytes = 10 * 1024 * 1024;

  static const jpeg = 'image/jpeg';
  static const png = 'image/png';
  static const webp = 'image/webp';
  static const pdf = 'application/pdf';

  final Uint8List bytes;
  final String name;
  final String contentType;

  int get size => bytes.length;
  bool get isImage => isImageType(contentType);
  bool get isPdf => contentType == pdf;

  static bool isImageType(String? contentType) => contentType == jpeg || contentType == png || contentType == webp;

  /// The accepted type whose signature [bytes] start with, or null. Same
  /// signatures as the API's `FileTypes.Detect`.
  static String? detectType(Uint8List bytes) {
    bool startsWith(List<int> signature, [int offset = 0]) {
      if (bytes.length < offset + signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[offset + i] != signature[i]) return false;
      }
      return true;
    }

    if (startsWith(const [0xFF, 0xD8, 0xFF])) return jpeg;
    if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return png;
    if (startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8)) return webp;
    if (startsWith('%PDF-'.codeUnits)) return pdf;
    return null;
  }
}

/// Why a picked file can't be used. [code] is the API's field code, so the
/// same ARB message shows whether the app or the server caught it.
class LicenseFileException implements Exception {
  const LicenseFileException(this.code);

  static const tooLarge = 'FILE_TOO_LARGE';
  static const typeNotAllowed = 'FILE_TYPE_NOT_ALLOWED';
  static const contentInvalid = 'FILE_CONTENT_INVALID';

  /// The camera or file dialog failed to open (permission refused, no camera).
  static const pickFailed = 'PICK_FAILED';

  final String code;

  @override
  String toString() => 'LicenseFileException($code)';
}
