import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../core/widgets/success_check.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../../sessions/application/sessions_providers.dart';
import '../application/prescriptions_providers.dart';
import '../application/rx_pdf_source.dart';
import '../application/rx_printer.dart';
import '../data/prescriptions_repository.dart';
import '../domain/prescription_models.dart';
import '../pdf/rx_text.dart';
import 'prescription_editor.dart' show PrescriptionEditor, RxActionBar;
import 'widgets/rx_widgets.dart';

/// The PDF to show: a draft's is built on the device (doctor only); a sent
/// or cancelled document's is the stored one (BR-RX5: what Reprint prints).
final rxPdfBytesProvider = FutureProvider.autoDispose.family<Uint8List, ({String id, DateTime updatedAt})>((ref, key) async {
  final rx = await ref.watch(prescriptionProvider(key.id).future);
  if (rx.hasPdf) return ref.read(prescriptionsRepositoryProvider).pdf(rx.prescriptionId);
  return ref.read(rxPdfSourceProvider).build(rx);
});

/// D15 preview and send, and AS8 for assistants with `prescriptionsPrint`.
///
/// - A draft (doctor): Send to patient, Send and print («إرسال وطباعة؟»,
///   BR-RX5: printing a draft sends it), Edit, Save as template.
/// - Sent: Print again (the stored PDF), Share, Print all, Cancel with a
///   reason, Issue new copy.
/// - Cancelled: no Print (BR-RX5); Issue new copy.
class PrescriptionView extends ConsumerStatefulWidget {
  const PrescriptionView({super.key, required this.rx, required this.clinic});

  final Prescription rx;
  final ClinicContext clinic;

  @override
  ConsumerState<PrescriptionView> createState() => _PrescriptionViewState();
}

class _PrescriptionViewState extends ConsumerState<PrescriptionView> {
  bool _busy = false;
  bool _justSent = false;
  String? _error;

  Prescription get _rx => widget.rx;
  ClinicContext get _clinic => widget.clinic;

