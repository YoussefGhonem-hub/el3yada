import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../sessions/data/sessions_repository.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../../sessions/domain/session_models.dart';
import '../application/prescriptions_providers.dart';
import '../application/rx_printer.dart';
import '../data/prescriptions_repository.dart';
import '../domain/prescription_models.dart';
import 'widgets/rx_widgets.dart';

/// D9: the session's prescriptions and requests, "New" for those who may
/// draft, and Print all when both kinds were sent (BR-RX5).
class SessionPrescriptionsCard extends ConsumerStatefulWidget {
  const SessionPrescriptionsCard({super.key, required this.session, required this.clinic});

  final SessionView session;
  final ClinicContext clinic;

  @override
  ConsumerState<SessionPrescriptionsCard> createState() => _SessionPrescriptionsCardState();
}

class _SessionPrescriptionsCardState extends ConsumerState<SessionPrescriptionsCard> {
  bool _printing = false;

  Future<void> _printAll(List<Prescription> sent) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _printing = true);
    try {
      final repository = ref.read(prescriptionsRepositoryProvider);
      final pdfs = [for (final rx in sent) await repository.pdf(rx.prescriptionId)];
      await ref.read(rxPrinterProvider).printAll(pdfs, name: 'session-${widget.session.sessionId}');
    } on ApiException catch (error) {
      if (mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    } on Object {
      if (mounted) showAdminSnack(context, l10n.rxPrintFailed, error: true);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = widget.session;
    final clinic = widget.clinic;
    final paths = ref.watch(clinicPathsProvider);
    final state = ref.watch(sessionPrescriptionsProvider(session.sessionId));
    final list = state.value ?? const <Prescription>[];
    final sent = [for (final rx in list) if (rx.status == PrescriptionStatus.sent) rx];
    final canPrintAll = clinic.canPrintRx && sent.map((rx) => rx.kind).toSet().length == PrescriptionKind.values.length;
    return SectionCard(
      title: l10n.rxSessionCardTitle,
      icon: Icons.medication_outlined,
      trailing: canPrintAll
          ? TextButton.icon(
              onPressed: _printing ? null : () => _printAll(sent),
              icon: const Icon(Icons.print_outlined),
              label: Text(l10n.rxPrintAll),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StateSwitcher(
            state: state.isLoading && !state.hasValue
                ? ViewState.loading
                : state.hasError && !state.hasValue
                    ? ViewState.error
                    : list.isEmpty
                        ? ViewState.empty
                        : ViewState.content,
            loading: (context) => SkeletonLoading(loading: true, child: _placeholderTile()),
            error: (context) => AdminErrorView(
              error: state.error!,
              compact: true,
              onRetry: () => ref.invalidate(sessionPrescriptionsProvider(session.sessionId)),
            ),
            empty: (context) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.rxSessionEmpty, style: Theme.of(context).textTheme.bodyMedium),
            ),
            content: (context) => StaggerGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, rx) in list.indexed)
                    StaggeredEntrance(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PrescriptionTile(
                          rx: rx,
                          showPreparedBy: clinic.isDoctor,
                          onTap: () => context.push(paths.prescription(session.patientId, rx.prescriptionId)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (clinic.canDraftRx) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in PrescriptionKind.values)
                  FilledButton.tonalIcon(
                    onPressed: () => createRxDraft(
                      context,
                      ref,
                      patientId: session.patientId,
                      sessionId: session.sessionId,
                      kind: kind,
                    ),
                    icon: Icon(rxKindIcon(kind)),
                    label: Text(kind == PrescriptionKind.medication ? l10n.rxNewMedication : l10n.rxNewInvestigations),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholderTile() => PrescriptionTile(
        rx: Prescription(
          prescriptionId: '',
          patientId: '',
          sessionId: '',
          kind: PrescriptionKind.medication,
          status: PrescriptionStatus.sent,
          medications: const [MedicationItem(drugName: 'Placeholder medicine')],
          qrShortCode: '',
          qrUrl: '',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
        showPreparedBy: false,
        onTap: () {},
      );
}

/// D6 / AS4 Prescriptions tab: newest first; cancelled ones struck through,
/// documents ready for review flagged for the doctor.
class PatientPrescriptionsTab extends ConsumerWidget {
  const PatientPrescriptionsTab({super.key, required this.patientId, required this.clinic});

  final String patientId;
  final ClinicContext clinic;

  /// BR-RX1: from the profile, the doctor picks one of today's sessions (or
  /// records one first).
  Future<void> _new(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final paths = ref.read(clinicPathsProvider);
    final kind = await pickRxKind(context);
    if (kind == null || !context.mounted) return;
    List<SessionListItem> today;
    try {
      final page = await ref.read(sessionsRepositoryProvider).patientSessions(patientId);
      final day = ClinicFormat.today();
      today = [for (final s in page.items) if (s.day == day) s];
    } on ApiException catch (error) {
      if (context.mounted) showAdminSnack(context, l10n.apiError(error), error: true);
      return;
    }
    if (!context.mounted) return;
    if (today.isEmpty) {
      final record = await confirmAction(
        context,
        title: l10n.rxNoSessionTodayTitle,
        message: l10n.rxNoSessionTodayBody,
        confirmLabel: l10n.sessionNew,
      );
      if (record && context.mounted) await context.push(paths.newSession(patientId));
      return;
    }
    final session = today.length == 1
        ? today.single
        : await showModalBottomSheet<SessionListItem>(
            context: context,
            showDragHandle: true,
            builder: (context) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Text(l10n.rxPickSession, style: Theme.of(context).textTheme.titleMedium),
                  ),
                  for (final s in today)
                    ListTile(
                      leading: TypeBadge(s.type),
                      title: Text(ClinicFormat.time(context, s.at)),
                      subtitle: Text(s.branch.name(Localizations.localeOf(context).languageCode)),
                      onTap: () => Navigator.of(context).pop(s),
                    ),
                ],
              ),
            ),
          );
    if (session == null || !context.mounted) return;
    await createRxDraft(context, ref, patientId: patientId, sessionId: session.sessionId, kind: kind);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final paths = ref.watch(clinicPathsProvider);
    final state = ref.watch(patientPrescriptionsProvider(patientId));
    final controller = ref.read(patientPrescriptionsProvider(patientId).notifier);
    final canNew = clinic.canDraftRx;
    final newButton = canNew
        ? Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonalIcon(
              onPressed: () => _new(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.rxNewTitle),
            ),
          )
        : null;
    return StateSwitcher(
      state: state.view,
      loading: (context) => SkeletonLoading(
        loading: true,
        child: Column(children: [for (var i = 0; i < 2; i++) const SizedBox(height: 96)]),
      ),
      error: (context) => AdminErrorView(error: state.error!, compact: true, onRetry: controller.reload),
      empty: (context) => EmptyState(
        title: l10n.rxEmptyTitle,
        message: canNew ? l10n.rxEmptyBody : null,
        actionLabel: canNew ? l10n.rxNewTitle : null,
        onAction: canNew ? () => _new(context, ref) : null,
      ),
      content: (context) => StaggerGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?newButton,
            const SizedBox(height: 8),
            for (final (i, rx) in state.items.indexed)
              StaggeredEntrance(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PrescriptionTile(
                    rx: rx,
                    showPreparedBy: clinic.isDoctor,
                    onTap: () => context.push(paths.prescription(patientId, rx.prescriptionId)),
                  ),
                ),
              ),
            if (state.moreError != null)
              AdminErrorView(error: state.moreError!, compact: true, onRetry: controller.loadMore)
            else if (state.hasMore)
              Center(
                child: TextButton(
                  onPressed: state.loadingMore ? null : controller.loadMore,
                  child: Text(state.loadingMore ? l10n.loading : l10n.patientLoadMore),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
