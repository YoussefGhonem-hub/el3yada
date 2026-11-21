import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/registration_form.dart';
import '../../application/registration_providers.dart';
import '../../domain/reference_lists.dart';
import '../../domain/registration_rules.dart';
import '../../domain/specialty.dart';
import '../widgets/form_parts.dart';
import '../widgets/license_field.dart';
import '../widgets/search_picker.dart';
import 'step_scaffold.dart';

/// A4 step 2: title, primary specialty (searchable, from the API), up to 2
/// extra specialties [S], syndicate number and the license file.
class ProfessionalStep extends RegistrationStep {
  const ProfessionalStep({super.key, required super.form, super.enabled, super.banner});

  @override
  ConsumerState<ProfessionalStep> createState() => _ProfessionalStepState();
}

class _ProfessionalStepState extends RegistrationStepState<ProfessionalStep> {
  @override
  List<String> get fieldOrder => const [
        RegField.title,
        RegField.specialty,
        RegField.extraSpecialties,
        RegField.licenseNumber,
        RegField.license,
      ];

  Future<Specialty?> _pickSpecialty(List<Specialty> all, {required bool primary}) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final other = language == 'ar' ? 'en' : 'ar';
    final taken = {
      if (!primary) form.specialty?.id,
      for (final extra in form.extraSpecialties) extra.id,
    };
    return showSearchPicker<Specialty>(
      context: context,
      title: primary ? l10n.regSpecialtyChoose : l10n.regAddSpecialty,
      selected: primary ? form.specialty : null,
      options: [
        for (final specialty in all)
          if (!taken.contains(specialty.id))
            PickerOption(
              value: specialty,
              title: specialty.name(language),
              subtitle: specialty.name(other),
              matches: specialty.matches,
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return stepBody(
      children: [
        FormSection(
          title: l10n.regProfessionalSection,
          children: [
            anchor(RegField.title, _TitlePicker(form: form, enabled: widget.enabled, error: errorText(RegField.title))),
            anchor(RegField.specialty, _specialtyField(l10n)),
            anchor(RegField.extraSpecialties, _extraSpecialties(l10n)),
          ],
        ),
        FormSection(
          title: l10n.regSyndicateSection,
          children: [
            textField(
              RegField.licenseNumber,
              form.licenseNumber,
              label: l10n.regLicenseNumberLabel,
              icon: Icons.numbers,
              ltr: true,
              keyboardType: TextInputType.visiblePassword,
              action: TextInputAction.done,
            ),
            anchor(RegField.license, LicenseField(form: form)),
          ],
        ),
      ],
    );
  }

  Widget _specialtyField(AppLocalizations l10n) {
    final language = Localizations.localeOf(context).languageCode;
    final specialties = ref.watch(specialtiesProvider);
    final failed = specialties.hasError && !specialties.hasValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerField(
          label: l10n.regSpecialtyLabel,
          placeholder: specialties.isLoading ? l10n.loading : l10n.regSpecialtyChoose,
          value: form.specialty?.name(language),
          icon: Icons.medical_services_outlined,
          helperText: l10n.regSpecialtyHint,
          errorText: failed ? l10n.regSpecialtiesError : errorText(RegField.specialty),
          enabled: widget.enabled && specialties.hasValue,
          onTap: () async {
            final chosen = await _pickSpecialty(specialties.requireValue, primary: true);
            if (chosen != null) form.setSpecialty(chosen);
          },
        ),
        if (failed)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => ref.invalidate(specialtiesProvider),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retryButton),
            ),
          ),
      ],
    );
  }

  Widget _extraSpecialties(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final specialties = ref.watch(specialtiesProvider);
    final error = errorText(RegField.extraSpecialties);
    final canAdd = widget.enabled &&
        specialties.hasValue &&
        form.specialty != null &&
        form.extraSpecialties.length < RegistrationRules.maxExtraSpecialties;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.regExtraSpecialtiesLabel, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: Motion.normal,
          curve: Motion.standardCurve,
          alignment: AlignmentDirectional.topStart,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final extra in form.extraSpecialties)
                InputChip(
                  label: Text(extra.name(language)),
                  isEnabled: widget.enabled,
                  onDeleted: () => form.removeExtraSpecialty(extra),
                  deleteButtonTooltipMessage: l10n.regRemoveSpecialty(extra.name(language)),
                ),
              if (form.extraSpecialties.length < RegistrationRules.maxExtraSpecialties)
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: Text(l10n.regAddSpecialty),
                  onPressed: canAdd
                      ? () async {
                          final chosen = await _pickSpecialty(specialties.requireValue, primary: false);
                          if (chosen != null) form.addExtraSpecialty(chosen);
                        }
                      : null,
                ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
            child: Semantics(
              liveRegion: true,
              child: Text(error, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ),
          ),
      ],
    );
  }
}

/// The title: a chip per common title and "Other" with a text field.
class _TitlePicker extends StatelessWidget {
  const _TitlePicker({required this.form, required this.enabled, this.error});

  final RegistrationForm form;
  final bool enabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.regTitleLabel, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final title in DoctorTitles.all)
              ChoiceChip(
                label: Text(title.of(language)),
                selected: form.titlePreset == title,
                onSelected: enabled ? (_) => form.selectTitle(title) : null,
              ),
            ChoiceChip(
              label: Text(l10n.regTitleOther),
              selected: form.otherTitle,
              onSelected: enabled ? (_) => form.selectOtherTitle() : null,
            ),
          ],
        ),
        AnimatedSize(
          duration: Motion.normal,
          curve: Motion.standardCurve,
          alignment: AlignmentDirectional.topStart,
          child: form.otherTitle
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                    controller: form.titleText,
                    enabled: enabled,
                    maxLength: RegistrationRules.maxTitleLength,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.regTitleOtherLabel,
                      errorText: error,
                      errorMaxLines: 2,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        if (error != null && !form.otherTitle)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
            child: Semantics(
              liveRegion: true,
              child: Text(error!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
            ),
          ),
      ],
    );
  }
}
