import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/platform/file_share.dart';
import '../application/patient_providers.dart';
import '../domain/patient_models.dart';
import 'patient_format.dart';
import 'patient_routes.dart';
import 'widgets/patient_widgets.dart';

/// P7 Prescription details: each medicine with dose, frequency, timing and duration in plain
/// words, or each test with its notes. View PDF, and Share (which also saves the file).
class PrescriptionDetailScreen extends ConsumerWidget {
  const PrescriptionDetailScreen({super.key, required this.prescriptionId});

  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rx = ref.watch(prescriptionDetailProvider(prescriptionId));
    return Scaffold(
      appBar: AppBar(title: Text(rx.value == null ? '' : context.prescriptionKind(rx.value!.kind))),
      body: AsyncValueView(
        value: rx,
        onRetry: () => ref.invalidate(prescriptionDetailProvider(prescriptionId)),
        data: (data) => _PrescriptionBody(rx: data),
      ),
    );
  }
}

class _PrescriptionBody extends ConsumerStatefulWidget {
  const _PrescriptionBody({required this.rx});

  final PrescriptionDetail rx;

  @override
  ConsumerState<_PrescriptionBody> createState() => _PrescriptionBodyState();
}

class _PrescriptionBodyState extends ConsumerState<_PrescriptionBody> {
  bool _sharing = false;

  Future<void> _share() async {
    final rx = widget.rx;
    setState(() => _sharing = true);
    try {
      final bytes = await ref.read(fileBytesProvider(FileRef.prescriptionPdf(rx.id)).future);
      await FileShare.share(bytes, fileName: pdfFileName(rx), mimeType: 'application/pdf');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rx = widget.rx;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rx.isCancelled)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.rxCancelledTitle, style: theme.textTheme.titleSmall?.copyWith(color: scheme.onErrorContainer)),
                      if (rx.cancelReason != null)
                        Text(l10n.reasonValue(rx.cancelReason!), style: TextStyle(color: scheme.onErrorContainer)),
                      if (rx.replacedById != null)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () => context.pushReplacement(PatientRoutes.prescription(rx.replacedById!)),
                            child: Text(l10n.rxOpenNewCopy),
                          ),
                        ),
                    ],
                  ),
                ),
              Text(context.doctorName(rx.doctor), style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                l10n.rxSentOn(context.date(rx.sentAt ?? rx.visitDay)),
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (rx.diagnosis != null && rx.diagnosis!.isNotEmpty) LabeledValue(label: l10n.diagnosis, value: rx.diagnosis!),
              for (final (index, item) in rx.medications.indexed) _MedicationCard(index: index + 1, item: item),
              for (final item in rx.investigations) _InvestigationCard(item: item),
              if (rx.advice != null && rx.advice!.isNotEmpty) ...[
                const SizedBox(height: 8),
                LabeledValue(label: l10n.rxAdvice, value: rx.advice!),
              ],
              const SizedBox(height: 16),
              if (rx.hasPdf)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(l10n.viewPdf),
                      onPressed: () => context.push(PatientRoutes.prescriptionPdf(rx.id)),
                    ),
                    OutlinedButton.icon(
                      icon: _sharing
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.ios_share),
                      label: Text(l10n.shareOrSave),
                      onPressed: _sharing ? null : _share,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String pdfFileName(PrescriptionDetail rx) {
  final d = rx.visitDay;
  final day = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return 'el3yada-${rx.kind.name}-$day.pdf';
}

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({required this.index, required this.item});

  final int index;
  final MedicationItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = context.doseParts(item);
    final name = [item.drugName, if (item.strength != null && !item.drugName.contains(item.strength!)) item.strength].join(' ');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 14, child: Text('$index', style: theme.textTheme.labelMedium)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drug names appear exactly as typed (BR-RX4), so always left-to-right.
                  Text(name, style: theme.textTheme.titleMedium, textDirection: TextDirection.ltr),
                  if (item.activeIngredient != null)
                    Text(item.activeIngredient!, style: theme.textTheme.bodySmall, textDirection: TextDirection.ltr),
                  if (parts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(parts.join(' · '), style: theme.textTheme.bodyLarge),
                  ],
                  if (item.instructions != null && item.instructions!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(item.instructions!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvestigationCard extends StatelessWidget {
  const _InvestigationCard({required this.item});

  final InvestigationItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(item.category == 'radiology' ? Icons.monitor_heart_outlined : Icons.science_outlined),
        title: Text(item.name, textDirection: TextDirection.ltr, style: theme.textTheme.titleMedium),
        subtitle: Text([context.investigationCategory(item.category), if (item.notes != null) item.notes!].join(' · ')),
      ),
    );
  }
}
