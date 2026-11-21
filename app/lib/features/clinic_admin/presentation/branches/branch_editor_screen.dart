import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/save_bar.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../appointments/application/appointment_providers.dart';
import '../../../appointments/data/appointments_repository.dart';
import '../../../appointments/domain/appointment_models.dart';
import '../../../appointments/presentation/appointment_format.dart';
import '../../../clinic/application/clinic_providers.dart';
import '../../../clinic/domain/clinic_permissions.dart';
import '../../application/clinic_admin_controllers.dart';
import '../../clinic_admin_routes.dart';
import '../../data/clinic_admin_repository.dart';
import '../../domain/branch_models.dart';
import '../../domain/price_models.dart';
import '../../domain/weekly_hours.dart';
import '../prices/price_editor.dart';
import '../widgets/clinic_admin_widgets.dart';
import 'branch_drafts.dart';
import 'branch_fields.dart';
import 'branch_photos.dart';
import 'branch_read_only.dart';
import 'branch_text.dart';
import 'schedule_conflicts_sheet.dart';
import 'schedule_drafts.dart';
import 'schedule_tabs.dart';

/// The D29 tabs, by their `?tab=` name.
enum BranchTab { info, address, contact, hours, dates, booking, clinic }

/// The tabs that save through `updateBranchSchedule`, with the conflicts sheet.
const scheduleTabs = {BranchTab.hours, BranchTab.dates, BranchTab.booking};

/// D29: one branch in tabs (Info, Address and map, Contact, Working hours,
/// Special dates, Booking settings, Clinic info for patients). Each tab saves
/// its own group; a tab with unsaved changes carries a dot, and leaving with
/// changes asks first. The Info tab also holds the status: temporarily close,
/// reopen, archive, make default, with the API's refusals explained (BR-BR1,
/// BR-BR9). The schedule tabs are the one place hours change: saving one
/// lists the bookings it would strand first (the conflicts sheet, BR-AP12).
///
/// AS17 is the same screen for an assistant with `scheduleManage`: the
/// schedule tabs are editable, Info, Address and Contact read-only, and
/// Clinic info isn't there. [embedded] is AS17's own menu page (no Back to D28).
class BranchEditorScreen extends ConsumerWidget {
  const BranchEditorScreen({super.key, required this.branchId, this.initialTab, this.embedded = false});

  final String branchId;
  final BranchTab? initialTab;
  final bool embedded;

  static BranchTab? tabNamed(String? name) => BranchTab.values.where((t) => t.name == name).firstOrNull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(branchDetailProvider(branchId));
    final clinic = ref.watch(clinicContextProvider).value;
    final doctor = clinic?.isDoctor ?? false;
    final canSchedule = clinic?.can(ClinicPermission.scheduleManage) ?? false;
    final back = embedded ? const SizedBox.shrink() : const ClinicBackButton(fallback: ClinicAdminRoutes.branches);
    return Scaffold(
      body: AsyncStateSwitcher<BranchDetails>(
        value: branch,
        loading: (context) => const _EditorSkeleton(),
        error: (context, error) => Column(
          children: [
            Align(alignment: AlignmentDirectional.centerStart, child: Padding(padding: const EdgeInsets.all(8), child: back)),
            Expanded(
              child: AdminErrorView(error: error, onRetry: () => ref.read(branchDetailProvider(branchId).notifier).reload()),
            ),
          ],
        ),
        data: (context, details) => _BranchEditor(
          // The tabs depend on who is signed in, once the clinic has loaded.
          key: ValueKey((details.id, doctor, canSchedule)),
          details: details,
          initialTab: initialTab ?? (doctor ? BranchTab.info : BranchTab.hours),
          doctor: doctor,
          canSchedule: canSchedule,
          back: back,
        ),
      ),
    );
  }
}

class _BranchEditor extends ConsumerStatefulWidget {
  const _BranchEditor({
    super.key,
    required this.details,
    required this.initialTab,
    required this.doctor,
    required this.canSchedule,
    required this.back,
  });

  final BranchDetails details;
  final BranchTab initialTab;

  /// The doctor edits every tab; an assistant only the schedule tabs (AS17).
  final bool doctor;
  final bool canSchedule;
  final Widget back;

  @override
  ConsumerState<_BranchEditor> createState() => _BranchEditorState();
}

/// Where one tab's save is.
class _TabState {
  SubmitStatus status = SubmitStatus.idle;
  Map<String, String> server = const {};
  bool showClient = false;
  int failures = 0;
  String? error;
}

/// The conflicts sheet was closed without applying: nothing was saved.
class _NotApplied implements Exception {
  const _NotApplied();
}

class _BranchEditorState extends ConsumerState<_BranchEditor> with SingleTickerProviderStateMixin {
  late final List<BranchTab> _visible = [
    for (final tab in BranchTab.values)
      if (widget.doctor || tab != BranchTab.clinic) tab,
  ];
  late final TabController _tabs = TabController(length: _visible.length, vsync: this, initialIndex: _indexOf(widget.initialTab));
  late final _info = InfoDraft(widget.details.info);
  late final _address = AddressDraft(widget.details.address);
  late final _contact = ContactDraft(widget.details.contact);
  late final _hours = HoursDraft(widget.details.workingHours.periods);
  late final _dates = DatesDraft();
  late final _booking = BookingSettingsDraft();
  late final _checklist = ChecklistDraft(widget.details.clinicInfo);
  final _state = {for (final tab in BranchTab.values) tab: _TabState()};

