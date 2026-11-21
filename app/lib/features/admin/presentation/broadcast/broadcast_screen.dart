import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data/paged_controller.dart';
import '../../../../core/format/app_format.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../admin_billing/data/admin_billing_repository.dart';
import '../../../admin_billing/domain/admin_billing_models.dart';
import '../../data/broadcast_repository.dart';
import '../widgets/admin_widgets.dart';

/// AD16 history: the broadcasts sent, newest first.
final broadcastHistoryProvider =
    NotifierProvider.autoDispose<BroadcastHistoryController, PagedState<BroadcastEntry>>(BroadcastHistoryController.new);

class BroadcastHistoryController extends PagedController<BroadcastEntry> {
  @override
  Future<Paged<BroadcastEntry>> fetch(int page, int pageSize) =>
      ref.read(broadcastRepositoryProvider).history(page: page, pageSize: pageSize);

  @override
  Object keyOf(BroadcastEntry item) => item.broadcastId;
}

/// AD16 Broadcast [C]: an in-app notification and a push to every doctor or
/// to chosen ones, in Arabic and English (spec 10.1). The form, a live
/// preview of the notification, and the broadcasts sent so far (from the
/// audit log). Desktop shows the form and the history side by side.
class BroadcastScreen extends ConsumerStatefulWidget {
  const BroadcastScreen({super.key});

