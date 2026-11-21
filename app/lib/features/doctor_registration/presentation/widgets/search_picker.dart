import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// A form field that opens a list to choose from (specialty, governorate):
/// it looks like a text field, shows the choice or [placeholder], and
/// carries the error like one. A button for screen readers.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.placeholder,
    this.helperText,
    this.errorText,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final String? placeholder;
  final String? helperText;
  final String? errorText;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = value == null || value!.isEmpty;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      value: empty ? placeholder : value,
      hint: errorText ?? helperText,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          isEmpty: empty,
          decoration: InputDecoration(
            labelText: label,
            hintText: placeholder,
            // The field never takes focus, so float the label to show the placeholder.
            floatingLabelBehavior: placeholder == null ? null : FloatingLabelBehavior.always,
            helperText: helperText,
            helperMaxLines: 3,
            errorText: errorText,
            errorMaxLines: 3,
            enabled: enabled,
            prefixIcon: icon == null ? null : Icon(icon),
            suffixIcon: const Icon(Icons.expand_more),
          ),
          child: empty ? null : Text(value!, style: theme.textTheme.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

/// One choice in [showSearchPicker].
class PickerOption<T> {
  const PickerOption({required this.value, required this.title, this.subtitle, required this.matches});

  final T value;
  final String title;

  /// The name in the other language, so either can be read and searched.
  final String? subtitle;
  final bool Function(String query) matches;
}

/// A searchable list: a bottom sheet on phones, a dialog on wider screens.
/// Returns the chosen value, or null when dismissed.
Future<T?> showSearchPicker<T>({
  required BuildContext context,
  required String title,
  required List<PickerOption<T>> options,
  T? selected,
}) {
  final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
  final sheet = _SearchPicker<T>(title: title, options: options, selected: selected, dialog: wide);
  if (wide) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620), child: sheet),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => FractionallySizedBox(heightFactor: 0.85, child: sheet),
  );
}

class _SearchPicker<T> extends StatefulWidget {
  const _SearchPicker({required this.title, required this.options, required this.dialog, this.selected});

  final String title;
  final List<PickerOption<T>> options;
  final T? selected;
  final bool dialog;

  @override
  State<_SearchPicker<T>> createState() => _SearchPickerState<T>();
}

class _SearchPickerState<T> extends State<_SearchPicker<T>> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = [for (final option in widget.options) if (option.matches(_query.text)) option];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, widget.dialog ? 20 : 0, 20, 12),
          child: Semantics(header: true, child: Text(widget.title, style: theme.textTheme.titleLarge)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _query,
            autofocus: widget.dialog,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l10n.regSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.regClearSearch,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_query.clear),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.normal,
            reverseDuration: Motion.normalExit,
            switchInCurve: Motion.enterCurve,
            switchOutCurve: Motion.exitCurveReversed,
            child: visible.isEmpty
                ? Padding(
                    key: const ValueKey('empty'),
                    padding: const EdgeInsets.all(24),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.regNoResults,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : ListView.builder(
                    key: const ValueKey('list'),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final option = visible[index];
                      final chosen = option.value == widget.selected;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        minTileHeight: 56,
                        selected: chosen,
                        title: Text(option.title),
                        subtitle: option.subtitle == null || option.subtitle == option.title
                            ? null
                            : Text(option.subtitle!, style: TextStyle(color: scheme.onSurfaceVariant)),
                        trailing: chosen ? Icon(Icons.check_circle, color: scheme.primary) : null,
                        onTap: () => Navigator.of(context).pop(option.value),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
