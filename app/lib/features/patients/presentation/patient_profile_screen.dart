import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format/app_format.dart';
import '../../../core/network/api_error.dart' show ApiErrorMessage;
import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../core/widgets/temporary_password_dialog.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../appointments/domain/appointment_models.dart' show Appointment, AppointmentStatus, PatientLookup;
import '../../appointments/presentation/appointment_format.dart' show AppointmentFormat, StatusChip;
import '../../chat/chat_data.dart' show chatRepositoryProvider;
import '../../clinic/domain/clinic_context.dart';
import '../../clinic/domain/clinic_permissions.dart';
import '../../records/presentation/files_tab.dart';
import '../../sessions/domain/session_models.dart';
import '../application/patients_providers.dart';
import '../clinic_paths.dart';
import '../data/patients_repository.dart';
import '../domain/patient_models.dart';
import '../../patient/domain/patient_models.dart' show BranchRef, DoctorRef;
import 'widgets/clinic_ui.dart';
import 'widgets/patient_text.dart';
import '../../prescriptions/presentation/rx_sections.dart';
import '../../prescriptions/presentation/widgets/rx_widgets.dart' show RxAbilities;

/// D6 / AS4 as a page: phones (a register card grows into it) and links
/// (`/doctor/patients/{patientId}`, after D5).
class PatientProfilePage extends StatelessWidget {
  const PatientProfilePage({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context) => Scaffold(body: PatientProfileView(patientId: patientId, showBack: true));
}

/// D6 / AS4: header, file summary, actions and the tabs the caller may see
/// (spec 7.6: Overview needs `clinicalView`; Sessions `sessionsCreate` or
/// `clinicalView`). Full screen, or the right side of D4 on desktop.
class PatientProfileView extends ConsumerWidget {
  const PatientProfileView({super.key, required this.patientId, this.showBack = false, this.onClose});

  final String patientId;
  final bool showBack;

  /// The desktop pane's close button.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = ref.watch(clinicPathsProvider);
    return ClinicGate(
      builder: (context, clinic) => AsyncStateSwitcher<PatientView>(
        value: ref.watch(patientProvider(patientId)),
        loading: (context) => const _ProfileSkeleton(),
        error: (context, error) => Column(
          children: [
            if (showBack)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, top: 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ClinicBackButton(fallback: paths.patients),
                ),
              ),
            Expanded(
              child: AdminErrorView(error: error, onRetry: () => ref.invalidate(patientProvider(patientId))),
            ),
          ],
        ),
        data: (context, patient) => _ProfileContent(
          key: ValueKey(patient.patientId),
          patient: patient,
          clinic: clinic,
          showBack: showBack,
          onClose: onClose,
        ),
      ),
    );
  }
}

enum _Tab { overview, sessions, files, prescriptions, appointments }

class _ProfileContent extends ConsumerStatefulWidget {
  const _ProfileContent({super.key, required this.patient, required this.clinic, required this.showBack, this.onClose});