  /// The schedule as saved on the server: what a schedule tab sends for the parts it doesn't edit.
  BranchScheduleData? _saved;
  ProviderSubscription<AsyncValue<BranchScheduleData>>? _scheduleSubscription;

  /// initState is done: setState may run.
  bool _started = false;

  BranchDetailController get _controller => ref.read(branchDetailProvider(widget.details.id).notifier);

  bool get _canEditBranch => widget.doctor;
  bool get _canEditSchedule => widget.doctor || widget.canSchedule;

  List<BranchDraft> get _drafts => [_info, _address, _contact, _hours, _dates, _booking, _checklist];

  int _indexOf(BranchTab tab) {
    final index = _visible.indexOf(tab);
    return index < 0 ? _visible.indexOf(BranchTab.hours) : index;
  }

  BranchDraft _draftOf(BranchTab tab) => switch (tab) {
        BranchTab.info => _info,
        BranchTab.address => _address,
        BranchTab.contact => _contact,
        BranchTab.hours => _hours,
        BranchTab.dates => _dates,
        BranchTab.booking => _booking,
        BranchTab.clinic => _checklist,
      };

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    _scheduleSubscription = ref.listenManual(scheduleProvider(widget.details.id), (previous, next) {
      final data = next.value;
      if (data == null || identical(data, _saved)) return;
      _adopt(data);
    }, fireImmediately: true);
    _started = true;
  }

  /// A schedule from the server: each schedule tab without unsaved changes starts from it.
  void _adopt(BranchScheduleData data) {
    final first = _saved == null;
    _saved = data;
    if (first || _hours.changes == 0) _hours.fill([for (final p in data.weekly) p.toBranchPeriod()]);
    if (first || _dates.changes == 0) _dates.fill(data);
    if (first || _booking.changes == 0) _booking.fill(data.settings);
    if (_started) setState(() {});
  }

  @override
  void didUpdateWidget(_BranchEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Opened again by a link to another tab.
    if (oldWidget.initialTab != widget.initialTab) _tabs.animateTo(_indexOf(widget.initialTab));
    // A saved group comes back from the server: start the tab from it. The
    // other tabs keep their changes. (The schedule tabs follow the schedule.)
    final before = oldWidget.details;
    final after = widget.details;
    String json(Object? value) => jsonEncode(value);
    if (json(before.info.toJson()) != json(after.info.toJson())) _info.fill(after.info);
    if (json(before.address.toJson()) != json(after.address.toJson())) _address.fill(after.address);
    if (json(before.contact.toJson()) != json(after.contact.toJson())) _contact.fill(after.contact);
    if (json([before.clinicInfo.paymentMethods, before.clinicInfo.amenities]) !=
        json([after.clinicInfo.paymentMethods, after.clinicInfo.amenities])) {
      _checklist.fill(after.clinicInfo);
    }
  }

  @override
  void dispose() {
    _scheduleSubscription?.close();
    _tabs.dispose();
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  int get _dirty => _drafts.fold(0, (sum, d) => sum + d.changes);

  void _fill(BranchTab tab) {
    final d = widget.details;
    final saved = _saved;
    switch (tab) {
      case BranchTab.info:
        _info.fill(d.info);
      case BranchTab.address:
        _address.fill(d.address);
      case BranchTab.contact:
        _contact.fill(d.contact);
      case BranchTab.hours:
        _hours.fill(saved == null ? d.workingHours.periods : [for (final p in saved.weekly) p.toBranchPeriod()]);
      case BranchTab.dates:
        if (saved != null) _dates.fill(saved);
      case BranchTab.booking:
        if (saved != null) _booking.fill(saved.settings);
      case BranchTab.clinic:
        _checklist.fill(d.clinicInfo);
    }
  }

  void _discardAll() {
    for (final tab in BranchTab.values) {
      _fill(tab);
    }
    setState(() {
      for (final s in _state.values) {
        s
          ..server = const {}
          ..showClient = false
          ..error = null;
      }
    });
  }

  void _discard(BranchTab tab) {
    _fill(tab);
    setState(() {
      _state[tab]!
        ..server = const {}
        ..showClient = false
        ..error = null;
    });
  }

  Future<void> _confirmDiscard(BranchTab tab) async {
    final count = _draftOf(tab).changes;
    if (count == 0 || await confirmDiscardChanges(context, count)) _discard(tab);
  }

  /// Runs one tab's save with the common states: the app's check first,
  /// then the API, with its field errors next to their fields. [write]
  /// returns the message to show.
  Future<void> _save(BranchTab tab, {required bool valid, required Future<String?> Function() write}) async {
    final l10n = AppLocalizations.of(context);
    final reduced = Motion.of(context).reduced;
    final s = _state[tab]!;
    setState(() {
      s
        ..server = const {}
        ..error = null
        ..showClient = true;
    });
    if (!valid) {
      setState(() {
        s
          ..failures += 1
          ..error = l10n.adminFixErrors;
      });
      return;
    }
    setState(() => s.status = SubmitStatus.loading);
    try {
      final message = await write();
      if (!mounted) return;
      setState(() {
        s
          ..status = SubmitStatus.success
          ..showClient = false;
      });
      showAdminSnack(context, message ?? l10n.branchSaved);
      await Future<void>.delayed(reduced ? Duration.zero : Motion.slow);
      if (mounted) setState(() => s.status = SubmitStatus.idle);
    } on _NotApplied {
      if (!mounted) return;
      setState(() => s.status = SubmitStatus.idle);
      showAdminSnack(context, l10n.scheduleNothingSaved);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        s
          ..status = SubmitStatus.idle
          ..server = error.fieldCodes
          ..failures += 1
          ..error = error.fieldCodes.isEmpty ? _errorText(l10n, error) : l10n.adminFixErrors;
      });
    }
  }

  /// A refused move names the booking problem (6.12.6); other errors as usual.
  String _errorText(AppLocalizations l10n, ApiException error) => switch (error.code) {
        'SLOT_TAKEN' || 'PERIOD_FULL' || 'OUTSIDE_HOURS' || 'BRANCH_CLOSED' || 'TOO_SOON' || 'ALREADY_HANDLED' || 'INVALID_TRANSITION' =>
          context.bookingError(ApiError(error.code!)),
        'OVERBOOKING_WARNING' => l10n.scheduleMoveFull,
        _ => l10n.apiError(error),
      };

  Future<String?> _saveBranch(Future<void> write) async {
    await write;
    return null;
  }

  Future<void> _saveInfo() =>
      _save(BranchTab.info, valid: _info.check().isEmpty, write: () => _saveBranch(_controller.saveInfo(_info.build())));

  Future<void> _saveAddress() =>
      _save(BranchTab.address, valid: _address.check().isEmpty, write: () => _saveBranch(_controller.saveAddress(_address.build())));

  Future<void> _saveContact() =>
      _save(BranchTab.contact, valid: _contact.check().isEmpty, write: () => _saveBranch(_controller.saveContact(_contact.build())));

  Future<void> _saveChecklists() =>
      _save(BranchTab.clinic, valid: true, write: () => _saveBranch(_controller.saveChecklists(_checklist.build())));

  /// A schedule tab sends its own part and the others as saved.
  BranchScheduleData _scheduleFor(BranchTab tab, BranchScheduleData saved) => switch (tab) {
        BranchTab.hours => saved.copyWith(weekly: [for (final p in _hours.build()) p.toWeekly()]),
        BranchTab.dates => saved.copyWith(overrides: _dates.overrides, closures: _dates.closures),
        _ => saved.copyWith(settings: _booking.value),
      };

  Future<void> _saveSchedule(BranchTab tab) async {
    final saved = _saved;
    if (saved == null) return;
    final valid = tab != BranchTab.hours || WeeklyHours.check(_hours.build()).isEmpty;
    await _save(tab, valid: valid, write: () => _writeSchedule(tab, _scheduleFor(tab, saved)));
  }

  /// BR-AP12: a dry run first; bookings left without a place open the
  /// conflicts sheet, and the change is applied with a decision for each. If
  /// more bookings were affected meanwhile, the sheet opens again for them.
  Future<String?> _writeSchedule(BranchTab tab, BranchScheduleData data) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(appointmentsRepositoryProvider);
    final decisions = <String, ConflictDecision>{};
    var pending = (await repository.saveSchedule(data, dryRun: true)).conflicts;
    while (true) {
      if (pending.isNotEmpty) {
        if (!mounted) throw const _NotApplied();
        // The save waits for the doctor's decisions, not for the network.
        setState(() => _state[tab]!.status = SubmitStatus.idle);
        final chosen = await showScheduleConflictsSheet(context, conflicts: pending, branchId: data.branchId);
        if (chosen == null || !mounted) throw const _NotApplied();
        setState(() => _state[tab]!.status = SubmitStatus.loading);
        decisions.addAll(chosen);
      }
      final result = await repository.saveSchedule(data, dryRun: false, decisions: decisions);
      if (result.applied) break;
      pending = result.conflicts;
    }

    _saved = data;
    _fill(tab);
    ref.invalidate(availabilityProvider);
    unawaited(_controller.refresh());
    final moved = decisions.values.where((d) => d.action == ConflictDecision.moveAction).length;
    final cancelled = decisions.values.where((d) => d.action == ConflictDecision.cancelAction).length;
    return [
      l10n.scheduleSaved,
      if (moved > 0) l10n.scheduleMovedCount(moved),
      if (cancelled > 0) l10n.scheduleCancelledCount(cancelled),
    ].join(l10n.regListSeparator);
  }

  /// Hours problems by the period's index in what is sent: the API's when
  /// it answered (`weekly[i]…`), else the app's own check once Save was tapped.
  (Map<int, List<String>>, String?) _hoursErrors(AppLocalizations l10n) {
    final s = _state[BranchTab.hours]!;
    final byPeriod = <int, List<String>>{};
    String? week;
    void add(int index, String code) {
      final message = code == 'INVALID_VALUE' && index < 0 ? l10n.branchErrorTooManyPeriods : (l10n.fieldError(code) ?? l10n.adminErrorInvalidValue);
      if (index < 0) {
        week = message;
      } else {
        (byPeriod[index] ??= []).add(message);
      }
    }

    if (s.server.isNotEmpty) {
      final path = RegExp(r'^weekly(?:\[(\d+)\])?');
      for (final MapEntry(:key, :value) in s.server.entries) {
        final match = path.firstMatch(key);
        if (match == null) continue;
        add(match.group(1) == null ? -1 : int.parse(match.group(1)!), value);
      }
    } else if (s.showClient) {
      for (final problem in WeeklyHours.check(_hours.build())) {
        add(problem.index, problem.code);
      }
    }
    return (byPeriod, week);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([for (final d in _drafts) d.edits]),
      builder: (context, _) {
        final dirty = _dirty;
        return PopScope(
          canPop: dirty == 0,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            if (await confirmDiscardChanges(context, dirty) && mounted) {
              _discardAll();
              navigator.pop();
            }
          },
          child: _layout(context),
        );
      },
    );
  }

  Widget _layout(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final details = widget.details;
    final attention = context.el3yadaColors.attention;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = adminGutter(constraints.maxWidth);
        Tab tab(BranchTab t) {
          final (label, icon) = _labelOf(l10n, t);
          final dirty = _draftOf(t).changes > 0;
          return Tab(
            height: 52,
            child: Semantics(
              label: dirty ? l10n.branchTabUnsaved(label) : label,
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Text(label),
                  AnimatedScale(
                    scale: dirty ? 1 : 0,
                    duration: Motion.of(context).reduced ? Duration.zero : Motion.fast,
                    curve: Motion.springBouncy,
                    child: Container(
                      margin: const EdgeInsetsDirectional.only(start: 6),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: attention, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 8),
              child: AdminHeader(
                leading: widget.back,
                title: details.name(language),
                subtitle: [details.address.city, details.address.governorate].where((s) => s.isNotEmpty).join(l10n.regListSeparator),
                actions: [
                  if (details.isDefault) const DefaultBranchPill(),
                  BranchStatusPill(status: details.status),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.symmetric(horizontal: gutter - 8),
              labelStyle: theme.textTheme.titleSmall,
              tabs: [for (final t in _visible) tab(t)],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [for (final t in _visible) _page(t, gutter)],
              ),
            ),
          ],
        );
      },
    );
  }

  (String, IconData) _labelOf(AppLocalizations l10n, BranchTab tab) => switch (tab) {
        BranchTab.info => (l10n.branchTabInfo, Icons.info_outline),
        BranchTab.address => (l10n.branchTabAddress, Icons.map_outlined),
        BranchTab.contact => (l10n.branchTabContact, Icons.call_outlined),
        BranchTab.hours => (l10n.branchTabHours, Icons.schedule_outlined),
        BranchTab.dates => (l10n.specialDates, Icons.event_note_outlined),
        BranchTab.booking => (l10n.bookingSettings, Icons.tune_outlined),
        BranchTab.clinic => (l10n.branchTabClinic, Icons.storefront_outlined),
      };

  Widget _page(BranchTab tab, double gutter) {
    if (!_canEditBranch && !scheduleTabs.contains(tab)) {
      return _KeepAlive(
        child: ClinicPage(
          maxWidth: 820,
          builder: (context, width) => [
            const DoctorOnlyNote(),
            const SizedBox(height: 16),
            switch (tab) {
              BranchTab.address => BranchAddressReadOnly(address: widget.details.address),
              BranchTab.contact => BranchContactReadOnly(contact: widget.details.contact),
              _ => BranchInfoReadOnly(details: widget.details),
            },
            if (tab == BranchTab.info) ...[const SizedBox(height: 16), BranchPhotosCard(details: widget.details, editable: false)],
          ],
        ),
      );
    }
    if (scheduleTabs.contains(tab) && _saved == null) return _KeepAlive(child: _scheduleLoading());
    return switch (tab) {
      BranchTab.info => _tab(tab, gutter, _infoTab(context), _saveInfo),
      BranchTab.address => _tab(tab, gutter, _addressTab(context), _saveAddress),
      BranchTab.contact => _tab(tab, gutter, _contactTab(context), _saveContact),
      BranchTab.hours => _tab(tab, gutter, _hoursTab(context), () => _saveSchedule(BranchTab.hours)),
      BranchTab.dates => _tab(tab, gutter, _datesTab(context), () => _saveSchedule(BranchTab.dates)),
      BranchTab.booking => _tab(tab, gutter, _bookingTab(context), () => _saveSchedule(BranchTab.booking)),
      BranchTab.clinic => _tab(tab, gutter, _clinicTab(context), _saveChecklists),
    };
  }

  /// The schedule tabs until `GET …/schedule` answers.
  Widget _scheduleLoading() {
    final schedule = ref.watch(scheduleProvider(widget.details.id));
    if (schedule.hasError) {
      return AdminErrorView(error: schedule.error!, onRetry: () => ref.invalidate(scheduleProvider(widget.details.id)));
    }
    return const _EditorSkeleton();
  }

  Widget _tab(BranchTab tab, double gutter, List<Widget> children, VoidCallback onSave) {
    final s = _state[tab]!;
    final dirty = _draftOf(tab).changes;
    final showBar = dirty > 0 || s.status != SubmitStatus.idle;
    return _KeepAlive(
      child: Column(
        children: [
          Expanded(
            child: ClinicPage(
              maxWidth: tab == BranchTab.hours ? 1100 : 820,
              bottomBarVisible: showBar,
              builder: (context, width) => [for (final (i, child) in children.indexed) ...[if (i > 0) const SizedBox(height: 16), child]],
            ),
          ),
          SaveBar(
            visible: showBar,
            dirty: dirty,
            status: s.status,
            error: s.error,
            failures: s.failures,
            gutter: gutter,
            bottomInset: MediaQuery.paddingOf(context).bottom,
            onDiscard: () => _confirmDiscard(tab),
            onSave: onSave,
          ),
        ],
      ),
    );
  }

  FieldErrors _errors(BranchTab tab, Map<String, BranchProblem> client) {
    final s = _state[tab]!;
    return FieldErrors(server: s.server, client: client, showClient: s.showClient);
  }

  bool _busy(BranchTab tab) => _state[tab]!.status != SubmitStatus.idle;

  List<Widget> _infoTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      SectionCard(
        icon: Icons.storefront_outlined,
        title: l10n.branchTabInfo,
        child: InfoFields(draft: _info, errors: _errors(BranchTab.info, _info.check()), enabled: !_busy(BranchTab.info)),
      ),
      BranchPhotosCard(details: widget.details),
      _StatusCard(details: widget.details),
    ];
  }

  List<Widget> _addressTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      SectionCard(
        icon: Icons.map_outlined,
        title: l10n.branchTabAddress,
        child: AddressFields(draft: _address, errors: _errors(BranchTab.address, _address.check()), enabled: !_busy(BranchTab.address)),
      ),
    ];
  }

  List<Widget> _contactTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      SectionCard(
        icon: Icons.call_outlined,
        title: l10n.branchTabContact,
        child: ContactFields(draft: _contact, errors: _errors(BranchTab.contact, _contact.check()), enabled: !_busy(BranchTab.contact)),
      ),
    ];
  }

  /// The saved booking settings: the hours and dates tabs show capacity in queue mode.
  BookingSettings get _settings => _saved?.settings ?? const BookingSettings();

  List<Widget> _hoursTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = _settings;
    final queueMode = settings.mode == 'queue';
    final (periodErrors, weekError) = _hoursErrors(l10n);
    final hasSaturday = _hours.ofDay(DateTime.saturday).isNotEmpty;
    final enabled = _canEditSchedule && !_busy(BranchTab.hours);
    return [
      InfoBanner(
        icon: Icons.confirmation_number_outlined,
        message: queueMode ? l10n.branchHoursQueueNote(settings.defaultCapacity) : l10n.branchHoursTimedNote,
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: hasSaturday && enabled ? _copySaturday : null,
          icon: const Icon(Icons.content_copy_outlined),
          label: Text(l10n.branchCopySaturday),
        ),
      ),
      HoursEditor(
        draft: _hours,
        queueMode: queueMode,
        defaultCapacity: settings.defaultCapacity,
        periodErrors: periodErrors,
        weekError: weekError,
        enabled: enabled,
      ),
    ];
  }

  Future<void> _copySaturday() async {
    final l10n = AppLocalizations.of(context);
    final others = _hours.periods.any((p) => p.weekday != DateTime.saturday);
    if (others &&
        !await confirmAction(
          context,
          title: l10n.branchCopySaturdayTitle,
          message: l10n.branchCopySaturdayBody,
          confirmLabel: l10n.branchCopySaturday,
        )) {
      return;
    }
    _hours.copySaturdayToAll();
  }

  List<Widget> _datesTab(BuildContext context) {
    final settings = _settings;
    final enabled = _canEditSchedule && !_busy(BranchTab.dates);
    final holidays = _saved?.holidays ?? const <HolidayRef>[];
    return [
      SpecialDatesEditor(
        draft: _dates,
        queueMode: settings.mode == 'queue',
        defaultCapacity: settings.defaultCapacity,
        enabled: enabled,
        extra: holidays.isEmpty ? null : HolidaySuggestions(holidays: holidays, draft: _dates, enabled: enabled),
      ),
    ];
  }

  List<Widget> _bookingTab(BuildContext context) => [
        BookingSettingsEditor(draft: _booking, enabled: _canEditSchedule && !_busy(BranchTab.booking)),
      ];

  List<Widget> _clinicTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prices = widget.details.clinicInfo.prices;
    final doctorPrices = ref.watch(pricesProvider).value?.doctor;
    return [
      SectionCard(
        icon: Icons.sell_outlined,
        title: l10n.branchPricesTitle,
        subtitle: l10n.pricesFutureOnly,
        child: doctorPrices == null
            ? SkeletonLoading(loading: true, child: Text(l10n.pricesUseDoctor))
            : PriceEditor(
                key: ValueKey((prices.examinationPricePiasters, prices.consultationPricePiasters, doctorPrices)),
                fieldPrefix: 'branch',
                saved: PricePair(
                  examinationPricePiasters: prices.examinationPricePiasters,
                  consultationPricePiasters: prices.consultationPricePiasters,
                ),
                doctorPrices: doctorPrices,
                onSave: (exam, consult) => _controller.savePrices(examination: exam, consultation: consult),
              ),
      ),
      SectionCard(
        icon: Icons.payments_outlined,
        title: l10n.branchForPatients,
        subtitle: l10n.branchForPatientsBody,
        child: ChecklistFields(draft: _checklist, enabled: !_busy(BranchTab.clinic)),
      ),
    ];
  }
}

