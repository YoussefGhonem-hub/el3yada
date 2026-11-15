import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../patients/application/patients_providers.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/sessions_providers.dart';
import '../data/sessions_repository.dart';
import '../domain/session_models.dart';
import '../domain/session_rules.dart';
import 'new_session_screen.dart' show FollowUpPicker, PrivateNoteField;
import 'widgets/vitals_editor.dart';

/// D9: everything the caller may see about one session.
///
/// - Type and time are locked (BR-S6), with a lock icon.
/// - The doctor edits the clinical fields (`updateClinical`, which clears
///   «بانتظار الطبيب», BR-AS7) and the private note; assistants never see it.
/// - The amount charged is editable on the session's Cairo day by the doctor
///   or whoever recorded it (BR-S10, `can.editAmount`).
/// - Delete appears only when BR-S7 allows it (`can.delete`), with a reason
///   and a confirmation; otherwise the reason it can't is explained to
///   those who may delete.
class SessionDetailsPage extends ConsumerWidget {
  const SessionDetailsPage({super.key, required this.sessionId, this.showPatientLink = true});

  final String sessionId;

  /// From D2 and the home: a link to the patient's file.
  final bool showPatientLink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(clinicPathsProvider);
    return Scaffold(
      body: ClinicGate(
        builder: (context, clinic) => AsyncStateSwitcher<SessionView>(
          value: ref.watch(sessionProvider(sessionId)),
          loading: (context) => const SkeletonLoading(loading: true, child: _DetailsSkeleton()),
          error: (context, error) => Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, top: 8),
                child: Align(alignment: AlignmentDirectional.centerStart, child: ClinicBackButton(fallback: paths.home)),
              ),
              Expanded(child: AdminErrorView(error: error, onRetry: () => ref.invalidate(sessionProvider(sessionId)))),
            ],
          ),
          data: (context, session) => _Details(session: session, clinic: clinic, showPatientLink: showPatientLink),
        ),
      ),
    );
  }
}

class _Details extends ConsumerStatefulWidget {
  const _Details({required this.session, required this.clinic, required this.showPatientLink});

  final SessionView session;
  final ClinicContext clinic;
  final bool showPatientLink;

  @override
  ConsumerState<_Details> createState() => _DetailsState();
}

class _DetailsState extends ConsumerState<_Details> {
  bool _deleting = false;

  SessionView get _session => widget.session;

  /// The server's answer replaces what is shown, and the lists and totals
  /// that include this session load again.
  void _updated(SessionView session) {
    ref.invalidate(sessionProvider(session.sessionId));
    sessionsChanged(ref, patientId: session.patientId);
  }

