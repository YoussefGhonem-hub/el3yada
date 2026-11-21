import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../application/registration_form.dart';
import '../registration_text.dart';
import '../widgets/form_parts.dart';

/// One A4 step. Each step reads and writes [form] (shared by all four, so
/// nothing is lost going back) and rebuilds when it changes.
abstract class RegistrationStep extends ConsumerStatefulWidget {
  const RegistrationStep({super.key, required this.form, this.enabled = true, this.banner});

  final RegistrationForm form;

  /// False while submitting.
  final bool enabled;

  /// A message for the top of the step (see [FormErrorBanner]).
  final String? banner;
}

/// Rebuilds on form changes and, when the form asks
/// ([RegistrationForm.pendingReveal]), scrolls the first field with an
/// error into view. Wrap each field in [anchor] so it can be found.
abstract class RegistrationStepState<T extends RegistrationStep> extends ConsumerState<T> {
  final _anchors = <String, GlobalKey>{};

  RegistrationForm get form => widget.form;

  /// The step's field keys in visual order.
  List<String> get fieldOrder;

  @override
  void initState() {
    super.initState();
    form.addListener(_onFormChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.form != widget.form) {
      oldWidget.form.removeListener(_onFormChanged);
      widget.form.addListener(_onFormChanged);
    }
  }

  @override
  void dispose() {
    form.removeListener(_onFormChanged);
    super.dispose();
  }

  void _onFormChanged() {
    if (!mounted) return;
    setState(() {});
    if (form.pendingReveal) WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  void _reveal() {
    if (!mounted || !form.pendingReveal) return;
    for (final key in fieldOrder) {
      if (form.errorOf(key) == null) continue;
      final target = _anchors[key]?.currentContext;
      if (target == null) continue;
      form.pendingReveal = false;
      Scrollable.ensureVisible(
        target,
        alignment: 0.15,
        duration: Motion.of(context).reduced ? Duration.zero : Motion.normal,
        curve: Motion.standardCurve,
      );
      return;
    }
  }

  /// Marks [child] as the place of the field [key] for [_reveal].
  Widget anchor(String key, Widget child) => KeyedSubtree(key: _anchors.putIfAbsent(key, GlobalKey.new), child: child);

  /// The ARB message for the field's current error, or null.
  String? errorText(String key) {
    final code = form.errorOf(key);
    return code == null ? null : AppLocalizations.of(context).regFieldError(key, code);
  }

  /// A text field bound to [controller], showing the error of [key].
  Widget textField(
    String key,
    TextEditingController controller, {
    required String label,
    String? hint,
    String? helper,
    IconData? icon,
    TextInputType? keyboardType,
    TextInputAction action = TextInputAction.next,
    bool ltr = false,
    bool obscure = false,
    Widget? suffix,
    String? suffixText,
    Iterable<String>? autofill,
    TextCapitalization capitalization = TextCapitalization.none,
    int? maxLength,
    ValueChanged<String>? onSubmitted,
    bool multiline = false,
  }) =>
      anchor(
        key,
        TextField(
          controller: controller,
          enabled: widget.enabled,
          keyboardType: multiline ? TextInputType.multiline : keyboardType,
          textInputAction: multiline ? TextInputAction.newline : action,
          minLines: multiline ? 2 : null,
          maxLines: multiline ? 4 : 1,
          textDirection: ltr ? TextDirection.ltr : null,
          obscureText: obscure,
          autocorrect: !obscure && !ltr,
          enableSuggestions: !obscure && !ltr,
          autofillHints: autofill,
          textCapitalization: capitalization,
          maxLength: maxLength,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintMaxLines: multiline ? 2 : null,
            alignLabelWithHint: multiline,
            hintTextDirection: ltr ? TextDirection.ltr : null,
            helperText: helper,
            helperMaxLines: 3,
            errorText: errorText(key),
            errorMaxLines: 3,
            prefixIcon: icon == null ? null : Icon(icon),
            suffixIcon: suffix,
            suffixText: suffixText,
          ),
        ),
      );

  /// The step's page: the banner, then [children], centred at most
  /// [maxWidth] wide and scrolling.
  Widget stepBody({required List<Widget> children, double maxWidth = kRegistrationFormWidth}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormErrorBanner(message: widget.banner),
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const SizedBox(height: 12),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