  @override
  ConsumerState<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends ConsumerState<BroadcastScreen> {
  final _titleAr = TextEditingController();
  final _bodyAr = TextEditingController();
  final _titleEn = TextEditingController();
  final _bodyEn = TextEditingController();
  BroadcastAudience _audience = BroadcastAudience.all;

  /// Chosen doctors: id → name.
  Map<String, String> _doctors = const {};
  Map<String, String> _errors = const {};
  SubmitStatus _status = SubmitStatus.idle;

  @override
  void initState() {
    super.initState();
    for (final (controller, key) in [
      (_titleAr, 'titleAr'),
      (_bodyAr, 'bodyAr'),
      (_titleEn, 'titleEn'),
      (_bodyEn, 'bodyEn'),
    ]) {
      controller.addListener(() {
        // The preview follows the text; an edit clears that field's error.
        if (!mounted) return;
        setState(() {
          if (_errors.containsKey(key)) _errors = {..._errors}..remove(key);
        });
      });
    }
  }

  @override
  void dispose() {
    for (final controller in [_titleAr, _bodyAr, _titleEn, _bodyEn]) {
      controller.dispose();
    }
    super.dispose();
  }

  BroadcastDraft get _draft => BroadcastDraft(
        audience: _audience,
        doctorIds: _doctors.keys.toList(),
        titleAr: _titleAr.text,
        bodyAr: _bodyAr.text,
        titleEn: _titleEn.text,
        bodyEn: _bodyEn.text,
      );

  Future<void> _chooseDoctors() async {
    final chosen = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _DoctorPicker(selected: _doctors),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _doctors = chosen;
      if (chosen.isNotEmpty) _errors = {..._errors}..remove('doctorIds');
    });
  }

  Future<void> _send() async {
    if (_status != SubmitStatus.idle) return;
    final l10n = AppLocalizations.of(context);
    final draft = _draft;
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    final confirmed = await confirmAction(
      context,
      title: l10n.broadcastConfirmTitle,
      message: draft.audience == BroadcastAudience.all
          ? l10n.broadcastConfirmAll
          : l10n.broadcastConfirmSelected(draft.doctorIds.length),
      confirmLabel: l10n.broadcastSend,
    );
    if (!confirmed || !mounted) return;
    setState(() => _status = SubmitStatus.loading);
    try {
      final sent = await ref.read(broadcastRepositoryProvider).send(draft);
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      showAdminSnack(context, l10n.broadcastSent(sent.recipients));
      unawaited(ref.read(broadcastHistoryProvider.notifier).refresh());
      if (!Motion.of(context).reduced) await Future<void>.delayed(Motion.slow);
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        for (final controller in [_titleAr, _bodyAr, _titleEn, _bodyEn]) {
          controller.clear();
        }
        _doctors = const {};
        _audience = BroadcastAudience.all;
        _errors = const {};
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        if (error.fieldCodes.isNotEmpty) _errors = error.fieldCodes;
      });
      if (error.fieldCodes.isEmpty) {
        showAdminSnack(
          context,
          error.code == 'BROADCAST_NO_RECIPIENTS' ? l10n.broadcastErrorNoRecipients : l10n.apiError(error),
          error: true,
        );
      }
    }
  }

  String? _errorText(AppLocalizations l10n, String key) {
    final code = _errors[key];
    if (code == null) return null;
    if (code == 'TOO_LONG') return l10n.fieldError(code) ?? l10n.errorUnknown;
    final empty = _titleAr.text.trim().isEmpty &&
        _bodyAr.text.trim().isEmpty &&
        _titleEn.text.trim().isEmpty &&
        _bodyEn.text.trim().isEmpty;
    return switch (key) {
      'doctorIds' => l10n.broadcastErrorNoDoctors,
      _ when empty => l10n.broadcastErrorEmpty,
      'titleAr' || 'titleEn' => l10n.broadcastErrorTitle,
      _ => l10n.broadcastErrorBody,
    };
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kAdminWideLayout;
        final gutter = adminGutter(constraints.maxWidth);
        final bottom = 24 + MediaQuery.paddingOf(context).bottom;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(gutter, 20, gutter, bottom),
                  child: Center(
                    child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: _compose(context)),
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              SizedBox(width: (constraints.maxWidth * 0.34).clamp(320.0, 420.0), child: const _History(gutter: 20)),
            ],
          );
        }
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 8),
              sliver: SliverToBoxAdapter(child: _compose(context)),
            ),
            _HistorySliver(gutter: gutter, bottom: bottom),
          ],
        );
      },
    );
  }

  Widget _compose(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final busy = _status != SubmitStatus.idle;
    Widget field(TextEditingController controller, String key, String label, {required bool arabic, bool body = false}) =>
        TextField(
          controller: controller,
          enabled: !busy,
          textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
          maxLength: body ? BroadcastDraft.maxBody : BroadcastDraft.maxTitle,
          minLines: body ? 3 : 1,
          maxLines: body ? 6 : 1,
          textInputAction: body ? TextInputAction.newline : TextInputAction.next,
          decoration: InputDecoration(labelText: label, alignLabelWithHint: body, errorText: _errorText(l10n, key), errorMaxLines: 2),
        );

    final draft = _draft;
    String pick(String preferred, String other) => preferred.trim().isNotEmpty ? preferred.trim() : other.trim();
    final previewTitle = language == 'ar' ? pick(draft.titleAr, draft.titleEn) : pick(draft.titleEn, draft.titleAr);
    final previewBody = language == 'ar' ? pick(draft.bodyAr, draft.bodyEn) : pick(draft.bodyEn, draft.bodyAr);

    return StaggerGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredEntrance(index: 0, child: AdminHeader(title: l10n.navBroadcast, subtitle: l10n.broadcastSubtitle)),
          const SizedBox(height: 16),
          StaggeredEntrance(
            index: 1,
            child: SectionCard(
              icon: Icons.groups_outlined,
              title: l10n.broadcastAudienceTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<BroadcastAudience>(
                    segments: [
                      ButtonSegment(
                        value: BroadcastAudience.all,
                        icon: const Icon(Icons.public),
                        label: Text(l10n.broadcastAudienceAll),
                      ),
                      ButtonSegment(
                        value: BroadcastAudience.selected,
                        icon: const Icon(Icons.checklist),
                        label: Text(l10n.broadcastAudienceSelected),
                      ),
                    ],
                    selected: {_audience},
                    onSelectionChanged: busy ? null : (value) => setState(() => _audience = value.first),
                  ),
                  const SizedBox(height: 12),
                  AdminAnimatedSize(
                    child: _audience == BroadcastAudience.all
                        ? Text(
                            l10n.broadcastAudienceAllHint,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          )
                        : _ChosenDoctors(
                            doctors: _doctors,
                            error: _errorText(l10n, 'doctorIds'),
                            enabled: !busy,
                            onChoose: _chooseDoctors,
                            onRemove: (id) => setState(() => _doctors = {..._doctors}..remove(id)),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          StaggeredEntrance(
            index: 2,
            child: SectionCard(
              icon: Icons.edit_note_outlined,
              title: l10n.broadcastMessageTitle,
              subtitle: l10n.broadcastMessageHint,
              child: ResponsiveGrid(
                minColumnWidth: 300,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      field(_titleAr, 'titleAr', l10n.broadcastTitleAr, arabic: true),
                      field(_bodyAr, 'bodyAr', l10n.broadcastBodyAr, arabic: true, body: true),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      field(_titleEn, 'titleEn', l10n.broadcastTitleEn, arabic: false),
                      field(_bodyEn, 'bodyEn', l10n.broadcastBodyEn, arabic: false, body: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          StaggeredEntrance(
            index: 3,
            child: SectionCard(
              icon: Icons.visibility_outlined,
              title: l10n.broadcastPreview,
              child: _NotificationPreview(title: previewTitle, body: previewBody),
            ),
          ),
          const SizedBox(height: 20),
          StaggeredEntrance(
            index: 4,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200),
                child: SubmitButton(label: l10n.broadcastSend, status: _status, onPressed: _send),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The chosen doctors as chips, and the button that opens the picker.
class _ChosenDoctors extends StatelessWidget {
  const _ChosenDoctors({
    required this.doctors,
    required this.enabled,
    required this.onChoose,
    required this.onRemove,
    this.error,
  });

  final Map<String, String> doctors;
  final bool enabled;
  final VoidCallback onChoose;
  final ValueChanged<String> onRemove;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final MapEntry(:key, :value) in doctors.entries)
              InputChip(
                avatar: InitialAvatar(name: value, size: 24),
                label: Text(value),
                onDeleted: enabled ? () => onRemove(key) : null,
                deleteButtonTooltipMessage: l10n.adminClearFilter,
              ),
            OutlinedButton.icon(
              onPressed: enabled ? onChoose : null,
              icon: const Icon(Icons.person_search_outlined),
              label: Text(doctors.isEmpty ? l10n.broadcastChooseDoctors : l10n.broadcastChosenCount(doctors.length)),
            ),
          ],
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ),
          ),
      ],
    );
  }
}

/// How the notification looks on a doctor's phone, in the app's language
/// (each doctor gets theirs, or the other one when it is empty).
class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = title.isEmpty && body.isEmpty;
    return Semantics(
      container: true,
      label: l10n.broadcastPreview,
      child: AnimatedContainer(
        duration: Motion.normal,
        curve: Motion.standardCurve,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.campaign_outlined, size: 20, color: scheme.onPrimary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.fast,
                reverseDuration: Motion.fastExit,
                child: empty
                    ? Text(
                        l10n.broadcastPreviewEmpty,
                        key: const ValueKey('empty'),
                        style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                      )
                    : Column(
                        key: const ValueKey('message'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.appTitle,
                                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ),
                              Text(
                                l10n.broadcastPreviewNow,
                                style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          if (title.isNotEmpty) Text(title, style: theme.textTheme.titleSmall),
                          if (body.isNotEmpty)
                            Text(body, maxLines: 4, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The broadcasts sent, beside the form on desktop.
class _History extends ConsumerWidget {
  const _History({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(broadcastHistoryProvider);
    final controller = ref.read(broadcastHistoryProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 12),
          child: Semantics(
            header: true,
            child: Text(l10n.broadcastHistoryTitle, style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        Expanded(
          child: StateSwitcher(
            state: state.view,
            loading: (context) => _HistorySkeleton(gutter: gutter),
            empty: (context) => EmptyState(
              title: l10n.broadcastHistoryEmpty,
              message: l10n.broadcastHistoryEmptyBody,
            ),
            error: (context) => AdminErrorView(error: state.error!, onRetry: controller.reload),
            content: (context) => NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 300) controller.loadMore();
                return false;
              },
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24),
                itemCount: state.items.length,
                separatorBuilder: (context, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => StaggeredEntrance(index: i, child: _HistoryCard(entry: state.items[i])),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The same history under the form on phones and tablets.
class _HistorySliver extends ConsumerWidget {
  const _HistorySliver({required this.gutter, required this.bottom});

  final double gutter;
  final double bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(broadcastHistoryProvider);
    final controller = ref.read(broadcastHistoryProvider.notifier);
    final title = Padding(
      padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
      child: Semantics(
        header: true,
        child: Text(l10n.broadcastHistoryTitle, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
    return SliverPadding(
      padding: EdgeInsets.only(bottom: bottom),
      sliver: SliverList.list(
        children: [
          title,
          StateSwitcher(
            state: state.view,
            loading: (context) => SizedBox(height: 260, child: _HistorySkeleton(gutter: gutter)),
            empty: (context) => EmptyState(
              title: l10n.broadcastHistoryEmpty,
              message: l10n.broadcastHistoryEmptyBody,
            ),
            error: (context) => AdminErrorView(error: state.error!, onRetry: controller.reload, compact: true),
            content: (context) => Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, entry) in state.items.indexed) ...[
                    if (i > 0) const SizedBox(height: 10),
                    StaggeredEntrance(index: i, child: _HistoryCard(entry: entry)),
                  ],
                  if (state.hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: state.loadingMore ? null : controller.loadMore,
                        child: Text(l10n.broadcastHistoryMore),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});

  final BroadcastEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final audience = entry.audience == BroadcastAudience.all ? l10n.broadcastAudienceAll : l10n.broadcastAudienceSelected;
    final meta = [
      AppFormat.relative(context, entry.sentAt),
      audience,
      l10n.broadcastRecipients(entry.recipients),
      if (entry.sentByName != null) l10n.broadcastSentBy(entry.sentByName!),
    ].join(l10n.adminListSeparator);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    entry.audience == BroadcastAudience.all ? Icons.public : Icons.checklist,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.title(language), style: theme.textTheme.titleSmall)),
                ],
              ),
              const SizedBox(height: 6),
              Text(entry.body(language), maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text(meta, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) => SkeletonLoading(
        loading: true,
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
          itemCount: 3,
          separatorBuilder: (context, _) => const SizedBox(height: 10),
          itemBuilder: (context, _) => _HistoryCard(
            entry: BroadcastEntry(
              broadcastId: '',
              sentAt: DateTime.now().toUtc(),
              audience: BroadcastAudience.all,
              recipients: 0,
              titleAr: '----------------',
              bodyAr: '------------------------------------',
              titleEn: '----------------',
              bodyEn: '------------------------------------',
            ),
          ),
        ),
      );
}

/// Picks doctors who can receive a broadcast (clinic active or suspended),
/// with search. Returns the choice (id → name), or null when cancelled.
class _DoctorPicker extends ConsumerStatefulWidget {
  const _DoctorPicker({required this.selected});

  final Map<String, String> selected;

  @override
  ConsumerState<_DoctorPicker> createState() => _DoctorPickerState();
}

class _DoctorPickerState extends ConsumerState<_DoctorPicker> {
  final _search = TextEditingController();
  late Map<String, String> _chosen = {...widget.selected};
  Timer? _debounce;
  Future<List<DoctorListItem>>? _results;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _results = ref
          .read(adminBillingRepositoryProvider)
          .doctors(DoctorFilter(search: _search.text.trim()), pageSize: 50)
          .then((page) => [for (final d in page.items) if (d.status == 'active' || d.status == 'suspended') d]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Semantics(header: true, child: Text(l10n.broadcastChooseDoctors, style: theme.textTheme.titleLarge)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), _load);
                },
                decoration: InputDecoration(hintText: l10n.broadcastPickerSearch, prefixIcon: const Icon(Icons.search)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<DoctorListItem>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return AdminErrorView(error: snapshot.error!, onRetry: _load, compact: true);
                  }
                  final doctors = snapshot.data;
                  if (doctors == null) return const Center(child: CircularProgressIndicator());
                  if (doctors.isEmpty) {
                    return Center(child: Text(l10n.broadcastPickerEmpty, style: theme.textTheme.bodyLarge));
                  }
                  return ListView.builder(
                    itemCount: doctors.length,
                    itemBuilder: (context, i) {
                      final doctor = doctors[i];
                      final name = doctor.name(language);
                      return CheckboxListTile(
                        value: _chosen.containsKey(doctor.doctorId),
                        onChanged: (value) => setState(() {
                          _chosen = {..._chosen};
                          value == true ? _chosen[doctor.doctorId] = name : _chosen.remove(doctor.doctorId);
                        }),
                        secondary: InitialAvatar(name: name, size: 36),
                        title: Text(name),
                        subtitle: Text(
                          [doctor.specialty(language), ?doctor.governorate].join(l10n.adminListSeparator),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.adminCancel)),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_chosen),
                    child: Text(l10n.broadcastPickerDone(_chosen.length)),
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
