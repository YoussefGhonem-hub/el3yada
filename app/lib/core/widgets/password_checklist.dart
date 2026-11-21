import 'package:material_ui/material_ui.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/motion.dart';
import '../validation/validators.dart';

/// The live password checklist (A4, A9, change password): ≥ 8 characters, a
/// letter, a number. Each row ticks as soon as the rule is met.
///
/// Pass the password field's controller; the list rebuilds as the user types.
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.passwordRulesTitle, style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            _Rule(label: l10n.passwordRuleLength, met: PasswordRules.hasLength(text)),
            _Rule(label: l10n.passwordRuleLetter, met: PasswordRules.hasLetter(text)),
            _Rule(label: l10n.passwordRuleNumber, met: PasswordRules.hasNumber(text)),
          ],
        );
      },
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.label, required this.met});

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final motion = Motion.of(context);
    return Semantics(
      label: met ? l10n.passwordRuleMet(label) : l10n.passwordRuleNotMet(label),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: motion.reduced ? Duration.zero : Motion.fast,
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Icon(
                met ? Icons.check_circle : Icons.radio_button_unchecked,
                key: ValueKey(met),
                size: 18,
                color: met ? scheme.primary : scheme.outline,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: met ? scheme.onSurface : scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
