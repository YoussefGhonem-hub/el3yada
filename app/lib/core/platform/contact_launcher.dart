import 'package:url_launcher/url_launcher.dart';

/// Opens the dialler, WhatsApp or the maps app. Returns false when nothing could open it.
abstract final class ContactLauncher {
  static Future<bool> call(String phone) => _open(Uri(scheme: 'tel', path: phone));

  /// WhatsApp wants the number without "+" (`https://wa.me/2010…`).
  static Future<bool> whatsApp(String phone) =>
      _open(Uri.https('wa.me', '/${phone.replaceAll(RegExp(r'[^0-9]'), '')}'));

  /// [query] is "lat,lng" or an address.
  static Future<bool> maps(String query) =>
      _open(Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query}));

  static Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
