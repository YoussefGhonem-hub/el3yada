import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/app_format.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/state_switcher.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../admin/presentation/widgets/admin_widgets.dart';
import '../../billing/presentation/billing_widgets.dart';
import '../../patients/presentation/widgets/clinic_ui.dart'
    show ClinicChips, ClinicFormat, GroupedRows, TypeBadge;
import '../application/admin_billing_providers.dart';
import '../data/admin_billing_repository.dart';
import '../domain/admin_billing_models.dart';
import 'admin_billing_widgets.dart';
import 'paged_list.dart';

/// AD4: the doctors, with search and filters (status), and for each the
/// month's sessions and what they still owe. Tap one for AD5.
class AdminDoctorsScreen extends ConsumerStatefulWidget {
  const AdminDoctorsScreen({super.key});

  @override
  ConsumerState<AdminDoctorsScreen> createState() => _AdminDoctorsScreenState();
}

class _AdminDoctorsScreenState extends ConsumerState<AdminDoctorsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final notifier = ref.read(doctorFilterProvider.notifier);
      notifier.set(ref.read(doctorFilterProvider).copyWith(search: text));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final filter = ref.watch(doctorFilterProvider);
    final state = ref.watch(adminDoctorsProvider);
    final controller = ref.read(adminDoctorsProvider.notifier);
    void set(DoctorFilter next) =>
        ref.read(doctorFilterProvider.notifier).set(next);
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = adminGutter(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
              child: AdminHeader(
                title: l10n.abDoctorsTitle,
                subtitle: l10n.abDoctorsSubtitle(state.totalCount),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.abDoctorsSearchHint,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
              child: ClinicChips(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.abAllStatuses),
                      selected: filter.status == null,
                      onSelected: (_) => set(filter.copyWith(status: null)),
                    ),
                    for (final status in const [
                      'active',
                      'suspended',
                      'disabled',
                      'pendingApproval',
                      'rejected',
                    ])
                      ChoiceChip(
                        label: Text(doctorStatusLabel(l10n, status)),
                        selected: filter.status == status,
                        onSelected: (_) => set(filter.copyWith(status: status)),
                      ),
                    PopupMenuButton<DoctorSort>(
                      tooltip: l10n.abSort,
                      onSelected: (sort) => set(filter.copyWith(sort: sort)),
                      itemBuilder: (context) => [
                        for (final sort in DoctorSort.values)
                          PopupMenuItem(
                            value: sort,
                            child: Text(_sortLabel(l10n, sort)),
                          ),
                      ],
                      child: Chip(
                        avatar: const Icon(Icons.sort, size: 18),
                        label: Text(_sortLabel(l10n, filter.sort)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: PagedGroupedList<DoctorListItem>(
                state: state,
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 32),
                onLoadMore: controller.loadMore,
                onRefresh: controller.refresh,
                onRetry: controller.reload,
                empty: (context) => EmptyState(
                  title: l10n.abDoctorsEmptyTitle,
                  message: l10n.abDoctorsEmptyBody,
                ),
                skeletonRow: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Text('████████████  ████'),
                ),
                itemBuilder: (context, doctor) =>
                    _DoctorRow(doctor: doctor, language: language),
              ),
            ),
          ],
        );
      },
    );
  }

  String _sortLabel(AppLocalizations l10n, DoctorSort sort) => switch (sort) {
    DoctorSort.name => l10n.abSortName,
    DoctorSort.newest => l10n.abSortNewest,
    DoctorSort.sessions => l10n.abSortSessions,
    DoctorSort.outstanding => l10n.abSortOutstanding,
  };
}

class _DoctorRow extends StatelessWidget {
  const _DoctorRow({required this.doctor, required this.language});

