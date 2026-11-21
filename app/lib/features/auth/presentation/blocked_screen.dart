import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/status_layout.dart';
import '../../../core/widgets/support_contact.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/auth_controller.dart';

/// A10: sign-in refused because the account is disabled, or (BR-AS9) because
/// an assistant's clinic is not active. The user is already signed out;
/// "Log out" returns to the login form.
class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final clinic = ref.watch(authBlockProvider) == ApiCodes.clinicNotActive;
    return StatusLayout(
      icon: clinic ? Icons.store_mall_directory_outlined : Icons.block,
      tone: StatusTone.error,
      title: clinic ? l10n.clinicNotActiveTitle : l10n.accountDisabledTitle,
      message: clinic ? l10n.clinicNotActiveBody : l10n.accountDisabledBody,
      details: [if (!clinic) const SupportContact()],
      actions: [
        FilledButton.tonalIcon(
          onPressed: () => ref.read(authBlockProvider.notifier).set(null),
          icon: const Icon(Icons.logout),
          label: Text(l10n.logout),
        ),
      ],
    );
  }
}
