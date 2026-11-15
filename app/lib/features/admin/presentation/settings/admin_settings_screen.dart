import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../../core/format/app_format.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/save_bar.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../admin_routes.dart';
import '../../application/admin_controllers.dart';
import '../../domain/admin_models.dart';
import '../../domain/setting_fields.dart';
import '../widgets/admin_widgets.dart';
import 'setting_history.dart';
import 'setting_labels.dart';

/// AD13: every platform setting in sections, edited in place. Only changed
/// fields are sent (`updateSettings` is a partial update), with the same
/// checks as the API before sending and the API's own errors next to each
/// field. A bar at the bottom counts unsaved changes; leaving with changes
/// asks first. Each field has its change history.
class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _text = {for (final field in SettingFields.all) field.name: TextEditingController()};
  final _fieldKeys = {for (final field in SettingFields.all) field.name: GlobalKey()};
  final _groupKeys = {for (final group in SettingGroup.values) group: GlobalKey()};
  late final Listenable _edits = Listenable.merge(_text.values.toList());

  /// The values the fields started from (the last load or save).
  PlatformSettings? _saved;
  Map<String, String> _serverErrors = const {};
  SubmitStatus _status = SubmitStatus.idle;
  String? _saveError;
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<PlatformSettings>>(adminSettingsProvider, (previous, next) {
      final value = next.value;
      if (value == null || _saved != null) return;
      if (mounted) {
        setState(() => _fill(value));
      }
    });
    final current = ref.read(adminSettingsProvider).value;
    if (current != null) _fill(current);
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _fill(PlatformSettings settings) {
    _saved = settings;
    _serverErrors = const {};
    _saveError = null;
    for (final field in SettingFields.all) {
      _text[field.name]!.text = field.display(settings[field.name]);
    }
  }

  String _savedText(SettingFieldSpec field) => field.display(_saved?[field.name]);

  bool _isDirty(SettingFieldSpec field) => _text[field.name]!.text.trim() != _savedText(field).trim();

  List<SettingFieldSpec> get _dirty => [
        for (final field in SettingFields.all)
          if (_isDirty(field)) field,
      ];

  void _discard() {
    setState(() {
      for (final field in _dirty) {
        _text[field.name]!.text = _savedText(field);
      }
      _serverErrors = const {};
      _saveError = null;
    });
    _formKey.currentState?.validate();
  }

  Future<bool> _confirmDiscard() async {
    final count = _dirty.length;
    if (count == 0) return true;
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.adminDiscardTitle,
      message: l10n.adminDiscardBody(count),
      confirmLabel: l10n.adminDiscard,
      destructive: true,
    );
    if (confirmed) _discard();
    return confirmed;
  }

  Future<void> _reload() async {
    if (!await _confirmDiscard()) return;
    setState(() => _saved = null);
    await ref.read(adminSettingsProvider.notifier).reload();
  }

  void _scrollTo(GlobalKey key) {
    final target = key.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      alignment: 0.1,
      duration: Motion.of(context).reduced ? Duration.zero : Motion.slow,
      curve: Motion.standardCurve,
    );
  }

  void _scrollToFirstError() {
    for (final field in SettingFields.all) {
      if (_serverErrors.containsKey(field.name) || _isDirty(field) && field.check(_text[field.name]!.text) != null) {
        _scrollTo(_fieldKeys[field.name]!);
        return;
      }
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final reduced = Motion.of(context).reduced;
    setState(() {
      _serverErrors = const {};
      _saveError = null;
    });
    final dirty = _dirty;
    if (dirty.isEmpty) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() {
        _failures++;
        _saveError = l10n.adminFixErrors;
      });
      _scrollToFirstError();
      return;
    }
    final changes = {for (final field in dirty) field.name: field.wire(_text[field.name]!.text)};
    setState(() => _status = SubmitStatus.loading);
    try {
      final result = await ref.read(adminSettingsProvider.notifier).save(changes);
      if (!mounted) return;
      setState(() {
        _fill(result);
        _status = SubmitStatus.success;
      });
      showAdminSnack(context, l10n.adminSettingsSaved(changes.length));
      await Future<void>.delayed(reduced ? Duration.zero : Motion.slow);
      if (mounted) setState(() => _status = SubmitStatus.idle);
    } on ApiException catch (error) {
      if (!mounted) return;
      final fieldErrors = {
        for (final MapEntry(:key, :value) in error.fieldCodes.entries)
          if (SettingFields.byName.containsKey(key)) key: value,
      };
      setState(() {
        _status = SubmitStatus.idle;
        _serverErrors = fieldErrors;
        _saveError = fieldErrors.isEmpty ? l10n.apiError(error) : l10n.adminFixErrors;
        _failures++;
      });
      _formKey.currentState?.validate();
      _scrollToFirstError();
    }
  }

  String? _validate(SettingFieldSpec field, String? value) {
    final l10n = AppLocalizations.of(context);
    final server = _serverErrors[field.name];
    if (server != null) {
      if (server == 'INVALID_PHONE') return l10n.settingProblem(field, SettingProblem.invalidPhone);
      return l10n.fieldError(server) ?? l10n.adminErrorInvalidValue;
    }
    // Only what the admin changed is checked: stored values came from the API.
    if (!_isDirty(field)) return null;
    final problem = field.check(value ?? '');
    return problem == null ? null : l10n.settingProblem(field, problem);
  }

  void _clearServerError(String name) {
    if (_serverErrors.containsKey(name)) setState(() => _serverErrors = {..._serverErrors}..remove(name));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(adminSettingsProvider);
    final ViewState view;
    if (_saved != null) {
      view = ViewState.content;
    } else if (settings.hasError && !settings.isLoading) {
      view = ViewState.error;
    } else {
      view = ViewState.loading;
    }
    return ListenableBuilder(
      listenable: _edits,
      builder: (context, _) {
        final dirty = _saved == null ? 0 : _dirty.length;
        return PopScope(
          canPop: dirty == 0,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            if (await _confirmDiscard() && mounted) navigator.maybePop();
          },
          child: StateSwitcher(
            state: view,
            loading: (context) => const _SettingsSkeleton(),
            error: (context) => AdminErrorView(
              error: settings.error ?? l10n.errorUnknown,
              onRetry: () => ref.read(adminSettingsProvider.notifier).reload(),
            ),
            content: (context) => _content(context, dirty),
          ),
        );
      },
    );
  }

  Widget _content(BuildContext context, int dirty) {
    final l10n = AppLocalizations.of(context);
    final saved = _saved!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gutter = adminGutter(width);
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final showBar = dirty > 0 || _status != SubmitStatus.idle;
        final sections = {for (final group in SettingGroup.values) group: _section(context, group)};
        final twoColumns = width >= 1180;
        var index = 0;
        Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);
        const gap = SizedBox(height: 16);

        final List<Widget> body;
        if (twoColumns) {
          Widget column(List<SettingGroup> groups) =>
              Column(children: [for (final group in groups) ...[enter(sections[group]!), gap]]);
          body = [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: column(const [SettingGroup.billing, SettingGroup.clinics, SettingGroup.files, SettingGroup.support]),
                ),
                const SizedBox(width: 16),
                Expanded(child: column(const [SettingGroup.payment, SettingGroup.appVersions, SettingGroup.maintenance])),
              ],
            ),
            enter(sections[SettingGroup.legal]!),
          ];
        } else {
          body = [for (final group in SettingGroup.values) ...[enter(sections[group]!), gap]];
        }

        return Column(
          children: [
            Expanded(
              child: Form(
                key: _formKey,
                child: StaggerGroup(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 24 + (showBar ? 0 : bottomInset)),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            enter(AdminHeader(
                              title: l10n.navSettings,
                              subtitle: saved.updatedAt == null
                                  ? null
                                  : l10n.adminSettingsLastChange(
                                      saved.updatedByName ?? l10n.adminSystem,
                                      AppFormat.relative(context, saved.updatedAt!),
                                    ),
                              actions: [
                                OutlinedButton.icon(
                                  onPressed: () => showSettingHistory(context),
                                  icon: const Icon(Icons.history),
                                  label: Text(l10n.adminHistoryTitle),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => context.go(AdminRoutes.profile),
                                  icon: const Icon(Icons.account_circle_outlined),
                                  label: Text(l10n.adminMyProfile),
                                ),
                                IconButton(
                                  tooltip: l10n.adminRefresh,
                                  onPressed: _status == SubmitStatus.idle ? _reload : null,
                                  icon: const Icon(Icons.refresh),
                                ),
                              ],
                            )),
                            const SizedBox(height: 16),
                            // Jump to a section: all of them on wide screens, a scrolling row on phones.
                            enter(Builder(builder: (context) {
                              final chips = [
                                for (final group in SettingGroup.values)
                                  ActionChip(
                                    avatar: Icon(settingGroupIcon(group), size: 18),
                                    label: Text(l10n.settingGroupTitle(group)),
                                    onPressed: () => _scrollTo(_groupKeys[group]!),
                                  ),
                              ];
                              if (width >= kAdminWideLayout) return Wrap(spacing: 8, runSpacing: 8, children: chips);
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: [
                                  for (final chip in chips)
                                    Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: chip),
                                ]),
                              );
                            })),
                            const SizedBox(height: 16),
                            ...body,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SaveBar(
              visible: showBar,
              dirty: dirty,
              status: _status,
              error: _saveError,
              failures: _failures,
              gutter: gutter,
              bottomInset: bottomInset,
              onDiscard: _confirmDiscard,
              onSave: _save,
            ),
          ],
        );
      },
    );
  }

  Widget _section(BuildContext context, SettingGroup group) {
    final l10n = AppLocalizations.of(context);
    final fields = SettingFields.inGroup(group);
    final Widget child;
    switch (group) {
      case SettingGroup.maintenance:
        child = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MaintenanceSwitch(
              controller: _text['maintenanceEnabled']!,
              saved: _saved?['maintenanceEnabled'] == true,
              onHistory: () => showSettingHistory(context, field: 'maintenanceEnabled'),
            ),
            const SizedBox(height: 16),
            ResponsiveGrid(minColumnWidth: 300, children: [
              for (final field in fields.where((f) => f.kind != SettingKind.boolean)) _input(context, field),
            ]),
          ],
        );
      case SettingGroup.legal:
        child = ResponsiveGrid(minColumnWidth: 360, children: [for (final field in fields) _input(context, field)]);
      case SettingGroup.support:
        child = ResponsiveGrid(columns: 3, minColumnWidth: 220, children: [for (final field in fields) _input(context, field)]);
      case SettingGroup.payment:
        child = ResponsiveGrid(minColumnWidth: 280, children: [for (final field in fields) _input(context, field)]);
      case _:
        child = ResponsiveGrid(minColumnWidth: 220, children: [for (final field in fields) _input(context, field)]);
    }
    return KeyedSubtree(
      key: _groupKeys[group],
      child: SectionCard(
        icon: settingGroupIcon(group),
        title: l10n.settingGroupTitle(group),
        subtitle: l10n.settingGroupDescription(group),
        child: child,
      ),
    );
  }

  Widget _input(BuildContext context, SettingFieldSpec field) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final controller = _text[field.name]!;
    final busy = _status != SubmitStatus.idle;
    final dirty = _isDirty(field);
    final legal = field.group == SettingGroup.legal;
    final ltr = settingIsLtr(field);
    final hint = l10n.settingHint(field);
    final saved = _saved?[field.name];
    final was = l10n.adminWasValue(settingValueText(
      context,
      field.name,
      field.kind == SettingKind.money ? (saved as int?)?.toString() : saved?.toString(),
    ));
    return TextFormField(
      key: _fieldKeys[field.name],
      controller: controller,
      enabled: !busy,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      // Numbers follow the page (aligned with the label, unit at the end);
      // emails, phones and English texts read left to right.
      textDirection: field.isNumber
          ? null
          : ltr
              ? TextDirection.ltr
              : (field.rtl == true ? TextDirection.rtl : null),
      keyboardType: switch (field.kind) {
        SettingKind.money => const TextInputType.numberWithOptions(decimal: true),
        SettingKind.integer => TextInputType.number,
        SettingKind.version => const TextInputType.numberWithOptions(decimal: true),
        SettingKind.email => TextInputType.emailAddress,
        SettingKind.phone || SettingKind.whatsapp => TextInputType.phone,
        _ => field.multiline ? TextInputType.multiline : TextInputType.text,
      },
      inputFormatters: field.kind == SettingKind.integer
          ? [FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹]'))]
          : null,
      minLines: field.multiline ? (legal ? 8 : 3) : null,
      maxLines: field.multiline ? (legal ? 14 : 6) : 1,
      maxLength: field.multiline ? field.maxLength : null,
      buildCounter: field.multiline
          ? (context, {required currentLength, required isFocused, maxLength}) => Text(
                l10n.adminCharacterCount(
                  NumberFormat('#,##0', 'en').format(currentLength),
                  NumberFormat('#,##0', 'en').format(maxLength ?? 0),
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              )
          : null,
      onChanged: (_) => _clearServerError(field.name),
      decoration: InputDecoration(
        labelText: l10n.settingLabel(field.name),
        alignLabelWithHint: field.multiline,
        helperText: dirty ? was : hint,
        helperMaxLines: 2,
        helperStyle: dirty ? TextStyle(color: scheme.primary, fontWeight: FontWeight.w600) : null,
        errorMaxLines: 2,
        suffixText: l10n.settingUnit(field),
        suffixIcon: IconButton(
          tooltip: l10n.adminFieldHistory(l10n.settingLabel(field.name)),
          icon: const Icon(Icons.history, size: 20),
          onPressed: () => showSettingHistory(context, field: field.name),
        ),
      ),
      validator: (value) => _validate(field, value),
    );
  }
}

