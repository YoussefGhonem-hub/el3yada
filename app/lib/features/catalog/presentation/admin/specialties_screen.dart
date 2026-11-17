import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../admin/admin_routes.dart';
import '../../../admin/presentation/widgets/admin_widgets.dart';
import '../../application/admin_catalog_providers.dart';
import '../../domain/catalog_models.dart';

/// AD19 Specialty profiles: every specialty with its number of doctors and
/// what its profile holds; General (added to every specialty that includes
/// it, BR-CAT3) first. A card opens the editor.
class SpecialtiesScreen extends ConsumerWidget {
  const SpecialtiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final specialties = ref.watch(adminSpecialtiesProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gutter = adminGutter(width);
        final columns = width >= 1180 ? 3 : (width >= 720 ? 2 : 1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 16),
              child: AdminHeader(title: l10n.navSpecialties, subtitle: l10n.specialtyProfilesSubtitle),
            ),
            Expanded(
              child: AsyncStateSwitcher<List<SpecialtySummary>>(
                value: specialties,
                loading: (context) => _Skeleton(gutter: gutter),
                error: (context, error) =>
                    AdminErrorView(error: error, onRetry: () => ref.invalidate(adminSpecialtiesProvider)),
                data: (context, specialties) => RefreshIndicator(
                  onRefresh: () => ref.refresh(adminSpecialtiesProvider.future),
                  child: StaggerGroup(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 24 + MediaQuery.paddingOf(context).bottom),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          const spacing = 12.0;
                          final tile = (box.maxWidth - spacing * (columns - 1)) / columns;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              for (final (i, specialty) in specialties.indexed)
                                SizedBox(
                                  width: specialty.isGeneral ? box.maxWidth : tile,
                                  child: StaggeredEntrance(
                                    index: i,
                                    child: _SpecialtyCard(specialty: specialty),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpecialtyCard extends StatelessWidget {
  const _SpecialtyCard({required this.specialty});

  final SpecialtySummary specialty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final counts = specialty.itemCounts;
    final radiology =
        (counts[ProfileItemType.radiologyRegion] ?? 0) +
        (counts[ProfileItemType.radiologyModality] ?? 0) +
        (counts[ProfileItemType.radiologyCode] ?? 0);
    final general = specialty.isGeneral;
    return Pressable(
      onTap: () => context.go(AdminRoutes.specialty(specialty.specialtyId)),
      semanticLabel: specialty.name(language),
      borderRadius: BorderRadius.circular(20),
      child: Card(
        margin: EdgeInsets.zero,
        color: general ? scheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: general ? scheme.primary : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  general ? Icons.public : Icons.local_hospital_outlined,
                  color: general ? scheme.onPrimary : scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(specialty.name(language), style: theme.textTheme.titleMedium),
                    Text(
                      specialty.name(language == 'ar' ? 'en' : 'ar'),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.specialtyItemsSummary(
                        counts[ProfileItemType.drugGroup] ?? 0,
                        counts[ProfileItemType.labCode] ?? 0,
                        radiology,
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (general)
                          StatusPill(label: l10n.specialtyGeneralBadge, tone: PillTone.positive, icon: Icons.public)
                        else ...[
                          StatusPill(
                            label: l10n.specialtyDoctorCount(specialty.doctorCount),
                            icon: Icons.person_outline,
                          ),
                          if (specialty.includeGeneral)
                            StatusPill(label: l10n.specialtyWithGeneral, tone: PillTone.positive),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, textDirection: Directionality.of(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) => SkeletonLoading(
    loading: true,
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: gutter),
      itemCount: 5,
      separatorBuilder: (context, _) => const SizedBox(height: 12),
      itemBuilder: (context, _) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(radius: 22),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text('--------------'), SizedBox(height: 6), Text('------------------------')],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
