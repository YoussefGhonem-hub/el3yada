import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../application/patient_providers.dart';
import 'patient_format.dart';
import 'widgets/patient_widgets.dart';

/// A patient must accept the Terms and Privacy Policy at first login (A9, P14) before
/// using the app. Shows [child] once accepted.
class TermsGate extends ConsumerStatefulWidget {
  const TermsGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TermsGate> createState() => _TermsGateState();
}

class _TermsGateState extends ConsumerState<TermsGate> {
  bool _agreed = false;
  bool _saving = false;

  Future<void> _accept() async {
    setState(() => _saving = true);
    try {
      await ref.read(patientAccountProvider.notifier).acceptTerms();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.apiErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(patientAccountProvider);
    // While the account loads, or if it fails, the app stays usable; the gate shows once we know.
    if (account.value?.acceptedTermsAt != null || !account.hasValue) return widget.child;

    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ContentWidth(
      maxWidth: 560,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.verified_user_outlined, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(l10n.termsGateTitle, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(l10n.termsGateBody, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: _agreed,
            onChanged: _saving ? null : (value) => setState(() => _agreed = value ?? false),
            title: Text(l10n.termsGateCheckbox),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _agreed && !_saving ? _accept : null,
            child: _saving
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.termsGateContinue),
          ),
        ],
      ),
    );
  }
}
