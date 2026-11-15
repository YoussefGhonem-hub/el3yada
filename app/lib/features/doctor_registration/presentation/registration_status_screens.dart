import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/widgets/status_layout.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../core/widgets/support_contact.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';

// First versions of A5, A6 and A7, enough for routing. The full screens
// (submitted data on A6, edit and resubmit on A7) replace these.

/// A6: the doctor's sign-up is waiting for the admin.
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  SubmitStatus _status = SubmitStatus.idle;

  Future<void> _refresh() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _status = SubmitStatus.loading);
    try {
      await ref.read(authControllerProvider.notifier).reloadAccount();
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.apiError(error))));
    } finally {
      if (mounted) setState(() => _status = SubmitStatus.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authControllerProvider).value;
    return StatusLayout(
      icon: Icons.hourglass_top,
      title: l10n.underConstructionTitle,
      message: session?.displayName,
      details: [
        if (session != null && !session.emailVerified)
          OutlinedButton(onPressed: () => context.push(AppRoutes.verifyEmail), child: const Text('A5')),
        const SupportContact(),
      ],
      actions: [
        SubmitButton(label: l10n.retryButton, status: _status, onPressed: _refresh),
        TextButton(onPressed: () => ref.read(authControllerProvider.notifier).logout(), child: Text(l10n.logout)),
      ],
    );
  }
}

/// A7: the admin rejected the sign-up; shows the reason.
class RegistrationRejectedScreen extends ConsumerWidget {
  const RegistrationRejectedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authControllerProvider).value;
    return StatusLayout(
      icon: Icons.report_outlined,
      tone: StatusTone.error,
      title: l10n.underConstructionTitle,
      message: session?.doctorStatusReason,
      details: const [SupportContact()],
      actions: [
        FilledButton(onPressed: () => context.go(AppRoutes.resubmit), child: Text(l10n.continueButton)),
        TextButton(onPressed: () => ref.read(authControllerProvider.notifier).logout(), child: Text(l10n.logout)),
      ],
    );
  }
}

/// A5 [S]: verify the email address.
class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(authControllerProvider).value;
    return StatusLayout(
      icon: Icons.mark_email_unread_outlined,
      title: l10n.underConstructionTitle,
      message: session?.email,
      actions: [
        FilledButton(
          onPressed: () => ref.read(authRepositoryProvider).resendVerificationEmail(),
          child: Text(l10n.forgotSubmit),
        ),
      ],
    );
  }
}

/// A4: doctor registration (4 steps). [resubmit] is A7 "Edit and resubmit".
class RegistrationScreen extends StatelessWidget {
  const RegistrationScreen({super.key, this.resubmit = false});

  final bool resubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.registerAsDoctor)),
      body: Center(child: Text(l10n.underConstructionBody('A4'))),
    );
  }
}
