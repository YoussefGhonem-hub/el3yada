import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/patient_providers.dart';
import '../domain/patient_models.dart';
import 'patient_format.dart';
import 'widgets/patient_widgets.dart';

/// P10 Medical profile: personal info, then each doctor's profile (allergies in red).
/// Read-only: "To update this information, contact your doctor".
class MedicalProfileScreen extends ConsumerWidget {
  const MedicalProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(medicalProfileProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.medicalProfileTitle)),
      body: AsyncValueView(
        value: profile,
        onRetry: () => ref.invalidate(medicalProfileProvider),
        data: (data) => _ProfileBody(profile: data),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});

  final MedicalProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final personal = profile.personal;
    final age = personal.ageOn(DateTime.now());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                title: l10n.personalInfo,
                icon: Icons.person_outline,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabeledValue(label: l10n.fullName, value: personal.fullName),
                    LabeledValue(label: l10n.mobileNumber, value: context.localPhone(personal.phone)),
                    LabeledValue(label: l10n.gender, value: context.gender(personal.gender)),
                    LabeledValue(label: l10n.age, value: l10n.ageYears(age)),
                    if (personal.bloodType != null) LabeledValue(label: l10n.bloodType, value: personal.bloodType!),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final doctor in profile.doctors) ...[
                _DoctorProfileCard(profile: doctor),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(l10n.medicalProfileReadOnly,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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

class _DoctorProfileCard extends StatelessWidget {
  const _DoctorProfileCard({required this.profile});

  final DoctorMedicalProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.el3yadaColors;
    final theme = Theme.of(context);

    return SectionCard(
      title: context.doctorName(profile.doctor),
      icon: Icons.medical_services_outlined,
      child: profile.isEmpty
          ? Text(l10n.medicalProfileEmpty, style: TextStyle(color: theme.colorScheme.onSurfaceVariant))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (profile.allergies.isNotEmpty)
                  // Allergies are shown in red everywhere (spec 6.1).
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: colors.allergy, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: colors.onAllergy),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.allergies, style: theme.textTheme.titleSmall?.copyWith(color: colors.onAllergy)),
                              Text(profile.allergies.join('، '), style: TextStyle(color: colors.onAllergy)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (profile.chronicDiseases.isNotEmpty)
                  LabeledValue(label: l10n.chronicDiseases, value: profile.chronicDiseases.join('\n')),
                if (profile.currentMedications.isNotEmpty)
                  LabeledValue(label: l10n.currentMedications, value: profile.currentMedications.join('\n')),
                if (profile.surgeries.isNotEmpty) LabeledValue(label: l10n.surgeries, value: profile.surgeries.join('\n')),
                if ((profile.familyHistory ?? '').isNotEmpty) LabeledValue(label: l10n.familyHistory, value: profile.familyHistory!),
                if ((profile.notes ?? '').isNotEmpty) LabeledValue(label: l10n.notes, value: profile.notes!),
              ],
            ),
    );
  }
}
