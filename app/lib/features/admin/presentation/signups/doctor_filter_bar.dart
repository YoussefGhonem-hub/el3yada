import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../doctor_registration/application/registration_providers.dart';
import '../../../doctor_registration/domain/reference_lists.dart';
import '../../../doctor_registration/domain/specialty.dart';
import '../../../doctor_registration/presentation/widgets/search_picker.dart';
import '../../domain/admin_models.dart';
import '../widgets/admin_widgets.dart';

// AD2's filters by specialty, governorate and sign-up date (the API's
// `specialtyId`, `governorate`, `from` and `to`). The specialty and the
// governorate open A4's searchable list; the dates open the date range
// picker, in Cairo days.

/// The specialty picker; null when dismissed.
Future<DoctorListFilter?> pickSpecialtyFilter(BuildContext context, WidgetRef ref, DoctorListFilter filter) async {
  final l10n = AppLocalizations.of(context);
  final language = Localizations.localeOf(context).languageCode;
  final List<Specialty> specialties;
  try {
    specialties = await ref.read(specialtiesProvider.future);
  } catch (error) {
    ref.invalidate(specialtiesProvider);
    if (context.mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    return null;
  }
  if (!context.mounted) return null;
  final picked = await showSearchPicker<String>(
    context: context,
    title: l10n.adminFilterSpecialty,
    selected: filter.specialty?.id,
    options: [
      for (final specialty in specialties)
        PickerOption(
          value: specialty.id,
          title: specialty.name(language),
          subtitle: specialty.name(language == 'ar' ? 'en' : 'ar'),
          matches: specialty.matches,
        ),
    ],
  );
  if (picked == null) return null;
  final chosen = specialties.firstWhere((s) => s.id == picked);
  return filter.withSpecialty(SpecialtyRef(id: chosen.id, nameAr: chosen.nameAr, nameEn: chosen.nameEn));
}

/// The governorate picker; null when dismissed.
Future<DoctorListFilter?> pickGovernorateFilter(BuildContext context, DoctorListFilter filter) async {
  final l10n = AppLocalizations.of(context);
  final language = Localizations.localeOf(context).languageCode;
  final picked = await showSearchPicker<String>(
    context: context,
    title: l10n.adminFilterGovernorate,
    selected: filter.governorate,
    options: [
      for (final governorate in Governorates.all)
        PickerOption(
          value: governorate.ar,
          title: governorate.of(language),
          subtitle: governorate.of(language == 'ar' ? 'en' : 'ar'),
          matches: (query) => matchesNames(query, [governorate.ar, governorate.en]),
        ),
    ],
  );
  return picked == null ? null : filter.withGovernorate(picked);
}

/// The sign-up date range (Cairo days); null when dismissed.
Future<DoctorListFilter?> pickSignupDates(BuildContext context, DoctorListFilter filter) async {
  final now = AppFormat.cairo(DateTime.now());
  final today = DateTime(now.year, now.month, now.day);
  final from = filter.from == null ? null : AppFormat.cairo(filter.from!);
  final to = filter.to == null ? null : AppFormat.cairo(filter.to!.subtract(const Duration(hours: 1)));
  final picked = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2025),
    lastDate: today,
    initialDateRange: from == null || to == null
        ? null
        : DateTimeRange(start: DateTime(from.year, from.month, from.day), end: DateTime(to.year, to.month, to.day)),
  );
  if (picked == null) return null;
  final end = DateTime(picked.end.year, picked.end.month, picked.end.day + 1);
  return filter.withDates(AppFormat.cairoDayStartUtc(picked.start), AppFormat.cairoDayStartUtc(end));
}

/// The names the filters show.
extension DoctorFilterText on DoctorListFilter {
  String? governorateName(String language) => governorate == null
      ? null
      : Governorates.all.where((g) => g.ar == governorate).firstOrNull?.of(language) ?? governorate;

  String? datesText(AppLocalizations l10n, String language) {
    if (from == null || to == null) return null;
    final format = DateFormat.MMMd(language);
    final start = format.format(AppFormat.cairo(from!));
    final end = format.format(AppFormat.cairo(to!.subtract(const Duration(hours: 1))));
    return start == end ? start : l10n.adminDateRange(start, end);
  }

  int get count => [specialty, governorate, from].where((value) => value != null).length;
}

/// The filters that are set, as pills under AD2's trial chips: tap one to
/// change it, its × to clear it; "Clear filters" resets them. Scrolls
/// sideways on narrow screens.
class DoctorFilterBar extends ConsumerWidget {
  const DoctorFilterBar({super.key, required this.filter, required this.gutter, required this.onChanged});

  final DoctorListFilter filter;
  final double gutter;
  final ValueChanged<DoctorListFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final governorate = filter.governorateName(language);
    final dates = filter.datesText(l10n, language);
    Future<void> apply(Future<DoctorListFilter?> picked) async {
      final next = await picked;
      if (next != null) onChanged(next);
    }

