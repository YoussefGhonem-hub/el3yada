import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/motion.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/shake_on_error.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../core/widgets/temporary_password_dialog.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../doctor_registration/presentation/widgets/form_parts.dart';
import '../application/patients_providers.dart';
import '../clinic_paths.dart';
import '../data/patients_repository.dart';
import '../domain/patient_models.dart';
import 'widgets/clinic_ui.dart';
import 'widgets/patient_identity_form.dart';

/// D5 / AS3: add a patient (`patientsManage`, not while suspended, BR-G5).
///
/// The mobile number comes first and is checked as it's typed
/// (`lookupPhone`): one of this clinic's patients offers their file; another
/// clinic's patient asks to link them (BR-P3, identity only); a new number
/// gets the full form and, on save, the temporary password shown once
/// (BR-P4). Then the profile (D6) opens.
class AddPatientScreen extends ConsumerWidget {
  const AddPatientScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(clinicPathsProvider);
    return Scaffold(
      body: ClinicGate(
        builder: (context, clinic) {
          if (!clinic.can(ClinicPermission.patientsManage)) {
            return AdminErrorView(error: const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.permissionDenied));
          }
          if (clinic.isSuspended) return SuspendedNotice(backFallback: paths.patients);
          return _AddPatientForm(clinic: clinic, paths: paths);
        },
      ),
    );
  }
}

enum _Lookup { idle, checking, isNew, linkedToYou, existsElsewhere, failed }

class _AddPatientForm extends ConsumerStatefulWidget {
  const _AddPatientForm({required this.clinic, required this.paths});

  final ClinicContext clinic;
  final ClinicPaths paths;

  @override
  ConsumerState<_AddPatientForm> createState() => _AddPatientFormState();
}

class _AddPatientFormState extends ConsumerState<_AddPatientForm> {
  static const _lookupDelay = Duration(milliseconds: 450);

  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _identity = PatientIdentityForm();
  Timer? _debounce;

  _Lookup _lookup = _Lookup.idle;
  PhoneLookup? _found;

  /// The number [_lookup] is about (E.164).
  String? _checked;
  int _lookupRequest = 0;

  /// The BR-P3 dialog was already shown for [_checked].
  bool _askedToLink = false;

