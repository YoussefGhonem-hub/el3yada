import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/startup/startup.dart';
import '../../l10n/gen/app_localizations.dart';
import '../validation/validators.dart';

/// "Contact support" with the admin's WhatsApp, phone and email (AD13), for
/// A6, A7 and A10. Shows nothing when none is set.
class SupportContact extends ConsumerWidget {
  const SupportContact({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(publicSettingsProvider);
    if (settings == null || !settings.hasSupportContact) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final whatsapp = settings.supportWhatsapp;
    final phone = settings.supportPhone;
    final email = settings.supportEmail;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.supportTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (whatsapp != null)
                  OutlinedButton.icon(
                    onPressed: () => _open(Uri.parse('https://wa.me/${_digits(whatsapp)}')),
                    icon: const Icon(Icons.chat_outlined),
                    label: Text(l10n.supportWhatsapp),
                  ),
                if (phone != null)
                  OutlinedButton.icon(
                    onPressed: () => _open(Uri(scheme: 'tel', path: phone)),
                    icon: const Icon(Icons.call_outlined),
                    label: Text(l10n.supportCall),
                  ),
                if (email != null)
                  OutlinedButton.icon(
                    onPressed: () => _open(Uri(scheme: 'mailto', path: email)),
                    icon: const Icon(Icons.mail_outline),
                    label: Text(l10n.supportEmail),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// wa.me wants the international number without `+` or leading zeros.
  static String _digits(String number) {
    final e164 = Validators.normalizeEgyptianMobile(number);
    return (e164 ?? Validators.normalizeDigits(number)).replaceAll(RegExp('[^0-9]'), '');
  }

  static Future<void> _open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
}
