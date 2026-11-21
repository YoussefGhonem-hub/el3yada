import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format/app_format.dart';
import '../../../core/network/api_error_text.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../admin/presentation/widgets/admin_widgets.dart';
import '../../billing/domain/billing_models.dart';

/// Asks the admin for a reason before a money action or a status change
/// (BR-PAY3, BR-PAY4, BR-G4): 3 to 500 characters. [presets] are tappable
/// phrases that fill the box. Returns the text, or null when cancelled.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
  List<String> presets = const [],
  String? label,
  bool destructive = false,
}) => showDialog<String>(
  context: context,
  builder: (context) => _ReasonDialog(
    title: title,
    confirmLabel: confirmLabel,
    message: message,
    presets: presets,
    label: label,
    destructive: destructive,
  ),
);

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.confirmLabel,
    this.message,
    required this.presets,
    this.label,
    required this.destructive,
  });

  final String title;
  final String confirmLabel;
  final String? message;
  final List<String> presets;
  final String? label;
  final bool destructive;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final text = _controller.text.trim();
    if (text.length < 3) {
      setState(() => _error = l10n.abReasonRequired);
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.message != null) ...[
                Text(widget.message!),
                const SizedBox(height: 12),
              ],
              if (widget.presets.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in widget.presets)
                      ActionChip(
                        label: Text(preset),
                        onPressed: () => setState(() {
                          _controller.text = preset;
                          _error = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
                decoration: InputDecoration(
                  labelText: widget.label ?? l10n.abReasonLabel,
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.adminCancel),
        ),
        FilledButton(
          style: widget.destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// «شهر أكتوبر 2026 — 4,800 ج.م».
String invoiceLine(BuildContext context, String monthLabel, int piasters) =>
    '$monthLabel — ${AppFormat.egp(context, piasters)}';

/// A doctor's status as the admin reads it (AD4, AD5).
String doctorStatusLabel(AppLocalizations l10n, String status) =>
    switch (status) {
      'active' => l10n.abDoctorActive,
      'pendingApproval' => l10n.abDoctorPending,
      'suspended' => l10n.abDoctorSuspended,
      'disabled' => l10n.abDoctorDisabled,
      'rejected' => l10n.abDoctorRejected,
      _ => status,
    };

PillTone doctorStatusTone(String status) => switch (status) {
  'active' => PillTone.positive,
  'pendingApproval' => PillTone.accent,
  'suspended' || 'disabled' || 'rejected' => PillTone.danger,
  _ => PillTone.neutral,
};

/// Shows a failed action's message in a snack bar (409 codes have their own texts).
void showActionError(BuildContext context, Object error) => showAdminSnack(
  context,
  AppLocalizations.of(context).apiError(error),
  error: true,
);

/// The three rejection presets of BR-PAY3, then free text.
List<String> rejectionPresets(AppLocalizations l10n) => [
  l10n.abRejectAmount,
  l10n.abRejectUnclear,
  l10n.abRejectNotReceived,
];

/// Month filter values: the last 12 months, newest first, as `yyyy-MM`.
List<String> lastMonthKeys(DateTime today, {int count = 12}) => [
  for (var i = 0; i < count; i++)
    () {
      final month = DateTime.utc(today.year, today.month - i);
      return '${month.year}-${month.month.toString().padLeft(2, '0')}';
    }(),
];

/// An invoice status as a choice chip row for AD9's filter.
List<InvoiceStatus> get filterableStatuses => const [
  InvoiceStatus.unpaid,
  InvoiceStatus.pendingReview,
  InvoiceStatus.overdue,
  InvoiceStatus.rejected,
  InvoiceStatus.paid,
  InvoiceStatus.waived,
  InvoiceStatus.noCharge,
];
