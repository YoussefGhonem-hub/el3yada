import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/patient_providers.dart';
import '../domain/patient_models.dart';
import 'patient_format.dart';
import 'patient_routes.dart';
import 'terms_gate.dart';
import 'widgets/patient_widgets.dart';

/// P1 Home: greeting, doctor selector, and cards for the latest visit, latest prescription,
/// next follow-up and recent files. The next-appointment card arrives with Phase 6 (P15–P17)
/// and unread messages with Phase 5 (P12).
class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorId = ref.watch(selectedDoctorProvider);
    final home = ref.watch(patientHomeProvider(doctorId));

    Future<void> refresh() {
      ref.invalidate(myDoctorsProvider);
      return ref.refresh(patientHomeProvider(doctorId).future);
    }

    return TermsGate(
      child: RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: ContentWidth(child: DoctorSelector())),
            SliverToBoxAdapter(
              child: ContentWidth(
                child: AsyncValueView(
                  value: home,
                  onRetry: () => ref.invalidate(patientHomeProvider(doctorId)),
                  data: (data) => _HomeCards(home: data),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCards extends ConsumerWidget {
  const _HomeCards({required this.home});

  final PatientHome home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final seen = ref.watch(seenItemsProvider);
    final doctors = ref.watch(myDoctorsProvider).value ?? const <MyDoctor>[];
    final firstName = home.fullName.split(' ').first;

    final visit = home.latestVisit;
    final rx = home.latestPrescription;
    final followUp = home.nextFollowUp;

    final cards = <Widget>[
      if (visit != null)
        SectionCard(
          title: l10n.homeLatestVisit,
          icon: Icons.medical_services_outlined,
          trailing: visit.isNew && !seen.visits.contains(visit.id) ? const NewBadge() : null,
          onTap: () => context.push(PatientRoutes.visit(visit.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                VisitTypeBadge(type: visit.type),
                const SizedBox(width: 8),
                Expanded(child: Text(context.date(visit.at), style: theme.textTheme.bodyMedium)),
              ]),
              const SizedBox(height: 8),
              Text(context.doctorName(visit.doctor), style: theme.textTheme.bodyMedium),
              if (visit.diagnosisSnippet != null) ...[
                const SizedBox(height: 4),
                Text(visit.diagnosisSnippet!, style: theme.textTheme.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
      if (rx != null)
        SectionCard(
          title: l10n.homeLatestPrescription,
          icon: Icons.receipt_long_outlined,
          trailing: rx.isNew && !seen.prescriptions.contains(rx.id) ? const NewBadge() : null,
          onTap: () => context.push(PatientRoutes.prescription(rx.id)),
          child: Text(
            '${context.prescriptionKind(rx.kind)} · ${context.doctorName(rx.doctor)} · ${context.date(rx.sentAt ?? DateTime.now())}',
            style: theme.textTheme.bodyMedium?.copyWith(
              decoration: rx.isCancelled ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      if (followUp != null)
        SectionCard(
          title: l10n.homeNextFollowUp,
          icon: Icons.event_repeat_outlined,
          onTap: () => context.push(PatientRoutes.visit(followUp.sessionId)),
          child: Text(
            l10n.followUpWith(context.date(followUp.date), context.doctorName(followUp.doctor)),
            style: theme.textTheme.bodyLarge,
          ),
        ),
      if (home.recentFiles.isNotEmpty)
        SectionCard(
          title: l10n.homeRecentFiles,
          icon: Icons.folder_open_outlined,
          trailing: TextButton(
            onPressed: () => context.go(PatientRoutes.file(tab: MedicalFileTab.files)),
            child: Text(l10n.seeAll),
          ),
          child: Row(
            children: [
              for (final file in home.recentFiles)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.push(PatientRoutes.record(file.id)),
                    child: Semantics(
                      label: file.title,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          FileThumb(recordId: file.id, cover: file.cover, size: 72),
                          if (file.isNew && !seen.files.contains(file.id))
                            const PositionedDirectional(top: -6, end: -6, child: NewBadge()),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.homeGreeting(firstName), style: theme.textTheme.headlineSmall),
          if (home.newCounts.total > 0) ...[
            const SizedBox(height: 4),
            Text(l10n.homeNewItems(home.newCounts.total), style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary)),
          ],
          const SizedBox(height: 16),
          if (cards.isEmpty)
            EmptyState(icon: Icons.folder_shared_outlined, message: l10n.homeEmpty)
          else
            for (final card in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: card),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.badge_outlined, size: 18),
                label: Text(doctors.length > 1 ? l10n.myDoctorsTitle : l10n.myDoctorTitle),
                onPressed: () => doctors.length == 1
                    ? context.push(PatientRoutes.doctor(doctors.single.doctor.id))
                    : context.push(PatientRoutes.doctors),
              ),
              ActionChip(
                avatar: const Icon(Icons.health_and_safety_outlined, size: 18),
                label: Text(l10n.medicalProfileTitle),
                onPressed: () => context.push(PatientRoutes.medicalProfile),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
