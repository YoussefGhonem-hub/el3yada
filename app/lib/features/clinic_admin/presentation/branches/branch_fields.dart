import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_error_text.dart';
import '../../../../core/widgets/map_link_field.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../doctor_registration/domain/reference_lists.dart';
import '../../../doctor_registration/domain/specialty.dart' show matchesNames;
import '../../../doctor_registration/presentation/widgets/search_picker.dart';
import '../../domain/branch_models.dart';
import '../../domain/weekly_hours.dart';
import '../widgets/clinic_admin_widgets.dart';
import 'branch_drafts.dart';
import 'branch_text.dart';

/// The fields of each D29 group, shared by the tabs and the new-branch
/// form. Errors come from the API (by field path, shown at once) and from
/// the app's own check (shown after a save attempt or once the field is
/// touched).
class FieldErrors {
  const FieldErrors({this.server = const {}, this.client = const {}, this.showClient = false});

  /// Field path → API error code.
  final Map<String, String> server;
  final Map<String, BranchProblem> client;
  final bool showClient;

  String? of(AppLocalizations l10n, String path, {int? max}) {
    final code = server[path];
    if (code != null) return l10n.fieldError(code) ?? l10n.adminErrorInvalidValue;
    final problem = showClient ? client[path] : null;
    return problem == null ? null : l10n.branchProblemText(problem, max: max);
  }
}

extension BranchProblemText on AppLocalizations {
  String branchProblemText(BranchProblem problem, {int? max}) => switch (problem) {
        BranchProblem.required => errorRequired,
        BranchProblem.nameLength => regErrorBranchName,
        BranchProblem.tooLong => max == null ? errorTooLong : adminErrorMaxLength('$max'),
        BranchProblem.invalidPhone => regErrorInvalidPhone,
        BranchProblem.phoneRequired => regErrorPhoneRequired,
        BranchProblem.invalidEmail => errorInvalidEmail,
        BranchProblem.invalidMapLink => mapLinkInvalid,
      };
}

/// Info: name, English name, description.
class InfoFields extends StatelessWidget {
  const InfoFields({super.key, required this.draft, required this.errors, this.enabled = true});

  final InfoDraft draft;
  final FieldErrors errors;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('info.nameAr'),
          controller: draft.nameAr,
          enabled: enabled,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.regBranchNameLabel,
            hintText: l10n.regBranchNameHint,
            errorText: errors.of(l10n, 'info.nameAr'),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: draft.nameEn,
          enabled: enabled,
          textDirection: TextDirection.ltr,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.adminFieldBranchNameEn,
            hintText: 'Maadi',
            errorText: errors.of(l10n, 'info.nameEn', max: 60),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: draft.description,
          enabled: enabled,
          minLines: 2,
          maxLines: 5,
          maxLength: 500,
          decoration: InputDecoration(
            labelText: l10n.branchDescription,
            hintText: l10n.branchDescriptionHint,
            alignLabelWithHint: true,
            errorText: errors.of(l10n, 'info.description', max: 500),
          ),
        ),
      ],
    );
  }
}

/// Address and map: governorate, city, area, «العنوان بالتفصيل», landmark,
/// and the Google Maps link with "Open in Google Maps".
class AddressFields extends StatelessWidget {
  const AddressFields({super.key, required this.draft, required this.errors, this.enabled = true});

  final AddressDraft draft;
  final FieldErrors errors;
  final bool enabled;

  Future<void> _pickGovernorate(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final current = draft.governorate == null ? null : Governorates.find(draft.governorate!);
    final chosen = await showSearchPicker<BilingualName>(
      context: context,
      title: l10n.regGovernorateChoose,
      selected: current,
      options: [
        for (final g in Governorates.all)
          PickerOption(
            value: g,
            title: g.of(language),
            subtitle: g.of(language == 'ar' ? 'en' : 'ar'),
            matches: (query) => matchesNames(query, [g.ar, g.en]),
          ),
      ],
    );
    if (chosen != null) draft.setGovernorate(chosen.ar);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final governorate = draft.governorate;
    Widget text(String field, TextEditingController controller, String label, {IconData? icon, String? hint, bool multiline = false}) =>
        TextField(
          key: ValueKey('address.$field'),
          controller: controller,
          enabled: enabled,
          keyboardType: multiline ? TextInputType.multiline : null,
          textInputAction: multiline ? TextInputAction.newline : TextInputAction.next,
          minLines: multiline ? 2 : null,
          maxLines: multiline ? 4 : 1,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintMaxLines: 2,
            alignLabelWithHint: multiline,
            prefixIcon: icon == null ? null : Icon(icon),
            errorText: errors.of(l10n, 'address.$field', max: AddressDraft.maxLength[field]),
            errorMaxLines: 2,
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerField(
          label: l10n.regGovernorateLabel,
          placeholder: l10n.regGovernorateChoose,
          value: governorate == null ? null : (Governorates.find(governorate)?.of(language) ?? governorate),
          icon: Icons.map_outlined,
          errorText: errors.of(l10n, 'address.governorate'),
          enabled: enabled,
          onTap: () => _pickGovernorate(context),
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minColumnWidth: 220,
          children: [
            text('city', draft.city, l10n.regCityLabel, icon: Icons.location_city_outlined),
            text('area', draft.area, l10n.branchAreaLabel),
          ],
        ),
        const SizedBox(height: 16),
        text('details', draft.details, l10n.addressDetailsLabel,
            icon: Icons.signpost_outlined, hint: l10n.addressDetailsHint, multiline: true),
        const SizedBox(height: 16),
        text('landmark', draft.landmark, l10n.regLandmarkLabel, icon: Icons.place_outlined, hint: l10n.regLandmarkHint),
        const SizedBox(height: 16),
        MapLinkField(
          fieldKey: const ValueKey('address.mapUrl'),
          controller: draft.mapUrl,
          errorText: errors.of(l10n, 'address.mapUrl', max: AddressDraft.maxLength['mapUrl']),
          enabled: enabled,
        ),
      ],
    );
  }
}

