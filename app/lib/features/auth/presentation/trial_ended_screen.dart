import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/status_layout.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../core/widgets/support_contact.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../application/auth_controller.dart';
import '../domain/user_role.dart';

/// A15: the clinic's free trial ended (spec 6.16, BR-T4). The doctor and
/// their assistants are still signed in, but every clinic screen is closed
/// until the admin activates the service or extends the trial. The screen
/// shows a message (the doctor contacts us; an assistant asks the doctor),
/// the support contacts, Check again and Log out.
///
/// Check again reloads the account. Once the trial no longer counts as
/// ended, the router leaves this screen by itself.
class TrialEndedScreen extends ConsumerStatefulWidget {
  const TrialEndedScreen({super.key});

  @override
  ConsumerState<TrialEndedScreen> createState() => _TrialEndedScreenState();
}

class _TrialEndedScreenState extends ConsumerState<TrialEndedScreen> {
  SubmitStatus _status = SubmitStatus.idle;

  Future<void> _checkAgain() async {
    if (_status != SubmitStatus.idle) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _status = SubmitStatus.loading);
    try {
      await ref.read(authControllerProvider.notifier).reloadAccount();
      final session = ref.read(authControllerProvider).value;
      if (mounted && (session?.trialEnded ?? false)) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.trialStillEnded)));
      }
    } on ApiException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.apiError(error))));
    } finally {
      if (mounted) setState(() => _status = SubmitStatus.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final assistant = ref.watch(authControllerProvider.select((auth) => auth.value?.role)) == UserRole.assistant;
    return StatusLayout(
      icon: Icons.timer_off_outlined,
      tone: StatusTone.warning,
      title: assistant ? l10n.trialEndedTitleAssistant : l10n.trialEndedTitle,
      message: assistant ? l10n.trialEndedBodyAssistant : l10n.trialEndedBody,
      // An assistant asks the doctor; the doctor is the one who contacts us.
      details: [if (!assistant) const SupportContact()],
      actions: [
        SubmitButton(label: l10n.trialCheckAgain, status: _status, onPressed: _checkAgain),
        TextButton.icon(
          onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: Text(l10n.logout),
        ),
      ],
    );
  }
}
