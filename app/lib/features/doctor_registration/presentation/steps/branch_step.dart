import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/registration_form.dart';
import '../../domain/doctor_registration.dart';
import '../../domain/reference_lists.dart';
import '../../domain/registration_rules.dart';
import '../../domain/specialty.dart';
import '../registration_text.dart';
import '../widgets/form_parts.dart';
import '../widgets/search_picker.dart';
import 'step_scaffold.dart';

/// A4 step 3: the first branch (name, address, 1–5 phones) and the visit
/// prices (optional, spec 6.15). The map pin is not in the app yet.
class BranchStep extends RegistrationStep {
  const BranchStep({super.key, required super.form, super.enabled, super.banner});

  @override
  ConsumerState<BranchStep> createState() => _BranchStepState();
}

class _BranchStepState extends RegistrationStepState<BranchStep> {
  /// Digits (Western or Arabic-Indic) and one decimal separator.
  static final _amountCharacters = FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.٫,]'));

  @override
  List<String> get fieldOrder => [
        RegField.branchName,
        RegField.governorate,
        RegField.city,
        RegField.street,
        RegField.building,
        RegField.floor,
        RegField.apartment,
        RegField.landmark,
        RegField.phones,
        for (var i = 0; i < form.phones.length; i++) RegField.phoneNumber(i),
        RegField.examinationPrice,
        RegField.consultationPrice,
      ];

  Future<void> _pickGovernorate() async {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final current = form.governorate == null ? null : Governorates.find(form.governorate!);
    final chosen = await showSearchPicker<BilingualName>(
      context: context,
      title: l10n.regGovernorateChoose,
      selected: current,
      options: [
        for (final governorate in Governorates.all)
          PickerOption(
            value: governorate,
            title: governorate.of(language),
            subtitle: governorate.of(language == 'ar' ? 'en' : 'ar'),
            matches: (query) => matchesNames(query, [governorate.ar, governorate.en]),
          ),
      ],
    );
    if (chosen != null) form.setGovernorate(chosen.ar);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final governorate = form.governorate;
    const short = TextInputAction.next;

    return stepBody(
      children: [
        FormSection(
          title: l10n.regBranchSection,
          subtitle: l10n.regBranchIntro,
          children: [
            textField(
              RegField.branchName,
              form.branchName,
              label: l10n.regBranchNameLabel,
              hint: l10n.regBranchNameHint,
              icon: Icons.storefront_outlined,
            ),
            anchor(
              RegField.governorate,
              PickerField(
                label: l10n.regGovernorateLabel,
                placeholder: l10n.regGovernorateChoose,
                value: governorate == null ? null : (Governorates.find(governorate)?.of(language) ?? governorate),
                icon: Icons.map_outlined,
                errorText: errorText(RegField.governorate),
                enabled: widget.enabled,
                onTap: _pickGovernorate,
              ),
            ),
            textField(RegField.city, form.city, label: l10n.regCityLabel, icon: Icons.location_city_outlined),
            textField(
              RegField.street,
              form.street,
              label: l10n.regStreetLabel,
              icon: Icons.signpost_outlined,
              keyboardType: TextInputType.streetAddress,
              autofill: const [AutofillHints.streetAddressLine1],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: textField(RegField.building, form.building, label: l10n.regBuildingLabel, action: short)),
                const SizedBox(width: 8),
                Expanded(child: textField(RegField.floor, form.floor, label: l10n.regFloorLabel, action: short)),
                const SizedBox(width: 8),
                Expanded(child: textField(RegField.apartment, form.apartment, label: l10n.regApartmentLabel, action: short)),
              ],
            ),
            textField(
              RegField.landmark,
              form.landmark,
              label: l10n.regLandmarkLabel,
              hint: l10n.regLandmarkHint,
              icon: Icons.place_outlined,
            ),
          ],
        ),
        anchor(RegField.phones, _phones(l10n)),
        FormSection(
          title: l10n.regPricesSection,
          subtitle: l10n.regPricesHint,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, (key, controller, label)) in [
                  (RegField.examinationPrice, form.examinationPrice, l10n.regExaminationPrice),
                  (RegField.consultationPrice, form.consultationPrice, l10n.regConsultationPrice),
                ].indexed) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(
                    child: anchor(
                      key,
                      TextField(
                        controller: controller,
                        enabled: widget.enabled,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [_amountCharacters],
                        textInputAction: index == 0 ? TextInputAction.next : TextInputAction.done,
                        // Digits read left to right on their own; the field keeps the
                        // page direction so «ج.م» sits apart at the end.
                        decoration: InputDecoration(
                          labelText: label,
                          hintText: '0',
                          suffixText: l10n.regCurrency,
                          errorText: errorText(key),
                          errorMaxLines: 3,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _phones(AppLocalizations l10n) {
    final listError = errorText(RegField.phones);
    final theme = Theme.of(context);
    return FormSection(
      title: l10n.regPhonesSection,
      subtitle: l10n.regPhonesHint,
      children: [
        AnimatedSize(
          duration: Motion.normal,
          curve: Motion.standardCurve,
          alignment: AlignmentDirectional.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, entry) in form.phones.indexed)
                Padding(
                  key: entry.key,
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                  child: anchor(
                    RegField.phoneNumber(index),
                    _PhoneRow(
                      form: form,
                      entry: entry,
                      index: index,
                      enabled: widget.enabled,
                      error: errorText(RegField.phoneNumber(index)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (listError != null)
          Semantics(
            liveRegion: true,
            child: Text(listError, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
          ),
        if (form.phones.length < RegistrationRules.maxPhones)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: widget.enabled ? form.addPhone : null,
              icon: const Icon(Icons.add),
              label: Text(l10n.regAddPhone),
            ),
          ),
      ],
    );
  }
}

/// One phone: the number, its type, WhatsApp, and remove (when there are
/// two or more).
class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.form, required this.entry, required this.index, required this.enabled, this.error});

  final RegistrationForm form;
  final PhoneEntry entry;
  final int index;
  final bool enabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: TextField(
                controller: entry.number,
                enabled: enabled,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.ltr,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: l10n.regPhoneLabel(index + 1),
                  hintText: '01XXXXXXXXX',
                  hintTextDirection: TextDirection.ltr,
                  prefixIcon: const Icon(Icons.call_outlined),
                  errorText: error,
                  errorMaxLines: 3,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                // The type takes the room left over, so it never truncates on a phone.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: PopupMenuButton<String>(
                      enabled: enabled,
                      tooltip: l10n.regPhoneType,
                      initialValue: entry.label,
                      onSelected: (label) => form.setPhoneLabel(entry, label),
                      itemBuilder: (context) => [
                        for (final label in BranchPhone.labels)
                          CheckedPopupMenuItem(
                            value: label,
                            checked: label == entry.label,
                            child: Text(l10n.regPhoneLabelName(label)),
                          ),
                      ],
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.regPhoneLabelName(entry.label),
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                              Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(l10n.regPhoneWhatsapp),
                  selected: entry.isWhatsapp,
                  onSelected: enabled ? (value) => form.setPhoneWhatsapp(entry, value) : null,
                ),
                if (form.phones.length > 1)
                  IconButton(
                    tooltip: l10n.regRemovePhone,
                    onPressed: enabled ? () => form.removePhone(entry) : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
