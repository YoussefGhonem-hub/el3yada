import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/contact_launcher.dart';
import '../application/patient_providers.dart';
import '../domain/patient_models.dart';
import 'medical_file_screen.dart' show PrescriptionRow;
import 'patient_format.dart';
import 'patient_routes.dart';
import 'widgets/patient_widgets.dart';

/// P5 Visit details. Shows only what the API returns for patients: private notes,
/// fees and staff fields never reach the app (AC-11).
class VisitDetailScreen extends ConsumerWidget {
  const VisitDetailScreen({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visit = ref.watch(visitDetailProvider(visitId));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.visitDetailsTitle)),
      body: AsyncValueView(
        value: visit,
        onRetry: () => ref.invalidate(visitDetailProvider(visitId)),
        data: (data) => _VisitBody(visit: data),
      ),
    );
  }
}

class _VisitBody extends StatelessWidget {
  const _VisitBody({required this.visit});

  final VisitDetail visit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final vitals = visit.vitals;

    String? text(String? value) => (value == null || value.trim().isEmpty) ? null : value;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  VisitTypeBadge(type: visit.type),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.dateTime(visit.at), style: theme.textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: 8),
              Text(context.doctorName(visit.doctor), style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              SectionCard(
                title: visit.branch.displayName(arabic: context.isArabic),
                icon: Icons.place_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visit.branch.address.singleLine),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.map_outlined),
                          label: Text(l10n.openInMaps),
                          onPressed: () => ContactLauncher.maps(visit.branch.address.mapsQuery),
                        ),
                        for (final phone in visit.branch.phones.take(1))
                          TextButton.icon(
                            icon: const Icon(Icons.call_outlined),
                            label: Text(context.localPhone(phone.number), textDirection: TextDirection.ltr),
                            onPressed: () => ContactLauncher.call(phone.number),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (text(visit.diagnosis) != null) LabeledValue(label: l10n.diagnosis, value: visit.diagnosis!),
              if (text(visit.chiefComplaint) != null) LabeledValue(label: l10n.chiefComplaint, value: visit.chiefComplaint!),
              if (text(visit.findings) != null) LabeledValue(label: l10n.findings, value: visit.findings!),
              if (!vitals.isEmpty) ...[
                Text(l10n.vitals, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (vitals.bpSys != null && vitals.bpDia != null)
                      _VitalChip(label: l10n.vitalBloodPressure, value: '${vitals.bpSys}/${vitals.bpDia}'),
                    if (vitals.pulse != null) _VitalChip(label: l10n.vitalPulse, value: '${vitals.pulse}'),
                    if (vitals.tempC != null) _VitalChip(label: l10n.vitalTemperature, value: '${vitals.tempC} °C'),
                    if (vitals.weightKg != null) _VitalChip(label: l10n.vitalWeight, value: '${vitals.weightKg} kg'),
                    if (vitals.heightCm != null) _VitalChip(label: l10n.vitalHeight, value: '${vitals.heightCm} cm'),
                    if (vitals.glucose != null) _VitalChip(label: l10n.vitalGlucose, value: '${vitals.glucose} mg/dL'),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (text(visit.patientNotes) != null) LabeledValue(label: l10n.doctorNotesForYou, value: visit.patientNotes!),
              if (visit.followUpDate != null) LabeledValue(label: l10n.followUpDate, value: context.date(visit.followUpDate!)),
              if (visit.prescriptions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l10n.tabPrescriptions, style: theme.textTheme.titleMedium),
                for (final rx in visit.prescriptions) PrescriptionRow(rx: rx),
              ],
              if (visit.files.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l10n.tabFiles, style: theme.textTheme.titleMedium),
                for (final file in visit.files)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: FileThumb(recordId: file.id, cover: file.cover, size: 44),
                    title: Text(file.title),
                    subtitle: Text('${context.recordCategory(file.category)} · ${context.date(file.documentDate)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(PatientRoutes.record(file.id)),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VitalChip extends StatelessWidget {
  const _VitalChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          Text(value, style: theme.textTheme.titleSmall, textDirection: TextDirection.ltr),
        ],
      ),
    );
  }
}
