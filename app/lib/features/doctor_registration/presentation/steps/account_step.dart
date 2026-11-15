import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/password_checklist.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/registration_form.dart';
import '../widgets/form_parts.dart';
import 'step_scaffold.dart';

/// A4 step 1: full name, email, mobile, and (first registration only) the
/// password with its live checklist.
class AccountStep extends RegistrationStep {
  const AccountStep({super.key, required super.form, super.enabled, super.banner, this.onDone});

  /// The keyboard's "done" on the last field (moves to the next step).
  final VoidCallback? onDone;

  @override
  ConsumerState<AccountStep> createState() => _AccountStepState();
}

class _AccountStepState extends RegistrationStepState<AccountStep> {
  bool _obscure = true;

  @override
  List<String> get fieldOrder => const [
        RegField.fullName,
        RegField.email,
        RegField.phone,
        RegField.password,
        RegField.confirmPassword,
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resubmit = form.resubmit;
    return AutofillGroup(
      child: stepBody(
        children: [
          FormSection(
            title: l10n.regAccountSection,
            subtitle: resubmit ? null : l10n.regAccountIntro,
            children: [
              textField(
                RegField.fullName,
                form.fullName,
                label: l10n.regFullNameLabel,
                helper: l10n.regFullNameHint,
                icon: Icons.person_outline,
                keyboardType: TextInputType.name,
                autofill: const [AutofillHints.name],
                capitalization: TextCapitalization.words,
              ),
              textField(
                RegField.email,
                form.email,
                label: l10n.regEmailLabel,
                hint: 'name@example.com',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                ltr: true,
                autofill: const [AutofillHints.email],
              ),
              textField(
                RegField.phone,
                form.phone,
                label: l10n.regMobileLabel,
                hint: '01XXXXXXXXX',
                icon: Icons.phone_iphone,
                keyboardType: TextInputType.phone,
                ltr: true,
                autofill: const [AutofillHints.telephoneNumber],
                action: resubmit ? TextInputAction.done : TextInputAction.next,
                onSubmitted: resubmit ? (_) => widget.onDone?.call() : null,
              ),
            ],
          ),
          if (!resubmit)
            FormSection(
              title: l10n.regPasswordSection,
              children: [
                textField(
                  RegField.password,
                  form.password,
                  label: l10n.passwordLabel,
                  icon: Icons.lock_outline,
                  obscure: _obscure,
                  ltr: true,
                  autofill: const [AutofillHints.newPassword],
                  suffix: IconButton(
                    tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                PasswordChecklist(controller: form.password),
                textField(
                  RegField.confirmPassword,
                  form.confirmPassword,
                  label: l10n.confirmPasswordLabel,
                  icon: Icons.lock_outline,
                  obscure: _obscure,
                  ltr: true,
                  autofill: const [AutofillHints.newPassword],
                  action: TextInputAction.done,
                  onSubmitted: (_) => widget.onDone?.call(),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
