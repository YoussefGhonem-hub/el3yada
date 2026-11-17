import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/container_transform.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/admin_controllers.dart';
import '../../../../core/data/paged_controller.dart';
import '../../domain/admin_models.dart';
import '../widgets/admin_widgets.dart';
import 'signup_review.dart';
import 'trial_parts.dart';

/// A doctor who signed up in the last day gets the coral "new" mark.
const _newFor = Duration(days: 1);

/// AD2, «الأطباء»: every doctor, newest first, with search and the
/// free-trial filter (all, in trial, trial ended). New doctors are active at
/// once (spec 6.16); legacy sign-ups still pending or rejected show their
/// status and can be reviewed in AD3. Phones show cards that grow into AD3
/// (container transform); wide screens show the list and AD3 side by side.
class SignupRequestsScreen extends ConsumerStatefulWidget {
  const SignupRequestsScreen({super.key});

  @override
  ConsumerState<SignupRequestsScreen> createState() => _SignupRequestsScreenState();
}

class _SignupRequestsScreenState extends ConsumerState<SignupRequestsScreen> {
  static const _searchDelay = Duration(milliseconds: 350);

  final _search = TextEditingController();
  Timer? _debounce;

  /// The request open in the detail pane (wide layout).
  String? _selected;

  /// Changes when the results change, so the list entrance plays again.
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  SignupsController get _controller => ref.read(signupsControllerProvider.notifier);

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(_searchDelay, () {
      _controller.setSearch(value);
      setState(() => _generation++);
    });
  }

  void _onSort(SignupSort sort) {
    _controller.setSort(sort);
    setState(() => _generation++);
  }

  /// Every doctor, or by free-trial state (spec 6.16).
  void _onTrial(TrialFilter? trial) {
    if (trial == _controller.trial) return;
    _controller.setTrial(trial);
    setState(() {
      _generation++;
      _selected = null;
    });
  }

  Future<void> _refresh() async {
    await _controller.refresh();
    if (!mounted) return;
    final state = ref.read(signupsControllerProvider);
    if (state.error != null && state.items.isNotEmpty) {
      showAdminSnack(context, AppLocalizations.of(context).adminRefreshFailed, error: true);
    }
  }

  /// Wide layout: after a legacy sign-up's review, the doctor stays open
  /// with the new status.
  void _onReviewedInPane(DoctorRegistration registration, ReviewDecision decision) {
    _controller.reviewed(registration.doctorId);
    ref.invalidate(registrationDetailProvider(registration.doctorId));
    showAdminSnack(context, reviewedMessage(AppLocalizations.of(context), registration, decision));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signupsControllerProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kAdminWideLayout;
        if (!wide) return _list(context, state, wide: false);

        // Open the first request when nothing is selected yet.
        if (_selected == null && state.items.isNotEmpty && !state.loading) {
          final first = state.items.first.doctorId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selected == null) setState(() => _selected = first);
          });
        }
        final listWidth = (constraints.maxWidth * 0.38).clamp(340.0, 440.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: listWidth, child: _list(context, state, wide: true)),
            const VerticalDivider(width: 1),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.normal,
                reverseDuration: Motion.normalExit,
                switchInCurve: Motion.enterCurve,
                switchOutCurve: Motion.exitCurveReversed,
                child: _selected == null
                    ? KeyedSubtree(
                        key: const ValueKey('none'),
                        child: EmptyState(
                          title: state.items.isEmpty && !state.loading
                              ? AppLocalizations.of(context).adminSignupsEmptyTitle
                              : AppLocalizations.of(context).adminSelectRequest,
                        ),
                      )
                    : SignupReviewView(
                        key: ValueKey(_selected),
                        doctorId: _selected!,
                        onReviewed: _onReviewedInPane,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context, PagedState<RegistrationSummary> state, {required bool wide}) {
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final gutter = wide ? 20.0 : adminGutter(width);
    final sort = ref.read(signupsControllerProvider.notifier).sort;
    final trial = ref.read(signupsControllerProvider.notifier).trial;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 12),
          child: AdminHeader(
            title: l10n.navSignups,
            subtitle: state.loading ? l10n.loading : l10n.adminDoctorsCount(state.totalCount),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.adminSignupsSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: ValueListenableBuilder(
                      valueListenable: _search,
                      builder: (context, value, _) => value.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: l10n.adminClearSearch,
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _search.clear();
                                _onSearch('');
                              },
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<SignupSort>(
                tooltip: l10n.adminSort,
                initialValue: sort,
                onSelected: _onSort,
                icon: const Icon(Icons.swap_vert),
                itemBuilder: (context) => [
                  CheckedPopupMenuItem(value: SignupSort.newest, checked: sort == SignupSort.newest, child: Text(l10n.adminSortNewest)),
                  CheckedPopupMenuItem(value: SignupSort.oldest, checked: sort == SignupSort.oldest, child: Text(l10n.adminSortOldest)),
                ],
              ),
              // Phones pull to refresh; mouse users get a button.
              if (wide)
                IconButton(
                  tooltip: l10n.adminRefresh,
                  onPressed: state.refreshing ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Every doctor, or by free-trial state (spec 6.16).
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in [
                (null, l10n.adminDoctorsFilterAll),
                (TrialFilter.running, l10n.adminSignupsFilterTrialRunning),
                (TrialFilter.ended, l10n.adminSignupsFilterTrialEnded),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: trial == value,
                  onSelected: (_) => _onTrial(value),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: StateSwitcher(
            state: state.view,
            loading: (context) => _SignupListSkeleton(gutter: gutter, compact: wide),
            empty: (context) => RefreshIndicator(
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: EmptyState(
                      title: _controller.search.isNotEmpty
                          ? l10n.adminSignupsNoMatchTitle
                          : trial != null
                              ? l10n.adminTrialListEmpty
                              : l10n.adminSignupsEmptyTitle,
                      message: _controller.search.isNotEmpty
                          ? l10n.adminSignupsNoMatchBody
                          : trial != null
                              ? l10n.adminTrialListEmptyBody
                              : l10n.adminSignupsEmptyBody,
                      actionLabel: _controller.search.isEmpty ? l10n.adminRefresh : l10n.adminClearSearch,
                      onAction: _controller.search.isEmpty
                          ? _refresh
                          : () {
                              _search.clear();
                              _onSearch('');
                            },
                    ),
                  ),
                ),
              ),
            ),
            error: (context) => AdminErrorView(error: state.error!, onRetry: _controller.reload),
            content: (context) => _results(context, state, gutter: gutter, wide: wide),
          ),
        ),
      ],
    );
  }

  Widget _results(BuildContext context, PagedState<RegistrationSummary> state, {required double gutter, required bool wide}) {
    final items = state.items;
    final footer = state.loadingMore || state.moreError != null || state.hasMore;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical && notification.metrics.extentAfter < 400) {
          _controller.loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: StaggerGroup(
          key: ValueKey(_generation),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 16 + MediaQuery.paddingOf(context).bottom),
            itemCount: items.length + (footer ? 1 : 0),
            separatorBuilder: (context, _) => SizedBox(height: wide ? 8 : 12),
            itemBuilder: (context, i) {
              if (i == items.length) {
                return state.moreError != null
                    ? AdminErrorView(error: state.moreError!, onRetry: _controller.loadMore, compact: true)
                    : SkeletonLoading(loading: true, child: _SignupCard.placeholder(compact: wide));
              }
              final item = items[i];
              final Widget card;
              if (wide) {
                card = _SignupCard(
                  item: item,
                  compact: true,
                  selected: item.doctorId == _selected,
                  onTap: () => setState(() => _selected = item.doctorId),
                );
              } else {
                card = ContainerTransform<(DoctorRegistration, ReviewDecision)>(
                  tappable: false,
                  closedBuilder: (context, open) => _SignupCard(item: item, onTap: open),
                  openBuilder: (context, close) => SignupReviewPage(
                    doctorId: item.doctorId,
                    onReviewed: (registration, decision) => close(returnValue: (registration, decision)),
                  ),
                  onClosed: (result) {
                    if (result == null || !mounted) return;
                    _controller.reviewed(result.$1.doctorId);
                    showAdminSnack(this.context, reviewedMessage(AppLocalizations.of(this.context), result.$1, result.$2));
                  },
                );
              }
              return StaggeredEntrance(index: i, child: card);
            },
          ),
        ),
      ),
    );
  }
}