/// Keeps a tab's scroll position and fields while another tab shows.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// The Info tab's status block: what the status means for patients, and
/// the actions it allows. Each action applies at once, after a confirm.
class _StatusCard extends ConsumerStatefulWidget {
  const _StatusCard({required this.details});

  final BranchDetails details;

  @override
  ConsumerState<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends ConsumerState<_StatusCard> {
  bool _busy = false;

  BranchDetailController get _controller => ref.read(branchDetailProvider(widget.details.id).notifier);

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) showAdminSnack(context, done);
    } on ApiException catch (error) {
      if (mounted) await showBranchRefusal(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close({bool editing = false}) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<(String, DateTime?)>(
      context: context,
      builder: (context) => _ClosureDialog(
        message: editing ? widget.details.closedMessage : null,
        reopenDate: editing ? widget.details.reopenDate : null,
      ),
    );
    if (result == null || !mounted) return;
    await _run(
      () => _controller.setStatus(BranchStatuses.temporarilyClosed, closedMessage: result.$1, reopenDate: result.$2),
      l10n.branchClosedMessage,
    );
  }

  Future<void> _archive() async {
    final l10n = AppLocalizations.of(context);
    final name = widget.details.name(Localizations.localeOf(context).languageCode);
    final confirmed = await confirmAction(
      context,
      title: l10n.branchArchiveTitle(name),
      message: l10n.branchArchiveBody,
      confirmLabel: l10n.branchArchive,
      destructive: true,
    );
    if (confirmed && mounted) await _run(() => _controller.setStatus(BranchStatuses.archived), l10n.branchArchivedMessage);
  }

  Future<void> _activate() async {
    final l10n = AppLocalizations.of(context);
    final archived = widget.details.archived;
    await _run(() => _controller.setStatus(BranchStatuses.active), archived ? l10n.branchRestoredMessage : l10n.branchReopenedMessage);
  }

  Future<void> _makeDefault() async {
    final l10n = AppLocalizations.of(context);
    final name = widget.details.name(Localizations.localeOf(context).languageCode);
    final confirmed = await confirmAction(
      context,
      title: l10n.branchMakeDefaultTitle(name),
      message: l10n.branchMakeDefaultBody,
      confirmLabel: l10n.branchMakeDefault,
    );
    if (confirmed && mounted) await _run(_controller.makeDefault, l10n.branchDefaultMessage(name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = widget.details;
    final enabled = !_busy;
    final String explanation = switch (d.status) {
      BranchStatuses.temporarilyClosed => l10n.branchStatusClosedBody,
      BranchStatuses.archived => l10n.branchStatusArchivedBody,
      _ => d.isDefault ? l10n.branchStatusDefaultBody : l10n.branchStatusActiveBody,
    };
    final destructive = OutlinedButton.styleFrom(foregroundColor: scheme.error, side: BorderSide(color: scheme.error, width: 2));
    return SectionCard(
      icon: Icons.toggle_on_outlined,
      title: l10n.branchStatusTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(explanation, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          if (d.temporarilyClosed) ...[
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.branchPatientsSee, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onTertiaryContainer)),
                    const SizedBox(height: 4),
                    Text(d.closedMessage ?? '', style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onTertiaryContainer)),
                    if (d.reopenDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.branchReopensOn(dayText(context, d.reopenDate!)),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onTertiaryContainer),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (d.active && !d.isDefault)
                FilledButton.tonalIcon(
                  onPressed: enabled ? _makeDefault : null,
                  icon: const Icon(Icons.star_outline_rounded),
                  label: Text(l10n.branchMakeDefault),
                ),
              if (d.active)
                OutlinedButton.icon(
                  onPressed: enabled ? _close : null,
                  icon: const Icon(Icons.pause_circle_outline),
                  label: Text(l10n.branchCloseTemporarily),
                ),
              if (d.temporarilyClosed) ...[
                FilledButton.icon(onPressed: enabled ? _activate : null, icon: const Icon(Icons.play_arrow_rounded), label: Text(l10n.branchReopen)),
                OutlinedButton.icon(
                  onPressed: enabled ? () => _close(editing: true) : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n.branchEditClosure),
                ),
              ],
              if (d.archived)
                FilledButton.icon(onPressed: enabled ? _activate : null, icon: const Icon(Icons.unarchive_outlined), label: Text(l10n.branchRestore))
              else
                OutlinedButton.icon(
                  style: destructive,
                  onPressed: enabled ? _archive : null,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(l10n.branchArchive),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A refused status change (BR-BR1, BR-BR9): why, and for bookings, which
/// ones stand in the way.
Future<void> showBranchRefusal(BuildContext context, ApiException error) {
  final l10n = AppLocalizations.of(context);
  final known = {
    ClinicAdminCodes.cannotArchiveDefaultBranch,
    ClinicAdminCodes.lastActiveBranch,
    ClinicAdminCodes.branchHasBookings,
    ClinicAdminCodes.branchNotActive,
    ClinicAdminCodes.branchLimitReached,
  };
  if (!known.contains(error.code)) {
    showAdminSnack(context, l10n.apiError(error), error: true);
    return Future.value();
  }
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      final bookings = error is BranchHasBookingsException ? error : null;
      return AlertDialog(
        icon: Icon(bookings != null ? Icons.event_busy_outlined : Icons.info_outline),
        title: Text(bookings != null ? l10n.branchBookingsTitle(bookings.totalCount) : l10n.branchRefusedTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.apiError(error)),
                if (bookings != null) ...[
                  const SizedBox(height: 12),
                  for (final booking in bookings.bookings) _BookingRow(booking: booking),
                  if (bookings.totalCount > bookings.bookings.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l10n.branchBookingsMore(bookings.totalCount - bookings.bookings.length),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(l10n.branchBookingsHint, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(l10n.ok))],
      );
    },
  );
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({required this.booking});

  final BranchBooking booking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.el3yadaColors;
    final consultation = booking.visitType == 'consultation';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ExcludeSemantics(child: Icon(Icons.event_outlined, size: 20, color: scheme.primary)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.isGuest ? l10n.branchBookingGuest(booking.name ?? '') : (booking.name ?? l10n.adminUnknownUser),
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  '${weekdayName(context, booking.localDate.weekday)} ${dayText(context, booking.localDate)}'
                  '${booking.periodStartLocal.isEmpty ? '' : l10n.regListSeparator + clockText(context, booking.periodStartLocal)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: ShapeDecoration(
              color: consultation ? colors.consultation : colors.examination,
              shape: const StadiumBorder(),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Text(
                l10n.visitTypeName(booking.visitType),
                style: theme.textTheme.labelMedium?.copyWith(color: consultation ? colors.onConsultation : colors.onExamination),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Temporarily close: the message patients see (required, ≤ 300) and an
/// optional reopening date (today or later).
class _ClosureDialog extends StatefulWidget {
  const _ClosureDialog({this.message, this.reopenDate});

  final String? message;
  final DateTime? reopenDate;

  @override
  State<_ClosureDialog> createState() => _ClosureDialogState();
}

class _ClosureDialogState extends State<_ClosureDialog> {
  late final _message = TextEditingController(text: widget.message ?? '');
  late DateTime? _reopen = widget.reopenDate;
  bool _tried = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDate: _reopen != null && !_reopen!.isBefore(today) ? _reopen! : today.add(const Duration(days: 7)),
    );
    if (picked != null) setState(() => _reopen = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = _message.text.trim();
    final error = !_tried ? null : (text.isEmpty ? l10n.errorRequired : (text.length > 300 ? l10n.adminErrorMaxLength('300') : null));
    return AlertDialog(
      icon: const Icon(Icons.pause_circle_outline),
      title: Text(l10n.branchCloseTemporarily),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.branchCloseBody),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('closedMessage'),
                controller: _message,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.branchClosedMessageLabel,
                  hintText: l10n.branchClosedMessageHint,
                  alignLabelWithHint: true,
                  errorText: error,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_reopen == null ? l10n.branchReopenDateAdd : l10n.branchReopensOn(dayText(context, _reopen!))),
                    ),
                  ),
                  if (_reopen != null)
                    IconButton(
                      tooltip: l10n.adminClearFilter,
                      onPressed: () => setState(() => _reopen = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.adminCancel)),
        FilledButton(
          onPressed: () {
            final message = _message.text.trim();
            if (message.isEmpty || message.length > 300) {
              setState(() => _tried = true);
              return;
            }
            Navigator.pop(context, (message, _reopen));
          },
          child: Text(l10n.branchCloseConfirm),
        ),
      ],
    );
  }
}

