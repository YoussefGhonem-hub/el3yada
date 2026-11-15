import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/save_bar.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../core/widgets/temporary_password_dialog.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../clinic/domain/clinic_permissions.dart';
import '../../../doctor_registration/domain/registration_rules.dart';
import '../../application/clinic_admin_controllers.dart';
import '../../clinic_admin_routes.dart';
import '../../data/clinic_admin_repository.dart';
import '../../domain/assistant_models.dart';
import '../../domain/branch_models.dart';
import '../widgets/clinic_admin_widgets.dart';
import 'assistant_text.dart';

/// The D26 form state: details, branches and permissions, and the preset
/// the doctor picked. Picking a preset fills the checklist; changing any
/// box makes it Custom (spec 6.10). Dependencies apply both ways
/// ([ClinicPermission.toggle]).
class AssistantForm extends ChangeNotifier {
  AssistantForm([Assistant? assistant]) {
    if (assistant != null) {
      fill(assistant);
    } else {
      preset = AssistantPreset.reception;
      permissions = {...AssistantPreset.permissions[AssistantPreset.reception]!};
    }
  }

  final fullName = TextEditingController();
  final phone = TextEditingController();
  bool allBranches = false;
  Set<String> branchIds = {};
  Set<String> permissions = {};
  String preset = AssistantPreset.custom;
  Assistant? _saved;

  /// The last box's knock-on effect: the key that was changed, and what
  /// changed with it, for the note under it.
  (String, Set<String>, bool)? lastDependency;

  void fill(Assistant assistant) {
    _saved = assistant;
    fullName.text = assistant.fullName;
    phone.text = assistant.phone.startsWith('+20') ? '0${assistant.phone.substring(3)}' : assistant.phone;
    allBranches = assistant.allBranches;
    branchIds = {...assistant.branchIds};
    permissions = {...assistant.permissions};
    preset = assistant.preset;
    lastDependency = null;
    notifyListeners();
  }

  void pickPreset(String value) {
    preset = value;
    final keys = AssistantPreset.permissions[value];
    if (keys != null) permissions = {...keys};
    lastDependency = null;
    notifyListeners();
  }

  /// One box. Its dependencies follow, and the preset becomes Custom.
  void toggle(String key, bool on) {
    final next = ClinicPermission.toggle(permissions, key, on: on);
    final knockOn = on ? next.difference(permissions) : permissions.difference(next);
    knockOn.remove(key);
    permissions = next;
    preset = AssistantPreset.custom;
    lastDependency = knockOn.isEmpty ? null : (key, knockOn, on);
    notifyListeners();
  }

  void setAllBranches(bool value) {
    allBranches = value;
    notifyListeners();
  }

  void toggleBranch(String id, bool on) {
    branchIds = on ? {...branchIds, id} : ({...branchIds}..remove(id));
    notifyListeners();
  }

  String get _name => RegistrationRules.collapseSpaces(fullName.text);

  String? get _phoneE164 => Validators.normalizeEgyptianMobile(phone.text);

  bool get _nameChanged => _saved == null || _name != _saved!.fullName;
  bool get _phoneChanged => _saved == null || (_phoneE164 ?? phone.text.trim()) != _saved!.phone;
  bool get _branchesChanged =>
      _saved == null ||
      allBranches != _saved!.allBranches ||
      (!allBranches && (branchIds.length != _saved!.branchIds.length || !branchIds.containsAll(_saved!.branchIds)));
  bool get _permissionsChanged =>
      _saved == null || permissions.length != _saved!.permissions.length || !permissions.containsAll(_saved!.permissions);

  /// How many parts changed (name, mobile, branches, permissions).
  int get changes {
    if (_saved == null) return [fullName.text.trim().isNotEmpty, phone.text.trim().isNotEmpty].where((c) => c).length;
    return [_nameChanged, _phoneChanged, _branchesChanged, _permissionsChanged].where((c) => c).length;
  }

  /// Field → problem code (the API's codes), before anything is sent.
  Map<String, String> check() => {
        if (fullName.text.trim().isEmpty)
          'fullName': 'REQUIRED'
        else if (!RegistrationRules.isFullName(fullName.text))
          'fullName': 'INVALID_NAME',
        if (phone.text.trim().isEmpty) 'phone': 'REQUIRED' else if (_phoneE164 == null) 'phone': 'INVALID_MOBILE',
        if (!allBranches && branchIds.isEmpty) 'branchIds': 'REQUIRED',
      };

