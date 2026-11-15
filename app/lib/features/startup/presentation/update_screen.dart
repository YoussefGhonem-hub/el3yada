import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/env.dart';
import '../../../core/platform/device_identity.dart';
import '../../../core/widgets/status_layout.dart';
import '../../../l10n/gen/app_localizations.dart';

/// A11: this app version is older than the minimum the admin set (AD13).
/// It can't be dismissed: the router keeps every other screen closed.
class UpdateScreen extends ConsumerWidget {
  const UpdateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final device = ref.watch(deviceIdentityProvider).value;
    final url = Env.updateUrls[device?.platform] ?? '';
    return PopScope(
      canPop: false,
      child: StatusLayout(
        icon: Icons.system_update_outlined,
        tone: StatusTone.warning,
        title: l10n.updateTitle,
        message: l10n.updateBody,
        details: [
          if (url.isEmpty) Text(l10n.updateNoLink, textAlign: TextAlign.center),
          if (device != null)
            Text(
              l10n.appVersionLabel(device.appVersion),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
        actions: [
          if (url.isNotEmpty)
            FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.updateButton),
            ),
        ],
      ),
    );
  }
}