/// Contact: phones with type and WhatsApp, and the email.
class ContactFields extends StatelessWidget {
  const ContactFields({super.key, required this.draft, required this.errors, this.enabled = true});

  final ContactDraft draft;
  final FieldErrors errors;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final listError = errors.of(l10n, 'contact.phones');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.regPhonesHint, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        MotionSize(
          alignment: AlignmentDirectional.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, phone) in draft.phones.indexed)
                Padding(
                  key: phone.key,
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                  child: _PhoneRow(
                    draft: draft,
                    phone: phone,
                    index: i,
                    enabled: enabled,
                    error: switch (draft.sentIndexOf(phone)) {
                      final sent? => errors.of(l10n, 'contact.phones[$sent].number'),
                      null => null,
                    },
                  ),
                ),
            ],
          ),
        ),
        if (listError != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
            child: Semantics(
              liveRegion: true,
              child: Text(listError, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ),
          ),
        if (draft.phones.length < ContactDraft.maxPhones)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(onPressed: enabled ? draft.addPhone : null, icon: const Icon(Icons.add), label: Text(l10n.regAddPhone)),
          ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('contact.email'),
          controller: draft.email,
          enabled: enabled,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: l10n.branchEmailLabel,
            prefixIcon: const Icon(Icons.alternate_email),
            errorText: errors.of(l10n, 'contact.email'),
          ),
        ),
      ],
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.draft, required this.phone, required this.index, required this.enabled, this.error});

  final ContactDraft draft;
  final PhoneDraft phone;
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
                key: ValueKey('contact.phones.$index'),
                controller: phone.number,
                enabled: enabled,
                keyboardType: TextInputType.phone,
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
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: PopupMenuButton<String>(
                      enabled: enabled,
                      tooltip: l10n.regPhoneType,
                      initialValue: phone.label,
                      onSelected: (label) => draft.setLabel(phone, label),
                      itemBuilder: (context) => [
                        for (final label in PhoneLabels.all)
                          CheckedPopupMenuItem(value: label, checked: label == phone.label, child: Text(l10n.phoneLabelName(label))),
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
                                  l10n.phoneLabelName(phone.label),
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
                  selected: phone.isWhatsapp,
                  onSelected: enabled ? (value) => draft.setWhatsapp(phone, value) : null,
                ),
                if (draft.phones.length > 1)
                  IconButton(
                    tooltip: l10n.regRemovePhone,
                    onPressed: enabled ? () => draft.removePhone(phone) : null,
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

/// Payment methods and amenities (BR-BR2).
class ChecklistFields extends StatelessWidget {
  const ChecklistFields({super.key, required this.draft, this.enabled = true});

  final ChecklistDraft draft;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: theme.textTheme.labelLarge),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label(l10n.branchPaymentMethods),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final method in BranchChecklists.paymentMethods)
              FilterChip(
                label: Text(l10n.paymentMethodName(method)),
                selected: draft.paymentMethods.contains(method),
                onSelected: enabled ? (on) => draft.togglePayment(method, on) : null,
              ),
          ],
        ),
        const SizedBox(height: 20),
        label(l10n.branchAmenities),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final amenity in BranchChecklists.amenities)
              FilterChip(
                label: Text(l10n.amenityName(amenity)),
                selected: draft.amenities.contains(amenity),
                onSelected: enabled ? (on) => draft.toggleAmenity(amenity, on) : null,
              ),
          ],
        ),
      ],
    );
  }
}

/// The weekly grid, Saturday first: several periods a day, each with its
/// times, «ends the next day», a label and (queue mode) a capacity.
/// [periodErrors] are by the period's index in [HoursDraft.ordered].
class HoursEditor extends StatelessWidget {
  const HoursEditor({
    super.key,
    required this.draft,
    required this.queueMode,
    required this.defaultCapacity,
    this.periodErrors = const {},
    this.weekError,
    this.enabled = true,
  });