  AssistantDraft build() => AssistantDraft(
        fullName: _name,
        phone: phone.text.trim(),
        allBranches: allBranches,
        branchIds: branchIds,
        permissions: permissions,
      );

  @override
  void dispose() {
    fullName.dispose();
    phone.dispose();
    super.dispose();
  }
}

/// D26: add or edit an assistant. Used full screen (phones, links) and as
/// the desktop detail pane of D25. [onDirtyChanged] tells D25 whether
/// switching to another assistant needs a confirm.
class AssistantEditor extends ConsumerStatefulWidget {
  const AssistantEditor({
    super.key,
    this.assistant,
    this.onCreated,
    this.onRemoved,
    this.onDirtyChanged,
    this.showBack = false,
  });

  /// Null to add one.
  final Assistant? assistant;
  final ValueChanged<Assistant>? onCreated;
  final VoidCallback? onRemoved;
  final ValueChanged<bool>? onDirtyChanged;
  final bool showBack;

  @override
  ConsumerState<AssistantEditor> createState() => _AssistantEditorState();
}

class _AssistantEditorState extends ConsumerState<AssistantEditor> {
  late final _form = AssistantForm(widget.assistant);
  SubmitStatus _status = SubmitStatus.idle;
  Map<String, String> _server = const {};
  bool _showClient = false;
  String? _error;
  int _failures = 0;
  bool _busyAction = false;
  bool _wasDirty = false;

  bool get _isNew => widget.assistant == null;

  @override
  void initState() {
    super.initState();
    _form.addListener(_reportDirty);
    _form.fullName.addListener(_reportDirty);
    _form.phone.addListener(_reportDirty);
  }