  SubmitStatus _status = SubmitStatus.idle;
  String? _phoneError;
  String? _formError;
  int _failures = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _phone.dispose();
    _identity.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    _debounce?.cancel();
    final number = Validators.normalizeEgyptianMobile(value);
    setState(() {
      _phoneError = null;
      if (number != _checked) {
        _lookup = _Lookup.idle;
        _found = null;
        _askedToLink = false;
      }
    });
    if (number == null || number == _checked) return;
    _debounce = Timer(_lookupDelay, () => _check(number));
  }

  Future<void> _check(String number) async {
    final request = ++_lookupRequest;
    setState(() {
      _lookup = _Lookup.checking;
      _checked = number;
    });
    try {
      final found = await ref.read(patientsRepositoryProvider).lookupPhone(number);
      if (!mounted || request != _lookupRequest) return;
      setState(() {
        _found = found;
        _lookup = switch (found.status) {
          PhoneLookupStatus.isNew => _Lookup.isNew,
          PhoneLookupStatus.linkedToYou => _Lookup.linkedToYou,
          PhoneLookupStatus.existsElsewhere => _Lookup.existsElsewhere,
        };
      });
      if (found.status == PhoneLookupStatus.existsElsewhere && !_askedToLink) {
        _askedToLink = true;
        await _askToLink();
      }
    } on ApiException catch (error) {
      if (!mounted || request != _lookupRequest) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _lookup = _Lookup.failed;
        _phoneError = l10n.fieldError(error.fieldCodes['phone']);
      });
    }
  }

  /// BR-P3: explain what linking means and ask.
  Future<void> _askToLink() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.link),
        title: Text(l10n.patientLinkTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.patientLinkBody(AppFormat.phone(_checked ?? ''))),
              const SizedBox(height: 12),
              Text(l10n.patientLinkPrivacy, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.adminCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.patientLinkConfirm)),
        ],
      ),
    );
    if (confirmed == true && mounted) await _save(link: true);
  }

  void _openExisting(String patientId) => context.go(widget.paths.patient(patientId));

  Future<void> _save({bool link = false}) async {
    final l10n = AppLocalizations.of(context);
    _identity.submitted = true;
    final number = Validators.normalizeEgyptianMobile(_phone.text);
    final linking = link || _lookup == _Lookup.existsElsewhere;
    // Linking needs the number alone; the account keeps its own identity (BR-P3).
    final valid = linking
        ? number != null
        : (_formKey.currentState?.validate() ?? false) && _identity.choicesValid && number != null;
    if (!valid) {
      setState(() {
        _formError = l10n.patientCheckFields;
        _failures++;
        if (number == null) _phoneError = _phone.text.trim().isEmpty ? l10n.errorRequired : l10n.errorInvalidMobile;
      });
      return;
    }

    setState(() {
      _status = SubmitStatus.loading;
      _formError = null;
    });
    try {
      final draft = linking
          ? PatientDraft.link(number)
          : _identity.draft(phone: number);
      final created = await ref.read(patientsRepositoryProvider).createPatient(draft);
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      if (ref.read(registerControllerProvider.exists)) ref.read(registerControllerProvider.notifier).refresh();
      await Future<void>.delayed(Motion.of(context).reduced ? Duration.zero : Motion.slow);
      if (!mounted) return;
      final patient = created.patient;
      if (created.linked || created.temporaryPassword == null) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.how_to_reg_outlined),
            title: Text(l10n.patientLinkedTitle),
            content: Text(l10n.patientLinkedBody),
            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.patientOpenFile))],
          ),
        );
      } else {
        await showTemporaryPasswordDialog(
          context,
          name: patient.fullName,
          phone: patient.phone,
          password: created.temporaryPassword!,
        );
      }
      if (mounted) context.go(widget.paths.patient(patient.patientId));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _failures++;
        if (error.hasCode(ApiCodes.patientAlreadyLinked)) {
          _lookup = _Lookup.linkedToYou;
          _found = PhoneLookup(
            status: PhoneLookupStatus.linkedToYou,
            patientId: error.details['patientId'] as String?,
            fileNumber: error.details['fileNumber'] as int?,
          );
          _formError = null;
          return;
        }
        final fields = {...error.fieldCodes}..remove('phone');
        _phoneError = l10n.fieldError(error.fieldCodes['phone']);
        _identity.serverErrors = fields;
        _formError = fields.isNotEmpty || _phoneError != null ? l10n.patientCheckFields : l10n.apiError(error);
      });
      _formKey.currentState?.validate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paths = widget.paths;
    final linking = _lookup == _Lookup.existsElsewhere;
    final ours = _lookup == _Lookup.linkedToYou;
    var index = 0;
    Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);

    return PopScope(
      canPop: _status == SubmitStatus.idle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = clinicGutter(constraints.maxWidth);
          return Form(
            key: _formKey,
            child: StaggerGroup(
              child: ListView(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: kRegistrationFormWidth),
                      child: ShakeOnError(
                        trigger: _failures == 0 ? null : _failures,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            enter(ClinicHeader(
                              title: l10n.patientAdd,
                              subtitle: l10n.patientAddSubtitle,
                              backFallback: paths.patients,
                            )),
                            const SizedBox(height: 20),
                            enter(FormErrorBanner(message: _formError)),
                            enter(_phoneCard(context)),
                            const SizedBox(height: 16),
                            SmoothSize(
                              child: linking || ours
                                  ? const SizedBox(width: double.infinity)
                                  : enter(PatientIdentityFields(form: _identity, enabled: _status == SubmitStatus.idle)),
                            ),
                            const SizedBox(height: 24),
                            if (!ours)
                              enter(SubmitButton(
                                label: linking ? l10n.patientLinkConfirm : l10n.patientAdd,
                                status: _status,
                                onPressed: _lookup == _Lookup.checking ? null : () => _save(link: linking),
                              )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _phoneCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final found = _found;

    Widget status() => switch (_lookup) {
          _Lookup.idle || _Lookup.failed => const SizedBox(width: double.infinity),
          _Lookup.checking => _LookupNote(icon: Icons.manage_search, text: l10n.patientPhoneChecking),
          _Lookup.isNew => _LookupNote(icon: Icons.check_circle_outline, text: l10n.patientPhoneNew, positive: true),
          _Lookup.linkedToYou => _LookupBanner(
              icon: Icons.folder_shared_outlined,
              title: l10n.patientPhoneOurs,
              body: found?.fullName == null
                  ? (found?.fileNumber == null ? null : l10n.patientFileNumber('${found!.fileNumber}'))
                  : '${found!.fullName}  ${l10n.patientFileNumber('${found.fileNumber}')}',
              action: found?.patientId == null
                  ? null
                  : FilledButton.tonalIcon(
                      onPressed: () => _openExisting(found!.patientId!),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(l10n.patientOpenFile),
                    ),
            ),
          _Lookup.existsElsewhere => _LookupBanner(
              icon: Icons.link,
              title: l10n.patientPhoneElsewhere,
              body: l10n.patientPhoneElsewhereBody,
            ),
        };

    return SectionCard(
      title: l10n.patientMobile,
      subtitle: l10n.patientMobileHint,
      icon: Icons.phone_iphone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _phone,
            enabled: _status == SubmitStatus.idle,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩+ ]')), LengthLimitingTextInputFormatter(16)],
            decoration: InputDecoration(
              labelText: l10n.patientMobileLabel,
              hintText: '01X XXXX XXXX',
              hintTextDirection: TextDirection.ltr,
              prefixIcon: Icon(Icons.call_outlined, color: scheme.onSurfaceVariant),
            ),
            forceErrorText: _phoneError,
            onChanged: _onPhoneChanged,
            validator: (value) => PatientFieldRules.mobile(l10n, value ?? ''),
          ),
          SmoothSize(child: Padding(padding: const EdgeInsets.only(top: 10), child: status())),
        ],
      ),
    );
  }
}

class _LookupNote extends StatelessWidget {
  const _LookupNote({required this.icon, required this.text, this.positive = false});

  final IconData icon;
  final String text;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = positive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: color))),
        ],
      ),
    );
  }
}

class _LookupBanner extends StatelessWidget {
  const _LookupBanner({required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Icon(icon, color: scheme.onPrimaryContainer)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall?.copyWith(color: scheme.onPrimaryContainer)),
                        if (body != null) ...[
                          const SizedBox(height: 4),
                          Text(body!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (action != null) ...[
                const SizedBox(height: 12),
                Align(alignment: AlignmentDirectional.centerEnd, child: action),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