  final HoursDraft draft;
  final bool queueMode;
  final int defaultCapacity;
  final Map<int, List<String>> periodErrors;
  final String? weekError;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ordered = draft.ordered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (weekError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InfoBanner(icon: Icons.error_outline, tone: PillTone.danger, message: weekError!),
          ),
        ResponsiveGrid(
          minColumnWidth: 380,
          children: [
            for (final day in WeeklyHours.weekOrder)
              _DayCard(
                weekday: day,
                draft: draft,
                queueMode: queueMode,
                defaultCapacity: defaultCapacity,
                enabled: enabled,
                errors: {for (final p in draft.ofDay(day)) p: periodErrors[ordered.indexOf(p)] ?? const []},
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.weekday,
    required this.draft,
    required this.queueMode,
    required this.defaultCapacity,
    required this.enabled,
    required this.errors,
  });

  final int weekday;
  final HoursDraft draft;
  final bool queueMode;
  final int defaultCapacity;
  final bool enabled;
  final Map<PeriodDraft, List<String>> errors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final periods = draft.ofDay(weekday);
    final name = weekdayName(context, weekday);
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(header: true, child: Text(name, style: theme.textTheme.titleMedium)),
                      if (periods.isEmpty)
                        Text(l10n.branchDayClosed, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (periods.length < WeeklyHours.maxPeriodsPerDay)
                  TextButton.icon(
                    onPressed: enabled ? () => draft.add(weekday) : null,
                    icon: const Icon(Icons.add),
                    label: Text(l10n.branchAddPeriod),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
              ],
            ),
            MotionSize(
              alignment: AlignmentDirectional.topStart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final period in periods)
                    _PeriodRow(
                      key: period.key,
                      draft: draft,
                      period: period,
                      dayName: name,
                      queueMode: queueMode,
                      defaultCapacity: defaultCapacity,
                      enabled: enabled,
                      errors: errors[period] ?? const [],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    super.key,
    required this.draft,
    required this.period,
    required this.dayName,
    required this.queueMode,
    required this.defaultCapacity,
    required this.enabled,
    required this.errors,
  });

  /// Stored in Arabic whatever the app's language: patients read them.
  static const morning = 'صباحي';
  static const evening = 'مسائي';

  final HoursDraft draft;
  final PeriodDraft period;
  final String dayName;
  final bool queueMode;
  final int defaultCapacity;
  final bool enabled;
  final List<String> errors;

  Future<void> _pick(BuildContext context, {required bool start}) async {
    final minutes = WeeklyHours.parse(start ? period.start : period.end) ?? 0;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: start ? AppLocalizations.of(context).branchPeriodFrom : AppLocalizations.of(context).branchPeriodTo,
    );
    if (picked == null) return;
    final value = WeeklyHours.format(picked.hour * 60 + picked.minute);
    if (start) {
      draft.update(period, start: value);
    } else {
      draft.update(period, end: value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasError = errors.isNotEmpty;
    final labelChoices = [
      morning,
      evening,
      if (period.label != null && period.label != morning && period.label != evening) period.label!,
    ];
    String labelName(String label) => switch (label) {
          morning => l10n.branchPeriodMorning,
          evening => l10n.branchPeriodEvening,
          _ => label,
        };
    Widget time(bool start) => OutlinedButton(
          onPressed: enabled ? () => _pick(context, start: start) : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            side: BorderSide(color: hasError && !start ? scheme.error : scheme.outline),
          ),
          child: Semantics(
            label: '${start ? l10n.branchPeriodFrom : l10n.branchPeriodTo} $dayName',
            child: Text(clockText(context, start ? period.start : period.end)),
          ),
        );
    return Container(
      margin: const EdgeInsetsDirectional.only(top: 10, end: 8),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 4, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: hasError ? Border.all(color: scheme.error) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: time(true)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ExcludeSemantics(child: Text('–', style: theme.textTheme.titleMedium)),
              ),
              Expanded(child: time(false)),
              IconButton(
                tooltip: l10n.branchRemovePeriod,
                onPressed: enabled ? () => draft.remove(period) : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: Text(l10n.branchEndsNextDay),
                selected: period.endsNextDay,
                onSelected: enabled ? (on) => draft.update(period, endsNextDay: on) : null,
                visualDensity: VisualDensity.compact,
              ),
              for (final choice in labelChoices)
                ChoiceChip(
                  label: Text(labelName(choice)),
                  selected: period.label == choice,
                  onSelected: enabled ? (on) => draft.update(period, label: () => on ? choice : null) : null,
                  visualDensity: VisualDensity.compact,
                ),
              if (queueMode)
                SizedBox(
                  width: 150,
                  child: TextField(
                    controller: period.capacity,
                    enabled: enabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩]'))],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: l10n.branchCapacity,
                      hintText: '$defaultCapacity',
                    ),
                  ),
                ),
            ],
          ),
          for (final error in errors)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 6, start: 4, end: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(error, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
              ),
            ),
        ],
      ),
    );
  }
}
