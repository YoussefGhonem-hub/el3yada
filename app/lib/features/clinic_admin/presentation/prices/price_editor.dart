import 'package:flutter/material.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../domain/price_models.dart';
import '../widgets/clinic_admin_widgets.dart';

/// The examination and consultation prices of the doctor or of one branch
/// (D37, and the D29 Clinic info tab). A branch has the «Use the doctor's
/// prices» switch; off, each empty field falls back to the doctor's price
/// for that visit type (BR-PR2). An empty price with nothing to fall back
/// to means patients see «يُرجى الاستفسار من العيادة» (BR-PR6), and the
/// field says so. Save and Discard appear while something changed.
///
/// Give it a key made of the saved prices, so a new answer from the server
/// starts it again.
class PriceEditor extends StatefulWidget {
  const PriceEditor({
    super.key,
    required this.saved,
    required this.onSave,
    this.doctorPrices,
    this.enabled = true,
    this.fieldPrefix = 'price',
  });

  /// The prices now: the doctor's, or the branch's own.
  final PricePair saved;

  /// Null for the doctor's prices; the doctor's for a branch.
  final PricePair? doctorPrices;
  final bool enabled;

  /// Throws `ApiException`.
  final Future<void> Function(int? examination, int? consultation) onSave;

  /// Keys for tests: `<prefix>-examination`, `<prefix>-consultation`, `<prefix>-doctor`.
  final String fieldPrefix;

  bool get isBranch => doctorPrices != null;

  @override
  State<PriceEditor> createState() => _PriceEditorState();
}

class _PriceEditorState extends State<PriceEditor> {
  late final _examination = TextEditingController(text: PriceRules.toInput(widget.saved.examinationPricePiasters));
  late final _consultation = TextEditingController(text: PriceRules.toInput(widget.saved.consultationPricePiasters));
  late bool _useDoctor = widget.isBranch && widget.saved.isEmpty;
  SubmitStatus _status = SubmitStatus.idle;
  Map<String, String> _serverErrors = const {};
  String? _error;
  bool _tried = false;

  @override
  void dispose() {
    _examination.dispose();
    _consultation.dispose();
    super.dispose();
  }

  bool get _dirty {
    if (widget.isBranch && _useDoctor) return !widget.saved.isEmpty;
    return _examination.text.trim() != PriceRules.toInput(widget.saved.examinationPricePiasters) ||
        _consultation.text.trim() != PriceRules.toInput(widget.saved.consultationPricePiasters);
  }

  void _discard() => setState(() {
        _examination.text = PriceRules.toInput(widget.saved.examinationPricePiasters);
        _consultation.text = PriceRules.toInput(widget.saved.consultationPricePiasters);
        _useDoctor = widget.isBranch && widget.saved.isEmpty;
        _serverErrors = const {};
        _error = null;
        _tried = false;
      });

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final reduced = Motion.of(context).reduced;
    setState(() {
      _tried = true;
      _serverErrors = const {};
      _error = null;
    });
    final useDoctor = widget.isBranch && _useDoctor;
    if (!useDoctor && (PriceRules.check(_examination.text) != null || PriceRules.check(_consultation.text) != null)) return;
    final examination = useDoctor ? null : PriceRules.toPiasters(_examination.text);
    final consultation = useDoctor ? null : PriceRules.toPiasters(_consultation.text);
    setState(() => _status = SubmitStatus.loading);
    try {
      await widget.onSave(examination, consultation);
      if (!mounted) return;
      setState(() => _status = SubmitStatus.success);
      showAdminSnack(context, l10n.pricesSaved);
      await Future<void>.delayed(reduced ? Duration.zero : Motion.slow);
      if (mounted) setState(() => _status = SubmitStatus.idle);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _serverErrors = error.fieldCodes;
        _error = error.fieldCodes.isEmpty ? l10n.apiError(error) : null;
      });
    }
  }

  String _money(BuildContext context, int? piasters) =>
      piasters == null ? AppLocalizations.of(context).pricesAskClinic : AppFormat.egp(context, piasters);

  String? _fieldError(String field, TextEditingController controller) {
    final l10n = AppLocalizations.of(context);
    if (_serverErrors[field] != null) return l10n.regErrorPrice;
    if ((_tried || controller.text.isNotEmpty) && PriceRules.check(controller.text) != null) return l10n.regErrorPrice;
    return null;
  }

  /// What an empty field means.
  String _emptyHint(BuildContext context, int? doctorPrice) {
    final l10n = AppLocalizations.of(context);
    if (!widget.isBranch || doctorPrice == null) return l10n.pricesEmptyAskClinic;
    return l10n.pricesEmptyUsesDoctor(AppFormat.egp(context, doctorPrice));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = _status != SubmitStatus.idle;
    final enabled = widget.enabled && !busy;
    final doctor = widget.doctorPrices;
    final showFields = !widget.isBranch || !_useDoctor;

    Widget field(String key, String label, TextEditingController controller, int? doctorPrice) => MoneyField(
          fieldKey: ValueKey('${widget.fieldPrefix}-$key'),
          controller: controller,
          label: label,
          enabled: enabled,
          hintText: widget.isBranch && doctorPrice != null ? PriceRules.toInput(doctorPrice) : null,
          onChanged: (_) => setState(() => _serverErrors = {..._serverErrors}..remove('${key}PricePiasters')),
          errorText: _fieldError('${key}PricePiasters', controller),
          helperText: controller.text.trim().isEmpty ? _emptyHint(context, doctorPrice) : null,
        );

    final fields = LayoutBuilder(
      builder: (context, constraints) {
        final exam = field('examination', l10n.regExaminationPrice, _examination, doctor?.examinationPricePiasters);
        final consult = field('consultation', l10n.regConsultationPrice, _consultation, doctor?.consultationPricePiasters);
        if (constraints.maxWidth < 280) return Column(children: [exam, const SizedBox(height: 12), consult]);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: exam), const SizedBox(width: 12), Expanded(child: consult)],
        );
      },
    );

    return ListenableBuilder(
      listenable: Listenable.merge([_examination, _consultation]),
      builder: (context, _) {
        final dirty = _dirty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isBranch)
              MergeSemantics(
                child: SwitchListTile(
                  key: ValueKey('${widget.fieldPrefix}-doctor'),
                  contentPadding: EdgeInsets.zero,
                  value: _useDoctor,
                  onChanged: enabled ? (value) => setState(() => _useDoctor = value) : null,
                  title: Text(l10n.pricesUseDoctor, style: theme.textTheme.bodyLarge),
                  subtitle: Text(
                    _useDoctor
                        ? l10n.pricesUseDoctorOn(
                            _money(context, doctor?.examinationPricePiasters),
                            _money(context, doctor?.consultationPricePiasters),
                          )
                        : l10n.pricesUseDoctorOff,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
            MotionSize(
              alignment: AlignmentDirectional.topStart,
              child: showFields
                  ? Padding(padding: EdgeInsets.only(top: widget.isBranch ? 8 : 0), child: fields)
                  : const SizedBox(width: double.infinity),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(liveRegion: true, child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error))),
              ),
            MotionSize(
              alignment: AlignmentDirectional.topEnd,
              child: dirty || _status != SubmitStatus.idle
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: busy ? null : _discard, child: Text(l10n.adminDiscard)),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 140,
                            child: SubmitButton(label: l10n.adminSave, status: _status, onPressed: _save),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        );
      },
    );
  }
}
