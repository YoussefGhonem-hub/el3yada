import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/validation/validators.dart';
import '../../patient/presentation/patient_format.dart';
import '../application/appointment_providers.dart';
import '../domain/appointment_models.dart';
import 'appointment_format.dart';

/// Picks an existing patient by name, phone or file number (D32 step 1). Returns null when cancelled.
class PatientPickerField extends ConsumerStatefulWidget {
  const PatientPickerField({super.key, required this.onPicked});

  final ValueChanged<PatientLookup> onPicked;

  @override
  ConsumerState<PatientPickerField> createState() => _PatientPickerFieldState();
}

class _PatientPickerFieldState extends ConsumerState<PatientPickerField> {
  final _query = TextEditingController();
  Timer? _debounce;
  String _term = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = ref.watch(patientLookupProvider(_term));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _query,
          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: l10n.searchPatient),
          onChanged: (v) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _term = v.trim()));
          },
        ),
        const SizedBox(height: 8),
        ...switch (results) {
          AsyncValue(:final value?, hasValue: true) => [
              for (final p in value.take(6))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_outline),
                  title: Text(p.name),
                  subtitle: Text('${l10n.fileNumber(p.fileNumber)} · ${context.localPhone(p.phone)}'
                      '${p.lastVisitAt == null ? ' · ${l10n.newPatient}' : ' · ${l10n.lastVisit}: ${context.date(p.lastVisitAt!)}'}'),
                  trailing: p.upcomingAppointmentId != null ? Icon(Icons.event_available, semanticLabel: l10n.hasUpcoming) : null,
                  onTap: () => widget.onPicked(p),
                ),
            ],
          AsyncValue(hasError: true) => [Text(l10n.errorUnknown)],
          _ => [const LinearProgressIndicator()],
        },
      ],
    );
  }
}

/// Case 4: a patient arrives without a booking: checked in at once with the next number.
class WalkInDialog extends ConsumerStatefulWidget {
  const WalkInDialog({super.key, required this.branchId});

  final String branchId;

  @override
  ConsumerState<WalkInDialog> createState() => _WalkInDialogState();
}

class _WalkInDialogState extends ConsumerState<WalkInDialog> {
  PatientLookup? _patient;
  bool _guest = false;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _visitType;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool get _isNew => _guest || (_patient?.isNew ?? false);

  Future<void> _save() async {
    final l10n = context.l10n;
    final visitType = _isNew ? 'examination' : _visitType;
    if (visitType == null) {
      setState(() => _error = l10n.chooseVisitType);
      return;
    }
    String? phone;
    if (_guest) {
      phone = Validators.normalizeEgyptianMobile(_phone.text);
      if (_name.text.trim().split(' ').where((w) => w.isNotEmpty).length < 2 || phone == null) {
        setState(() => _error = l10n.guestNameAndPhone);
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(boardProvider(widget.branchId).notifier).walkIn(
            patientId: _patient?.patientId, guestName: _guest ? _name.text.trim() : null, guestPhone: phone, visitType: visitType);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = context.bookingError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.walkIn),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<bool>(
                segments: [ButtonSegment(value: false, label: Text(l10n.existingPatient)), ButtonSegment(value: true, label: Text(l10n.guest))],
                selected: {_guest},
                onSelectionChanged: (v) => setState(() {
                  _guest = v.single;
                  _patient = null;
                }),
              ),
              const SizedBox(height: 12),
              if (_guest) ...[
                TextField(controller: _name, decoration: InputDecoration(labelText: l10n.fullName)),
                const SizedBox(height: 8),
                TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: l10n.mobileNumber)),
              ] else if (_patient == null)
                PatientPickerField(onPicked: (p) => setState(() => _patient = p))
              else
                ListTile(
                  title: Text(_patient!.name),
                  subtitle: Text(l10n.fileNumber(_patient!.fileNumber)),
                  trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _patient = null)),
                ),
              if (_guest || _patient != null) ...[
                const SizedBox(height: 12),
                VisitTypePicker(
                  isNew: _isNew,
                  consultationAllowed: _patient?.consultationAllowed ?? false,
                  value: _visitType,
                  onChanged: (v) => setState(() => _visitType = v),
                ),
              ],
              if (_error != null) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _saving || (!_guest && _patient == null) ? null : _save, child: Text(l10n.checkIn)),
      ],
    );
  }
}

/// BR-AP4: new patients and guests are examinations (locked); existing patients must choose,
/// with nothing pre-selected, and consultation is off at the limit.
class VisitTypePicker extends StatelessWidget {
  const VisitTypePicker({
    super.key,
    required this.isNew,
    required this.consultationAllowed,
    required this.value,
    required this.onChanged,
    this.examPrice,
    this.consultationPrice,
    this.consultationCount,
    this.maxConsultations,
  });

  final bool isNew;
  final bool consultationAllowed;
  final String? value;
  final ValueChanged<String> onChanged;
  final int? examPrice;
  final int? consultationPrice;
  final int? consultationCount;
  final int? maxConsultations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final showPrices = examPrice != null || consultationPrice != null;
    Widget option(String code, String label, int? price, {required bool enabled}) => RadioListTile<String>(
          value: code,
          title: Text(label),
          subtitle: showPrices ? Text(context.price(price)) : null,
          enabled: enabled,
          contentPadding: EdgeInsets.zero,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.visitType, style: theme.textTheme.titleSmall),
        RadioGroup<String>(
          groupValue: isNew ? 'examination' : value,
          onChanged: (v) {
            if (v != null && !isNew) onChanged(v);
          },
          child: Column(children: [
            option('examination', l10n.visitTypeExamination, examPrice, enabled: true),
            if (!isNew) option('consultation', l10n.visitTypeConsultation, consultationPrice, enabled: consultationAllowed),
          ]),
        ),
        if (isNew) Text(l10n.firstVisitIsExam, style: theme.textTheme.bodySmall),
        if (!isNew && !consultationAllowed) Text(l10n.errConsultationRequiresExam, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        if (!isNew && consultationAllowed && consultationCount != null && maxConsultations != null && consultationCount! > 0)
          Text(l10n.consultationCount(consultationCount!, maxConsultations!), style: theme.textTheme.bodySmall),
      ],
    );
  }
}
