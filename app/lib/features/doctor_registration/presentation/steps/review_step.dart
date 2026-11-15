import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/registration_form.dart';
import '../widgets/form_parts.dart';
import '../widgets/registration_summary.dart';
import 'step_scaffold.dart';

/// A4 step 4: everything entered, with "Edit" per section, and (first
/// registration only) the required Terms and Privacy checkbox. Two columns
/// on desktop.
class ReviewStep extends RegistrationStep {
  const ReviewStep({super.key, required super.form, super.enabled, super.banner, required this.onEdit});

  /// Opens step 0–2.
  final ValueChanged<int> onEdit;

  @override
  ConsumerState<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends RegistrationStepState<ReviewStep> {
  @override
  List<String> get fieldOrder => const [RegField.acceptTerms];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;

    return stepBody(
      maxWidth: wide ? 960 : kRegistrationFormWidth,
      children: [
        Text(
          form.resubmit ? l10n.regReviewIntroResubmit : l10n.regReviewIntro,
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        RegistrationSummary(
          data: SummaryData.fromForm(form, language),
          onEdit: widget.enabled ? widget.onEdit : null,
          columns: wide ? 2 : 1,
        ),
        if (!form.resubmit)
          anchor(
            RegField.acceptTerms,
            Card(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 16, 12),
                child: TermsCheckbox(
                  value: form.acceptTerms,
                  enabled: widget.enabled,
                  error: errorText(RegField.acceptTerms),
                  onChanged: form.setAcceptTerms,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