  @override
  void didUpdateWidget(AssistantEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.assistant;
    if (next != null && !identical(next, oldWidget.assistant) && _form.changes == 0) _form.fill(next);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _reportDirty() {
    final dirty = _form.changes > 0;
    if (dirty != _wasDirty) {
      _wasDirty = dirty;
      widget.onDirtyChanged?.call(dirty);
    }
  }

  void _discard() {
    final saved = widget.assistant;
    if (saved != null) _form.fill(saved);
    setState(() {
      _server = const {};
      _showClient = false;
      _error = null;
    });
  }

  Future<void> _confirmDiscard() async {
    final count = _form.changes;
    if (count == 0 || await confirmDiscardChanges(context, count)) _discard();
  }

  String? _fieldError(String field) {
    final l10n = AppLocalizations.of(context);
    final code = _server[field] ?? (_showClient ? _form.check()[field] : null);
    if (code == null) return null;
    if (field == 'branchIds' && code == 'REQUIRED') return l10n.assistantErrorBranchRequired;
    return l10n.fieldError(code) ?? l10n.adminErrorInvalidValue;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final reduced = Motion.of(context).reduced;
    setState(() {
      _server = const {};
      _error = null;
      _showClient = true;
    });
    if (_form.check().isNotEmpty) {
      setState(() {
        _failures++;
        _error = l10n.adminFixErrors;
      });
      return;
    }
    final controller = ref.read(assistantsProvider.notifier);
    setState(() => _status = SubmitStatus.loading);
    try {
      if (_isNew) {
        final created = await controller.create(_form.build());
        if (!mounted) return;
        setState(() => _status = SubmitStatus.success);
        // BR-AS2: shown once, with WhatsApp / SMS / Copy.
        await showTemporaryPasswordDialog(
          context,
          name: created.assistant.fullName,
          phone: created.assistant.phone,
          password: created.temporaryPassword,
        );
        if (!mounted) return;
        _form.fill(created.assistant);
        setState(() => _status = SubmitStatus.idle);
        widget.onCreated?.call(created.assistant);
        return;
      }
      final saved = widget.assistant!;
      final draft = _form.build();
      final updated = await controller.save(
        saved.userId,
        fullName: _form._nameChanged ? draft.fullName : null,
        phone: _form._phoneChanged ? draft.phone : null,
        allBranches: _form._branchesChanged ? draft.allBranches : null,
        branchIds: _form._branchesChanged && !draft.allBranches ? draft.branchIds : null,
        permissions: _form._permissionsChanged ? draft.permissions : null,
      );
      if (!mounted) return;
      _form.fill(updated);
      setState(() => _status = SubmitStatus.success);
      showAdminSnack(context, l10n.assistantSaved(updated.fullName));
      await Future<void>.delayed(reduced ? Duration.zero : Motion.slow);
      if (mounted) setState(() => _status = SubmitStatus.idle);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _server = {
          ...error.fieldCodes,
          if (error.code == ClinicAdminCodes.assistantPhoneTaken) 'phone': ClinicAdminCodes.assistantPhoneTaken,
        };
        _failures++;
        _error = _server.isEmpty ? l10n.apiError(error) : l10n.adminFixErrors;
      });
    }
  }

  Future<void> _action(Future<void> Function() run) async {
    setState(() => _busyAction = true);
    try {
      await run();
    } on ApiException catch (error) {
      if (mounted) showAdminSnack(context, AppLocalizations.of(context).apiError(error), error: true);
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _resetPassword(Assistant assistant) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.assistantResetTitle(assistant.fullName),
      message: l10n.assistantResetBody,
      confirmLabel: l10n.assistantResetPassword,
    );
    if (!confirmed || !mounted) return;
    await _action(() async {
      final reset = await ref.read(assistantsProvider.notifier).resetPassword(assistant.userId);
      if (!mounted) return;
      await showTemporaryPasswordDialog(
        context,
        name: reset.assistant.fullName,
        phone: reset.assistant.phone,
        password: reset.temporaryPassword,
        title: l10n.assistantNewPasswordTitle,
      );
    });
  }

  Future<void> _setStatus(Assistant assistant, String status) async {
    final l10n = AppLocalizations.of(context);
    final name = assistant.fullName;
    final (title, body, label, destructive) = switch (status) {
      AssistantStatuses.disabled => (l10n.assistantDisableTitle(name), l10n.assistantDisableBody, l10n.adminDisable, true),
      AssistantStatuses.removed => (l10n.assistantRemoveTitle(name), l10n.assistantRemoveBody, l10n.assistantRemove, true),
      _ => (l10n.assistantEnableTitle(name), l10n.assistantEnableBody, l10n.adminEnable, false),
    };
    final confirmed = await confirmAction(context, title: title, message: body, confirmLabel: label, destructive: destructive);
    if (!confirmed || !mounted) return;
    await _action(() async {
      final updated = await ref.read(assistantsProvider.notifier).setStatus(assistant.userId, status);
      if (!mounted) return;
      showAdminSnack(
        context,
        switch (status) {
          AssistantStatuses.disabled => l10n.adminDisabledMessage(name),
          AssistantStatuses.removed => l10n.assistantRemovedMessage(name),
          _ => l10n.adminEnabledMessage(name),
        },
      );
      if (updated.isRemoved) {
        widget.onRemoved?.call();
      } else {
        _form.fill(updated);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_form, _form.fullName, _form.phone]),
      builder: (context, _) {
        final dirty = _form.changes;
        return PopScope(
          canPop: dirty == 0 || _status == SubmitStatus.success,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            if (await confirmDiscardChanges(context, dirty) && mounted) {
              _discard();
              navigator.pop();
            }
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gutter = adminGutter(constraints.maxWidth);
              final showBar = _isNew || dirty > 0 || _status != SubmitStatus.idle;
              return Column(
                children: [
                  Expanded(
                    child: ClinicPage(
                      maxWidth: 820,
                      bottomBarVisible: showBar,
                      builder: (context, width) => _sections(context, width),
                    ),
                  ),
                  SaveBar(
                    visible: showBar,
                    dirty: _isNew ? (dirty == 0 ? 1 : dirty) : dirty,
                    status: _status,
                    error: _error,
                    failures: _failures,
                    gutter: gutter,
                    bottomInset: MediaQuery.paddingOf(context).bottom,
                    saveLabel: _isNew ? l10nOf(context).assistantAdd : null,
                    onDiscard: _isNew ? () => Navigator.of(context).maybePop() : _confirmDiscard,
                    onSave: _save,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  static AppLocalizations l10nOf(BuildContext context) => AppLocalizations.of(context);

  List<Widget> _sections(BuildContext context, double width) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final assistant = widget.assistant;
    final busy = _status != SubmitStatus.idle;
    const gap = SizedBox(height: 16);

    final header = AdminHeader(
      leading: widget.showBack ? const ClinicBackButton(fallback: ClinicAdminRoutes.assistants) : null,
      title: assistant?.fullName ?? l10n.assistantAdd,
      subtitle: assistant == null
          ? l10n.assistantAddBody
          : (assistant.lastActiveAt == null
              ? l10n.assistantNeverActive
              : l10n.assistantLastActive(AppFormat.relative(context, assistant.lastActiveAt!))),
      actions: [
        if (assistant != null) AssistantStatusPill(status: assistant.status),
        if (assistant != null && assistant.mustChangePassword) StatusPill(label: l10n.adminPasswordNotSet, tone: PillTone.warning),
      ],
    );

    final details = SectionCard(
      icon: Icons.person_outline,
      title: l10n.assistantDetails,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('assistant.fullName'),
            controller: _form.fullName,
            enabled: !busy,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _server = {..._server}..remove('fullName')),
            decoration: InputDecoration(
              labelText: l10n.adminFieldFullName,
              helperText: l10n.regFullNameHint,
              prefixIcon: const Icon(Icons.badge_outlined),
              errorText: _fieldError('fullName'),
              errorMaxLines: 2,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('assistant.phone'),
            controller: _form.phone,
            enabled: !busy,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            onChanged: (_) => setState(() => _server = {..._server}..remove('phone')),
            decoration: InputDecoration(
              labelText: l10n.regMobileLabel,
              hintText: '01XXXXXXXXX',
              hintTextDirection: TextDirection.ltr,
              helperText: l10n.assistantPhoneHint,
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.phone_android_outlined),
              errorText: _fieldError('phone'),
              errorMaxLines: 2,
            ),
          ),
        ],
      ),
    );

    final branches = _BranchesCard(form: _form, enabled: !busy, error: _fieldError('branchIds'));
    final permissions = _PermissionsCard(form: _form, enabled: !busy);

    final actions = assistant == null
        ? null
        : SettingsGroup(
            title: l10n.assistantAccountActions,
            children: [
              SettingsTile(
                icon: Icons.key_outlined,
                title: l10n.assistantResetPassword,
                subtitle: l10n.assistantResetPasswordHint,
                onTap: _busyAction ? null : () => _resetPassword(assistant),
              ),
              if (assistant.isActive)
                SettingsTile(
                  icon: Icons.block,
                  title: l10n.adminDisable,
                  subtitle: l10n.assistantDisableHint,
                  onTap: _busyAction ? null : () => _setStatus(assistant, AssistantStatuses.disabled),
                )
              else
                SettingsTile(
                  icon: Icons.check_circle_outline,
                  title: l10n.adminEnable,
                  subtitle: l10n.assistantEnableHint,
                  onTap: _busyAction ? null : () => _setStatus(assistant, AssistantStatuses.active),
                ),
              SettingsTile(
                icon: Icons.person_remove_outlined,
                title: l10n.assistantRemove,
                subtitle: l10n.assistantRemoveHint,
                destructive: true,
                onTap: _busyAction ? null : () => _setStatus(assistant, AssistantStatuses.removed),
              ),
            ],
          );

    final limitNote = _isNew
        ? Builder(builder: (context) {
            final list = ref.watch(assistantsProvider).value;
            if (list == null || list.canAdd) return const SizedBox.shrink();
            return InfoBanner(icon: Icons.block, tone: PillTone.warning, message: l10n.assistantErrorLimitReached);
          })
        : null;

    return [
      header,
      if (limitNote != null) ...[gap, limitNote],
      gap,
      details,
      gap,
      branches,
      gap,
      permissions,
      if (actions != null) ...[const SizedBox(height: 24), actions],
      if (assistant != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 8, top: 12),
          child: Text(
            l10n.assistantAddedOn(AppFormat.date(context, assistant.createdAt)),
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
    ];
  }
}

/// "All branches", or one or more of the clinic's open branches (BR-AS13).
class _BranchesCard extends ConsumerWidget {
  const _BranchesCard({required this.form, required this.enabled, this.error});

  final AssistantForm form;
  final bool enabled;
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final branches = ref.watch(branchesProvider).value?.items.where((b) => !b.archived).toList() ?? const <BranchCard>[];
    return SectionCard(
      icon: Icons.store_mall_directory_outlined,
      title: l10n.assistantBranches,
      subtitle: l10n.assistantBranchesHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(l10n.assistantAllBranches), icon: const Icon(Icons.select_all)),
              ButtonSegment(value: false, label: Text(l10n.assistantSomeBranches), icon: const Icon(Icons.checklist)),
            ],
            selected: {form.allBranches},
            onSelectionChanged: enabled ? (s) => form.setAllBranches(s.first) : null,
          ),
          AnimatedSize(
            duration: Motion.of(context).reduced ? Duration.zero : Motion.normal,
            curve: Motion.standardCurve,
            alignment: AlignmentDirectional.topStart,
            child: form.allBranches
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(l10n.assistantAllBranchesBody, style: theme.textTheme.bodySmall),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final branch in branches)
                          CheckboxListTile(
                            key: ValueKey('assistant.branch.${branch.id}'),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: form.branchIds.contains(branch.id),
                            onChanged: enabled ? (on) => form.toggleBranch(branch.id, on ?? false) : null,
                            title: Text(branch.name(language)),
                            subtitle: Text(
                              [branch.city, branch.governorate].join(l10n.regListSeparator),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        if (error != null)
                          Semantics(
                            liveRegion: true,
                            child: Text(error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
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

/// The preset picker and the full checklist of spec 6.10, each box with a
/// one-line explanation. A box that pulls another on (or off) says so
/// under it.
class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({required this.form, required this.enabled});

  final AssistantForm form;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dependency = form.lastDependency;
    return SectionCard(
      icon: Icons.verified_user_outlined,
      title: l10n.assistantPermissions,
      subtitle: l10n.assistantPermissionsHint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveGrid(
            columns: 4,
            minColumnWidth: 150,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in AssistantPreset.all)
                _PresetCard(
                  preset: preset,
                  selected: form.preset == preset,
                  onTap: enabled ? () => form.pickPreset(preset) : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (group, keys) in permissionGroups) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 16, bottom: 4),
              child: Row(
                children: [
                  ExcludeSemantics(child: Icon(permissionGroupIcon(group), size: 18, color: scheme.primary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l10n.permissionGroupName(group), style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
                    ),
                  ),
                ],
              ),
            ),
            for (final key in keys) ...[
              CheckboxListTile(
                key: ValueKey('permission.$key'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: form.permissions.contains(key),
                onChanged: enabled ? (on) => form.toggle(key, on ?? false) : null,
                title: Text(l10n.permissionName(key)),
                subtitle: Text(l10n.permissionHelp(key), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
              AnimatedSize(
                duration: Motion.of(context).reduced ? Duration.zero : Motion.normal,
                curve: Motion.standardCurve,
                alignment: AlignmentDirectional.topStart,
                child: dependency != null && dependency.$1 == key
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(start: 40, bottom: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: InfoBanner(
                            icon: Icons.link,
                            message: dependency.$3
                                ? l10n.assistantAlsoOn(l10n.permissionList(dependency.$2))
                                : l10n.assistantAlsoOff(l10n.permissionList(dependency.$2)),
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.preset, required this.selected, this.onTap});

  final String preset;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduced = Motion.of(context).reduced;
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '${l10n.assistantPresetName(preset)}. ${l10n.assistantPresetBody(preset)}',
      child: AnimatedContainer(
        duration: reduced ? Duration.zero : Motion.fast,
        curve: Motion.standardCurve,
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.assistantPresetName(preset),
                    style: theme.textTheme.titleSmall?.copyWith(color: selected ? scheme.onPrimaryContainer : null),
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: reduced ? Duration.zero : Motion.fast,
                  curve: Motion.springBouncy,
                  child: Icon(Icons.check_circle, size: 18, color: scheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.assistantPresetBody(preset),
              style: theme.textTheme.bodySmall?.copyWith(color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
