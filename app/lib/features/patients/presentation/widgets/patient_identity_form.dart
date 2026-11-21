import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_error_text.dart';
import '../../../../core/validation/egyptian_phone.dart';
import '../../../../core/validation/validators.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../doctor_registration/domain/registration_rules.dart';
import '../../domain/patient_models.dart';
import 'clinic_ui.dart';

/// The identity fields of D5 and D7 (spec section 11): full name, gender,
/// date of birth **or** age, and the optional details (national ID,
/// address, blood type, emergency contact). Owns its controllers.
class PatientIdentityForm extends ChangeNotifier {
  PatientIdentityForm() {
    for (final controller in _controllers) {
      controller.addListener(notifyListeners);
    }
  }

  final name = TextEditingController();
  final age = TextEditingController();
  final nationalId = TextEditingController();
  final address = TextEditingController();
  final emergencyName = TextEditingController();
  final emergencyPhone = TextEditingController();

  List<TextEditingController> get _controllers => [name, age, nationalId, address, emergencyName, emergencyPhone];

  Gender? _gender;
  bool _useAge = false;
  DateTime? _dateOfBirth;
  String? _bloodType;

  /// Field errors from the API, by its field name.
  Map<String, String> serverErrors = const {};

  /// Set when the user tried to save, so the gender and date errors show.
  bool submitted = false;

  Gender? get gender => _gender;
  set gender(Gender? value) => _set(() => _gender = value, 'gender');

  /// Age in years instead of a date of birth (stored as estimated).
  bool get useAge => _useAge;
  set useAge(bool value) => _set(() => _useAge = value, value ? 'ageYears' : 'dateOfBirth');

  DateTime? get dateOfBirth => _dateOfBirth;
  set dateOfBirth(DateTime? value) => _set(() => _dateOfBirth = value, 'dateOfBirth');

  String? get bloodType => _bloodType;
  set bloodType(String? value) => _set(() => _bloodType = value, 'bloodType');

  void _set(VoidCallback change, String field) {
    change();
    clearServerError(field);
    notifyListeners();
  }

  void clearServerError(String field) {
    if (serverErrors.containsKey(field)) serverErrors = {...serverErrors}..remove(field);
  }

  /// Starts from a saved patient (D7).
  void fill(PatientView patient) {
    name.text = patient.fullName;
    _gender = patient.gender;
    _useAge = patient.dateOfBirthEstimated;
    _dateOfBirth = patient.dateOfBirthEstimated ? null : patient.dateOfBirth;
    age.text = patient.dateOfBirthEstimated ? '${patient.ageYears}' : '';
    nationalId.text = patient.nationalId ?? '';
    address.text = patient.address ?? '';
    _bloodType = patient.bloodType;
    emergencyName.text = patient.emergencyContactName ?? '';
    emergencyPhone.text = patient.emergencyContactPhone ?? '';
    notifyListeners();
  }

  /// Everything typed, to tell whether the form changed (D7's guard).
  String get signature => [
        name.text.trim(),
        _gender?.name,
        _useAge ? 'age:${age.text.trim()}' : 'dob:${_dateOfBirth?.toIso8601String()}',
        nationalId.text.trim(),
        address.text.trim(),
        _bloodType,
        emergencyName.text.trim(),
        emergencyPhone.text.trim(),
      ].join('|');

