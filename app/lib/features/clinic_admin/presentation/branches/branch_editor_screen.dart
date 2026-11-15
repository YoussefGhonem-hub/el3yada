import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/save_bar.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
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
import 'branch_text.dart';

/// The D29 tabs, by their `?tab=` name. Booking settings and special dates
/// come in Phase 6.
enum BranchTab { info, address, contact, hours, clinic }

/// D29: one branch in tabs (Info, Address and map, Contact, Working hours,
/// Clinic info for patients). Each tab saves its own group; a tab with
/// unsaved changes carries a dot, and leaving with changes asks first. The
/// Info tab also holds the status: temporarily close, reopen, archive, make
/// default, with the API's refusals explained (BR-BR1, BR-BR9).
class BranchEditorScreen extends ConsumerWidget {
  const BranchEditorScreen({super.key, required this.branchId, this.initialTab});

  final String branchId;
  final BranchTab? initialTab;

  static BranchTab? tabNamed(String? name) => BranchTab.values.where((t) => t.name == name).firstOrNull;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(branchDetailProvider(branchId));
    return Scaffold(
      body: AsyncStateSwitcher<BranchDetails>(
        value: branch,
        loading: (context) => const _EditorSkeleton(),
        error: (context, error) => Column(
          children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(padding: EdgeInsets.all(8), child: ClinicBackButton(fallback: ClinicAdminRoutes.branches)),
            ),
            Expanded(
              child: AdminErrorView(error: error, onRetry: () => ref.read(branchDetailProvider(branchId).notifier).reload()),
            ),
          ],
        ),
        data: (context, details) => _BranchEditor(details: details, initialTab: initialTab ?? BranchTab.info),
      ),
    );
  }
}

class _BranchEditor extends ConsumerStatefulWidget {
  const _BranchEditor({required this.details, required this.initialTab});