class _EditorSkeleton extends StatelessWidget {
  const _EditorSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonLoading(
        loading: true,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [
            Text('------------------'),
            SizedBox(height: 16),
            Text('---------   ---------   ---------'),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(decoration: InputDecoration(labelText: '----------')),
                    SizedBox(height: 16),
                    TextField(decoration: InputDecoration(labelText: '----------')),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

/// D29 "new": the Info, Address and Contact groups and the payment methods
/// on one page. After it is added the branch opens on Working hours.
class NewBranchScreen extends ConsumerStatefulWidget {
  const NewBranchScreen({super.key});

  @override
  ConsumerState<NewBranchScreen> createState() => _NewBranchScreenState();
}

class _NewBranchScreenState extends ConsumerState<NewBranchScreen> {
  final _info = InfoDraft();
  final _address = AddressDraft();
  final _contact = ContactDraft();
  final _checklist = ChecklistDraft();
  SubmitStatus _status = SubmitStatus.idle;
  Map<String, String> _server = const {};
  bool _showClient = false;
  String? _error;
  int _failures = 0;

  List<BranchDraft> get _drafts => [_info, _address, _contact, _checklist];

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  int get _changes => _info.changes + _address.changes + _contact.changes;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _showClient = true;
      _server = const {};
      _error = null;
    });
    if (_info.check().isNotEmpty || _address.check().isNotEmpty || _contact.check().isNotEmpty) {
      setState(() {
        _failures++;
        _error = l10n.adminFixErrors;
      });
      return;
    }
    setState(() => _status = SubmitStatus.loading);
    try {
      final created = await ref.read(branchesProvider.notifier).create(
            info: _info.build(),
            address: _address.build(),
            contact: _contact.build(),
            clinicInfo: _checklist.build(),
          );
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      showAdminSnack(context, l10n.branchAddedMessage);
      // Working hours come next; the branch's page replaces this one.
      context.go(ClinicAdminRoutes.branch(created.id, tab: BranchTab.hours.name));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _server = error.fieldCodes;
        _failures++;
        _error = error.fieldCodes.isEmpty ? l10n.apiError(error) : l10n.adminFixErrors;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(branchesProvider).value;
    if (list != null && !list.canAdd && _status == SubmitStatus.idle) {
      return Scaffold(
        body: Column(
          children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(padding: EdgeInsets.all(8), child: ClinicBackButton(fallback: ClinicAdminRoutes.branches)),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: InfoBanner(icon: Icons.block, tone: PillTone.warning, message: l10n.branchErrorLimitReached),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final busy = _status != SubmitStatus.idle;
    return Scaffold(
      body: ListenableBuilder(
        listenable: Listenable.merge([for (final d in _drafts) d.edits]),
        builder: (context, _) {
          final changes = _changes;
          return PopScope(
            canPop: changes == 0 || _status == SubmitStatus.success,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              final navigator = Navigator.of(context);
              if (await confirmDiscardChanges(context, changes) && mounted) navigator.pop();
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gutter = adminGutter(constraints.maxWidth);
                FieldErrors errors(Map<String, BranchProblem> client) => FieldErrors(server: _server, client: client, showClient: _showClient);
                return Column(
                  children: [
                    Expanded(
                      child: ClinicPage(
                        maxWidth: 820,
                        bottomBarVisible: true,
                        builder: (context, width) => [
                          AdminHeader(
                            leading: const ClinicBackButton(fallback: ClinicAdminRoutes.branches),
                            title: l10n.branchAdd,
                            subtitle: list == null ? null : l10n.branchCountOf(list.count + 1, list.limit),
                          ),
                          const SizedBox(height: 16),
                          SectionCard(
                            icon: Icons.storefront_outlined,
                            title: l10n.branchTabInfo,
                            child: InfoFields(draft: _info, errors: errors(_info.check()), enabled: !busy),
                          ),
                          const SizedBox(height: 16),
                          SectionCard(
                            icon: Icons.map_outlined,
                            title: l10n.branchTabAddress,
                            child: AddressFields(draft: _address, errors: errors(_address.check()), enabled: !busy),
                          ),
                          const SizedBox(height: 16),
                          SectionCard(
                            icon: Icons.call_outlined,
                            title: l10n.branchTabContact,
                            child: ContactFields(draft: _contact, errors: errors(_contact.check()), enabled: !busy),
                          ),
                          const SizedBox(height: 16),
                          SectionCard(
                            icon: Icons.payments_outlined,
                            title: l10n.branchForPatients,
                            subtitle: l10n.branchNewNextSteps,
                            child: ChecklistFields(draft: _checklist, enabled: !busy),
                          ),
                        ],
                      ),
                    ),
                    _CreateBar(
                      status: _status,
                      error: _error,
                      failures: _failures,
                      gutter: gutter,
                      onSubmit: _submit,
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CreateBar extends StatelessWidget {
  const _CreateBar({required this.status, required this.error, required this.failures, required this.gutter, required this.onSubmit});

  final SubmitStatus status;
  final String? error;
  final int failures;
  final double gutter;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 6,
      shadowColor: scheme.shadow.withValues(alpha: 0.3),
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(liveRegion: true, child: Text(error!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error))),
              ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200),
                child: SubmitButton(label: l10n.branchAdd, status: status, onPressed: onSubmit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
