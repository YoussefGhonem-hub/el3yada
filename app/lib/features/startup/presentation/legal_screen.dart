import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/gen/app_localizations.dart';
import '../public_settings.dart';
import '../startup.dart';

enum LegalDocument { terms, privacy }

/// A12: the Terms of use or the Privacy Policy, as the admin wrote them
/// (AD13). Plain text: paragraphs are separated by blank lines.
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(publicSettingsProvider);
    final legal = switch (document) {
      LegalDocument.terms => settings?.terms,
      LegalDocument.privacy => settings?.privacy,
    } ??
        const LegalText();
    final locale = Localizations.localeOf(context);
    final text = legal.textFor(locale.languageCode);
    final updatedAt = legal.updatedAt;

    return Scaffold(
      appBar: AppBar(title: Text(document == LegalDocument.terms ? l10n.termsTitle : l10n.privacyTitle)),
      body: SafeArea(
        child: text == null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l10n.legalEmpty)))
            : Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Center(
                    child: ConstrainedBox(
                      // About 70 characters per line for long reading.
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (updatedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                l10n.legalUpdated(DateFormat.yMMMd(locale.toLanguageTag()).format(updatedAt.toLocal())),
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          SelectableText(text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.7)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
