import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';

/// A white card that groups a step's fields under a [title], on the mint
/// ground (the "queue ticket" cards, radius 20).
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, this.subtitle, required this.children, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Semantics(header: true, child: Text(title, style: theme.textTheme.titleMedium))),
                ?trailing,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 16),
            for (final (index, child) in children.indexed) ...[
              if (index > 0) const SizedBox(height: 16),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

/// "Check the highlighted fields", or a message for the whole request, at the
/// top of a step. Read out when it appears.
class FormErrorBanner extends StatelessWidget {
  const FormErrorBanner({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AnimatedSize(
      duration: Motion.normal,
      curve: Motion.standardCurve,
      alignment: AlignmentDirectional.topCenter,
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(
                liveRegion: true,
                container: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        ExcludeSemantics(child: Icon(Icons.error_outline, color: scheme.onErrorContainer)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message!,
                            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// The required «أوافق على الشروط والأحكام وسياسة الخصوصية» checkbox, with
/// links to A12 under it (the same as A9's).
class TermsCheckbox extends StatefulWidget {
  const TermsCheckbox({super.key, required this.value, required this.onChanged, this.enabled = true, this.error});

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final String? error;

  @override
  State<TermsCheckbox> createState() => _TermsCheckboxState();
}

class _TermsCheckboxState extends State<TermsCheckbox> {
  late final _termsTap = TapGestureRecognizer()..onTap = () => context.push(AppRoutes.terms);
  late final _privacyTap = TapGestureRecognizer()..onTap = () => context.push(AppRoutes.privacy);

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final link = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: scheme.primary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          value: widget.value,
          onChanged: widget.enabled ? (checked) => widget.onChanged(checked ?? false) : null,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          isError: widget.error != null,
          title: Text(l10n.acceptTermsLabel),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 48),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: l10n.termsTitle, style: link, recognizer: _termsTap),
            const TextSpan(text: '   '),
            TextSpan(text: l10n.privacyTitle, style: link, recognizer: _privacyTap),
          ])),
        ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 48, top: 4),
            child: Semantics(
              liveRegion: true,
              child: Text(widget.error!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
            ),
          ),
      ],
    );
  }
}

/// Max width of A4's single-column steps and A6's columns.
const double kRegistrationFormWidth = 560;
