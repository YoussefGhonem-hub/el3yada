import 'dart:async';

import 'package:animations/animations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/page_transitions.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/shake_on_error.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../core/widgets/success_check.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/application/clinic_providers.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../doctor_registration/presentation/widgets/form_parts.dart';
import '../../doctor_registration/presentation/widgets/step_progress.dart';
import '../../patients/application/patients_providers.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/data/patients_repository.dart';
import '../../patients/domain/patient_models.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/sessions_providers.dart';
import '../data/sessions_repository.dart';
import '../domain/session_models.dart';
import '../domain/session_rules.dart';
import 'widgets/session_widgets.dart';
import 'widgets/vitals_editor.dart';

/// Where D8 was opened from: Back and "View session" go there.
enum SessionOrigin { patient, home, dashboard }

/// D8 / AS5: record a session in two steps.
///
/// 1. **Type**: two ticket cards, Examination and Consultation, each with
///    its visit price and platform fee (`newSessionInfo`). Consultation is
///    closed with the BR-S4 message at the limit, and not offered at all on
///    a first visit (BR-S2).
/// 2. **Details**: the doctor's clinical fields (chief complaint, findings,
///    vitals, diagnosis, notes for the patient, the private note, follow-up)
///    or, for an assistant, only the chief complaint and vitals (BR-AS5);
///    then the amount charged (BR-S10).
///
/// Save asks the BR-S6 confirmation, then morphs into progress and a check,
/// and the after-save sheet opens (the screen's one signature moment).
class NewSessionScreen extends ConsumerWidget {
  const NewSessionScreen({super.key, this.patientId, this.origin = SessionOrigin.patient});

  /// Null: pick the patient first (from the home or D2).
  final String? patientId;
  final SessionOrigin origin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(clinicPathsProvider);
    final fallback = switch (origin) {
      SessionOrigin.patient => patientId == null ? paths.patients : paths.patient(patientId!),
      SessionOrigin.home => paths.home,
      SessionOrigin.dashboard => paths.today(),
    };
    return Scaffold(
      body: ClinicGate(
        builder: (context, clinic) {
          if (!clinic.can(ClinicPermission.sessionsCreate)) {
            return AdminErrorView(
              error: const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.permissionDenied),
            );
          }
          // BR-S8: a suspended doctor (and their assistants) can't record sessions.
          if (clinic.isSuspended) return SuspendedNotice(backFallback: fallback);
          return _NewSessionFlow(
            key: ValueKey(patientId),
            clinic: clinic,
            initialPatientId: patientId,
            origin: origin,
            fallback: fallback,
          );
        },
      ),
    );
  }
}

class _NewSessionFlow extends ConsumerStatefulWidget {
  const _NewSessionFlow({
    super.key,
    required this.clinic,
    required this.initialPatientId,
    required this.origin,
    required this.fallback,
  });

  final ClinicContext clinic;
  final String? initialPatientId;
  final SessionOrigin origin;
  final String fallback;

  @override
  ConsumerState<_NewSessionFlow> createState() => _NewSessionFlowState();
}

class _NewSessionFlowState extends ConsumerState<_NewSessionFlow> {
  String? _patientId;
  late String _branchId;
  int _step = 0;
  bool _reverse = false;
  SessionType? _type;

  final _complaint = TextEditingController();
  final _findings = TextEditingController();
  final _diagnosis = TextEditingController();
  final _patientNotes = TextEditingController();
  final _privateNote = TextEditingController();
  final _amount = TextEditingController();
  final _vitals = VitalsControllers();
  DateTime? _followUp;
  PaymentMethod? _method;
  bool _free = false;

  /// The type the amount's default was filled for, until staff type their own.
  SessionType? _amountFor;
  bool _amountEdited = false;

  SubmitStatus _status = SubmitStatus.idle;
  String? _formError;
  String? _amountError;

  /// After `CONSULTATION_REQUIRES_EXAM`: someone saved first (AC-2).
  String? _ruleNotice;
  Map<String, String> _fieldErrors = const {};
  int _failures = 0;

  bool get _isDoctor => widget.clinic.isDoctor;

  @override
  void initState() {
    super.initState();
    _patientId = widget.initialPatientId;
    final current = ref.read(currentBranchProvider);
    final work = widget.clinic.workBranches;
    _branchId = (current != null && work.any((b) => b.id == current.id) ? current.id : work.firstOrNull?.id) ?? '';
  }

  @override
  void dispose() {
    for (final c in [_complaint, _findings, _diagnosis, _patientNotes, _privateNote, _amount]) {
      c.dispose();
    }
    _vitals.dispose();
    super.dispose();
  }

  ({String patientId, String branchId}) get _key => (patientId: _patientId!, branchId: _branchId);

