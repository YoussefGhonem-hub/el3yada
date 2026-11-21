import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/staggered_entrance.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../clinic/domain/clinic_context.dart';
import '../../patients/clinic_paths.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../../sessions/application/sessions_providers.dart';
import '../application/prescriptions_providers.dart';
import '../data/prescriptions_repository.dart';
import '../domain/prescription_models.dart';
import '../pdf/rx_text.dart';
import 'widgets/item_sheets.dart';
import 'widgets/rx_widgets.dart';

/// D13 (medication) and D14 (investigations), AS7 [S] for assistants with
/// `prescriptionsDraft`. Items are dragged to reorder and swiped away; the
/// draft saves when you leave (BR-RX2: drafts are invisible to the patient).
class PrescriptionEditor extends ConsumerStatefulWidget {
  const PrescriptionEditor({super.key, required this.rx, required this.clinic});

  final Prescription rx;
  final ClinicContext clinic;

  @override
  ConsumerState<PrescriptionEditor> createState() => _PrescriptionEditorState();
}

class _PrescriptionEditorState extends ConsumerState<PrescriptionEditor> {
  late final _diagnosis = TextEditingController(text: widget.rx.diagnosis);
  late final _advice = TextEditingController(text: widget.rx.advice);
  late DateTime? _followUp = widget.rx.followUpDate;
  late List<MedicationItem> _medications = [...widget.rx.medications];
  late List<InvestigationItem> _investigations = [...widget.rx.investigations];
  bool _dirty = false;
  SubmitStatus _saving = SubmitStatus.idle;
  bool _busy = false;
  String? _error;
  int _keySeed = 0;
  late List<int> _keys = List.generate(widget.rx.itemCount, (_) => _keySeed++);

  Prescription get _rx => widget.rx;
  bool get _medication => _rx.kind == PrescriptionKind.medication;
  int get _count => _medication ? _medications.length : _investigations.length;

  @override
  void dispose() {
    _diagnosis.dispose();
    _advice.dispose();
    super.dispose();
  }

  void _touch() => setState(() {
        _dirty = true;
        _error = null;
      });

  PrescriptionDraftInput get _input => PrescriptionDraftInput(
        diagnosis: _diagnosis.text,
        advice: _advice.text,
        followUpDate: _followUp,
        medications: _medications,
        investigations: _investigations,
      );