  /// The API body. Call after the form validated.
  PatientDraft draft({String? phone}) {
    String? text(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    final id = text(nationalId);
    final emergency = text(emergencyPhone);
    return PatientDraft(
      phone: phone,
      fullName: RegistrationRules.collapseSpaces(name.text),
      gender: _gender!,
      dateOfBirth: _useAge ? null : _dateOfBirth,
      ageYears: _useAge ? int.tryParse(Validators.normalizeDigits(age.text.trim())) : null,
      nationalId: id == null ? null : Validators.normalizeDigits(id).replaceAll(' ', ''),
      address: text(address),
      bloodType: _bloodType,
      emergencyContactName: text(emergencyName),
      emergencyContactPhone: emergency == null ? null : EgyptianPhone.normalize(emergency) ?? emergency,
    );
  }

  /// Whether gender and the date / age are filled and valid (the text
  /// fields check themselves through the [Form]).
  bool get choicesValid => _gender != null && (_useAge ? true : _dateOfBirth != null);

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// Spec section 11 checks, with the ARB messages.
abstract final class PatientFieldRules {
  static String? fullName(AppLocalizations l10n, String value) {
    if (value.trim().isEmpty) return l10n.errorRequired;
    if (!RegistrationRules.isFullName(value)) return l10n.patientErrorName;
    return null;
  }

  static String? mobile(AppLocalizations l10n, String value) {
    if (value.trim().isEmpty) return l10n.errorRequired;
    return Validators.normalizeEgyptianMobile(value) == null ? l10n.errorInvalidMobile : null;
  }

  static String? age(AppLocalizations l10n, String value) {
    final text = Validators.normalizeDigits(value.trim());
    if (text.isEmpty) return l10n.errorRequired;
    final years = int.tryParse(text);
    if (years == null || years < 0 || years > 120) return l10n.patientErrorAge;
    return null;
  }

  static String? nationalId(AppLocalizations l10n, String value) {
    final text = Validators.normalizeDigits(value).replaceAll(' ', '');
    if (text.isEmpty) return null;
    return RegExp(r'^\d{14}$').hasMatch(text) ? null : l10n.patientErrorNationalId;
  }

  static String? phone(AppLocalizations l10n, String value) {
    if (value.trim().isEmpty) return null;
    return EgyptianPhone.normalize(value) == null ? l10n.regErrorInvalidPhone : null;
  }

  static String? maxLength(AppLocalizations l10n, String value, int max) => value.trim().length > max ? l10n.errorTooLong : null;
}

/// The identity form's widgets. Wrap them in a [Form].
class PatientIdentityFields extends StatelessWidget {
  const PatientIdentityFields({super.key, required this.form, this.showDetails = true, this.enabled = true});

  final PatientIdentityForm form;

  /// The optional details (BR-P3: only the clinic that created the account).
  final bool showDetails;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: form,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: AppLocalizations.of(context).patientIdentity,
              icon: Icons.person_outline,
              child: _IdentityPart(form: form, enabled: enabled),
            ),
            if (showDetails) ...[
              const SizedBox(height: 16),
              _DetailsPart(form: form, enabled: enabled),
            ],
          ],
        ),
      );
}

class _IdentityPart extends StatelessWidget {
  const _IdentityPart({required this.form, required this.enabled});

  final PatientIdentityForm form;
  final bool enabled;

