import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_text.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../patients/application/patients_providers.dart';
import '../../patients/presentation/widgets/clinic_ui.dart';
import '../../sessions/domain/session_models.dart';
import '../domain/record_models.dart';
import 'record_text.dart';

/// The BR-F3 details of a record, shared by D10/D11 (new) and D12 "edit
/// details": category (required), the Other type, title (the hint shows the
/// default), document date (not in the future), notes, and the visit.
/// Read it with [RecordFormState.validate] through a `GlobalKey`.
class RecordForm extends ConsumerStatefulWidget {
  const RecordForm({
    super.key,
    required this.patientId,
    this.initial,
    this.fieldErrors = const {},
    this.enabled = true,
  });

  final String patientId;

  /// The record being edited; null for a new one (the visit then defaults to
  /// today's, if there is one).
  final RecordDraft? initial;

  /// The server's field messages, by JSON field name.
  final Map<String, String> fieldErrors;
  final bool enabled;

  @override
  ConsumerState<RecordForm> createState() => RecordFormState();
}

class RecordFormState extends ConsumerState<RecordForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late final _otherText = TextEditingController(text: widget.initial?.otherTypeText ?? '');
  late RecordCategory? _category = widget.initial?.category;
  late RecordOtherType? _otherType = widget.initial?.otherType;
  late DateTime _date = widget.initial?.documentDate ?? ClinicFormat.today();
  late String? _sessionId = widget.initial?.sessionId;
  bool _sessionTouched = false;
  bool _showCategoryError = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _otherText.dispose();
    super.dispose();
  }

  /// The details, or null with the errors shown.
  RecordDraft? validate() {
    final formOk = _form.currentState?.validate() ?? false;
    setState(() => _showCategoryError = _category == null);
    if (!formOk || _category == null) return null;
    return RecordDraft(
      category: _category!,
      otherType: _category == RecordCategory.other ? _otherType : null,
      otherTypeText: _otherType == RecordOtherType.custom ? _otherText.text : null,
      title: _title.text,
      documentDate: _date,
      notes: _notes.text,
      sessionId: _sessionId,
    );
  }

  String _defaultTitle(AppLocalizations l10n) {
    final name = (_category == RecordCategory.other && _otherType == RecordOtherType.custom && _otherText.text.trim().isNotEmpty)
        ? _otherText.text.trim()
        : (_category == RecordCategory.other && _otherType != null && _otherType != RecordOtherType.custom)
            ? l10n.recordOtherTypeName(_otherType!)
            : _category == null
                ? '…'
                : l10n.recordCategoryName(_category);
    return '$name ${dayKey(_date)}';
  }

  Future<void> _pickDate() async {
    final today = ClinicFormat.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime.utc(1900),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _date = DateTime.utc(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final errors = widget.fieldErrors;
    final sessions = ref.watch(patientSessionsProvider(widget.patientId));
    final today = ClinicFormat.today();

    // A new record links to today's visit when there is one (D10).
    if (widget.initial == null && !_sessionTouched && _sessionId == null && !sessions.loading) {
      for (final s in sessions.items) {
        if (s.day == today) {
          _sessionId = s.sessionId;
          break;
        }
      }
    }

    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.recordFieldCategory, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          ClinicChips(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in RecordCategory.values)
                  ChoiceChip(
                    avatar: Icon(recordCategoryIcon(category), size: 18),
                    label: Text(l10n.recordCategoryName(category)),
                    selected: _category == category,
                    onSelected: widget.enabled
                        ? (_) => setState(() {
                              _category = category;
                              _showCategoryError = false;
                            })
                        : null,
                  ),
              ],
            ),
          ),
          if (_showCategoryError || errors['category'] != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
              child: Text(
                errors['category'] ?? l10n.recordCategoryRequired,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          if (_category == RecordCategory.other) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<RecordOtherType?>(
              initialValue: _otherType,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.recordFieldOtherType, errorText: errors['otherType']),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.recordOtherNone)),
                for (final type in RecordOtherType.values) DropdownMenuItem(value: type, child: Text(l10n.recordOtherTypeName(type))),
              ],
              onChanged: widget.enabled ? (value) => setState(() => _otherType = value) : null,
            ),
            if (_otherType == RecordOtherType.custom) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _otherText,
                enabled: widget.enabled,
                maxLength: 60,
                decoration: InputDecoration(labelText: l10n.recordFieldOtherTypeText, errorText: errors['otherTypeText']),
                validator: (value) => (value ?? '').trim().isEmpty ? l10n.errorRequired : null,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _title,
            enabled: widget.enabled,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: l10n.recordFieldTitle,
              helperText: _title.text.trim().isEmpty ? l10n.recordTitleHint(_defaultTitle(l10n)) : null,
              errorText: errors['title'],
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: widget.enabled ? _pickDate : null,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.recordFieldDate,
                errorText: errors['documentDate'],
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              child: Text(ClinicFormat.day(context, _date)),
            ),
          ),
          if (!sessions.loading && sessions.error == null && sessions.items.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              key: ValueKey('session-$_sessionId'),
              initialValue: sessions.items.any((s) => s.sessionId == _sessionId) ? _sessionId : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.recordFieldSession, errorText: errors['sessionId']),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.recordNoSession)),
                for (final s in sessions.items)
                  DropdownMenuItem(
                    value: s.sessionId,
                    child: Text(
                      l10n.recordSessionOption(sessionTypeLabel(l10n, s.type), ClinicFormat.dayAuto(context, s.day)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: widget.enabled
                  ? (value) => setState(() {
                        _sessionTouched = true;
                        _sessionId = value;
                      })
                  : null,
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _notes,
            enabled: widget.enabled,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: InputDecoration(labelText: l10n.recordFieldNotes, errorText: errors['notes']),
          ),
        ],
      ),
    );
  }
}

/// The server's field codes as messages for [RecordForm].
Map<String, String> recordFieldErrors(AppLocalizations l10n, Map<String, String> codes) => {
      for (final MapEntry(:key, :value) in codes.entries)
        if (key != 'uploadIds') key: switch (value) {
          'INVALID_SESSION' => l10n.recordErrorInvalidSession,
          'INVALID_DATE' => l10n.recordErrorInvalidDate,
          _ => l10n.fieldError(value) ?? l10n.errorUnknown,
        },
    };