  Future<void> _editAmount() async {
    final updated = await showDialog<SessionView>(context: context, builder: (context) => _AmountDialog(session: _session));
    if (updated == null || !mounted) return;
    _updated(updated);
    showAdminSnack(context, AppLocalizations.of(context).sessionAmountSaved);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final reason = await showDialog<String>(context: context, builder: (context) => const _DeleteDialog());
    if (reason == null || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(sessionsRepositoryProvider).deleteSession(_session.sessionId, reason);
      if (!mounted) return;
      sessionsChanged(ref, patientId: _session.patientId);
      showAdminSnack(context, l10n.sessionDeleted);
      final paths = ref.read(clinicPathsProvider);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go(paths.patient(_session.patientId));
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ref.invalidate(sessionProvider(_session.sessionId));
      showAdminSnack(context, l10n.apiError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paths = ref.watch(clinicPathsProvider);
    final session = _session;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gutter = clinicGutter(width);
        final twoColumns = width >= 980;
        var index = 0;
        Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);

        final header = enter(ClinicHeader(
          title: l10n.sessionDetailsTitle,
          subtitle: session.patientName,
          backFallback: paths.patient(session.patientId),
          trailingTitle: TypeBadge(session.type, large: true, locked: true),
          actions: [
            if (widget.showPatientLink)
              TextButton.icon(
                onPressed: () => context.push(paths.patient(session.patientId)),
                icon: const Icon(Icons.folder_shared_outlined),
                label: Text(l10n.patientOpenFile),
              ),
          ],
        ));
        final summary = enter(_SummaryCard(session: session, clinic: widget.clinic, onEditAmount: session.can.editAmount ? _editAmount : null));
        final clinical = session.clinical == null ? null : enter(_ClinicalCard(session: session, onSaved: _updated));
        final note = session.can.privateNote ? enter(_PrivateNoteCard(sessionId: session.sessionId)) : null;
        final delete = enter(_DeleteArea(session: session, clinic: widget.clinic, busy: _deleting, onDelete: _delete));

        final List<Widget> children;
        if (twoColumns) {
          children = [
            header,
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 380,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [summary, if (note != null) ...[const SizedBox(height: 16), note], const SizedBox(height: 16), delete],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: clinical ?? const SizedBox.shrink()),
              ],
            ),
          ];
        } else {
          children = [
            header,
            const SizedBox(height: 16),
            summary,
            if (clinical != null) ...[const SizedBox(height: 16), clinical],
            if (note != null) ...[const SizedBox(height: 16), note],
            const SizedBox(height: 16),
            delete,
          ];
        }
        return StaggerGroup(
          child: ListView(
            padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32 + MediaQuery.paddingOf(context).bottom),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: twoColumns ? 1200 : 760),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Time and type (locked), branch, platform fee, recorded by, the amount.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.session, required this.clinic, required this.onEditAmount});

  final SessionView session;
  final ClinicContext clinic;
  final VoidCallback? onEditAmount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final amount = session.amountChargedPiasters;
    final recorder = session.recordedBy;

    Widget locked(String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(text, style: theme.textTheme.bodyLarge)),
            const SizedBox(width: 6),
            Tooltip(
              message: l10n.sessionLocked,
              child: Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant, semanticLabel: l10n.sessionLocked),
            ),
          ],
        );

    return SectionCard(
      title: l10n.sessionSummary,
      icon: Icons.event_note_outlined,
      trailing: session.awaitingDoctor ? const AwaitingDoctorBadge() : null,
      child: ResponsiveGrid(
        minColumnWidth: 150,
        runSpacing: 16,
        children: [
          InfoRow(label: l10n.sessionTime, child: locked(AppFormat.dateTime(context, session.at))),
          InfoRow(label: l10n.sessionType, child: locked(sessionTypeLabel(l10n, session.type))),
          InfoRow(label: l10n.sessionBranchLabel, value: session.branch.name(language)),
          InfoRow(label: l10n.sessionPlatformFeeLabel, value: AppFormat.egp(context, session.platformFeePiasters)),
          // BR-AS6: the doctor sees who recorded it.
          if (clinic.isDoctor)
            InfoRow(
              label: l10n.sessionRecordedByLabel,
              value: recorder.isAssistant ? l10n.sessionRecordedByAssistant(recorder.name) : l10n.sessionRecordedByDoctor,
            ),
          if (amount != null)
            InfoRow(
              label: l10n.sessionAmountCharged,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(amount == 0 ? l10n.sessionFree : AppFormat.egp(context, amount), style: theme.textTheme.titleMedium),
                        if (session.listPricePiasters != null && session.listPricePiasters != amount)
                          Text(
                            l10n.sessionVisitPrice(AppFormat.egp(context, session.listPricePiasters!)),
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        if (session.paymentMethod != null)
                          Text(
                            paymentMethodLabel(l10n, session.paymentMethod!),
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (onEditAmount != null)
                    IconButton(tooltip: l10n.sessionEditAmount, onPressed: onEditAmount, icon: const Icon(Icons.edit_outlined)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The clinical fields (`clinicalView`), editable by the doctor.
class _ClinicalCard extends ConsumerStatefulWidget {
  const _ClinicalCard({required this.session, required this.onSaved});

  final SessionView session;
  final ValueChanged<SessionView> onSaved;

  @override
  ConsumerState<_ClinicalCard> createState() => _ClinicalCardState();
}

class _ClinicalCardState extends ConsumerState<_ClinicalCard> {
  bool _editing = false;
  final _complaint = TextEditingController();
  final _findings = TextEditingController();
  final _diagnosis = TextEditingController();
  final _notes = TextEditingController();
  final _vitals = VitalsControllers();
  DateTime? _followUp;
  SubmitStatus _status = SubmitStatus.idle;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  SessionClinical get _clinical => widget.session.clinical!;

  @override
  void dispose() {
    for (final c in [_complaint, _findings, _diagnosis, _notes]) {
      c.dispose();
    }
    _vitals.dispose();
    super.dispose();
  }

  void _startEditing() {
    final clinical = _clinical;
    _complaint.text = clinical.chiefComplaint ?? '';
    _findings.text = clinical.findings ?? '';
    _diagnosis.text = clinical.diagnosis ?? '';
    _notes.text = clinical.patientNotes ?? '';
    _vitals.fill(clinical.vitals);
    _followUp = clinical.followUpDate;
    setState(() {
      _editing = true;
      _error = null;
      _fieldErrors = const {};
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final vitals = readVitals(_vitals.values);
    if (vitals.vitals == null) {
      setState(() => _error = l10n.patientCheckFields);
      return;
    }
    setState(() {
      _status = SubmitStatus.loading;
      _error = null;
    });
    try {
      final updated = await ref.read(sessionsRepositoryProvider).updateClinical(
            widget.session.sessionId,
            ClinicalDraft(
              chiefComplaint: _complaint.text,
              findings: _findings.text,
              vitals: vitals.vitals!,
              diagnosis: _diagnosis.text,
              patientNotes: _notes.text,
              followUpDate: _followUp,
            ),
          );
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      await Future<void>.delayed(Motion.of(context).reduced ? Duration.zero : Motion.slow);
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _editing = false;
      });
      widget.onSaved(updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _fieldErrors = error.fieldCodes;
        _error = error.fieldCodes.isEmpty ? l10n.apiError(error) : l10n.patientCheckFields;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canEdit = widget.session.can.editClinical;
    return SectionCard(
      title: l10n.sessionClinical,
      icon: Icons.medical_services_outlined,
      trailing: canEdit && !_editing
          ? TextButton.icon(onPressed: _startEditing, icon: const Icon(Icons.edit_outlined), label: Text(l10n.patientEdit))
          : null,
      child: AnimatedSwitcher(
        duration: Motion.normal,
        reverseDuration: Motion.normalExit,
        switchInCurve: Motion.enterCurve,
        switchOutCurve: Motion.exitCurveReversed,
        layoutBuilder: (current, previous) => Stack(alignment: AlignmentDirectional.topStart, children: [...previous, ?current]),
        child: _editing ? KeyedSubtree(key: const ValueKey('edit'), child: _form(context)) : KeyedSubtree(key: const ValueKey('view'), child: _view(context)),
      ),
    );
  }

  Widget _view(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final clinical = _clinical;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    Widget block(String label, String? text) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(text ?? l10n.sessionNotRecorded, style: text == null ? muted : theme.textTheme.bodyLarge),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.session.awaitingDoctor && widget.session.can.editClinical) ...[
          Text(l10n.sessionAwaitingHint, style: muted),
          const SizedBox(height: 16),
        ],
        block(l10n.sessionChiefComplaint, clinical.chiefComplaint),
        Text(l10n.sessionVitals, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        VitalsView(vitals: clinical.vitals),
        const SizedBox(height: 16),
        block(l10n.sessionFindings, clinical.findings),
        block(l10n.sessionDiagnosis, clinical.diagnosis),
        block(l10n.sessionPatientNotes, clinical.patientNotes),
        block(l10n.sessionFollowUp, clinical.followUpDate == null ? null : ClinicFormat.dayWithWeekday(context, clinical.followUpDate!)),
      ],
    );
  }

  Widget _form(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = _status != SubmitStatus.idle;
    String? server(String field) => _fieldErrors[field] == null ? null : (l10n.fieldError(_fieldErrors[field]) ?? l10n.adminErrorInvalidValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          Text(_error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _complaint,
          enabled: !busy,
          minLines: 1,
          maxLines: 4,
          maxLength: 1000,
          decoration: InputDecoration(labelText: l10n.sessionChiefComplaint, errorText: server('chiefComplaint')),
        ),
        const SizedBox(height: 8),
        VitalsSection(controllers: _vitals, enabled: !busy, initiallyOpen: true, serverErrors: _fieldErrors),
        const SizedBox(height: 16),
        TextField(
          controller: _findings,
          enabled: !busy,
          minLines: 2,
          maxLines: 8,
          decoration: InputDecoration(labelText: l10n.sessionFindings, errorText: server('findings')),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _diagnosis,
          enabled: !busy,
          minLines: 1,
          maxLines: 3,
          maxLength: 1000,
          decoration: InputDecoration(labelText: l10n.sessionDiagnosis, errorText: server('diagnosis')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notes,
          enabled: !busy,
          minLines: 2,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: l10n.sessionPatientNotes,
            helperText: l10n.sessionPatientNotesHint,
            errorText: server('patientNotes'),
          ),
        ),
        const SizedBox(height: 16),
        FollowUpPicker(
          value: _followUp,
          enabled: !busy,
          from: widget.session.day,
          error: server('followUpDate'),
          onChanged: (date) => setState(() => _followUp = date),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: busy ? null : () => setState(() => _editing = false), child: Text(l10n.adminCancel)),
            const SizedBox(width: 8),
            SizedBox(width: 140, child: SubmitButton(label: l10n.adminSave, status: _status, onPressed: _save)),
          ],
        ),
      ],
    );
  }
}

/// The doctor's private note (lock icon, never visible to the patient or
/// assistants, AC-11).
class _PrivateNoteCard extends ConsumerStatefulWidget {
  const _PrivateNoteCard({required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<_PrivateNoteCard> createState() => _PrivateNoteCardState();
}

class _PrivateNoteCardState extends ConsumerState<_PrivateNoteCard> {
  bool _editing = false;
  final _text = TextEditingController();
  SubmitStatus _status = SubmitStatus.idle;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _status = SubmitStatus.loading;
      _error = null;
    });
    try {
      await ref.read(sessionsRepositoryProvider).setPrivateNote(widget.sessionId, _text.text.trim());
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      ref.invalidate(privateNoteProvider(widget.sessionId));
      await Future<void>.delayed(Motion.of(context).reduced ? Duration.zero : Motion.slow);
      if (mounted) {
        setState(() {
          _status = SubmitStatus.idle;
          _editing = false;
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _error = l10n.fieldError(error.fieldCodes['text']) ?? l10n.apiError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final note = ref.watch(privateNoteProvider(widget.sessionId));
    if (_editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrivateNoteField(controller: _text, enabled: _status == SubmitStatus.idle, error: _error, autofocus: true),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _status == SubmitStatus.idle ? () => setState(() => _editing = false) : null,
                child: Text(l10n.adminCancel),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 140, child: SubmitButton(label: l10n.adminSave, status: _status, onPressed: _save)),
            ],
          ),
        ],
      );
    }
    return SectionCard(
      title: l10n.sessionPrivateNote,
      subtitle: l10n.sessionPrivateNoteHint,
      icon: Icons.lock_outline,
      trailing: note.hasValue
          ? TextButton.icon(
              onPressed: () {
                _text.text = note.value?.text ?? '';
                setState(() => _editing = true);
              },
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.patientEdit),
            )
          : null,
      child: AsyncStateSwitcher(
        value: note,
        loading: (context) => const SkeletonLoading(loading: true, child: Text('———————————————')),
        error: (context, error) => AdminErrorView(error: error, compact: true, onRetry: () => ref.invalidate(privateNoteProvider(widget.sessionId))),
        data: (context, note) => Text(
          note.text ?? l10n.sessionNoPrivateNote,
          style: note.text == null
              ? theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)
              : theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Delete (BR-S7), or why it isn't possible, for callers with `sessionsDelete`.
class _DeleteArea extends StatelessWidget {
  const _DeleteArea({required this.session, required this.clinic, required this.busy, required this.onDelete});

  final SessionView session;
  final ClinicContext clinic;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (session.can.delete) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: scheme.error, side: BorderSide(color: scheme.error, width: 1.5)),
        onPressed: busy ? null : onDelete,
        icon: const Icon(Icons.delete_outline),
        label: Text(l10n.sessionDelete),
      );
    }
    final reason = session.can.deleteBlockedReason;
    if (!clinic.can(ClinicPermission.sessionsDelete) || reason == null) return const SizedBox.shrink();
    return Row(
      children: [
        ExcludeSemantics(child: Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            reason == DeleteBlock.notLatest ? l10n.sessionNotDeletableLatest : l10n.sessionNotDeletableDay,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog();

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final l10n = AppLocalizations.of(context);
    final text = _reason.text.trim();
    if (text.length < 3) {
      setState(() => _error = l10n.sessionDeleteReasonRequired);
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.delete_outline, color: scheme.error),
      title: Text(l10n.sessionDeleteTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.sessionDeleteBody),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              autofocus: true,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.sessionDeleteReason, errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.adminCancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: _confirm,
          child: Text(l10n.sessionDeleteConfirm),
        ),
      ],
    );
  }
}

/// BR-S10: change the amount charged on the session's day.
class _AmountDialog extends ConsumerStatefulWidget {
  const _AmountDialog({required this.session});

  final SessionView session;

  @override
  ConsumerState<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends ConsumerState<_AmountDialog> {
  late final _amount = TextEditingController(text: AmountRules.text(widget.session.amountChargedPiasters));
  late PaymentMethod? _method = widget.session.paymentMethod;
  late bool _free = widget.session.amountChargedPiasters == 0;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final parsed = _free ? (piasters: 0, problem: null) : AmountRules.parse(_amount.text, required: true);
    if (parsed.problem != null) {
      setState(() => _error = switch (parsed.problem!) {
            AmountProblem.required => l10n.sessionAmountRequired,
            AmountProblem.invalid => l10n.adminErrorInvalidValue,
            AmountProblem.outOfRange => l10n.adminErrorOutOfRange,
          });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await ref.read(sessionsRepositoryProvider).updateAmountCharged(
            widget.session.sessionId,
            amountChargedPiasters: parsed.piasters!,
            paymentMethod: _method,
          );
      if (mounted) Navigator.pop(context, updated);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.fieldError(error.fieldCodes['amountChargedPiasters']) ?? l10n.apiError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final list = widget.session.listPricePiasters;
    return AlertDialog(
      title: Text(l10n.sessionEditAmount),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (list != null) Text(l10n.sessionVisitPrice(AppFormat.egp(context, list))),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                enabled: !_busy && !_free,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textDirection: TextDirection.ltr,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,٫]')), LengthLimitingTextInputFormatter(10)],
                decoration: InputDecoration(labelText: l10n.sessionAmountLabel, suffixText: l10n.sessionCurrency, errorText: _error),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _free,
                onChanged: _busy
                    ? null
                    : (on) => setState(() {
                          _free = on;
                          if (on) _amount.text = '0';
                        }),
                title: Text(l10n.sessionFreeVisit),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in PaymentMethod.values)
                    ChoiceChip(
                      label: Text(paymentMethodLabel(l10n, method)),
                      selected: _method == method,
                      onSelected: _busy ? null : (on) => setState(() => _method = on ? method : null),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(l10n.sessionAmountLogged, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l10n.adminCancel)),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.adminSave)),
      ],
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('—————————', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const Card(child: SizedBox(height: 180, child: Center(child: Text('————————————')))),
          const SizedBox(height: 16),
          const Card(child: SizedBox(height: 240, child: Center(child: Text('————————————')))),
        ],
      );
}
