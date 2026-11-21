import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error_text.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/shake_on_error.dart';
import '../../../core/widgets/submit_button.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../data/catalog_report_repository.dart';
import '../domain/catalog_models.dart';
import 'catalog_text.dart';

/// "Report a missing or wrong item" [S] (BR-CAT8), from D13's and D14's
/// search: what is wrong, in the doctor's words, sent to the admins (AD20's
/// doctor reports). A bottom sheet on phones, a dialog on wide screens.
/// [itemRef] says which item (`drug:…`, `loinc:…`, `search:…`); [itemName]
/// is shown with it. Returns true when sent.
Future<bool> showCatalogReportSheet(
  BuildContext context, {
  required CatalogReportType type,
  String text = '',
  String? itemRef,
  String? itemName,
}) async {
  final form = _ReportForm(type: type, text: text, itemRef: itemRef, itemName: itemName);
  final bool? sent;
  if (MediaQuery.sizeOf(context).width >= 720) {
    sent = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: form),
      ),
    );
  } else {
    sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Padding(
        // Above the keyboard.
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: form,
      ),
    );
  }
  if (sent == true && context.mounted) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).catalogReportSent),
        behavior: SnackBarBehavior.floating,
      ));
  }
  return sent ?? false;
}

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm({required this.type, required this.text, this.itemRef, this.itemName});

  final CatalogReportType type;
  final String text;
  final String? itemRef;
  final String? itemName;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  static const _maxText = 500;

  late CatalogReportType _type = widget.type;
  late final _text = TextEditingController(text: widget.text);
  SubmitStatus _status = SubmitStatus.idle;
  String? _error;
  int _failures = 0;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_status != SubmitStatus.idle) return;
    final l10n = AppLocalizations.of(context);
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() {
        _error = l10n.catalogReportErrorText;
        _failures++;
      });
      return;
    }
    setState(() {
      _status = SubmitStatus.loading;
      _error = null;
    });
    try {
      await ref.read(catalogReportRepositoryProvider).report(type: _type, text: text, itemRef: widget.itemRef);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _error = error.fieldCodes['text'] == null ? l10n.apiError(error) : l10n.catalogReportErrorText;
        _failures++;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _status = SubmitStatus.success);
    if (!Motion.of(context).reduced) await Future<void>.delayed(Motion.normal);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = _status != SubmitStatus.idle;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: ShakeOnError(
          trigger: _failures == 0 ? null : _failures,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_outlined, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(header: true, child: Text(l10n.catalogReportTitle, style: theme.textTheme.titleLarge)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(l10n.catalogReportIntro, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
              if (widget.itemName != null) ...[
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(l10n.catalogReportAbout(widget.itemName!), style: theme.textTheme.bodyMedium),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(l10n.catalogReportType, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in CatalogReportType.values)
                    ChoiceChip(
                      label: Text(l10n.catalogReportTypeName(type)),
                      selected: _type == type,
                      onSelected: busy ? null : (_) => setState(() => _type = type),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _text,
                enabled: !busy,
                autofocus: true,
                minLines: 2,
                maxLines: 5,
                maxLength: _maxText,
                textInputAction: TextInputAction.newline,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  labelText: l10n.catalogReportText,
                  hintText: l10n.catalogReportTextHint,
                  hintMaxLines: 2,
                  alignLabelWithHint: true,
                  errorText: _error,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: busy ? null : () => Navigator.of(context).pop(false), child: Text(l10n.adminCancel)),
                  const SizedBox(width: 8),
                  SubmitButton(label: l10n.catalogReportSend, status: _status, onPressed: _send),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
