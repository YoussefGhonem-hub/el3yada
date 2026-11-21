import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../appointments/application/appointment_providers.dart';
import '../../../appointments/domain/appointment_models.dart';
import '../../../appointments/presentation/place_picker.dart';
import '../widgets/clinic_admin_widgets.dart';
import 'branch_text.dart';
import 'schedule_tabs.dart' show scheduleDayText;

/// BR-AP12's conflicts sheet: the bookings a schedule change leaves without a
/// place, each to keep as an exception, move (to the server's suggestion or a
/// place picked here) or cancel (the patient is told, with a rebook link), or
/// one action for all. Null when closed without applying: nothing is saved.
Future<Map<String, ConflictDecision>?> showScheduleConflictsSheet(
  BuildContext context, {
  required List<ScheduleConflict> conflicts,
  required String branchId,
}) =>
    showModalBottomSheet<Map<String, ConflictDecision>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 760),
      builder: (context) => ScheduleConflictsSheet(conflicts: conflicts, branchId: branchId),
    );

class ScheduleConflictsSheet extends StatefulWidget {
  const ScheduleConflictsSheet({super.key, required this.conflicts, required this.branchId});

  final List<ScheduleConflict> conflicts;

  /// The branch whose schedule changes: a move defaults to it.
  final String branchId;

  @override
  State<ScheduleConflictsSheet> createState() => _ScheduleConflictsSheetState();
}

class _ScheduleConflictsSheetState extends State<ScheduleConflictsSheet> {
  // Nothing is dropped by default: every booking starts as kept.
  late final Map<String, ConflictDecision> _decisions = {
    for (final c in widget.conflicts) c.appointmentId: const ConflictDecision.keep(),
  };

  /// Places picked here, which win over the suggestion.
  final _picked = <String, MovePlace>{};

  MovePlace? _targetOf(ScheduleConflict c) => _picked[c.appointmentId] ?? c.suggestion;

  void _all(String action) => setState(() {
        for (final c in widget.conflicts) {
          final target = _targetOf(c);
          _decisions[c.appointmentId] = switch (action) {
            ConflictDecision.cancelAction => const ConflictDecision.cancel(),
            // A booking without a free place stays as it is until one is picked.
            ConflictDecision.moveAction => target == null ? _decisions[c.appointmentId]! : ConflictDecision.move(target),
            _ => const ConflictDecision.keep(),
          };
        }
      });

  Future<void> _choose(ScheduleConflict c, String action) async {
    if (action != ConflictDecision.moveAction) {
      setState(() => _decisions[c.appointmentId] = action == ConflictDecision.cancelAction
          ? const ConflictDecision.cancel()
          : const ConflictDecision.keep());
      return;
    }
    final target = _targetOf(c) ?? await _pick(c);
    if (target == null || !mounted) return;
    setState(() => _decisions[c.appointmentId] = ConflictDecision.move(target));
  }

