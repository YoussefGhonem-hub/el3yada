import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/format/app_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/motion.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../admin/presentation/widgets/admin_widgets.dart';
import '../../../clinic/application/clinic_providers.dart';
import '../../../clinic/domain/clinic_context.dart';
import '../../../sessions/domain/session_models.dart';
import '../../../../core/widgets/navigation/app_back_button.dart';

export '../../../admin/presentation/widgets/admin_widgets.dart'
    show AdminErrorView, InfoRow, InitialAvatar, PillTone, ResponsiveGrid, SectionCard, StatusPill, confirmAction, showAdminSnack;

/// Shared pieces of the patient, session and fee screens (D1–D9, AS1–AS5).

/// Side padding: 16 on phones, more on wide content.
double clinicGutter(double width) => width >= 840 ? 32 : (width >= 600 ? 24 : 16);

/// Cairo dates and times for the clinic screens (spec section 12).
abstract final class ClinicFormat {
  static String _locale(BuildContext context) => Localizations.localeOf(context).languageCode;

  /// A Cairo day (UTC midnight): «3 نوفمبر 2026» / "Nov 3, 2026".
  static String day(BuildContext context, DateTime day) => DateFormat.yMMMd(_locale(context)).format(day);

  /// «3 نوفمبر» / "Nov 3".
  static String dayShort(BuildContext context, DateTime day) => DateFormat.MMMd(_locale(context)).format(day);

  /// «الثلاثاء 3 نوفمبر» / "Tue, Nov 3".
  static String dayWithWeekday(BuildContext context, DateTime day) => DateFormat.MMMEd(_locale(context)).format(day);

  /// [dayShort] this year, [day] (with the year) otherwise.
  static String dayAuto(BuildContext context, DateTime day) =>
      day.year == today().year ? dayShort(context, day) : ClinicFormat.day(context, day);

  /// «نوفمبر 2026» / "November 2026".
  static String month(BuildContext context, DateTime month) => DateFormat.yMMMM(_locale(context)).format(month);

  /// The Cairo clock time of a UTC instant: «10:04 ص» / "10:04 AM".
  static String time(BuildContext context, DateTime at) => DateFormat.jm(_locale(context)).format(AppFormat.cairo(at));

  /// Today in Cairo, as UTC midnight (AC-4: never the device's own day).
  static DateTime today([DateTime? now]) {
    final cairo = AppFormat.cairo(now ?? DateTime.now());
    return DateTime.utc(cairo.year, cairo.month, cairo.day);
  }

  /// "Today", "Yesterday", "5 days ago".
  static String daysAgo(AppLocalizations l10n, int days) => switch (days) {
        <= 0 => l10n.sessionToday,
        1 => l10n.sessionYesterday,
        _ => l10n.sessionDaysAgo(days),
      };
}

/// كشف (blue) or استشارة (green): the colours keep their meaning everywhere
/// (spec section 12). Always text, never colour alone.
class TypeBadge extends StatelessWidget {
  const TypeBadge(this.type, {super.key, this.large = false, this.locked = false});

  final SessionType type;
  final bool large;

