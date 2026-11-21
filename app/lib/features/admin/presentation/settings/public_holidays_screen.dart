import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/navigation/app_back_button.dart';
import '../../../../core/widgets/staggered_entrance.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../admin_routes.dart';
import '../../data/public_holidays_repository.dart';
import '../widgets/admin_widgets.dart';

/// AD13's public holidays [C] (BR-AP13), from a month ago on.
final publicHolidaysProvider = FutureProvider.autoDispose<List<PublicHoliday>>(
  (ref) => ref.watch(publicHolidaysRepositoryProvider).list(),
);

/// AD13 [C]: the Egyptian public holidays the admin keeps. Clinics see the
/// coming ones as suggestions in D29's Special dates, and close a branch on
/// one only if they choose (a closure, through the conflicts check). One
/// holiday a date.
class PublicHolidaysScreen extends ConsumerWidget {
  const PublicHolidaysScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final added = await showDialog<PublicHoliday>(context: context, builder: (context) => const _HolidayDialog());
    if (added == null || !context.mounted) return;
    ref.invalidate(publicHolidaysProvider);
    showAdminSnack(context, AppLocalizations.of(context).holidayAdded);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, PublicHoliday holiday) async {
    final l10n = AppLocalizations.of(context);
    final name = holiday.name(Localizations.localeOf(context).languageCode);
    final confirmed = await confirmAction(
      context,
      title: l10n.holidayDeleteTitle(name),
      message: l10n.holidayDeleteBody,
      confirmLabel: l10n.remove,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(publicHolidaysRepositoryProvider).delete(holiday.id);
      ref.invalidate(publicHolidaysProvider);
    } on ApiException catch (error) {
      if (context.mounted) showAdminSnack(context, l10n.apiError(error), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final holidays = ref.watch(publicHolidaysProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: Text(l10n.holidayAdd),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = adminGutter(constraints.maxWidth);
          return ListView(
            padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 96 + MediaQuery.paddingOf(context).bottom),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: StaggerGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StaggeredEntrance(
                          index: 0,
                          child: AdminHeader(
                            leading: const AppBackButton(fallback: AdminRoutes.settings),
                            title: l10n.holidaysTitle,
                            subtitle: l10n.holidaysAdminBody,
                          ),
                        ),
                        const SizedBox(height: 16),
                        switch (holidays) {
                          AsyncValue(:final value?, hasValue: true) when value.isEmpty =>
                            EmptyState(title: l10n.holidaysEmpty, message: l10n.holidaysEmptyBody),
                          AsyncValue(:final value?, hasValue: true) => Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  for (final (i, h) in value.indexed) ...[
                                    if (i > 0) const Divider(height: 1),
                                    StaggeredEntrance(
                                      index: i + 1,
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: h.date.isBefore(today) ? scheme.surfaceContainerHigh : scheme.primaryContainer,
                                          foregroundColor: h.date.isBefore(today) ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
                                          child: Text('${h.date.day}'),
                                        ),
                                        title: Text(h.name(language)),
                                        subtitle: Text(
                                          '${DateFormat.yMMMMEEEEd(language).format(h.date)}${l10n.regListSeparator}${h.name(language == 'ar' ? 'en' : 'ar')}',
                                        ),
                                        trailing: IconButton(
                                          tooltip: l10n.remove,
                                          onPressed: () => _delete(context, ref, h),
                                          icon: const Icon(Icons.delete_outline),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          AsyncValue(:final error?, hasError: true) =>
                            AdminErrorView(error: error, onRetry: () => ref.invalidate(publicHolidaysProvider)),
                          _ => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                        },
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A date and its name in both languages.
class _HolidayDialog extends ConsumerStatefulWidget {
  const _HolidayDialog();

  @override
  ConsumerState<_HolidayDialog> createState() => _HolidayDialogState();
}

class _HolidayDialogState extends ConsumerState<_HolidayDialog> {
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  DateTime? _date;
  bool _tried = false;
  bool _saving = false;
  Map<String, String> _server = const {};
  String? _error;

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      firstDate: today.subtract(const Duration(days: 31)),
      lastDate: today.add(const Duration(days: 730)),
      initialDate: _date ?? today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  String? _fieldError(AppLocalizations l10n, String field, TextEditingController controller) {
    if (_server[field] case final code?) return l10n.fieldError(code) ?? l10n.adminErrorInvalidValue;
    if (!_tried) return null;
    final text = controller.text.trim();
    if (text.isEmpty) return l10n.errorRequired;
    if (text.length > 100) return l10n.adminErrorMaxLength('100');
    return null;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _tried = true;
      _server = const {};
      _error = null;
    });
    final nameAr = _nameAr.text.trim();
    final nameEn = _nameEn.text.trim();
    if (_date == null || nameAr.isEmpty || nameEn.isEmpty || nameAr.length > 100 || nameEn.length > 100) return;
    setState(() => _saving = true);
    try {
      final created = await ref.read(publicHolidaysRepositoryProvider).create(date: _date!, nameAr: nameAr, nameEn: nameEn);
      if (mounted) Navigator.pop(context, created);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _server = error.fieldCodes;
        _error = error.code == publicHolidayExists ? l10n.holidayExists : (error.fieldCodes.isEmpty ? l10n.apiError(error) : null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final missingDate = _tried && _date == null;
    return AlertDialog(
      icon: const Icon(Icons.celebration_outlined),
      title: Text(l10n.holidayAdd),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(_date == null ? l10n.holidayDate : DateFormat.yMMMMEEEEd(language).format(_date!)),
              ),
              if (missingDate)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(l10n.errorRequired, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameAr,
                enabled: !_saving,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(labelText: l10n.holidayNameAr, errorText: _fieldError(l10n, 'nameAr', _nameAr)),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameEn,
                enabled: !_saving,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l10n.holidayNameEn, errorText: _fieldError(l10n, 'nameEn', _nameEn)),
                onChanged: (_) => setState(() {}),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(liveRegion: true, child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error))),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: Text(l10n.adminCancel)),
        FilledButton(onPressed: _saving ? null : _save, child: Text(l10n.holidayAdd)),
      ],
    );
  }
}
