import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_format.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../doctor_registration/presentation/widgets/form_parts.dart';
import '../application/patients_providers.dart';
import '../clinic_paths.dart';
import '../data/patients_repository.dart';
import '../domain/patient_models.dart';
import 'patient_profile_screen.dart' show profileListLabel;
import 'widgets/clinic_ui.dart';
import 'widgets/patient_identity_form.dart';

/// D7: the patient's identity (`patientsManage`) and this clinic's medical
/// profile (`clinicalEditProfile`). The optional details show only when this
/// clinic created the account (`ownsDetails`, BR-P3). The phone changes
/// through its own confirmation (`updatePatientPhone`). Leaving with unsaved
/// changes asks first.
class EditPatientScreen extends ConsumerWidget {
  const EditPatientScreen({super.key, required this.patientId, this.medicalFirst = false});

  final String patientId;

  /// Opened from the Overview tab's "Edit medical profile".
  final bool medicalFirst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(clinicPathsProvider);
    return Scaffold(
      body: ClinicGate(
        builder: (context, clinic) {
          final identity = clinic.can(ClinicPermission.patientsManage);
          final medical = clinic.can(ClinicPermission.clinicalEditProfile);
          if (!identity && !medical) {
            return AdminErrorView(error: const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.permissionDenied));
          }
          final patient = ref.watch(patientProvider(patientId));
          final AsyncValue<MedicalProfile?> profile =
              medical ? ref.watch(medicalProfileProvider(patientId)) : const AsyncData<MedicalProfile?>(null);
          final error = patient.error ?? profile.error;
          if (error != null && (!patient.hasValue || !profile.hasValue)) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8, top: 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ClinicBackButton(fallback: paths.patient(patientId)),
                  ),
                ),
                Expanded(
                  child: AdminErrorView(
                    error: error,
                    onRetry: () {
                      ref.invalidate(patientProvider(patientId));
                      ref.invalidate(medicalProfileProvider(patientId));
                    },
                  ),
                ),
              ],
            );
          }
          if (!patient.hasValue || !profile.hasValue) {
            return const SkeletonLoading(loading: true, child: _EditSkeleton());
          }
          return _EditForm(
            patient: patient.requireValue,
            profile: profile.value,
            clinic: clinic,
            editIdentity: identity,
            editMedical: medical,
            medicalFirst: medicalFirst,
          );
        },
      ),
    );
  }
}

enum _Part { identity, medical }

/// A list item with a stable key, so reordering keeps each row's state.
class _Item {
  _Item(this.text) : key = UniqueKey();

  final Key key;
  String text;
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({
    required this.patient,
    required this.profile,
    required this.clinic,
    required this.editIdentity,
    required this.editMedical,
    required this.medicalFirst,
  });

  final PatientView patient;
  final MedicalProfile? profile;
  final ClinicContext clinic;
  final bool editIdentity;
  final bool editMedical;
  final bool medicalFirst;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _formKey = GlobalKey<FormState>();
  final _identity = PatientIdentityForm();
  late String _identitySaved;

  late final Map<ProfileList, List<_Item>> _lists;
  final _familyHistory = TextEditingController();
  final _notes = TextEditingController();
  late String _medicalSaved;

  late _Part _part;
  SubmitStatus _status = SubmitStatus.idle;
  String? _formError;
  Map<String, String> _medicalErrors = const {};

  PatientView get _patient => widget.patient;

