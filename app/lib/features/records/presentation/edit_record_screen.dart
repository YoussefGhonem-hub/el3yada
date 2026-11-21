import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/shake_on_error.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../clinic_admin/presentation/widgets/clinic_admin_widgets.dart' show ClinicPage;
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../application/records_providers.dart';
import '../data/records_repository.dart';
import '../domain/record_models.dart';
import 'record_form.dart';
import 'record_text.dart';

/// D12 "edit details" and "change category" (AS6 too): the same form as
/// the upload, every field replaced. Pops with true when saved.
class EditRecordScreen extends ConsumerWidget {
  const EditRecordScreen({super.key, required this.patientId, required this.recordId});

  final String patientId;
  final String recordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(clinicPathsProvider);
    return Scaffold(
      body: ClinicGate(
        builder: (context, clinic) {
          if (!clinic.can(ClinicPermission.filesManage)) {
            return AdminErrorView(error: const ApiException(kind: ApiErrorKind.http, status: 403, code: ApiCodes.permissionDenied));
          }
          if (clinic.isSuspended) return SuspendedNotice(backFallback: paths.record(patientId, recordId));
          final record = ref.watch(recordProvider(recordId));
          return switch (record) {
            AsyncData(:final value) => _EditForm(patientId: patientId, record: value),
            AsyncError(:final error) => AdminErrorView(error: error, onRetry: () => ref.invalidate(recordProvider(recordId))),
            _ => const Center(child: CircularProgressIndicator()),
          };
        },
      ),
    );
  }
}

class _EditForm extends ConsumerStatefulWidget {
  const _EditForm({required this.patientId, required this.record});

  final String patientId;
  final MedicalRecordView record;

  @override
  ConsumerState<_EditForm> createState() => _EditFormState();
}

class _EditFormState extends ConsumerState<_EditForm> {
  final _form = GlobalKey<RecordFormState>();
  SubmitStatus _status = SubmitStatus.idle;
  Map<String, String> _fieldErrors = const {};
  String? _error;
  int _failures = 0;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final draft = _form.currentState?.validate();
    if (draft == null) {
      setState(() => _failures++);
      return;
    }
    setState(() {
      _status = SubmitStatus.loading;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await ref.read(recordsRepositoryProvider).updateRecord(widget.record.recordId, draft);
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      recordsChanged(ref, recordId: widget.record.recordId);
      showAdminSnack(context, l10n.recordUpdated);
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(ref.read(clinicPathsProvider).record(widget.patientId, widget.record.recordId));
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _failures++;
        _fieldErrors = recordFieldErrors(l10n, error.fieldCodes);
        _error = _fieldErrors.isEmpty ? l10n.recordError(error) : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final paths = ref.watch(clinicPathsProvider);
    return ClinicPage(
      maxWidth: 640,
      builder: (context, width) => [
        ClinicHeader(
          title: l10n.recordEditTitle,
          subtitle: widget.record.title,
          backFallback: paths.record(widget.patientId, widget.record.recordId),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: l10n.recordDetailsHeading,
          icon: Icons.edit_note_outlined,
          child: RecordForm(
            key: _form,
            patientId: widget.patientId,
            initial: widget.record.toDraft(),
            fieldErrors: _fieldErrors,
            enabled: _status == SubmitStatus.idle,
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
          ),
        ShakeOnError(trigger: _failures, child: SubmitButton(label: l10n.adminSave, status: _status, onPressed: _save)),
      ],
    );
  }
}
