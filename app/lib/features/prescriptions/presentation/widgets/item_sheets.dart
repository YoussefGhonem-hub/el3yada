import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/search/search_normalizer.dart' show parseStrength;
import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../catalog/application/catalog_search_provider.dart';
import '../../../catalog/data/local_catalog_search.dart' show mayBeUnavailable;
import '../../../catalog/presentation/catalog_text.dart';
import '../../../catalog/domain/catalog_search.dart';
import '../../domain/prescription_models.dart';
import '../../pdf/rx_text.dart';

/// Opens [child] as a bottom sheet on phones and a dialog on wide screens.
Future<T?> showRxItemSheet<T>(BuildContext context, Widget child) {
  final wide = MediaQuery.sizeOf(context).width >= 720;
  if (wide) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760), child: child),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(heightFactor: 0.94, child: child),
  );
}

/// D13 "Add medicine": search (BR-CAT4–CAT8) and the BR-RX fields.
class MedicationItemSheet extends ConsumerStatefulWidget {
  const MedicationItemSheet({super.key, this.initial});

  /// Editing an item already on the prescription.
  final MedicationItem? initial;

  @override
  ConsumerState<MedicationItemSheet> createState() => _MedicationItemSheetState();
}

class _MedicationItemSheetState extends ConsumerState<MedicationItemSheet> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _ingredient = TextEditingController();
  final _strength = TextEditingController();
  final _formText = TextEditingController();
  final _dose = TextEditingController();
  final _frequency = TextEditingController();
  final _durationCount = TextEditingController();
  final _durationText = TextEditingController();
  final _instructions = TextEditingController();
  String? _catalogId;
  String? _form;
  MedicationTiming _timing = MedicationTiming.unspecified;
  RxDurationUnit? _durationUnit;
  bool _mySpecialtyOnly = false;
  bool _picked = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    if (item != null) {
      _picked = true;
      _name.text = item.drugName;
      _ingredient.text = item.activeIngredient ?? '';
      _strength.text = item.strength ?? '';
      _catalogId = item.catalogId;
      if (DrugForms.isKnown(item.form)) {
        _form = item.form;
      } else if (item.form != null) {
        _form = DrugForms.other;
        _formText.text = item.form!;
      }
      _dose.text = item.dose ?? '';
      _frequency.text = item.frequency ?? '';
      _timing = item.timing;
      _instructions.text = item.instructions ?? '';
      _durationText.text = item.duration ?? '';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // An existing duration written by the app is read back into its parts.
    final duration = widget.initial?.duration;
    if (duration != null && _durationUnit == null && _durationCount.text.isEmpty) {
      final parts = parseRxDuration(duration);
      if (parts != null) {
        _durationUnit = parts.unit;
        if (parts.unit != RxDurationUnit.continuous) _durationCount.text = '${parts.count}';
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _search, _name, _ingredient, _strength, _formText, _dose, _frequency, _durationCount, _durationText, _instructions,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// BR-CAT7: the name, ingredient and catalog ID, with the form and the
  /// strength suggested; everything stays editable.
  void _pick(DrugHit hit) {
    setState(() {
      _picked = true;
      _name.text = hit.name;
      _catalogId = hit.catalogId;
      _ingredient.text = hit.activeIngredient ?? '';
      final strength = hit.strengthHint ?? parseStrength(hit.name);
      if (strength != null) _strength.text = strength;
      if (DrugForms.isKnown(hit.formHint)) _form = hit.formHint;
    });
  }

  /// BR-CAT8: a name that isn't in the catalog.
  void _typeFree(String text) => setState(() {
        _picked = true;
        _name.text = text.trim();
        _catalogId = null;
        // "Augmentin 1 GM" typed: the strength is suggested all the same.
        if (_strength.text.trim().isEmpty) _strength.text = parseStrength(text) ?? '';
      });

  String? _duration(AppLocalizations l10n) {
    final unit = _durationUnit;
    if (unit == RxDurationUnit.continuous) return l10n.rxDurationContinuous;
    final count = int.tryParse(_durationCount.text.trim());
    if (unit != null && count != null && count > 0) return rxDurationText(l10n, unit, count);
    final typed = _durationText.text.trim();
    return typed.isEmpty ? null : typed;
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = l10n.errorRequired);
      return;
    }
    final form = _form == DrugForms.other && _formText.text.trim().isNotEmpty ? _formText.text.trim() : _form;
    Navigator.of(context).pop(MedicationItem(
      drugName: _name.text.trim(),
      activeIngredient: _value(_ingredient),
      catalogId: _catalogId,
      form: form,
      strength: _value(_strength),
      dose: _value(_dose),
      frequency: _value(_frequency),
      timing: _timing,
      duration: _duration(l10n),
      instructions: _value(_instructions),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(widget.initial == null ? l10n.rxAddMedicine : l10n.rxEditMedicine, style: theme.textTheme.titleLarge),
              ),
              IconButton(tooltip: l10n.adminClose, onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              CatalogSearchBox<DrugHit>(
                controller: _search,
                label: l10n.rxSearchMedicine,
                mySpecialtyOnly: _mySpecialtyOnly,
                onMySpecialtyOnly: (value) => setState(() => _mySpecialtyOnly = value),
                search: (query, mySpecialtyOnly) =>
                    ref.read(catalogSearchProvider).drugs(query, mySpecialtyOnly: mySpecialtyOnly),
                tileOf: (hit) => _DrugHitTile(hit: hit),
                keyOf: (hit) => hit.catalogId ?? hit.name,
                onPick: _pick,
                onTypeFree: _typeFree,
                collapsed: _picked,
              ),
              AnimatedSwitcher(
                duration: Motion.normal,
                switchInCurve: Motion.enterCurve,
                switchOutCurve: Motion.exitCurveReversed,
                child: !_picked
                    ? const SizedBox(key: ValueKey('empty'))
                    : Column(
                        key: const ValueKey('fields'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          TextField(
                            controller: _name,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(labelText: l10n.rxDrugName, errorText: _nameError),
                            maxLength: 200,
                            onChanged: (_) => setState(() {
                              _nameError = null;
                              _catalogId = null;
                            }),
                          ),
                          TextField(
                            controller: _ingredient,
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(labelText: l10n.rxActiveIngredient),
                            maxLength: 300,
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _strength,
                                  textDirection: TextDirection.ltr,
                                  decoration: InputDecoration(labelText: l10n.rxStrength, hintText: '500 mg'),
                                  maxLength: 40,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _form,
                                  isExpanded: true,
                                  decoration: InputDecoration(labelText: l10n.rxForm),
                                  items: [
                                    for (final form in DrugForms.all)
                                      DropdownMenuItem(value: form, child: Text(rxFormName(l10n, form))),
                                  ],
                                  onChanged: (value) => setState(() => _form = value),
                                ),
                              ),
                            ],
                          ),
                          if (_form == DrugForms.other)
                            TextField(
                              controller: _formText,
                              decoration: InputDecoration(labelText: l10n.rxFormOtherText),
                              maxLength: 40,
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _dose,
                                  decoration: InputDecoration(labelText: l10n.rxDose, hintText: l10n.rxDoseHint),
                                  maxLength: 60,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _frequency,
                                  decoration: InputDecoration(labelText: l10n.rxFrequency, hintText: l10n.rxFrequencyHint),
                                  maxLength: 60,
                                ),
                              ),
                            ],
                          ),
                          Text(l10n.rxTiming, style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final timing in MedicationTiming.values)
                                ChoiceChip(
                                  label: Text(rxTimingName(l10n, timing)),
                                  selected: _timing == timing,
                                  onSelected: (_) => setState(() => _timing = timing),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(l10n.rxDuration, style: theme.textTheme.labelLarge),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (_durationUnit != RxDurationUnit.continuous)
                                SizedBox(
                                  width: 96,
                                  child: TextField(
                                    controller: _durationCount,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: l10n.rxDurationCount, isDense: true),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              for (final unit in RxDurationUnit.values)
                                ChoiceChip(
                                  label: Text(switch (unit) {
                                    RxDurationUnit.days => l10n.rxDurationUnitDays,
                                    RxDurationUnit.weeks => l10n.rxDurationUnitWeeks,
                                    RxDurationUnit.continuous => l10n.rxDurationContinuous,
                                  }),
                                  selected: _durationUnit == unit,
                                  onSelected: (selected) => setState(() {
                                    _durationUnit = selected ? unit : null;
                                    _durationText.clear();
                                  }),
                                ),
                            ],
                          ),
                          if (_durationUnit == null && _durationText.text.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: _durationText,
                              decoration: InputDecoration(labelText: l10n.rxDuration),
                              maxLength: 60,
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextField(
                            controller: _instructions,
                            minLines: 1,
                            maxLines: 3,
                            maxLength: 300,
                            decoration: InputDecoration(labelText: l10n.rxInstructions),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        _SheetActions(enabled: _picked, label: widget.initial == null ? l10n.rxAddToPrescription : l10n.adminSave, onSave: _save),
      ],
    );
  }
}