  final BranchDetails details;
  final BranchTab initialTab;

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

class _BranchEditorState extends ConsumerState<_BranchEditor> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: BranchTab.values.length, vsync: this, initialIndex: widget.initialTab.index);
  late final _info = InfoDraft(widget.details.info);
  late final _address = AddressDraft(widget.details.address);
  late final _contact = ContactDraft(widget.details.contact);
  late final _hours = HoursDraft(widget.details.workingHours.periods);
  late final _checklist = ChecklistDraft(widget.details.clinicInfo);
  final _state = {for (final tab in BranchTab.values) tab: _TabState()};

  BranchDetailController get _controller => ref.read(branchDetailProvider(widget.details.id).notifier);

  List<BranchDraft> get _drafts => [_info, _address, _contact, _hours, _checklist];

  BranchDraft _draftOf(BranchTab tab) => switch (tab) {
        BranchTab.info => _info,
        BranchTab.address => _address,
        BranchTab.contact => _contact,
        BranchTab.hours => _hours,
        BranchTab.clinic => _checklist,
      };

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void didUpdateWidget(_BranchEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Opened again by a link to another tab.
    if (oldWidget.initialTab != widget.initialTab) _tabs.animateTo(widget.initialTab.index);
    // A saved group comes back from the server: start the tab from it. The
    // other tabs keep their changes.
    final before = oldWidget.details;
    final after = widget.details;
    String json(Object? value) => jsonEncode(value);
    if (json(before.info.toJson()) != json(after.info.toJson())) _info.fill(after.info);
    if (json(before.address.toJson()) != json(after.address.toJson())) _address.fill(after.address);
    if (json(before.contact.toJson()) != json(after.contact.toJson())) _contact.fill(after.contact);
    if (json([for (final p in before.workingHours.periods) p.toJson()]) != json([for (final p in after.workingHours.periods) p.toJson()])) {
      _hours.fill(after.workingHours.periods);
    }
    if (json([before.clinicInfo.paymentMethods, before.clinicInfo.amenities]) !=
        json([after.clinicInfo.paymentMethods, after.clinicInfo.amenities])) {
      _checklist.fill(after.clinicInfo);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  int get _dirty => _drafts.fold(0, (sum, d) => sum + d.changes);

  void _discardAll() {
    final d = widget.details;
    _info.fill(d.info);
    _address.fill(d.address);
    _contact.fill(d.contact);
    _hours.fill(d.workingHours.periods);
    _checklist.fill(d.clinicInfo);
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
    final d = widget.details;
    switch (tab) {
      case BranchTab.info:
        _info.fill(d.info);
      case BranchTab.address:
        _address.fill(d.address);
      case BranchTab.contact:
        _contact.fill(d.contact);
      case BranchTab.hours:
        _hours.fill(d.workingHours.periods);
      case BranchTab.clinic:
        _checklist.fill(d.clinicInfo);
    }
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
  /// then the API, with its field errors next to their fields.
  Future<void> _save(BranchTab tab, {required bool valid, required Future<void> Function() write}) async {
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
      await write();
      if (!mounted) return;
      setState(() {
        s
          ..status = SubmitStatus.success
          ..showClient = false;
      });
      showAdminSnack(context, l10n.branchSaved);
      await Future<void>.delayed(reduced ? Duration.zero : Motion.slow);
      if (mounted) setState(() => s.status = SubmitStatus.idle);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        s
          ..status = SubmitStatus.idle
          ..server = error.fieldCodes
          ..failures += 1
          ..error = error.fieldCodes.isEmpty ? l10n.apiError(error) : l10n.adminFixErrors;
      });
    }
  }

  Future<void> _saveInfo() =>
      _save(BranchTab.info, valid: _info.check().isEmpty, write: () => _controller.saveInfo(_info.build()));

  Future<void> _saveAddress() =>
      _save(BranchTab.address, valid: _address.check().isEmpty, write: () => _controller.saveAddress(_address.build()));

  Future<void> _saveContact() =>
      _save(BranchTab.contact, valid: _contact.check().isEmpty, write: () => _controller.saveContact(_contact.build()));

  Future<void> _saveChecklists() =>
      _save(BranchTab.clinic, valid: true, write: () => _controller.saveChecklists(_checklist.build()));

  Future<void> _saveHours() =>
      _save(BranchTab.hours, valid: WeeklyHours.check(_hours.build()).isEmpty, write: () => _controller.saveHours(_hours.build()));

  /// Hours problems by the period's index in what is sent: the API's when
  /// it answered, else the app's own check once Save was tapped.
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
      final path = RegExp(r'^periods(?:\[(\d+)\])?');
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
        Tab tab(BranchTab t, String label, IconData icon) {
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
                leading: const ClinicBackButton(fallback: ClinicAdminRoutes.branches),
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
              tabs: [
                tab(BranchTab.info, l10n.branchTabInfo, Icons.info_outline),
                tab(BranchTab.address, l10n.branchTabAddress, Icons.map_outlined),
                tab(BranchTab.contact, l10n.branchTabContact, Icons.call_outlined),
                tab(BranchTab.hours, l10n.branchTabHours, Icons.schedule_outlined),
                tab(BranchTab.clinic, l10n.branchTabClinic, Icons.storefront_outlined),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _tab(BranchTab.info, gutter, _infoTab(context), _saveInfo),
                  _tab(BranchTab.address, gutter, _addressTab(context), _saveAddress),
                  _tab(BranchTab.contact, gutter, _contactTab(context), _saveContact),
                  _tab(BranchTab.hours, gutter, _hoursTab(context), _saveHours),
                  _tab(BranchTab.clinic, gutter, _clinicTab(context), _saveChecklists),
                ],
              ),
            ),
          ],
        );
      },
    );
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
      _StatusCard(details: widget.details),
      SettingsGroup(
        title: l10n.branchLaterTabs,
        children: [
          SettingsTile(
            icon: Icons.event_note_outlined,
            title: l10n.branchLaterTabsTitle,
            subtitle: l10n.branchLaterTabsBody,
            trailing: StatusPill(label: l10n.settingsLaterPhase),
          ),
        ],
      ),
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

  List<Widget> _hoursTab(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hours = widget.details.workingHours;
    final (periodErrors, weekError) = _hoursErrors(l10n);
    final hasSaturday = _hours.ofDay(DateTime.saturday).isNotEmpty;
    return [
      InfoBanner(
        icon: Icons.confirmation_number_outlined,
        message: hours.queueMode ? l10n.branchHoursQueueNote(hours.defaultCapacity) : l10n.branchHoursTimedNote,
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: hasSaturday && !_busy(BranchTab.hours) ? _copySaturday : null,
          icon: const Icon(Icons.content_copy_outlined),
          label: Text(l10n.branchCopySaturday),
        ),
      ),
      HoursEditor(
        draft: _hours,
        queueMode: hours.queueMode,
        defaultCapacity: hours.defaultCapacity,
        periodErrors: periodErrors,
        weekError: weekError,
        enabled: !_busy(BranchTab.hours),
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
