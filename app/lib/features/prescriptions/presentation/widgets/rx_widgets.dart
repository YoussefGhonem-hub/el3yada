import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../clinic/domain/clinic_context.dart';
import '../../../clinic/domain/clinic_permissions.dart';
import '../../../patients/clinic_paths.dart';
import '../../../patients/presentation/widgets/clinic_ui.dart';
import '../../application/prescriptions_providers.dart';
import '../../data/prescriptions_repository.dart';
import '../../domain/prescription_models.dart';
import '../../pdf/rx_text.dart';

/// What the caller may do with prescriptions (spec 6.10, AS7, AS8).
extension RxAbilities on ClinicContext {
  /// Create and edit drafts: the doctor, or `prescriptionsDraft`. Never while suspended (BR-G5).
  bool get canDraftRx => can(ClinicPermission.prescriptionsDraft) && !isSuspended;

  /// See prescriptions at all: `clinicalView` (every status) or `prescriptionsPrint` (sent ones).
  bool get canReadRx => can(ClinicPermission.clinicalView) || can(ClinicPermission.prescriptionsPrint);

  /// Send, cancel and issue copies: the doctor only.
  bool get canSendRx => isDoctor && !isSuspended;

  /// Print and share sent documents (AS8).
  bool get canPrintRx => isDoctor || can(ClinicPermission.prescriptionsPrint);
}

/// The status as a pill: never colour alone.
class RxStatusPill extends StatelessWidget {
  const RxStatusPill({super.key, required this.status});

  final PrescriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (status) {
      PrescriptionStatus.draft => StatusPill(label: l10n.rxStatusDraft, icon: Icons.edit_note_outlined),
      PrescriptionStatus.readyForReview =>
        StatusPill(label: l10n.rxStatusReadyForReview, tone: PillTone.accent, icon: Icons.rate_review_outlined),
      PrescriptionStatus.sent => StatusPill(label: l10n.rxStatusSent, tone: PillTone.positive, icon: Icons.check_circle_outline),
      PrescriptionStatus.cancelled => StatusPill(label: l10n.rxStatusCancelled, tone: PillTone.danger, icon: Icons.block),
    };
  }
}

IconData rxKindIcon(PrescriptionKind kind) =>
    kind == PrescriptionKind.medication ? Icons.medication_outlined : Icons.biotech_outlined;

/// One prescription in D6's tab and D9's card: kind, date, the first
/// items, the status, and who prepared it (BR-AS10, the doctor only).
class PrescriptionTile extends StatelessWidget {
  const PrescriptionTile({super.key, required this.rx, required this.showPreparedBy, required this.onTap});