  String get _fileName {
    final day = (_rx.sentAt ?? _rx.createdAt).toIso8601String().substring(0, 10);
    return _rx.kind == PrescriptionKind.medication ? 'prescription-$day.pdf' : 'request-$day.pdf';
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).apiError(error));
    } on Object {
      if (mounted) setState(() => _error = AppLocalizations.of(context).rxPrintFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Send to patient, optionally printing the same bytes (BR-RX4, BR-RX5).
  Future<void> _send({required bool print}) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: print ? l10n.rxSendAndPrintTitle : l10n.rxSendTitle,
      message: print ? l10n.rxSendAndPrintBody : l10n.rxSendBody,
      confirmLabel: print ? l10n.rxSendAndPrint : l10n.rxSend,
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      final pdf = await ref.read(rxPdfSourceProvider).build(_rx);
      await ref.read(prescriptionsRepositoryProvider).send(_rx.prescriptionId, pdf);
      if (!mounted) return;
      setState(() => _justSent = true);
      itemHistoryChanged(ref);
      if (print) await ref.read(rxPrinterProvider).print(pdf, name: _fileName);
      if (!mounted) return;
      showAdminSnack(context, l10n.rxSent);
      prescriptionsChanged(ref, patientId: _rx.patientId, sessionId: _rx.sessionId, prescriptionId: _rx.prescriptionId);
    });
  }

  Future<void> _print() => _run(() async {
        final pdf = await ref.read(prescriptionsRepositoryProvider).pdf(_rx.prescriptionId);
        await ref.read(rxPrinterProvider).print(pdf, name: _fileName);
      });

  Future<void> _share() => _run(() async {
        final pdf = await ref.read(prescriptionsRepositoryProvider).pdf(_rx.prescriptionId);
        await ref.read(rxPrinterProvider).share(pdf, fileName: _fileName);
      });

  /// BR-RX5 Print all: the session's sent documents in one job.
  Future<void> _printAll(List<Prescription> sent) => _run(() async {
        final repository = ref.read(prescriptionsRepositoryProvider);
        final pdfs = [for (final rx in sent) await repository.pdf(rx.prescriptionId)];
        await ref.read(rxPrinterProvider).printAll(pdfs, name: 'session-${_rx.sessionId}');
      });

  Future<void> _cancel() async {
    final l10n = AppLocalizations.of(context);
    final reason = await askRxCancelReason(context);
    if (reason == null || !mounted) return;
    await _run(() async {
      await ref.read(prescriptionsRepositoryProvider).cancel(_rx.prescriptionId, reason);
      if (!mounted) return;
      showAdminSnack(context, l10n.rxCancelled);
      prescriptionsChanged(ref, patientId: _rx.patientId, sessionId: _rx.sessionId, prescriptionId: _rx.prescriptionId);
    });
  }

  /// "Issue new copy": a draft pre-filled from this one (D15).
  Future<void> _newCopy() => _run(() async {
        final copy = await ref
            .read(prescriptionsRepositoryProvider)
            .createDraft(sessionId: _rx.sessionId, kind: _rx.kind, copyFromId: _rx.prescriptionId);
        if (!mounted) return;
        prescriptionsChanged(ref, patientId: _rx.patientId, sessionId: _rx.sessionId, prescriptionId: _rx.prescriptionId);
        context.pushReplacement(ref.read(clinicPathsProvider).prescription(_rx.patientId, copy.prescriptionId));
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paths = ref.watch(clinicPathsProvider);
    final session = ref.watch(sessionProvider(_rx.sessionId)).value;
    final doctor = _clinic.isDoctor;
    final draft = _rx.status.editable;
    final sent = _rx.status == PrescriptionStatus.sent;
    final cancelled = _rx.status == PrescriptionStatus.cancelled;
    final siblings = ref.watch(sessionPrescriptionsProvider(_rx.sessionId)).value ?? const [];
    final sentInSession = [for (final rx in siblings) if (rx.status == PrescriptionStatus.sent) rx];
    final canPrintAll = sent &&
        _clinic.canPrintRx &&
        sentInSession.length >= 2 &&
        sentInSession.map((rx) => rx.kind).toSet().length == PrescriptionKind.values.length;
    final subtitle = session == null
        ? null
        : '${session.patientName}${l10n.adminListSeparator}${ClinicFormat.day(context, session.day)}';

    final actions = <Widget>[
      if (draft && _clinic.canDraftRx)
        OutlinedButton.icon(
          onPressed: _busy ? null : () => context.pushReplacement(paths.prescription(_rx.patientId, _rx.prescriptionId)),
          icon: const Icon(Icons.edit_outlined),
          label: Text(l10n.rxEdit),
        ),
      if (draft && _clinic.canSendRx) ...[
        OutlinedButton.icon(
          onPressed: _busy || _rx.isEmpty ? null : () => _send(print: true),
          icon: const Icon(Icons.print_outlined),
          label: Text(l10n.rxSendAndPrint),
        ),
        FilledButton.icon(
          onPressed: _busy || _rx.isEmpty ? null : () => _send(print: false),
          icon: const Icon(Icons.send_outlined),
          label: Text(l10n.rxSend),
        ),
      ],
      if (sent && _clinic.canPrintRx) ...[
        OutlinedButton.icon(onPressed: _busy ? null : _share, icon: const Icon(Icons.ios_share), label: Text(l10n.rxShare)),
        if (canPrintAll)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _printAll(sentInSession),
            icon: const Icon(Icons.print_outlined),
            label: Text(l10n.rxPrintAll),
          ),
        FilledButton.icon(onPressed: _busy ? null : _print, icon: const Icon(Icons.print), label: Text(l10n.rxPrint)),
      ],
    ];

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final gutter = clinicGutter(width);
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
                child: ClinicHeader(
                  title: rxKindName(l10n, _rx.kind),
                  subtitle: subtitle,
                  backFallback: paths.patient(_rx.patientId),
                  trailingTitle: RxStatusPill(status: _rx.status),
                  actions: [
                    if (doctor)
                      PopupMenuButton<String>(
                        tooltip: l10n.rxMore,
                        onSelected: (value) => switch (value) {
                          'template' => saveRxAsTemplate(context, ref, kind: _rx.kind, items: _rx.toInput()),
                          'cancel' => _cancel(),
                          'copy' => _newCopy(),
                          _ => null,
                        },
                        itemBuilder: (context) => [
                          if (!_rx.isEmpty) PopupMenuItem(value: 'template', child: Text(l10n.rxSaveAsTemplate)),
                          if (sent && _clinic.canSendRx) PopupMenuItem(value: 'cancel', child: Text(l10n.rxCancelAction)),
                          if ((sent || cancelled) && _rx.replacedById == null && _clinic.canDraftRx)
                            PopupMenuItem(value: 'copy', child: Text(l10n.rxNewCopy)),
                        ],
                      ),
                  ],
                ),
              ),
              if (cancelled)
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
                  child: _CancelledBanner(rx: _rx, onNewCopy: _clinic.canDraftRx && _rx.replacedById == null ? _newCopy : null),
                ),
              if (_justSent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox.square(dimension: 72, child: SuccessCheck(onCompleted: () {
                    if (mounted) setState(() => _justSent = false);
                  })),
                ),
              Expanded(child: _Preview(rx: _rx, doctor: doctor)),
              if (actions.isNotEmpty || _error != null)
                RxActionBar(
                  gutter: gutter,
                  bottomInset: MediaQuery.paddingOf(context).bottom,
                  error: _error,
                  children: actions,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CancelledBanner extends StatelessWidget {
  const _CancelledBanner({required this.rx, this.onNewCopy});

  final Prescription rx;
  final VoidCallback? onNewCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.block, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                rx.cancelReason == null ? l10n.rxCancelledNotice : l10n.rxCancelledReason(rx.cancelReason!),
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            if (onNewCopy != null) TextButton(onPressed: onNewCopy, child: Text(l10n.rxNewCopy)),
          ],
        ),
      ),
    );
  }
}