/// D14: one lab test or scan.
class InvestigationItemSheet extends ConsumerStatefulWidget {
  const InvestigationItemSheet({super.key, this.initial, this.category = InvestigationCategory.lab});

  final InvestigationItem? initial;
  final InvestigationCategory category;

  @override
  ConsumerState<InvestigationItemSheet> createState() => _InvestigationItemSheetState();
}

class _InvestigationItemSheetState extends ConsumerState<InvestigationItemSheet> {
  final _search = TextEditingController();
  final _name = TextEditingController();
  final _notes = TextEditingController();
  late InvestigationCategory _category = widget.initial?.category ?? widget.category;
  String? _code;
  bool _mySpecialtyOnly = false;
  bool _picked = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    if (item != null) {
      _picked = true;
      _name.text = item.name;
      _notes.text = item.notes ?? '';
      _code = item.loincCode;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _pick(TestHit hit) => setState(() {
        _picked = true;
        _name.text = hit.name;
        _code = hit.code;
        _category = InvestigationCategory.fromWire(hit.category);
      });

  void _typeFree(String text) => setState(() {
        _picked = true;
        _name.text = text.trim();
        _code = null;
      });

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = AppLocalizations.of(context).errorRequired);
      return;
    }
    Navigator.of(context).pop(InvestigationItem(category: _category, name: _name.text.trim(), loincCode: _code, notes: _value(_notes)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(widget.initial == null ? l10n.rxAddTest : l10n.rxEditTest, style: theme.textTheme.titleLarge),
              ),
              IconButton(tooltip: l10n.adminClose, onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              SegmentedButton<InvestigationCategory>(
                segments: [
                  ButtonSegment(value: InvestigationCategory.lab, icon: const Icon(Icons.science_outlined), label: Text(l10n.rxCategoryLab)),
                  ButtonSegment(
                    value: InvestigationCategory.radiology,
                    icon: const Icon(Icons.settings_overscan_outlined),
                    label: Text(l10n.rxCategoryRadiology),
                  ),
                ],
                selected: {_category},
                onSelectionChanged: (value) => setState(() => _category = value.first),
              ),
              const SizedBox(height: 16),
              CatalogSearchBox<TestHit>(
                key: ValueKey(_category),
                controller: _search,
                label: _category == InvestigationCategory.lab ? l10n.rxSearchLab : l10n.rxSearchRadiology,
                mySpecialtyOnly: _mySpecialtyOnly,
                onMySpecialtyOnly: (value) => setState(() => _mySpecialtyOnly = value),
                search: (query, mySpecialtyOnly) => ref
                    .read(catalogSearchProvider)
                    .tests(query, category: _category.wire, mySpecialtyOnly: mySpecialtyOnly),
                tileOf: (hit) => _TestHitTile(hit: hit),
                keyOf: (hit) => hit.code ?? hit.name,
                onPick: _pick,
                onTypeFree: _typeFree,
                collapsed: _picked,
              ),
              if (_picked) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  decoration: InputDecoration(labelText: l10n.rxTestName, errorText: _nameError),
                  maxLength: 200,
                  onChanged: (_) => setState(() {
                    _nameError = null;
                    _code = null;
                  }),
                ),
                TextField(
                  controller: _notes,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 300,
                  decoration: InputDecoration(labelText: l10n.rxTestNotes, hintText: l10n.rxTestNotesHint),
                ),
              ],
            ],
          ),
        ),
        _SheetActions(enabled: _picked, label: widget.initial == null ? l10n.rxAddToPrescription : l10n.adminSave, onSave: _save),
      ],
    );
  }
}