  /// BR-S6: type can't change after saving (D9).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.el3yadaColors;
    final exam = type == SessionType.examination;
    final background = exam ? colors.examination : colors.consultation;
    final foreground = exam ? colors.onExamination : colors.onConsultation;
    final style = (large ? Theme.of(context).textTheme.titleSmall : Theme.of(context).textTheme.labelMedium)
        ?.copyWith(color: foreground, fontWeight: FontWeight.w600);
    return DecoratedBox(
      decoration: ShapeDecoration(color: background, shape: const StadiumBorder()),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10, vertical: large ? 6 : 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (locked) ...[
              ExcludeSemantics(child: Icon(Icons.lock_outline, size: large ? 16 : 13, color: foreground)),
              const SizedBox(width: 4),
            ],
            Flexible(child: Text(sessionTypeLabel(l10n, type), style: style, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

String sessionTypeLabel(AppLocalizations l10n, SessionType type) =>
    type == SessionType.examination ? l10n.sessionTypeExamination : l10n.sessionTypeConsultation;

String paymentMethodLabel(AppLocalizations l10n, PaymentMethod method) => switch (method) {
      PaymentMethod.cash => l10n.sessionPaymentCash,
      PaymentMethod.card => l10n.sessionPaymentCard,
      PaymentMethod.instapay => l10n.sessionPaymentInstapay,
      PaymentMethod.wallet => l10n.sessionPaymentWallet,
    };

/// «بانتظار الطبيب» on a session an assistant recorded (BR-AS7).
class AwaitingDoctorBadge extends StatelessWidget {
  const AwaitingDoctorBadge({super.key});

  @override
  Widget build(BuildContext context) => StatusPill(
        label: AppLocalizations.of(context).sessionAwaitingDoctor,
        tone: PillTone.warning,
        icon: Icons.hourglass_top_rounded,
      );
}

/// The red allergy flag (spec 6.1: allergies are red everywhere).
class AllergyFlag extends StatelessWidget {
  const AllergyFlag({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.el3yadaColors;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.patientHasAllergies,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: ShapeDecoration(color: colors.allergy, shape: const StadiumBorder()),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded, size: 14, color: colors.onAllergy),
                if (!compact) ...[
                  const SizedBox(width: 4),
                  Text(
                    l10n.patientAllergyFlag,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.onAllergy, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «ملف 12»: the file number, always left to right.
class FileNumberPill extends StatelessWidget {
  const FileNumberPill(this.number, {super.key});

  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          AppLocalizations.of(context).patientFileNumber('$number'),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// «2 كشف + 3 استشارة = 105 ج.م» (BR-B2, AC-4).
String feeEquation(BuildContext context, FeeTotals totals) {
  final l10n = AppLocalizations.of(context);
  return l10n.feesEquation(
    l10n.feesExaminationCount(totals.examinationCount),
    l10n.feesConsultationCount(totals.consultationCount),
    AppFormat.egp(context, totals.totalPiasters),
  );
}

/// An icon and a short text, for meta lines under a title.
class MetaLine extends StatelessWidget {
  const MetaLine({super.key, required this.icon, required this.text, this.ltr = false, this.color});

  final IconData icon;
  final String text;
  final bool ltr;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 16, color: tint)),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textDirection: ltr ? TextDirection.ltr : null,
            style: theme.textTheme.bodySmall?.copyWith(color: tint),
          ),
        ),
      ],
    );
  }
}

/// The title row of a clinic screen, with Back on detail screens (the tab's
/// top bar has none).
class ClinicHeader extends StatelessWidget {
  const ClinicHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.backFallback,
    this.trailingTitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Shows Back; where it goes when there's nothing to pop (opened by link).
  final String? backFallback;

  /// Next to the title, for example a type badge.
  final Widget? trailingTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (backFallback != null && !ShellBackScope.handlesBack(context)) ...[
          ClinicBackButton(fallback: backFallback!),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: theme.textTheme.headlineSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  if (trailingTitle != null) ...[const SizedBox(width: 10), trailingTitle!],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        for (final action in actions) ...[const SizedBox(width: 8), action],
      ],
    );
  }
}

/// Back inside a tab: pops, or goes to [fallback] when opened by link.
class ClinicBackButton extends StatelessWidget {
  const ClinicBackButton({super.key, required this.fallback});

  final String fallback;

  @override
  Widget build(BuildContext context) =>
      ShellBackScope.handlesBack(context) ? const SizedBox.shrink() : AppBackButton(fallback: fallback);
}

/// Waits for the clinic (`GET /api/clinic/me`): what the caller may see and
/// do decides the whole screen (spec 7.6).
class ClinicGate extends ConsumerWidget {
  const ClinicGate({super.key, required this.builder, this.loading});

  final Widget Function(BuildContext context, ClinicContext clinic) builder;

  /// The skeleton while the clinic loads.
  final Widget? loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clinic = ref.watch(clinicContextProvider);
    final value = clinic.value;
    if (value != null) return builder(context, value);
    if (clinic.hasError && !clinic.isLoading) {
      return AdminErrorView(error: clinic.error!, onRetry: () => ref.invalidate(clinicContextProvider));
    }
    return loading ?? const SkeletonLoading(loading: true, child: _GateSkeleton());
  }
}

class _GateSkeleton extends StatelessWidget {
  const _GateSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < 4; i++) ...[
            const Card(child: SizedBox(height: 96, child: Center(child: Text('—————————————')))),
            const SizedBox(height: 12),
          ],
        ],
      );
}

/// Shown instead of an action BR-G5 blocks while the doctor is suspended
/// (opened by its address; the buttons to it are hidden).
class SuspendedNotice extends StatelessWidget {
  const SuspendedNotice({super.key, this.backFallback});

  final String? backFallback;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: scheme.errorContainer, shape: BoxShape.circle),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Icon(Icons.pause_circle_outline, size: 36, color: scheme.onErrorContainer),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.errorDoctorSuspended, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
              if (backFallback != null) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : context.go(backFallback!),
                  child: Text(l10n.regBack),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A grouped list: rows inside one white card, split by hairlines (the
/// "queue ticket" grouped rows).
class GroupedRows extends StatelessWidget {
  const GroupedRows({super.key, required this.children, this.padding = EdgeInsets.zero});

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                child,
              ],
            ],
          ),
        ),
      );
}

/// Grows and shrinks with its content; instant with reduced motion.
class SmoothSize extends StatelessWidget {
  const SmoothSize({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: Motion.of(context).reduced ? Duration.zero : Motion.normal,
        curve: Motion.standardCurve,
        alignment: AlignmentDirectional.topStart,
        child: child,
      );
}

/// The «ج.م» / "EGP" amount, always left to right inside Arabic text.
class MoneyText extends StatelessWidget {
  const MoneyText(this.piasters, {super.key, this.style});

  final int piasters;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(AppFormat.egp(context, piasters), style: style);
}

/// Filter and choice chips on the mint ground: a white chip with a hairline,
/// so an unselected chip still reads as tappable.
class ClinicChips extends StatelessWidget {
  const ClinicChips({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChipTheme(
      data: ChipTheme.of(context).copyWith(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