  /// `updatePrescriptionDraft`. True when saved (or nothing to save).
  Future<bool> _save({bool quiet = false}) async {
    if (!_dirty) return true;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _saving = SubmitStatus.loading;
      _error = null;
    });
    try {
      await ref.read(prescriptionsRepositoryProvider).updateDraft(_rx.prescriptionId, _rx.kind, _input);
      if (!mounted) return true;
      setState(() {
        _dirty = false;
        _saving = quiet ? SubmitStatus.idle : SubmitStatus.success;
      });
      prescriptionsChanged(ref, patientId: _rx.patientId, sessionId: _rx.sessionId);
      if (!quiet) {
        await Future<void>.delayed(Motion.of(context).reduced ? Duration.zero : Motion.slow);
        if (mounted) setState(() => _saving = SubmitStatus.idle);
      }
      return true;
    } on ApiException catch (error) {
      if (!mounted) return false;
      setState(() {
        _saving = SubmitStatus.idle;
        _error = l10n.apiError(error);
      });
      return false;
    }
  }

  Future<void> _preview() async {
    if (_count == 0) {
      setState(() => _error = AppLocalizations.of(context).rxErrorEmpty);
      return;
    }
    if (!await _save(quiet: true) || !mounted) return;
    ref.invalidate(prescriptionProvider(_rx.prescriptionId));
    await context.push(ref.read(clinicPathsProvider).prescriptionPreview(_rx.patientId, _rx.prescriptionId));
  }

  /// AS7: «إرسال للطبيب للمراجعة» (BR-AS12).
  Future<void> _submitForReview() async {
    final l10n = AppLocalizations.of(context);
    if (_count == 0) {
      setState(() => _error = l10n.rxErrorEmpty);
      return;
    }
    if (!await _save(quiet: true) || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(prescriptionsRepositoryProvider).submitForReview(_rx.prescriptionId);
      if (!mounted) return;
      prescriptionsChanged(ref, patientId: _rx.patientId, sessionId: _rx.sessionId, prescriptionId: _rx.prescriptionId);
      showAdminSnack(context, l10n.rxSubmittedForReview);
      _leave();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = l10n.apiError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.rxDeleteDraftTitle,
      message: l10n.rxDeleteDraftBody,
      confirmLabel: l10n.rxDeleteDraft,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(prescriptionsRepositoryProvider).deleteDraft(_rx.prescriptionId);
      if (!mounted) return;
      prescriptionsChanged(ref, patientId: _rx.patientId, sessionId: _rx.sessionId);
      _dirty = false;
      showAdminSnack(context, l10n.rxDraftDeleted);
      _leave();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = l10n.apiError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _leave() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      context.go(ref.read(clinicPathsProvider).patient(_rx.patientId));
    }
  }

  Future<void> _addOrEdit([int? index]) async {
    if (_medication) {
      final item = await showRxItemSheet<MedicationItem>(
        context,
        MedicationItemSheet(initial: index == null ? null : _medications[index]),
      );
      if (item == null || !mounted) return;
      setState(() {
        if (index == null) {
          _medications = [..._medications, item];
          _keys = [..._keys, _keySeed++];
        } else {
          _medications = [..._medications]..[index] = item;
        }
      });
    } else {
      final item = await showRxItemSheet<InvestigationItem>(
        context,
        InvestigationItemSheet(initial: index == null ? null : _investigations[index]),
      );
      if (item == null || !mounted) return;
      setState(() {
        if (index == null) {
          _investigations = [..._investigations, item];
          _keys = [..._keys, _keySeed++];
        } else {
          _investigations = [..._investigations]..[index] = item;
        }
      });
    }
    _touch();
  }

  void _remove(int index) {
    final l10n = AppLocalizations.of(context);
    final removedMed = _medication ? _medications[index] : null;
    final removedTest = _medication ? null : _investigations[index];
    final key = _keys[index];
    setState(() {
      if (_medication) {
        _medications = [..._medications]..removeAt(index);
      } else {
        _investigations = [..._investigations]..removeAt(index);
      }
      _keys = [..._keys]..removeAt(index);
    });
    _touch();
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l10n.rxItemRemoved),
        action: SnackBarAction(
          label: l10n.rxUndo,
          onPressed: () {
            if (!mounted) return;
            setState(() {
              if (removedMed != null) {
                _medications = [..._medications]..insert(index.clamp(0, _medications.length), removedMed);
              } else {
                _investigations = [..._investigations]..insert(index.clamp(0, _investigations.length), removedTest!);
              }
              _keys = [..._keys]..insert(index.clamp(0, _keys.length), key);
            });
          },
        ),
      ));
  }

  /// `onReorderItem`: [to] already counts the item taken out.
  void _reorder(int from, int to) {
    setState(() {
      if (_medication) {
        final list = [..._medications];
        list.insert(to, list.removeAt(from));
        _medications = list;
      } else {
        final list = [..._investigations];
        list.insert(to, list.removeAt(from));
        _investigations = list;
      }
      final keys = [..._keys];
      keys.insert(to, keys.removeAt(from));
      _keys = keys;
    });
    _touch();
  }

  /// «من قالب» [S]: the template's items are added, and its advice fills an empty box.
  Future<void> _fromTemplate() async {
    final l10n = AppLocalizations.of(context);
    final templates = await ref.read(templatesProvider(_rx.kind).future).catchError((_) => <PrescriptionTemplate>[]);
    if (!mounted) return;
    if (templates.isEmpty) {
      showAdminSnack(context, l10n.rxNoTemplates);
      return;
    }
    final template = await showModalBottomSheet<PrescriptionTemplate>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l10n.rxFromTemplate, style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final template in templates)
              ListTile(
                leading: Icon(rxKindIcon(template.kind)),
                title: Text(template.name),
                subtitle: Text(l10n.rxItemCount(template.itemCount)),
                onTap: () => Navigator.of(context).pop(template),
              ),
          ],
        ),
      ),
    );
    if (template == null || !mounted) return;
    setState(() {
      if (_medication) {
        _medications = [..._medications, ...template.medications];
        _keys = [..._keys, for (final _ in template.medications) _keySeed++];
      } else {
        _investigations = [..._investigations, ...template.investigations];
        _keys = [..._keys, for (final _ in template.investigations) _keySeed++];
      }
      if (_advice.text.trim().isEmpty && template.advice != null) _advice.text = template.advice!;
    });
    _touch();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paths = ref.watch(clinicPathsProvider);
    final session = ref.watch(sessionProvider(_rx.sessionId)).value;
    final doctor = widget.clinic.isDoctor;
    final title = rxKindName(l10n, _rx.kind);
    final subtitle = session == null
        ? null
        : '${session.patientName}${l10n.adminListSeparator}${ClinicFormat.day(context, session.day)}';
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _save(quiet: true) && mounted) _leave();
      },
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final gutter = clinicGutter(width);
            final bottom = MediaQuery.paddingOf(context).bottom;
            return Column(
              children: [
                Expanded(
                  child: StaggerGroup(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 24),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 820),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                StaggeredEntrance(
                                  index: 0,
                                  child: ClinicHeader(
                                    title: title,
                                    subtitle: subtitle,
                                    backFallback: paths.patient(_rx.patientId),
                                    trailingTitle: RxStatusPill(status: _rx.status),
                                    actions: [
                                      PopupMenuButton<String>(
                                        tooltip: l10n.rxMore,
                                        onSelected: (value) => switch (value) {
                                          'template' => saveRxAsTemplate(context, ref, kind: _rx.kind, items: _input),
                                          'delete' => _delete(),
                                          _ => null,
                                        },
                                        itemBuilder: (context) => [
                                          if (doctor && _count > 0)
                                            PopupMenuItem(value: 'template', child: Text(l10n.rxSaveAsTemplate)),
                                          PopupMenuItem(value: 'delete', child: Text(l10n.rxDeleteDraft)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (doctor && _rx.preparedBy?.isAssistant == true) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.rxPreparedBy(_rx.preparedBy!.name),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                                const SizedBox(height: 16),
                                StaggeredEntrance(
                                  index: 1,
                                  child: TextField(
                                    controller: _diagnosis,
                                    minLines: 1,
                                    maxLines: 3,
                                    maxLength: 1000,
                                    decoration: InputDecoration(labelText: l10n.rxDiagnosis, prefixIcon: const Icon(Icons.assignment_outlined)),
                                    onChanged: (_) => _touch(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                StaggeredEntrance(index: 2, child: _itemsCard(context)),
                                const SizedBox(height: 16),
                                StaggeredEntrance(
                                  index: 3,
                                  child: TextField(
                                    controller: _advice,
                                    minLines: 2,
                                    maxLines: 5,
                                    maxLength: 1000,
                                    decoration: InputDecoration(
                                      labelText: _medication ? l10n.rxAdvice : l10n.rxRequestNotes,
                                      alignLabelWithHint: true,
                                    ),
                                    onChanged: (_) => _touch(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                StaggeredEntrance(
                                  index: 4,
                                  child: RxDateField(
                                    label: _medication ? l10n.rxFollowUp : l10n.rxResultsOn,
                                    value: _followUp,
                                    from: ClinicFormat.today(),
                                    onChanged: (value) {
                                      _followUp = value;
                                      _touch();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _ActionBar(
                  gutter: gutter,
                  bottomInset: bottom,
                  error: _error,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy || !_dirty ? null : () => _save(),
                      icon: _saving == SubmitStatus.success ? const Icon(Icons.check) : const Icon(Icons.save_outlined),
                      label: Text(_saving == SubmitStatus.success ? l10n.rxDraftSaved : l10n.rxSaveDraft),
                    ),
                    if (doctor)
                      FilledButton.icon(
                        onPressed: _busy ? null : _preview,
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(l10n.rxPreview),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _busy || _rx.status == PrescriptionStatus.readyForReview && !_dirty ? null : _submitForReview,
                        icon: const Icon(Icons.send_outlined),
                        label: Text(l10n.rxSubmitForReview),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _itemsCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final empty = _count == 0;
    return SectionCard(
      title: _medication ? l10n.rxMedicines : l10n.rxTests,
      icon: rxKindIcon(_rx.kind),
      trailing: widget.clinic.isDoctor
          ? TextButton.icon(onPressed: _fromTemplate, icon: const Icon(Icons.bookmarks_outlined), label: Text(l10n.rxFromTemplate))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (empty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _medication ? l10n.rxNoMedicinesYet : l10n.rxNoTestsYet,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _count,
              onReorderItem: _reorder,
              itemBuilder: (context, index) => Dismissible(
                key: ValueKey(('item', _keys[index])),
                direction: DismissDirection.horizontal,
                background: _swipeBackground(context, AlignmentDirectional.centerStart),
                secondaryBackground: _swipeBackground(context, AlignmentDirectional.centerEnd),
                onDismissed: (_) => _remove(index),
                child: _ItemRow(
                  index: index,
                  title: _medication ? _medicationTitle(l10n, _medications[index]) : _investigations[index].name,
                  subtitle: _medication
                      ? rxInstructionLine(l10n, _medications[index])
                      : _investigations[index].notes,
                  chip: _medication && _medications[index].duration != null
                      ? rxDurationLabel(l10n, _medications[index].duration!)
                      : null,
                  icon: _medication
                      ? null
                      : (_investigations[index].category == InvestigationCategory.lab
                          ? Icons.science_outlined
                          : Icons.settings_overscan_outlined),
                  onTap: () => _addOrEdit(index),
                  onRemove: () => _remove(index),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: _count >= (_medication ? 30 : 50) ? null : () => _addOrEdit(),
              icon: const Icon(Icons.add),
              label: Text(_medication ? l10n.rxAddMedicine : l10n.rxAddTest),
            ),
          ),
        ],
      ),
    );
  }

  String _medicationTitle(AppLocalizations l10n, MedicationItem item) =>
      [item.drugName, ?item.strength, if (item.form != null) rxFormLabel(l10n, item.form)].join(' · ');

  Widget _swipeBackground(BuildContext context, AlignmentGeometry alignment) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.chip,
    required this.icon,
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final String title;
  final String? subtitle;
  final String? chip;
  final IconData? icon;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Tooltip(
                  message: l10n.rxDragToReorder,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.drag_indicator, color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (icon != null) ...[Icon(icon, size: 20, color: scheme.primary), const SizedBox(width: 8)] else
                SizedBox(
                  width: 24,
                  child: Text('${index + 1}.', style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary)),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (chip != null) ...[
                const SizedBox(width: 8),
                StatusPill(label: chip!),
              ],
              IconButton(tooltip: l10n.rxRemoveItem, onPressed: onRemove, icon: const Icon(Icons.close)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar under the editor and D15: the error above the buttons.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.gutter, required this.bottomInset, required this.children, this.error});

  final double gutter;
  final double bottomInset;
  final List<Widget> children;
  final String? error;

  @override
  Widget build(BuildContext context) => RxActionBar(gutter: gutter, bottomInset: bottomInset, error: error, children: children);
}

/// The bottom bar of D13–D15: an error line, then the actions at the end.
class RxActionBar extends StatelessWidget {
  const RxActionBar({super.key, required this.gutter, required this.bottomInset, required this.children, this.error});

  final double gutter;
  final double bottomInset;
  final List<Widget> children;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 6,
      shadowColor: scheme.shadow.withValues(alpha: 0.25),
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 12, gutter, 12 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSize(
              duration: Motion.normal,
              curve: Motion.standardCurve,
              child: error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(error!, style: TextStyle(color: scheme.error)),
                    ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: children,
            ),
          ],
        ),
      ),
    );
  }
}
