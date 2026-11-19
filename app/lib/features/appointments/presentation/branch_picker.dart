import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../patient/presentation/patient_format.dart';
import '../application/appointment_providers.dart';

/// BR-BR3: the current branch. Hidden when the caller works in one branch only.
class BranchPicker extends ConsumerWidget {
  const BranchPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(staffBranchesProvider).value ?? const [];
    final current = ref.watch(currentBranchProvider);
    if (branches.length < 2) {
      final only = branches.firstOrNull;
      return only == null ? const SizedBox.shrink() : Chip(avatar: const Icon(Icons.store_mall_directory_outlined, size: 18),
          label: Text(only.displayName(arabic: context.isArabic)));
    }
    return DropdownButton<String>(
      value: branches.any((b) => b.id == current) ? current : null,
      hint: Text(context.l10n.branchesTitle),
      underline: const SizedBox.shrink(),
      items: [
        for (final b in branches) DropdownMenuItem(value: b.id, child: Text(b.displayName(arabic: context.isArabic))),
      ],
      onChanged: (id) {
        if (id != null) ref.read(currentBranchProvider.notifier).select(id);
      },
    );
  }
}
