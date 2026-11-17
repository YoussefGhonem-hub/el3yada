import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/staggered_entrance.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../doctor_registration/presentation/registration_text.dart' show ltrIsolate;
import '../application/catalog_providers.dart';

/// The notices the sources require, word for word (spec A.7,
/// tools/catalog-builder/README.md "Licensing checklist"). Never translated
/// or edited: LOINC licence section 10.1 asks for this exact text.
abstract final class CatalogNotices {
  static const loinc =
      'This material contains content from LOINC (http://loinc.org). LOINC is copyright © Regenstrief Institute, '
      'Inc. and the Logical Observation Identifiers Names and Codes (LOINC) Committee and is available at no cost '
      'under the license at http://loinc.org/license. LOINC® is a registered United States trademark of '
      'Regenstrief Institute, Inc.';

  static const radlex =
      'The LOINC/RSNA Radiology Playbook contains content from RadLex® (http://www.radlex.org), copyright © '
      '2005-2025, The Radiological Society of North America, Inc., available at no cost under the license at '
      'https://www.rsna.org/uploadedFiles/RSNA/Content/Informatics/RadLex_License_Agreement_and_Terms_of_Use_V2_Final.pdf.';

  static const drugs = 'Medicine data: Egyptian Drug Database by karem505 (CC0).';
}

/// About → "Data sources and licences" (BR-CAT14, A.7): the LOINC copyright
/// notice, the RSNA Radiology Playbook / RadLex attribution and the credit
/// for the Egyptian drug dataset, with the versions on this device.
class CatalogSourcesScreen extends ConsumerWidget {
  const CatalogSourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final installed = ref.watch(catalogControllerProvider.select((s) => s.installed));

    var index = 0;
    Widget enter(Widget child) => StaggeredEntrance(index: index++, child: child);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.catalogSourcesTitle)),
      body: SafeArea(
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: StaggerGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      enter(
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                          child: Text(
                            l10n.catalogSourcesIntro,
                            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                          ),
                        ),
                      ),
                      enter(
                        _SourceCard(
                          icon: Icons.medication_outlined,
                          title: l10n.catalogSourceDrugsTitle,
                          body: l10n.catalogSourceDrugsBody,
                          detail: installed?.drugSourceDate == null
                              ? null
                              : l10n.catalogSourceDrugsDate(ltrIsolate(installed!.drugSourceDate!)),
                          notice: CatalogNotices.drugs,
                        ),
                      ),
                      const SizedBox(height: 12),
                      enter(
                        _SourceCard(
                          icon: Icons.biotech_outlined,
                          title: l10n.catalogSourceLoincTitle,
                          body: l10n.catalogSourceLoincBody,
                          detail: installed?.loincRelease == null
                              ? null
                              : l10n.catalogSourceLoincRelease(ltrIsolate(installed!.loincRelease!)),
                          notice: CatalogNotices.loinc,
                        ),
                      ),
                      const SizedBox(height: 12),
                      enter(
                        _SourceCard(
                          icon: Icons.settings_overscan_outlined,
                          title: l10n.catalogSourceRadlexTitle,
                          body: l10n.catalogSourceRadlexBody,
                          notice: CatalogNotices.radlex,
                        ),
                      ),
                      const SizedBox(height: 12),
                      enter(
                        _SourceCard(
                          icon: Icons.translate,
                          title: l10n.catalogSourceOursTitle,
                          body: l10n.catalogSourceOursBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.icon, required this.title, required this.body, this.detail, this.notice});

  final IconData icon;
  final String title;
  final String body;
  final String? detail;

  /// Shown in English, left to right, as the licence requires.
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(header: true, child: Text(title, style: theme.textTheme.titleMedium)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.6)),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(detail!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            if (notice != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                child: SelectableText(
                  notice!,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.6, fontFamily: 'Alexandria'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
