import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/status_layout.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../startup.dart';

/// A13: maintenance mode is on (AD13). Shows the admin's message and a Retry
/// button. Signed-in admins are let through so they can turn it off, and
/// "Admin sign in" opens the login for them.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final startup = ref.watch(startupProvider);
    final languageCode = Localizations.localeOf(context).languageCode;
    final message = startup.value?.settings?.maintenanceMessage(languageCode) ?? l10n.maintenanceBody;
    final signedIn = ref.watch(authControllerProvider).value != null;

    return StatusLayout(
      icon: Icons.construction_outlined,
      tone: StatusTone.warning,
      title: l10n.maintenanceTitle,
      message: message,
      actions: [
        SubmitButton(
          label: l10n.retryButton,
          status: startup.isLoading ? SubmitStatus.loading : SubmitStatus.idle,
          onPressed: () => ref.read(startupProvider.notifier).retry(),
        ),
        if (signedIn)
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: Text(l10n.logout),
          )
        else
          TextButton(onPressed: () => context.go(AppRoutes.login), child: Text(l10n.adminSignIn)),
      ],
    );
  }
}
