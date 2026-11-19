import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Hands a downloaded file to the system share sheet, where the user can also save it to the
/// device ("Save to Files", Downloads) or open it with another app (BR-F4 "Open with").
abstract final class FileShare {
  static Future<void> share(Uint8List bytes, {required String fileName, required String mimeType}) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
      fileNameOverrides: [fileName],
    ));
  }
}