/// A field's text, or null when it's blank.
String? _value(TextEditingController controller) {
  final text = controller.text.trim();
  return text.isEmpty ? null : text;
}

class _SheetActions extends StatelessWidget {
  const _SheetActions({required this.enabled, required this.label, required this.onSave});

  final bool enabled;
  final String label;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.adminCancel)),
            const SizedBox(width: 8),
            FilledButton(onPressed: enabled ? onSave : null, child: Text(label)),
          ],
        ),
      ),
    );
  }
}

/// The search box with the three BR-CAT4 sections, the «تخصصي فقط» chip and
/// "use what I typed" (BR-CAT8).
class CatalogSearchBox<T> extends StatefulWidget {
  const CatalogSearchBox({
    super.key,
    required this.controller,
    required this.label,
    required this.mySpecialtyOnly,
    required this.onMySpecialtyOnly,
    required this.search,
    required this.tileOf,
    required this.keyOf,
    required this.onPick,
    required this.onTypeFree,
    this.collapsed = false,
  });

  final TextEditingController controller;
  final String label;
  final bool mySpecialtyOnly;
  final ValueChanged<bool> onMySpecialtyOnly;
  final Future<CatalogHits<T>> Function(String query, bool mySpecialtyOnly) search;
  final Widget Function(T hit) tileOf;
  final Object Function(T hit) keyOf;
  final ValueChanged<T> onPick;
  final ValueChanged<String> onTypeFree;