  Future<void> _pickDate(BuildContext context) async {
    final today = ClinicFormat.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: form.dateOfBirth ?? DateTime.utc(today.year - 30, today.month, today.day),
      firstDate: DateTime.utc(today.year - 120, today.month, today.day),
      lastDate: today,
      initialEntryMode: DatePickerEntryMode.calendar,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) form.dateOfBirth = DateTime.utc(picked.year, picked.month, picked.day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final errors = form.serverErrors;
    String? server(String field) => l10n.fieldError(errors[field]) ?? (errors[field] == null ? null : l10n.errorUnknown);
    final genderError = server('gender') ?? (form.submitted && form.gender == null ? l10n.errorRequired : null);
    final dateError = server('dateOfBirth') ?? (form.submitted && !form.useAge && form.dateOfBirth == null ? l10n.errorRequired : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: form.name,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: InputDecoration(labelText: l10n.patientFullName, helperText: l10n.patientFullNameHint),
          forceErrorText: server('fullName'),
          onChanged: (_) => form.clearServerError('fullName'),
          validator: (value) => PatientFieldRules.fullName(l10n, value ?? ''),
        ),
        const SizedBox(height: 16),
        Text(l10n.patientGender, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<Gender>(
          segments: [
            ButtonSegment(value: Gender.male, label: Text(l10n.patientGenderMale), icon: const Icon(Icons.male)),
            ButtonSegment(value: Gender.female, label: Text(l10n.patientGenderFemale), icon: const Icon(Icons.female)),
          ],
          selected: {?form.gender},
          emptySelectionAllowed: true,
          onSelectionChanged: enabled ? (value) => form.gender = value.firstOrNull : null,
        ),
        _ErrorLine(error: genderError),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Text(l10n.patientDateOfBirth, style: theme.textTheme.labelLarge)),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(value: false, label: Text(l10n.patientUseDate)),
                ButtonSegment(value: true, label: Text(l10n.patientUseAge)),
              ],
              selected: {form.useAge},
              onSelectionChanged: enabled ? (value) => form.useAge = value.first : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SmoothSize(
          child: form.useAge
              ? TextFormField(
                  key: const ValueKey('age'),
                  controller: form.age,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩]')), LengthLimitingTextInputFormatter(3)],
                  decoration: InputDecoration(labelText: l10n.patientAgeLabel, suffixText: l10n.patientYearsSuffix),
                  forceErrorText: server('ageYears'),
                  onChanged: (_) => form.clearServerError('ageYears'),
                  validator: (value) => PatientFieldRules.age(l10n, value ?? ''),
                )
              : InkWell(
                  key: const ValueKey('date'),
                  borderRadius: BorderRadius.circular(14),
                  onTap: enabled ? () => _pickDate(context) : null,
                  child: InputDecorator(
                    isEmpty: form.dateOfBirth == null,
                    decoration: InputDecoration(
                      labelText: l10n.patientDateOfBirthLabel,
                      suffixIcon: const Icon(Icons.calendar_month_outlined),
                      errorText: dateError,
                      enabled: enabled,
                    ),
                    child: Text(
                      form.dateOfBirth == null ? '' : ClinicFormat.day(context, form.dateOfBirth!),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _DetailsPart extends StatelessWidget {
  const _DetailsPart({required this.form, required this.enabled});

  final PatientIdentityForm form;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final errors = form.serverErrors;
    String? server(String field) => l10n.fieldError(errors[field]) ?? (errors[field] == null ? null : l10n.errorUnknown);
    return SectionCard(
      title: l10n.patientMoreDetails,
      subtitle: l10n.patientOptional,
      icon: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: form.nationalId,
            enabled: enabled,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩ ]')), LengthLimitingTextInputFormatter(17)],
            decoration: InputDecoration(labelText: l10n.patientNationalId, helperText: l10n.patientNationalIdHint),
            forceErrorText: server('nationalId'),
            onChanged: (_) => form.clearServerError('nationalId'),
            validator: (value) => PatientFieldRules.nationalId(l10n, value ?? ''),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: form.address,
            enabled: enabled,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(labelText: l10n.patientAddress),
            forceErrorText: server('address'),
            onChanged: (_) => form.clearServerError('address'),
            validator: (value) => PatientFieldRules.maxLength(l10n, value ?? '', 300),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: form.bloodType,
            decoration: InputDecoration(labelText: l10n.patientBloodType, errorText: server('bloodType')),
            items: [
              DropdownMenuItem(value: null, child: Text(l10n.patientNotSet)),
              for (final type in bloodTypes)
                DropdownMenuItem(value: type, child: Text(type, textDirection: TextDirection.ltr)),
            ],
            onChanged: enabled ? (value) => form.bloodType = value : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: form.emergencyName,
            enabled: enabled,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.patientEmergencyName),
            forceErrorText: server('emergencyContactName'),
            onChanged: (_) => form.clearServerError('emergencyContactName'),
            validator: (value) => PatientFieldRules.maxLength(l10n, value ?? '', 60),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: form.emergencyPhone,
            enabled: enabled,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: l10n.patientEmergencyPhone),
            forceErrorText: server('emergencyContactPhone'),
            onChanged: (_) => form.clearServerError('emergencyContactPhone'),
            validator: (value) => PatientFieldRules.phone(l10n, value ?? ''),
          ),
        ],
      ),
    );
  }
}

/// An error under a non-text field, read out when it appears.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) => SmoothSize(
        child: error == null
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ),
      );
}