class _MaintenanceSwitch extends StatelessWidget {
  const _MaintenanceSwitch({required this.controller, required this.saved, required this.onHistory});

  final TextEditingController controller;
  final bool saved;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = controller.text == 'true';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: on ? scheme.tertiaryContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  value: on,
                  onChanged: (value) => controller.text = '$value',
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(
                    l10n.adminSettingMaintenance,
                    style: theme.textTheme.titleSmall?.copyWith(color: on ? scheme.onTertiaryContainer : null),
                  ),
                  subtitle: Text(
                    on ? l10n.adminMaintenanceOn : l10n.adminMaintenanceOff,
                    style: TextStyle(color: on ? scheme.onTertiaryContainer : scheme.onSurfaceVariant),
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.adminFieldHistory(l10n.adminSettingMaintenance),
                icon: const Icon(Icons.history, size: 20),
                color: on ? scheme.onTertiaryContainer : null,
                onPressed: onHistory,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        if (on != saved)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                on ? l10n.adminMaintenanceWillStart : l10n.adminMaintenanceWillEnd,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget card() => const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('------------------'),
                SizedBox(height: 16),
                TextField(decoration: InputDecoration(labelText: '----------')),
                SizedBox(height: 16),
                TextField(decoration: InputDecoration(labelText: '----------')),
              ],
            ),
          ),
        );
    return SkeletonLoading(
      loading: true,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text('---------------'),
          const SizedBox(height: 16),
          card(),
          const SizedBox(height: 16),
          card(),
        ],
      ),
    );
  }
}