  final Prescription rx;
  final bool showPreparedBy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cancelled = rx.status == PrescriptionStatus.cancelled;
    final names = rx.kind == PrescriptionKind.medication
        ? [for (final item in rx.medications) item.drugName]
        : [for (final item in rx.investigations) item.name];
    final summary = names.isEmpty ? l10n.rxNoItems : names.take(3).join(l10n.rxListSeparator) + (names.length > 3 ? '…' : '');
    final preparedBy = rx.preparedBy;
    return Pressable(
      onTap: onTap,
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(rxKindIcon(rx.kind), color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(rxKindName(l10n, rx.kind), style: theme.textTheme.titleSmall),
                        RxStatusPill(status: rx.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: cancelled ? TextDecoration.lineThrough : null,
                        color: cancelled ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        ClinicFormat.dayAuto(context, rx.sentAt ?? rx.createdAt),
                        l10n.rxItemCount(rx.itemCount),
                        if (showPreparedBy && preparedBy != null && preparedBy.isAssistant) l10n.rxPreparedBy(preparedBy.name),
                      ].join(l10n.adminListSeparator),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right,
                  color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks the kind: «روشتة علاج» or «روشتة تحاليل وأشعة».
Future<PrescriptionKind?> pickRxKind(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<PrescriptionKind>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(l10n.rxNewTitle, style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final kind in PrescriptionKind.values)
            ListTile(
              leading: Icon(rxKindIcon(kind)),
              title: Text(rxKindName(l10n, kind)),
              subtitle: Text(kind == PrescriptionKind.medication ? l10n.rxKindMedicationHint : l10n.rxKindInvestigationsHint),
              onTap: () => Navigator.of(context).pop(kind),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// BR-RX1: a new draft on [sessionId], then its editor (D13/D14).
Future<void> createRxDraft(
  BuildContext context,
  WidgetRef ref, {
  required String patientId,
  required String sessionId,
  PrescriptionKind? kind,
}) async {
  final l10n = AppLocalizations.of(context);
  final chosen = kind ?? await pickRxKind(context);
  if (chosen == null || !context.mounted) return;
  try {
    final rx = await ref.read(prescriptionsRepositoryProvider).createDraft(sessionId: sessionId, kind: chosen);
    if (!context.mounted) return;
    prescriptionsChanged(ref, patientId: patientId, sessionId: sessionId);
    await context.push(ref.read(clinicPathsProvider).prescription(patientId, rx.prescriptionId));
  } on ApiException catch (error) {
    if (context.mounted) showAdminSnack(context, l10n.apiError(error), error: true);
  }
}

/// A reason of 3–500 characters (cancel, BR-RX2).
Future<String?> askRxCancelReason(BuildContext context) => showDialog<String>(
      context: context,
      builder: (context) => const _ReasonDialog(),
    );

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final text = _reason.text.trim();
    if (text.length < 3) {
      setState(() => _error = l10n.adminErrorReasonRequired);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l10n.rxCancelTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.rxCancelBody),
            const SizedBox(height: 16),
            TextField(
              controller: _reason,
              autofocus: true,
              maxLength: 500,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(labelText: l10n.rxCancelReason, errorText: _error),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.adminCancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: _submit,
          child: Text(l10n.rxCancelConfirm),
        ),
      ],
    );
  }
}

/// A template's name (≤ 100), for "Save as template" and "Rename".
Future<String?> askRxTemplateName(BuildContext context, {String? initial, required String title}) => showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(initial: initial, title: title),
    );

class _NameDialog extends StatefulWidget {
  const _NameDialog({this.initial, required this.title});

  final String? initial;
  final String title;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _name.text.trim();
    if (text.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).errorRequired);
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: TextField(
          controller: _name,
          autofocus: true,
          maxLength: 100,
          decoration: InputDecoration(labelText: l10n.rxTemplateName, errorText: _error),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.adminCancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.adminSave)),
      ],
    );
  }
}

/// "Save as template" [S] (BR-RX6).
Future<void> saveRxAsTemplate(BuildContext context, WidgetRef ref, {required PrescriptionKind kind, required PrescriptionDraftInput items}) async {
  final l10n = AppLocalizations.of(context);
  final name = await askRxTemplateName(context, title: l10n.rxSaveAsTemplate);
  if (name == null || !context.mounted) return;
  try {
    await ref.read(prescriptionsRepositoryProvider).createTemplate(name: name, kind: kind, items: items, advice: items.advice);
    ref.invalidate(templatesProvider);
    if (context.mounted) showAdminSnack(context, l10n.rxTemplateSaved);
  } on ApiException catch (error) {
    if (context.mounted) showAdminSnack(context, l10n.apiError(error), error: true);
  }
}

/// A date field for zone 6: «موعد المتابعة» or «إحضار النتائج في».
class RxDateField extends StatelessWidget {
  const RxDateField({super.key, required this.label, required this.value, required this.onChanged, required this.from, this.enabled = true});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime from;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
          enabled: enabled,
          suffixIcon: value == null || !enabled
              ? null
              : IconButton(tooltip: l10n.rxClearDate, icon: const Icon(Icons.close), onPressed: () => onChanged(null)),
        ),
        child: value == null ? null : Text(ClinicFormat.day(context, value!)),
      ),
    );
  }
}