  /// After a pick the results fold away until the doctor types again.
  final bool collapsed;

  @override
  State<CatalogSearchBox<T>> createState() => _CatalogSearchBoxState<T>();
}

class _CatalogSearchBoxState<T> extends State<CatalogSearchBox<T>> {
  Timer? _debounce;
  CatalogHits<T>? _hits;
  bool _loading = false;
  bool _showResults = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _showResults = !widget.collapsed;
    _run();
  }

  @override
  void didUpdateWidget(CatalogSearchBox<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mySpecialtyOnly != widget.mySpecialtyOnly) _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _changed(String _) {
    setState(() => _showResults = true);
    _debounce?.cancel();
    _debounce = Timer(Motion.fast, _run);
  }

  Future<void> _run() async {
    final request = ++_request;
    setState(() => _loading = true);
    final hits = await widget.search(widget.controller.text, widget.mySpecialtyOnly);
    if (!mounted || request != _request) return;
    setState(() {
      _hits = hits;
      _loading = false;
    });
  }

  void _pick(T hit) {
    setState(() => _showResults = false);
    widget.onPick(hit);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hits = _hits;
    final typed = widget.controller.text.trim();
    final sections = [
      (CatalogSection.usedBefore, l10n.rxSectionUsedBefore),
      (CatalogSection.mySpecialty, l10n.rxSectionMySpecialty),
      (CatalogSection.others, l10n.rxSectionOthers),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          autofocus: !widget.collapsed,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _loading
                ? const Padding(padding: EdgeInsets.all(14), child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                : null,
          ),
          onChanged: _changed,
          onSubmitted: (text) {
            if (text.trim().isNotEmpty) {
              setState(() => _showResults = false);
              widget.onTypeFree(text);
            }
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilterChip(
            label: Text(l10n.rxMySpecialtyOnly),
            selected: widget.mySpecialtyOnly,
            onSelected: widget.onMySpecialtyOnly,
          ),
        ),
        if (hits != null && !hits.catalogReady)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(Icons.cloud_download_outlined, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.rxCatalogNotReady, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        AnimatedSize(
          duration: Motion.normal,
          curve: Motion.standardCurve,
          alignment: AlignmentDirectional.topStart,
          child: !_showResults || hits == null
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (section, title) in sections)
                      if (hits.section(section).isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 4),
                          child: Text(title, style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
                        ),
                        for (final hit in hits.section(section))
                          InkWell(
                            key: ValueKey(('hit', section, widget.keyOf(hit))),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _pick(hit),
                            child: widget.tileOf(hit),
                          ),
                      ],
                    if (typed.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.edit_outlined),
                          title: Text(l10n.rxUseTyped(typed)),
                          subtitle: hits.isEmpty ? Text(l10n.rxNoMatches) : null,
                          onTap: () {
                            setState(() => _showResults = false);
                            widget.onTypeFree(typed);
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DrugHitTile extends StatelessWidget {
  const _DrugHitTile({required this.hit});

  final DrugHit hit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final details = [?hit.activeIngredient, if (hit.route case final route?) l10n.catalogRouteName(route), ?hit.manufacturer, if (hit.strengthHint != null && hit.activeIngredient == null) hit.strengthHint!];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          const Icon(Icons.medication_outlined, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hit.name, style: theme.textTheme.bodyLarge, textDirection: TextDirection.ltr),
                if (hit.nameAr != null) Text(hit.nameAr!, style: theme.textTheme.bodySmall),
                if (details.isNotEmpty)
                  Text(
                    details.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                // The drug dataset marks it N/A: it comes last, muted (catalog feature).
                if (mayBeUnavailable(hit))
                  Text(
                    l10n.catalogMayBeUnavailable,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TestHitTile extends StatelessWidget {
  const _TestHitTile({required this.hit});

  final TestHit hit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = [
      if (hit.aliases.isNotEmpty) hit.aliases.join(', '),
      ?hit.modality,
      ?hit.region,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Icon(hit.category == 'radiology' ? Icons.settings_overscan_outlined : Icons.science_outlined, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hit.name, style: theme.textTheme.bodyLarge),
                if (hit.nameAr != null) Text(hit.nameAr!, style: theme.textTheme.bodySmall),
                if (details.isNotEmpty)
                  Text(
                    details.join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