  @override
  void initState() {
    super.initState();
    _identity.fill(_patient);
    _identitySaved = _identity.signature;
    final profile = widget.profile;
    _lists = {
      for (final list in ProfileList.values) list: [for (final item in profile?.list(list) ?? const <ProfileItem>[]) _Item(item.text)],
    };
    _familyHistory.text = profile?.familyHistory ?? '';
    _notes.text = profile?.notes ?? '';
    _medicalSaved = _medicalSignature;
    _part = widget.editMedical && (widget.medicalFirst || !widget.editIdentity) ? _Part.medical : _Part.identity;
    _identity.addListener(_changed);
    _familyHistory.addListener(_changed);
    _notes.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _identity.dispose();
    _familyHistory.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _medicalSignature => [
        for (final list in ProfileList.values) _lists[list]!.map((i) => i.text).join('\u0001'),
        _familyHistory.text.trim(),
        _notes.text.trim(),
      ].join('\u0002');

  bool get _identityDirty => widget.editIdentity && _identity.signature != _identitySaved;
  bool get _medicalDirty => widget.editMedical && _medicalSignature != _medicalSaved;
  int get _dirtyCount => (_identityDirty ? 1 : 0) + (_medicalDirty ? 1 : 0);

  Future<bool> _confirmDiscard() async {
    if (_dirtyCount == 0) return true;
    final l10n = AppLocalizations.of(context);
    return confirmAction(
      context,
      title: l10n.adminDiscardTitle,
      message: l10n.patientDiscardBody,
      confirmLabel: l10n.adminDiscard,
      destructive: true,
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_identityDirty) {
      _identity.submitted = true;
      final valid = (_formKey.currentState?.validate() ?? false) && _identity.choicesValid;
      if (!valid) {
        setState(() {
          _part = _Part.identity;
          _formError = l10n.patientCheckFields;
        });
        return;
      }
    }
    setState(() {
      _status = SubmitStatus.loading;
      _formError = null;
      _medicalErrors = const {};
    });
    final repository = ref.read(patientsRepositoryProvider);
    try {
      if (_identityDirty) {
        await repository.updatePatient(_patient.patientId, _identity.draft());
        _identitySaved = _identity.signature;
      }
      if (_medicalDirty) {
        String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
        await repository.updateMedicalProfile(
          _patient.patientId,
          MedicalProfileDraft(
            allergies: [for (final i in _lists[ProfileList.allergies]!) i.text],
            chronicDiseases: [for (final i in _lists[ProfileList.chronicDiseases]!) i.text],
            currentMedications: [for (final i in _lists[ProfileList.currentMedications]!) i.text],
            surgeries: [for (final i in _lists[ProfileList.surgeries]!) i.text],
            familyHistory: text(_familyHistory),
            notes: text(_notes),
          ),
        );
        _medicalSaved = _medicalSignature;
      }
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      patientChanged(ref, _patient.patientId);
      await Future<void>.delayed(Motion.of(context).reduced ? Duration.zero : Motion.slow);
      if (!mounted) return;
      showAdminSnack(context, l10n.patientSaved);
      await Navigator.of(context).maybePop();
    } on ApiException catch (error) {
      if (!mounted) return;
      final medicalKeys = {for (final list in ProfileList.values) list.name, 'familyHistory', 'notes'};
      final medical = <String, String>{};
      final identity = <String, String>{};
      for (final MapEntry(:key, :value) in error.fieldCodes.entries) {
        final root = key.split('[').first;
        (medicalKeys.contains(root) ? medical : identity)[root] = value;
      }
      setState(() {
        _status = SubmitStatus.idle;
        _identity.serverErrors = identity;
        _medicalErrors = medical;
        if (identity.isNotEmpty) _part = _Part.identity;
        if (identity.isEmpty && medical.isNotEmpty) _part = _Part.medical;
        _formError = identity.isNotEmpty || medical.isNotEmpty ? l10n.patientCheckFields : l10n.apiError(error);
      });
      _formKey.currentState?.validate();
    }
  }

  Future<void> _changePhone() async {
    final changed = await showDialog<PatientView>(
      context: context,
      builder: (context) => _PhoneChangeDialog(patient: _patient),
    );
    if (changed == null || !mounted) return;
    patientChanged(ref, _patient.patientId);
    showAdminSnack(context, AppLocalizations.of(context).patientPhoneChanged);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paths = ref.watch(clinicPathsProvider);
    final both = widget.editIdentity && widget.editMedical;
    final busy = _status != SubmitStatus.idle;
    var index = 0;
    Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);

    return PopScope(
      canPop: _dirtyCount == 0 && !busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || busy) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          _identitySaved = _identity.signature;
          _medicalSaved = _medicalSignature;
          setState(() {});
          navigator.pop();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = clinicGutter(constraints.maxWidth);
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          return Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: StaggerGroup(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 24),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: kRegistrationFormWidth + 80),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                enter(ClinicHeader(
                                  title: l10n.patientEditTitle,
                                  subtitle: _patient.fullName,
                                  backFallback: paths.patient(_patient.patientId),
                                )),
                                const SizedBox(height: 16),
                                if (both) ...[
                                  enter(SegmentedButton<_Part>(
                                    segments: [
                                      ButtonSegment(value: _Part.identity, label: Text(l10n.patientIdentity), icon: const Icon(Icons.person_outline)),
                                      ButtonSegment(value: _Part.medical, label: Text(l10n.patientMedicalProfile), icon: const Icon(Icons.medical_information_outlined)),
                                    ],
                                    selected: {_part},
                                    onSelectionChanged: (value) => setState(() => _part = value.first),
                                  )),
                                  const SizedBox(height: 16),
                                ],
                                enter(FormErrorBanner(message: _formError)),
                                enter(AnimatedSwitcher(
                                  duration: Motion.normal,
                                  reverseDuration: Motion.normalExit,
                                  switchInCurve: Motion.enterCurve,
                                  switchOutCurve: Motion.exitCurveReversed,
                                  layoutBuilder: (current, previous) =>
                                      Stack(alignment: AlignmentDirectional.topCenter, children: [...previous, ?current]),
                                  child: KeyedSubtree(
                                    key: ValueKey(_part),
                                    child: _part == _Part.identity ? _identityPart(context, busy) : _medicalPart(context, busy),
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                elevation: 3,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12 + bottomInset),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: kRegistrationFormWidth + 80),
                      child: Row(
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: Motion.fast,
                              child: Text(
                                _status == SubmitStatus.success
                                    ? l10n.adminAllSaved
                                    : (_dirtyCount == 0 ? l10n.patientNoChanges : l10n.patientUnsaved),
                                key: ValueKey('$_dirtyCount$_status'),
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 160,
                            child: SubmitButton(
                              label: l10n.adminSave,
                              status: _status,
                              onPressed: _dirtyCount == 0 ? null : _save,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _identityPart(BuildContext context, bool busy) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: l10n.patientMobile,
          subtitle: l10n.patientPhoneChangeHint,
          icon: Icons.phone_iphone,
          child: Row(
            children: [
              Expanded(child: LtrText(AppFormat.phone(_patient.phone), style: theme.textTheme.titleMedium)),
              OutlinedButton.icon(
                onPressed: busy ? null : _changePhone,
                icon: const Icon(Icons.swap_horiz),
                label: Text(l10n.patientChangePhone),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PatientIdentityFields(form: _identity, showDetails: _patient.ownsDetails, enabled: !busy),
        if (!_patient.ownsDetails) ...[
          const SizedBox(height: 12),
          Text(l10n.patientLinkedNote, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }

  Widget _medicalPart(BuildContext context, bool busy) {
    final l10n = AppLocalizations.of(context);
    String? error(String key) => _medicalErrors[key] == null ? null : (l10n.fieldError(_medicalErrors[key]) ?? l10n.errorUnknown);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final list in ProfileList.values) ...[
          _ListEditor(
            title: profileListLabel(l10n, list),
            items: _lists[list]!,
            allergy: list == ProfileList.allergies,
            enabled: !busy,
            error: error(list.name),
            onChanged: _changed,
          ),
          const SizedBox(height: 16),
        ],
        SectionCard(
          title: l10n.patientFamilyHistory,
          icon: Icons.family_restroom_outlined,
          child: TextFormField(
            controller: _familyHistory,
            enabled: !busy,
            minLines: 2,
            maxLines: 6,
            maxLength: 2000,
            decoration: InputDecoration(hintText: l10n.patientFamilyHistoryHint, errorText: error('familyHistory')),
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.patientGeneralNotes,
          icon: Icons.sticky_note_2_outlined,
          child: TextFormField(
            controller: _notes,
            enabled: !busy,
            minLines: 2,
            maxLines: 6,
            maxLength: 2000,
            decoration: InputDecoration(errorText: error('notes')),
          ),
        ),
      ],
    );
  }
}

/// One medical-profile list: add, remove and reorder (drag, or the screen
/// reader's move up / move down). Allergies are red (spec 6.1).
class _ListEditor extends StatefulWidget {
  const _ListEditor({
    required this.title,
    required this.items,
    required this.allergy,
    required this.enabled,
    required this.onChanged,
    this.error,
  });

  final String title;
  final List<_Item> items;
  final bool allergy;
  final bool enabled;
  final VoidCallback onChanged;
  final String? error;

  @override
  State<_ListEditor> createState() => _ListEditorState();
}

class _ListEditorState extends State<_ListEditor> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  String? _problem;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add() {
    final l10n = AppLocalizations.of(context);
    final text = _input.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return;
    if (text.length > 200) {
      setState(() => _problem = l10n.errorTooLong);
      return;
    }
    if (widget.items.length >= 50) {
      setState(() => _problem = l10n.patientListFull);
      return;
    }
    if (widget.items.any((i) => i.text.toLowerCase() == text.toLowerCase())) {
      setState(() => _problem = l10n.patientListDuplicate);
      return;
    }
    setState(() {
      widget.items.add(_Item(text));
      _input.clear();
      _problem = null;
    });
    _focus.requestFocus();
    widget.onChanged();
  }

  void _remove(_Item item) {
    setState(() => widget.items.remove(item));
    widget.onChanged();
  }

  void _move(int from, int to) {
    if (to < 0 || to >= widget.items.length) return;
    setState(() => widget.items.insert(to, widget.items.removeAt(from)));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.el3yadaColors;
    final background = widget.allergy ? colors.allergy : scheme.surfaceContainer;
    final foreground = widget.allergy ? colors.onAllergy : scheme.onSurface;
    final items = widget.items;
    return SectionCard(
      title: widget.title,
      icon: widget.allergy ? Icons.warning_amber_rounded : Icons.list_alt_outlined,
      subtitle: l10n.patientListCount(items.length),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isNotEmpty)
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorderItem: _move,
              itemBuilder: (context, i) {
                final item = items[i];
                return Padding(
                  key: item.key,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    customSemanticsActions: {
                      if (i > 0) CustomSemanticsAction(label: l10n.patientMoveUp): () => _move(i, i - 1),
                      if (i < items.length - 1) CustomSemanticsAction(label: l10n.patientMoveDown): () => _move(i, i + 1),
                    },
                    child: Material(
                      color: background,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(4, 2, 4, 2),
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: i,
                              enabled: widget.enabled,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Icon(Icons.drag_indicator, color: foreground.withValues(alpha: 0.7)),
                              ),
                            ),
                            Expanded(
                              child: Text(item.text, style: theme.textTheme.bodyLarge?.copyWith(color: foreground)),
                            ),
                            IconButton(
                              tooltip: l10n.patientRemoveItem(item.text),
                              onPressed: widget.enabled ? () => _remove(item) : null,
                              icon: Icon(Icons.close, color: foreground),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          TextField(
            controller: _input,
            focusNode: _focus,
            enabled: widget.enabled,
            textInputAction: TextInputAction.done,
            inputFormatters: [LengthLimitingTextInputFormatter(220)],
            onSubmitted: (_) => _add(),
            onChanged: (_) {
              if (_problem != null) setState(() => _problem = null);
            },
            decoration: InputDecoration(
              hintText: l10n.patientAddItemHint,
              errorText: _problem ?? widget.error,
              suffixIcon: IconButton(
                tooltip: l10n.patientAddItem,
                onPressed: widget.enabled ? _add : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The phone change, with its own confirmation (BR-P2: the number is the
/// patient's login, unique among patient accounts).
class _PhoneChangeDialog extends ConsumerStatefulWidget {
  const _PhoneChangeDialog({required this.patient});

  final PatientView patient;

  @override
  ConsumerState<_PhoneChangeDialog> createState() => _PhoneChangeDialogState();
}

class _PhoneChangeDialogState extends ConsumerState<_PhoneChangeDialog> {
  final _phone = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final problem = PatientFieldRules.mobile(l10n, _phone.text);
    final number = Validators.normalizeEgyptianMobile(_phone.text);
    if (problem != null || number == null) {
      setState(() => _error = problem ?? l10n.errorInvalidMobile);
      return;
    }
    if (number == widget.patient.phone) {
      setState(() => _error = l10n.patientPhoneSame);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await ref.read(patientsRepositoryProvider).updatePatientPhone(widget.patient.patientId, number);
      if (mounted) Navigator.pop(context, updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.fieldError(error.fieldCodes['phone']) ?? l10n.apiError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.phone_iphone),
      title: Text(l10n.patientChangePhone),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.patientChangePhoneBody(widget.patient.fullName)),
            const SizedBox(height: 16),
            TextField(
              controller: _phone,
              autofocus: true,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩+ ]')), LengthLimitingTextInputFormatter(16)],
              decoration: InputDecoration(labelText: l10n.patientNewMobile, errorText: _error),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l10n.adminCancel)),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(l10n.patientChangePhoneConfirm)),
      ],
    );
  }
}

class _EditSkeleton extends StatelessWidget {
  const _EditSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('——————————', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 20),
          for (var i = 0; i < 3; i++) ...[
            const Card(child: SizedBox(height: 140, child: Center(child: Text('——————————————')))),
            const SizedBox(height: 16),
          ],
        ],
      );
}
