import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../clinic/domain/clinic_permissions.dart';
import '../../application/clinic_admin_controllers.dart';
import '../../clinic_admin_routes.dart';
import '../../domain/assistant_models.dart';
import '../widgets/clinic_admin_widgets.dart';
import 'assistant_editor.dart';
import 'assistant_text.dart';

/// D25: the clinic's assistants with their preset, status, branches and
/// last activity, and "Add assistant" with "2 of 5" (disabled at the limit
/// with «وصلت للحد الأقصى لعدد المساعدين»). Wide screens show D26 on the
/// right; phones open it as a page.
class AssistantsScreen extends ConsumerStatefulWidget {
  const AssistantsScreen({super.key});

  @override
  ConsumerState<AssistantsScreen> createState() => _AssistantsScreenState();
}

/// What the desktop pane shows.
sealed class _Pane {
  const _Pane();
}

class _NewPane extends _Pane {
  const _NewPane();
}

class _AssistantPane extends _Pane {
  const _AssistantPane(this.id);

  final String id;
}

class _AssistantsScreenState extends ConsumerState<AssistantsScreen> {
  _Pane? _pane;

  /// The pane's form has changes: switching asks first. Kept out of build
  /// state, since the form reports it while building.
  bool _paneDirty = false;

  /// A new form each time the pane opens, so its state starts clean.
  int _paneGeneration = 0;

  Future<void> _show(_Pane pane, {required bool wide}) async {
    if (!wide) {
      context.go(switch (pane) {
        _NewPane() => ClinicAdminRoutes.newAssistant,
        _AssistantPane(:final id) => ClinicAdminRoutes.assistant(id),
      });
      return;
    }
    if (_paneDirty && !await confirmDiscardChanges(context, 1)) return;
    if (!mounted) return;
    setState(() {
      _pane = pane;
      _paneDirty = false;
      _paneGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final assistants = ref.watch(assistantsProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kAdminWideLayout;
        if (!wide) return _list(context, assistants, wide: false);

        // Open the first assistant when nothing is chosen yet.
        final items = assistants.value?.items ?? const <Assistant>[];
        if (_pane == null && items.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _pane == null) setState(() => _pane = _AssistantPane(items.first.userId));
          });
        }
        final listWidth = (constraints.maxWidth * 0.38).clamp(340.0, 440.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: listWidth, child: _list(context, assistants, wide: true)),
            const VerticalDivider(width: 1),
            Expanded(child: _detail(context, items)),
          ],
        );
      },
    );
  }

  Widget _detail(BuildContext context, List<Assistant> items) {
    final l10n = AppLocalizations.of(context);
    final pane = _pane;
    final Widget child;
    switch (pane) {
      case null:
        child = EmptyState(key: const ValueKey('none'), title: l10n.assistantChoose);
      case _NewPane():
        child = AssistantEditor(
          key: ValueKey('new-$_paneGeneration'),
          onDirtyChanged: (dirty) => _paneDirty = dirty,
          onCreated: (assistant) => setState(() {
            _pane = _AssistantPane(assistant.userId);
            _paneDirty = false;
            _paneGeneration++;
          }),
        );
      case _AssistantPane(:final id):
        final assistant = items.where((a) => a.userId == id).firstOrNull;
        child = assistant == null
            ? EmptyState(key: const ValueKey('gone'), title: l10n.assistantChoose)
            : AssistantEditor(
                key: ValueKey('$id-$_paneGeneration'),
                assistant: assistant,
                onDirtyChanged: (dirty) => _paneDirty = dirty,
                onRemoved: () => setState(() {
                  _pane = null;
                  _paneDirty = false;
                }),
              );
    }
    return AnimatedSwitcher(
      duration: Motion.normal,
      reverseDuration: Motion.normalExit,
      switchInCurve: Motion.enterCurve,
      switchOutCurve: Motion.exitCurveReversed,
      child: child,
    );
  }

  Widget _list(BuildContext context, AsyncValue<AssistantList> assistants, {required bool wide}) {
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final gutter = wide ? 20.0 : adminGutter(width);
    final list = assistants.value;
    final canAdd = list?.canAdd ?? false;
    final selected = switch (_pane) {
      _AssistantPane(:final id) when wide => id,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 8),
          child: AdminHeader(
            title: l10n.navAssistants,
            subtitle: l10n.assistantsSubtitle,
            actions: [
              FilledButton.icon(
                onPressed: canAdd ? () => _show(const _NewPane(), wide: wide) : null,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(l10n.assistantAdd),
              ),
            ],
          ),
        ),
        if (list != null)
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CapacityMeter(count: list.count, limit: list.limit, label: l10n.assistantCountOf(list.count, list.limit)),
                if (!list.canAdd)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InfoBanner(icon: Icons.block, tone: PillTone.warning, message: l10n.assistantErrorLimitReached),
                  ),
              ],
            ),
          ),
        Expanded(
          child: AsyncStateSwitcher<AssistantList>(
            value: assistants,
            isEmpty: (list) => list.items.isEmpty,
            loading: (context) => SkeletonLoading(
              loading: true,
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: gutter),
                children: [for (var i = 0; i < 3; i++) ...[AssistantTile.placeholder(), const SizedBox(height: 10)]],
              ),
            ),
            empty: (context) => EmptyState(
              title: l10n.assistantsEmptyTitle,
              message: l10n.assistantsEmptyBody,
              actionLabel: canAdd ? l10n.assistantAdd : null,
              onAction: canAdd ? () => _show(const _NewPane(), wide: wide) : null,
            ),
            error: (context, error) => AdminErrorView(error: error, onRetry: () => ref.read(assistantsProvider.notifier).reload()),
            data: (context, list) => RefreshIndicator(
              onRefresh: () => ref.read(assistantsProvider.notifier).reload(),
              child: StaggerGroup(
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 24 + MediaQuery.paddingOf(context).bottom),
                  itemCount: list.items.length,
                  separatorBuilder: (context, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final assistant = list.items[i];
                    return StaggeredEntrance(
                      index: i,
                      child: AssistantTile(
                        assistant: assistant,
                        selected: assistant.userId == selected,
                        onTap: () => _show(_AssistantPane(assistant.userId), wide: wide),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One D25 row: name, mobile, preset, status, branches and last active.
class AssistantTile extends StatelessWidget {
  const AssistantTile({super.key, required this.assistant, this.onTap, this.selected = false});

  static Widget placeholder() => AssistantTile(
        assistant: Assistant(
          userId: '',
          fullName: '----------------',
          phone: '+201000000000',
          preset: AssistantPreset.reception,
          status: AssistantStatuses.active,
          allBranches: true,
          createdAt: DateTime.now(),
        ),
      );

  final Assistant assistant;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final branches = assistant.allBranches
        ? l10n.assistantAllBranches
        : assistant.branches.map((b) => b.name(language)).join(l10n.regListSeparator);
    final active = assistant.lastActiveAt == null
        ? l10n.assistantNeverActive
        : l10n.assistantLastActive(AppFormat.relative(context, assistant.lastActiveAt!));
    return Pressable(
      onTap: onTap,
      selected: selected,
      borderRadius: const BorderRadius.all(Radius.circular(20)),
      child: AnimatedContainer(
        duration: Motion.of(context).reduced ? Duration.zero : Motion.fast,
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? scheme.primary : Colors.transparent, width: 2),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InitialAvatar(name: assistant.fullName, muted: !assistant.isActive),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(assistant.fullName, style: theme.textTheme.titleMedium),
                  LtrText(AppFormat.phone(assistant.phone), style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      PresetPill(preset: assistant.preset),
                      AssistantStatusPill(status: assistant.status),
                      if (assistant.mustChangePassword) StatusPill(label: l10n.adminPasswordNotSet, tone: PillTone.warning),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _Fact(icon: Icons.store_mall_directory_outlined, text: branches),
                  _Fact(icon: Icons.schedule_outlined, text: active),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: ExcludeSemantics(child: Icon(icon, size: 16, color: muted))),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall?.copyWith(color: muted))),
        ],
      ),
    );
  }
}

