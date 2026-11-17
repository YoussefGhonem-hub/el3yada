import 'package:flutter/material.dart';

import '../../../../l10n/gen/app_localizations.dart';
import '../../data/local_catalog_search.dart';
import '../../domain/catalog_search.dart';
import '../catalog_text.dart';

/// Search results in the three sections of BR-CAT4, each with its heading:
/// "Used before", "Your specialty" and «من تخصصات أخرى». Empty sections
/// are left out. Used by AD19's preview; the editors (D13, D14) can use it
/// too.
class CatalogHitsView<T> extends StatelessWidget {
  const CatalogHitsView({super.key, required this.hits, this.onPick, this.dense = false});

  final CatalogHits<T> hits;
  final ValueChanged<T>? onPick;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sections = [
      (CatalogSection.usedBefore, l10n.rxSectionUsedBefore, Icons.history),
      (CatalogSection.mySpecialty, l10n.rxSectionMySpecialty, Icons.star_outline_rounded),
      (CatalogSection.others, l10n.rxSectionOthers, Icons.layers_outlined),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (section, title, icon) in sections)
          if (hits.section(section).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 12, bottom: 4, start: 4),
              child: Semantics(
                header: true,
                child: Row(
                  children: [
                    Icon(icon, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$title · ${hits.section(section).length}',
                        style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final hit in hits.section(section))
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onPick == null ? null : () => onPick!(hit),
                child: switch (hit) {
                  final DrugHit drug => CatalogDrugTile(hit: drug, dense: dense),
                  final TestHit test => CatalogTestTile(hit: test, dense: dense),
                  _ => Text('$hit'),
                },
              ),
          ],
      ],
    );
  }
}

/// A medicine: trade name as published, then ingredient · route · maker
/// (A.3.7). A product the dataset marks N/A says «قد لا يكون متوفرًا».
/// Prices are never shown (BR-CAT13).
class CatalogDrugTile extends StatelessWidget {
  const CatalogDrugTile({super.key, required this.hit, this.dense = false});

  final DrugHit hit;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unavailable = mayBeUnavailable(hit);
    final details = [
      ?hit.activeIngredient,
      if (hit.route case final route?) l10n.catalogRouteName(route),
      ?hit.manufacturer,
    ];
    return Opacity(
      opacity: unavailable ? 0.72 : 1,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: dense ? 6 : 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.medication_outlined, size: 20, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(hit.name, style: theme.textTheme.bodyLarge, textDirection: TextDirection.ltr),
                      if (hit.custom) _Tag(label: l10n.catalogCustomTag, color: scheme.tertiary),
                    ],
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  if (unavailable)
                    Text(
                      l10n.catalogMayBeUnavailable,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A lab test or radiology procedure: the LOINC name as published
/// (BR-CAT10), our Arabic name and short names, and for radiology the
/// modality and region.
class CatalogTestTile extends StatelessWidget {
  const CatalogTestTile({super.key, required this.hit, this.dense = false, this.trailing});

  final TestHit hit;
  final bool dense;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final details = [if (hit.aliases.isNotEmpty) hit.aliases.join(', '), ?hit.modality, ?hit.region, ?hit.code];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 6 : 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hit.category == 'radiology' ? Icons.settings_overscan_outlined : Icons.biotech_outlined,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(hit.name, style: theme.textTheme.bodyLarge, textDirection: TextDirection.ltr),
                    if (hit.custom) _Tag(label: l10n.catalogCustomTag, color: scheme.tertiary),
                  ],
                ),
                if (hit.nameAr != null) Text(hit.nameAr!, style: theme.textTheme.bodyMedium),
                if (details.isNotEmpty)
                  Text(
                    details.join(' · '),
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      shape: StadiumBorder(side: BorderSide(color: color)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
    ),
  );
}