/// One doctor: who, what, where, when, a status other than active, and the
/// free trial. A ticket-like card on phones, a compact selectable row in the
/// wide list.
class _SignupCard extends StatelessWidget {
  const _SignupCard({required this.item, required this.onTap, this.compact = false, this.selected = false});

  static Widget placeholder({bool compact = false}) => _SignupCard(
        item: RegistrationSummary(
          doctorId: '',
          fullName: '-------------------',
          title: '--------',
          specialty: const SpecialtyRef(id: '', nameAr: '----------', nameEn: '----------'),
          governorate: '--------',
          city: '--------',
          status: '',
          submittedAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
        compact: compact,
        onTap: null,
      );

  final RegistrationSummary item;
  final VoidCallback? onTap;
  final bool compact;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final isNew = DateTime.now().toUtc().difference(item.submittedAt) < _newFor;
    final specialty = item.specialty.name(language);
    final place = [?item.governorate, ?item.city].join(l10n.adminListSeparator);
    final when = AppFormat.relative(context, item.submittedAt);
    final name = l10n.adminDoctorName(item.fullName);
    final what = item.title.isEmpty ? specialty : '${item.title} · $specialty';

    final content = Padding(
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InitialAvatar(name: item.fullName, size: compact ? 40 : 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: selected ? scheme.onPrimaryContainer : null,
                        ),
                      ),
                    ),
                    if (isNew) ...[const SizedBox(width: 8), const NewMark()],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  what,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (place.isNotEmpty) _Meta(icon: Icons.place_outlined, text: place, selected: selected),
                    _Meta(icon: Icons.schedule, text: when, selected: selected),
                    if (item.status != DoctorStatuses.active) DoctorStatusPill(status: item.status),
                    if (item.trial != null) TrialPill(trial: item.trial),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final trial = item.trial;
    final semantics = [
      name,
      what,
      if (place.isNotEmpty) place,
      l10n.adminSubmittedShort(when),
      if (isNew) l10n.adminNew,
      if (item.status != DoctorStatuses.active) doctorStatusLabel(l10n, item.status),
      if (trial != null) trial.ended ? l10n.adminTrialEnded : l10n.adminTrialDaysLeft(trial.daysLeft),
    ].join(l10n.adminListSeparator);
    if (compact) {
      return Pressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: semantics,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.enterCurve,
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
          ),
          child: content,
        ),
      );
    }
    return Pressable(
      onTap: onTap,
      semanticLabel: semantics,
      borderRadius: BorderRadius.circular(20),
      child: Card(margin: EdgeInsets.zero, child: content),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.selected});

  final IconData icon;
  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

class _SignupListSkeleton extends StatelessWidget {
  const _SignupListSkeleton({required this.gutter, required this.compact});

  final double gutter;
  final bool compact;

  @override
  Widget build(BuildContext context) => SkeletonLoading(
        loading: true,
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 16),
          itemCount: 6,
          separatorBuilder: (context, _) => SizedBox(height: compact ? 8 : 12),
          itemBuilder: (context, _) => _SignupCard.placeholder(compact: compact),
        ),
      );
}