    final pills = [
      if (filter.specialty != null)
        _FilterPill(
          icon: Icons.medical_services_outlined,
          label: filter.specialty!.name(language),
          onTap: () => apply(pickSpecialtyFilter(context, ref, filter)),
          onClear: () => onChanged(filter.withSpecialty(null)),
        ),
      if (governorate != null)
        _FilterPill(
          icon: Icons.place_outlined,
          label: governorate,
          onTap: () => apply(pickGovernorateFilter(context, filter)),
          onClear: () => onChanged(filter.withGovernorate(null)),
        ),
      if (dates != null)
        _FilterPill(
          icon: Icons.date_range_outlined,
          label: l10n.adminFilterSignedUp(dates),
          onTap: () => apply(pickSignupDates(context, filter)),
          onClear: () => onChanged(filter.withDates(null, null)),
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Row(
        children: [
          for (final pill in pills) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: pill),
          TextButton(onPressed: () => onChanged(const DoctorListFilter()), child: Text(l10n.adminClearFilters)),
        ],
      ),
    );
  }
}

/// A set filter: tap to change it, × to clear it.
class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.icon, required this.label, required this.onTap, required this.onClear});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = scheme.onSecondaryContainer;
    return DecoratedBox(
      decoration: ShapeDecoration(color: scheme.secondaryContainer, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pressable(
            onTap: onTap,
            semanticLabel: label,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: foreground),
                  const SizedBox(width: 6),
                  Text(label, style: theme.textTheme.labelLarge?.copyWith(color: foreground)),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.adminClearFilter,
            visualDensity: VisualDensity.compact,
            onPressed: onClear,
            icon: Icon(Icons.close, size: 18, color: foreground),
          ),
        ],
      ),
    );
  }
}

/// The Filters button by AD2's search: opens the three filters (a bottom
/// sheet on phones, a dialog on wider screens), with a count of those set.
/// Each choice applies at once, so the list behind updates.
class DoctorFiltersButton extends ConsumerWidget {
  const DoctorFiltersButton({super.key, required this.filter, required this.onChanged});

  final DoctorListFilter filter;
  final ValueChanged<DoctorListFilter> onChanged;

  Future<void> _open(BuildContext context) {
    final sheet = _FiltersSheet(filter: filter, onChanged: onChanged);
    if (MediaQuery.sizeOf(context).width >= Breakpoints.tablet) {
      return showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: sheet),
        ),
      );
    }
    return showModalBottomSheet<void>(context: context, showDragHandle: true, useSafeArea: true, builder: (context) => sheet);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final count = filter.count;
    return IconButton(
      tooltip: count == 0 ? l10n.adminFilters : l10n.adminFiltersSet(count),
      onPressed: () => _open(context),
      isSelected: count > 0,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.tune),
      ),
    );
  }
}

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet({required this.filter, required this.onChanged});

  final DoctorListFilter filter;
  final ValueChanged<DoctorListFilter> onChanged;

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  late DoctorListFilter _filter = widget.filter;

  Future<void> _apply(Future<DoctorListFilter?> picked) async {
    final next = await picked;
    if (next == null || !mounted) return;
    _set(next);
  }

  void _set(DoctorListFilter next) {
    setState(() => _filter = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    Widget row({
      required IconData icon,
      required String label,
      required String? value,
      required VoidCallback onTap,
      required VoidCallback onClear,
    }) =>
        ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: AnimatedSwitcher(
            duration: Motion.fast,
            reverseDuration: Motion.fastExit,
            child: Text(value ?? l10n.adminFilterAny, key: ValueKey(value)),
          ),
          onTap: onTap,
          trailing: value == null
              ? const Icon(Icons.chevron_right)
              : IconButton(tooltip: l10n.adminClearFilter, onPressed: onClear, icon: const Icon(Icons.close)),
        );

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Semantics(header: true, child: Text(l10n.adminFilters, style: theme.textTheme.titleLarge)),
          ),
          row(
            icon: Icons.medical_services_outlined,
            label: l10n.adminFilterSpecialty,
            value: _filter.specialty?.name(language),
            onTap: () => _apply(pickSpecialtyFilter(context, ref, _filter)),
            onClear: () => _set(_filter.withSpecialty(null)),
          ),
          row(
            icon: Icons.place_outlined,
            label: l10n.adminFilterGovernorate,
            value: _filter.governorateName(language),
            onTap: () => _apply(pickGovernorateFilter(context, _filter)),
            onClear: () => _set(_filter.withGovernorate(null)),
          ),
          row(
            icon: Icons.date_range_outlined,
            label: l10n.adminFilterSignupDate,
            value: _filter.datesText(l10n, language),
            onTap: () => _apply(pickSignupDates(context, _filter)),
            onClear: () => _set(_filter.withDates(null, null)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _filter.isEmpty ? null : () => _set(const DoctorListFilter()),
                  child: Text(l10n.adminClearFilters),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.adminFiltersDone)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