/// D26 as a page (phones, and links such as the activity log's): add, or
/// one assistant by ID.
class AssistantEditorPage extends ConsumerWidget {
  const AssistantEditorPage({super.key, this.assistantId});

  /// Null to add one.
  final String? assistantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final id = assistantId;
    void back() {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        context.go(ClinicAdminRoutes.assistants);
      }
    }

    if (id == null) {
      return Scaffold(
        body: AssistantEditor(
          showBack: true,
          onCreated: (assistant) => context.go(ClinicAdminRoutes.assistant(assistant.userId)),
        ),
      );
    }
    // The list's copy when D25 is open, else a fresh read (a link).
    final fromList = ref.watch(assistantsProvider).value?.items.where((a) => a.userId == id).firstOrNull;
    final detail = fromList != null ? AsyncData<Assistant>(fromList) : ref.watch(assistantDetailProvider(id));
    return Scaffold(
      body: AsyncStateSwitcher<Assistant>(
        value: detail,
        loading: (context) => const SkeletonLoading(loading: true, child: Center(child: Text('----------------'))),
        error: (context, error) => Column(
          children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(padding: EdgeInsets.all(8), child: ClinicBackButton(fallback: ClinicAdminRoutes.assistants)),
            ),
            Expanded(child: AdminErrorView(error: error, onRetry: () => ref.invalidate(assistantDetailProvider(id)))),
          ],
        ),
        data: (context, assistant) => assistant.isRemoved
            ? Column(
                children: [
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(padding: EdgeInsets.all(8), child: ClinicBackButton(fallback: ClinicAdminRoutes.assistants)),
                  ),
                  Expanded(child: EmptyState(title: l10n.assistantRemovedTitle(assistant.fullName), message: l10n.assistantErrorRemoved)),
                ],
              )
            : AssistantEditor(assistant: assistant, showBack: true, onRemoved: back),
      ),
    );
  }
}
