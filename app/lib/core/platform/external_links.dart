import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] in another app (Google Maps, the browser). True when it
/// opened.
typedef ExternalLinkOpener = Future<bool> Function(Uri uri);

/// The system's opener. Tests override it to see what was opened.
final externalLinkOpenerProvider = Provider<ExternalLinkOpener>(
  (ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false),
);