/// The PDF, or the items as a list for an assistant looking at a draft (the
/// header data behind the PDF is the doctor's).
class _Preview extends ConsumerWidget {
  const _Preview({required this.rx, required this.doctor});

  final Prescription rx;
  final bool doctor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!rx.hasPdf && !doctor) return _ItemsList(rx: rx);
    final pdf = ref.watch(rxPdfBytesProvider((id: rx.prescriptionId, updatedAt: rx.updatedAt)));
    final view = ref.watch(rxPdfViewProvider);
    return AsyncStateSwitcher<Uint8List>(
      value: pdf,
      loading: (context) => const SkeletonLoading(loading: true, child: _PageSkeleton()),
      error: (context, error) => AdminErrorView(
        error: error,
        onRetry: () => ref.invalidate(rxPdfBytesProvider((id: rx.prescriptionId, updatedAt: rx.updatedAt))),
      ),
      data: (context, bytes) => ClipRect(child: view(bytes)),
    );
  }
}

class _PageSkeleton extends StatelessWidget {
  const _PageSkeleton();

  @override
  Widget build(BuildContext context) => Center(
        child: AspectRatio(
          aspectRatio: 148 / 210,
          child: Container(margin: const EdgeInsets.all(24), color: Theme.of(context).colorScheme.surfaceContainerHigh),
        ),
      );
}

class _ItemsList extends StatelessWidget {
  const _ItemsList({required this.rx});

  final Prescription rx;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (rx.diagnosis != null) InfoRow(label: l10n.rxDiagnosis, value: rx.diagnosis!),
        const SizedBox(height: 12),
        for (final item in rx.medications)
          ListTile(
            leading: const Icon(Icons.medication_outlined),
            title: Text([item.drugName, ?item.strength].join(' · ')),
            subtitle: Text(rxInstructionLine(l10n, item)),
            trailing: item.duration == null ? null : Text(rxDurationLabel(l10n, item.duration!), style: theme.textTheme.bodySmall),
          ),
        for (final item in rx.investigations)
          ListTile(
            leading: Icon(item.category == InvestigationCategory.lab ? Icons.science_outlined : Icons.settings_overscan_outlined),
            title: Text(item.name),
            subtitle: item.notes == null ? null : Text(item.notes!),
          ),
        if (rx.advice != null) ...[
          const SizedBox(height: 12),
          InfoRow(label: rx.kind == PrescriptionKind.medication ? l10n.rxAdvice : l10n.rxRequestNotes, value: rx.advice!),
        ],
      ],
    );
  }
}

/// The router's entry for one prescription: the editor while it's a draft
/// the caller may edit, otherwise D15.
class PrescriptionPage extends ConsumerWidget {
  const PrescriptionPage({super.key, required this.prescriptionId, this.preview = false});

  final String prescriptionId;

  /// D15 even for an editable draft.
  final bool preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(clinicPathsProvider);
    return Scaffold(
      body: ClinicGate(
        builder: (context, clinic) => AsyncStateSwitcher<Prescription>(
          value: ref.watch(prescriptionProvider(prescriptionId)),
          loading: (context) => const SkeletonLoading(loading: true, child: _PageSkeleton()),
          error: (context, error) => Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, top: 8),
                child: Align(alignment: AlignmentDirectional.centerStart, child: ClinicBackButton(fallback: paths.patients)),
              ),
              Expanded(child: AdminErrorView(error: error, onRetry: () => ref.invalidate(prescriptionProvider(prescriptionId)))),
            ],
          ),
          data: (context, rx) => AnimatedSwitcher(
            duration: Motion.normal,
            switchInCurve: Motion.enterCurve,
            switchOutCurve: Motion.exitCurveReversed,
            child: !preview && rx.status.editable && clinic.canDraftRx
                ? PrescriptionEditor(key: ValueKey(('edit', rx.prescriptionId)), rx: rx, clinic: clinic)
                : PrescriptionView(key: ValueKey(('view', rx.prescriptionId, rx.status)), rx: rx, clinic: clinic),
          ),
        ),
      ),
    );
  }
}
