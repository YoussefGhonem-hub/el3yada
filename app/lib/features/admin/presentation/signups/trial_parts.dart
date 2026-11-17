import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/admin_controllers.dart';
import '../../data/admin_repository.dart';
import '../../domain/admin_models.dart';
import '../widgets/admin_widgets.dart';

/// The words for a doctor's status (`Doctors.Status`).
String doctorStatusLabel(AppLocalizations l10n, String status) => switch (status) {
      DoctorStatuses.pendingApproval => l10n.adminStatusPending,
      DoctorStatuses.active => l10n.adminStatusActive,
      DoctorStatuses.rejected => l10n.adminStatusRejected,
      DoctorStatuses.suspended => l10n.adminStatusSuspended,
      _ => l10n.adminStatusDisabled,
    };

/// A doctor's status as a pill: a legacy sign-up waiting or rejected, or a
/// suspended or disabled account.
class DoctorStatusPill extends StatelessWidget {
  const DoctorStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => StatusPill(
        label: doctorStatusLabel(AppLocalizations.of(context), status),
        tone: switch (status) {
          DoctorStatuses.pendingApproval => PillTone.warning,
          DoctorStatuses.active => PillTone.positive,
          DoctorStatuses.rejected || DoctorStatuses.suspended => PillTone.danger,
          _ => PillTone.neutral,
        },
      );
}

/// A doctor's free trial as a small pill (spec 6.16): days left, ended, or
/// (with [showActive]) the service active.
class TrialPill extends StatelessWidget {
  const TrialPill({super.key, required this.trial, this.showActive = false});

  final TrialInfo? trial;
  final bool showActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trial = this.trial;
    if (trial == null) {
      return showActive
          ? StatusPill(label: l10n.adminServiceActive, tone: PillTone.positive, icon: Icons.verified_outlined)
          : const SizedBox.shrink();
    }
    return trial.ended
        ? StatusPill(label: l10n.adminTrialEnded, tone: PillTone.danger, icon: Icons.timer_off_outlined)
        : StatusPill(
            label: l10n.adminTrialDaysLeft(trial.daysLeft),
            tone: PillTone.warning,
            icon: Icons.hourglass_bottom_rounded,
          );
  }
}

/// AD3 for an approved doctor: the free trial (running, ended, or the
/// service active) with Activate service and Extend trial (BR-T5).
class DoctorTrialSection extends ConsumerStatefulWidget {
  const DoctorTrialSection({super.key, required this.registration});

  final DoctorRegistration registration;

  @override
  ConsumerState<DoctorTrialSection> createState() => _DoctorTrialSectionState();
}

class _DoctorTrialSectionState extends ConsumerState<DoctorTrialSection> {
  SubmitStatus _activate = SubmitStatus.idle;
  bool _busy = false;

  DoctorRegistration get _registration => widget.registration;

  Future<void> _onActivate() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmAction(
      context,
      title: l10n.adminActivateServiceTitle(_registration.fullName),
      message: l10n.adminActivateServiceBody,
      confirmLabel: l10n.adminActivateService,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _activate = SubmitStatus.loading;
      _busy = true;
    });
    try {
      await ref.read(adminRepositoryProvider).activateDoctorService(_registration.doctorId);
      if (!mounted) return;
      setState(() => _activate = SubmitStatus.success);
      _changed(l10n.adminServiceActivatedMessage(_registration.fullName));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _activate = SubmitStatus.idle;
        _busy = false;
      });
      showAdminSnack(context, l10n.apiError(error), error: true);
    }
  }

  Future<void> _onExtend() async {
    final l10n = AppLocalizations.of(context);
    final view = await showDialog<DoctorTrialView>(
      context: context,
      builder: (context) => _ExtendTrialDialog(registration: _registration),
    );
    if (view == null || !mounted) return;
    _changed(l10n.adminTrialExtendedMessage(_registration.fullName, AppFormat.date(context, view.trial!.endsAt.toLocal())));
  }

  /// The doctor's trial changed: reload AD3 and AD2, and say so.
  void _changed(String message) {
    showAdminSnack(context, message);
    ref.invalidate(registrationDetailProvider(_registration.doctorId));
    ref.read(signupsControllerProvider.notifier).refresh().ignore();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trial = _registration.trial;
    final String body;
    if (trial == null) {
      body = l10n.adminServiceActiveBody;
    } else if (trial.ended) {
      body = l10n.adminTrialEndedBody(AppFormat.date(context, trial.endsAt.toLocal()));
    } else {
      body = l10n.adminTrialRunningBody(AppFormat.date(context, trial.endsAt.toLocal()));
    }
    return SectionCard(
      icon: Icons.hourglass_bottom_rounded,
      title: l10n.adminSectionTrial,
      trailing: TrialPill(trial: trial, showActive: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(body, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          if (trial != null) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: SubmitButton(label: l10n.adminActivateService, status: _activate, onPressed: _onActivate),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _onExtend,
                  icon: const Icon(Icons.more_time_rounded),
                  label: Text(l10n.adminExtendTrial),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// How many days to add (1–90, 7 by default), then `extendDoctorTrial`.
/// Pops with the new trial.
class _ExtendTrialDialog extends ConsumerStatefulWidget {
  const _ExtendTrialDialog({required this.registration});

  final DoctorRegistration registration;

  @override
  ConsumerState<_ExtendTrialDialog> createState() => _ExtendTrialDialogState();
}

class _ExtendTrialDialogState extends ConsumerState<_ExtendTrialDialog> {
  static const minDays = 1;
  static const maxDays = 90;

  final _days = TextEditingController(text: '7');
  SubmitStatus _status = SubmitStatus.idle;
  String? _error;

  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  int? get _value => int.tryParse(Validators.normalizeDigits(_days.text.trim()));

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final days = _value;
    if (days == null || days < minDays || days > maxDays) {
      setState(() => _error = l10n.adminErrorRange('$minDays', '$maxDays'));
      return;
    }
    setState(() {
      _status = SubmitStatus.loading;
      _error = null;
    });
    try {
      final view = await ref.read(adminRepositoryProvider).extendDoctorTrial(widget.registration.doctorId, days: days);
      if (mounted) Navigator.of(context).pop(view);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _error = error.fieldCodes['days'] == null ? l10n.apiError(error) : l10n.adminErrorRange('$minDays', '$maxDays');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.adminExtendTrialTitle(widget.registration.fullName)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.adminExtendTrialBody),
            const SizedBox(height: 16),
            TextField(
              controller: _days,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩]')), LengthLimitingTextInputFormatter(2)],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.adminExtendTrialDays,
                suffixText: l10n.adminUnitDays,
                helperText: l10n.adminRangeHint('$minDays', '$maxDays'),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _status == SubmitStatus.loading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.adminCancel),
        ),
        SizedBox(
          width: 160,
          child: SubmitButton(label: l10n.adminExtendTrial, status: _status, onPressed: _submit),
        ),
      ],
    );
  }
}