  final DoctorListItem doctor;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.go('/admin/doctors/${doctor.doctorId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            InitialAvatar(name: doctor.name(language)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.name(language),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      doctor.specialty(language),
                      if (doctor.clinic(language) != null)
                        doctor.clinic(language)!,
                      if (doctor.phone != null) AppFormat.phone(doctor.phone!),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusPill(
                        label: doctorStatusLabel(l10n, doctor.status),
                        tone: doctorStatusTone(doctor.status),
                      ),
                      Text(
                        l10n.abSessionsThisMonth(doctor.sessionsThisMonth),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (doctor.outstandingPiasters > 0) ...[
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.abOutstanding,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  LtrText(
                    AppFormat.egp(context, doctor.outstandingPiasters),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ---- AD5 -------------------------------------------------------------------------------------

/// AD5: one doctor, in tabs: Profile (with the internal notes), Activity,
/// Invoices, Payments, Audit, Branches, Appointments and Assistants, and the
/// actions: Suspend, Reactivate, Disable, Send password reset, Add note.
class AdminDoctorScreen extends ConsumerWidget {
  const AdminDoctorScreen({super.key, required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final profile = ref.watch(adminDoctorProfileProvider(doctorId));
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = adminGutter(constraints.maxWidth);
        return DefaultTabController(
          length: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
                child: AdminHeader(
                  title: profile.value?.name(language) ?? l10n.abDoctorTitle,
                  subtitle: profile.value?.specialty(language),
                  leading: const AdminBackButton(fallback: '/admin/doctors'),
                ),
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: l10n.abTabProfile),
                  Tab(text: l10n.abTabActivity),
                  Tab(text: l10n.abTabInvoices),
                  Tab(text: l10n.abTabPayments),
                  Tab(text: l10n.abTabAudit),
                  Tab(text: l10n.abTabBranches),
                  Tab(text: l10n.abTabAppointments),
                  Tab(text: l10n.abTabAssistants),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _ProfileTab(doctorId: doctorId, gutter: gutter),
                    _ActivityTab(doctorId: doctorId, gutter: gutter),
                    _InvoicesTab(doctorId: doctorId, gutter: gutter),
                    _PaymentsTab(doctorId: doctorId, gutter: gutter),
                    _AuditTab(doctorId: doctorId, gutter: gutter),
                    _BranchesTab(doctorId: doctorId, gutter: gutter),
                    _AppointmentsTab(doctorId: doctorId, gutter: gutter),
                    _AssistantsTab(doctorId: doctorId, gutter: gutter),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A tab body: skeleton, error with Retry, and the data.
class _TabBody<T> extends StatelessWidget {
  const _TabBody({
    required this.value,
    required this.onRetry,
    required this.builder,
    required this.gutter,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T data) builder;
  final double gutter;

  @override
  Widget build(BuildContext context) => AsyncStateSwitcher<T>(
    value: value,
    loading: (context) =>
        const SkeletonLoading(loading: true, child: SizedBox(height: 280)),
    error: (context, error) => AdminErrorView(error: error, onRetry: onRetry),
    data: (context, data) => ListView(
      padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
      children: [builder(context, data)],
    ),
  );
}

class _ProfileTab extends ConsumerStatefulWidget {
  const _ProfileTab({required this.doctorId, required this.gutter});

  final String doctorId;
  final double gutter;

  @override
  ConsumerState<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<_ProfileTab> {
  bool _busy = false;

  AdminBillingRepository get _repo => ref.read(adminBillingRepositoryProvider);

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ref.invalidate(adminDoctorProfileProvider(widget.doctorId));
      ref.invalidate(adminDoctorsProvider);
      ref.invalidate(doctorNotesProvider(widget.doctorId));
      showAdminSnack(context, done);
    } catch (error) {
      if (mounted) showActionError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _status(AdminDoctorProfile profile, String status) async {
    final l10n = AppLocalizations.of(context);
    final (title, body, confirm, done, destructive) = switch (status) {
      'suspended' => (
        l10n.abSuspendTitle,
        l10n.abSuspendBody,
        l10n.abSuspend,
        l10n.abSuspendedSnack,
        true,
      ),
      'disabled' => (
        l10n.abDisableTitle,
        l10n.abDisableBody,
        l10n.abDisable,
        l10n.abDisabledSnack,
        true,
      ),
      _ => (
        l10n.abReactivateTitle,
        l10n.abReactivateBody,
        l10n.abReactivate,
        l10n.abReactivatedSnack,
        false,
      ),
    };
    final reason = await askReason(
      context,
      title: title,
      message: body,
      confirmLabel: confirm,
      destructive: destructive,
    );
    if (reason == null || !mounted) return;
    await _run(
      () => _repo.setDoctorStatus(
        widget.doctorId,
        status: status,
        reason: reason,
      ),
      done,
    );
  }

  Future<void> _addNote() async {
    final l10n = AppLocalizations.of(context);
    final text = await askReason(
      context,
      title: l10n.abAddNote,
      confirmLabel: l10n.abSave,
      label: l10n.abNoteLabel,
    );
    if (text == null || !mounted) return;
    await _run(
      () => _repo.addDoctorNote(widget.doctorId, text),
      l10n.abNoteAdded,
    );
  }

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmAction(
      context,
      title: l10n.abResetTitle,
      message: l10n.abResetBody,
      confirmLabel: l10n.abSend,
    );
    if (!ok || !mounted) return;
    await _run(
      () => _repo.sendPasswordReset(widget.doctorId),
      l10n.abResetSent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final profile = ref.watch(adminDoctorProfileProvider(widget.doctorId));
    final notes = ref.watch(doctorNotesProvider(widget.doctorId));
    return _TabBody<AdminDoctorProfile>(
      value: profile,
      gutter: widget.gutter,
      onRetry: () =>
          ref.invalidate(adminDoctorProfileProvider(widget.doctorId)),
      builder: (context, data) {
        final suspended = data.status == 'suspended';
        final disabled = data.status == 'disabled';
        final active = data.status == 'active';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              title: l10n.abProfile,
              icon: Icons.badge_outlined,
              trailing: StatusPill(
                label: doctorStatusLabel(l10n, data.status),
                tone: doctorStatusTone(data.status),
              ),
              child: ResponsiveGrid(
                children: [
                  InfoRow(label: l10n.abFullName, value: data.name(language)),
                  InfoRow(
                    label: l10n.abSpecialty,
                    value: data.specialty(language),
                  ),
                  InfoRow(label: l10n.abEmail, value: data.email, ltr: true),
                  InfoRow(
                    label: l10n.abPhone,
                    value: data.phone == null
                        ? null
                        : AppFormat.phone(data.phone!),
                    ltr: true,
                  ),
                  InfoRow(
                    label: l10n.abLicense,
                    value: data.licenseNumber,
                    ltr: true,
                  ),
                  InfoRow(
                    label: l10n.abJoined,
                    value: ClinicFormat.day(context, data.createdAt),
                  ),
                  if (data.statusReason != null)
                    InfoRow(
                      label: l10n.abStatusReason,
                      value: data.statusReason!.startsWith('billing:')
                          ? l10n.abReasonBilling(
                              data.statusReason!.substring(8),
                            )
                          : data.statusReason,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: l10n.abActions,
              icon: Icons.admin_panel_settings_outlined,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (active)
                    FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => _status(data, 'suspended'),
                      icon: const Icon(Icons.pause_circle_outline),
                      label: Text(l10n.abSuspend),
                    ),
                  if (suspended || disabled)
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _status(data, 'active'),
                      icon: const Icon(Icons.play_circle_outline),
                      label: Text(l10n.abReactivate),
                    ),
                  if (active || suspended)
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _status(data, 'disabled'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      icon: const Icon(Icons.block),
                      label: Text(l10n.abDisable),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy || data.email == null ? null : _reset,
                    icon: const Icon(Icons.lock_reset),
                    label: Text(l10n.abSendReset),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _addNote,
                    icon: const Icon(Icons.note_add_outlined),
                    label: Text(l10n.abAddNote),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: l10n.abNotes,
              icon: Icons.sticky_note_2_outlined,
              child: AsyncStateSwitcher<List<DoctorNote>>(
                value: notes,
                loading: (context) => const SizedBox(height: 60),
                error: (context, error) => AdminErrorView(
                  error: error,
                  compact: true,
                  onRetry: () =>
                      ref.invalidate(doctorNotesProvider(widget.doctorId)),
                ),
                isEmpty: (data) => data.isEmpty,
                empty: (context) => Text(l10n.abNotesEmpty),
                data: (context, data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final note in data)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(note.text),
                            Text(
                              '${note.authorName} · ${AppFormat.dateTime(context, note.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActivityTab extends ConsumerWidget {
  const _ActivityTab({required this.doctorId, required this.gutter});

  final String doctorId;
  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _TabBody<DoctorActivity>(
      value: ref.watch(doctorActivityProvider(doctorId)),
      gutter: gutter,
      onRetry: () => ref.invalidate(doctorActivityProvider(doctorId)),
      builder: (context, data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: l10n.abSessionsPerMonth,
            icon: Icons.bar_chart,
            child: Column(
              children: [
                for (final month in data.months)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(ClinicFormat.month(context, month.month)),
                        ),
                        Text(
                          l10n.billCounts(
                            month.examinations,
                            month.consultations,
                          ),
                        ),
                        const SizedBox(width: 12),
                        LtrText(
                          AppFormat.egp(context, month.platformFeesPiasters),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: l10n.abSessionsOfMonth(
              ClinicFormat.month(context, parseMonth(data.month)),
            ),
            subtitle: l10n.abMaskedHint,
            icon: Icons.list_alt,
            child: data.sessions.items.isEmpty
                ? Text(l10n.abNoSessions)
                : Column(
                    children: [
                      for (final session in data.sessions.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(session.patientMasked),
                                    Text(
                                      AppFormat.dateTime(context, session.at),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              TypeBadge(session.type),
                              const SizedBox(width: 12),
                              LtrText(
                                AppFormat.egp(context, session.feePiasters),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _InvoicesTab extends ConsumerWidget {
  const _InvoicesTab({required this.doctorId, required this.gutter});

  final String doctorId;
  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _TabBody<AdminInvoicesPage>(
      value: ref.watch(doctorInvoicesProvider(doctorId)),
      gutter: gutter,
      onRetry: () => ref.invalidate(doctorInvoicesProvider(doctorId)),
      builder: (context, data) => data.page.items.isEmpty
          ? EmptyState(
              title: l10n.abInvoicesEmptyTitle,
              message: l10n.abInvoicesEmptyBody,
            )
          : GroupedRows(
              children: [
                for (final item in data.page.items)
                  InvoiceRow(
                    invoice: InvoiceItem(
                      id: item.id,
                      monthKey: item.monthKey,
                      periodStart: item.month,
                      periodEnd: DateTime.utc(
                        item.month.year,
                        item.month.month + 1,
                        0,
                      ),
                      examCount: item.examCount,
                      consultationCount: item.consultationCount,
                      examAmountPiasters: 0,
                      consultationAmountPiasters: 0,
                      adjustmentsPiasters: 0,
                      totalDuePiasters: item.totalDuePiasters,
                      dueDate: item.dueDate,
                      status: item.status,
                      canPay: item.status.payable,
                    ),
                    onTap: () => context.go('/admin/invoices/${item.id}'),
                  ),
              ],
            ),
    );
  }
}

class _PaymentsTab extends ConsumerWidget {
  const _PaymentsTab({required this.doctorId, required this.gutter});

  final String doctorId;
  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _TabBody<Paged<PaymentQueueItem>>(
      value: ref.watch(doctorPaymentsProvider(doctorId)),
      gutter: gutter,
      onRetry: () => ref.invalidate(doctorPaymentsProvider(doctorId)),
      builder: (context, data) => data.items.isEmpty
          ? EmptyState(
              title: l10n.abPaymentsEmptyTitle,
              message: l10n.abPaymentsEmptyBody,
            )
          : GroupedRows(
              children: [
                for (final item in data.items)
                  ListTile(
                    title: LtrText(AppFormat.egp(context, item.amountPiasters)),
                    subtitle: Text(
                      '${l10n.abInvoiceOf(ClinicFormat.month(context, item.month))} · ${AppFormat.relative(context, item.submittedAt)}',
                    ),
                    trailing: StatusPill(
                      label: switch (item.status) {
                        PaymentStatus.pendingReview => l10n.billPaymentPending,
                        PaymentStatus.approved => l10n.billPaymentApproved,
                        PaymentStatus.rejected => l10n.billPaymentRejected,
                      },
                      tone: switch (item.status) {
                        PaymentStatus.pendingReview => PillTone.accent,
                        PaymentStatus.approved => PillTone.positive,
                        PaymentStatus.rejected => PillTone.danger,
                      },
                    ),
                    onTap: () =>
                        context.go('/admin/payments/${item.paymentId}'),
                    subtitleTextStyle: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
    );
  }
}

class _AuditTab extends ConsumerWidget {
  const _AuditTab({required this.doctorId, required this.gutter});

  final String doctorId;
  final double gutter;

  String _action(AppLocalizations l10n, String action) => switch (action) {
    'doctorSuspended' => l10n.abAuditSuspended,
    'doctorReactivated' => l10n.abAuditReactivated,
    'doctorDisabled' => l10n.abAuditDisabled,
    'doctorServiceActivated' => l10n.abAuditServiceActivated,
    'doctorTrialExtended' => l10n.abAuditTrialExtended,
    'invoiceOverdue' => l10n.abAuditInvoiceOverdue,
    _ => action,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _TabBody<DoctorAudit>(
      value: ref.watch(doctorAuditProvider(doctorId)),
      gutter: gutter,
      onRetry: () => ref.invalidate(doctorAuditProvider(doctorId)),
      builder: (context, data) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: l10n.abStatusChanges,
            icon: Icons.swap_vert,
            child: data.statusChanges.items.isEmpty
                ? Text(l10n.abNothingHere)
                : Column(
                    children: [
                      for (final row in data.statusChanges.items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_action(l10n, row.action)),
                          subtitle: Text(
                            '${AppFormat.dateTime(context, row.at)} · ${row.actorRole}',
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: l10n.abDeletedSessions,
            icon: Icons.delete_outline,
            child: data.deletedSessions.items.isEmpty
                ? Text(l10n.abNothingHere)
                : Column(
                    children: [
                      for (final row in data.deletedSessions.items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${row.patientMasked} · ${ClinicFormat.day(context, row.day)}',
                          ),
                          subtitle: Text(
                            row.reason == null
                                ? ''
                                : l10n.abDeleteReason(row.reason!),
                          ),
                          trailing: TypeBadge(row.type),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _BranchesTab extends ConsumerWidget {
  const _BranchesTab({required this.doctorId, required this.gutter});

  final String doctorId;
  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return _TabBody<List<DoctorBranchRow>>(
      value: ref.watch(doctorBranchesProvider(doctorId)),
      gutter: gutter,
      onRetry: () => ref.invalidate(doctorBranchesProvider(doctorId)),
      builder: (context, data) => GroupedRows(
        children: [
          for (final branch in data)
            ListTile(
              title: Text(branch.name(language)),
              subtitle: Text(
                [
                  if (branch.area != null) branch.area!,
                  branch.city,
                  ...branch.phones.map(AppFormat.phone),
                ].join(' · '),
              ),
              trailing: StatusPill(
                label: branch.isDefault ? l10n.abBranchDefault : branch.status,
                tone: PillTone.neutral,
              ),
            ),
        ],
      ),
    );
  }
}

class _AppointmentsTab extends ConsumerWidget {
  const _AppointmentsTab({required this.doctorId, required this.gutter});

  final String doctorId;
  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _TabBody<List<DoctorAppointmentsMonth>>(
      value: ref.watch(doctorAppointmentsProvider(doctorId)),
      gutter: gutter,
      onRetry: () => ref.invalidate(doctorAppointmentsProvider(doctorId)),
      builder: (context, data) => SectionCard(
        title: l10n.abAppointmentsCounts,
        subtitle: l10n.abCountsOnly,
        icon: Icons.event_note_outlined,
        child: Column(
          children: [
            for (final month in data)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(ClinicFormat.month(context, month.month)),
                    ),
                    Text(
                      l10n.abAppointmentsLine(
                        month.bookings,
                        month.noShows,
                        month.cancellations,
                        (month.noShowRate * 100).round(),
                        month.checkedInNoSession,
                      ),
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

class _AssistantsTab extends ConsumerWidget {
  const _AssistantsTab({required this.doctorId, required this.gutter});

  final String doctorId;
  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return _TabBody<List<DoctorAssistantRow>>(
      value: ref.watch(doctorAssistantsProvider(doctorId)),
      gutter: gutter,
      onRetry: () => ref.invalidate(doctorAssistantsProvider(doctorId)),
      builder: (context, data) => data.isEmpty
          ? Text(l10n.abNoAssistants)
          : GroupedRows(
              children: [
                for (final assistant in data)
                  ListTile(
                    leading: InitialAvatar(name: assistant.fullName),
                    title: Text(assistant.fullName),
                    subtitle: Text(
                      [
                        if (assistant.phone != null)
                          AppFormat.phone(assistant.phone!),
                        if (assistant.lastActiveAt != null)
                          AppFormat.relative(context, assistant.lastActiveAt!),
                      ].join(' · '),
                    ),
                    trailing: StatusPill(
                      label: assistant.status,
                      tone: assistant.status == 'active'
                          ? PillTone.positive
                          : PillTone.neutral,
                    ),
                  ),
              ],
            ),
    );
  }
}
