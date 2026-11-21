import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/admin_catalog_providers.dart';
import '../../application/catalog_providers.dart';
import '../../domain/catalog_models.dart';
import '../catalog_text.dart';

/// AD20: add or edit a custom item (BR-CAT9): a medicine, a lab test or a
/// radiology procedure. Doctors see it within a minute. Returns the saved
/// item, or null when cancelled.
Future<CustomCatalogItem?> showCustomItemDialog(
  BuildContext context, {
  CustomCatalogItem? item,
  CatalogItemType? type,
}) => showDialog<CustomCatalogItem>(
  context: context,
  builder: (context) => _CustomItemDialog(item: item, type: type ?? CatalogItemType.drug),
);

class _CustomItemDialog extends ConsumerStatefulWidget {
  const _CustomItemDialog({this.item, required this.type});

  final CustomCatalogItem? item;
  final CatalogItemType type;

  @override
  ConsumerState<_CustomItemDialog> createState() => _CustomItemDialogState();
}

class _CustomItemDialogState extends ConsumerState<_CustomItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late CatalogItemType _type = widget.item?.type ?? widget.type;
  late final _nameEn = TextEditingController(text: widget.item?.nameEn);
  late final _nameAr = TextEditingController(text: widget.item?.nameAr);
  late final _ingredient = TextEditingController(text: widget.item?.activeIngredient);
  late final _group = TextEditingController(text: widget.item?.drugGroupId);
  late final _code = TextEditingController(text: widget.item?.loincCode);
  late final _aliases = TextEditingController(text: widget.item?.aliases.join(', '));
  late String? _route = widget.item?.route;
  late bool _active = widget.item?.active ?? true;
  SubmitStatus _status = SubmitStatus.idle;
  Map<String, String> _fieldErrors = const {};
  String? _error;

  bool get _editing => widget.item != null;

  static const _routes = [
    'ORAL.SOLID',
    'ORAL.LIQUID',
    'INJECTION',
    'TOPICAL',
    'EFF',
    'RECTAL',
    'EYE',
    'EAR',
    'SPRAY',
    'VAGINAL',
    'MOUTH',
  ];

  @override
  void dispose() {
    for (final controller in [_nameEn, _nameAr, _ingredient, _group, _code, _aliases]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _fieldErrors = const {};
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _status = SubmitStatus.loading);
    final draft = CustomItemDraft(
      type: _type,
      nameEn: _nameEn.text,
      nameAr: _nameAr.text,
      activeIngredient: _ingredient.text,
      drugGroupId: _group.text,
      route: _route,
      loincCode: _code.text,
      aliases: _aliases.text.split(RegExp('[,،]')),
      active: _active,
    );
    final repository = ref.read(adminCatalogRepositoryProvider);
    try {
      final saved = _editing
          ? await repository.updateCustomItem(widget.item!.customItemId, draft)
          : await repository.createCustomItem(draft);
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _fieldErrors = error.fieldCodes;
        _error = error.fieldCodes.isEmpty ? l10n.apiError(error) : null;
      });
      _formKey.currentState?.validate();
    }
  }

  String? _server(String field) {
    final l10n = AppLocalizations.of(context);
    final code = _fieldErrors[field];
    return code == null ? null : (l10n.fieldError(code) ?? l10n.errorUnknown);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = _status != SubmitStatus.idle;
    final drug = _type == CatalogItemType.drug;
    final groups = ref.watch(catalogChoicesProvider).value?.groups ?? const [];
    final language = Localizations.localeOf(context).languageCode;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    _editing ? l10n.adminCatalogEditItem : l10n.adminCatalogAddItem,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.adminCatalogItemBody,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                if (!_editing) ...[
                  SegmentedButton<CatalogItemType>(
                    segments: [
                      for (final type in CatalogItemType.values)
                        ButtonSegment(
                          value: type,
                          label: Text(l10n.catalogTypeName(type)),
                          icon: Icon(catalogTypeIcon(type)),
                        ),
                    ],
                    selected: {_type},
                    onSelectionChanged: busy ? null : (value) => setState(() => _type = value.first),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _nameEn,
                  enabled: !busy,
                  autofocus: !_editing,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: drug ? l10n.adminCatalogFieldTradeName : l10n.adminCatalogFieldTestName,
                    helperText: drug ? l10n.adminCatalogFieldTradeNameHint : null,
                  ),
                  validator: (value) {
                    final server = _server('nameEn');
                    if (server != null) return server;
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return l10n.errorRequired;
                    if (text.length > 200) return l10n.errorTooLong;
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nameAr,
                  enabled: !busy,
                  decoration: InputDecoration(labelText: l10n.adminCatalogFieldNameAr),
                  validator: (value) =>
                      _server('nameAr') ?? ((value ?? '').trim().length > 200 ? l10n.errorTooLong : null),
                ),
                const SizedBox(height: 14),
                if (drug) ...[
                  TextFormField(
                    controller: _ingredient,
                    enabled: !busy,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: l10n.adminCatalogFieldIngredient),
                    validator: (value) => _server('activeIngredient'),
                  ),
                  const SizedBox(height: 14),
                  if (groups.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: groups.any((g) => g.value == _group.text) ? _group.text : null,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.adminCatalogFieldGroup),
                      items: [
                        for (final group in groups)
                          DropdownMenuItem(
                            value: group.value,
                            child: Text(group.label(language), overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: busy ? null : (value) => _group.text = value ?? '',
                    )
                  else
                    TextFormField(
                      controller: _group,
                      enabled: !busy,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: l10n.adminCatalogFieldGroup,
                        helperText: 'antibiotics, analgesics …',
                      ),
                      validator: (value) => _server('drugGroupId'),
                    ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _routes.contains(_route) ? _route : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.adminCatalogFieldRoute),
                    items: [
                      for (final route in _routes)
                        DropdownMenuItem(value: route, child: Text(l10n.catalogRouteName(route))),
                    ],
                    onChanged: busy ? null : (value) => setState(() => _route = value),
                  ),
                ] else
                  TextFormField(
                    controller: _code,
                    enabled: !busy,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: l10n.adminCatalogFieldCode,
                      helperText: l10n.adminCatalogFieldCodeHint,
                    ),
                    validator: (value) =>
                        _server('loincCode') ?? ((value ?? '').trim().length > 20 ? l10n.errorTooLong : null),
                  ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _aliases,
                  enabled: !busy,
                  decoration: InputDecoration(
                    labelText: l10n.adminCatalogFieldAliases,
                    helperText: l10n.adminCatalogFieldAliasesHint,
                  ),
                  validator: (value) {
                    final server = _server('aliases');
                    if (server != null) return server;
                    final aliases = (value ?? '').split(RegExp('[,،]')).where((a) => a.trim().isNotEmpty).toList();
                    if (aliases.length > 10 || aliases.any((a) => a.trim().length > 100)) {
                      return l10n.adminCatalogAliasesTooMany;
                    }
                    return null;
                  },
                ),
                if (_editing) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _active,
                    onChanged: busy ? null : (value) => setState(() => _active = value),
                    title: Text(l10n.adminCatalogItemActive),
                    subtitle: Text(l10n.adminCatalogItemActiveHint),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    child: Text(_error!, style: TextStyle(color: scheme.error)),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: busy ? null : () => Navigator.of(context).pop(),
                      child: Text(l10n.adminCancel),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 150,
                      child: SubmitButton(label: l10n.adminCatalogSave, status: _status, onPressed: _save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