  Future<MovePlace?> _pick(ScheduleConflict c) async {
    final picked = await showDialog<MovePlace>(
      context: context,
      builder: (context) => _PickPlaceDialog(conflict: c, branchId: c.branchId ?? widget.branchId, initial: _targetOf(c)),
    );
    if (picked != null && mounted) setState(() => _picked[c.appointmentId] = picked);
    return picked;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = widget.conflicts.length;
    String allAction() {
      final actions = _decisions.values.map((d) => d.action).toSet();
      return actions.length == 1 ? actions.single : '';
    }

    final moves = _decisions.values.where((d) => d.action == ConflictDecision.moveAction).length;
    final cancels = _decisions.values.where((d) => d.action == ConflictDecision.cancelAction).length;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: scheme.tertiaryContainer, shape: BoxShape.circle),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.event_busy_outlined, color: scheme.onTertiaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l10n.affectedBookings(count), style: theme.textTheme.titleLarge),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(l10n.conflictsBody, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Text(l10n.conflictsForAll, style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.push_pin_outlined, size: 18),
                  label: Text(l10n.keepAll),
                  selected: allAction() == ConflictDecision.keepAction,
                  onSelected: (_) => _all(ConflictDecision.keepAction),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.east, size: 18),
                  label: Text(l10n.moveAll),
                  selected: allAction() == ConflictDecision.moveAction,
                  onSelected: widget.conflicts.any((c) => _targetOf(c) != null) ? (_) => _all(ConflictDecision.moveAction) : null,
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.event_busy_outlined, size: 18),
                  label: Text(l10n.cancelAll),
                  selected: allAction() == ConflictDecision.cancelAction,
                  onSelected: (_) => _all(ConflictDecision.cancelAction),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: count,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = widget.conflicts[i];
                  return _ConflictRow(
                    key: ValueKey(c.appointmentId),
                    conflict: c,
                    decision: _decisions[c.appointmentId]!,
                    target: _targetOf(c),
                    onChoose: (action) => _choose(c, action),
                    onPick: () async {
                      final picked = await _pick(c);
                      if (picked != null && mounted) setState(() => _decisions[c.appointmentId] = ConflictDecision.move(picked));
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (moves > 0 || cancels > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  [if (moves > 0) l10n.scheduleMovedCount(moves), if (cancels > 0) l10n.scheduleCancelledCount(cancels)]
                      .join(l10n.regListSeparator),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l10n.conflictsDismiss)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, Map<String, ConflictDecision>.of(_decisions)),
                    icon: const Icon(Icons.check),
                    label: Text(l10n.applyChanges),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConflictRow extends StatelessWidget {
  const _ConflictRow({
    super.key,
    required this.conflict,
    required this.decision,
    required this.target,
    required this.onChoose,
    required this.onPick,
  });

  final ScheduleConflict conflict;
  final ConflictDecision decision;
  final MovePlace? target;
  final ValueChanged<String> onChoose;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduced = Motion.of(context).reduced;
    final c = conflict;
    final when = [
      scheduleDayText(context, c.date),
      clockText(context, c.time),
      if (c.queueNumber != null) l10n.queueNumber(c.queueNumber!),
    ].join(l10n.regListSeparator);
    final (String note, IconData noteIcon, Color noteColor) = switch (decision.action) {
      ConflictDecision.moveAction => (
          l10n.conflictMoveTo('${scheduleDayText(context, decision.to!.date)}${l10n.regListSeparator}${clockText(context, decision.to!.time)}'),
          Icons.east,
          scheme.primary,
        ),
      ConflictDecision.cancelAction => (l10n.conflictCancelNote, Icons.notifications_active_outlined, scheme.error),
      _ => (target == null ? l10n.conflictKeepNoPlace : l10n.conflictKeepNote, Icons.push_pin_outlined, scheme.onSurfaceVariant),
    };
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const RowIcon(Icons.event_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.displayName, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(when, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: ConflictDecision.keepAction, icon: const Icon(Icons.push_pin_outlined), label: Text(l10n.keep)),
                ButtonSegment(value: ConflictDecision.moveAction, icon: const Icon(Icons.east), label: Text(l10n.conflictMove)),
                ButtonSegment(value: ConflictDecision.cancelAction, icon: const Icon(Icons.event_busy_outlined), label: Text(l10n.cancel)),
              ],
              selected: {decision.action},
              onSelectionChanged: (v) => onChoose(v.single),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: reduced ? Duration.zero : Motion.normal,
              reverseDuration: reduced ? Duration.zero : Motion.normalExit,
              switchInCurve: Motion.enterCurve,
              switchOutCurve: Motion.exitCurve,
              child: Row(
                key: ValueKey('${decision.action}-${decision.to?.date}-${decision.to?.time}'),
                children: [
                  ExcludeSemantics(child: Icon(noteIcon, size: 18, color: noteColor)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(note, style: theme.textTheme.bodySmall?.copyWith(color: noteColor))),
                  if (decision.action == ConflictDecision.moveAction || target == null)
                    TextButton(onPressed: onPick, child: Text(target == null ? l10n.conflictPickPlace : l10n.conflictChangePlace)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Another place for one booking: a branch the caller works in, then a day
/// and a period or slot from the server's availability (BR-AP1).
class _PickPlaceDialog extends ConsumerStatefulWidget {
  const _PickPlaceDialog({required this.conflict, required this.branchId, this.initial});

  final ScheduleConflict conflict;
  final String branchId;
  final MovePlace? initial;

  @override
  ConsumerState<_PickPlaceDialog> createState() => _PickPlaceDialogState();
}

class _PickPlaceDialogState extends ConsumerState<_PickPlaceDialog> {
  late String _branchId = widget.initial?.branchId ?? widget.branchId;
  PlaceChoice? _place;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final branches = ref.watch(staffBranchesProvider).value ?? const [];
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return AlertDialog(
      title: Text(l10n.conflictPickPlace),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, minWidth: 320),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.conflict.displayName, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(l10n.conflictPickNote, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              if (branches.length > 1) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: branches.any((b) => b.id == _branchId) ? _branchId : null,
                  decoration: InputDecoration(labelText: l10n.branchesTitle),
                  items: [for (final b in branches) DropdownMenuItem(value: b.id, child: Text(b.displayName(arabic: arabic)))],
                  onChanged: (id) => setState(() {
                    if (id != null) _branchId = id;
                    _place = null;
                  }),
                ),
              ],
              const SizedBox(height: 12),
              PlacePicker(
                key: ValueKey(_branchId),
                branchId: _branchId,
                visitType: widget.conflict.visitType,
                staff: true,
                value: _place,
                onChanged: (p) => setState(() => _place = p),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.adminCancel)),
        FilledButton(
          onPressed: _place == null || _place!.full
              ? null
              : () => Navigator.pop(context, MovePlace(branchId: _branchId, date: _place!.date, time: _place!.time)),
          child: Text(l10n.conflictMove),
        ),
      ],
    );
  }
}
