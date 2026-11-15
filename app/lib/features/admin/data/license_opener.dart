import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/admin_models.dart';

/// Opens a license file that the app can't show itself (a PDF) in the
/// system's viewer: the file goes to a private temporary folder, then the
/// system opens it. Tests override [licenseOpenerProvider].
///
/// Works on Windows and macOS (where admins mostly work). Android and iOS
/// can't open a `file:` link from another app without a file provider, so
/// [open] returns false there and the screen says so.
abstract interface class LicenseOpener {
  /// True when the system viewer opened the file.
  Future<bool> open(LicenseFile file, {required String name});
}

final licenseOpenerProvider = Provider<LicenseOpener>((ref) => const SystemLicenseOpener());

class SystemLicenseOpener implements LicenseOpener {
  const SystemLicenseOpener();

  @override
  Future<bool> open(LicenseFile file, {required String name}) async {
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return false;
    final extension = file.isPdf ? 'pdf' : file.contentType.split('/').last;
    final folder = await Directory.systemTemp.createTemp('el3yada_license_');
    // Letters of any language and digits; anything else (slashes, dots) becomes _.
    final safeName = name.replaceAll(RegExp(r'[^\p{L}\p{N}\-]+', unicode: true), '_');
    final target = File('${folder.path}${Platform.pathSeparator}$safeName.$extension');
    await target.writeAsBytes(file.bytes, flush: true);
    return launchUrl(Uri.file(target.path));
  }
}
