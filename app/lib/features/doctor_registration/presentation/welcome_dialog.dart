import 'package:flutter/material.dart';

import '../../../core/widgets/success_check.dart';
import '../../../l10n/gen/app_localizations.dart';

/// The welcome after sign-up (A4 → the doctor's home). A new doctor is
/// active at once, with a free trial (spec 6.16), so there is no review to
/// wait for. This is the sign-up's one signature moment: the success check
/// draws in, then «أهلاً بك في العيادة» and the trial's length. With
/// reduced motion the check is shown at once.
///
/// Closes on Get started; the caller then signs the doctor in, and the
/// router opens the home.
Future<void> showWelcomeDialog(BuildContext context, {int? trialDays}) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WelcomeDialog(trialDays: trialDays),
    );

class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key, this.trialDays});

  /// The days in the free trial (`trial.daysLeft` from the sign-up's
  /// session); null hides that line.
  final int? trialDays;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = trialDays;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: SuccessCheck(size: 88)),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(l10n.regWelcomeTitle, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
              ),
              if (days != null) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.regWelcomeTrial(days),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                l10n.regWelcomeBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              FilledButton(
                autofocus: true,
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.regWelcomeStart),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
