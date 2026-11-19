import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/patient_providers.dart';
import 'patient_format.dart';
import 'patient_routes.dart';
import 'widgets/patient_widgets.dart';

/// P2 My doctors: one card per linked doctor → P3. Chat arrives with Phase 5 (P12).
class MyDoctorsScreen extends ConsumerWidget {
  const MyDoctorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final doctors = ref.watch(myDoctorsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myDoctorsTitle)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myDoctorsProvider.future),
        child: AsyncValueView(
          value: doctors,
          onRetry: () => ref.invalidate(myDoctorsProvider),
          data: (list) => list.isEmpty
              ? ListView(children: [EmptyState(icon: Icons.badge_outlined, message: l10n.noDoctors)])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final theme = Theme.of(context);
                    return ContentWidth(
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const CircleAvatar(child: Icon(Icons.medical_services_outlined)),
                          title: Text(context.doctorName(item.doctor), style: theme.textTheme.titleMedium),
                          subtitle: Text([
                            item.doctor.displayTitle(arabic: context.isArabic),
                            item.specialty.displayName(arabic: context.isArabic),
                            if (item.defaultBranch != null) context.branchName(item.defaultBranch!),
                          ].join(' · ')),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.newCounts.total > 0) const NewBadge(),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => context.push(PatientRoutes.doctor(item.doctor.id)),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