  void _goTo(int step) => setState(() {
    _reverse = step < _step;
    _step = step;
  });

  void _select(SessionType type) => setState(() {
    _type = type;
    _ruleNotice = null;
  });

  /// Fills the amount with the visit price of the chosen type, unless staff
  /// typed their own (BR-S10).
  void _fillAmount(NewSessionInfo info) {
    if (_amountEdited || _amountFor == _type || _type == null) return;
    _amountFor = _type;
    _amount.text = AmountRules.text(AmountRules.defaultFor(info, _type!));
    _amountError = null;
  }

  void _next(NewSessionInfo info) {
    if (_type == null) return;
    _fillAmount(info);
    _goTo(1);
  }

  void _back() {
    if (_step == 1) {
      _goTo(0);
    } else if (widget.initialPatientId == null && _patientId != null) {
      setState(() {
        _patientId = null;
        _type = null;
        _amountFor = null;
      });
    }
  }

  Future<void> _save(NewSessionInfo info, PatientView? patient) async {
    final l10n = AppLocalizations.of(context);
    final type = _type!;
    final vitals = readVitals(_vitals.values);
    final amount = _free
        ? (piasters: 0, problem: null)
        : AmountRules.parse(_amount.text, required: AmountRules.requiredFor(info, type));
    setState(() {
      _amountError = switch (amount.problem) {
        AmountProblem.required => l10n.sessionAmountRequired,
        AmountProblem.invalid => l10n.adminErrorInvalidValue,
        AmountProblem.outOfRange => l10n.adminErrorOutOfRange,
        null => null,
      };
    });
    if (vitals.vitals == null || amount.problem != null) {
      setState(() {
        _formError = l10n.patientCheckFields;
        _failures++;
      });
      return;
    }

    final charged = amount.piasters ?? AmountRules.defaultFor(info, type);
    final confirmed = await _confirm(info, type, patient, charged);
    if (!confirmed || !mounted) return;

    setState(() {
      _status = SubmitStatus.loading;
      _formError = null;
      _fieldErrors = const {};
    });
    String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    try {
      final session = await ref
          .read(sessionsRepositoryProvider)
          .createSession(
            NewSessionDraft(
              patientId: _patientId!,
              branchId: _branchId,
              type: type,
              chiefComplaint: text(_complaint),
              vitals: vitals.vitals!,
              findings: _isDoctor ? text(_findings) : null,
              diagnosis: _isDoctor ? text(_diagnosis) : null,
              patientNotes: _isDoctor ? text(_patientNotes) : null,
              privateNote: _isDoctor ? text(_privateNote) : null,
              followUpDate: _isDoctor ? _followUp : null,
              amountChargedPiasters: amount.piasters,
              paymentMethod: _method,
            ),
          );
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      sessionsChanged(ref, patientId: _patientId!);
      await Future<void>.delayed(Motion.of(context).reduced ? Motion.fast : Motion.slow);
      if (!mounted) return;
      await _afterSave(session);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.hasCode(ApiCodes.consultationRequiresExam)) {
        // Someone saved a session for this patient first (AC-2): read the rule again.
        ref.invalidate(newSessionInfoProvider(_key));
        final max =
            (error.details['maxConsecutiveConsultations'] as num?)?.toInt() ??
            widget.clinic.fees.maxConsecutiveConsultations;
        setState(() {
          _status = SubmitStatus.idle;
          _type = null;
          _amountFor = null;
          _ruleNotice = error.details['reason'] == 'firstVisit'
              ? l10n.sessionRuleFirstVisit
              : l10n.sessionRuleChanged(l10n.sessionConsultationLimit(max));
          _reverse = true;
          _step = 0;
        });
        return;
      }
      final amountCode = error.fieldCodes['amountChargedPiasters'];
      setState(() {
        _status = SubmitStatus.idle;
        _failures++;
        _fieldErrors = error.fieldCodes;
        if (amountCode != null) _amountError = l10n.fieldError(amountCode) ?? l10n.adminErrorInvalidValue;
        _formError = error.fieldCodes.isNotEmpty ? l10n.patientCheckFields : l10n.apiError(error);
      });
    }
  }

  /// BR-S6: "Save as Examination? A fee of 30 EGP will be added."
  Future<bool> _confirm(NewSessionInfo info, SessionType type, PatientView? patient, int? charged) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _FeeConfirmDialog(
        type: type,
        freeTrial: widget.clinic.freeTrial,
        feePiasters: info.option(type).platformFeePiasters,
        patientName: patient?.fullName,
        branchName: widget.clinic.branch(_branchId)?.name(Localizations.localeOf(context).languageCode),
        chargedPiasters: charged,
        method: _method,
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _afterSave(SessionView session) async {
    final paths = ref.read(clinicPathsProvider);
    final action = await showModalBottomSheet<_AfterSave>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (context) => _AfterSaveSheet(session: session, isDoctor: _isDoctor, freeTrial: widget.clinic.freeTrial),
    );
    if (!mounted) return;
    final detail = switch (widget.origin) {
      SessionOrigin.patient => paths.patientSession(session.patientId, session.sessionId),
      SessionOrigin.home => paths.homeSession(session.sessionId),
      SessionOrigin.dashboard => paths.dashboardSession(session.sessionId),
    };
    if (action == _AfterSave.view) {
      context.pushReplacement(detail);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(widget.fallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final patientId = _patientId;
    if (patientId == null) {
      return _PatientPicker(
        fallback: widget.fallback,
        canAdd: widget.clinic.can(ClinicPermission.patientsManage),
        onPicked: (id) => setState(() {
          _patientId = id;
          _step = 0;
          _type = null;
        }),
      );
    }
    final info = ref.watch(newSessionInfoProvider(_key));
    final patient = ref.watch(patientProvider(patientId)).value;
    final reduced = Motion.of(context).reduced;
    final busy = _status != SubmitStatus.idle;

    return PopScope(
      canPop: !busy && (_step == 0 && (widget.initialPatientId != null)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) _back();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = clinicGutter(constraints.maxWidth);
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClinicHeader(
                          title: l10n.sessionNew,
                          subtitle: patient?.fullName,
                          backFallback: widget.fallback,
                        ),
                        SizedBox(height: constraints.maxWidth < 600 ? 8 : 12),
                        _ContextStrip(
                          clinic: widget.clinic,
                          patient: patient,
                          branchId: _branchId,
                          enabled: !busy,
                          onBranch: (id) => setState(() {
                            _branchId = id;
                            _amountFor = null;
                            _ruleNotice = null;
                          }),
                        ),
                        SizedBox(height: constraints.maxWidth < 600 ? 10 : 16),
                        constraints.maxWidth < 600
                            ? _CompactSteps(step: _step, labels: [l10n.sessionStepType, l10n.sessionStepDetails])
                            : StepProgress(step: _step, labels: [l10n.sessionStepType, l10n.sessionStepDetails]),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ShakeOnError(
                  trigger: _failures == 0 ? null : _failures,
                  child: PageTransitionSwitcher(
                    reverse: _reverse,
                    duration: reduced ? Motion.normal : Motion.slow,
                    layoutBuilder: (entries) => Stack(fit: StackFit.expand, children: entries),
                    transitionBuilder: (child, primary, secondary) => reduced
                        ? FadeTransition(
                            opacity: primary,
                            child: FadeTransition(opacity: ReverseAnimation(secondary), child: child),
                          )
                        : DirectionalSharedAxisTransition(
                            animation: primary,
                            secondaryAnimation: secondary,
                            child: child,
                          ),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _step == 0
                          ? _typeStep(context, info, gutter)
                          : _detailsStep(context, info.value, gutter, busy),
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
                      constraints: const BoxConstraints(maxWidth: _maxWidth),
                      child: _step == 0
                          ? _typeActions(context, info.value)
                          : _detailsActions(context, info.value, patient, busy),
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

  static const double _maxWidth = 760;

  Widget _typeActions(BuildContext context, NewSessionInfo? info) {
    final l10n = AppLocalizations.of(context);
    final allowed = info != null && _type != null && ConsultationRuleView.from(info).allowedTypes.contains(_type);
    return Row(
      children: [
        Expanded(
          child: Text(
            _type == null ? l10n.sessionPickType : l10n.sessionPicked(sessionTypeLabel(l10n, _type!)),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: allowed ? () => _next(info) : null,
          icon: const Icon(Icons.arrow_forward),
          label: Text(l10n.sessionNext),
        ),
      ],
    );
  }

  Widget _detailsActions(BuildContext context, NewSessionInfo? info, PatientView? patient, bool busy) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        OutlinedButton(onPressed: busy ? null : _back, child: Text(l10n.regBack)),
        const SizedBox(width: 12),
        Expanded(
          child: SubmitButton(
            label: l10n.sessionSave,
            status: _status,
            onPressed: info == null || _type == null ? null : () => _save(info, patient),
          ),
        ),
      ],
    );
  }

  Widget _typeStep(BuildContext context, AsyncValue<NewSessionInfo> info, double gutter) {
    return AsyncStateSwitcher<NewSessionInfo>(
      value: info,
      loading: (context) => ListView(
        padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: SkeletonLoading(loading: true, child: _TypeCards.placeholder()),
            ),
          ),
        ],
      ),
      error: (context, error) =>
          AdminErrorView(error: error, onRetry: () => ref.invalidate(newSessionInfoProvider(_key))),
      data: (context, info) {
        final rule = ConsultationRuleView.from(info);
        // A type the rule no longer allows can't stay picked.
        if (_type != null && !rule.allowedTypes.contains(_type)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _type = null);
          });
        }
        // A first visit is always an examination: pick it at once.
        if (_type == null && !rule.offerConsultation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _type == null) setState(() => _type = SessionType.examination);
          });
        }
        return StaggerGroup(
          child: ListView(
            padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 24),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_ruleNotice != null) ...[
                        StaggeredEntrance(index: 0, child: _RuleNotice(message: _ruleNotice!)),
                        const SizedBox(height: 16),
                      ],
                      StaggeredEntrance(
                        index: 1,
                        child: _RuleLine(info: info, rule: rule),
                      ),
                      const SizedBox(height: 16),
                      StaggeredEntrance(
                        index: 2,
                        child: _TypeCards(
                          info: info,
                          rule: rule,
                          selected: _type,
                          onSelect: _select,
                          freeTrial: widget.clinic.freeTrial,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailsStep(BuildContext context, NewSessionInfo? info, double gutter, bool busy) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final type = _type ?? SessionType.examination;
    var index = 0;
    Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);
    String? server(String field) =>
        _fieldErrors[field] == null ? null : (l10n.fieldError(_fieldErrors[field]) ?? l10n.adminErrorInvalidValue);

    final complaint = TextField(
      controller: _complaint,
      enabled: !busy,
      minLines: 1,
      maxLines: 4,
      inputFormatters: [LengthLimitingTextInputFormatter(1000)],
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(labelText: l10n.sessionChiefComplaint, errorText: server('chiefComplaint')),
    );

    return StaggerGroup(
      child: ListView(
        padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  enter(FormErrorBanner(message: _formError)),
                  enter(
                    Row(
                      children: [
                        TypeBadge(type, large: true),
                        const SizedBox(width: 10),
                        if (info != null)
                          Expanded(
                            child: Text(
                              widget.clinic.freeTrial
                                  ? l10n.sessionFeeFreeTrial
                                  : l10n.sessionPlatformFeeShort(
                                      AppFormat.egp(context, info.option(type).platformFeePiasters),
                                    ),
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isDoctor) ...[
                    enter(
                      SectionCard(
                        title: l10n.sessionClinical,
                        icon: Icons.medical_services_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            complaint,
                            const SizedBox(height: 12),
                            TextField(
                              controller: _findings,
                              enabled: !busy,
                              minLines: 2,
                              maxLines: 8,
                              decoration: InputDecoration(
                                labelText: l10n.sessionFindings,
                                errorText: server('findings'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _diagnosis,
                              enabled: !busy,
                              minLines: 1,
                              maxLines: 3,
                              inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                              decoration: InputDecoration(
                                labelText: l10n.sessionDiagnosis,
                                errorText: server('diagnosis'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _patientNotes,
                              enabled: !busy,
                              minLines: 2,
                              maxLines: 6,
                              decoration: InputDecoration(
                                labelText: l10n.sessionPatientNotes,
                                helperText: l10n.sessionPatientNotesHint,
                                errorText: server('patientNotes'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    enter(VitalsSection(controllers: _vitals, enabled: !busy, serverErrors: _fieldErrors)),
                    const SizedBox(height: 16),
                    enter(PrivateNoteField(controller: _privateNote, enabled: !busy, error: server('privateNote'))),
                    const SizedBox(height: 16),
                    enter(
                      _FollowUpField(
                        value: _followUp,
                        enabled: !busy,
                        error: server('followUpDate'),
                        onChanged: (date) => setState(() => _followUp = date),
                      ),
                    ),
                  ] else ...[
                    enter(SectionCard(title: l10n.sessionChiefComplaint, icon: Icons.chat_outlined, child: complaint)),
                    const SizedBox(height: 16),
                    enter(
                      VitalsSection(
                        controllers: _vitals,
                        enabled: !busy,
                        initiallyOpen: true,
                        serverErrors: _fieldErrors,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (info != null) enter(_amountCard(context, info, type, busy)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountCard(BuildContext context, NewSessionInfo info, SessionType type, bool busy) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final price = AmountRules.defaultFor(info, type);
    return SectionCard(
      title: l10n.sessionAmountCharged,
      subtitle: price == null ? l10n.sessionNoPrice : l10n.sessionVisitPrice(AppFormat.egp(context, price)),
      icon: Icons.payments_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _amount,
            enabled: !busy && !_free,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫]')),
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: (_) => setState(() {
              _amountEdited = true;
              _amountError = null;
            }),
            decoration: InputDecoration(
              labelText: _free ? l10n.sessionFree : l10n.sessionAmountLabel,
              suffixText: l10n.sessionCurrency,
              helperText: l10n.sessionAmountHint,
              errorText: _amountError,
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _free,
            onChanged: busy
                ? null
                : (on) => setState(() {
                    _free = on;
                    _amountError = null;
                    if (on) {
                      _amount.text = '0';
                    } else {
                      _amount.text = AmountRules.text(price);
                      _amountEdited = false;
                    }
                  }),
            title: Text(l10n.sessionFreeVisit),
          ),
          const SizedBox(height: 8),
          Text(l10n.sessionPaymentMethod, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final method in PaymentMethod.values)
                ChoiceChip(
                  label: Text(paymentMethodLabel(l10n, method)),
                  selected: _method == method,
                  onSelected: busy ? null : (on) => setState(() => _method = on ? method : null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// The context strip: patient (with the allergy flag) and the branch

class _ContextStrip extends StatelessWidget {
  const _ContextStrip({
    required this.clinic,
    required this.patient,
    required this.branchId,
    required this.enabled,
    required this.onBranch,
  });

  final ClinicContext clinic;
  final PatientView? patient;
  final String branchId;
  final bool enabled;
  final ValueChanged<String> onBranch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final branches = clinic.workBranches;
    final branch = clinic.branch(branchId);
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (patient != null) ...[
          FileNumberPill(patient!.fileNumber),
          if (patient!.hasAllergies ?? false) const AllergyFlag(),
        ],
        // BR-BR3: the current branch, changeable among the caller's branches.
        if (branches.length > 1)
          MenuAnchor(
            menuChildren: [
              for (final b in branches)
                MenuItemButton(
                  leadingIcon: Icon(b.id == branchId ? Icons.check : null, size: 20),
                  onPressed: enabled ? () => onBranch(b.id) : null,
                  child: Text(b.name(language)),
                ),
            ],
            builder: (context, controller, _) => ActionChip(
              avatar: const Icon(Icons.store_mall_directory_outlined, size: 18),
              label: Text(l10n.sessionBranch(branch?.name(language) ?? '')),
              onPressed: enabled ? () => controller.isOpen ? controller.close() : controller.open() : null,
              tooltip: l10n.sessionChangeBranch,
            ),
          )
        else if (branch != null)
          MetaLine(
            icon: Icons.store_mall_directory_outlined,
            text: l10n.sessionBranch(branch.name(language)),
            color: theme.colorScheme.onSurfaceVariant,
          ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Step 1: the rule line and the type cards

class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.info, required this.rule});

  final NewSessionInfo info;
  final ConsultationRuleView rule;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = info.lastSession;
    final lines = <Widget>[
      if (last == null || info.isFirstVisit)
        MetaLine(icon: Icons.fiber_new_outlined, text: l10n.sessionFirstVisit, color: scheme.onSurface)
      else
        MetaLine(
          icon: Icons.history,
          text: l10n.sessionLastSession(sessionTypeLabel(l10n, last.type), ClinicFormat.dayShort(context, last.day)),
          color: scheme.onSurface,
        ),
      if (rule.showCount) MetaLine(icon: Icons.repeat, text: l10n.sessionConsultationCount(rule.count, rule.max)),
    ];
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, line) in lines.indexed) ...[if (i > 0) const SizedBox(height: 6), line],
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleNotice extends StatelessWidget {
  const _RuleNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(Icons.info_outline, color: scheme.onTertiaryContainer)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onTertiaryContainer)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two big ticket cards, side by side when there's room.
class _TypeCards extends StatelessWidget {
  const _TypeCards({
    required this.info,
    required this.rule,
    required this.selected,
    required this.onSelect,
    this.freeTrial = false,
  });

  static Widget placeholder() {
    const option = TypeOption(allowed: true, platformFeePiasters: 3000, visitPricePiasters: 30000);
    const info = NewSessionInfo(
      patientId: '',
      branchId: '',
      isFirstVisit: false,
      consultationsSinceExam: 0,
      maxConsecutiveConsultations: 2,
      consultationAllowed: true,
      examination: option,
      consultation: option,
    );
    return _TypeCards(info: info, rule: ConsultationRuleView.from(info), selected: null, onSelect: (_) {});
  }

  final NewSessionInfo info;
  final ConsultationRuleView rule;
  final SessionType? selected;
  final ValueChanged<SessionType> onSelect;

  /// The clinic's free trial runs: no platform fee (BR-T3).
  final bool freeTrial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exam = TypeTicket(
      type: SessionType.examination,
      option: info.examination,
      selected: selected == SessionType.examination,
      onTap: () => onSelect(SessionType.examination),
      freeTrial: freeTrial,
    );
    if (!rule.offerConsultation) return exam;
    final consult = TypeTicket(
      type: SessionType.consultation,
      option: info.consultation,
      selected: selected == SessionType.consultation,
      onTap: rule.consultationEnabled ? () => onSelect(SessionType.consultation) : null,
      blockedMessage: rule.block == ConsultationBlock.limitReached ? l10n.sessionConsultationLimit(rule.max) : null,
      freeTrial: freeTrial,
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 560
          ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: exam),
                  const SizedBox(width: 16),
                  Expanded(child: consult),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [exam, const SizedBox(height: 14), consult],
            ),
    );
  }
}

/// One type as a queue ticket: the stub in the type's colour (كشف blue,
/// استشارة green), the visit price and the platform fee. Picking it draws
/// the border in and pops a check; a closed type shows why, with a lock.
class TypeTicket extends StatelessWidget {
  const TypeTicket({
    super.key,
    required this.type,
    required this.option,
    required this.selected,
    required this.onTap,
    this.blockedMessage,
    this.freeTrial = false,
  });

  final SessionType type;
  final TypeOption option;

  /// The clinic's free trial runs: «بدون رسوم منصة» instead of the fee (BR-T3).
  final bool freeTrial;
  final bool selected;

  /// Null when the type can't be picked now.
  final VoidCallback? onTap;

  /// BR-S4: why it's closed.
  final String? blockedMessage;

  static const double _stub = 84;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.el3yadaColors;
    final motion = Motion.of(context);
    final exam = type == SessionType.examination;
    final enabled = onTap != null;
    final tint = enabled ? (exam ? colors.examination : colors.consultation) : scheme.surfaceContainerHigh;
    final onTint = enabled ? (exam ? colors.onExamination : colors.onConsultation) : scheme.onSurfaceVariant;
    final label = sessionTypeLabel(l10n, type);
    final price = option.visitPricePiasters;
    final feeText = freeTrial
        ? l10n.sessionPlatformFeeFree
        : l10n.sessionPlatformFee(AppFormat.egp(context, option.platformFeePiasters));

    final semantics = [
      label,
      price == null ? l10n.sessionNoPriceShort : l10n.sessionVisitPrice(AppFormat.egp(context, price)),
      feeText,
      ?blockedMessage,
    ].join(l10n.adminListSeparator);

    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: semantics,
      borderRadius: BorderRadius.circular(22),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selected ? 1 : 0),
        duration: motion.reduced ? Duration.zero : Motion.normal,
        curve: Motion.standardCurve,
        builder: (context, t, child) => Material(
          color: scheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: TicketShapeBorder(
            radius: 22,
            stubWidth: _stub,
            side: BorderSide(color: Color.lerp(scheme.outlineVariant, onTint, t)!, width: 1 + 1.5 * t),
          ),
          child: child,
        ),
        child: IntrinsicHeight(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 148),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The stub.
                Container(
                  width: _stub,
                  color: tint,
                  alignment: Alignment.center,
                  child: ExcludeSemantics(
                    child: Icon(
                      enabled ? (exam ? Icons.medical_services_outlined : Icons.forum_outlined) : Icons.lock_outline,
                      size: 34,
                      color: onTint,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            _CheckPop(visible: selected, color: onTint, background: tint),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (blockedMessage != null)
                          Text(blockedMessage!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error))
                        else ...[
                          Text(
                            price == null ? l10n.sessionNoPriceShort : AppFormat.egp(context, price),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            price == null ? l10n.sessionNoPriceHint : l10n.sessionVisitPriceLabel,
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Text(
                          feeText,
                          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The check that pops in on the picked ticket.
class _CheckPop extends StatelessWidget {
  const _CheckPop({required this.visible, required this.color, required this.background});

  final bool visible;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.of(context).reduced;
    return AnimatedScale(
      scale: visible ? 1 : 0,
      duration: reduced ? Duration.zero : Motion.slow,
      curve: visible ? Motion.springBouncy : Motion.exitCurve,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.check_rounded, size: 22, color: color),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Step 2 parts

/// The doctor's private note: lock icon, "not visible to the patient".
class PrivateNoteField extends StatelessWidget {
  const PrivateNoteField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.error,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? error;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: scheme.inverseSurface, shape: BoxShape.circle),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.lock_outline, size: 18, color: scheme.onInverseSurface),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.sessionPrivateNote, style: theme.textTheme.titleMedium),
                      Text(
                        l10n.sessionPrivateNoteHint,
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              enabled: enabled,
              autofocus: autofocus,
              minLines: 2,
              maxLines: 8,
              decoration: InputDecoration(hintText: l10n.sessionPrivateNotePlaceholder, errorText: error),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowUpField extends StatelessWidget {
  const _FollowUpField({required this.value, required this.enabled, required this.onChanged, this.error});

  final DateTime? value;
  final bool enabled;
  final ValueChanged<DateTime?> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) =>
      FollowUpPicker(value: value, enabled: enabled, onChanged: onChanged, error: error, from: ClinicFormat.today());
}

/// The optional follow-up date: from [from] to two years after.
class FollowUpPicker extends StatelessWidget {
  const FollowUpPicker({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.from,
    this.error,
  });

  final DateTime? value;
  final bool enabled;
  final ValueChanged<DateTime?> onChanged;
  final DateTime from;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Future<void> pick() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: value ?? from.add(const Duration(days: 7)),
        firstDate: from,
        lastDate: DateTime.utc(from.year + 2, from.month, from.day),
      );
      if (picked != null) onChanged(DateTime.utc(picked.year, picked.month, picked.day));
    }

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? pick : null,
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          labelText: l10n.sessionFollowUp,
          prefixIcon: const Icon(Icons.event_repeat_outlined),
          errorText: error,
          enabled: enabled,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(
                  tooltip: l10n.sessionClearFollowUp,
                  onPressed: enabled ? () => onChanged(null) : null,
                  icon: const Icon(Icons.close),
                ),
        ),
        child: Text(
          value == null ? '' : ClinicFormat.dayWithWeekday(context, value!),
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// BR-S6 confirmation

class _FeeConfirmDialog extends StatelessWidget {
  const _FeeConfirmDialog({
    required this.type,
    required this.freeTrial,
    required this.feePiasters,
    required this.patientName,
    required this.branchName,
    required this.chargedPiasters,
    required this.method,
  });

  final SessionType type;
  final bool freeTrial;
  final int feePiasters;
  final String? patientName;
  final String? branchName;
  final int? chargedPiasters;
  final PaymentMethod? method;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.el3yadaColors;
    final exam = type == SessionType.examination;
    final tint = exam ? colors.examination : colors.consultation;
    final onTint = exam ? colors.onExamination : colors.onConsultation;
    final typeLabel = sessionTypeLabel(l10n, type);
    // "Save as **Examination**?": the type in bold, wherever the language puts it.
    final parts = l10n.sessionConfirmTitle('\u0000').split('\u0000');
    final fee = AppFormat.egp(context, feePiasters);
    final charged = chargedPiasters;

    Widget row(IconData icon, String label, String value, {bool ltr = false}) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(icon, size: 18, color: scheme.onSurfaceVariant)),
          const SizedBox(width: 10),
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              textDirection: ltr ? TextDirection.ltr : null,
              style: theme.textTheme.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The ticket stub of the chosen type.
              Material(
                color: tint,
                shape: const TicketShapeBorder(radius: 18, stubWidth: 64, notch: 7),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 16, 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: ExcludeSemantics(
                          child: Icon(
                            exam ? Icons.medical_services_outlined : Icons.forum_outlined,
                            color: onTint,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 28),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text.rich(
                            TextSpan(
                              style: theme.textTheme.titleMedium?.copyWith(color: onTint),
                              children: [
                                TextSpan(text: parts.first),
                                TextSpan(
                                  text: typeLabel,
                                  style: theme.textTheme.headlineSmall?.copyWith(color: onTint, fontWeight: FontWeight.w800),
                                ),
                                if (parts.length > 1) TextSpan(text: parts.last),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(freeTrial ? l10n.sessionConfirmFeeFree : l10n.sessionConfirmFee(fee), style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              const Divider(),
              if (patientName != null) row(Icons.person_outline, l10n.sessionConfirmPatient, patientName!),
              if (branchName != null) row(Icons.store_mall_directory_outlined, l10n.sessionConfirmBranch, branchName!),
              if (charged != null)
                row(
                  Icons.payments_outlined,
                  l10n.sessionAmountCharged,
                  charged == 0 ? l10n.sessionFree : AppFormat.egp(context, charged),
                ),
              if (method != null)
                row(
                  Icons.account_balance_wallet_outlined,
                  l10n.sessionPaymentMethod,
                  paymentMethodLabel(l10n, method!),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ExcludeSemantics(child: Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.sessionConfirmLocked,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.adminCancel)),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.sessionConfirmSave)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// After save

enum _AfterSave { done, view }

class _AfterSaveSheet extends StatelessWidget {
  const _AfterSaveSheet({required this.session, required this.isDoctor, this.freeTrial = false});

  final SessionView session;
  final bool isDoctor;
  final bool freeTrial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget later(IconData icon, String label) => ListTile(
      enabled: false,
      leading: Icon(icon),
      title: Text(label),
      trailing: StatusPill(label: l10n.sessionLater),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: SuccessCheck(size: 88)),
                const SizedBox(height: 12),
                Text(l10n.sessionSaved, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  freeTrial && session.platformFeePiasters == 0
                      ? l10n.sessionSavedBodyFree(sessionTypeLabel(l10n, session.type), session.patientName)
                      : l10n.sessionSavedBody(
                          sessionTypeLabel(l10n, session.type),
                          session.patientName,
                          AppFormat.egp(context, session.platformFeePiasters),
                        ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (session.awaitingDoctor) ...[const SizedBox(height: 10), const Center(child: AwaitingDoctorBadge())],
                const SizedBox(height: 16),
                // Prescriptions and requests come in Phase 3, files too.
                if (isDoctor) ...[
                  later(Icons.medication_outlined, l10n.sessionWritePrescription),
                  later(Icons.biotech_outlined, l10n.sessionLabRequest),
                ],
                later(Icons.attach_file, l10n.sessionAttachFiles),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, _AfterSave.view),
                        child: Text(l10n.sessionView),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        autofocus: true,
                        onPressed: () => Navigator.pop(context, _AfterSave.done),
                        child: Text(l10n.done),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Patient search (D8 opened from the home or D2)

final _pickerProvider = FutureProvider.autoDispose.family<Paged<PatientRegisterRow>, String>(
  (ref, search) => ref.watch(patientsRepositoryProvider).register(RegisterQuery(search: search), pageSize: 25),
);

class _PatientPicker extends ConsumerStatefulWidget {
  const _PatientPicker({required this.fallback, required this.canAdd, required this.onPicked});

  final String fallback;
  final bool canAdd;
  final ValueChanged<String> onPicked;

  @override
  ConsumerState<_PatientPicker> createState() => _PatientPickerState();
}

class _PatientPickerState extends ConsumerState<_PatientPicker> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final paths = ref.watch(clinicPathsProvider);
    final results = ref.watch(_pickerProvider(_query));
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = clinicGutter(constraints.maxWidth);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
                  child: ClinicHeader(
                    title: l10n.sessionNew,
                    subtitle: l10n.sessionPickPatient,
                    backFallback: widget.fallback,
                    actions: [
                      if (widget.canAdd)
                        IconButton.filledTonal(
                          tooltip: l10n.patientAdd,
                          onPressed: () => context.push(paths.addPatient),
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.patientSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter + 4),
                  child: Text(
                    _query.isEmpty ? l10n.sessionRecentPatients : l10n.sessionSearchResults,
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: AsyncStateSwitcher<Paged<PatientRegisterRow>>(
                    value: results,
                    isEmpty: (page) => page.items.isEmpty,
                    loading: (context) => SkeletonLoading(
                      loading: true,
                      child: ListView(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: gutter),
                        children: [
                          GroupedRows(
                            children: [
                              for (var i = 0; i < 5; i++)
                                const ListTile(title: Text('——————————'), subtitle: Text('——————')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    error: (context, error) =>
                        AdminErrorView(error: error, onRetry: () => ref.invalidate(_pickerProvider(_query))),
                    empty: (context) => EmptyState(title: l10n.patientNoMatchTitle, message: l10n.patientNoMatchBody),
                    data: (context, page) => StaggerGroup(
                      key: ValueKey(_query),
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24 + MediaQuery.paddingOf(context).bottom),
                        children: [
                          GroupedRows(
                            children: [
                              for (final (i, row) in page.items.indexed)
                                StaggeredEntrance(
                                  index: i,
                                  child: ListTile(
                                    onTap: () => widget.onPicked(row.patientId),
                                    leading: InitialAvatar(name: row.fullName, size: 40),
                                    title: Text(row.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    subtitle: Text(
                                      [
                                        l10n.patientFileNumber('${row.fileNumber}'),
                                        if (row.visits.lastVisit != null)
                                          l10n.sessionLastSession(
                                            sessionTypeLabel(l10n, row.visits.lastVisit!.type),
                                            ClinicFormat.dayShort(context, row.visits.lastVisit!.day),
                                          )
                                        else
                                          l10n.patientNoVisits,
                                      ].join(l10n.adminListSeparator),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: (row.hasAllergies ?? false) ? const AllergyFlag(compact: true) : null,
                                  ),
                                ),
                            ],
                          ),
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
    );
  }
}

/// Phones: the step on one line over a thin two-part bar, so the type cards
/// stay above the fold. Wider screens use the registration's `StepProgress`.
class _CompactSteps extends StatelessWidget {
  const _CompactSteps({required this.step, required this.labels});

  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduced = Motion.of(context).reduced;
    final text = l10n.regStepSemantics(step + 1, labels.length, labels[step]);
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: reduced ? Duration.zero : Motion.normal,
              layoutBuilder: (current, previous) =>
                  Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
              child: Text(text, key: ValueKey(step), style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: i <= step ? scheme.primary : scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
