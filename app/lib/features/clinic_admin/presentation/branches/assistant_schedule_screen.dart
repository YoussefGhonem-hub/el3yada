import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../clinic/application/clinic_providers.dart';
import 'branch_editor_screen.dart';

/// AS17, the assistant's Schedule menu item: D29 for the current branch (the
/// top bar's picker, BR-BR3), opened on its schedule tabs. Only assistants
/// with `scheduleManage` see the item (spec 7.6); the Info, Address and
/// Contact tabs are read-only.
class AssistantScheduleScreen extends ConsumerWidget {
  const AssistantScheduleScreen({super.key, this.initialTab});

  final BranchTab? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clinic = ref.watch(clinicContextProvider);
    final branch = ref.watch(currentBranchProvider);
    if (!clinic.hasValue) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (branch == null) {
      return Scaffold(
        body: EmptyState(title: AppLocalizations.of(context).branchNoWorkBranch, message: AppLocalizations.of(context).branchNoWorkBranchBody),
      );
    }
    return BranchEditorScreen(
      key: ValueKey(branch.id),
      branchId: branch.id,
      initialTab: initialTab ?? BranchTab.hours,
      embedded: true,
    );
  }
}
