import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_error_text.dart';
import '../../../../core/theme/motion.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../patients/presentation/widgets/clinic_ui.dart';
import '../../domain/session_models.dart';
import '../../domain/session_rules.dart';

/// The typed vitals of D8 and D9.
class VitalsControllers {
  final texts = {for (final field in VitalField.values) field: TextEditingController()};

  void fill(Vitals vitals) {
    for (final MapEntry(:key, :value) in vitalsTexts(vitals).entries) {
      texts[key]!.text = value;
    }
  }

  Map<VitalField, String> get values => {for (final MapEntry(:key, :value) in texts.entries) key: value.text};

  bool get isEmpty => texts.values.every((c) => c.text.trim().isEmpty);

  Listenable get listenable => Listenable.merge(texts.values.toList());

  void dispose() {
    for (final controller in texts.values) {
      controller.dispose();
    }
  }
}

String vitalLabel(AppLocalizations l10n, VitalField field) => switch (field) {
      VitalField.bpSys => l10n.sessionVitalBpSys,
      VitalField.bpDia => l10n.sessionVitalBpDia,
      VitalField.pulse => l10n.sessionVitalPulse,
      VitalField.tempC => l10n.sessionVitalTemp,
      VitalField.weightKg => l10n.sessionVitalWeight,
      VitalField.heightCm => l10n.sessionVitalHeight,
      VitalField.glucose => l10n.sessionVitalGlucose,
    };

/// Units are the same in both languages and read left to right.
String vitalUnit(VitalField field) => switch (field) {
      VitalField.bpSys || VitalField.bpDia => 'mmHg',
      VitalField.pulse => 'bpm',
      VitalField.tempC => '°C',
      VitalField.weightKg => 'kg',
      VitalField.heightCm => 'cm',
      VitalField.glucose => 'mg/dL',
    };

/// Vitals in a collapsible section (D8 step 2, D9). Unusual values warn
/// (spec 11: «القيمة غير معتادة، تأكد منها»); values the API refuses, and
/// half a blood pressure, show as errors.
class VitalsSection extends StatefulWidget {
  const VitalsSection({
    super.key,
    required this.controllers,
    this.enabled = true,
    this.initiallyOpen = false,
    this.serverErrors = const {},
  });

  final VitalsControllers controllers;
  final bool enabled;
  final bool initiallyOpen;

  /// `vitals.bpSys` … from the API.
  final Map<String, String> serverErrors;

  @override
  State<VitalsSection> createState() => _VitalsSectionState();
}

class _VitalsSectionState extends State<VitalsSection> {
  late bool _open = widget.initiallyOpen || !widget.controllers.isEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduced = Motion.of(context).reduced;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Semantics(
              expanded: _open,
              button: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.monitor_heart_outlined, size: 20, color: scheme.onPrimaryContainer),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.sessionVitals, style: theme.textTheme.titleMedium),
                          ListenableBuilder(
                            listenable: widget.controllers.listenable,
                            builder: (context, _) => Text(
                              widget.controllers.isEmpty ? l10n.sessionVitalsHint : _summary(l10n),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: reduced ? Duration.zero : Motion.normal,
                      curve: Motion.standardCurve,
                      child: const Icon(Icons.expand_more),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SmoothSize(
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: ListenableBuilder(
                      listenable: widget.controllers.listenable,
                      builder: (context, _) => _fields(context),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _summary(AppLocalizations l10n) {
    final values = widget.controllers.values;
    final parts = <String>[];
    final sys = values[VitalField.bpSys]!.trim();
    final dia = values[VitalField.bpDia]!.trim();
    if (sys.isNotEmpty || dia.isNotEmpty) parts.add('$sys/$dia');
    for (final field in [VitalField.pulse, VitalField.tempC, VitalField.weightKg, VitalField.heightCm, VitalField.glucose]) {
      final value = values[field]!.trim();
      if (value.isNotEmpty) parts.add('$value ${vitalUnit(field)}');
    }
    return parts.join('   ');
  }

  Widget _fields(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final read = readVitals(widget.controllers.values);
    String? errorFor(VitalField field) {
      final server = widget.serverErrors['vitals.${field.name}'];
      if (server != null) return l10n.fieldError(server) ?? l10n.adminErrorInvalidValue;
      switch (read.problems[field]) {
        case VitalProblem.invalid:
          return l10n.adminErrorInvalidValue;
        case VitalProblem.outOfRange:
          return l10n.adminErrorOutOfRange;
        case VitalProblem.unusual || null:
          break;
      }
      // Half a blood pressure: ask for the other half.
      final pressure = field == VitalField.bpSys || field == VitalField.bpDia;
      if (pressure && read.bpIncomplete && widget.controllers.texts[field]!.text.trim().isEmpty) return l10n.sessionVitalBpPair;
      return null;
    }

    String? warningFor(VitalField field) => read.problems[field] == VitalProblem.unusual ? l10n.sessionVitalUnusual : null;

    Widget field(VitalField f) {
      final decimals = f.decimals > 0;
      return TextField(
        controller: widget.controllers.texts[f],
        enabled: widget.enabled,
        keyboardType: TextInputType.numberWithOptions(decimal: decimals),
        textDirection: TextDirection.ltr,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(decimals ? r'[0-9٠-٩.,٫]' : '[0-9٠-٩]')),
          LengthLimitingTextInputFormatter(6),
        ],
        decoration: InputDecoration(
          labelText: vitalLabel(l10n, f),
          suffixText: vitalUnit(f),
          errorText: errorFor(f),
          helperText: warningFor(f),
          helperStyle: TextStyle(color: Theme.of(context).colorScheme.tertiary),
          isDense: true,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.sessionVitalBp, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: field(VitalField.bpSys)),
            const SizedBox(width: 12),
            Expanded(child: field(VitalField.bpDia)),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minColumnWidth: 150,
          spacing: 12,
          runSpacing: 16,
          children: [
            for (final f in [VitalField.pulse, VitalField.tempC, VitalField.weightKg, VitalField.heightCm, VitalField.glucose]) field(f),
          ],
        ),
      ],
    );
  }
}

/// Read-only vitals (D9), only those recorded.
class VitalsView extends StatelessWidget {
  const VitalsView({super.key, required this.vitals});

  final Vitals vitals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final entries = <(String, String)>[
      if (vitals.bpSys != null && vitals.bpDia != null) (l10n.sessionVitalBp, '${vitals.bpSys}/${vitals.bpDia} mmHg'),
      for (final (field, value) in [
        (VitalField.pulse, vitals.pulse),
        (VitalField.tempC, vitals.tempC),
        (VitalField.weightKg, vitals.weightKg),
        (VitalField.heightCm, vitals.heightCm),
        (VitalField.glucose, vitals.glucose),
      ])
        if (value != null) (vitalLabel(l10n, field), '${field.text(value)} ${vitalUnit(field)}'),
    ];
    if (entries.isEmpty) {
      return Text(l10n.sessionNoVitals, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (label, value) in entries)
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(value, textDirection: TextDirection.ltr, style: theme.textTheme.titleMedium),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