  final PatientView patient;
  final ClinicContext clinic;
  final bool showBack;
  final VoidCallback? onClose;

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> with TickerProviderStateMixin {
  TabController? _tabs;
  List<_Tab> _visible = const [];
  bool _busy = false;

  PatientView get _patient => widget.patient;
  ClinicContext get _clinic => widget.clinic;

  /// AS4: the tabs by permission. Files needs `filesManage` (AS6);
  /// Prescriptions `clinicalView` or `prescriptionsPrint` (AS8);
  /// Appointments `appointmentsView`.
  List<_Tab> get _allowedTabs => [
        if (_clinic.can(ClinicPermission.clinicalView)) _Tab.overview,
        if (_clinic.can(ClinicPermission.sessionsCreate) || _clinic.can(ClinicPermission.clinicalView)) _Tab.sessions,
        if (_clinic.can(ClinicPermission.filesManage)) _Tab.files,
        if (_clinic.canReadRx) _Tab.prescriptions,
        if (_clinic.can(ClinicPermission.appointmentsView)) _Tab.appointments,
      ];

  /// D6 Book: D32 with this patient already picked (`appointmentsManage`; archived patients can't be
  /// booked, BR-P7). The patient goes along as `extra`; the query lets a reload find them again.
  bool get _canBook =>
      _clinic.can(ClinicPermission.appointmentsManage) && !_clinic.isSuspended && !_patient.archived;

  void _book() {
    final patient = _patient;
    final visits = patient.visits;
    context.push(
      Uri(
        path: '${_paths.base}/appointments/book',
        queryParameters: {'patient': patient.patientId, 'file': '${patient.fileNumber}'},
      ).toString(),
      extra: PatientLookup(
        patientId: patient.patientId,
        name: patient.fullName,
        phone: patient.phone,
        fileNumber: patient.fileNumber,
        sessionCount: visits.total,
        consultationAllowed: visits.total > 0 && visits.consultationsSinceExam < _clinic.fees.maxConsecutiveConsultations,
        consultationsSinceExam: visits.consultationsSinceExam,
        lastVisitAt: visits.lastVisit?.at,
        upcomingAppointmentId: patient.nextBooking?.appointmentId,
      ),
    );
  }

  /// D6 Chat (`chat`): the link's conversation, made if it doesn't exist yet (D17).
  Future<void> _openChat() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final chat = await ref.read(chatRepositoryProvider).openForPatient(_patient.patientId);
      if (mounted) await context.push('${_paths.base}/chats/${chat.id}');
    } catch (error) {
      if (mounted) showAdminSnack(context, l10n.apiErrorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _syncTabs();
  }

  @override
  void didUpdateWidget(_ProfileContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTabs();
  }

  void _syncTabs() {
    final allowed = _allowedTabs;
    if (_listEquals(allowed, _visible)) return;
    final current = _tabs == null || _visible.isEmpty ? null : _visible[_tabs!.index];
    _tabs?.dispose();
    _visible = allowed;
    if (allowed.isEmpty) {
      _tabs = null;
      return;
    }
    _tabs = TabController(
      length: allowed.length,
      vsync: this,
      initialIndex: current == null ? 0 : allowed.indexOf(current).clamp(0, allowed.length - 1),
    )..addListener(() {
        if (mounted) setState(() {});
      });
  }

  static bool _listEquals(List<_Tab> a, List<_Tab> b) => a.length == b.length && a.indexed.every((e) => b[e.$1] == e.$2);

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  ClinicPaths get _paths => ref.read(clinicPathsProvider);

  Future<void> _resetPassword() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.patientResetPasswordTitle,
      message: l10n.patientResetPasswordBody(_patient.fullName),
      confirmLabel: l10n.patientResetPassword,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final password = await ref.read(patientsRepositoryProvider).resetPatientPassword(_patient.patientId);
      if (!mounted) return;
      await showTemporaryPasswordDialog(
        context,
        name: _patient.fullName,
        phone: _patient.phone,
        password: password,
        title: l10n.patientNewTemporaryPassword,
      );
    } on ApiException catch (error) {
      if (mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setArchived(bool archived) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: archived ? l10n.patientArchiveTitle : l10n.patientUnarchiveTitle,
      message: archived ? l10n.patientArchiveBody : l10n.patientUnarchiveBody,
      confirmLabel: archived ? l10n.patientArchive : l10n.patientUnarchive,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(patientsRepositoryProvider).setArchived(_patient.patientId, archived: archived);
      if (!mounted) return;
      patientChanged(ref, _patient.patientId);
      showAdminSnack(context, archived ? l10n.patientArchivedDone : l10n.patientUnarchivedDone);
    } on ApiException catch (error) {
      if (mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gutter = clinicGutter(width);
        final twoColumns = width >= 960;
        final bottom = 24 + MediaQuery.paddingOf(context).bottom;
        var index = 0;
        Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);

        final head = enter(_header(context));
        final summary = enter(_Summary(patient: _patient, maxConsultations: _clinic.fees.maxConsecutiveConsultations));
        final details = _detailsCard(context);
        final tabs = _tabs == null ? enter(_noTabs(context)) : enter(_tabsCard(context, twoColumns: twoColumns));

        if (twoColumns) {
          return StaggerGroup(
            child: Padding(
              padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 400,
                    child: ListView(
                      padding: EdgeInsets.only(bottom: bottom),
                      children: [
                        head,
                        const SizedBox(height: 16),
                        summary,
                        if (details != null) ...[const SizedBox(height: 16), enter(details)],
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: SingleChildScrollView(padding: EdgeInsets.only(bottom: bottom), child: tabs),
                  ),
                ],
              ),
            ),
          );
        }
        return StaggerGroup(
          child: RefreshIndicator(
            onRefresh: () async {
              patientChanged(ref, _patient.patientId);
              if (ref.read(patientSessionsProvider(_patient.patientId).exists)) {
                await ref.read(patientSessionsProvider(_patient.patientId).notifier).refresh();
              }
            },
            child: ListView(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, bottom),
              children: [
                head,
                const SizedBox(height: 16),
                summary,
                if (details != null) ...[const SizedBox(height: 16), enter(details)],
                const SizedBox(height: 16),
                tabs,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final patient = _patient;
    final canSession = _clinic.can(ClinicPermission.sessionsCreate) && !_clinic.isSuspended;
    final canEdit = _clinic.can(ClinicPermission.patientsManage);
    final canReset = _clinic.can(ClinicPermission.patientsResetPassword);
    final menu = [
      if (canReset)
        MenuItemButton(
          leadingIcon: const Icon(Icons.key_outlined),
          onPressed: _busy ? null : _resetPassword,
          child: Text(l10n.patientResetPassword),
        ),
      if (canEdit)
        MenuItemButton(
          leadingIcon: Icon(patient.archived ? Icons.unarchive_outlined : Icons.archive_outlined),
          onPressed: _busy ? null : () => _setArchived(!patient.archived),
          child: Text(patient.archived ? l10n.patientUnarchive : l10n.patientArchive),
        ),
    ];
    final canChat = _clinic.can(ClinicPermission.chat);
    final actions = <Widget>[
      if (canSession)
        FilledButton.icon(
          onPressed: () => context.push(_paths.newSession(patient.patientId)),
          icon: const Icon(Icons.add_circle_outline),
          label: Text(l10n.sessionNew),
        ),
      if (_canBook)
        FilledButton.tonalIcon(
          onPressed: _book,
          icon: const Icon(Icons.event_available_outlined),
          label: Text(l10n.bookButton),
        ),
      if (canChat)
        OutlinedButton.icon(
          onPressed: _busy ? null : _openChat,
          icon: const Icon(Icons.chat_bubble_outline),
          label: Text(l10n.chatButton),
        ),
      if (canEdit)
        OutlinedButton.icon(
          onPressed: () => context.push(_paths.editPatient(patient.patientId)),
          icon: const Icon(Icons.edit_outlined),
          label: Text(l10n.patientEdit),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (widget.showBack) ClinicBackButton(fallback: _paths.patients),
                const Spacer(),
                if (menu.isNotEmpty)
                  MenuAnchor(
                    menuChildren: menu,
                    builder: (context, controller, _) => IconButton(
                      tooltip: l10n.patientMoreActions,
                      onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                      icon: const Icon(Icons.more_vert),
                    ),
                  ),
                if (widget.onClose != null)
                  IconButton(tooltip: l10n.adminClose, onPressed: widget.onClose, icon: const Icon(Icons.close)),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InitialAvatar(name: patient.fullName, size: 60, muted: patient.archived),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(patient.fullName, style: theme.textTheme.headlineSmall),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FileNumberPill(patient.fileNumber),
                          Text(
                            patientAgeGender(l10n, patient.ageYears, patient.gender, estimated: patient.dateOfBirthEstimated),
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          if (patient.hasAllergies ?? false) const AllergyFlag(),
                          if (patient.archived) StatusPill(label: l10n.patientArchived, icon: Icons.archive_outlined),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _PhoneRow(phone: patient.phone),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 14),
              // Two to a row, so four actions still fit a phone.
              for (var i = 0; i < actions.length; i += 2) ...[
                if (i > 0) const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: actions[i]),
                    const SizedBox(width: 10),
                    Expanded(child: i + 1 < actions.length ? actions[i + 1] : const SizedBox.shrink()),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// The optional D5 details, only in the clinic that created the account
  /// (BR-P3); a linking clinic gets a short note instead.
  Widget? _detailsCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final patient = _patient;
    if (!patient.ownsDetails) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(Icons.link, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(width: 12),
              Expanded(child: Text(l10n.patientLinkedNote, style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
        ),
      );
    }
    if (!patient.hasDetails) return null;
    return SectionCard(
      title: l10n.patientDetails,
      icon: Icons.badge_outlined,
      child: ResponsiveGrid(
        minColumnWidth: 140,
        runSpacing: 14,
        children: [
          if (patient.bloodType != null) InfoRow(label: l10n.patientBloodType, value: patient.bloodType, ltr: true),
          if (patient.nationalId != null) InfoRow(label: l10n.patientNationalId, value: patient.nationalId, ltr: true),
          if (patient.address != null) InfoRow(label: l10n.patientAddress, value: patient.address),
          if (patient.emergencyContactName != null || patient.emergencyContactPhone != null)
            InfoRow(
              label: l10n.patientEmergencyContact,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (patient.emergencyContactName != null)
                    Text(patient.emergencyContactName!, style: Theme.of(context).textTheme.bodyLarge),
                  if (patient.emergencyContactPhone != null)
                    LtrText(AppFormat.phone(patient.emergencyContactPhone!), style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _noTabs(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            AppLocalizations.of(context).patientNoTabs,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );

  Widget _tabsCard(BuildContext context, {required bool twoColumns}) {
    final l10n = AppLocalizations.of(context);
    final tabs = _tabs!;
    final current = _visible[tabs.index];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Four tabs don't fit a phone's width: they scroll there instead of clipping.
          LayoutBuilder(
            builder: (context, constraints) {
              final scroll = constraints.maxWidth < 120.0 * _visible.length;
              return TabBar(
                controller: tabs,
                isScrollable: scroll,
                tabAlignment: scroll ? TabAlignment.start : null,
                tabs: [
                  for (final tab in _visible)
                    Tab(
                      text: switch (tab) {
                        _Tab.overview => l10n.patientTabOverview,
                        _Tab.sessions => l10n.patientTabSessions,
                        _Tab.files => l10n.patientTabFiles,
                        _Tab.prescriptions => l10n.patientTabPrescriptions,
                        _Tab.appointments => l10n.patientTabAppointments,
                      },
                    ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedSwitcher(
              duration: Motion.normal,
              reverseDuration: Motion.normalExit,
              switchInCurve: Motion.enterCurve,
              switchOutCurve: Motion.exitCurveReversed,
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.topStart,
                children: [...previous, ?current],
              ),
              child: KeyedSubtree(
                key: ValueKey(current),
                child: switch (current) {
                  _Tab.overview => _Overview(patient: _patient, clinic: _clinic),
                  _Tab.sessions => _SessionsTimeline(patient: _patient, clinic: _clinic),
                  _Tab.files => FilesTab(patientId: _patient.patientId, clinic: _clinic),
                  _Tab.prescriptions => PatientPrescriptionsTab(patientId: _patient.patientId, clinic: _clinic),
                  _Tab.appointments => _AppointmentsTab(patient: _patient, onBook: _canBook ? _book : null),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The phone, left to right, with Call and WhatsApp.
class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.phone});

  final String phone;

  Future<void> _open(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!opened && context.mounted) showAdminSnack(context, AppLocalizations.of(context).patientCantOpenApp, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 4),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(Icons.phone_iphone, size: 20, color: scheme.onSurfaceVariant)),
            const SizedBox(width: 10),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: LtrText(AppFormat.phone(phone), style: theme.textTheme.titleMedium),
              ),
            ),
            IconButton(
              tooltip: l10n.patientCall,
              onPressed: () => _open(context, Uri(scheme: 'tel', path: phone)),
              icon: const Icon(Icons.call_outlined),
            ),
            IconButton(
              tooltip: l10n.patientWhatsApp,
              onPressed: () => _open(context, Uri.parse('https://wa.me/${phone.replaceAll(RegExp(r'[^0-9]'), '')}')),
              icon: const Icon(Icons.chat_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

/// First and last visit, the visit counts, the consultation count and the
/// total paid (`revenueView`).
class _Summary extends StatelessWidget {
  const _Summary({required this.patient, this.maxConsultations = 2});

  final PatientView patient;

  /// BR-S3's limit, for «استشارة 1 من 2 منذ آخر كشف».
  final int maxConsultations;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final visits = patient.visits;
    final last = visits.lastVisit;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    Widget tile(String label, Widget value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            value,
          ],
        );

    // Bookings, files and prescriptions show for a patient who hasn't visited yet too.
    final extras = <Widget>[
      if (patient.nextBooking case final next?)
        tile(
          l10n.patientColumnNextBooking,
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TypeBadge(next.visitType),
              Text(ClinicFormat.dayAuto(context, next.date), style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
      if (patient.noShowCount > 0)
        tile(l10n.patientColumnNoShows, Text(l10n.patientCardNoShows(patient.noShowCount), style: theme.textTheme.bodyLarge?.copyWith(color: scheme.error))),
      if (patient.filesTotal > 0) tile(l10n.patientSortFiles, Text(l10n.patientCardFiles(patient.filesTotal), style: theme.textTheme.bodyLarge)),
      if (patient.prescriptionCount > 0)
        tile(l10n.patientTabPrescriptions, Text('${patient.prescriptionCount}', style: theme.textTheme.bodyLarge)),
    ];

    return SectionCard(
      title: l10n.patientFileSummary,
      icon: Icons.folder_open_outlined,
      child: visits.total == 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.patientNoVisits, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                if (extras.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ResponsiveGrid(minColumnWidth: 140, runSpacing: 16, children: extras),
                ],
              ],
            )
          : ResponsiveGrid(
              minColumnWidth: 140,
              runSpacing: 16,
              children: [
                tile(
                  l10n.patientColumnLastVisit,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TypeBadge(last!.type),
                          Text(ClinicFormat.dayAuto(context, last.day), style: theme.textTheme.bodyLarge),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${last.branchName(language)}  ${ClinicFormat.daysAgo(l10n, last.daysAgo)}', style: muted),
                    ],
                  ),
                ),
                tile(
                  l10n.patientColumnFirstVisit,
                  Text(AppFormat.date(context, visits.firstVisitAt!), style: theme.textTheme.bodyLarge),
                ),
                tile(
                  l10n.patientColumnVisits,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.patientVisitsCount(visits.total), style: theme.textTheme.bodyLarge),
                      Text(l10n.patientVisitsSplit(visits.examinations, visits.consultations), style: muted),
                    ],
                  ),
                ),
                tile(
                  l10n.patientConsultationsSinceExam,
                  Text(l10n.sessionConsultationShort(visits.consultationsSinceExam, maxConsultations),
                      style: theme.textTheme.bodyLarge),
                ),
                if (patient.totalPaidPiasters != null)
                  tile(l10n.patientTotalPaid, Text(AppFormat.egp(context, patient.totalPaidPiasters!), style: theme.textTheme.titleMedium)),
                ...extras,
              ],
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// Appointments

/// The Appointments tab (`appointmentsView`): upcoming bookings soonest first, then the past ones
/// newest first, each with its status (no-shows in red). A row opens D31.
class _AppointmentsTab extends ConsumerWidget {
  const _AppointmentsTab({required this.patient, required this.onBook});

  final PatientView patient;

  /// Null when the caller may not book (no `appointmentsManage`, suspended, archived patient).
  final VoidCallback? onBook;

  static const _active = {
    AppointmentStatus.pending,
    AppointmentStatus.confirmed,
    AppointmentStatus.checkedIn,
    AppointmentStatus.withDoctor,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paths = ref.watch(clinicPathsProvider);
    final provider = patientAppointmentsProvider(patient.patientId);
    final today = DateUtils.dateOnly(DateTime.now());

    Widget header(String text) => Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
        );

    return AsyncStateSwitcher<List<Appointment>>(
      value: ref.watch(provider),
      loading: (context) => SkeletonLoading(
        loading: true,
        child: Column(children: [for (var i = 0; i < 3; i++) _AppointmentRow.placeholder()]),
      ),
      error: (context, error) => Semantics(
        liveRegion: true,
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.apiErrorMessage(error), style: theme.textTheme.bodyMedium)),
            TextButton(onPressed: () => ref.invalidate(provider), child: Text(l10n.retryButton)),
          ],
        ),
      ),
      isEmpty: (list) => list.isEmpty,
      empty: (context) => EmptyState(
        title: l10n.patientAppointmentsEmptyTitle,
        message: onBook == null ? null : l10n.patientAppointmentsEmptyBody,
        actionLabel: onBook == null ? null : l10n.bookButton,
        onAction: onBook,
      ),
      data: (context, list) {
        final upcoming = list.where((a) => _active.contains(a.status) && !a.date.isBefore(today)).toList().reversed.toList();
        final past = list.where((a) => !upcoming.contains(a)).toList();
        var index = 0;
        Widget row(Appointment a) => StaggeredEntrance(
              index: index++,
              child: _AppointmentRow(appointment: a, onTap: () => context.push('${paths.base}/appointments/${a.id}')),
            );
        return StaggerGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onBook != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(onPressed: onBook, icon: const Icon(Icons.add), label: Text(l10n.bookButton)),
                ),
              if (patient.noShowCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MetaLine(icon: Icons.event_busy_outlined, text: l10n.patientCardNoShows(patient.noShowCount), color: scheme.error),
                ),
              if (upcoming.isNotEmpty) ...[header(l10n.patientAppointmentsUpcoming), for (final a in upcoming) row(a)],
              if (past.isNotEmpty) ...[
                if (upcoming.isNotEmpty) const SizedBox(height: 8),
                header(l10n.patientAppointmentsPast),
                for (final a in past) row(a),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.appointment, required this.onTap});

  static Widget placeholder() => _AppointmentRow(
        appointment: Appointment(
          id: '',
          doctor: const DoctorRef(id: '', fullName: '————', title: ''),
          branch: const BranchRef(id: '', nameAr: '——————'),
          displayName: '',
          isGuest: false,
          visitType: 'examination',
          mode: 'queue',
          date: DateTime.utc(2026),
          time: '17:00',
          startUtc: DateTime.utc(2026),
          status: AppointmentStatus.confirmed,
          source: 'staff',
        ),
        onTap: null,
      );

  final Appointment appointment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = appointment;
    final language = Localizations.localeOf(context).languageCode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TypeBadge(SessionType.fromWire(a.visitType)),
                        Text('${ClinicFormat.dayAuto(context, a.date)}  ${context.appointmentWhen(a)}', style: theme.textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: 6),
                    MetaLine(
                      icon: Icons.store_mall_directory_outlined,
                      text: language == 'ar' || a.branch.nameEn == null ? a.branch.nameAr : a.branch.nameEn!,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(status: a.status),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Overview

/// The medical profile, allergies first in a red block (spec 6.1).
class _Overview extends ConsumerWidget {
  const _Overview({required this.patient, required this.clinic});

  final PatientView patient;
  final ClinicContext clinic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canEdit = clinic.can(ClinicPermission.clinicalEditProfile);
    final paths = ref.watch(clinicPathsProvider);
    void edit() => context.push(paths.editPatient(patient.patientId, medical: true));
    return AsyncStateSwitcher<MedicalProfile>(
      value: ref.watch(medicalProfileProvider(patient.patientId)),
      loading: (context) => const SkeletonLoading(loading: true, child: _ProfilePlaceholder()),
      error: (context, error) =>
          AdminErrorView(error: error, compact: true, onRetry: () => ref.invalidate(medicalProfileProvider(patient.patientId))),
      isEmpty: (profile) => profile.isEmpty,
      empty: (context) => EmptyState(
        title: l10n.patientProfileEmptyTitle,
        message: canEdit ? l10n.patientProfileEmptyBody : null,
        actionLabel: canEdit ? l10n.patientEditMedicalProfile : null,
        onAction: canEdit ? edit : null,
      ),
      data: (context, profile) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AllergiesBlock(items: [for (final item in profile.allergies) item.text]),
          const SizedBox(height: 16),
          for (final list in const [ProfileList.chronicDiseases, ProfileList.currentMedications, ProfileList.surgeries])
            _ProfileSection(title: profileListLabel(l10n, list), items: [for (final i in profile.list(list)) i.text]),
          if (profile.familyHistory != null) _ProfileText(title: l10n.patientFamilyHistory, text: profile.familyHistory!),
          if (profile.notes != null) _ProfileText(title: l10n.patientGeneralNotes, text: profile.notes!),
          if (canEdit)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: edit,
                icon: const Icon(Icons.edit_note_outlined),
                label: Text(l10n.patientEditMedicalProfile),
              ),
            ),
        ],
      ),
    );
  }
}

String profileListLabel(AppLocalizations l10n, ProfileList list) => switch (list) {
      ProfileList.allergies => l10n.patientAllergies,
      ProfileList.chronicDiseases => l10n.patientChronicDiseases,
      ProfileList.currentMedications => l10n.patientCurrentMedications,
      ProfileList.surgeries => l10n.patientSurgeries,
    };

/// Allergies in a red highlighted block, or "No known allergies".
class AllergiesBlock extends StatelessWidget {
  const AllergiesBlock({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = context.el3yadaColors;
    if (items.isEmpty) {
      return Row(
        children: [
          ExcludeSemantics(child: Icon(Icons.verified_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Text(l10n.patientNoAllergies, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      );
    }
    return Semantics(
      container: true,
      label: l10n.patientAllergies,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.allergy, borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(child: Icon(Icons.warning_amber_rounded, color: colors.onAllergy)),
                  const SizedBox(width: 8),
                  Text(l10n.patientAllergies,
                      style: theme.textTheme.titleSmall?.copyWith(color: colors.onAllergy, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in items)
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: StadiumBorder(side: BorderSide(color: colors.onAllergy.withValues(alpha: 0.5))),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        child: Text(item, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onAllergy, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(l10n.patientNothingRecorded,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final item in items) Chip(label: Text(item), visualDensity: VisualDensity.compact)],
            ),
        ],
      ),
    );
  }
}

class _ProfileText extends StatelessWidget {
  const _ProfileText({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(text, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _ProfilePlaceholder extends StatelessWidget {
  const _ProfilePlaceholder();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AllergiesBlock(items: ['——————', '————']),
          SizedBox(height: 16),
          _ProfileSection(title: '————————', items: ['————————', '——————']),
          _ProfileSection(title: '————————', items: ['————————']),
        ],
      );
}

// -----------------------------------------------------------------------------
// Sessions

/// The Sessions tab: a timeline, newest first, with type badges. Clinical
/// snippets only with `clinicalView`; amounts with `revenueView` or for
/// the person who recorded the session.
class _SessionsTimeline extends ConsumerWidget {
  const _SessionsTimeline({required this.patient, required this.clinic});

  final PatientView patient;
  final ClinicContext clinic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(patientSessionsProvider(patient.patientId));
    final controller = ref.read(patientSessionsProvider(patient.patientId).notifier);
    final paths = ref.watch(clinicPathsProvider);
    final canSession = clinic.can(ClinicPermission.sessionsCreate) && !clinic.isSuspended;
    return StateSwitcher(
      state: state.view,
      loading: (context) => SkeletonLoading(
        loading: true,
        child: Column(children: [for (var i = 0; i < 3; i++) _TimelineRow.placeholder(last: i == 2)]),
      ),
      error: (context) => AdminErrorView(error: state.error!, compact: true, onRetry: controller.reload),
      empty: (context) => EmptyState(
        title: l10n.patientSessionsEmptyTitle,
        message: canSession ? l10n.patientSessionsEmptyBody : null,
        actionLabel: canSession ? l10n.sessionNew : null,
        onAction: canSession ? () => context.push(paths.newSession(patient.patientId)) : null,
      ),
      content: (context) => StaggerGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, item) in state.items.indexed)
              StaggeredEntrance(
                index: i,
                child: _TimelineRow(
                  item: item,
                  showRecorder: clinic.isDoctor,
                  last: i == state.items.length - 1 && !state.hasMore,
                  onTap: () => context.push(paths.patientSession(patient.patientId, item.sessionId)),
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

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.showRecorder, required this.last, required this.onTap});

  static Widget placeholder({bool last = false}) => _TimelineRow(
        item: SessionListItem(
          sessionId: '',
          at: DateTime.utc(2026),
          day: DateTime.utc(2026),
          type: SessionType.examination,
          patientId: '',
          fileNumber: 1,
          patientName: '',
          branch: const SessionBranch(id: '', nameAr: '——————'),
          platformFeePiasters: 3000,
          recordedBy: const RecordedBy(userId: '', name: '————', isAssistant: false),
          chiefComplaint: '————————————',
        ),
        showRecorder: false,
        last: last,
        onTap: null,
      );

  final SessionListItem item;
  final bool showRecorder;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.el3yadaColors;
    final language = Localizations.localeOf(context).languageCode;
    final dot = item.type == SessionType.examination ? colors.onExamination : colors.onConsultation;
    final snippet = item.diagnosis ?? item.chiefComplaint;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 18),
                DecoratedBox(
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  child: const SizedBox.square(dimension: 12),
                ),
                if (!last)
                  Expanded(child: Container(width: 2, color: scheme.outlineVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pressable(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          TypeBadge(item.type),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${ClinicFormat.dayAuto(context, item.day)}  ${ClinicFormat.time(context, item.at)}',
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          ExcludeSemantics(child: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                      if (snippet != null) ...[
                        const SizedBox(height: 6),
                        Text(snippet, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          MetaLine(icon: Icons.store_mall_directory_outlined, text: item.branch.name(language)),
                          MetaLine(icon: Icons.receipt_outlined, text: l10n.sessionPlatformFeeShort(AppFormat.egp(context, item.platformFeePiasters))),
                          if (item.amountChargedPiasters != null)
                            MetaLine(icon: Icons.payments_outlined, text: AppFormat.egp(context, item.amountChargedPiasters!)),
                          if (showRecorder && item.recordedBy.isAssistant)
                            MetaLine(icon: Icons.person_outline, text: l10n.sessionRecordedBy(item.recordedBy.name)),
                          if (item.awaitingDoctor) const AwaitingDoctorBadge(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Skeleton

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    final patient = PatientView(
      patientId: '',
      fileNumber: 12,
      fullName: '————————————',
      phone: '+201000000000',
      gender: Gender.female,
      dateOfBirth: DateTime.utc(1990),
      ageYears: 36,
      linkedAt: DateTime.utc(2026),
    );
    return SkeletonLoading(
      loading: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  InitialAvatar(name: patient.fullName, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(patient.fullName, style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        const Text('———— ————— ————'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Summary(patient: patient),
          const SizedBox(height: 16),
          const Card(child: SizedBox(height: 180)),
        ],
      ),
    );
  }
}
