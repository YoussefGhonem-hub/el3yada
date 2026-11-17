import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/platform/app_platform.dart';

/// What D12 does with a file's bytes outside the app: open it in another
/// app, save a copy, or share it. Tests override [fileActionsProvider].
abstract interface class FileActions {
  /// «فتح باستخدام…»: the file goes to a private temporary folder, then the
  /// system's default app for its type opens it. False when nothing could.
  Future<bool> openWith(Uint8List bytes, {required String fileName, required String mimeType});

  /// «تنزيل»: a save dialog on desktop; the share sheet on phones (where
  /// "Save to Files" lives). False when cancelled.
  Future<bool> save(Uint8List bytes, {required String fileName, required String mimeType});

  /// The share sheet (WhatsApp, email …).
  Future<void> share(Uint8List bytes, {required String fileName, required String mimeType});
}

final fileActionsProvider = Provider<FileActions>((ref) => SystemFileActions(ref.watch(appPlatformProvider)));

class SystemFileActions implements FileActions {
  const SystemFileActions(this.platform);

  final AppPlatform platform;

  @override
  Future<bool> openWith(Uint8List bytes, {required String fileName, required String mimeType}) async {
    final file = await _temporaryCopy(bytes, fileName);
    if (platform.isDesktop) return launchUrl(Uri.file(file.path));
    final result = await OpenFilex.open(file.path, type: mimeType);
    return result.type == ResultType.done;
  }

  @override
  Future<bool> save(Uint8List bytes, {required String fileName, required String mimeType}) async {
    if (!platform.isDesktop) {
      await share(bytes, fileName: fileName, mimeType: mimeType);
      return true;
    }
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null) return false;
    await File(location.path).writeAsBytes(bytes, flush: true);
    return true;
  }

  @override
  Future<void> share(Uint8List bytes, {required String fileName, required String mimeType}) =>
      SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)], fileNameOverrides: [fileName]));

  /// A copy in a fresh private folder, named after the file (letters of any
  /// language, digits, dots and dashes; anything else becomes _).
  static Future<File> _temporaryCopy(Uint8List bytes, String fileName) async {
    final base = await getTemporaryDirectory();
    final folder = await Directory('${base.path}${Platform.pathSeparator}el3yada_files').create(recursive: true);
    final unique = await folder.createTemp('f');
    final safe = fileName.replaceAll(RegExp(r'[^\p{L}\p{N}.\-]+', unicode: true), '_');
    final file = File('${unique.path}${Platform.pathSeparator}${safe.isEmpty ? 'file' : safe}');
    return file.writeAsBytes(bytes, flush: true);
  }
}
