import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/app_format.dart';
import '../../../../core/network/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/save_bar.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../core/widgets/state_switcher.dart';
import '../../../../core/widgets/submit_button.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../doctor_registration/application/registration_providers.dart';
import '../../../doctor_registration/domain/reference_lists.dart';
import '../../../doctor_registration/domain/registration_rules.dart';
import '../../../doctor_registration/domain/specialty.dart';
import '../../../doctor_registration/presentation/widgets/search_picker.dart';
import '../../application/clinic_admin_controllers.dart';
import '../../clinic_admin_routes.dart';
import '../../domain/account_models.dart';
import '../settings/clinic_settings_screen.dart';
import '../widgets/clinic_admin_widgets.dart';

/// D22: the doctor's personal and professional details. Email, mobile and
/// syndicate number are read-only. A specialty change applies at once and
/// the admin is told. The prescription header comes in Phase 3. Leaving with
/// unsaved changes asks first.
class DoctorProfileScreen extends ConsumerWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(doctorProfileProvider);
    return Scaffold(
      body: AsyncStateSwitcher<DoctorProfile>(
        value: profile,
        loading: (context) => const _ProfileSkeleton(),
        error: (context, error) => Column(
          children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(padding: EdgeInsets.all(8), child: ClinicBackButton(fallback: ClinicAdminRoutes.doctorSettings)),
            ),
            Expanded(child: AdminErrorView(error: error, onRetry: () => ref.read(doctorProfileProvider.notifier).reload())),
          ],
        ),
        data: (context, profile) => _ProfileForm(profile: profile),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});

  final DoctorProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _fullNameEn = TextEditingController();
  final _titleOther = TextEditingController();
  final _titleEn = TextEditingController();
  final _degreesAr = TextEditingController();
  final _degreesEn = TextEditingController();
  late final Listenable _edits = Listenable.merge([_fullName, _fullNameEn, _titleOther, _titleEn, _degreesAr, _degreesEn]);

  late DoctorProfile _saved;
  BilingualName? _titlePreset;
  bool _otherTitle = false;
  Specialty? _specialty;
  List<Specialty> _extras = const [];
  Map<String, String> _serverErrors = const {};
  SubmitStatus _status = SubmitStatus.idle;
  String? _saveError;
  int _failures = 0;

  @override
  void initState() {
    super.initState();
    _fill(widget.profile);
  }

  @override
  void dispose() {
    for (final c in [_fullName, _fullNameEn, _titleOther, _titleEn, _degreesAr, _degreesEn]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(DoctorProfile p) {
    _saved = p;
    _fullName.text = p.fullName;
    _fullNameEn.text = p.fullNameEn ?? '';
    _titlePreset = DoctorTitles.find(p.title);
    _otherTitle = _titlePreset == null && p.title.isNotEmpty;
    _titleOther.text = _otherTitle ? p.title : '';
    _titleEn.text = p.titleEn ?? '';
    _degreesAr.text = p.degreesAr ?? '';
    _degreesEn.text = p.degreesEn ?? '';
    _specialty = p.specialty ?? Specialty(id: p.specialtyId);
    _extras = [...p.extraSpecialties];
    _serverErrors = const {};
    _saveError = null;
  }

  String get _title => _otherTitle ? _titleOther.text.trim() : (_titlePreset?.ar ?? '');

  static String? _optional(String text) => text.trim().isEmpty ? null : text.trim();

  /// The changed fields, for the save bar's count.
  List<String> get _dirty {
    final p = _saved;
    return [
      if (RegistrationRules.collapseSpaces(_fullName.text) != p.fullName) 'fullName',
      if (_optional(_fullNameEn.text) != p.fullNameEn) 'fullNameEn',
      if (_title != p.title) 'title',
      if (_optional(_titleEn.text) != p.titleEn) 'titleEn',
      if (_optional(_degreesAr.text) != p.degreesAr) 'degreesAr',
      if (_optional(_degreesEn.text) != p.degreesEn) 'degreesEn',
      if (_specialty?.id != p.specialtyId) 'specialtyId',
      if (_extras.map((s) => s.id).join(',') != p.extraSpecialtyIds.join(',')) 'extraSpecialtyIds',
    ];
  }

  bool get _specialtyChanged => _dirty.any((f) => f == 'specialtyId' || f == 'extraSpecialtyIds');

  void _discard() {
    setState(() => _fill(_saved));
    _formKey.currentState?.validate();
  }

  Future<bool> _confirmDiscard() async {
    final count = _dirty.length;
    if (count == 0) return true;
    final confirmed = await confirmDiscardChanges(context, count);
    if (confirmed) _discard();
    return confirmed;
  }

  void _clearServer(String field) {
    if (_serverErrors.containsKey(field)) setState(() => _serverErrors = {..._serverErrors}..remove(field));
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final reduced = Motion.of(context).reduced;
    setState(() {
      _serverErrors = const {};
      _saveError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false) || _title.isEmpty || _specialty == null) {
      setState(() {
        _failures++;
        _saveError = l10n.adminFixErrors;
      });
      return;
    }
    final specialtyChanged = _specialtyChanged;
    setState(() => _status = SubmitStatus.loading);
    try {
      final saved = await ref.read(doctorProfileProvider.notifier).save(DoctorProfileUpdate(
            fullName: RegistrationRules.collapseSpaces(_fullName.text),
            fullNameEn: _optional(_fullNameEn.text),
            title: _title,
            titleEn: _optional(_titleEn.text),
            degreesAr: _optional(_degreesAr.text),
            degreesEn: _optional(_degreesEn.text),
            specialtyId: _specialty!.id,
            extraSpecialtyIds: [for (final s in _extras) s.id],
          ));
      // The menu shows the account's name.
      ref.read(authControllerProvider.notifier).reloadAccount().ignore();
      if (!mounted) return;
      setState(() {
        _fill(saved);
        _status = SubmitStatus.success;
      });
      showAdminSnack(context, specialtyChanged ? l10n.profileSavedSpecialty : l10n.profileSaved);
      await Future<void>.delayed(reduced ? Duration.zero : Motion.slow);
      if (mounted) setState(() => _status = SubmitStatus.idle);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = SubmitStatus.idle;
        _serverErrors = error.fieldCodes;
        _saveError = error.fieldCodes.isEmpty ? l10n.apiError(error) : l10n.adminFixErrors;
        _failures++;
      });
      _formKey.currentState?.validate();
    }
  }

  String? _server(String field) {
    final code = _serverErrors[field];
    if (code == null) return null;
    final l10n = AppLocalizations.of(context);
    return l10n.fieldError(code) ?? l10n.adminErrorInvalidValue;
  }

  Future<Specialty?> _pickSpecialty(List<Specialty> all, {required bool primary}) {
    final l10n = AppLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final taken = {if (!primary) _specialty?.id, ..._extras.map((s) => s.id)};
    return showSearchPicker<Specialty>(
      context: context,
      title: primary ? l10n.regSpecialtyChoose : l10n.regAddSpecialty,
      selected: primary ? _specialty : null,
      options: [
        for (final s in all)
          if (primary || !taken.contains(s.id))
            PickerOption(
              value: s,
              title: s.name(language),
              subtitle: s.name(language == 'ar' ? 'en' : 'ar'),
              matches: s.matches,
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _edits,
      builder: (context, _) {
        final dirty = _dirty.length;
        final showBar = dirty > 0 || _status != SubmitStatus.idle;
        return PopScope(
          canPop: dirty == 0,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final navigator = Navigator.of(context);
            // Confirmed: leave without asking again.
            if (await _confirmDiscard() && mounted) navigator.pop();
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gutter = adminGutter(constraints.maxWidth);
              return Column(
                children: [
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: ClinicPage(
                        bottomBarVisible: showBar,
                        builder: (context, width) => _sections(context, width),
                      ),
                    ),
                  ),
                  SaveBar(
                    visible: showBar,
                    dirty: dirty,
                    status: _status,
                    error: _saveError,
                    failures: _failures,
                    gutter: gutter,
                    bottomInset: MediaQuery.paddingOf(context).bottom,
                    onDiscard: _confirmDiscard,
                    onSave: _save,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  List<Widget> _sections(BuildContext context, double width) {
    final l10n = AppLocalizations.of(context);
    final wide = width >= kAdminWideLayout;
    const gap = SizedBox(height: 16);
    final personal = _personal(context);
    final professional = _professional(context);
    final later = _prescriptionHeader(context);
    final password = SettingsGroup(
      children: [
        SettingsTile(
          icon: Icons.lock_outline,
          title: l10n.adminChangePassword,
          subtitle: l10n.adminChangePasswordBody,
          onTap: () => showChangePasswordDialog(context),
        ),
      ],
    );
    final header = AdminHeader(
      leading: const ClinicBackButton(fallback: ClinicAdminRoutes.doctorSettings),
      title: l10n.profileTitle,
      subtitle: _saved.updatedAt == null ? l10n.profileSubtitle : l10n.profileLastSaved(AppFormat.relative(context, _saved.updatedAt!)),
    );
    if (!wide) return [header, gap, personal, gap, professional, gap, later, gap, password];
    return [
      header,
      gap,
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [personal, gap, later, gap, password])),
          const SizedBox(width: 16),
          Expanded(child: professional),
        ],
      ),
    ];
  }

  Widget _personal(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final busy = _status != SubmitStatus.idle;
    final p = _saved;
    return SectionCard(
      icon: Icons.person_outline,
      title: l10n.profilePersonal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _fullName,
            enabled: !busy,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearServer('fullName'),
            decoration: InputDecoration(labelText: l10n.profileFullNameAr, helperText: l10n.regFullNameHint),
            validator: (value) {
              final server = _server('fullName');
              if (server != null) return server;
              final name = (value ?? '').trim();
              if (name.isEmpty) return l10n.errorRequired;
              if (!RegistrationRules.isFullName(name)) return l10n.adminErrorInvalidName;
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _fullNameEn,
            enabled: !busy,
            textDirection: TextDirection.ltr,
            maxLength: 60,
            onChanged: (_) => _clearServer('fullNameEn'),
            decoration: InputDecoration(labelText: l10n.adminFieldFullNameEn, counterText: ''),
            validator: (_) => _server('fullNameEn'),
          ),
          const SizedBox(height: 12),
          // Read-only: they identify the account and the license.
          DecoratedBox(
            decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l10n.profileReadOnlyNote, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ResponsiveGrid(
                    columns: 3,
                    minColumnWidth: 160,
                    runSpacing: 12,
                    children: [
                      InfoRow(
                        label: l10n.adminFieldEmail,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (p.email != null) LtrText(p.email!, style: theme.textTheme.bodyLarge),
                            if (p.email != null)
                              StatusPill(
                                label: p.emailVerified ? l10n.adminEmailVerified : l10n.adminEmailNotVerified,
                                tone: p.emailVerified ? PillTone.positive : PillTone.warning,
                              ),
                          ],
                        ),
                      ),
                      InfoRow(label: l10n.adminFieldMobile, value: p.phone == null ? null : AppFormat.phone(p.phone!), ltr: true),
                      InfoRow(label: l10n.adminFieldLicenseNumber, value: p.licenseNumber, ltr: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _professional(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final language = Localizations.localeOf(context).languageCode;
    final busy = _status != SubmitStatus.idle;
    final specialties = ref.watch(specialtiesProvider);
    final titleError = _server('title');
    return SectionCard(
      icon: Icons.medical_services_outlined,
      title: l10n.profileProfessional,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.regTitleLabel, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final title in DoctorTitles.all)
                ChoiceChip(
                  label: Text(title.of(language)),
                  selected: !_otherTitle && _titlePreset == title,
                  onSelected: busy
                      ? null
                      : (_) => setState(() {
                            final previous = _titlePreset;
                            _titlePreset = title;
                            _otherTitle = false;
                            // Keep the English title in step unless the doctor typed their own.
                            final en = _titleEn.text.trim();
                            if (en.isEmpty || en == previous?.en || DoctorTitles.find(en) != null) _titleEn.text = title.en;
                            _clearServer('title');
                          }),
                ),
              ChoiceChip(
                label: Text(l10n.regTitleOther),
                selected: _otherTitle,
                onSelected: busy ? null : (_) => setState(() => _otherTitle = true),
              ),
            ],
          ),
          MotionSize(
            alignment: AlignmentDirectional.topStart,
            child: _otherTitle
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      controller: _titleOther,
                      enabled: !busy,
                      maxLength: RegistrationRules.maxTitleLength,
                      onChanged: (_) => _clearServer('title'),
                      decoration: InputDecoration(labelText: l10n.regTitleOtherLabel),
                      validator: (value) {
                        if (titleError != null) return titleError;
                        return (value ?? '').trim().isEmpty ? l10n.regErrorTitleRequired : null;
                      },
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          if (!_otherTitle && titleError != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
              child: Text(titleError, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
            ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleEn,
            enabled: !busy,
            textDirection: TextDirection.ltr,
            maxLength: 40,
            onChanged: (_) => _clearServer('titleEn'),
            decoration: InputDecoration(labelText: l10n.adminFieldTitleEn, counterText: ''),
            validator: (_) => _server('titleEn'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _degreesAr,
            enabled: !busy,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            onChanged: (_) => _clearServer('degreesAr'),
            decoration: InputDecoration(labelText: l10n.adminFieldDegreesAr, hintText: l10n.profileDegreesHint, alignLabelWithHint: true),
            validator: (_) => _server('degreesAr'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _degreesEn,
            enabled: !busy,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            textDirection: TextDirection.ltr,
            onChanged: (_) => _clearServer('degreesEn'),
            decoration: InputDecoration(labelText: l10n.adminFieldDegreesEn, alignLabelWithHint: true),
            validator: (_) => _server('degreesEn'),
          ),
          const SizedBox(height: 12),
          PickerField(
            label: l10n.regSpecialtyLabel,
            placeholder: l10n.regSpecialtyChoose,
            value: _specialty?.name(language).isEmpty ?? true ? null : _specialty!.name(language),
            icon: Icons.local_hospital_outlined,
            helperText: l10n.regSpecialtyHint,
            errorText: _server('specialtyId') ?? (specialties.hasError ? l10n.regSpecialtiesError : null),
            enabled: !busy && specialties.hasValue,
            onTap: () async {
              final chosen = await _pickSpecialty(specialties.requireValue, primary: true);
              if (chosen == null || !mounted) return;
              setState(() {
                _specialty = chosen;
                _extras = _extras.where((s) => s.id != chosen.id).toList();
                _clearServer('specialtyId');
              });
            },
          ),
          const SizedBox(height: 16),
          Text(l10n.regExtraSpecialtiesLabel, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final extra in _extras)
                InputChip(
                  label: Text(extra.name(language)),
                  isEnabled: !busy,
                  onDeleted: () => setState(() {
                    _extras = _extras.where((s) => s.id != extra.id).toList();
                    _clearServer('extraSpecialtyIds');
                  }),
                  deleteButtonTooltipMessage: l10n.regRemoveSpecialty(extra.name(language)),
                ),
              if (_extras.length < RegistrationRules.maxExtraSpecialties)
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: Text(l10n.regAddSpecialty),
                  onPressed: busy || !specialties.hasValue
                      ? null
                      : () async {
                          final chosen = await _pickSpecialty(specialties.requireValue, primary: false);
                          if (chosen == null || !mounted) return;
                          setState(() {
                            _extras = [..._extras, chosen];
                            _clearServer('extraSpecialtyIds');
                          });
                        },
                ),
            ],
          ),
          if (_server('extraSpecialtyIds') case final error?)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
              child: Text(error, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
            ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: Motion.normal,
            reverseDuration: Motion.normalExit,
            switchInCurve: Motion.enterCurve,
            switchOutCurve: Motion.exitCurveReversed,
            child: InfoBanner(
              key: ValueKey(_specialtyChanged),
              icon: _specialtyChanged ? Icons.campaign_outlined : Icons.info_outline,
              tone: _specialtyChanged ? PillTone.warning : PillTone.positive,
              message: l10n.profileSpecialtyNote,
            ),
          ),
        ],
      ),
    );
  }

  Widget _prescriptionHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsGroup(
      title: l10n.profilePrescriptionHeader,
      children: [
        SettingsTile(
          icon: Icons.receipt_outlined,
          title: l10n.profilePrescriptionHeaderTitle,
          subtitle: l10n.rxSettingsTileHint,
          onTap: () => context.go(ClinicAdminRoutes.doctorRxSettings),
        ),
      ],
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonLoading(
        loading: true,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: const [
            Text('----------------'),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('------------'),
                    SizedBox(height: 16),
                    TextField(decoration: InputDecoration(labelText: '----------')),
                    SizedBox(height: 16),
                    TextField(decoration: InputDecoration(labelText: '----------')),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}
